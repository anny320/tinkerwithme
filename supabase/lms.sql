-- Tinkerwith courses (learn.html, course.html, teach.html).
-- Run once in Supabase: SQL Editor → New query → paste → Run.
-- Safe to run again: it keeps all courses, lessons and progress.
--
-- Sign-in is Clerk. Supabase trusts Clerk's session token (Authentication →
-- Third-Party Auth → Clerk), so auth.jwt()->>'sub' is the Clerk user id and
-- auth.jwt()->>'email' is their email (added in Clerk → Sessions →
-- Customize session token: { "email": "{{user.primary_email_address}}" }).
--
-- Who can do what:
--   * Anyone can see published courses and their lesson titles.
--   * Signed-in students read lessons, take quizzes and record progress only
--     through the lms_* functions below, and only for courses they're enrolled in.
--     Quiz answers never leave the database; quizzes are marked here.
--   * Free courses: students enrol themselves. Paid courses: an admin enrols
--     them by email (works before they've signed up — it waits until they do).
--   * Admins (rows in lms_admins) can do everything from teach.html.
--
-- Make yourself admin after you first sign in on teach.html (it shows your id):
--   insert into public.lms_admins (user_id, note) values ('user_…', 'Anne');

create extension if not exists pgcrypto;

-- ── Tables ─────────────────────────────────────────────────────────────

create table if not exists public.lms_admins (
  user_id    text primary key,
  note       text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.lms_profiles (
  user_id      text primary key,
  email        text not null default '',
  full_name    text not null default '',
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create table if not exists public.lms_courses (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 60),
  title        text not null check (char_length(title) between 1 and 120),
  summary      text not null default '',
  description  text not null default '',   -- markdown
  age_range    text not null default '',
  cover_url    text not null default '',
  price_kes    int  not null default 0 check (price_kes >= 0),   -- 0 = free
  is_published boolean not null default false,
  position     int  not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.lms_lessons (
  id         uuid primary key default gen_random_uuid(),
  course_id  uuid not null references public.lms_courses(id) on delete cascade,
  position   int  not null default 0,
  section    text not null default '',     -- groups lessons, e.g. "Lesson 1: Teach the Robot"
  title      text not null check (char_length(title) between 1 and 160),
  body       text not null default '',     -- markdown
  video_url  text not null default '',     -- YouTube link, optional
  -- [{"q": "Question?", "options": ["A", "B", "C"], "answer": 1}, …]
  quiz       jsonb not null default '[]'::jsonb check (jsonb_typeof(quiz) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists lms_lessons_course on public.lms_lessons (course_id, position);
-- Free preview: anyone can open this lesson before buying the course.
alter table public.lms_lessons add column if not exists is_preview boolean not null default false;
-- Families outside Kenya: a USD price to show, and a HustleSasa card-payment
-- link (set its redirect to course.html?c=<slug>&paid=card).
alter table public.lms_courses add column if not exists price_usd int check (price_usd is null or price_usd >= 0);
alter table public.lms_courses add column if not exists card_url text not null default '' check (card_url = '' or card_url ~ '^https://');
-- Launch offer: a lower price until offer_ends_at, then price_kes/price_usd again.
alter table public.lms_courses add column if not exists offer_price_kes int check (offer_price_kes is null or offer_price_kes > 0);
alter table public.lms_courses add column if not exists offer_price_usd int check (offer_price_usd is null or offer_price_usd > 0);
alter table public.lms_courses add column if not exists offer_ends_at timestamptz;

create table if not exists public.lms_enrollments (
  user_id    text not null,
  course_id  uuid not null references public.lms_courses(id) on delete cascade,
  source     text not null default 'self' check (source in ('self', 'admin', 'import')),
  created_at timestamptz not null default now(),
  primary key (user_id, course_id)
);
create index if not exists lms_enrollments_course on public.lms_enrollments (course_id);
-- Paid courses unlock for 12 months; null = no end (free courses, and everyone
-- enrolled before access limits were added keeps lifetime access).
alter table public.lms_enrollments add column if not exists expires_at timestamptz;

-- Enrolments made by email for people who haven't signed up yet.
create table if not exists public.lms_pending_enrollments (
  email      text not null check (email = lower(email) and email like '%@%'),
  course_id  uuid not null references public.lms_courses(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (email, course_id)
);

create table if not exists public.lms_progress (
  user_id      text not null,
  lesson_id    uuid not null references public.lms_lessons(id) on delete cascade,
  course_id    uuid not null references public.lms_courses(id) on delete cascade,
  completed_at timestamptz,
  quiz_score   int,
  quiz_total   int,
  updated_at   timestamptz not null default now(),
  primary key (user_id, lesson_id)
);
create index if not exists lms_progress_course on public.lms_progress (user_id, course_id);

-- Keep updated_at fresh on edits.
create or replace function public.lms_touch() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists lms_courses_touch on public.lms_courses;
create trigger lms_courses_touch before update on public.lms_courses for each row execute function public.lms_touch();
drop trigger if exists lms_lessons_touch on public.lms_lessons;
create trigger lms_lessons_touch before update on public.lms_lessons for each row execute function public.lms_touch();

-- ── Helpers ────────────────────────────────────────────────────────────

create or replace function public.lms_uid() returns text
language sql stable as $$ select nullif(auth.jwt() ->> 'sub', '') $$;

create or replace function public.lms_email() returns text
language sql stable as $$ select nullif(lower(btrim(auth.jwt() ->> 'email')), '') $$;

create or replace function public.lms_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from lms_admins where user_id = lms_uid())
$$;

create or replace function public.lms_can_access(p_course uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select lms_is_admin() or exists (
    select 1 from lms_enrollments e join lms_courses c on c.id = e.course_id
    where e.user_id = lms_uid() and e.course_id = p_course and c.is_published
      and (e.expires_at is null or e.expires_at > now()))
$$;

-- A lesson can be opened by students with access, and by anyone if it's a free preview.
create or replace function public.lms_can_open_lesson(p_lesson uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from lms_lessons l join lms_courses c on c.id = l.course_id
    where l.id = p_lesson and (lms_can_access(l.course_id) or (l.is_preview and c.is_published)))
$$;

-- When a new enrolment in this course ends: 12 months for paid courses, never for free ones.
create or replace function public.lms_access_end(p_course uuid) returns timestamptz
language sql stable security definer set search_path = public as $$
  select case when price_kes > 0 then now() + interval '12 months' end from lms_courses where id = p_course
$$;

-- ── Row-level security ─────────────────────────────────────────────────
-- Students never touch these tables directly except to read their own rows;
-- everything else goes through the security-definer functions below.

alter table public.lms_admins              enable row level security;
alter table public.lms_profiles            enable row level security;
alter table public.lms_courses             enable row level security;
alter table public.lms_lessons             enable row level security;
alter table public.lms_enrollments         enable row level security;
alter table public.lms_pending_enrollments enable row level security;
alter table public.lms_progress            enable row level security;

grant select on public.lms_courses to anon;
grant select, insert, update, delete on
  public.lms_courses, public.lms_lessons, public.lms_enrollments,
  public.lms_pending_enrollments, public.lms_progress, public.lms_profiles
  to authenticated;
grant select on public.lms_admins to authenticated;
revoke insert, update, delete on public.lms_admins from anon, authenticated;

do $$
declare t text;
begin
  -- Drop and recreate so re-running the file picks up changes.
  for t in select unnest(array['lms_admins','lms_profiles','lms_courses','lms_lessons',
                               'lms_enrollments','lms_pending_enrollments','lms_progress']) loop
    execute format('drop policy if exists "admin all" on public.%I', t);
    execute format('drop policy if exists "own rows" on public.%I', t);
  end loop;
  drop policy if exists "published courses" on public.lms_courses;
end $$;

create policy "published courses" on public.lms_courses for select to anon, authenticated using (is_published);
create policy "admin all" on public.lms_courses             for all to authenticated using (lms_is_admin()) with check (lms_is_admin());
create policy "admin all" on public.lms_lessons             for all to authenticated using (lms_is_admin()) with check (lms_is_admin());
create policy "admin all" on public.lms_enrollments         for all to authenticated using (lms_is_admin()) with check (lms_is_admin());
create policy "admin all" on public.lms_pending_enrollments for all to authenticated using (lms_is_admin()) with check (lms_is_admin());
create policy "admin all" on public.lms_progress            for all to authenticated using (lms_is_admin()) with check (lms_is_admin());
create policy "admin all" on public.lms_profiles            for all to authenticated using (lms_is_admin()) with check (lms_is_admin());
create policy "admin all" on public.lms_admins              for select to authenticated using (lms_is_admin());
create policy "own rows" on public.lms_enrollments for select to authenticated using (user_id = lms_uid());
create policy "own rows" on public.lms_progress    for select to authenticated using (user_id = lms_uid());
create policy "own rows" on public.lms_profiles    for select to authenticated using (user_id = lms_uid());

-- ── Student functions ──────────────────────────────────────────────────

-- Called on every signed-in page load: saves the profile, turns any
-- enrolments waiting on this email into real ones, and says if you're admin.
create or replace function public.lms_hello(p_name text default '')
returns json language plpgsql security definer set search_path = public as $$
declare uid text := lms_uid(); em text := lms_email();
begin
  if uid is null then raise exception 'Please sign in.'; end if;
  insert into lms_profiles (user_id, email, full_name)
    values (uid, coalesce(em, ''), left(btrim(coalesce(p_name, '')), 80))
  on conflict (user_id) do update set
    email = coalesce(em, lms_profiles.email),
    full_name = case when btrim(coalesce(p_name, '')) = '' then lms_profiles.full_name else left(btrim(p_name), 80) end,
    last_seen_at = now();
  if em is not null then
    insert into lms_enrollments (user_id, course_id, source, expires_at)
      select uid, course_id, 'admin', lms_access_end(course_id) from lms_pending_enrollments where email = em
    on conflict do nothing;
    delete from lms_pending_enrollments where email = em;
  end if;
  return json_build_object('user_id', uid, 'email', em, 'is_admin', lms_is_admin());
end $$;

-- Courses I'm enrolled in, with progress.
create or replace function public.lms_my_courses()
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(x order by x.last_activity desc nulls last, x.title), '[]'::json) from (
    select c.slug, c.title, c.summary, c.age_range, c.cover_url,
           (select count(*) from lms_lessons l where l.course_id = c.id) as lessons,
           (select count(*) from lms_progress p where p.course_id = c.id and p.user_id = e.user_id and p.completed_at is not null) as done,
           (select max(p.updated_at) from lms_progress p where p.course_id = c.id and p.user_id = e.user_id) as last_activity,
           e.expires_at, coalesce(e.expires_at <= now(), false) as expired
    from lms_enrollments e join lms_courses c on c.id = e.course_id
    where e.user_id = lms_uid() and c.is_published
  ) x
$$;

-- A course page: details, lesson outline, and (if signed in) enrolment and progress.
create or replace function public.lms_course(p_slug text)
returns json language plpgsql stable security definer set search_path = public as $$
declare c lms_courses; uid text := lms_uid(); enrolled boolean; ends timestamptz; offer boolean;
begin
  select * into c from lms_courses where slug = p_slug and (is_published or lms_is_admin());
  if not found then return null; end if;
  offer := c.price_kes > 0 and c.offer_price_kes is not null and c.offer_ends_at > now();
  select true, expires_at into enrolled, ends from lms_enrollments where user_id = uid and course_id = c.id;
  enrolled := coalesce(enrolled, false);
  return json_build_object(
    'id', c.id, 'slug', c.slug, 'title', c.title, 'summary', c.summary, 'description', c.description,
    'age_range', c.age_range, 'cover_url', c.cover_url, 'is_published', c.is_published, 'card_url', c.card_url,
    -- price_kes/price_usd are what to pay today; regular_* is the normal price while a launch offer runs.
    'price_kes', case when offer then c.offer_price_kes else c.price_kes end,
    'price_usd', case when offer then c.offer_price_usd else c.price_usd end,
    'regular_kes', case when offer then c.price_kes end, 'regular_usd', case when offer then c.price_usd end,
    'offer_ends_at', case when offer then c.offer_ends_at end,
    'enrolled', enrolled, 'can_access', lms_can_access(c.id) or (lms_is_admin()),
    'expires_at', ends, 'expired', coalesce(ends <= now(), false),
    'lessons', coalesce((
      select json_agg(json_build_object(
        'id', l.id, 'section', l.section, 'title', l.title, 'preview', l.is_preview,
        'has_video', l.video_url <> '', 'quiz_count', jsonb_array_length(l.quiz),
        'done', p.completed_at is not null, 'quiz_score', p.quiz_score, 'quiz_total', p.quiz_total)
        order by l.position, l.created_at)
      from lms_lessons l left join lms_progress p on p.lesson_id = l.id and p.user_id = uid
      where l.course_id = c.id), '[]'::json));
end $$;

create or replace function public.lms_enroll_free(p_course uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if lms_uid() is null then raise exception 'Please sign in.'; end if;
  if not exists (select 1 from lms_courses where id = p_course and is_published and price_kes = 0) then
    raise exception 'This course needs enrolment by Tinkerwith.';
  end if;
  insert into lms_enrollments (user_id, course_id, source) values (lms_uid(), p_course, 'self') on conflict do nothing;
end $$;

-- One lesson's content. Quiz questions come without their answers.
create or replace function public.lms_lesson(p_lesson uuid)
returns json language plpgsql stable security definer set search_path = public as $$
declare l lms_lessons; p lms_progress;
begin
  select * into l from lms_lessons where id = p_lesson;
  if not found or not lms_can_open_lesson(l.id) then raise exception 'You don''t have access to this lesson.'; end if;
  select * into p from lms_progress where user_id = lms_uid() and lesson_id = l.id;
  return json_build_object(
    'id', l.id, 'course_id', l.course_id, 'section', l.section, 'title', l.title, 'body', l.body, 'video_url', l.video_url,
    'quiz', coalesce((select json_agg(json_build_object('q', q->>'q', 'options', q->'options') order by n)
                      from jsonb_array_elements(l.quiz) with ordinality as t(q, n)), '[]'::json),
    'done', p.completed_at is not null, 'quiz_score', p.quiz_score, 'quiz_total', p.quiz_total);
end $$;

-- Mark a lesson without a quiz as done.
create or replace function public.lms_complete_lesson(p_lesson uuid)
returns void language plpgsql security definer set search_path = public as $$
declare l lms_lessons;
begin
  select * into l from lms_lessons where id = p_lesson;
  if lms_uid() is null then raise exception 'Sign in to save your progress.'; end if;
  if not found or not lms_can_open_lesson(l.id) then raise exception 'You don''t have access to this lesson.'; end if;
  if jsonb_array_length(l.quiz) > 0 then raise exception 'Pass the quiz to finish this lesson.'; end if;
  insert into lms_progress (user_id, lesson_id, course_id, completed_at)
    values (lms_uid(), l.id, l.course_id, now())
  on conflict (user_id, lesson_id) do update set completed_at = coalesce(lms_progress.completed_at, now()), updated_at = now();
end $$;

-- Mark a quiz. 60% or more completes the lesson; the best score is kept.
-- Returns which questions were right, but not the right answers.
create or replace function public.lms_submit_quiz(p_lesson uuid, p_answers int[])
returns json language plpgsql security definer set search_path = public as $$
declare l lms_lessons; total int; score int := 0; correct boolean[] := '{}'; q jsonb; i int := 0; ok boolean; passed boolean;
begin
  select * into l from lms_lessons where id = p_lesson;
  if lms_uid() is null then raise exception 'Sign in to check your answers and save your progress.'; end if;
  if not found or not lms_can_open_lesson(l.id) then raise exception 'You don''t have access to this lesson.'; end if;
  total := jsonb_array_length(l.quiz);
  if total = 0 then raise exception 'This lesson has no quiz.'; end if;
  for q in select value from jsonb_array_elements(l.quiz) loop
    i := i + 1;
    ok := p_answers is not null and array_length(p_answers, 1) >= i and p_answers[i] = (q->>'answer')::int;
    correct := correct || ok;
    if ok then score := score + 1; end if;
  end loop;
  passed := score * 100 >= total * 60;
  insert into lms_progress (user_id, lesson_id, course_id, completed_at, quiz_score, quiz_total)
    values (lms_uid(), l.id, l.course_id, case when passed then now() end, score, total)
  on conflict (user_id, lesson_id) do update set
    quiz_score = greatest(coalesce(lms_progress.quiz_score, 0), score),
    quiz_total = total,
    completed_at = coalesce(lms_progress.completed_at, case when passed then now() end),
    updated_at = now();
  return json_build_object('score', score, 'total', total, 'passed', passed, 'correct', to_json(correct));
end $$;

-- ── Admin functions ────────────────────────────────────────────────────

-- Everyone who has signed in, their courses and progress, plus waiting enrolments.
create or replace function public.lms_admin_students()
returns json language plpgsql stable security definer set search_path = public as $$
begin
  if not lms_is_admin() then raise exception 'Admins only.'; end if;
  return json_build_object(
    'students', coalesce((select json_agg(json_build_object(
        'user_id', pr.user_id, 'email', pr.email, 'full_name', pr.full_name,
        'created_at', pr.created_at, 'last_seen_at', pr.last_seen_at,
        'courses', coalesce((select json_agg(json_build_object(
            'course_id', c.id, 'title', c.title, 'source', e.source, 'enrolled_at', e.created_at, 'expires_at', e.expires_at,
            'lessons', (select count(*) from lms_lessons l where l.course_id = c.id),
            'done', (select count(*) from lms_progress p where p.user_id = pr.user_id and p.course_id = c.id and p.completed_at is not null))
            order by c.position, c.title)
          from lms_enrollments e join lms_courses c on c.id = e.course_id where e.user_id = pr.user_id), '[]'::json))
        order by pr.last_seen_at desc)
      from lms_profiles pr), '[]'::json),
    'pending', coalesce((select json_agg(json_build_object('email', pe.email, 'course_id', pe.course_id, 'title', c.title, 'created_at', pe.created_at)
        order by pe.created_at desc)
      from lms_pending_enrollments pe join lms_courses c on c.id = pe.course_id), '[]'::json));
end $$;

-- Give a signed-up user access to a course: a new enrolment, or 12 more
-- months on a time-limited one. Returns 'enrolled', 'renewed' or 'already'
-- (lifetime access). Only called from other functions here.
create or replace function public.lms_grant_access(p_uid text, p_course uuid)
returns text language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from lms_enrollments where user_id = p_uid and course_id = p_course) then
    update lms_enrollments set expires_at = greatest(expires_at, now()) + interval '12 months'
      where user_id = p_uid and course_id = p_course and expires_at is not null;
    return case when found then 'renewed' else 'already' end;
  end if;
  insert into lms_enrollments (user_id, course_id, source, expires_at) values (p_uid, p_course, 'admin', lms_access_end(p_course));
  return 'enrolled';
end $$;
revoke all on function public.lms_grant_access(text, uuid) from public, anon, authenticated;

-- Enrol someone by email. Enrols them now if they've signed in before,
-- otherwise the enrolment waits until they sign in with that email.
-- Enrolling someone already enrolled renews a time-limited enrolment for
-- another 12 months from today (or from its end, if that's later).
create or replace function public.lms_admin_enroll(p_email text, p_course uuid)
returns text language plpgsql security definer set search_path = public as $$
declare em text := lower(btrim(coalesce(p_email, ''))); uid text;
begin
  if not lms_is_admin() then raise exception 'Admins only.'; end if;
  if em !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'That doesn''t look like an email address.'; end if;
  if not exists (select 1 from lms_courses where id = p_course) then raise exception 'Course not found.'; end if;
  select user_id into uid from lms_profiles where email = em order by last_seen_at desc limit 1;
  if uid is not null then
    return lms_grant_access(uid, p_course);
  end if;
  insert into lms_pending_enrollments (email, course_id) values (em, p_course) on conflict do nothing;
  return 'pending';
end $$;

revoke all on function
  public.lms_hello(text), public.lms_my_courses(), public.lms_course(text), public.lms_enroll_free(uuid),
  public.lms_lesson(uuid), public.lms_complete_lesson(uuid), public.lms_submit_quiz(uuid, int[]),
  public.lms_admin_students(), public.lms_admin_enroll(text, uuid)
  from public;
grant execute on function public.lms_course(text), public.lms_lesson(uuid) to anon, authenticated;
grant execute on function
  public.lms_hello(text), public.lms_my_courses(), public.lms_enroll_free(uuid),
  public.lms_lesson(uuid), public.lms_complete_lesson(uuid), public.lms_submit_quiz(uuid, int[]),
  public.lms_admin_students(), public.lms_admin_enroll(text, uuid)
  to authenticated;

-- True when the first folder of a storage path is a course the user can open.
create or replace function public.lms_can_access_folder(p_name text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare f text := split_part(p_name, '/', 1);
begin
  return f ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' and lms_can_access(f::uuid);
end $$;

-- ── Lesson images ──────────────────────────────────────────────────────
-- A public bucket for pictures in lessons; only admins can upload or delete.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public) values ('lms-media', 'lms-media', true) on conflict (id) do nothing;
    drop policy if exists "lms-media admin write" on storage.objects;
    create policy "lms-media admin write" on storage.objects for all to authenticated
      using (bucket_id = 'lms-media' and public.lms_is_admin())
      with check (bucket_id = 'lms-media' and public.lms_is_admin());

    -- Private course downloads (e.g. the full curriculum PDF), stored as
    -- lms-files/<course id>/<file>. Admins manage them; a student can read a
    -- course's files only while they have access to that course. Pages fetch
    -- them through short-lived signed links.
    insert into storage.buckets (id, name, public, file_size_limit) values ('lms-files', 'lms-files', false, 52428800)
      on conflict (id) do update set public = false;
    drop policy if exists "lms-files admin write" on storage.objects;
    create policy "lms-files admin write" on storage.objects for all to authenticated
      using (bucket_id = 'lms-files' and public.lms_is_admin())
      with check (bucket_id = 'lms-files' and public.lms_is_admin());
    drop policy if exists "lms-files student read" on storage.objects;
    create policy "lms-files student read" on storage.objects for select to authenticated
      using (bucket_id = 'lms-files' and public.lms_can_access_folder(name));
  end if;
end $$;

-- ── M-Pesa payments ────────────────────────────────────────────────────
-- Parents pay by Till, then paste the M-Pesa SMS (or just its code) on the
-- course page. It waits here until an admin checks it against the M-Pesa
-- statement in teach.html and approves it, which unlocks or renews the
-- course. Trainer hours are approved the same way (no course access change).

create table if not exists public.lms_payments (
  id          uuid primary key default gen_random_uuid(),
  user_id     text not null,
  email       text not null default '',
  course_id   uuid references public.lms_courses(id) on delete set null,
  kind        text not null check (kind in ('course', 'renewal', 'trainer')),
  hours       int  check (hours between 1 and 10),
  code        text not null unique,
  amount_kes  int,
  message     text not null default '' check (char_length(message) <= 600),
  status      text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  note        text not null default '',
  created_at  timestamptz not null default now(),
  decided_at  timestamptz
);
create index if not exists lms_payments_status on public.lms_payments (status, created_at desc);
-- M-Pesa codes are 10 characters; card payments (HustleSasa) store the order number.
alter table public.lms_payments add column if not exists method text not null default 'mpesa' check (method in ('mpesa', 'card'));
alter table public.lms_payments drop constraint if exists lms_payments_code_check;
alter table public.lms_payments drop constraint if exists lms_payments_code_ok;
alter table public.lms_payments add constraint lms_payments_code_ok check (
  (method = 'mpesa' and code ~ '^[A-Z0-9]{10}$') or (method = 'card' and code ~ '^[A-Z0-9-]{3,40}$'));
-- Curriculum purchases are for a live course in premium_courses.json (its id), not an online course.
alter table public.lms_payments add column if not exists product text check (product is null or product ~ '^[a-z0-9]+(-[a-z0-9]+)*$');
alter table public.lms_payments drop constraint if exists lms_payments_kind_check;
alter table public.lms_payments add constraint lms_payments_kind_check check (kind in ('course', 'renewal', 'trainer', 'curriculum'));

alter table public.lms_payments enable row level security;
revoke all on public.lms_payments from anon, authenticated;
grant select on public.lms_payments to authenticated;
drop policy if exists "own rows" on public.lms_payments;
drop policy if exists "admin all" on public.lms_payments;
create policy "own rows"  on public.lms_payments for select to authenticated using (user_id = lms_uid());
create policy "admin all" on public.lms_payments for all    to authenticated using (lms_is_admin()) with check (lms_is_admin());

-- Trainer support per hour. Keep in step with TRAINER_KES / TRAINER_USD in course.html.
create or replace function public.lms_trainer_rate() returns int language sql immutable as $$ select 3000 $$;
create or replace function public.lms_trainer_rate_usd() returns int language sql immutable as $$ select 39 $$;

-- Submit a payment for this course (or p_hours of trainer time).
-- M-Pesa: finds the 10-character code and the amount in whatever was pasted.
-- Card (HustleSasa): the order number.
drop function if exists public.lms_submit_payment(uuid, text, int);
create or replace function public.lms_submit_payment(p_course uuid, p_message text, p_hours int default null, p_method text default 'mpesa')
returns json language plpgsql security definer set search_path = public as $$
declare
  uid text := lms_uid(); msg text := left(btrim(coalesce(p_message, '')), 600);
  v_code text; v_amount int; v_kind text; c lms_courses; r lms_payments;
begin
  if uid is null then raise exception 'Please sign in.'; end if;
  if p_method not in ('mpesa', 'card') then raise exception 'Unknown payment method.'; end if;
  select * into c from lms_courses where id = p_course and is_published;
  if not found then raise exception 'Course not found.'; end if;
  if p_method = 'card' then
    -- The first word with a digit in it, e.g. "Order #HS-48213" → HS-48213.
    v_code := left((regexp_match(upper(msg), '([A-Z0-9][A-Z0-9-]*[0-9][A-Z0-9-]*)'))[1], 40);
    if coalesce(char_length(v_code), 0) < 3 then raise exception 'Please paste your HustleSasa order number.'; end if;
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

-- My payments for one course, newest first.
create or replace function public.lms_my_payments(p_course uuid)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object('kind', kind, 'hours', hours, 'code', code, 'amount_kes', amount_kes, 'method', method,
           'status', status, 'note', note, 'created_at', created_at) order by created_at desc), '[]'::json)
  from (select * from lms_payments where user_id = lms_uid() and course_id = p_course order by created_at desc limit 10) p
$$;

-- Everything waiting for approval, plus the 30 most recent decisions.
create or replace function public.lms_admin_payments()
returns json language plpgsql stable security definer set search_path = public as $$
begin
  if not lms_is_admin() then raise exception 'Admins only.'; end if;
  return coalesce((select json_agg(x order by x.pending desc, x.created_at desc) from (
    select p.id, p.kind, p.hours, p.code, p.amount_kes, p.message, p.status, p.note, p.created_at, p.decided_at, p.method,
           p.status = 'pending' as pending, p.email, coalesce(pr.full_name, '') as full_name, p.product,
           case when p.kind = 'curriculum' then 'Curriculum: ' || p.product else c.title end as title,
           case p.kind when 'trainer' then p.hours * lms_trainer_rate() when 'curriculum' then lms_curriculum_price() else case when c.offer_price_kes is not null and p.created_at < c.offer_ends_at then c.offer_price_kes else c.price_kes end end as expected_kes,
           case p.kind when 'trainer' then p.hours * lms_trainer_rate_usd() when 'curriculum' then lms_curriculum_price_usd() else case when c.offer_price_usd is not null and p.created_at < c.offer_ends_at then c.offer_price_usd else c.price_usd end end as expected_usd
    from lms_payments p left join lms_courses c on c.id = p.course_id left join lms_profiles pr on pr.user_id = p.user_id
    where p.status = 'pending' or p.id in (select id from lms_payments where status <> 'pending' order by decided_at desc limit 30)
  ) x), '[]'::json);
end $$;

-- ── Teach-it-yourself curriculums ──────────────────────────────────────
-- The full facilitator curriculum of a live course, sold per course to one
-- teacher or family (curriculum.html). The PDF lives in the private lms-files
-- bucket at curriculum/<premium course id>/<file>; buyers can read it once an
-- admin approves their payment.

create table if not exists public.lms_curriculum_access (
  user_id     text not null,
  premium_id  text not null check (premium_id ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  created_at  timestamptz not null default now(),
  primary key (user_id, premium_id)
);
alter table public.lms_curriculum_access enable row level security;
revoke all on public.lms_curriculum_access from anon, authenticated;
grant select, delete on public.lms_curriculum_access to authenticated;
drop policy if exists "own rows" on public.lms_curriculum_access;
drop policy if exists "admin all" on public.lms_curriculum_access;
create policy "own rows"  on public.lms_curriculum_access for select to authenticated using (user_id = lms_uid());
create policy "admin all" on public.lms_curriculum_access for all    to authenticated using (lms_is_admin()) with check (lms_is_admin());

-- Price of one curriculum. Keep in step with curriculum_price in premium_courses.json.
create or replace function public.lms_curriculum_price() returns int language sql immutable as $$ select 1500 $$;
create or replace function public.lms_curriculum_price_usd() returns int language sql immutable as $$ select 10 $$;

create or replace function public.lms_has_curriculum(p_premium text) returns boolean
language sql stable security definer set search_path = public as $$
  select lms_is_admin() or exists (select 1 from lms_curriculum_access where user_id = lms_uid() and premium_id = p_premium)
$$;

-- Submit a payment for one curriculum (M-Pesa code or card order number).
create or replace function public.lms_submit_curriculum_payment(p_premium text, p_message text, p_method text default 'mpesa')
returns json language plpgsql security definer set search_path = public as $$
declare uid text := lms_uid(); msg text := left(btrim(coalesce(p_message, '')), 600); v_code text; v_amount int; r lms_payments;
begin
  if uid is null then raise exception 'Please sign in.'; end if;
  if coalesce(p_premium, '') !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then raise exception 'Curriculum not found.'; end if;
  if p_method not in ('mpesa', 'card') then raise exception 'Unknown payment method.'; end if;
  if p_method = 'card' then
    v_code := left((regexp_match(upper(msg), '([A-Z0-9][A-Z0-9-]*[0-9][A-Z0-9-]*)'))[1], 40);
    if coalesce(char_length(v_code), 0) < 3 then raise exception 'Please paste your HustleSasa order number.'; end if;
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

-- Whether I have this curriculum, and my payments for it.
create or replace function public.lms_my_curriculum(p_premium text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object('has_access', lms_has_curriculum(p_premium),
    'payments', coalesce((select json_agg(json_build_object('kind', kind, 'code', code, 'amount_kes', amount_kes, 'method', method,
        'status', status, 'note', note, 'created_at', created_at) order by created_at desc)
      from (select * from lms_payments where user_id = lms_uid() and kind = 'curriculum' and product = p_premium order by created_at desc limit 10) p), '[]'::json))
$$;

-- Curriculum PDFs (lms-files/curriculum/<premium course id>/<file>) are readable by their buyers.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    drop policy if exists "lms-files curriculum read" on storage.objects;
    create policy "lms-files curriculum read" on storage.objects for select to authenticated
      using (bucket_id = 'lms-files' and split_part(name, '/', 1) = 'curriculum' and public.lms_has_curriculum(split_part(name, '/', 2)));
  end if;
end $$;

revoke all on function public.lms_submit_curriculum_payment(text, text, text), public.lms_my_curriculum(text) from public;
grant execute on function public.lms_submit_curriculum_payment(text, text, text), public.lms_my_curriculum(text) to authenticated;

-- Approve (unlocks or renews the course; trainer hours just get marked paid) or reject with a note the parent sees.
create or replace function public.lms_admin_decide_payment(p_id uuid, p_approve boolean, p_note text default '')
returns text language plpgsql security definer set search_path = public as $$
declare p lms_payments; res text := 'rejected';
begin
  if not lms_is_admin() then raise exception 'Admins only.'; end if;
  select * into p from lms_payments where id = p_id for update;
  if not found then raise exception 'Payment not found.'; end if;
  if p.status <> 'pending' then raise exception 'This payment was already %.', p.status; end if;
  if p_approve then
    res := 'approved';
    if p.kind = 'curriculum' then
      insert into lms_curriculum_access (user_id, premium_id) values (p.user_id, p.product) on conflict do nothing;
    elsif p.kind <> 'trainer' then
      if p.course_id is null then raise exception 'That course no longer exists.'; end if;
      res := lms_grant_access(p.user_id, p.course_id);
    end if;
  end if;
  update lms_payments set status = case when p_approve then 'approved' else 'rejected' end,
    note = left(btrim(coalesce(p_note, '')), 300), decided_at = now() where id = p_id;
  return res;
end $$;

revoke all on function public.lms_submit_payment(uuid, text, int, text), public.lms_my_payments(uuid),
  public.lms_admin_payments(), public.lms_admin_decide_payment(uuid, boolean, text) from public;
grant execute on function public.lms_submit_payment(uuid, text, int, text), public.lms_my_payments(uuid),
  public.lms_admin_payments(), public.lms_admin_decide_payment(uuid, boolean, text) to authenticated;

-- ── Leads: enquiries from the courses page ──────────────────────────────
-- Parents pick one or more live courses and send an enquiry. Anyone may
-- submit (through lms_submit_lead only); only admins can read and update
-- them, in teach.html → Leads.

create table if not exists public.lms_leads (
  id               uuid primary key default gen_random_uuid(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  source           text not null default 'courses' check (char_length(source) <= 40),
  parent_name      text not null check (char_length(parent_name) between 1 and 80),
  whatsapp         text not null check (whatsapp ~ '^\+?[0-9 ]{7,20}$'),
  email            text not null check (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' and char_length(email) <= 120),
  child_age        text not null check (char_length(child_age) between 1 and 20),
  mode             text not null check (mode in ('online-1:1', 'online-group', 'in-person', 'not-sure')),
  preferred_dates  text not null check (char_length(preferred_dates) between 1 and 120),
  courses          jsonb not null check (jsonb_typeof(courses) = 'array' and jsonb_array_length(courses) between 1 and 20 and length(courses::text) <= 6000),
  extras           jsonb not null default '{}'::jsonb check (jsonb_typeof(extras) = 'object' and length(extras::text) <= 600),
  message          text not null default '' check (char_length(message) <= 1000),
  status           text not null default 'new' check (status in ('new', 'contacted', 'booked', 'not_now')),
  notes            text not null default '' check (char_length(notes) <= 2000)
);
create index if not exists lms_leads_created on public.lms_leads (created_at desc);
drop trigger if exists lms_leads_touch on public.lms_leads;
create trigger lms_leads_touch before update on public.lms_leads for each row execute function public.lms_touch();

alter table public.lms_leads enable row level security;
revoke all on public.lms_leads from anon, authenticated;
grant select, update, delete on public.lms_leads to authenticated;
drop policy if exists "admin all" on public.lms_leads;
create policy "admin all" on public.lms_leads for all to authenticated using (lms_is_admin()) with check (lms_is_admin());

-- Save an enquiry. p is the form as JSON. "website" is a hidden trap field:
-- people never fill it, bots do, so those are quietly dropped.
create or replace function public.lms_submit_lead(p jsonb)
returns text language plpgsql security definer set search_path = public as $$
declare wa text := regexp_replace(btrim(coalesce(p->>'whatsapp', '')), '[^0-9+ ]', '', 'g'); id uuid;
begin
  if coalesce(p->>'website', '') <> '' then return 'ok'; end if;
  if (select count(*) from lms_leads where created_at > now() - interval '1 minute') >= 20
     or (select count(*) from lms_leads where whatsapp = wa and created_at > now() - interval '1 hour') >= 3 then
    raise exception 'We''ve received your enquiry already. We''ll be in touch soon, or message us on WhatsApp.';
  end if;
  insert into lms_leads (source, parent_name, whatsapp, email, child_age, mode, preferred_dates, courses, extras, message)
  values (left(coalesce(p->>'source', 'courses'), 40), btrim(p->>'parent_name'), wa, lower(btrim(p->>'email')),
          btrim(p->>'child_age'), p->>'mode', btrim(p->>'preferred_dates'),
          coalesce(p->'courses', '[]'::jsonb), coalesce(p->'extras', '{}'::jsonb), left(btrim(coalesce(p->>'message', '')), 1000))
  returning lms_leads.id into id;
  return 'ok';
exception when check_violation or not_null_violation then
  raise exception 'Please fill in every required field (name, WhatsApp number, email, child''s age, how you''d like to learn, preferred dates).';
end $$;
revoke all on function public.lms_submit_lead(jsonb) from public;
grant execute on function public.lms_submit_lead(jsonb) to anon, authenticated;
