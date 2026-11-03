-- ════════════════════════════════════════════════════════════════════════
-- Auto-fulfil one-time COURSE purchases paid with the Paystack inline popup.
--
-- The course checkout (course.html → psPay) opens the Paystack popup with
--   metadata: { course: <slug>, user_id: <clerk id>, kind: 'course' }
-- On a successful charge Paystack POSTs charge.success to the webhook
-- (supabase/functions/paystack-webhook), which — for a charge with no plan but
-- a metadata.course — calls THIS function with the service-role key.
--
-- It grants the buyer 12 months of access (lms_grant_access), idempotent on the
-- Paystack transaction reference so webhook retries never double-grant. If the
-- payer can't be bound to an account, it parks a pending enrolment by email
-- (which lms_hello redeems the next time they sign in) plus a pending payment.
--
-- Locked to service_role only — no browser can reach it.
-- Run this whole file in the Supabase SQL editor.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.lms_apply_paystack_course(
  p_user_id text, p_email text, p_course text, p_reference text, p_amount_kes int default null
) returns json language plpgsql security definer set search_path = public as $$
declare
  v_uid text;
  v_ref text := nullif(upper(regexp_replace(coalesce(p_reference, ''), '[^A-Za-z0-9_-]', '', 'g')), '');
  v_code text;                 -- the reference, only if it fits the paystack code check
  v_slug text := lower(btrim(coalesce(p_course, '')));
  c lms_courses;
  v_kind text;
  v_result text;
begin
  -- Keep the reference as a payments.code only if it matches the stored format,
  -- so a malformed reference can never raise and break webhook idempotency.
  if v_ref ~ '^[A-Z0-9_-]{6,60}$' then v_code := v_ref; end if;

  -- Retry-safe: once this reference is recorded as approved, do nothing.
  if v_code is not null and exists (select 1 from lms_payments where code = v_code and status = 'approved') then
    return json_build_object('ok', true, 'event', 'already');
  end if;

  select * into c from lms_courses where slug = v_slug and is_published;
  if not found then
    -- Unknown/unpublished course: acknowledge so Paystack stops retrying; a human can reconcile.
    return json_build_object('ok', false, 'reason', 'course not found', 'course', v_slug);
  end if;

  -- Bind to an account: the Clerk id from checkout metadata, else the payer email.
  v_uid := nullif(btrim(coalesce(p_user_id, '')), '');
  if v_uid is null and coalesce(p_email, '') <> '' then
    select user_id into v_uid from lms_profiles
      where lower(email) = lower(p_email) order by last_seen_at desc limit 1;
  end if;

  -- No account yet → park a pending enrolment (redeemed on next sign-in) + pending payment.
  if v_uid is null then
    insert into lms_pending_enrollments (email, course_id) values (lower(coalesce(p_email, '')), c.id)
      on conflict do nothing;
    insert into lms_payments (user_id, email, course_id, kind, product, code, amount_kes, message, method, status, note)
      values ('', coalesce(p_email, ''), c.id, 'course', c.slug,
              coalesce(v_code, upper('PS' || substr(md5(coalesce(p_email, '') || clock_timestamp()::text), 1, 20))),
              p_amount_kes, 'Paystack charge — no linked account', 'paystack', 'pending',
              'Auto-staged via Paystack webhook; enrols on sign-in')
      on conflict (code) do nothing;
    return json_build_object('ok', true, 'event', 'pending', 'email', p_email, 'course', c.slug);
  end if;

  -- Grant (or renew) access. Idempotent because an approved row above short-circuits retries.
  v_result := lms_grant_access(v_uid, c.id);
  v_kind := case when v_result = 'enrolled' then 'course' else 'renewal' end;

  -- Audit trail: record the payment as already approved (or flip an existing
  -- pending row from the on-site fallback to approved).
  if v_code is not null then
    insert into lms_payments (user_id, email, course_id, kind, product, code, amount_kes, message, method, status, decided_at, note)
      values (v_uid, coalesce(p_email, ''), c.id, v_kind, c.slug,
              v_code, p_amount_kes, 'Paystack charge', 'paystack', 'approved', now(),
              'Auto-approved via Paystack webhook')
      on conflict (code) do update
        set status = 'approved', decided_at = now(), user_id = excluded.user_id,
            course_id = excluded.course_id, note = excluded.note;
  end if;

  return json_build_object('ok', true, 'event', v_result, 'user', v_uid, 'course', c.slug);
end $$;

-- Lock it down: service_role only (the Edge Function). Never the public API.
revoke all on function public.lms_apply_paystack_course(text, text, text, text, int) from public, anon, authenticated;
grant execute on function public.lms_apply_paystack_course(text, text, text, text, int) to service_role;
