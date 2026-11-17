-- ════════════════════════════════════════════════════════════════════════
-- Auto-fulfil BUNDLE purchases paid with the Paystack inline popup.
--
-- bundle.html opens the popup with metadata { bundle: <slug>, kind: 'bundle',
-- user_id }. On a successful charge the webhook (no plan, metadata.bundle present)
-- calls this with the service role key: it grants every course in the bundle for
-- 12 months. Idempotent on the Paystack reference. If the payer can't be bound to
-- an account, it parks a pending payment for manual follow-up.
--
-- Depends on lms.sql (lms_grant_access, lms_bundles, lms_bundle_courses,
-- lms_payments, lms_profiles). Safe to run again.
-- 'bundle' is already an allowed lms_payments.kind (see lms.sql / passes-and-combos.sql).
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.lms_apply_paystack_bundle(
  p_user_id text, p_email text, p_bundle text, p_reference text, p_amount_kes int default null
) returns json language plpgsql security definer set search_path = public as $$
declare
  v_uid text;
  v_ref text := nullif(upper(regexp_replace(coalesce(p_reference, ''), '[^A-Za-z0-9_-]', '', 'g')), '');
  v_code text;
  v_slug text := lower(btrim(coalesce(p_bundle, '')));
  v_n int;
begin
  if v_ref is not null and char_length(v_ref) between 6 and 60 then v_code := v_ref; end if;

  -- Retry-safe: once this reference is approved, do nothing.
  if v_code is not null and exists (select 1 from lms_payments where code = v_code and status = 'approved') then
    return json_build_object('ok', true, 'event', 'already');
  end if;

  if not exists (select 1 from lms_bundles where slug = v_slug) then
    return json_build_object('ok', false, 'reason', 'bad bundle', 'bundle', v_slug);
  end if;

  v_uid := nullif(btrim(coalesce(p_user_id, '')), '');
  if v_uid is null and coalesce(p_email, '') <> '' then
    select user_id into v_uid from lms_profiles where lower(email) = lower(p_email) order by last_seen_at desc limit 1;
  end if;

  -- No account yet → park a pending payment for manual follow-up.
  if v_uid is null then
    insert into lms_payments (user_id, email, kind, product, code, amount_kes, message, method, status, note)
      values ('', coalesce(p_email, ''), 'bundle', v_slug,
              coalesce(v_code, upper('PS' || substr(md5(coalesce(p_email, '') || clock_timestamp()::text), 1, 20))),
              p_amount_kes, 'Paystack bundle', 'paystack', 'pending',
              'Bundle — no linked account; grant once the buyer signs in')
      on conflict (code) do nothing;
    return json_build_object('ok', true, 'event', 'pending', 'bundle', v_slug);
  end if;

  -- Grant every course in the bundle (12 months each; idempotent).
  select count(lms_grant_access(v_uid, bc.course_id)) into v_n
    from lms_bundle_courses bc where bc.bundle_slug = v_slug;

  if v_code is not null then
    insert into lms_payments (user_id, email, kind, product, code, amount_kes, message, method, status, decided_at, note)
      values (v_uid, coalesce(p_email, ''), 'bundle', v_slug, v_code, p_amount_kes,
              'Paystack bundle', 'paystack', 'approved', now(), 'Auto-approved via Paystack webhook')
      on conflict (code) do update set status = 'approved', decided_at = now(), user_id = excluded.user_id, note = excluded.note;
  end if;

  return json_build_object('ok', true, 'event', 'granted', 'user', v_uid, 'bundle', v_slug, 'courses', v_n);
end $$;
revoke all on function public.lms_apply_paystack_bundle(text, text, text, text, int) from public, anon, authenticated;
grant execute on function public.lms_apply_paystack_bundle(text, text, text, text, int) to service_role;
