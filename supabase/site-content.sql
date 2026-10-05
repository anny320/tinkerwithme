-- Website content for the Course editor (admin.html): the course picker
-- catalogue, testimonials and blog posts. One row per former JSON file.
--
-- Run once in Supabase → SQL Editor, AFTER lms.sql (it uses lms_is_admin()).
-- Safe to re-run: it never overwrites content already saved by the editor.
--
-- Who can do what:
--   * admins (lms_admins) read and save everything from admin.html;
--   * everyone else reads through site_content_public(), which only returns
--     published testimonials and leaves out the consent notes.

create table if not exists public.site_content (
  key        text primary key check (key in ('courses', 'testimonials', 'posts')),
  data       jsonb not null,
  updated_at timestamptz not null default now()
);

drop trigger if exists site_content_touch on public.site_content;
create trigger site_content_touch before update on public.site_content
  for each row execute function public.lms_touch();

alter table public.site_content enable row level security;
revoke all on public.site_content from anon, authenticated;
grant select, insert, update on public.site_content to authenticated;
drop policy if exists "admin all" on public.site_content;
create policy "admin all" on public.site_content for all to authenticated
  using (lms_is_admin()) with check (lms_is_admin());

create or replace function public.site_content_public(p_key text) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when key = 'testimonials' then
      jsonb_build_object('testimonials', coalesce((
        select jsonb_agg(t - 'consent' - 'source')
        from jsonb_array_elements(data -> 'testimonials') t
        where t ->> 'published' = 'true'), '[]'::jsonb))
    else data end
  from site_content where key = p_key
$$;
grant execute on function public.site_content_public(text) to anon, authenticated;

