-- Let "This week's Tinker Challenge" be edited in teach.html → Challenge and
-- shown in the homepage hero corner.
--
-- Stored in a site_content row with key 'tinker_challenge'. The homepage reads
-- it for everyone via SiteData / site_content_public(); teach.html (admins) saves
-- it. site_content.key has a CHECK that only allows a fixed set, so we widen it
-- (keeping the group_quote_pricing key added earlier), then seed a default.
--
-- Run once in Supabase → SQL Editor, after site-content.sql. Safe to re-run.

alter table public.site_content drop constraint if exists site_content_key_check;
alter table public.site_content add constraint site_content_key_check
  check (key in ('courses', 'testimonials', 'posts', 'group_quote_pricing', 'tinker_challenge'));

insert into public.site_content (key, data) values
  ('tinker_challenge', $j${
    "active": true,
    "week": "",
    "headline": "Build something that moves using only recycled parts",
    "body": "Bottle caps, cardboard, an old motor — anything. Snap a photo or video of your maker creation and share it!",
    "image": "",
    "cta_text": "Share your build",
    "cta_url": "stories.html"
  }$j$::jsonb)
on conflict (key) do nothing;
