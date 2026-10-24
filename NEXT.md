# Tinkerwith — Next tasks (pick-up notes)

_Last updated: 24 Oct 2026_

## ▶️ Do first when we resume
1. **⭐ Submit sitemap to Google Search Console** (owner action — needs your Google login). At search.google.com/search-console, select the **tinkerwith.me** property (add it as a **Domain** property + DNS TXT verify if it isn't there), then **Indexing → Sitemaps** → submit `sitemap.xml` (now **~25 URLs**, incl. `teachers.html` + `resources.html`). Then watch **Indexing → Pages**. Sitemap + robots.txt + canonicals are already live. _Note: the "agentic OAuth" email from Google = no action needed (Sign-in-with-Google is auth only)._
2. **Verify the teacher waitlist end-to-end** (owner): on the live teachers page submit a test signup, then confirm it shows in **teach.html → Leads** tagged `teacher-waitlist`.
3. **Paystack storefront** (once the account is approved): create the 17 products on `paystack.shop/tinkerwith-store` using the delivered **cover images**, **descriptions** (Word doc) and **After-Purchase** settings (Word doc). Optionally add each product URL into `premium_courses.json` as `paystack_url`.

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
- **#28 — Membership (Club / Premium)** — _page + schema built; recurring billing pending Paystack._
  - **Pricing (locked):** Club **KES 1,500/mo · 15,000/yr** (all 17 self-paced courses + free projects + new monthly builds). Premium **KES 4,000/mo · 40,000/yr** (Club + **two live group classes a month**). One account = **family plan**. Prices live in `membership.html` + `lms_membership_price()`.
  - **Built:** `membership.html` (tiers, monthly/annual toggle, join/pay flow, member banner) + `supabase/membership.sql` (`lms_memberships`, `lms_my_membership`, `lms_member_rank`, `lms_has_membership`, `lms_submit_membership_payment`, admin `lms_grant_membership`; `lms_can_access` extended; `lms_courses.membership_tier` column). Nav/footer/sitemap link added.
  - **To do:** (1) **run `supabase/membership.sql`** in the SQL editor; (2) **set `membership_tier='club'`** on the self-paced course rows (example UPDATE at the bottom of the file); (3) **wire teach.html payment approval** to call `lms_grant_membership` when approving a `kind='membership'` payment (until then approve by running the RPC manually); (4) **Paystack Plans + webhook** (the one server-code bit — a Supabase Edge Function verifying signatures with the secret key) for true auto-renew, once Paystack is approved. Until then members are activated the same manual-approve way as curriculums.
- **#27 — Paystack finish**: wire **paid courses** too (not just curriculums); test with `pk_test_`, then flip to `pk_live_`. Optional later: inline on-site checkout (scaffolding in `paystack.js` + `lms.js` `CONFIG.paystackKey`).

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

### Recent (Oct 24)
- **Membership Premium corrected** (PR #102, branch `claude/membership`, **open**) — cadence fixed from "a weekly live group class" to **two live group classes a month**, and Premium repriced **KES 6,500→4,000/mo · 65,000→40,000/yr** (tracks the ~2 live hrs/mo it adds over Club). Updated in `membership.html` (PRICES, tier feature, both FAQs, meta descriptions), `supabase/membership.sql` (`lms_membership_price` + header), and the #28 note below. Rendered clean, no JS errors.

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
