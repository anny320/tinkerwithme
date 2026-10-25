-- ─────────────────────────────────────────────────────────────
-- Tinkerwith membership (Club / Premium)
-- Run this in the Supabase SQL editor, after lms.sql.
--
-- Club    : all self-paced courses + free content + new monthly projects
-- Premium : Club + two live group classes a month
-- Pricing (KES): Club 2,000/mo · 20,000/yr   Premium 6,500/mo · 65,000/yr
-- A membership is per account; a family plan simply means one account for
-- the household (no per-child seats to manage).
--
-- Recurring billing (Paystack Plans + webhook) comes later. Until then a
-- member is activated the same manual way as a curriculum: they paste a
-- payment reference, you approve it in teach.html (which calls
-- lms_grant_membership), and access flips on.
-- ─────────────────────────────────────────────────────────────

-- One current membership per account. Upgrades/downgrades update the row.
create table if not exists public.lms_memberships (
  user_id     text primary key,
  tier        text not null check (tier in ('club', 'premium')),
  status      text not null default 'active' check (status in ('active', 'expired', 'pending')),
  cycle       text not null default 'monthly' check (cycle in ('monthly', 'annual')),
  started_at  timestamptz not null default now(),
  expires_at  timestamptz,                       -- null = open-ended (e.g. comped); set per cycle on grant
  updated_at  timestamptz not null default now()
);
alter table public.lms_memberships enable row level security;
revoke all on public.lms_memberships from anon, authenticated;
grant select on public.lms_memberships to authenticated;
drop policy if exists "own rows"  on public.lms_memberships;
drop policy if exists "admin all" on public.lms_memberships;
create policy "own rows"  on public.lms_memberships for select to authenticated using (user_id = lms_uid());
create policy "admin all" on public.lms_memberships for all    to authenticated using (lms_is_admin()) with check (lms_is_admin());
drop trigger if exists lms_memberships_touch on public.lms_memberships;
create trigger lms_memberships_touch before update on public.lms_memberships for each row execute function public.lms_touch();

-- Prices (keep in step with membership.html). KES.
create or replace function public.lms_membership_price(p_tier text, p_cycle text) returns int
language sql immutable as $$
  select case
    when p_tier = 'club'    and p_cycle = 'monthly' then 2000
    when p_tier = 'club'    and p_cycle = 'annual'  then 20000
    when p_tier = 'premium' and p_cycle = 'monthly' then 6500
    when p_tier = 'premium' and p_cycle = 'annual'  then 65000
  end
$$;

-- The caller's current membership rank: 0 none, 1 club, 2 premium. Admins = 2.
create or replace function public.lms_member_rank() returns int
language sql stable security definer set search_path = public as $$
  select greatest(
    case when lms_is_admin() then 2 else 0 end,
    coalesce((select max(case tier when 'premium' then 2 else 1 end)
      from lms_memberships
      where user_id = lms_uid() and status = 'active'
        and (expires_at is null or expires_at > now())), 0))
$$;

-- Does the caller hold at least this tier?
create or replace function public.lms_has_membership(p_tier text) returns boolean
language sql stable security definer set search_path = public as $$
  select lms_member_rank() >= case p_tier when 'premium' then 2 else 1 end
$$;

-- My membership, for membership.html.
create or replace function public.lms_my_membership() returns json
language sql stable security definer set search_path = public as $$
  select coalesce((select json_build_object(
      'tier', tier, 'status', status, 'cycle', cycle, 'expires_at', expires_at,
      'active', status = 'active' and (expires_at is null or expires_at > now()))
    from lms_memberships where user_id = lms_uid()), json_build_object('tier', null, 'active', false))
$$;

