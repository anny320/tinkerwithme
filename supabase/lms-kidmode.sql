-- Kid mode for premium courses.
-- Makes course.html's "👶 Kid mode" button work for the 17 premium courses by
-- (1) ensuring the lesson kid_body column exists and (2) returning it from lms_lesson.
-- Safe to run multiple times. Free courses are unaffected (they use kids_content.json).

alter table public.lms_lessons add column if not exists kid_body text not null default '';

create or replace function public.lms_lesson(p_lesson uuid)
returns json language plpgsql stable security definer set search_path = public as $$
declare l lms_lessons; p lms_progress;
begin
  select * into l from lms_lessons where id = p_lesson;
  if not found or not lms_can_open_lesson(l.id) then raise exception 'You don''t have access to this lesson.'; end if;
  select * into p from lms_progress where user_id = lms_uid() and lesson_id = l.id;
  return json_build_object(
    'id', l.id, 'course_id', l.course_id, 'section', l.section, 'title', l.title, 'body', l.body, 'kid_body', l.kid_body, 'video_url', l.video_url,
    'quiz', coalesce((select json_agg(json_build_object('q', q->>'q', 'options', q->'options') order by n)
                      from jsonb_array_elements(l.quiz) with ordinality as t(q, n)), '[]'::json),
    'done', p.completed_at is not null, 'quiz_score', p.quiz_score, 'quiz_total', p.quiz_total);
end $$;
