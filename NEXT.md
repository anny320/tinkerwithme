# Tinkerwith — Next tasks (pick-up notes)

_Last updated: 24 Oct 2026_

## ▶️ Do first when we resume
1. **⭐ Submit sitemap to Google Search Console** (owner action — needs your Google login). At search.google.com/search-console, select the **tinkerwith.me** property (add it as a **Domain** property + DNS TXT verify if it isn't there), then **Indexing → Sitemaps** → submit `sitemap.xml` (now **~25 URLs**, incl. `teachers.html` + `resources.html`). Then watch **Indexing → Pages**. Sitemap + robots.txt + canonicals are already live. _Note: the "agentic OAuth" email from Google = no action needed (Sign-in-with-Google is auth only)._
2. **Verify the teacher waitlist end-to-end** (owner): on the live teachers page submit a test signup, then confirm it shows in **teach.html → Leads** tagged `teacher-waitlist`.
3. **✅ Paystack is APPROVED (25 Oct).** Recurring billing + live payments are now unblocked — see the Revenue section (#27/#28). Immediate: (a) create the 17 storefront products on `paystack.shop/tinkerwith-store` using the delivered **cover images**, **descriptions** (Word doc) and **After-Purchase** settings (Word doc), optionally adding each product URL into `premium_courses.json` as `paystack_url`; (b) decide the membership recurring-billing path (Paystack **Plans + webhook Edge Function** vs manual-approve for now) — Claude to scope the Edge Function.

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
    - **Premium** (standard KES 6,500/mo · 65,000/yr): Club + a **small live cohort (max 8 + your own trainer, 2 classes/mo)** + **all 17 courses incl. the robotics lab — kit-optional** (everyday parts + free simulator; Maker Kit is an optional upsell, never a gate — fixes the thesis contradiction) + **parent progress reports** + **termly demo day + mailed certificate** + priority + early access.
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
- **#27 — Paystack finish** (**account approved 25 Oct**): wire **paid courses** too (not just curriculums); test with `pk_test_`, then flip to `pk_live_`. Optional later: inline on-site checkout (scaffolding in `paystack.js` + `lms.js` `CONFIG.paystackKey`).

### Shipped (Oct 25) — Paystack (PR #104, merged to main)
- **Paid courses → Paystack** (#27): `course.html` inline **Pay with Paystack** button (card/M-Pesa) + a Paystack radio in the paste-fallback form; wires `paystack.js`. Hidden until `CONFIG.paystackKey` is set. One-time, manual-approve.
- **Membership auto-renew** (#28): `supabase/functions/paystack-webhook/index.ts` (verifies `x-paystack-signature` HMAC-SHA512 over the raw body, service-role-only RPC, retry-safe/idempotent) + `supabase/paystack-subscriptions.sql` (`lms_apply_paystack_membership` [service_role only], `lms_paystack_plans` map, `lms_paystack_plan()`, Paystack id/email cols on `lms_memberships`) + `membership.html` auto-renew **Subscribe** button (dormant until keys+plans set — **not used in the founding reserve-and-pay phase**; the offering PR keeps the reserve-and-pay flow) + README. `lms.js` `CONFIG.paystackPlans`, `paystack.js` `plan` passthrough.

### Content (the thing membership unlocks)
- **⭐ Build the Premium courses into the LMS as self-paced student courses** (owner-flagged). Right now a learner's only touchpoints with premium content are **booking a tutor** or **downloading the full PDF**. Add a **third mode**: the course lives in the LMS (`lms_courses` + lessons) so a student can **go back and review after a session**, at their own pace. This is what the membership unlocks — until these exist, Club/Premium are partly ahead of the content (the page soft-launches with "soon" labels). Plan: turn each premium curriculum into a published `lms_courses` row with lessons (reuse the generator's structured content), then set `membership_tier` — **`'club'` on the 8 AI courses, `'premium'` on the 9 robotics courses**. **Prices stay locked** to `premium_courses.json` (`self_paced_price`); author premium lesson bodies into Supabase, not GitHub.

### Standing / cleanup (do together)
- **#22** strip `project_content` off GitHub · **#21** point the curriculum generator at Supabase (reader move) · **#23** route generator output to Supabase.

### Nice-to-have
- Normalise relative `og:image` paths to absolute on older pages (index, free-for-kids).

## ✅ Shipped & live on main

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
