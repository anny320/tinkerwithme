-- AI Beginners Workbook: replace the old WordPress cover image
-- (https://tinkerwith.me/wp-content/uploads/.../ai-images.jpg, being retired)
-- with the new local illustrative cover. Run once in Supabase → SQL Editor.

update public.lms_courses
  set cover_url = 'assets/courses/ai-beginners-workbook.svg'
  where slug = 'ai-beginners-workbook';

select slug, cover_url from public.lms_courses where slug = 'ai-beginners-workbook';
