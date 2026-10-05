-- Free starter courses + the AI & Young Engineers bundle.
-- Run in Supabase -> SQL Editor after lms.sql. Safe to run more than once.

-- 1. "What is Artificial Intelligence?" and "Robotics 101" become free starter courses,
--    each ending with a "What's next?" lesson that points to the paid courses.
update public.lms_courses set price_kes = 0, price_usd = null, card_url = '',
  offer_price_kes = null, offer_price_usd = null, offer_ends_at = null, is_published = true
where slug in ('what-is-ai', 'robotics-101');

do $$
declare cid uuid;
begin
  for cid in select id from public.lms_courses where slug in ('what-is-ai', 'robotics-101') loop
    delete from public.lms_lessons where course_id = cid and title = $tw$What's next?$tw$;
    insert into public.lms_lessons (course_id, position, section, title, body)
    values (cid, coalesce((select max(position) from public.lms_lessons where course_id = cid), 0) + 1,
      $tw$Keep going$tw$, $tw$What's next?$tw$, $tw$## 🎉 Well done!

You've finished this free starter course. Tick **Mark lesson complete** below to get your certificate.

### Ready for more?

- **[AI Beginners Workbook](https://tinkerwith.me/course.html?c=ai-beginners-workbook)** (ages 8–14): 14 lessons on what AI is, AI careers, making art and stories with AI, staying safe, and a final project where you **build your own chatbot**. The first 2 lessons are free to try.
- **[Young Engineers](https://tinkerwith.me/course.html?c=young-engineers)** (ages 5–18): the Tinker Loop, the 8 engineering superpowers, and a hands-on challenge for every age.
- 💡 **Save with the [AI & Young Engineers Bundle](https://tinkerwith.me/bundle.html?b=ai-young-engineers)**: both courses for one price.

### Prefer learning with a trainer?

Our **[live courses](https://tinkerwith.me/courses.html)** run online or in person, 1:1 or in small groups, with a hands-on robotics and AI project in every session.

### More free fun

Try the **[free activities](https://tinkerwith.me/free-for-kids.html)**: a robot colouring book, the Train an AI game and an AI careers crossword.$tw$);
  end loop;
end $$;

-- 2. The AI & Young Engineers Bundle: both courses for KES 8,000 / US$99.
insert into public.lms_bundles (slug, title, summary, price_kes, price_usd, is_published, position)
values ('ai-young-engineers', 'AI & Young Engineers Bundle',
  'Our two biggest online courses for one price: the AI Beginners Workbook (build your own chatbot) and Young Engineers (think and build like an engineer). 12 months of access to both.',
  8000, 99, true, 1)
on conflict (slug) do update set title = excluded.title, summary = excluded.summary,
  price_kes = excluded.price_kes, price_usd = excluded.price_usd, is_published = excluded.is_published;

delete from public.lms_bundle_courses where bundle_slug = 'ai-young-engineers';
insert into public.lms_bundle_courses (bundle_slug, course_id, position)
select 'ai-young-engineers', id, case slug when 'ai-beginners-workbook' then 1 else 2 end
from public.lms_courses where slug in ('ai-beginners-workbook', 'young-engineers');
