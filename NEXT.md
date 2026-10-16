# Tinkerwith — Next tasks (pick-up notes)

_Last updated: 16 Oct 2026_

## ▶️ Do first when we resume
1. **⭐ Submit sitemap to Google Search Console** (owner action — needs your Google login). At search.google.com/search-console, select the **tinkerwith.me** property (add it as a **Domain** property + DNS TXT verify if it isn't there), then **Indexing → Sitemaps** → submit `sitemap.xml` (expect ~23 URLs). Then watch **Indexing → Pages**. The sitemap + robots.txt + canonicals are already live on the site (SEO pass merged). _Note: the "agentic OAuth" email from Google = no action needed; Sign-in-with-Google is auth only, not a Workspace AI agent._
2. **Paystack storefront** (once the account is approved, ~7 days): create the 17 products on `paystack.shop/tinkerwith-store` using the delivered **cover images**, **descriptions** (Word doc), and **After-Purchase** redirect + success message (Word doc). Optionally add each product URL into `premium_courses.json` as `paystack_url` for per-product deep links.

_(All Supabase SQL for this session is already run: supplier removal, AI student-POV, publish, Paystack method, and the Robots renames/upsells.)_

## 🗂️ Backlog (priority order)
- **#28 — Membership subscription** (Club ~KES 2,000 / Premium ~KES 7,000): tiers, member access gating, Paystack **Plans + webhook** (the one bit of server code — a Supabase Edge Function verifying Paystack signatures with the secret key), live-class access. Recurring revenue — biggest next build. Card subscriptions auto-renew; M-Pesa members pay monthly via a request.
- **#24 → #25 — Teachers/Tutors hub → tutor community + certification.**
- **#27 — Paystack finish**: wire paid courses too (not just curriculums); test live with `pk_test_`, then flip to `pk_live_`. Optional later: inline on-site checkout (scaffolding already in `paystack.js` + `lms.js` `CONFIG.paystackKey`).
- **Standing / cleanup (do together):** **#22** strip `project_content` off GitHub · **#21** point the curriculum generator at Supabase (reader move) · **#23** route generator output to Supabase.

## ✅ Shipped & live on main (this session)
- Publish/Unpublish button on the course manager (teach.html)
- Supplier names stripped from Arduino lessons; **Kenya kit-sourcing kept on the teacher PDFs**; Tinkerwith **logo on all generated PDFs**
- All **17 premium curricula** generated → private Supabase bucket
- **13 AI lessons** rewritten to student-attempting POV
- **7 free courses** published and live
- **Engagement flywheel**: share-your-build (you approve first) + moderation + Builds Wall + live counters + admin traction view
- **Privacy policy** updated for children's *project* photos (not child photos)
- **Paystack** one-time curriculum wiring (storefront button + reference auto-capture + `paystack` payment method)
- **Free-for-kids redesign**: one prominent big-card "Free online courses" block (7 curated + 3 classics), covers for all, jump-nav
- **Anti-cannibalisation**: free "Robots & Smart Builds" renames ("Robot arm basics", "Mini smart city") + "Go deeper" premium upsells

## 🔑 Operating reminders
- **Supabase writes are manual**: Claude shares SQL files, owner runs them in the SQL Editor. No service-role key in play.
- Keep `project_content` for now (the curriculum generator depends on it); GitHub content cleanup is a standing task (#22).
- **Premium curriculum content is PDF-only** → generated in the workflow → private Supabase bucket; never committed to GitHub.
- Deliverables for the owner go in the working directory / scratchpad so they open in the app.

## 📦 Deliverables already handed over (for the storefront)
- 17 curriculum cover images (PNG + SVG)
- Curriculum descriptions (Word doc)
- Paystack After-Purchase settings per product (Word doc)
