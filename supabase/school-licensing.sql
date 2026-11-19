-- ============================================================================
-- School / Hotel B2B licensing + utilization tracking
-- ----------------------------------------------------------------------------
-- Adds an "organization" (a school or hotel) that owns a pool of SEATS.
-- Learners join an org two ways:
--   • Roster    — a teacher adds an existing learner by email (lms_org_add_member)
--   • Redeem    — a learner enters a seat code at signup       (lms_redeem_code)
-- Both routes grant the listed courses via the existing lms_grant_access, and
-- record org membership so each learner's progress rolls up to their school.
--
-- Utilization is READ from data we already collect (lms_progress, lms_enrollments)
-- — no new event log. Teachers/owners see it via lms_org_dashboard / lms_org_report.
--
-- Conventions mirror lms.sql: text uid, security-definer RPCs, search_path=public,
-- RLS on every table, provisioning functions revoked to service_role only.
-- Apply manually in the Supabase SQL editor. Idempotent.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.lms_orgs (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  slug            text not null unique check (slug = lower(slug)),
  kind            text not null default 'school' check (kind in ('school','hotel','club','other')),
  tier            text not null default 'facilitated' check (tier in ('starter','facilitated','academy')),
  seats_purchased int  not null default 0 check (seats_purchased >= 0),
  kits_included   boolean not null default false,
  term_start      date,
  term_end        date,
  contact_name    text,
  contact_email   text,
  notes           text,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- One row per person in an org. role: owner/teacher = staff (can see dashboard);
-- learner = a seat holder whose progress is tracked.
create table if not exists public.lms_org_members (
  org_id       uuid not null references public.lms_orgs(id) on delete cascade,
  user_id      text not null,
  role         text not null default 'learner' check (role in ('owner','teacher','learner')),
  display_name text,
  created_at   timestamptz not null default now(),
  primary key (org_id, user_id)
);
create index if not exists lms_org_members_user on public.lms_org_members (user_id);
create index if not exists lms_org_members_role on public.lms_org_members (org_id, role);

-- Seat codes a learner redeems. grant_courses = courses unlocked on redeem
-- (empty array = membership only, no course grant).
create table if not exists public.lms_redeem_codes (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  org_id        uuid not null references public.lms_orgs(id) on delete cascade,
  grant_courses uuid[] not null default '{}',
  max_uses      int not null default 1 check (max_uses >= 1),
  used_count    int not null default 0 check (used_count >= 0),
  expires_at    timestamptz,
  created_by    text,
  created_at    timestamptz not null default now()
);
create index if not exists lms_redeem_codes_org on public.lms_redeem_codes (org_id);

-- Audit: who redeemed what (also prevents a learner double-redeeming one code).
create table if not exists public.lms_redemptions (
  code_id     uuid not null references public.lms_redeem_codes(id) on delete cascade,
  user_id     text not null,
  org_id      uuid not null references public.lms_orgs(id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  primary key (code_id, user_id)
);

-- keep updated_at fresh
drop trigger if exists lms_orgs_touch on public.lms_orgs;
create trigger lms_orgs_touch before update on public.lms_orgs
  for each row execute function public.lms_touch();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.lms_orgs          enable row level security;
alter table public.lms_org_members   enable row level security;
alter table public.lms_redeem_codes  enable row level security;
alter table public.lms_redemptions   enable row level security;

-- staff of an org = owner/teacher member, or a site admin
create or replace function public.lms_is_org_staff(p_org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select lms_is_admin() or exists (
    select 1 from lms_org_members m
    where m.org_id = p_org and m.user_id = lms_uid() and m.role in ('owner','teacher')
  );
$$;

drop policy if exists "admin all" on public.lms_orgs;
create policy "admin all" on public.lms_orgs for all to authenticated
  using (lms_is_admin()) with check (lms_is_admin());
drop policy if exists "members read org" on public.lms_orgs;
create policy "members read org" on public.lms_orgs for select to authenticated
  using (exists (select 1 from lms_org_members m where m.org_id = id and m.user_id = lms_uid()));

drop policy if exists "admin all" on public.lms_org_members;
create policy "admin all" on public.lms_org_members for all to authenticated
  using (lms_is_admin()) with check (lms_is_admin());
drop policy if exists "staff read members" on public.lms_org_members;
create policy "staff read members" on public.lms_org_members for select to authenticated
  using (lms_is_org_staff(org_id));
drop policy if exists "own membership" on public.lms_org_members;
create policy "own membership" on public.lms_org_members for select to authenticated
  using (user_id = lms_uid());

drop policy if exists "admin all" on public.lms_redeem_codes;
create policy "admin all" on public.lms_redeem_codes for all to authenticated
  using (lms_is_admin()) with check (lms_is_admin());
drop policy if exists "staff read codes" on public.lms_redeem_codes;
create policy "staff read codes" on public.lms_redeem_codes for select to authenticated
  using (lms_is_org_staff(org_id));

drop policy if exists "admin all" on public.lms_redemptions;
create policy "admin all" on public.lms_redemptions for all to authenticated
  using (lms_is_admin()) with check (lms_is_admin());
drop policy if exists "staff read redemptions" on public.lms_redemptions;
create policy "staff read redemptions" on public.lms_redemptions for select to authenticated
  using (lms_is_org_staff(org_id));

-- ---------------------------------------------------------------------------
-- Seat accounting helper
-- ---------------------------------------------------------------------------
create or replace function public.lms_org_seats_used(p_org uuid)
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from lms_org_members where org_id = p_org and role = 'learner';
$$;

-- ---------------------------------------------------------------------------
-- Provisioning (site admin only) — create/update an org
-- ---------------------------------------------------------------------------
create or replace function public.lms_admin_upsert_org(
  p_name text, p_slug text, p_kind text default 'school', p_tier text default 'facilitated',
  p_seats int default 0, p_kits boolean default false,
  p_term_start date default null, p_term_end date default null,
  p_contact_name text default null, p_contact_email text default null, p_notes text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare oid uuid;
begin
  if not lms_is_admin() then raise exception 'Admins only.'; end if;
  insert into lms_orgs (name, slug, kind, tier, seats_purchased, kits_included,
                        term_start, term_end, contact_name, contact_email, notes)
  values (p_name, lower(p_slug), p_kind, p_tier, p_seats, p_kits,
          p_term_start, p_term_end, p_contact_name, p_contact_email, p_notes)
  on conflict (slug) do update set
    name = excluded.name, kind = excluded.kind, tier = excluded.tier,
    seats_purchased = excluded.seats_purchased, kits_included = excluded.kits_included,
    term_start = excluded.term_start, term_end = excluded.term_end,
    contact_name = excluded.contact_name, contact_email = excluded.contact_email,
    notes = coalesce(excluded.notes, lms_orgs.notes)
  returning id into oid;
  return oid;
end;
$$;

-- Make a person staff of an org (site admin only). Looks up uid by email.
create or replace function public.lms_admin_set_org_staff(p_org uuid, p_email text, p_role text default 'teacher')
returns text language plpgsql security definer set search_path = public as $$
declare uid text;
begin
  if not lms_is_admin() then raise exception 'Admins only.'; end if;
  if p_role not in ('owner','teacher') then raise exception 'Role must be owner or teacher.'; end if;
  select user_id into uid from lms_profiles where lower(email) = lower(p_email);
  if uid is null then raise exception 'No account for % — ask them to sign up first.', p_email; end if;
  insert into lms_org_members (org_id, user_id, role, display_name)
  values (p_org, uid, p_role, p_email)
  on conflict (org_id, user_id) do update set role = excluded.role;
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- Codes (org staff) — generate seat codes
-- ---------------------------------------------------------------------------
-- 8 chars, no confusable letters/digits.
create or replace function public.lms_gen_code() returns text
language plpgsql security definer set search_path = public as $$
declare alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; c text; i int;
begin
  loop
    c := '';
    for i in 1..8 loop c := c || substr(alphabet, 1 + floor(random()*length(alphabet))::int, 1); end loop;
    exit when not exists (select 1 from lms_redeem_codes where code = c);
  end loop;
  return c;
end;
$$;

create or replace function public.lms_org_create_code(
  p_org uuid, p_courses uuid[] default '{}', p_max_uses int default 1, p_days_valid int default null
) returns json language plpgsql security definer set search_path = public as $$
declare c text; exp timestamptz;
begin
  if not lms_is_org_staff(p_org) then raise exception 'Not a teacher for this organization.'; end if;
  c := lms_gen_code();
  exp := case when p_days_valid is not null then now() + (p_days_valid || ' days')::interval end;
  insert into lms_redeem_codes (code, org_id, grant_courses, max_uses, expires_at, created_by)
  values (c, p_org, coalesce(p_courses,'{}'), greatest(p_max_uses,1), exp, lms_uid());
  return json_build_object('code', c, 'max_uses', greatest(p_max_uses,1), 'expires_at', exp);
end;
$$;

-- ---------------------------------------------------------------------------
-- Redeem (any signed-in learner)
-- ---------------------------------------------------------------------------
create or replace function public.lms_redeem_code(p_code text)
returns json language plpgsql security definer set search_path = public as $$
declare rc lms_redeem_codes; uid text := lms_uid(); cid uuid; used int;
begin
  if uid is null then raise exception 'Please sign in first.'; end if;
  select * into rc from lms_redeem_codes where code = upper(trim(p_code));
  if rc.id is null then raise exception 'That code is not valid.'; end if;
  if rc.expires_at is not null and rc.expires_at < now() then raise exception 'That code has expired.'; end if;

  -- already redeemed by this learner? treat as success (idempotent)
  if exists (select 1 from lms_redemptions where code_id = rc.id and user_id = uid) then
    return json_build_object('ok', true, 'org_id', rc.org_id, 'note', 'already redeemed');
  end if;
  if rc.used_count >= rc.max_uses then raise exception 'That code has already been used up.'; end if;

  -- seat check
  used := lms_org_seats_used(rc.org_id);
  if used >= (select seats_purchased from lms_orgs where id = rc.org_id)
     and not exists (select 1 from lms_org_members where org_id = rc.org_id and user_id = uid) then
    raise exception 'This school has no seats left — please tell your teacher.';
  end if;

  insert into lms_org_members (org_id, user_id, role) values (rc.org_id, uid, 'learner')
    on conflict (org_id, user_id) do nothing;
  insert into lms_redemptions (code_id, user_id, org_id) values (rc.id, uid, rc.org_id);
  update lms_redeem_codes set used_count = used_count + 1 where id = rc.id;

  foreach cid in array rc.grant_courses loop
    perform lms_grant_access(uid, cid);
  end loop;

  return json_build_object('ok', true, 'org_id', rc.org_id, 'courses_granted', coalesce(array_length(rc.grant_courses,1),0));
end;
$$;

-- ---------------------------------------------------------------------------
-- Roster (org staff) — add an existing learner by email, optionally grant courses
-- ---------------------------------------------------------------------------
create or replace function public.lms_org_add_member(
  p_org uuid, p_email text, p_courses uuid[] default '{}'
) returns text language plpgsql security definer set search_path = public as $$
declare uid text; cid uuid; used int;
begin
  if not lms_is_org_staff(p_org) then raise exception 'Not a teacher for this organization.'; end if;
  select user_id into uid from lms_profiles where lower(email) = lower(p_email);
  if uid is null then raise exception 'No account for % yet — share a seat code instead, or ask them to sign up first.', p_email; end if;

  if not exists (select 1 from lms_org_members where org_id = p_org and user_id = uid) then
    used := lms_org_seats_used(p_org);
    if used >= (select seats_purchased from lms_orgs where id = p_org) then
      raise exception 'No seats left for this organization.';
    end if;
    insert into lms_org_members (org_id, user_id, role, display_name) values (p_org, uid, 'learner', p_email);
  end if;

  foreach cid in array coalesce(p_courses,'{}') loop
    perform lms_grant_access(uid, cid);
  end loop;
  return 'ok';
end;
$$;

create or replace function public.lms_org_remove_member(p_org uuid, p_user text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not lms_is_org_staff(p_org) then raise exception 'Not a teacher for this organization.'; end if;
  delete from lms_org_members where org_id = p_org and user_id = p_user and role = 'learner';
  return 'ok';
end;
$$;

-- ---------------------------------------------------------------------------
-- Which orgs am I staff of? (routes a teacher to their dashboard)
-- ---------------------------------------------------------------------------
create or replace function public.lms_my_orgs()
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
    'id', o.id, 'name', o.name, 'slug', o.slug, 'kind', o.kind, 'tier', o.tier,
    'role', m.role, 'seats_purchased', o.seats_purchased,
    'seats_used', lms_org_seats_used(o.id)
  ) order by o.name), '[]'::json)
  from lms_org_members m join lms_orgs o on o.id = m.org_id
  where m.user_id = lms_uid() and m.role in ('owner','teacher');
$$;

-- ---------------------------------------------------------------------------
-- Dashboard (org staff) — live utilization
-- ---------------------------------------------------------------------------
-- p_org null = the caller's first staff org. "Stuck" = enrolled but no progress
-- update in the last 14 days (and not yet finished any course).
create or replace function public.lms_org_dashboard(p_org uuid default null)
returns json language plpgsql stable security definer set search_path = public as $$
declare oid uuid; org lms_orgs;
begin
  oid := coalesce(p_org, (select org_id from lms_org_members
                          where user_id = lms_uid() and role in ('owner','teacher')
                          order by created_at limit 1));
  if oid is null then raise exception 'You are not a teacher for any organization.'; end if;
  if not lms_is_org_staff(oid) then raise exception 'Not a teacher for this organization.'; end if;
  select * into org from lms_orgs where id = oid;

  return json_build_object(
    'org', json_build_object('id', org.id, 'name', org.name, 'kind', org.kind, 'tier', org.tier,
      'seats_purchased', org.seats_purchased, 'seats_used', lms_org_seats_used(oid),
      'seats_free', org.seats_purchased - lms_org_seats_used(oid),
      'kits_included', org.kits_included, 'term_start', org.term_start, 'term_end', org.term_end),

    -- headline numbers
    'summary', (
      with learners as (select user_id from lms_org_members where org_id = oid and role='learner'),
      act as (
        select l.user_id,
          max(p.updated_at)                                        as last_active,
          count(*) filter (where p.completed_at is not null)       as lessons_done,
          count(distinct p.course_id) filter (where p.completed_at is not null) as courses_touched,
          avg(p.quiz_score::numeric / nullif(p.quiz_total,0)) filter (where p.quiz_total > 0) as quiz_ratio
        from learners l left join lms_progress p on p.user_id = l.user_id
        group by l.user_id
      )
      select json_build_object(
        'learners', (select count(*) from learners),
        'active_7d', (select count(*) from act where last_active > now() - interval '7 days'),
        'active_30d', (select count(*) from act where last_active > now() - interval '30 days'),
        'lessons_completed', (select coalesce(sum(lessons_done),0) from act),
        'avg_quiz_pct', (select round(100*avg(quiz_ratio)) from act where quiz_ratio is not null),
        'stuck', (select count(*) from act
                  where (last_active is null or last_active < now() - interval '14 days')
                  and coalesce(lessons_done,0) = 0)
      )
    ),

    -- per-learner rows
    'learners', (
      select coalesce(json_agg(r order by r->>'name'), '[]'::json) from (
        select json_build_object(
          'user_id', m.user_id,
          'name', coalesce(m.display_name, pr.email, m.user_id),
          'last_active', st.last_active,
          'lessons_done', coalesce(st.lessons_done,0),
          'courses_done', coalesce(st.courses_done,0),
          'avg_quiz_pct', case when st.quiz_ratio is not null then round(100*st.quiz_ratio) end,
          'stuck', (st.last_active is null or st.last_active < now() - interval '14 days') and coalesce(st.lessons_done,0)=0
        ) as r
        from lms_org_members m
        left join lms_profiles pr on pr.user_id = m.user_id
        left join lateral (
          select max(p.updated_at) as last_active,
                 count(*) filter (where p.completed_at is not null) as lessons_done,
                 count(distinct p.course_id) filter (where p.completed_at is not null) as courses_done,
                 avg(p.quiz_score::numeric / nullif(p.quiz_total,0)) filter (where p.quiz_total > 0) as quiz_ratio
          from lms_progress p where p.user_id = m.user_id
        ) st on true
        where m.org_id = oid and m.role = 'learner'
      ) s
    ),

    -- per-course breakdown across the org's learners
    'courses', (
      select coalesce(json_agg(r order by r->>'title'), '[]'::json) from (
        select json_build_object(
          'course_id', c.id, 'title', c.title,
          'enrolled', count(distinct e.user_id),
          'completed_lessons', count(*) filter (where p.completed_at is not null),
          'avg_quiz_pct', case when avg(p.quiz_score::numeric/nullif(p.quiz_total,0)) filter (where p.quiz_total>0) is not null
                               then round(100*avg(p.quiz_score::numeric/nullif(p.quiz_total,0)) filter (where p.quiz_total>0)) end
        ) as r
        from lms_courses c
        join lms_enrollments e on e.course_id = c.id
          and e.user_id in (select user_id from lms_org_members where org_id = oid and role='learner')
        left join lms_progress p on p.course_id = c.id and p.user_id = e.user_id
        group by c.id, c.title
      ) s
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Termly report (org staff) — aggregates over a date window for the head teacher
-- ---------------------------------------------------------------------------
create or replace function public.lms_org_report(
  p_org uuid, p_from date default null, p_to date default null
) returns json language plpgsql stable security definer set search_path = public as $$
declare oid uuid; org lms_orgs; dfrom timestamptz; dto timestamptz;
begin
  oid := coalesce(p_org, (select org_id from lms_org_members
                          where user_id = lms_uid() and role in ('owner','teacher')
                          order by created_at limit 1));
  if oid is null or not lms_is_org_staff(oid) then raise exception 'Not a teacher for this organization.'; end if;
  select * into org from lms_orgs where id = oid;
  dfrom := coalesce(p_from, org.term_start, (now() - interval '90 days')::date)::timestamptz;
  dto   := coalesce(p_to, org.term_end, now()::date)::timestamptz + interval '1 day';

  return json_build_object(
    'org', json_build_object('name', org.name, 'kind', org.kind, 'tier', org.tier,
      'seats_purchased', org.seats_purchased, 'seats_used', lms_org_seats_used(oid)),
    'window', json_build_object('from', dfrom::date, 'to', (dto - interval '1 day')::date),
    'activation_pct', case when org.seats_purchased > 0
      then round(100.0 * lms_org_seats_used(oid) / org.seats_purchased) else null end,
    'lessons_completed', (select count(*) from lms_progress p
      where p.user_id in (select user_id from lms_org_members where org_id=oid and role='learner')
      and p.completed_at between dfrom and dto),
    'active_learners', (select count(distinct p.user_id) from lms_progress p
      where p.user_id in (select user_id from lms_org_members where org_id=oid and role='learner')
      and p.updated_at between dfrom and dto),
    'avg_quiz_pct', (select round(100*avg(p.quiz_score::numeric/nullif(p.quiz_total,0)))
      from lms_progress p
      where p.user_id in (select user_id from lms_org_members where org_id=oid and role='learner')
      and p.quiz_total > 0 and p.updated_at between dfrom and dto),
    'courses_started', (select count(distinct p.course_id) from lms_progress p
      where p.user_id in (select user_id from lms_org_members where org_id=oid and role='learner')
      and p.updated_at between dfrom and dto)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants — provisioning is service_role only; teacher/learner RPCs to authenticated
-- ---------------------------------------------------------------------------
revoke all on function public.lms_admin_upsert_org(text,text,text,text,int,boolean,date,date,text,text,text) from public, anon, authenticated;
revoke all on function public.lms_admin_set_org_staff(uuid,text,text) from public, anon, authenticated;
revoke all on function public.lms_gen_code() from public, anon, authenticated;

grant execute on function public.lms_is_org_staff(uuid)               to authenticated;
grant execute on function public.lms_org_seats_used(uuid)             to authenticated;
grant execute on function public.lms_org_create_code(uuid,uuid[],int,int) to authenticated;
grant execute on function public.lms_redeem_code(text)                to authenticated;
grant execute on function public.lms_org_add_member(uuid,text,uuid[]) to authenticated;
grant execute on function public.lms_org_remove_member(uuid,text)     to authenticated;
grant execute on function public.lms_my_orgs()                        to authenticated;
grant execute on function public.lms_org_dashboard(uuid)              to authenticated;
grant execute on function public.lms_org_report(uuid,date,date)       to authenticated;
