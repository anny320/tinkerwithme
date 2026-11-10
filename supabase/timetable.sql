-- ════════════════════════════════════════════════════════════════════════
-- Weekly live-session TIMETABLE for members.
--
-- A recurring weekly template: one row per session (cohort, day, time), set up
-- once and shown every week. Two read paths, from one table:
--
--   • lms_timetable_public()  — the weekly RHYTHM (day/time/cohort/tier), with
--     NO join links. Callable by anyone (anon) — this powers the public teaser
--     on the homepage and the logged-out view, to promote the club.
--   • lms_my_timetable()      — the full timetable WITH join links, returned
--     only for the sessions the caller's active membership entitles them to.
--
-- Join links never leave the server except through lms_my_timetable(), so a
-- non-member (or a "view source" snooper) can never see them.
--
-- Admins manage rows directly from teach.html (RLS: admins only).
--
-- Depends on lms.sql (lms_uid(), lms_is_admin()) + membership.sql
-- (lms_member_rank(): 0 = none, 1 = club, 2 = premium/admin). Safe to run again.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.lms_timetable (
  id         uuid primary key default gen_random_uuid(),
  cohort     text not null,                               -- e.g. "Builders (10–12)"
  tier       text not null default 'all'
               check (tier in ('all', 'club', 'premium')), -- who may see it
  weekday    int  not null check (weekday between 0 and 6), -- 0=Sun … 6=Sat (JS getDay)
  start_time text not null check (start_time ~ '^[0-2][0-9]:[0-5][0-9]$'), -- 'HH:MM', EAT
  end_time   text          check (end_time   ~ '^[0-2][0-9]:[0-5][0-9]$'),
  tz         text not null default 'Africa/Nairobi',
  join_url   text,
  image_url  text,                                        -- photo/illustration of the build
  note       text,
  active     boolean not null default true,
  sort       int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- In case an earlier version of this table was already created without it:
alter table public.lms_timetable add column if not exists image_url text;
create index if not exists lms_timetable_active_idx on public.lms_timetable (active, weekday, start_time);

alter table public.lms_timetable enable row level security;
revoke all on public.lms_timetable from anon, authenticated;
-- Admins manage the rows (teach.html uses db().from('lms_timetable')); the two
-- RPCs below are the only read path for everyone else.
grant select, insert, update, delete on public.lms_timetable to authenticated;
drop policy if exists "admin timetable" on public.lms_timetable;
create policy "admin timetable" on public.lms_timetable for all to authenticated
  using (public.lms_is_admin()) with check (public.lms_is_admin());

-- ── Public teaser: the weekly rhythm, no join links ──────────────────────
create or replace function public.lms_timetable_public() returns json
language sql stable security definer set search_path = public as $$
  select coalesce((
    select json_agg(json_build_object(
      'id', id, 'cohort', cohort, 'tier', tier, 'weekday', weekday,
      'start_time', start_time, 'end_time', end_time, 'tz', tz,
      'image_url', image_url, 'note', note
    ) order by weekday, start_time, sort)
    from lms_timetable where active), '[]'::json)
$$;
grant execute on function public.lms_timetable_public() to anon, authenticated;

-- ── Member view: full rows + join links, only what the caller is entitled to ─
-- lms_member_rank(): 0 none, 1 club, 2 premium/admin. A row needs rank >= 2 for
-- 'premium', else rank >= 1 ('all' and 'club'). Non-members get an empty list.
create or replace function public.lms_my_timetable() returns json
language sql stable security definer set search_path = public as $$
  select coalesce((
    select json_agg(json_build_object(
      'id', id, 'cohort', cohort, 'tier', tier, 'weekday', weekday,
      'start_time', start_time, 'end_time', end_time, 'tz', tz,
      'join_url', join_url, 'image_url', image_url, 'note', note
    ) order by weekday, start_time, sort)
    from lms_timetable
    where active
      and public.lms_member_rank() >= case tier when 'premium' then 2 else 1 end), '[]'::json)
$$;
grant execute on function public.lms_my_timetable() to authenticated;

-- ── Seed examples (optional) — edit from teach.html instead ───────────────
-- insert into public.lms_timetable (cohort, tier, weekday, start_time, end_time, join_url) values
--   ('Club — monthly group session', 'club',    6, '10:00', '11:00', 'https://meet.google.com/xxx'),
--   ('Explorers (7–9)',              'premium', 4, '16:00', '17:00', 'https://meet.google.com/yyy'),
--   ('Builders (10–12)',             'premium', 5, '16:30', '17:30', 'https://meet.google.com/zzz'),
--   ('Makers (13–16)',               'premium', 6, '17:00', '18:00', 'https://meet.google.com/www');
