-- AI Comic Studio — a self-paced online course, loaded as a DRAFT.
--
-- Run once in Supabase → SQL Editor, after lms.sql. It inserts the course and
-- its lessons. Re-running does nothing (the slug already exists), so it won't
-- duplicate — but it also won't update an existing one. If you want to reload a
-- fresh copy, first: delete from public.lms_courses where slug='ai-comic-studio';
-- (that also removes its lessons and any progress — only do it before go-live).
--
-- After it runs: teach.html → Courses → "AI Comic Studio" to review, then
-- Publish when you're happy. Price KES 3,500 / US$45, ages 7–16.

with c as (
  insert into public.lms_courses
    (slug, title, summary, description, age_range, cover_url, price_kes, price_usd, is_published, position)
  values (
    'ai-comic-studio',
    'AI Comic Studio',
    'Invent a character, write a short story, then use AI to draw the panels and build your very own comic — no drawing skills needed.',
    $d$## Make your own comic — with AI as your art studio

You don't need to be able to draw. In **AI Comic Studio** you become the writer and director of your own comic, and you use AI tools to help you draw the pictures.

You'll invent a character, build a short story, turn it into comic panels, generate the artwork with an AI image tool, and add speech bubbles and sound effects to finish it off. By the end you'll have a real comic you can print, share or read aloud.

Along the way you'll learn how to **talk to AI tools clearly** (prompting), how to keep a character looking the same from panel to panel, and how to stay the boss while the AI does the drawing.

**Who it's for:** ages 7–16 — younger makers keep it to 3 simple panels, older ones build longer, branching stories.

**What you'll need:** a free AI chat tool (ChatGPT or Microsoft Copilot), a free AI image tool (Bing Image Creator or Craiyon), and something to put it together (Canva or Google Slides). Everything works in a browser.

**What you'll make:** a finished 3–6 panel comic, and the skills to make many more.$d$,
    '7–16',
    'assets/courses/ai-comic-studio.svg',
    3500, 45, false, 100
  )
  on conflict (slug) do nothing
  returning id
)
insert into public.lms_lessons (course_id, position, section, title, body, quiz, is_preview)
select c.id, v.position, v.section, v.title, v.body, v.quiz::jsonb, v.is_preview
from c, (values
  (1, 'Start here', 'What makes a comic?',
   $b$## The building blocks of every comic

Before we make one, let's see how comics work. Every comic is built from a few simple parts:

- **Panels** — the boxes. Each panel is one moment in the story.
- **Characters** — who the story is about.
- **Speech bubbles** — what characters say. Pointy tail = speaking, cloud = thinking.
- **Captions** — the little boxes that say things like *"Later that day…"*.
- **Sound effects** — big fun words like **POW!**, **ZOOM!**, **CLICK**.

## Your mission for this lesson

1. Find a comic you like (a book, a newspaper strip, or one online).
2. Count the **panels** on one page.
3. Spot one **speech bubble**, one **caption**, and one **sound effect**.
4. Notice how the pictures change from panel to panel to move the story along.

## Think about it

A comic tells a story with **pictures + words together**. Neither one does the whole job — the magic is in the mix. Keep that in mind: in this course *you* write the words and direct the pictures, and AI helps draw them.$b$,
   $q$[{"q":"What is a single box in a comic called?","options":["A bubble","A panel","A caption"],"answer":1},{"q":"A speech bubble with a pointy tail shows that a character is…","options":["Thinking","Speaking","Sleeping"],"answer":1},{"q":"What carries a comic's story?","options":["Only the pictures","Only the words","Pictures and words together"],"answer":2}]$q$::jsonb,
   true),

  (2, 'Build your story', 'Invent your character and world',
   $b$## Every great comic starts with a character

Your comic needs someone worth following. Let's invent them — and use an AI chat tool to brainstorm.

## Step 1 — Fill in four boxes

- **Who:** a name and one personality word (e.g. *Zuri, brave*).
- **Where:** the setting (e.g. *a floating market in the sky*).
- **Wants:** what they're trying to get or do.
- **Problem:** what's in the way.

## Step 2 — Brainstorm with AI

Open your AI chat tool and try a prompt like:

> *"Help me invent a comic character for a young reader. Give me 3 ideas, each with a name, one personality trait, what they want, and a problem they face. Keep it fun and kid-friendly."*

Pick your favourite idea — or mix two together. **You decide**; the AI only suggests.

## Step 3 — Describe how they look

Write one clear sentence you can reuse every time you draw them, e.g.:

> *"Zuri, a 10-year-old girl with short curly hair and a yellow raincoat, cartoon style."*

Keep this sentence safe — you'll paste it into the image tool in every panel so your character stays the same.

## Tip

The AI can't read your mind. The more detail you give (hair, clothes, colours, style), the more the picture matches what's in your head.$b$,
   $q$[{"q":"When the AI suggests character ideas, who decides which to use?","options":["The AI picks for you","You do","Nobody — you must use the first one"],"answer":1},{"q":"Why write one clear description of how your character looks?","options":["To reuse it so the character stays the same in every panel","Because the AI needs your password","So the comic is longer"],"answer":0}]$q$::jsonb,
   false),

  (3, 'Build your story', 'Plan your story in panels',
   $b$## Turn your idea into panels

A comic is a story broken into moments. Each **panel** is one moment.

## Step 1 — The story shape

Most short comics follow: **Beginning → Problem → Try → Twist → Ending.** That's a great fit for 5 panels. Younger makers: use just 3 — *Beginning, Problem, Ending.*

## Step 2 — Draft it with AI

Give the AI your character and ask for a panel plan:

> *"Write a short comic script with 5 panels about Zuri, a brave girl in a sky market who loses her flying scooter. For each panel give: what we see, and one short line of dialogue. Keep it simple for a young reader."*

## Step 3 — Make it yours

Copy the script and **change at least 3 things** — a line of dialogue, a setting detail, the ending. The AI gives a starting point; your changes make it *your* comic.

## Step 4 — Write a picture note per panel

For each panel, jot what we should *see* (character + action + place). You'll turn these into image prompts in the next lesson.

## Think about it

Why break a story into panels at all? Because each box lets the reader pause on one moment — a bit like frames in a film.$b$,
   $q$[{"q":"A simple 5-panel story shape is…","options":["Beginning, Problem, Try, Twist, Ending","Just a title and the end","Ten random pictures"],"answer":0},{"q":"After the AI drafts your script you should…","options":["Use it exactly as-is","Change at least a few things to make it yours","Delete it"],"answer":1}]$q$::jsonb,
   false),

  (4, 'Make the pictures', 'Draw your panels with AI',
   $b$## Let AI draw — while you direct

Now turn each panel's picture note into an **image prompt** and generate the art.

## The prompt formula

**Character + Action + Setting + Style**

> *"Zuri, a 10-year-old girl with short curly hair and a yellow raincoat, riding a flying scooter over a busy sky market, cartoon style, bright colours."*

## Steps

1. Open your AI image tool (Bing Image Creator, or Craiyon if you're not signed in).
2. Paste your **character description** first, then add the action and setting for that panel.
3. Generate 2–3 versions and pick the best.
4. If it's wrong, fix the words and try again ("make the scooter smaller", "plain sky background").
5. Save each chosen picture in order (Panel 1, Panel 2, …).

## Keeping your character the same

The image tool has **no memory** between pictures — ask twice and you may get two different faces. The fix: paste the **same character description** into every panel's prompt. Same words → same-looking character.

## Tips

- **Weird result?** (extra fingers, odd text) — that's a real AI limit, not your mistake. Reword and retry.
- **Blocked prompt?** The tool refuses some things (violence, real people). Reword it — don't try to sneak past the filter.
- Plan your prompt before you click generate — free tools only give you so many tries.$b$,
   $q$[{"q":"A good image prompt includes…","options":["Character, action, setting and style","Only the word 'comic'","Your home address"],"answer":0},{"q":"Why might your character look different in each panel?","options":["The tool has no memory between pictures, so reuse the same description","The tool is broken","Because you used too few tries"],"answer":0},{"q":"If a prompt is blocked by the tool's safety filter, you should…","options":["Try to trick the filter","Reword it into something allowed","Give up on the whole comic"],"answer":1}]$q$::jsonb,
   false),

  (5, 'Finish & share', 'Add bubbles, captions and sound effects',
   $b$## Put the words back in

Pictures are ready — now add the words and lay it out like a real comic.

## Step 1 — Lay out the panels

Open **Canva** or **Google Slides**. Place your panel pictures in order, left to right, top to bottom.

## Step 2 — Add the talking

- **Speech bubbles** for dialogue — point the tail at who's talking.
- **Thought bubbles** (cloud shaped) for what someone is thinking.
- **Captions** (small boxes) for narration: *"Meanwhile…"*.

Keep text short — comics say a lot with few words.

## Step 3 — Add sound effects

Big, fun words make panels pop: **ZOOM!**, **CRASH!**, **TA-DA!**. Make them bold and colourful.

## Step 4 — Tidy up

Check the reading order flows, the character looks consistent, and every panel earns its place. Remove any panel that doesn't move the story.

## Think about it

You wrote the story, directed the pictures, and arranged it all. How much of the final comic was *made by you* versus the AI? (Hint: the ideas and the decisions were all yours.)$b$,
   $q$[{"q":"Which bubble shape shows what a character is thinking?","options":["A pointy speech bubble","A cloud-shaped bubble","A square caption"],"answer":1},{"q":"Good comic text is usually…","options":["Short and punchy","Long paragraphs","Invisible"],"answer":0}]$q$::jsonb,
   false),

  (6, 'Finish & share', 'Publish and share your comic',
   $b$## Share your comic with the world

You made a comic! Time to publish it and show it off.

## Step 1 — Export

In Canva or Slides, export your finished comic as a **PDF** or **image** so it's easy to share or print.

## Step 2 — Share it

- Read it aloud to family or friends.
- Print it as a little booklet.
- Send it to someone, or show it in your Tinkerwith group.

## Step 3 — Reflect

Answer these for yourself:

- What did the AI do well, and what did *you* have to fix?
- When did the AI surprise you?
- What would you change or add next time?

## Challenge yourself

- **Easy:** add one more panel with a new sound effect.
- **Medium:** make a 3-panel sequel with the same character (reuse your description!).
- **Hard:** make a *choose-your-own-adventure* comic with two endings — each path needs its own panels and art.

## Well done

You've learned to invent a character, plan a story, direct AI art, and build a finished comic. Those same skills work for posters, storybooks and animations too. Keep making!$b$,
   $q$[{"q":"What's a good way to save your comic for sharing or printing?","options":["Export it as a PDF or image","Leave it open in the app forever","Only screenshot one panel"],"answer":0},{"q":"For a sequel with the same character, you should…","options":["Invent a brand-new look each time","Reuse the same character description","Skip the character"],"answer":1}]$q$::jsonb,
   false)
) as v(position, section, title, body, quiz, is_preview);
