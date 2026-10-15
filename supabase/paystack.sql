-- ════════════════════════════════════════════════════════════════════════
-- Paystack support for payments (one-time curriculums, courses, bundles).
--
-- Adds 'paystack' as a payment method. Buyers pay on the Paystack storefront
-- (or card/M-Pesa), then paste their Paystack reference on the site; it lands
-- as a pending payment you verify in the Paystack dashboard and approve in
-- teach.html — the same manual-approve flow as M-Pesa and card.
--
-- Safe to run again. Depends on lms.sql.
-- ════════════════════════════════════════════════════════════════════════

alter table public.lms_payments drop constraint if exists lms_payments_method_check;
alter table public.lms_payments add constraint lms_payments_method_check check (method in ('mpesa', 'card', 'paystack'));
alter table public.lms_payments drop constraint if exists lms_payments_code_ok;
alter table public.lms_payments add constraint lms_payments_code_ok check (
  (method = 'mpesa' and code ~ '^[A-Z0-9]{10}$')
  or (method = 'card' and code ~ '^[A-Z0-9-]{3,40}$')
  or (method = 'paystack' and code ~ '^[A-Z0-9_-]{6,60}$'));

drop function if exists public.lms_submit_payment(uuid, text, int);

create or replace function public.lms_submit_payment(p_course uuid, p_message text, p_hours int default null, p_method text default 'mpesa')
returns json language plpgsql security definer set search_path = public as $$
declare
  uid text := lms_uid(); msg text := left(btrim(coalesce(p_message, '')), 600);
  v_code text; v_amount int; v_kind text; c lms_courses; r lms_payments;
begin
  if uid is null then raise exception 'Please sign in.'; end if;
  if p_method not in ('mpesa', 'card', 'paystack') then raise exception 'Unknown payment method.'; end if;
  select * into c from lms_courses where id = p_course and is_published;
  if not found then raise exception 'Course not found.'; end if;
  if p_method = 'card' then
    -- The first word with a digit in it, e.g. "Order #HS-48213" → HS-48213.
    v_code := left((regexp_match(upper(msg), '([A-Z0-9][A-Z0-9-]*[0-9][A-Z0-9-]*)'))[1], 40);
    if coalesce(char_length(v_code), 0) < 3 then raise exception 'Please paste your HustleSasa order number.'; end if;
  elsif p_method = 'paystack' then
    -- Paystack transaction reference, pasted from the receipt.
    v_code := left(regexp_replace(upper(btrim(msg)), '[^A-Z0-9_-]', '', 'g'), 60);
    if coalesce(char_length(v_code), 0) < 6 then raise exception 'We couldn''t read your Paystack reference. Paste the reference from your Paystack receipt.'; end if;
  else
    select m[1] into v_code from regexp_matches(upper(msg), '\m([A-Z0-9]{10})\M', 'g') as m
      where m[1] ~ '[0-9]' and m[1] ~ '[A-Z]' limit 1;
    if v_code is null then
      raise exception 'We couldn''t find the M-Pesa code. Paste the whole M-Pesa message, or just the 10-character code (like SJK4AB12CD).';
    end if;
  end if;
  if exists (select 1 from lms_payments where code = v_code) then
    raise exception 'That payment has already been sent to us.';
  end if;
  if (select count(*) from lms_payments where user_id = uid and status = 'pending') >= 5 then
    raise exception 'You already have 5 payments waiting. We''ll check them soon.';
  end if;
  if p_method = 'mpesa' then
    v_amount := nullif(replace((regexp_match(upper(msg), 'KSHS?\.?\s*([0-9,]+)'))[1], ',', ''), '')::int;
  end if;
  if p_hours is not null then
    if p_hours not between 1 and 10 then raise exception 'Choose between 1 and 10 hours.'; end if;
    v_kind := 'trainer';
  elsif c.price_kes = 0 then raise exception 'This course is free.';
  elsif exists (select 1 from lms_enrollments where user_id = uid and course_id = c.id) then v_kind := 'renewal';
  else v_kind := 'course';
  end if;
  insert into lms_payments (user_id, email, course_id, kind, hours, code, amount_kes, message, method)
    values (uid, coalesce(lms_email(), ''), c.id, v_kind, case when v_kind = 'trainer' then p_hours end, v_code, v_amount, msg, p_method)
    returning * into r;
  return json_build_object('id', r.id, 'kind', r.kind, 'code', r.code, 'amount_kes', r.amount_kes, 'status', r.status);
end $$;

