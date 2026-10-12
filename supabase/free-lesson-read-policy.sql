-- Public read access to FREE, PUBLISHED lesson bodies.
--
-- The curriculum generator (and any public page) can read lesson bodies for
-- free, published courses through the public (anon) key. Paid-course lessons
-- stay protected: there is no anon policy that matches them, so RLS denies them.
--
-- Column grant excludes `quiz`, so quiz answers are never exposed to anon even
-- for free courses. Authenticated access still goes through the lms_* functions.

grant select (course_id, position, section, title, body, is_preview, created_at)
  on public.lms_lessons to anon;

drop policy if exists "free published lessons" on public.lms_lessons;
create policy "free published lessons" on public.lms_lessons
  for select to anon
  using (exists (
    select 1 from public.lms_courses c
    where c.id = lms_lessons.course_id
      and c.is_published
      and c.price_kes is null
  ));
