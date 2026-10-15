-- ════════════════════════════════════════════════════════════════════════
-- Share-your-build: the engagement flywheel.
--
-- Kids (signed-in) submit a photo + caption of something they built. Every
-- submission is PRIVATE and PENDING until an admin approves it in teach.html —
-- nothing a child uploads is public until a human says so. Approved builds
-- show on the public Builds Wall (builds-wall.html) and feed the live counters.
--
-- Safe to run again. Depends on lms.sql (lms_uid(), lms_is_admin()).
-- ════════════════════════════════════════════════════════════════════════

-- ── Table ───────────────────────────────────────────────────────────────
create table if not exists public.tw_builds (
  id           uuid primary key default gen_random_uuid(),
  user_id      text not null,                          -- lms_uid() of the submitter
  first_name   text not null check (char_length(first_name) between 1 and 40),
  age          int  check (age between 3 and 18),
  caption      text not null default '' check (char_length(caption) <= 500),
  course_slug  text,                                   -- which course/project (optional)
  course_title text not null default '',               -- denormalised for the wall
  photo_path   text,                                   -- private path in tw-builds-pending
  photo_url    text,                                   -- public URL, set on approval
  status       text not null default 'pending' check (status in ('pending','approved','rejected')),
  note         text not null default '',               -- rejection reason / admin note
  featured     boolean not null default false,         -- pin to the top of the wall
  created_at   timestamptz not null default now(),
  decided_at   timestamptz
);
create index if not exists tw_builds_status on public.tw_builds (status, created_at desc);
create index if not exists tw_builds_user   on public.tw_builds (user_id, created_at desc);

alter table public.tw_builds enable row level security;

-- RLS: admins do anything; a submitter may create and read only their own rows.
-- The public wall is served by a SECURITY DEFINER function below (no anon
-- table policy), so unapproved rows and submitter identities never leak.
drop policy if exists "builds admin all" on public.tw_builds;
create policy "builds admin all" on public.tw_builds for all to authenticated
  using (public.lms_is_admin()) with check (public.lms_is_admin());

drop policy if exists "builds owner insert" on public.tw_builds;
create policy "builds owner insert" on public.tw_builds for insert to authenticated
  with check (user_id = public.lms_uid() and status = 'pending');

drop policy if exists "builds owner read" on public.tw_builds;
create policy "builds owner read" on public.tw_builds for select to authenticated
  using (user_id = public.lms_uid() or public.lms_is_admin());

drop policy if exists "builds owner attach photo" on public.tw_builds;
create policy "builds owner update own pending" on public.tw_builds for update to authenticated
  using (user_id = public.lms_uid() and status = 'pending')
  with check (user_id = public.lms_uid() and status = 'pending');

-- ── Storage buckets ───────────────────────────────────────────────────────
-- tw-builds-pending (private): submissions upload here as <uid>/<build id>.
--   Readable only by the owner and admins. Approval copies the photo across.
-- tw-builds-public (public): approved photos only; the wall reads these.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit)
      values ('tw-builds-pending', 'tw-builds-pending', false, 10485760)
      on conflict (id) do update set public = false;
    insert into storage.buckets (id, name, public, file_size_limit)
      values ('tw-builds-public', 'tw-builds-public', true, 10485760)
      on conflict (id) do nothing;

    -- Pending bucket: a signed-in user manages only their own folder; admins all.
    drop policy if exists "builds-pending owner" on storage.objects;
    create policy "builds-pending owner" on storage.objects for all to authenticated
      using (bucket_id = 'tw-builds-pending'
             and (public.lms_is_admin() or split_part(name, '/', 1) = public.lms_uid()))
      with check (bucket_id = 'tw-builds-pending'
             and (public.lms_is_admin() or split_part(name, '/', 1) = public.lms_uid()));

    -- Public bucket: only admins write (on approval); everyone reads (it is public).
    drop policy if exists "builds-public admin write" on storage.objects;
    create policy "builds-public admin write" on storage.objects for all to authenticated
      using (bucket_id = 'tw-builds-public' and public.lms_is_admin())
      with check (bucket_id = 'tw-builds-public' and public.lms_is_admin());
  end if;
end $$;

-- ── Submit (signed-in) ────────────────────────────────────────────────────
-- Creates a pending build and returns its id. The page then uploads the photo
-- to tw-builds-pending/<uid>/<id> and calls tw_attach_build_photo to record it.
create or replace function public.tw_submit_build(
  p_first_name text, p_age int, p_caption text, p_course_slug text)