create or replace function public.lms_submit_curriculum_payment(p_premium text, p_message text, p_method text default 'mpesa')
returns json language plpgsql security definer set search_path = public as $$
declare uid text := lms_uid(); msg text := left(btrim(coalesce(p_message, '')), 600); v_code text; v_amount int; r lms_payments;
begin
  if uid is null then raise exception 'Please sign in.'; end if;
  if coalesce(p_premium, '') !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then raise exception 'Curriculum not found.'; end if;
  if p_method not in ('mpesa', 'card', 'paystack') then raise exception 'Unknown payment method.'; end if;
  if p_method = 'card' then
    v_code := left((regexp_match(upper(msg), '([A-Z0-9][A-Z0-9-]*[0-9][A-Z0-9-]*)'))[1], 40);
    if coalesce(char_length(v_code), 0) < 3 then raise exception 'Please paste your HustleSasa order number.'; end if;
  elsif p_method = 'paystack' then
    v_code := left(regexp_replace(upper(btrim(msg)), '[^A-Z0-9_-]', '', 'g'), 60);
    if coalesce(char_length(v_code), 0) < 6 then raise exception 'We couldn''t read your Paystack reference. Paste the reference from your Paystack receipt.'; end if;
  else
    select m[1] into v_code from regexp_matches(upper(msg), '\m([A-Z0-9]{10})\M', 'g') as m
      where m[1] ~ '[0-9]' and m[1] ~ '[A-Z]' limit 1;
    if v_code is null then
      raise exception 'We couldn''t find the M-Pesa code. Paste the whole M-Pesa message, or just the 10-character code (like SJK4AB12CD).';
    end if;
    v_amount := nullif(replace((regexp_match(upper(msg), 'KSHS?\.?\s*([0-9,]+)'))[1], ',', ''), '')::int;
  end if;
  if exists (select 1 from lms_payments where code = v_code) then raise exception 'That payment has already been sent to us.'; end if;
  if (select count(*) from lms_payments where user_id = uid and status = 'pending') >= 5 then
    raise exception 'You already have 5 payments waiting. We''ll check them soon.';
  end if;
  insert into lms_payments (user_id, email, kind, product, code, amount_kes, message, method)
    values (uid, coalesce(lms_email(), ''), 'curriculum', p_premium, v_code, v_amount, msg, p_method)
    returning * into r;
  return json_build_object('id', r.id, 'kind', r.kind, 'code', r.code, 'amount_kes', r.amount_kes, 'status', r.status);
end $$;

create or replace function public.lms_submit_bundle_payment(p_bundle text, p_message text, p_method text default 'mpesa')
returns json language plpgsql security definer set search_path = public as $$
declare uid text := lms_uid(); msg text := left(btrim(coalesce(p_message, '')), 600); v_code text; v_amount int; r lms_payments;
begin
  if uid is null then raise exception 'Please sign in.'; end if;
  if not exists (select 1 from lms_bundles where slug = p_bundle and is_published) then raise exception 'Bundle not found.'; end if;
  if p_method not in ('mpesa', 'card', 'paystack') then raise exception 'Unknown payment method.'; end if;
  if p_method = 'card' then
    v_code := left((regexp_match(upper(msg), '([A-Z0-9][A-Z0-9-]*[0-9][A-Z0-9-]*)'))[1], 40);
    if coalesce(char_length(v_code), 0) < 3 then raise exception 'Please paste your HustleSasa order number.'; end if;
  elsif p_method = 'paystack' then
    v_code := left(regexp_replace(upper(btrim(msg)), '[^A-Z0-9_-]', '', 'g'), 60);
    if coalesce(char_length(v_code), 0) < 6 then raise exception 'We couldn''t read your Paystack reference. Paste the reference from your Paystack receipt.'; end if;
  else
    select m[1] into v_code from regexp_matches(upper(msg), '\m([A-Z0-9]{10})\M', 'g') as m
      where m[1] ~ '[0-9]' and m[1] ~ '[A-Z]' limit 1;
    if v_code is null then
      raise exception 'We couldn''t find the M-Pesa code. Paste the whole M-Pesa message, or just the 10-character code (like SJK4AB12CD).';
    end if;
    v_amount := nullif(replace((regexp_match(upper(msg), 'KSHS?\.?\s*([0-9,]+)'))[1], ',', ''), '')::int;
  end if;
  if exists (select 1 from lms_payments where code = v_code) then raise exception 'That payment has already been sent to us.'; end if;
  if (select count(*) from lms_payments where user_id = uid and status = 'pending') >= 5 then
    raise exception 'You already have 5 payments waiting. We''ll check them soon.';
  end if;
  insert into lms_payments (user_id, email, kind, product, code, amount_kes, message, method)
    values (uid, coalesce(lms_email(), ''), 'bundle', p_bundle, v_code, v_amount, msg, p_method)
    returning * into r;
  return json_build_object('id', r.id, 'kind', r.kind, 'code', r.code, 'amount_kes', r.amount_kes, 'status', r.status);
end $$;

grant execute on function public.lms_submit_payment(uuid, text, int, text) to authenticated;
grant execute on function public.lms_submit_curriculum_payment(text, text, text) to authenticated;
grant execute on function public.lms_submit_bundle_payment(text, text, text) to authenticated;