-- Starting content: what was in the JSON files when this was written.
insert into public.site_content (key, data) values
  ('courses', $seed${
 "arduino": {
  "ages": [
   "6-9 yrs",
   "10-12 yrs",
   "13-15 yrs",
   "All ages"
  ],
  "projects": [
   {
    "id": "ar1",
    "icon": "ti-traffic-lights",
    "title": "Traffic light simulation",
    "diff": "Beginner",
    "age": "6-9 yrs",
    "time": 60,
    "level": 1,
    "desc": "3 LEDs mimic real traffic light sequences"
   },
   {
    "id": "ar2",
    "icon": "ti-hand-click",
    "title": "Button controlled LED",
    "diff": "Beginner",
    "age": "6-9 yrs",
    "time": 45,
    "level": 1,
    "desc": "Push button toggles LED on/off"
   },
   {
    "id": "ar3",
    "icon": "ti-brightness",
    "title": "Fade an LED",
    "diff": "Beginner",
    "age": "6-9 yrs",
    "time": 45,
    "level": 1,
    "desc": "PWM & analogWrite() to dim LED smoothly"
   },
   {
    "id": "ar4",
    "icon": "ti-palette",
    "title": "RGB LED colour mixer",
    "diff": "Beginner",
    "age": "6-9 yrs",
    "time": 60,
    "level": 1,
    "desc": "3 potentiometers mix red, green & blue"
   },
   {
    "id": "ar5",
    "icon": "ti-hand-finger",
    "title": "Capacitive touch sensor",
    "diff": "Beginner",
    "age": "10-12 yrs",
    "time": 60,
    "level": 2,
    "desc": "Touch sensor module toggles an LED"
   },
   {
    "id": "ar6",
    "icon": "ti-music",
    "title": "Buzzer melody",
    "diff": "Beginner",
    "age": "6-9 yrs",
    "time": 60,
    "level": 1,
    "desc": "Piezo buzzer plays tunes like Ode to Joy"
   },
   {
    "id": "ar7",
    "icon": "ti-dots",
    "title": "Morse code blinker",
    "diff": "Intermediate",
    "age": "10-12 yrs",
    "time": 75,
    "level": 2,
    "desc": "LED blinks out Morse code messages"
   },
   {
    "id": "ar8",
    "icon": "ti-temperature",
    "title": "Temperature logger",
    "diff": "Intermediate",
    "age": "10-12 yrs",
    "time": 90,
    "level": 2,
    "desc": "DHT11 reads & displays temperature"
   },
   {
    "id": "ar9",
    "icon": "ti-radar",
    "title": "Ultrasonic distance sensor",
    "diff": "Intermediate",
    "age": "10-12 yrs",
    "time": 75,
    "level": 2,
    "desc": "HC-SR04 measures distance, LED warns on proximity"
   },
   {
    "id": "ar10",
    "icon": "ti-rotate-clockwise",
    "title": "Servo motor control",
    "diff": "Intermediate",
    "age": "10-12 yrs",
    "time": 75,
    "level": 2,
    "desc": "Potentiometer steers servo to any position"
   },
   {
    "id": "ar11",
    "icon": "ti-sun",
    "title": "Light-activated LED",
    "diff": "Beginner",
    "age": "6-9 yrs",
    "time": 60,
    "level": 1,
    "desc": "Photoresistor auto-lights LED when dark"
   },
   {
    "id": "ar12",
    "icon": "ti-dice-5",
    "title": "Digital dice",
    "diff": "Intermediate",
    "age": "10-12 yrs",
    "time": 90,
    "level": 3,
    "desc": "Multiple LEDs randomly show a dice roll"
   },
   {
    "id": "ar13",
    "icon": "ti-bell",
    "title": "Basic alarm system",
    "diff": "Intermediate",
    "age": "10-12 yrs",
    "time": 90,
    "level": 3,
    "desc": "Motion sensor triggers buzzer & LED alarm"
   },
   {
    "id": "ar14",
    "icon": "ti-wind",
    "title": "Fan control",
    "diff": "Advanced",
    "age": "13-15 yrs",
    "time": 90,
    "level": 4,
    "desc": "Temperature sensor controls relay-powered fan"
   },
   {
    "id": "ar15",
    "icon": "ti-gamepad",
    "title": "Simon says game",
    "diff": "Advanced",
    "age": "13-15 yrs",
    "time": 120,
    "level": 3,
    "desc": "Classic memory game with LEDs, buttons & buzzer"
   },
   {
    "id": "ar16",
    "icon": "ti-robot",
    "title": "Line-following robot",
    "diff": "Advanced",
    "age": "13-15 yrs",
    "time": 120,
    "level": 4,
    "desc": "IR sensors steer a two-motor chassis along a track"
   },
   {
    "id": "ar17",
    "icon": "ti-building-skyscraper",
    "title": "Smart city",
    "diff": "Advanced",
    "age": "13-15 yrs",
    "time": 120,
    "level": 4,
    "desc": "Coordinated traffic lights, street lights & a parking sensor on one build"
   },
   {
    "id": "ar18",
    "icon": "ti-radar-2",
    "title": "Obstacle-avoiding robot",
    "diff": "Advanced",
    "age": "13-15 yrs",
    "time": 120,
    "level": 4,
    "desc": "Ultrasonic sensor steers the robot around obstacles"
   },
   {
    "id": "ar19",
    "icon": "ti-cloud",
    "title": "Weather station",
    "diff": "Advanced",
    "age": "13-15 yrs",
    "time": 90,
    "level": 4,
    "desc": "DHT11 + LCD logs temperature & humidity"
   },
   {
    "id": "ar20",
    "icon": "ti-microphone",
    "title": "Voice- / gesture-controlled robot",
    "diff": "Advanced",
    "age": "13-15 yrs",
    "time": 150,
    "level": 4,
    "desc": "A Teachable Machine model drives an Arduino robot — an AI × Arduino crossover"
   },
   {
    "id": "ar21",
    "icon": "ti-hand-move",
    "title": "Cardboard robotic arm",
    "diff": "Intermediate",
    "age": "All ages",
    "time": 120,
    "level": 3,
    "desc": "Build a cardboard arm and steer its servos live with potentiometers"
   }
  ]
 },
 "ai": {
  "ages": [
   "7-10 yrs",
   "10-13 yrs",
   "13-16 yrs",
   "All ages"
  ],
  "projects": [
   {
    "id": "a1",
    "icon": "ti-message-circle",
    "title": "Prompting power",
    "diff": "Beginner",
    "age": "7-10 yrs",
    "time": 60,
    "level": 1,
    "desc": "ChatGPT basics — ask better questions"
   },
   {
    "id": "a2",
    "icon": "ti-photo-ai",
    "title": "AI art studio",
    "diff": "Beginner",
    "age": "7-10 yrs",
    "time": 60,
    "level": 1,
    "desc": "DALL-E image generation workshop"
   },
   {
    "id": "a3",
    "icon": "ti-music",
    "title": "AI music & sound",
    "diff": "Beginner",
    "age": "7-10 yrs",
    "time": 60,
    "level": 1,
    "desc": "Generate soundtracks and beats"
   },
   {
    "id": "a4",
    "icon": "ti-book-2",
    "title": "AI storytelling",
    "diff": "Beginner",
    "age": "10-13 yrs",
    "time": 75,
    "level": 3,
    "desc": "Write illustrated stories with AI"
   },
   {
    "id": "a5",
    "icon": "ti-cpu",
    "title": "Teachable Machine",
    "diff": "Intermediate",
    "age": "10-13 yrs",
    "time": 90,
    "level": 2,
    "desc": "Train your own image classifier"
   },
   {
    "id": "a6",
    "icon": "ti-palette",
    "title": "Mashup madness",
    "diff": "Intermediate",
    "age": "10-13 yrs",
    "time": 90,
    "level": 3,
    "desc": "Combine multiple AI tools creatively"
   },
   {
    "id": "a7",
    "icon": "ti-scale",
    "title": "Bias detective",
    "diff": "Intermediate",
    "age": "13-16 yrs",
    "time": 75,
    "level": 4,
    "desc": "Find and discuss bias in AI tools"
   },
   {
    "id": "a8",
    "icon": "ti-briefcase",
    "title": "AI careers deep dive",
    "diff": "Intermediate",
    "age": "13-16 yrs",
    "time": 60,
    "level": 5,
    "desc": "ML engineers, ethicists, data scientists"
   },
   {
    "id": "a9",
    "icon": "ti-rocket",
    "title": "Build your portfolio",
    "diff": "Advanced",
    "age": "13-16 yrs",
    "time": 120,
    "level": 5,
    "desc": "GitHub, pitch deck, and showcase prep"
   },
   {
    "id": "a10",
    "icon": "ti-sitemap",
    "title": "How AI systems work",
    "diff": "Intermediate",
    "age": "10-13 yrs",
    "time": 60,
    "level": 2,
    "desc": "Follow the input → model → output pipeline with hands-on examples"
   },
   {
    "id": "a11",
    "icon": "ti-database",
    "title": "Good Data, Bad Data",
    "diff": "Intermediate",
    "age": "10-13 yrs",
    "time": 75,
    "level": 2,
    "desc": "Clean and sort data to see how the quality of data shapes what AI learns"
   },
   {
    "id": "a12",
    "icon": "ti-shield-check",
    "title": "Ethical AI design",
    "diff": "Advanced",
    "age": "13-16 yrs",
    "time": 75,
    "level": 5,
    "desc": "Design an AI feature with fairness, privacy and safety in mind"
   },
   {
    "id": "a13",
    "icon": "ti-presentation",
    "title": "Explain AI to others",
    "diff": "Intermediate",
    "age": "13-16 yrs",
    "time": 60,
    "level": 5,
    "desc": "Prepare and give a clear talk that teaches AI to a younger audience"
   }
  ]
 }
}$seed$::jsonb),
  ('testimonials', $seed${
 "_comment": "Testimonials shown on index.html. Set \"published\": false to hold one back without deleting it — only published entries ever render. Keep \"consent\" honest: it records that the person agreed in writing to be quoted. Never publish a quote you did not receive.",
 "_fields": {
  "quote": "their words, unedited except for obvious typos",
  "name": "first name + last initial is enough, and is the right call for children",
  "role": "who they are — 'Parent of an 8-year-old', 'Teen student'",
  "source": "where it came from — whatsapp, email, in-person, google-review",
  "date": "ISO date you received it",
  "consent": true,
  "published": true
 },
 "testimonials": [
  {
   "quote": "My son went from just playing with gadgets to actually building his own! He's so proud of the little robot he made, and I've never seen him this excited about learning.",
   "name": "Sarah M",
   "role": "Parent of an 8-year-old",
   "source": "migrated-from-wordpress",
   "date": null,
   "consent": null,
   "published": true
  },
  {
   "quote": "I built a robot that follows me around — and my friends think it's the coolest thing ever!",
   "name": "Ethan R",
   "role": "10 years old",
   "source": "migrated-from-wordpress",
   "date": null,
   "consent": null,
   "published": true
  },
  {
   "quote": "The AI course blew my mind. I went from zero coding knowledge to making my own chatbot in just a few weeks.",
   "name": "Marissa Young",
   "role": "Teen student",
   "source": "migrated-from-wordpress",
   "date": null,
   "consent": null,
   "published": true
  },
  {
   "quote": "I always loved tech, but these courses showed me how to actually make things work. Now I'm working on a project that could enter our school's science fair!",
   "name": "Taylor M",
   "role": "Teen student",
   "source": "migrated-from-wordpress",
   "date": null,
   "consent": null,
   "published": true
  },
  {
   "quote": "I thought robotics was only for engineers, but Tinker With Me made it easy and fun. Now I'm building projects I never imagined I could do.",
   "name": "Whitney R",
   "role": "Adult learner",
   "source": "migrated-from-wordpress",
   "date": null,
   "consent": null,
   "published": false
  },
  {
   "quote": "Learning here feels like playing. Every project gives me a little win and a big smile.",
   "name": "Daniel W",
   "role": "Adult learner",
   "source": "migrated-from-wordpress",
   "date": null,
   "consent": null,
   "published": false
  }
 ]
}$seed$::jsonb),
  ('posts', $seed${
 "_comment": "Blog posts for blog.html and post.html. Add an entry here and it appears on both, newest first. Dates are ISO. 'body' is HTML.",
 "posts": [
  {
   "slug": "why-ai-literacy-matters",
   "title": "Why AI literacy matters for kids — and why coding isn't the starting point",
   "date": "2026-08-12",
   "tag": "AI",
   "readingTime": 4,
   "excerpt": "Children are growing up surrounded by AI. Almost none of them are being taught how it works, how it learns, or how to use it responsibly.",
   "body": "<p>Children are growing up surrounded by artificial intelligence. It is in their phones, their social media feeds, the tools they use at school, and the games they play after it. For most of them, AI is simply part of the weather.</p><p>Yet almost none of them are ever taught how AI actually works, how it learns, or how to use it responsibly. We hand children an extraordinarily powerful technology and then say nothing about it.</p><h2>Coding is not the first step</h2><p>The instinct is to jump to programming. Teach them Python, the thinking goes, and understanding will follow. In our experience it rarely does — and it puts a hard barrier in front of children who do not have a laptop at home, a reliable connection, or an adult who can debug with them.</p><p>Understanding comes first. A child who can explain, in their own words, that a model learns from examples — and that biased examples produce biased answers — has something more durable than a child who can copy a script.</p><h2>What we teach instead</h2><p>Our AI Skills for Kids course is built for ages 7 to 9, and it needs no coding, no expensive devices, and no constant internet access. Learners work through what AI is, how it learns from data, where it goes wrong, and what it means to use it honestly.</p><p>The goal is not to produce young engineers. It is to produce young people who can look at a confident-sounding answer on a screen and ask the right question: how does it know that?</p><p>The course is free. If your child is curious, that is the only prerequisite.</p>"
  },
  {
   "slug": "screen-time-to-skill-time",
   "title": "From screen time to skill time",
   "date": "2026-07-29",
   "tag": "Parents",
   "readingTime": 3,
   "excerpt": "Your child is already spending hours on a screen. The question is whether they come away from it having made something.",
   "body": "<p>Is your child spending hours scrolling — but not building? It is the question we hear most often from parents, usually with a note of guilt attached to it.</p><p>The honest answer is that screen time is not the problem. Passive screen time is. There is an enormous difference between a child consuming an endless feed and a child using the same device to write a story, design a character, or work out why their code will not run.</p><h2>The shift is smaller than it looks</h2><p>Children who are handed a concrete project tend to stop scrolling on their own. Not because they were told to, but because making something is more interesting than watching something — provided the making is achievable and the first win comes quickly.</p><p>That is the whole design principle behind our workbook. It is built for ages 8 to 16, needs no prior experience, and moves a child from their first prompt to a finished, sharable project they can point at.</p><h2>What they come away with</h2><p>Not a certificate. A thing they made: a story they wrote with AI as a collaborator, a project they built and debugged, and — more importantly — the discovery that they are someone who makes things.</p><p>That discovery tends to outlast the specific tools. The tools will change. The self-image does not.</p>"
  },
  {
   "slug": "inside-robotics-101",
   "title": "What kids actually learn in Robotics 101",
   "date": "2026-07-15",
   "tag": "Robotics",
   "readingTime": 3,
   "excerpt": "Circuits, code and critical thinking — taught through builds children can hold in their hands at the end of the session.",
   "body": "<p>Robotics sounds intimidating to a lot of parents, and to a fair number of children. The word suggests engineering degrees and expensive kits. In practice, the entry point is a great deal friendlier than that.</p><h2>The three strands</h2><p>Robotics 101 introduces young learners to foundational robotics and coding through hands-on activities and problem-solving projects. Three things run through every session:</p><ul><li><strong>Electronic circuit assembly</strong> — how components connect, what each one does, and why a circuit fails when it fails.</li><li><strong>Basic coding</strong> — enough to make something move, respond, and behave the way the child intended.</li><li><strong>Critical thinking</strong> — the debugging habit. Something is not working; what changed, and what will you test first?</li></ul><h2>Why hands-on matters</h2><p>Complex topics become accessible when a child can hold the thing they are learning about. A servo that turns the wrong way teaches more in thirty seconds than a diagram teaches in ten minutes.</p><p>The projects are collaborative by design. Children work in pairs and small groups, which does two useful things: it makes the debugging social rather than lonely, and it means the child who understands the circuit explains it to the child who understands the code.</p><p>They leave with skills in technology, electronics and coding — and with something they built themselves.</p>"
  }
 ]
}$seed$::jsonb)
on conflict (key) do nothing;
