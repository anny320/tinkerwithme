-- ════════════════════════════════════════════════════════════════════════
-- Paystack recurring billing for memberships (auto-renew).
--
-- This is the server-side half of #28. It gives the Edge Function
-- (supabase/functions/paystack-webhook) a SAFE way to turn *verified* Paystack
-- subscription events into membership grants, without the public API ever
-- being able to grant itself a membership.
--
-- Trust model:
--   • The Edge Function verifies the x-paystack-signature HMAC first, then
--     authenticates to PostgREST with the SERVICE ROLE key (server-only).
--   • lms_apply_paystack_membership is granted to service_role ONLY — anon and
--     authenticated cannot execute it, so no browser can call it.
--   • This is the one place memberships are written automatically. Everything
--     a signed-in user can reach still goes through the manual-approve flow.
--
-- Idempotent + retry-safe: Paystack re-delivers a webhook until it gets a 200.
--   • A charge/renewal is deduped by its unique transaction reference.
--   • expires_at is set to Paystack's next_payment_date when present (absolute,
--     so re-delivery is a no-op); only when no date is given do we add a cycle.
--
-- Depends on lms.sql + membership.sql. Safe to run again.
-- ════════════════════════════════════════════════════════════════════════

-- Remember the Paystack identifiers + the billing email on each membership, so
-- renewal events (which carry no app metadata) can be matched back to a user.
alter table public.lms_memberships add column if not exists email text;
alter table public.lms_memberships add column if not exists paystack_customer_code text;
alter table public.lms_memberships add column if not exists paystack_subscription_code text;
alter table public.lms_memberships add column if not exists paystack_plan_code text;
create index if not exists lms_memberships_email_idx on public.lms_memberships (lower(email));

-- One Paystack Plan per tier×cycle. The owner seeds this with the real plan
-- codes from the Paystack dashboard (see the README). Example at the bottom.
create table if not exists public.lms_paystack_plans (
  plan_code text primary key,
  tier      text not null check (tier in ('club', 'premium')),
  cycle     text not null check (cycle in ('monthly', 'annual'))
);
alter table public.lms_paystack_plans enable row level security;
revoke all on public.lms_paystack_plans from anon, authenticated;
-- Readable by signed-in users: membership.html looks up the plan code to start
-- a subscription. Only admins can change the mapping.
grant select on public.lms_paystack_plans to authenticated;
drop policy if exists "read plans"  on public.lms_paystack_plans;
drop policy if exists "admin plans" on public.lms_paystack_plans;
create policy "read plans"  on public.lms_paystack_plans for select to authenticated using (true);
create policy "admin plans" on public.lms_paystack_plans for all    to authenticated using (lms_is_admin()) with check (lms_is_admin());

-- Frontend helper: the plan code for a tier+cycle (null until the owner seeds it).
create or replace function public.lms_paystack_plan(p_tier text, p_cycle text) returns text
language sql stable security definer set search_path = public as $$
  select plan_code from lms_paystack_plans where tier = p_tier and cycle = p_cycle limit 1
$$;
grant execute on function public.lms_paystack_plan(text, text) to anon, authenticated;

