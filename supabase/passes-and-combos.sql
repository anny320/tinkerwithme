-- ════════════════════════════════════════════════════════════════════════
-- Two one-time (non-subscription) products for buyers who won't tick membership:
--
--   • PASS  — pay once for 3 or 6 months of Club/Premium. No card saved, no
--             auto-renew. Just extends membership access by N months.
--   • COMBO — a premium course + 1 live trainer hour, sold at 20% off the pair.
--             The course unlocks instantly; the live hour is logged for the
--             admin to arrange (the buyer is nudged to WhatsApp).
--
-- Both are paid with the Paystack inline popup (a one-time charge, no plan) and
-- fulfilled by the webhook (supabase/functions/paystack-webhook) via the RPCs
-- below, which are service_role only. Idempotent on the Paystack reference.
--
-- Depends on lms.sql (lms_grant_access, lms_courses, lms_payments, lms_profiles)
-- + membership.sql (lms_memberships). Safe to run again.
-- ════════════════════════════════════════════════════════════════════════

-- Allow every payment kind we use anywhere (this also reconciles the earlier
-- split where lms.sql ended on 'bundle' and membership.sql on 'membership').
alter table public.lms_payments drop constraint if exists lms_payments_kind_check;
alter table public.lms_payments add constraint lms_payments_kind_check
  check (kind in ('course', 'renewal', 'trainer', 'curriculum', 'bundle', 'membership', 'pass', 'combo'));

-- A pass grant marks the membership cycle as 'pass' (non-renewing).
alter table public.lms_memberships drop constraint if exists lms_memberships_cycle_check;
alter table public.lms_memberships add constraint lms_memberships_cycle_check
  check (cycle in ('monthly', 'annual', 'pass'));

-- ── Pass prices — the server-side source of truth (KES) ───────────────────
create or replace function public.lms_pass_price(p_tier text, p_months int) returns int
language sql immutable as $$
  select case lower(p_tier)
    when 'club'    then case p_months when 3 then 5700  when 6 then 11000 end
    when 'premium' then case p_months when 3 then 18500 when 6 then 36000 end
  end
$$;
grant execute on function public.lms_pass_price(text, int) to anon, authenticated;

-- ── Apply a PASS (service_role only, from the webhook) ────────────────────
create or replace function public.lms_apply_paystack_pass(
  p_user_id text, p_email text, p_tier text, p_months int, p_reference text, p_amount_kes int default null
) returns json language plpgsql security definer set search_path = public as $$
declare
  v_uid text;
  v_ref text := nullif(upper(regexp_replace(coalesce(p_reference, ''), '[^A-Za-z0-9_-]', '', 'g')), '');
  v_code text;
  v_tier text := lower(btrim(coalesce(p_tier, '')));
  v_months int := p_months;
  v_expected int;