returns uuid language plpgsql security definer set search_path = public as $$
declare uid text := lms_uid(); new_id uuid; title text := '';
begin
  if uid is null then raise exception 'Please sign in to share your build.'; end if;
  if coalesce(trim(p_first_name), '') = '' then raise exception 'Please add a first name.'; end if;
  if p_course_slug is not null then
    select coalesce(c.title, '') into title from lms_courses c where c.slug = p_course_slug;
  end if;
  insert into tw_builds (user_id, first_name, age, caption, course_slug, course_title)
    values (uid, left(trim(p_first_name), 40), p_age, left(coalesce(p_caption, ''), 500),
            p_course_slug, coalesce(title, ''))
    returning id into new_id;
  return new_id;
end $$;

-- Record the uploaded photo's path on the submitter's own pending build.
create or replace function public.tw_attach_build_photo(p_id uuid, p_path text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update tw_builds set photo_path = p_path
    where id = p_id and user_id = lms_uid() and status = 'pending';
  if not found then raise exception 'Build not found.'; end if;
end $$;

-- The submitter's own builds (to show "waiting for review / live").
create or replace function public.tw_my_builds()
returns json language sql security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
    'id', id, 'caption', caption, 'course_title', course_title,
    'status', status, 'photo_url', photo_url, 'created_at', created_at
  ) order by created_at desc), '[]'::json)
  from tw_builds where user_id = lms_uid();
$$;

-- ── Public Builds Wall (anon-readable, safe columns only) ─────────────────
create or replace function public.tw_builds_wall(p_limit int default 60)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(b order by b.featured desc, b.created_at desc), '[]'::json)
  from (
    select json_build_object(
      'id', id, 'first_name', first_name, 'age', age, 'caption', caption,
      'course_title', course_title, 'photo_url', photo_url,
      'featured', featured, 'created_at', created_at) as b,
      featured, created_at
    from tw_builds
    where status = 'approved' and photo_url is not null
    order by featured desc, created_at desc
    limit greatest(1, least(p_limit, 200))
  ) b;
$$;

-- ── Live engagement counters (anon-readable) ──────────────────────────────
-- Headline numbers for the site: learners signed up, lessons finished,
-- courses live, and builds shared. All aggregate counts, no personal data.
create or replace function public.tw_stats()
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'learners',       (select count(*) from lms_profiles),
    'lessons_done',   (select count(*) from lms_progress where completed_at is not null),
    'courses_live',   (select count(*) from lms_courses where is_published),
    'builds_shared',  (select count(*) from tw_builds where status = 'approved')
  );
$$;

-- ── Admin moderation (teach.html) ─────────────────────────────────────────
-- Pending first, then recent decisions. photo_path lets the admin preview the
-- private photo (admin storage policy) and copy it to the public bucket on
-- approval; photo_url is the live public URL once approved.
create or replace function public.tw_admin_builds()
returns json language sql security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
    'id', id, 'first_name', first_name, 'age', age, 'caption', caption,
    'course_title', course_title, 'status', status, 'note', note,
    'photo_path', photo_path, 'photo_url', photo_url, 'featured', featured,
    'created_at', created_at, 'decided_at', decided_at
  ) order by (status = 'pending') desc, created_at desc), '[]'::json)
  from tw_builds
  where status = 'pending' or decided_at > now() - interval '30 days';
$$;

-- Approve (with the public photo URL the admin page produced), reject, feature,
-- or delete a build. Only admins.
create or replace function public.tw_admin_decide_build(
  p_id uuid, p_action text, p_note text default '', p_photo_url text default null)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not lms_is_admin() then raise exception 'Admins only.'; end if;
  if p_action = 'approve' then
    update tw_builds set status = 'approved', photo_url = coalesce(p_photo_url, photo_url),
      note = '', decided_at = now() where id = p_id;
  elsif p_action = 'reject' then
    update tw_builds set status = 'rejected', note = left(coalesce(p_note, ''), 300),
      decided_at = now() where id = p_id;
  elsif p_action = 'feature' then
    update tw_builds set featured = not featured where id = p_id;
  elsif p_action = 'delete' then
    delete from tw_builds where id = p_id;
  else
    raise exception 'Unknown action %', p_action;
  end if;
  return p_action;
end $$;

-- Execution grants: wall + stats are public; the rest need a signed-in user,
-- and the admin functions self-check lms_is_admin().
grant execute on function public.tw_builds_wall(int) to anon, authenticated;
grant execute on function public.tw_stats() to anon, authenticated;
grant execute on function public.tw_submit_build(text, int, text, text) to authenticated;
grant execute on function public.tw_attach_build_photo(uuid, text) to authenticated;
grant execute on function public.tw_my_builds() to authenticated;
grant execute on function public.tw_admin_builds() to authenticated;
grant execute on function public.tw_admin_decide_build(uuid, text, text, text) to authenticated;