-- ── The webhook writer — service-role only ──────────────────────────────
-- Called by the Edge Function AFTER the signature is verified.
--   p_user_id    : our Clerk id, from the first charge's metadata (null later)
--   p_email      : the Paystack customer email (matches renewals to a user)
--   p_plan_code  : the Paystack plan code (maps to tier+cycle)
--   p_tier/cycle : from metadata when present; else resolved from the plan map
--   p_event      : 'charge' (money in → activate/extend) or 'disable' (stop renew)
--   p_reference  : the transaction reference (unique; used for dedup)
--   p_paid_until : next_payment_date from Paystack (we set expires_at to this)
create or replace function public.lms_apply_paystack_membership(
  p_user_id text, p_email text, p_plan_code text, p_tier text, p_cycle text,
  p_event text, p_reference text, p_subscription_code text, p_customer_code text,
  p_paid_until timestamptz, p_amount_kes int
) returns json language plpgsql security definer set search_path = public as $$
declare v_uid text; v_tier text; v_cycle text; v_ref text; v_code text; m lms_memberships;
begin
  v_ref := nullif(upper(regexp_replace(coalesce(p_reference, ''), '[^A-Za-z0-9_-]', '', 'g')), '');
  -- Only use the reference as a payments.code if it fits the 6–60 char check,
  -- so a malformed reference can never raise and break webhook idempotency.
  v_code := case when v_ref is not null and char_length(v_ref) between 6 and 60 then v_ref end;

  -- Retry-safe: if we've already recorded this reference, do nothing.
  if v_code is not null and exists (select 1 from lms_payments where code = v_code) then
    return json_build_object('ok', true, 'duplicate', true);
  end if;

  -- Resolve tier/cycle: trust metadata first, else the plan map.
  v_tier  := coalesce(nullif(p_tier, ''),  (select tier  from lms_paystack_plans where plan_code = p_plan_code));
  v_cycle := coalesce(nullif(p_cycle, ''), (select cycle from lms_paystack_plans where plan_code = p_plan_code));
  if v_tier is null or v_cycle is null then
    raise exception 'Unknown Paystack plan "%". Add it to lms_paystack_plans.', p_plan_code;
  end if;

  -- Resolve our user: metadata id first, then the email on an existing membership.
  v_uid := nullif(btrim(coalesce(p_user_id, '')), '');
  if v_uid is null and coalesce(p_email, '') <> '' then
    select user_id into v_uid from lms_memberships
      where lower(email) = lower(p_email) order by updated_at desc limit 1;
  end if;

  -- Couldn't bind to an account — park it as a pending payment for manual follow-up.
  if v_uid is null then
    insert into lms_payments (user_id, email, kind, product, code, amount_kes, message, method, status, note)
      values ('', coalesce(p_email, ''), 'membership', v_tier || '-' || v_cycle,
              coalesce(v_code, upper('PS' || substr(md5(coalesce(p_email, '') || clock_timestamp()::text), 1, 20))),
              p_amount_kes, 'Paystack ' || p_event || ' — no linked account', 'paystack', 'pending',
              'Unmatched Paystack payment; link it to a user and grant manually.')
      on conflict (code) do nothing;
    return json_build_object('ok', false, 'reason', 'no-user-for-email');
  end if;

  -- Cancellation: don't yank access mid-term; let it lapse at expires_at.
  if p_event = 'disable' then
    update lms_memberships
      set paystack_subscription_code = coalesce(p_subscription_code, paystack_subscription_code), updated_at = now()
      where user_id = v_uid;
    return json_build_object('ok', true, 'event', 'disable', 'user', v_uid);
  end if;

  -- Money in → activate + extend. Prefer Paystack's next_payment_date (absolute,
  -- so re-delivery is harmless); otherwise add one cycle.
  insert into lms_memberships (user_id, tier, status, cycle, email, expires_at,
      paystack_customer_code, paystack_subscription_code, paystack_plan_code)
    values (v_uid, v_tier, 'active', v_cycle, p_email,
      coalesce(p_paid_until, now() + (case v_cycle when 'annual' then interval '1 year' else interval '1 month' end)),
      p_customer_code, p_subscription_code, p_plan_code)
  on conflict (user_id) do update set
    tier   = excluded.tier,
    status = 'active',
    cycle  = excluded.cycle,
    email  = coalesce(excluded.email, lms_memberships.email),
    expires_at = coalesce(p_paid_until,
      greatest(now(), coalesce(lms_memberships.expires_at, now()))
        + (case excluded.cycle when 'annual' then interval '1 year' else interval '1 month' end)),
    paystack_customer_code     = coalesce(excluded.paystack_customer_code, lms_memberships.paystack_customer_code),
    paystack_subscription_code = coalesce(excluded.paystack_subscription_code, lms_memberships.paystack_subscription_code),
    paystack_plan_code         = coalesce(excluded.paystack_plan_code, lms_memberships.paystack_plan_code),
    updated_at = now()
  returning * into m;

  -- Audit trail: an already-approved payment row (best effort; refs are unique).
  if v_code is not null then
    insert into lms_payments (user_id, email, kind, product, code, amount_kes, message, method, status, decided_at, note)
      values (v_uid, coalesce(p_email, ''), 'membership', v_tier || '-' || v_cycle,
              v_code, p_amount_kes, 'Paystack ' || p_event, 'paystack', 'approved', now(),
              'Auto-approved via Paystack webhook')
      on conflict (code) do nothing;
  end if;

  return json_build_object('ok', true, 'event', 'charge', 'user', v_uid, 'tier', m.tier, 'expires_at', m.expires_at);
end $$;

-- Lock it down: service_role only (the Edge Function). Never the public API.
revoke all on function public.lms_apply_paystack_membership(text, text, text, text, text, text, text, text, text, timestamptz, int) from public, anon, authenticated;
grant execute on function public.lms_apply_paystack_membership(text, text, text, text, text, text, text, text, text, timestamptz, int) to service_role;

-- ── After running: seed your real plan codes from the Paystack dashboard ──
-- Create 4 Plans in Paystack (Club/Premium × monthly/annual) at the locked
-- prices, then map their codes here, e.g.:
--
--   insert into public.lms_paystack_plans (plan_code, tier, cycle) values
--     ('PLN_xxxxxxxxxxxx', 'club',    'monthly'),
--     ('PLN_xxxxxxxxxxxx', 'club',    'annual'),
--     ('PLN_xxxxxxxxxxxx', 'premium', 'monthly'),
--     ('PLN_xxxxxxxxxxxx', 'premium', 'annual')
--   on conflict (plan_code) do update set tier = excluded.tier, cycle = excluded.cycle;
--
-- Put the same four codes in lms.js CONFIG.paystackPlans so the join flow can
-- start the subscription. See supabase/functions/paystack-webhook/README.md.