begin
  if v_ref is not null and char_length(v_ref) between 6 and 60 then v_code := v_ref; end if;

  -- Retry-safe: once this reference is approved, do nothing.
  if v_code is not null and exists (select 1 from lms_payments where code = v_code and status = 'approved') then
    return json_build_object('ok', true, 'event', 'already');
  end if;

  if v_tier not in ('club', 'premium') or v_months not in (3, 6) then
    return json_build_object('ok', false, 'reason', 'bad pass', 'tier', v_tier, 'months', v_months);
  end if;
  v_expected := lms_pass_price(v_tier, v_months);

  v_uid := nullif(btrim(coalesce(p_user_id, '')), '');
  if v_uid is null and coalesce(p_email, '') <> '' then
    select user_id into v_uid from lms_profiles where lower(email) = lower(p_email) order by last_seen_at desc limit 1;
  end if;

  -- No account, or paid less than the pass costs → park pending for review.
  if v_uid is null or (p_amount_kes is not null and v_expected is not null and p_amount_kes < v_expected - 50) then
    insert into lms_payments (user_id, email, kind, product, code, amount_kes, message, method, status, note)
      values (coalesce(v_uid, ''), coalesce(p_email, ''), 'pass', v_tier || '-' || v_months || 'm',
              coalesce(v_code, upper('PS' || substr(md5(coalesce(p_email, '') || clock_timestamp()::text), 1, 20))),
              p_amount_kes, 'Paystack pass', 'paystack', 'pending',
              case when v_uid is null then 'Paystack pass — no linked account; grant by hand once they sign in'
                   else 'Paystack pass — amount below expected (' || v_expected || '); review' end)
      on conflict (code) do nothing;
    return json_build_object('ok', true, 'event', 'pending', 'tier', v_tier, 'months', v_months);
  end if;

  -- Grant: extend access by N months from today (or from the current expiry if
  -- it's still in the future). No subscription code → never auto-renews.
  insert into lms_memberships (user_id, tier, status, cycle, email, expires_at)
    values (v_uid, v_tier, 'active', 'pass', p_email, now() + (v_months || ' months')::interval)
  on conflict (user_id) do update set
    tier = excluded.tier, status = 'active', cycle = 'pass',
    email = coalesce(excluded.email, lms_memberships.email),
    expires_at = greatest(now(), coalesce(lms_memberships.expires_at, now())) + (v_months || ' months')::interval,
    updated_at = now();

  if v_code is not null then
    insert into lms_payments (user_id, email, kind, product, code, amount_kes, message, method, status, decided_at, note)
      values (v_uid, coalesce(p_email, ''), 'pass', v_tier || '-' || v_months || 'm', v_code, p_amount_kes,
              'Paystack pass', 'paystack', 'approved', now(),
              'Auto-approved via Paystack webhook (' || v_months || '-month ' || v_tier || ' pass)')
      on conflict (code) do update set status = 'approved', decided_at = now(), user_id = excluded.user_id, note = excluded.note;
  end if;

  return json_build_object('ok', true, 'event', 'granted', 'user', v_uid, 'tier', v_tier, 'months', v_months);
end $$;
revoke all on function public.lms_apply_paystack_pass(text, text, text, int, text, int) from public, anon, authenticated;
grant execute on function public.lms_apply_paystack_pass(text, text, text, int, text, int) to service_role;

-- ── Apply a COMBO: course + 1 live trainer hour (service_role only) ───────
create or replace function public.lms_apply_paystack_combo(
  p_user_id text, p_email text, p_course text, p_reference text, p_amount_kes int default null
) returns json language plpgsql security definer set search_path = public as $$
declare
  v_uid text;
  v_ref text := nullif(upper(regexp_replace(coalesce(p_reference, ''), '[^A-Za-z0-9_-]', '', 'g')), '');
  v_code text;
  v_slug text := lower(btrim(coalesce(p_course, '')));
  c lms_courses;
begin
  if v_ref is not null and char_length(v_ref) between 6 and 60 then v_code := v_ref; end if;

  if v_code is not null and exists (select 1 from lms_payments where code = v_code and status = 'approved') then
    return json_build_object('ok', true, 'event', 'already');
  end if;

  select * into c from lms_courses where slug = v_slug;
  if c.id is null then
    return json_build_object('ok', false, 'reason', 'bad course', 'course', v_slug);
  end if;

  v_uid := nullif(btrim(coalesce(p_user_id, '')), '');
  if v_uid is null and coalesce(p_email, '') <> '' then
    select user_id into v_uid from lms_profiles where lower(email) = lower(p_email) order by last_seen_at desc limit 1;
  end if;

  -- No account → park the whole combo pending for manual follow-up.
  if v_uid is null then
    insert into lms_payments (user_id, email, kind, product, code, amount_kes, hours, message, method, status, note)
      values ('', coalesce(p_email, ''), 'combo', v_slug,
              coalesce(v_code, upper('PS' || substr(md5(coalesce(p_email, '') || clock_timestamp()::text), 1, 20))),
              p_amount_kes, 1, 'Paystack combo (course + 1 live hour)', 'paystack', 'pending',
              'Combo — no linked account; grant the course + arrange the live hour once they sign in')
      on conflict (code) do nothing;
    return json_build_object('ok', true, 'event', 'pending', 'course', v_slug);
  end if;

  -- Unlock the course now (12 months).
  perform lms_grant_access(v_uid, c.id);

  -- Record the combo as approved — this row is the admin's cue that 1 live
  -- trainer hour is owed and needs scheduling.
  if v_code is not null then
    insert into lms_payments (user_id, email, kind, product, code, amount_kes, hours, message, method, status, decided_at, note)
      values (v_uid, coalesce(p_email, ''), 'combo', v_slug, v_code, p_amount_kes, 1,
              'Paystack combo', 'paystack', 'approved', now(),
              'Auto: course unlocked + 1 live trainer hour to arrange')
      on conflict (code) do update set status = 'approved', decided_at = now(), user_id = excluded.user_id, note = excluded.note;
  end if;

  return json_build_object('ok', true, 'event', 'granted', 'user', v_uid, 'course', v_slug);
end $$;
revoke all on function public.lms_apply_paystack_combo(text, text, text, text, int) from public, anon, authenticated;
grant execute on function public.lms_apply_paystack_combo(text, text, text, text, int) to service_role;

-- ── Admin payments list: teach the existing view about 'pass' and 'combo' ──
-- Same as lms.sql's lms_admin_payments, plus a title and expected price for the
-- two new kinds (so the Payments tab shows them correctly instead of null).
create or replace function public.lms_admin_payments()
returns json language plpgsql stable security definer set search_path = public as $$
begin
  if not lms_is_admin() then raise exception 'Admins only.'; end if;
  return coalesce((select json_agg(x order by x.pending desc, x.created_at desc) from (
    select p.id, p.kind, p.hours, p.code, p.amount_kes, p.message, p.status, p.note, p.created_at, p.decided_at, p.method,
           p.status = 'pending' as pending, p.email, coalesce(pr.full_name, '') as full_name, p.product,
           case p.kind
             when 'curriculum' then 'Curriculum: ' || p.product
             when 'bundle' then 'Bundle: ' || coalesce(b.title, p.product)
             when 'combo' then 'Course + live hour: ' || coalesce(cc.title, p.product)
             when 'pass' then 'Membership pass: ' || p.product
             else c.title end as title,
           case p.kind
             when 'trainer' then p.hours * lms_trainer_rate()
             when 'curriculum' then lms_curriculum_price()
             when 'bundle' then b.price_kes
             when 'combo' then round((coalesce(cc.price_kes, 0) + lms_trainer_rate()) * 0.8)::int
             when 'pass' then lms_pass_price(split_part(p.product, '-', 1), nullif(regexp_replace(split_part(p.product, '-', 2), '[^0-9]', '', 'g'), '')::int)
             else case when c.offer_price_kes is not null and p.created_at < c.offer_ends_at then c.offer_price_kes else c.price_kes end end as expected_kes,
           case p.kind
             when 'trainer' then p.hours * lms_trainer_rate_usd()
             when 'curriculum' then lms_curriculum_price_usd()
             when 'bundle' then b.price_usd
             when 'combo' then round((coalesce(cc.price_usd, 0) + lms_trainer_rate_usd()) * 0.8)::int
             else case when c.offer_price_usd is not null and p.created_at < c.offer_ends_at then c.offer_price_usd else c.price_usd end end as expected_usd
    from lms_payments p left join lms_courses c on c.id = p.course_id left join lms_profiles pr on pr.user_id = p.user_id
      left join lms_bundles b on p.kind = 'bundle' and b.slug = p.product
      left join lms_courses cc on p.kind = 'combo' and cc.slug = p.product
    where p.status = 'pending' or p.id in (select id from lms_payments where status <> 'pending' order by decided_at desc limit 30)
  ) x), '[]'::json);
end $$;
grant execute on function public.lms_admin_payments() to authenticated;
