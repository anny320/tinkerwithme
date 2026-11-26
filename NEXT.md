# Tinkerwith — Next tasks (pick-up notes)

_Last updated: 24 Nov 2026_

## ▶️ Do first when we resume
0. **Review & publish the new AI Comic Studio course** (owner) — the SQL is already run (it loaded as a **draft**). Open **teach.html → Courses → AI Comic Studio**, read the 6 lessons/quizzes, then **Publish** when happy. PR **#146** (cover + seed) is **open** — merge it so the cover file deploys. _Optional cleanup: the sample row "AI Comic Studio" still sits in `school-dashboard.html` demo data — harmless, now that a real course of that name exists, but can be swapped for another sample title._
1. **⭐ Submit sitemap to Google Search Console** (owner action — needs your Google login). At search.google.com/search-console, select the **tinkerwith.me** property (add it as a **Domain** property + DNS TXT verify if it isn't there), then **Indexing → Sitemaps** → submit `sitemap.xml` (now **~25 URLs**, incl. `teachers.html` + `resources.html`). Then watch **Indexing → Pages**. Sitemap + robots.txt + canonicals are already live. _Note: the "agentic OAuth" email from Google = no action needed (Sign-in-with-Google is auth only)._
2. **Verify the teacher waitlist end-to-end** (owner): on the live teachers page submit a test signup, then confirm it shows in **teach.html → Leads** tagged `teacher-waitlist`.
3. **✅ Paystack — DONE (Nov 2026).** Storefront products live, **paid courses wired** (live key in use), and **membership recurring billing** (Plans + webhook) working. No action left here — see Shipped.

## 🧲 Homepage conversion optimisation (CRO) — concepts + scorecard
_Added 10 Nov 2026. Goal: rebuild the homepage to cut selection fatigue (34 courses) and lift sales + platform usage._

**Prototypes (private Claude artifacts — open/share from Claude Code):**
- **Homepage concept ("Concept C")** — slider hero → "what kids built" showcase → **"Life at the camp" gallery** → 30-second age+interest **course router** (one free recommendation + premium upsell) → premium tracks (Robotics vs AI) → membership **"club"** band (Club KES 2,000/mo · Premium KES 6,500/mo, card-or-M-Pesa, 10-day refund) → email capture → quiet teacher/school door. Uses **real Fireside-camp photos with faces blurred**.
- **Content-editor concepts** — a single-page "Homepage content editor" and a multi-page "Site content editor": swap images / add a gallery / edit regions behind the existing **Clerk + `lms_admins` + Supabase** admin gate; each region tagged **SEO-in-HTML** vs **loaded-live**.

**Scorecard (LIFT + Cialdini + 5-second test) — overall ≈ 3.6/5.** Strong value prop + risk-reducers; under-converting on **urgency, authority, and a single clear CTA**.
- LIFT: Value prop 4.5 · Relevance 3.5 · Clarity 3.5 · **Urgency 2.5 (weakest)** · Anxiety/risk 4 · Distraction 3.
- Cialdini: reciprocity ✅ · social proof ✅ (thin on numbers) · commitment ✅ · liking ✅ · **authority ⚠ underused** · **scarcity ⚠ near-zero since Founding-100 removed (PR #130)**.

**Prioritised optimisations (by sales impact):**
1. **Ethical urgency** (biggest gap after PR #130): "Premium cohorts **max 8** — limited spots", next cohort / live-session start date, term/holiday timing. Real scarcity, not fake timers.
2. **One dominant CTA per screen:** hero leads with **"Start a free project"**; membership CTA **"See membership" → "Join the Club"**.
3. **Authority / trust strip:** live **Kenyan trainers**, team of 10, **6 partner-school** logos, a **safeguarding** line — near the CTAs.
4. **Social proof with numbers + stars:** "Join **170+ families**", ★★★★★, families in _N_ countries, 2–3 **consented** parent quotes.
5. **Pricing clarity / anchoring:** Free → Club → Premium comparison so **Club is the easy default**; annual "2 months free"; value-stack beside price.
6. **Cut distraction:** slow / simplify the auto-rotating hero slider (carousels test poorly); keep the spine **free → club**.
7. **Lead with the wedge:** **"no expensive kit — everyday parts"** at headline level (unique, local, objection-killing).

**Governance / caveats:** camp photos must keep **faces blurred** before publish (no reliable auto-blur yet); testimonials need **written consent** (`testimonials.json` is currently unconsented); static site (GitHub Pages) → keep **SEO-critical copy in HTML**, load images/gallery/prices live.

**Status (10 Nov):** tackling the most urgent now — (1) ethical urgency + (2) single dominant CTA on the concept — then wire Concept C into `index.html` (keep the existing footer/nav) + add a `site_content` table and a "Homepage/Site content" tab in `admin.html`.

## 🗂️ Backlog (priority order)

### Teachers / tutors (continue #25)
- **Decide curriculum price tiers**, then wire them (`curriculum.html` + Paystack). Owner to set numbers:
  - Single curriculum: **KES 1,500 / $10** (set — keep low for KE teachers, on-strategy).
  - **All-17 bundle** (e.g. ~KES 12,000 vs 25,500 à la carte) — number TBD.
  - **School / multi-teacher licence** — quote (the thesis's $1,000 line).
  - **International** (private / overseas schools) — higher USD tier (the $2,500 line).
  - Approach: **anchor the value** (already added: "part of our KES 9,000 live course") + add a **"what's inside" preview**, rather than raising the base price.
- **Dedicated teacher role (Supabase + Clerk)** — the gated side. A `lms_teachers` row (school, phone, subjects, `pending`/`approved`); self-serve "I'm a teacher" signup → pending → **approve in teach.html** → access to teacher-only resources (answer keys, slide decks, tutor certification). Keep authz in Supabase (like `lms_is_admin` / `lms_has_curriculum`); Clerk = identity only. _(Owner said Supabase + Clerk work happens next week.)_
- **Leads filter / tab in teach.html** so `teacher-waitlist` signups are easy to see (currently mixed into the general Leads list).
- **Tutor certification + community** (the rest of #25): the self-paced teacher course, outcomes/skill-check reports — flagged "coming soon" on the site; build when ready.

### Revenue
- **#28 — Membership (Club / Premium)** — _page + schema built. Paystack **approved (25 Oct)** → recurring billing now buildable (was the blocker)._
  - **⭐ OFFERING MODEL (locked 25 Oct — brainstorm + Thiel critique) — three intents: Free / Club / Premium.** **Repositioned around the monopoly:** live + local + community + kit-optional + outcomes (the un-commoditisable moat), NOT "number of courses" (the depreciating part AI is commoditising). Lead with the live Kenyan trainers, the maker cohort/Builds Wall, and "build with what you have."
    - **Free** (KES 0): the 34 build-alongs + Builds Wall + certificates. The funnel.
    - **Club** (standard KES 2,000/mo · 20,000/yr): a **monthly live group session** (Kenyan trainer) + the maker community + the **AI self-paced courses** (browser-only) + new monthly build + family plan.
    - **Premium** (standard KES 6,500/mo · 65,000/yr): Club + a **small live cohort (max 8 + your own trainer, 2 classes/mo)** + **all 17 courses incl. the robotics lab — kit-optional** (everyday parts + free simulator; Maker Kit is an optional upsell, never a gate — fixes the thesis contradiction) + **parent progress reports** + **termly demo day + print-at-home certificate & shareable skill badges** (physical mailing dropped — unreliable in KE) + priority + early access.
    - **Capacity:** **10 trainers → multiple Premium cohorts in parallel** (grouped by age/level). Premium is a scalable growth engine, not a bottleneck; Founding 100 is easily serviceable.
    - **Early-bird = Founding 100 (scarcity, not a price war):** first **100 families** reserve-AND-pay now at **40% off locked for 12 months** (Club KES 1,200/mo, Premium KES 3,900/mo), get **lifetime founding status** + founders wall + first access. **10-day money-back** guarantee, tightened to *not-yet-consumed* (no completed course / no live session) to stop gaming. Join form tags payments `[EARLY-BIRD …]`; approve with **`lms_grant_membership_early`** (sets `early_bird` + `early_bird_until = +12mo`).
    - **Distribution baked in:** referral (WhatsApp share → both get a free month, manual for now) · schools channel card → `schools.html` (B2B2C, bypasses per-family CAC) · free→paid trigger at free-project completion (**still to build on `course.html`/free-for-kids**).
    - **Course tier flags:** `membership_tier='club'` on the AI courses, `='premium'` on the robotics courses. lms_can_access gates by rank.
    - **Still owed before it's fully truthful:** the self-paced courses must exist in the LMS (see Content section); live sessions/cohort/reports/demo day must run; auto-renew needs the Paystack webhook (PR #104). **Shipped as a soft-launch** ("soon" chips + Founding-100 framing).
  - **Prices:** standard Club **KES 2,000/mo · 20,000/yr**, Premium **KES 6,500/mo · 65,000/yr** (in `lms_membership_price()`). Founding early-bird: Club **1,200**, Premium **3,900** (40% off, 12 months). One account = **family plan**.
  - **Positioning reach:** hero/meta say **"young African makers"** (not "Kenyan") — Kenya-first in delivery, African in identity; Paystack (approved) covers multiple African countries, online/AI content is pan-African, only M-Pesa + physical kit are Kenya-centric. Easy to revert to Kenya-only.
  - **Course list + timetable modal:** a "See courses & timetable" link on each tier opens a modal — the full catalog (34 free + 17 paid) with **Free/Club/Premium badges** and ⭐ popular flags (AI = Club & Premium, robotics = Premium · kit-optional), plus a **PROPOSED live timetable** (Club monthly session + Premium cohorts by age/level, EAT). _Owner: confirm the real session days/times; it's drafted as a placeholder._
  - **Built:** `membership.html` (3-tier, live/local repositioning, Founding-100 banner + `lms_founding_spots` counter, early-bird reserve+pay, referral + schools band, courses+timetable modal, FAQ) + `index.html` membership band + `supabase/membership.sql` (base) + **`supabase/membership-earlybird.sql`** (`early_bird`/`early_bird_until` cols, `lms_grant_membership_early`, `lms_founding_spots`, `lms_early_bird_renewals`).
  - **To do:** (1) **run `supabase/membership.sql`** then **`supabase/membership-earlybird.sql`**; (2) set `membership_tier` per course (`'club'` on AI, `'premium'` on robotics — bottom of membership.sql); (3) **approve `[EARLY-BIRD …]` payments with `lms_grant_membership_early`** (standard ones with `lms_grant_membership`); (4) honour referrals (add a free month to both accounts) manually for now; (5) at renewal, run **`lms_early_bird_renewals()`** to find founding members whose 40%-off window is ending; (6) **Paystack Plans + webhook** for auto-renew — see PR #104. Until then members are activated the manual-approve way.
- **✅ #27 — Paystack finish — DONE (Nov 2026):** paid courses wired and live (`pk_live_`), storefront products created. See Shipped.

### Shipped (Oct 25) — Paystack (PR #104, merged to main)
- **Paid courses → Paystack** (#27): `course.html` inline **Pay with Paystack** button (card/M-Pesa) + a Paystack radio in the paste-fallback form; wires `paystack.js`. Hidden until `CONFIG.paystackKey` is set. One-time, manual-approve.
- **Membership auto-renew** (#28): `supabase/functions/paystack-webhook/index.ts` (verifies `x-paystack-signature` HMAC-SHA512 over the raw body, service-role-only RPC, retry-safe/idempotent) + `supabase/paystack-subscriptions.sql` (`lms_apply_paystack_membership` [service_role only], `lms_paystack_plans` map, `lms_paystack_plan()`, Paystack id/email cols on `lms_memberships`) + `membership.html` auto-renew **Subscribe** button (dormant until keys+plans set — **not used in the founding reserve-and-pay phase**; the offering PR keeps the reserve-and-pay flow) + README. `lms.js` `CONFIG.paystackPlans`, `paystack.js` `plan` passthrough.

### Content (the thing membership unlocks)
- **✅ DONE (Nov 2026) — Premium courses built into the LMS as self-paced student courses.** _(History below kept for context; confirm `membership_tier` flags are set per course.)_ Right now a learner's only touchpoints with premium content are **booking a tutor** or **downloading the full PDF**. Add a **third mode**: the course lives in the LMS (`lms_courses` + lessons) so a student can **go back and review after a session**, at their own pace. This is what the membership unlocks — until these exist, Club/Premium are partly ahead of the content (the page soft-launches with "soon" labels). Plan: turn each premium curriculum into a published `lms_courses` row with lessons (reuse the generator's structured content), then set `membership_tier` — **`'club'` on the 8 AI courses, `'premium'` on the 9 robotics courses**. **Standalone prices = `premium_courses.json` `price`** (the original full course price, KES 5,000–9,000: 5,000 Smart City / AI Game Designer / AI Movie Studio; 7,000 the mid tier; 9,000 Smart Home / Self-Driving Car / AI Entrepreneur / AI for Social Good / Smart City 2.0). Courses stay purchasable standalone at those prices **and** are unlocked by Club/Premium membership (tier-aware `lms_can_access`). Do **not** price them at `self_paced_price` (3,000/3,500) — that was an error, fixed. Author premium lesson bodies into Supabase, not GitHub.

### Group sessions / B2B & quote builder (from the 22 Nov session)
- **Review & publish AI Comic Studio** (owner — see Do-first #0) and merge PR #146.
- **Confirm the group-session rates** in teach.html → Prices now that they're editable (defaults seeded: 4,500 / 6,000 / 9,000 / 10,000, 10% discount >20, +30% kits). Adjust to real numbers anytime — no code change.
- **✅ DONE — longer programme path added:** `group-quote.html` now has a **Full-year club (3 terms)** at KES 27,000/child (10% off 3×term), weekly 1hr sessions, editable in teach → Prices (`rate_year`). _Note: the live `group_quote_pricing` row predates `rate_year`, so the builder uses the 27,000 default until you Save once in teach → Prices (which writes it); no SQL re-run needed._
- **Optional: per-course `og:image` prerender** so social-link previews show the right share image (covers now exist; link unfurls still use the generic OG image).
- **Pattern proven:** AI Comic Studio is a net-new **self-paced course authored directly as a SQL seed** (course + lessons + quizzes). Reuse this seed pattern for any **future courses** (the 17 premium ones are already in the LMS).

### Standing / cleanup (do together)
- **#22** strip `project_content` off GitHub · **#21** point the curriculum generator at Supabase (reader move) · **#23** route generator output to Supabase.

### UX review (courses now online)
- **Review the planner → inquiry UX now that the courses are live in the LMS.** The session planner (`picker.html`), camp planner (`camp-planner.html`) and the curriculum generator all previously ended in a **PDF preview / download** as the main outcome — a lot of work went into those previews. Now that the 17 courses exist online, revisit each planner's end-state so an enquirer is also routed to the matching **online course / membership**, not only the PDF: add "see this as a self-paced course" / "enquire" CTAs alongside the preview, and check the preview-PDF step still makes sense as the primary call-to-action. Audit all three flows for consistency with the new online offering. _(Partial: `schools.html#enquire` now hands off to the group quote builder, and `picker.html` links to it. Still to do: `camp-planner.html` + the curriculum generator, and "see this as a self-paced course" CTAs on the planners.)_

### Circuit Lab — browser Arduino simulator (`/circuit-lab/`)
_Added 24 Nov 2026. Free in-browser Arduino **Uno R3** teaching tool: **Guided** mode (kids edit the numbers, runs fully offline) + **Code** mode (real C++ → compiled → run live on a simulated ATmega328P via **avr8js**). Four lessons: Blink, Breathing/PWM, Traffic light, OLED. Built on branch `claude/arduino-visualization-tools-7mr5o7`. Guided mode is done and verified; Code mode ships with a **direct-to-container** compile path (no Supabase needed to compile)._

- **⭐ Owner: deploy the compiler + connect it** (makes Code mode compile for real). Files are in `circuit-lab/compiler/`. On your machine (needs flyctl + `fly auth login`): `cd circuit-lab/compiler` → set a unique `app` name in `fly.toml` → `fly launch --no-deploy && fly deploy` → paste the printed URL into `COMPILE_ENDPOINT` in `circuit-lab/index.html`, commit & push. Then **verify in a browser**: compile a Blink/Traffic sketch and confirm the LED + serial + PWM behave (the avr8js engine is verified in Node, but the live round-trip, PWM-brightness and serial timing still need one real-browser pass). First compile after idle cold-starts a few seconds (~1 GB image); cache makes the rest instant.

- **TODO — (optional) harden the compile path with a Supabase Edge Function gateway.** _Only needed if the open container URL gets abused — CORS stops other sites, but anyone can still `curl` it; today's rate-limit + size-cap + timeout keep that bounded. The page's compile contract is identical, so switching is just a URL + auth-header change._ Puts Clerk auth + a shared, persistent hex cache in front of the `arduino-cli` container. **Requirements:**
  1. **`tw_compiles` cache table** (one SQL run in the SQL Editor, like `builds.sql`): `sketch_hash text primary key, board text, hex text, hits int default 0, created_at timestamptz default now()`; RLS on, no anon policy; written/read by the function via the **service role** (keep `lms.sql` conventions — `lms_uid()` / `lms_is_admin()` for any admin view).
  2. **`compile` Edge Function** (TypeScript/Deno, in `supabase/functions/compile/`): verify the **Clerk JWT** (reuse the existing auth pattern), per-user rate-limit, check `tw_compiles` → on hit return cached hex, on miss `fetch` the container (`COMPILER_URL`), store the hex, return `{hex, cached}`. **Same contract** as now: `POST {board, source}` → `{hex, cached}` / `{error}`.
  3. **Secrets + deploy via the Supabase CLI** (not SQL): `supabase secrets set COMPILER_URL=https://<app>.fly.dev/compile` then `supabase functions deploy compile` (mirror the `paystack-webhook` deploy note). Needs the container deployed first (it's the upstream).
  4. **Lock the container** so only the function can reach it (set `ALLOW_ORIGIN` to the function origin, or keep the container private / behind a shared token the function sends).
  5. **Frontend switch:** point `COMPILE_ENDPOINT` at the function URL and send the Clerk token in `COMPILE_HEADERS` (`{ Authorization: 'Bearer ' + token }`). No other page changes.
  - **Depends on:** Supabase CLI + `supabase login` (owner machine); the Fly/Render container live; the existing Clerk/`lms_*` auth. Cross-refs the "Dedicated teacher role (Supabase + Clerk)" work — same auth plumbing.

- **TODO — OLED display emulation** (so the on-screen-graphics lesson also runs real compiled code): add an I2C (`AVRTWI`/`twiConfig`) + SSD1306 command parser that draws to the existing `#oled` canvas. Until then the OLED lesson falls back to the built-in preview (the UI says so).
- **Nice-to-have:** wire `/circuit-lab/` into `courses.html#arduino` as a free "try it" tool and/or repoint a stub like `first-circuits-lights/`; more lessons (button→LED input, servo sweep); preview images are in `circuit-lab/previews/` for marketing/social.

### Nice-to-have
- Normalise relative `og:image` paths to absolute on older pages (index, free-for-kids).

## ✅ Shipped & live on main

### Paystack go-live + premium courses in the LMS (Nov 2026)
- **✅ Paystack fully live** — all 17 **storefront products** created (covers + descriptions + after-purchase settings), **paid courses** check out via Paystack on-site (live key in use, not just curriculums), and **membership recurring billing** (Paystack Plans + webhook Edge Function) is working so Club/Premium auto-renew. This closes old #27 and the recurring-billing blocker on #28.
- **✅ Premium courses built into the LMS** — the 17 premium courses now exist as self-paced `lms_courses` with lessons (the "third mode" alongside booking a tutor / downloading the PDF), so learners can review at their own pace. This was the ⭐ Content blocker membership depended on. _(Set/confirm `membership_tier` per course — `'club'` on AI, `'premium'` on robotics — if not already.)_

### Group quote system + Prices admin + AI Comic Studio (Nov 20–22)
- **Group session quote builder** (`group-quote.html`, PRs #143/#144) — B2B quote tool for schools/camps/hotels/companies. One-off sessions (3h KES 4,500 / 4h 6,000 / full day 9,000, with the **4-hour anchored as "Popular"**) + **8-week after-school club KES 10,000/child/term** (benchmarked vs Nairobi clubs; 8×1hr, 1 trainer per 15). Group discount (10% off per child, only with the checkbox **and** >20 learners), kits +30%, outside-Nairobi travel note, 1-per-5 trainers (cap 10), 50-learner capacity → multi-day/parallel groups. **Printable proforma invoice** (Wakara Technologies, quote no., valid-to-month-end, M-Pesa Till 3022049, email + WhatsApp, out-of-Nairobi transport clause payable before signing, fine-print **payment terms 70% advance / 30% on delivery, 5%/week late surcharge**). Linked from `picker.html`, `schools.html`, and the homepage (`index.html` nav "Learn" + footer Tools).
- **Quote → Leads pipeline** (PR #144) — "Send this query to Anne" posts to `lms_submit_lead` (`source: 'group-quote'`) so quotes land in **teach.html → Leads** with a 🧾 pill; WhatsApp fallback; `schools.html#enquire` has a "Build an instant quote" hand-off that pre-fills the builder.
- **Prices tab in `teach.html`** (PR #145) — (a) **course prices & discounts** overview with inline per-row editing (price KES/US$, launch offer + end date, 🏷️ live-offer flag); (b) **group session rates** editor (all the quote-builder knobs) saved to `site_content` key `group_quote_pricing`; the builder reads them live via `site_content_public()` and falls back to defaults. **SQL run:** `supabase/group-quote-pricing.sql` (widened the `site_content` key CHECK).
- **AI Comic Studio course** (PR #146, **open**) — self-paced online course, ages 7–16, **KES 3,500 / US$45**, loaded as a **draft** via `supabase/ai-comic-studio-course.sql` (**run**). 6 lessons + quizzes (comic basics → invent character → plan panels → draw with AI → bubbles/SFX → publish), lesson 1 free-preview, illustrative title-free cover. _Owner to review & publish._

### Covers, school licensing, MakerBreaker, social (Nov 11–19)
- **Course covers redesigned** — illustrative, title-free SVGs for all free + 17 premium courses (PRs #140–#142); `supabase/course-covers.sql` repoints `cover_url` (DB is source of truth for curated/learn pages). Separate share-images-with-title per course.
- **Schools / B2B licensing** (PR #138) — `supabase/school-licensing.sql` (orgs/seats/codes/roster + RPCs), Schools admin in both `admin.html` and `teach.html`, `school-dashboard.html` (utilisation + termly report + CSV + embed), schools.html dashboard teaser.
- **MakerBreaker** (PR #139/#140) — teardown finder + quarterly event booking + downloadable safety-guide PDF.
- **Social share widget** sitewide (`social.js`) + TikTok/IG (@tinkerwith_anne); AI Explorer Journal rebuilt with read-aloud.

### Earlier this build
- Publish/Unpublish button on the course manager (teach.html)
- Supplier names stripped from Arduino lessons; **Kenya kit-sourcing kept on the teacher PDFs**; Tinkerwith **logo on all generated PDFs**
- All **17 premium curricula** generated → private Supabase bucket
- **13 AI lessons** rewritten to student-attempting POV
- **Free courses published**; **Free-for-kids redesign** (one big-card block, covers, jump-nav)
- **Engagement flywheel**: share-your-build + moderation + Builds Wall + live counters + admin traction view
- **Privacy policy** updated for children's *project* photos
- **Paystack** one-time curriculum wiring (storefront button + reference auto-capture + `paystack` method)
- **Anti-cannibalisation**: free "Robots & Smart Builds" renames + "Go deeper" upsells

### Recent (Oct 25)
- **Membership offering redesign → 3 tiers** (branch `claude/membership-offering`, **PR open**) — reframed around three learner intents (Free / Club / Premium). `membership.html` now shows a 3-tier table (Free KES 0 → Club KES 2,000 + 7-day trial KES 1,000 → Premium KES 6,500), with the AI/robotics split, luxury Premium features (small cohort, parent reports, demo day) and **soft-launch "soon" labels + founding-member framing** (content/live ops not live yet). Homepage (`index.html`) gets a **Membership intro band**. `supabase/membership.sql` tier-flag guidance updated for the AI=club / robotics=premium split. See the OFFERING MODEL block under #28.
- **Membership pricing finalised** (merged) — Premium cadence fixed from "a weekly live group class" to **two live group classes a month** (held at **KES 6,500/mo · 65,000/yr**). **Club raised to KES 2,000/mo · 20,000/yr** (was 1,500). — Premium cadence fixed from "a weekly live group class" to **two live group classes a month** (price held at **KES 6,500/mo · 65,000/yr** — live instruction justifies the premium multiple). **Club raised to KES 2,000/mo · 20,000/yr** (was 1,500). Updated in `membership.html` (PRICES, tier feature, both FAQs, all three meta descriptions), `supabase/membership.sql` (`lms_membership_price` + header), and the #28 note above. Rendered clean, no JS errors.

### Recent (Oct 16–19)
- **Course certificate fix** — reading-only lessons auto-complete on Next/Finish, so finishing a course reliably unlocks the certificate (scrolls straight to it)
- **Holiday "34 free projects" campaign** — homepage banner ("Swap 'I'm bored' for 'I built a robot'") + poster-matched "34 projects / 10 courses" copy across homepage + free-for-kids
- **Sitewide SEO pass** — `robots.txt`, `sitemap.xml`, canonicals on all public pages, OG/Twitter tags, Organization + Course JSON-LD, `noindex` on admin
- **share.html** mobile dropzone fix
- **The Teachers' Workbench** (`teachers.html`) — "tinker with what you have" positioning; "For teachers" nav + footer sitewide; mobile menu surfaces **Free for kids + For teachers** at the top; illustrations + trimmed copy
- **Resources guide** (`resources.html`) — everyday-parts → each of the 17 projects; **microcontroller = the one core buy**, everything else optional
- **Teacher waitlist form** — name / email / WhatsApp / ages taught / goals → `lms_submit_lead` (`source: 'teacher-waitlist'`); works now, no new backend
- **Free-vs-full value ladder** on the teachers page — concrete **Self-Driving Car** example (free obstacle-avoider taster → full 3-session curriculum)
- **curriculum.html** — value anchor on the buy box + **admin-preview label** (so the admin preview is never mistaken for a leak)
- **Kit-optional for kids** — homepage FAQ + Robotics 101 no longer imply a kit is required
- Landing **"I'm a teacher"** card in "Where do you fit in?"

## 🔎 Verified (reassurances)
- **No premium leak.** The 17 `proposals/*.pdf` are 2-page marketing brochures (verified — no code/wiring/step-by-step). The full curriculum downloads are gated by `lms_has_curriculum` = **admin OR a purchase row**, enforced in the frontend **and** a storage RLS policy. The "leak" scare was the admin preview.
- **GA4** (`G-26H8GCM572`) via `analytics.js` is on **all** pages, incl. `teachers.html` + `resources.html`.

## 💵 Pricing reference
- Curriculum (teacher PDF download): **KES 1,500 / $10**
- Live course: **from KES 9,000** (per course, varies)
- Maker Kit (optional hardware): **KES 8,500**
- Strategy: affordability is the thesis's core, so keep the **individual KE** curriculum price low; capture more via **bundle / school / international** tiers and by **anchoring value**, not by raising the base.

## 🔑 Operating reminders
- **Supabase writes are manual**: Claude shares SQL files, owner runs them in the SQL Editor. No service-role key in play.
- **Premium curriculum content is PDF-only** → generated in the workflow → private Supabase bucket; never committed to GitHub.
- Keep `project_content` for now (the generator depends on it); GitHub cleanup is a standing task (#22).
- Deliverables for the owner go in the working directory / scratchpad so they open in the app.

## 📦 Deliverables already handed over (for the storefront)
- 17 curriculum cover images (PNG + SVG)
- Curriculum descriptions (Word doc)
- Paystack After-Purchase settings per product (Word doc)