-- Submit a membership payment (M-Pesa code, card order no., or Paystack ref).
-- Mirrors lms_submit_curriculum_payment; the admin approves it in teach.html.
create or replace function public.lms_submit_membership_payment(p_tier text, p_cycle text, p_message text, p_method text default 'mpesa')
returns json language plpgsql security definer set search_path = public as $$
declare uid text := lms_uid(); msg text := left(btrim(coalesce(p_message, '')), 600); v_code text; v_amount int; r lms_payments;
begin
  if uid is null then raise exception 'Please sign in.'; end if;
  if p_tier not in ('club', 'premium') then raise exception 'Unknown membership tier.'; end if;
  if p_cycle not in ('monthly', 'annual') then raise exception 'Unknown billing cycle.'; end if;
  if p_method not in ('mpesa', 'card', 'paystack') then raise exception 'Unknown payment method.'; end if;
  if p_method = 'card' then
    v_code := left((regexp_match(upper(msg), '([A-Z0-9][A-Z0-9-]*[0-9][A-Z0-9-]*)'))[1], 40);
    if coalesce(char_length(v_code), 0) < 3 then raise exception 'Please paste your order number.'; end if;
  elsif p_method = 'paystack' then
    v_code := left(regexp_replace(upper(btrim(msg)), '[^A-Z0-9_-]', '', 'g'), 60);
    if coalesce(char_length(v_code), 0) < 6 then raise exception 'We couldn''t read your Paystack reference.'; end if;
  else
    select m[1] into v_code from regexp_matches(upper(msg), '\m([A-Z0-9]{10})\M', 'g') as m
      where m[1] ~ '[0-9]' and m[1] ~ '[A-Z]' limit 1;
    if v_code is null then raise exception 'We couldn''t find the M-Pesa code. Paste the whole message, or the 10-character code.'; end if;
    v_amount := nullif(replace((regexp_match(upper(msg), 'KSHS?\.?\s*([0-9,]+)'))[1], ',', ''), '')::int;
  end if;
  if exists (select 1 from lms_payments where code = v_code) then raise exception 'That payment has already been sent to us.'; end if;
  if (select count(*) from lms_payments where user_id = uid and status = 'pending') >= 5 then
    raise exception 'You already have 5 payments waiting. We''ll check them soon.';
  end if;
  -- product encodes tier+cycle, e.g. "club-monthly", so the approver knows what to grant.
  insert into lms_payments (user_id, email, kind, product, code, amount_kes, message, method)
    values (uid, coalesce(lms_email(), ''), 'membership', p_tier || '-' || p_cycle, v_code, v_amount, msg, p_method)
    returning * into r;
  return json_build_object('id', r.id, 'kind', r.kind, 'code', r.code, 'status', r.status);
end $$;

-- Admin: grant / extend a membership (called when approving a membership payment).
-- Extends from the later of now or the current expiry, so renewals stack.
create or replace function public.lms_grant_membership(p_user text, p_tier text, p_cycle text)
returns void language plpgsql security definer set search_path = public as $$
declare base timestamptz;
begin
  if not lms_is_admin() then raise exception 'Admins only.'; end if;
  if p_tier not in ('club', 'premium') then raise exception 'Unknown tier.'; end if;
  if p_cycle not in ('monthly', 'annual') then raise exception 'Unknown cycle.'; end if;
  select greatest(now(), coalesce(expires_at, now())) into base from lms_memberships where user_id = p_user;
  base := coalesce(base, now());
  insert into lms_memberships (user_id, tier, status, cycle, expires_at)
    values (p_user, p_tier, 'active', p_cycle, base + (case p_cycle when 'annual' then interval '1 year' else interval '1 month' end))
  on conflict (user_id) do update set
    tier = excluded.tier, status = 'active', cycle = excluded.cycle,
    expires_at = greatest(now(), coalesce(lms_memberships.expires_at, now()))
                 + (case excluded.cycle when 'annual' then interval '1 year' else interval '1 month' end),
    updated_at = now();
end $$;

-- lms_payments: allow kind 'membership'.
alter table public.lms_payments drop constraint if exists lms_payments_kind_check;
alter table public.lms_payments add constraint lms_payments_kind_check
  check (kind in ('course', 'renewal', 'trainer', 'curriculum', 'membership'));

-- Mark which courses a membership unlocks: 'club' (in Club and above) or
-- 'premium' (Premium only). null = sold/enrolled individually, not by membership.
alter table public.lms_courses add column if not exists membership_tier text
  check (membership_tier is null or membership_tier in ('club', 'premium'));

-- Extend course access: admin OR an active enrolment OR an active membership
-- that covers this course's membership_tier. (Additive — existing access is
-- unchanged.)
create or replace function public.lms_can_access(p_course uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select lms_is_admin()
    or exists (
      select 1 from lms_enrollments e join lms_courses c on c.id = e.course_id
      where e.user_id = lms_uid() and e.course_id = p_course and c.is_published
        and (e.expires_at is null or e.expires_at > now()))
    or exists (
      select 1 from lms_courses c
      where c.id = p_course and c.is_published and c.membership_tier is not null
        and public.lms_member_rank() >= case c.membership_tier when 'premium' then 2 else 1 end)
$$;

grant execute on function
  public.lms_membership_price(text, text), public.lms_member_rank(), public.lms_has_membership(text),
  public.lms_my_membership(), public.lms_submit_membership_payment(text, text, text, text)
  to authenticated;
grant execute on function public.lms_my_membership(), public.lms_member_rank() to anon, authenticated;

-- ── After running: mark the self-paced courses that Club unlocks ──────
-- Membership unlocks the self-paced courses, not the free minis (already
-- free) or the live courses. Set the flag on the right rows, e.g.:
--
--   update public.lms_courses set membership_tier = 'club'
--   where price_kes > 0 and slug in ( …your self-paced course slugs… );
--
-- Review `select slug, title, price_kes, membership_tier from lms_courses
-- order by price_kes;` first, then set the flag on the self-paced set.
