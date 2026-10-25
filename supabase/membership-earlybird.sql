-- ════════════════════════════════════════════════════════════════════════
-- Early-bird / Founding-100 support for memberships.
--
-- Pre-launch, members reserve-and-pay at 40% off locked for their first 12
-- months, as one of the first 100 "founding" families. This tags those members
-- durably so that:
--   • the page can show a Founding-100 scarcity counter, and
--   • at renewal time you can find everyone whose founding discount is ending
--     and move them to standard pricing.
--
-- How the tag is set: the join form sends payments whose message starts with
-- "[EARLY-BIRD …]". When you approve one in teach.html, grant it with
-- lms_grant_membership_early (instead of lms_grant_membership) — that flips the
-- founding flag and stamps when the 12-month discount ends.
--
-- Depends on lms.sql + membership.sql. Safe to run again.
-- ════════════════════════════════════════════════════════════════════════

alter table public.lms_memberships add column if not exists early_bird boolean not null default false;
alter table public.lms_memberships add column if not exists early_bird_until timestamptz;  -- when the 40%-off period ends

-- Admin: grant/extend a membership AND tag it founding (40% off for 12 months).
-- Mirrors lms_grant_membership; use this when approving an [EARLY-BIRD …] payment.
create or replace function public.lms_grant_membership_early(p_user text, p_tier text, p_cycle text)
returns void language plpgsql security definer set search_path = public as $$
declare base timestamptz;
begin
  if not lms_is_admin() then raise exception 'Admins only.'; end if;
  if p_tier  not in ('club', 'premium')    then raise exception 'Unknown tier.';  end if;
  if p_cycle not in ('monthly', 'annual')  then raise exception 'Unknown cycle.'; end if;
  select greatest(now(), coalesce(expires_at, now())) into base from lms_memberships where user_id = p_user;
  base := coalesce(base, now());
  insert into lms_memberships (user_id, tier, status, cycle, expires_at, early_bird, early_bird_until)
    values (p_user, p_tier, 'active', p_cycle,
            base + (case p_cycle when 'annual' then interval '1 year' else interval '1 month' end),
            true, now() + interval '12 months')
  on conflict (user_id) do update set
    tier = excluded.tier, status = 'active', cycle = excluded.cycle,
    expires_at = greatest(now(), coalesce(lms_memberships.expires_at, now()))
                 + (case excluded.cycle when 'annual' then interval '1 year' else interval '1 month' end),
    early_bird = true,
    early_bird_until = coalesce(lms_memberships.early_bird_until, now() + interval '12 months'),
    updated_at = now();
end $$;
grant execute on function public.lms_grant_membership_early(text, text, text) to authenticated;

-- Founding-100 counter for the page. Anyone may read the tally (not the people).
-- "taken" = founding memberships granted so far; cap is 100.
create or replace function public.lms_founding_spots() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object('cap', 100, 'taken', c, 'left', greatest(0, 100 - c))
  from (select count(*)::int c from lms_memberships where early_bird) q
$$;
grant execute on function public.lms_founding_spots() to anon, authenticated;

-- Admin: founding members whose 40%-off window ends within 30 days (or has),
-- so you can reach out before they renew at standard pricing.
create or replace function public.lms_early_bird_renewals() returns json
language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
           'user_id', user_id, 'tier', tier, 'cycle', cycle,
           'early_bird_until', early_bird_until, 'expires_at', expires_at
         ) order by early_bird_until), '[]'::json)
  from lms_memberships
  where lms_is_admin() and early_bird and early_bird_until is not null
    and early_bird_until < now() + interval '30 days'
$$;
grant execute on function public.lms_early_bird_renewals() to authenticated;
