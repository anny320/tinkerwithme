-- Let the group quote builder's rates be edited in teach.html → Prices.
--
-- The rates live in a site_content row with key 'group_quote_pricing'. The
-- builder (group-quote.html) reads them for everyone through the existing
-- site_content_public() function; teach.html (admins only) saves them.
--
-- site_content.key has a CHECK that only allows a fixed set of keys, so we
-- widen it to include the new one, then seed the current defaults.
--
-- Run once in Supabase → SQL Editor, after site-content.sql. Safe to re-run.

alter table public.site_content drop constraint if exists site_content_key_check;
alter table public.site_content add constraint site_content_key_check
  check (key in ('courses', 'testimonials', 'posts', 'group_quote_pricing'));

insert into public.site_content (key, data) values
  ('group_quote_pricing', $j${
    "rate_3h": 4500, "rate_4h": 6000, "rate_full": 9000, "rate_term": 10000,
    "discount_pct": 10, "discount_min": 20, "kits_pct": 30,
    "ratio_day": 5, "ratio_term": 15, "trainer_cap": 10, "capacity": 50
  }$j$::jsonb)
on conflict (key) do nothing;
