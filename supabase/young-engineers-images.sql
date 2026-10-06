-- Young Engineers: add illustrations (assets/courses/young-engineers/) and a cover.
-- Each picture goes under a heading in its lesson; lessons that already have it,
-- or whose heading was changed, are left alone. Safe to run more than once.
do $$
declare cid uuid; img record; n int; total int := 0;
begin
  select id into cid from public.lms_courses where slug = 'young-engineers';
  if cid is null then raise exception 'Young Engineers course not found.'; end if;

  update public.lms_courses set cover_url = 'https://tinkerwith.me/assets/courses/young-engineers/cover.svg'
  where id = cid and cover_url = '';

  for img in select * from (values
    ('### The Tinker Loop', 'tinker-loop.svg', 'The Tinker Loop: think, design, build, test, measure, diagnose, improve, explain'),
    ('## 🗺️ The Young Engineer Journey', 'journey.svg', 'The five stages of the Young Engineer Journey, from Explorer to Innovator'),
    ('## 🧩 The 8 engineering superpowers', 'superpowers.svg', 'The 8 engineering superpowers'),
    ('### 🚧 Challenge: The Bridge Builder', 'bridge-challenge.svg', 'A flat paper bridge sags, a folded one holds 10 blocks'),
    ('### 🚦 Challenge: Smart Traffic', 'smart-traffic.svg', 'A traffic light turns green when its sensor sees a waiting car'),
    ('### 🤖 Challenge: Autonomous Rover', 'rover-challenge.svg', 'A rover drives from A to B around obstacles'),
    ('### 🏁 Challenge: Autonomous Vehicle', 'trade-offs.svg', 'Trade-offs between speed, accuracy, cost and battery life'),
    ('### 🌍 Grand Challenge: Build for the Real World', 'capstone.svg', 'Community problems a capstone can solve'),
    ('## 📓 The Engineer''s Notebook', 'notebook.svg', 'The 9 steps of the Engineer''s Notebook')
  ) as v(heading, file, alt) loop
    update public.lms_lessons
      set body = replace(body, img.heading, img.heading || E'\n\n![' || img.alt || '](https://tinkerwith.me/assets/courses/young-engineers/' || img.file || ')')
    where course_id = cid and position(img.heading in body) > 0 and position(img.file in body) = 0;
    get diagnostics n = row_count; total := total + n;
  end loop;
  raise notice 'Pictures added to % lessons.', total;
end $$;

-- Check: which lessons now have a picture.
select l.position, l.title, (l.body like '%assets/courses/young-engineers/%') as has_picture
from public.lms_lessons l join public.lms_courses c on c.id = l.course_id
where c.slug = 'young-engineers' order by l.position;
