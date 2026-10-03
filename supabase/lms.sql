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

create table if not exists public.lms_enrollments (
  user_id    text not null,
  course_id  uuid not null references public.lms_courses(id) on delete cascade,
  source     text not null default 'self' check (source in ('self', 'admin', 'import')),
  created_at timestamptz not null default now(),
  primary key (user_id, course_id)
);
create index if not exists lms_enrollments_course on public.lms_enrollments (course_id);

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
    where e.user_id = lms_uid() and e.course_id = p_course and c.is_published)
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
    insert into lms_enrollments (user_id, course_id, source)
      select uid, course_id, 'admin' from lms_pending_enrollments where email = em
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
           (select max(p.updated_at) from lms_progress p where p.course_id = c.id and p.user_id = e.user_id) as last_activity
    from lms_enrollments e join lms_courses c on c.id = e.course_id
    where e.user_id = lms_uid() and c.is_published
  ) x
$$;

-- A course page: details, lesson outline, and (if signed in) enrolment and progress.
create or replace function public.lms_course(p_slug text)
returns json language plpgsql stable security definer set search_path = public as $$
declare c lms_courses; uid text := lms_uid(); enrolled boolean;
begin
  select * into c from lms_courses where slug = p_slug and (is_published or lms_is_admin());
  if not found then return null; end if;
  enrolled := uid is not null and exists (select 1 from lms_enrollments where user_id = uid and course_id = c.id);
  return json_build_object(
    'id', c.id, 'slug', c.slug, 'title', c.title, 'summary', c.summary, 'description', c.description,
    'age_range', c.age_range, 'cover_url', c.cover_url, 'price_kes', c.price_kes, 'is_published', c.is_published,
    'enrolled', enrolled, 'can_access', lms_can_access(c.id) or (lms_is_admin()),
    'lessons', coalesce((
      select json_agg(json_build_object(
        'id', l.id, 'section', l.section, 'title', l.title,
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
  if not found or not lms_can_access(l.course_id) then raise exception 'You don''t have access to this lesson.'; end if;
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
  if not found or not lms_can_access(l.course_id) then raise exception 'You don''t have access to this lesson.'; end if;
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
  if not found or not lms_can_access(l.course_id) then raise exception 'You don''t have access to this lesson.'; end if;
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
            'course_id', c.id, 'title', c.title, 'source', e.source, 'enrolled_at', e.created_at,
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

-- Enrol someone by email. Enrols them now if they've signed in before,
-- otherwise the enrolment waits until they sign in with that email.
create or replace function public.lms_admin_enroll(p_email text, p_course uuid)
returns text language plpgsql security definer set search_path = public as $$
declare em text := lower(btrim(coalesce(p_email, ''))); uid text;
begin
  if not lms_is_admin() then raise exception 'Admins only.'; end if;
  if em !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'That doesn''t look like an email address.'; end if;
  if not exists (select 1 from lms_courses where id = p_course) then raise exception 'Course not found.'; end if;
  select user_id into uid from lms_profiles where email = em order by last_seen_at desc limit 1;
  if uid is not null then
    insert into lms_enrollments (user_id, course_id, source) values (uid, p_course, 'admin') on conflict do nothing;
    return 'enrolled';
  end if;
  insert into lms_pending_enrollments (email, course_id) values (em, p_course) on conflict do nothing;
  return 'pending';
end $$;

revoke all on function
  public.lms_hello(text), public.lms_my_courses(), public.lms_course(text), public.lms_enroll_free(uuid),
  public.lms_lesson(uuid), public.lms_complete_lesson(uuid), public.lms_submit_quiz(uuid, int[]),
  public.lms_admin_students(), public.lms_admin_enroll(text, uuid)
  from public;
grant execute on function public.lms_course(text) to anon, authenticated;
grant execute on function
  public.lms_hello(text), public.lms_my_courses(), public.lms_enroll_free(uuid),
  public.lms_lesson(uuid), public.lms_complete_lesson(uuid), public.lms_submit_quiz(uuid, int[]),
  public.lms_admin_students(), public.lms_admin_enroll(text, uuid)
  to authenticated;

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
  end if;
end $$;
