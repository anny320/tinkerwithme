-- ════════════════════════════════════════════════════════════════════════
-- Auto-fulfil CURRICULUM purchases (the KES 1,500 teacher PDFs) paid with the
-- Paystack inline popup.
--
-- curriculum.html opens the popup with metadata { curriculum: <premium id>,
-- user_id: <clerk id>, kind: 'curriculum' }. On a successful charge the webhook
-- (no plan, metadata.curriculum present) calls this function with the service
-- role key. It grants download access (lms_curriculum_access), idempotent on the
-- Paystack reference. If the payer can't be bound to an account, it parks a
-- pending payment for manual follow-up (curriculum access has no sign-in redeem,
-- unlike course enrolments, so an unmatched payer is rare but handled by hand).
--
-- Locked to service_role only. Run this whole file in the Supabase SQL editor.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.lms_apply_paystack_curriculum(
  p_user_id text, p_email text, p_premium text, p_reference text, p_amount_kes int default null
) returns json language plpgsql security definer set search_path = public as $$
declare
  v_uid text;
  v_ref text := nullif(upper(regexp_replace(coalesce(p_reference, ''), '[^A-Za-z0-9_-]', '', 'g')), '');
  v_code text;
  v_premium text := lower(btrim(coalesce(p_premium, '')));
begin
  if v_ref ~ '^[A-Z0-9_-]{6,60}$' then v_code := v_ref; end if;

  -- Retry-safe: once this reference is recorded as approved, do nothing.
  if v_code is not null and exists (select 1 from lms_payments where code = v_code and status = 'approved') then
    return json_build_object('ok', true, 'event', 'already');
  end if;

  if v_premium !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    return json_build_object('ok', false, 'reason', 'bad curriculum id', 'curriculum', v_premium);
  end if;

  v_uid := nullif(btrim(coalesce(p_user_id, '')), '');
  if v_uid is null and coalesce(p_email, '') <> '' then
    select user_id into v_uid from lms_profiles
      where lower(email) = lower(p_email) order by last_seen_at desc limit 1;
  end if;

  -- No account yet → park a pending payment for manual follow-up.
  if v_uid is null then
    insert into lms_payments (user_id, email, kind, product, code, amount_kes, message, method, status, note)
      values ('', coalesce(p_email, ''), 'curriculum', v_premium,
              coalesce(v_code, upper('PS' || substr(md5(coalesce(p_email, '') || clock_timestamp()::text), 1, 20))),
              p_amount_kes, 'Paystack charge — no linked account', 'paystack', 'pending',
              'Auto-staged via Paystack webhook; grant by hand once the buyer signs in')
      on conflict (code) do nothing;
    return json_build_object('ok', true, 'event', 'pending', 'email', p_email, 'curriculum', v_premium);
  end if;

  -- Grant download access (idempotent — an approved row above short-circuits retries).
  insert into lms_curriculum_access (user_id, premium_id) values (v_uid, v_premium) on conflict do nothing;

  if v_code is not null then
    insert into lms_payments (user_id, email, kind, product, code, amount_kes, message, method, status, decided_at, note)
      values (v_uid, coalesce(p_email, ''), 'curriculum', v_premium,
              v_code, p_amount_kes, 'Paystack charge', 'paystack', 'approved', now(),
              'Auto-approved via Paystack webhook')
      on conflict (code) do update
        set status = 'approved', decided_at = now(), user_id = excluded.user_id, note = excluded.note;
  end if;

  return json_build_object('ok', true, 'event', 'granted', 'user', v_uid, 'curriculum', v_premium);
end $$;

revoke all on function public.lms_apply_paystack_curriculum(text, text, text, text, int) from public, anon, authenticated;
grant execute on function public.lms_apply_paystack_curriculum(text, text, text, text, int) to service_role;
