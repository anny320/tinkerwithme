# Online courses (Clerk + Supabase)

A simple course platform that replaces Tutor LMS on WordPress.

| Page | Who | What |
|---|---|---|
| `learn.html` | everyone | All published courses; "My learning" with progress when signed in |
| `course.html?c=<slug>` | everyone | Course overview, enrol, lessons (text, pictures, YouTube), quizzes, certificate |
| `teach.html` | admins | Create and edit courses and lessons, build quizzes, upload pictures, enrol students |

```
Browser ── Clerk (sign-in, Google or email) ──▶ session token
        ── Supabase (with that token) ────────▶ courses, lessons, progress
                                                 rules in lms.sql decide who sees what
```

Everything runs from the static site. There is no server of our own. Both
keys in `lms.js` are public by design. The database rules in `lms.sql` stop
students from reading paid lessons, seeing quiz answers or editing anything.

## One-time setup

### Clerk (sign-in)
1. https://dashboard.clerk.com → **Create application** `Tinkerwith`, with
   Email and Google turned on.
2. **Configure → SSO connections → Google**: enabled.
3. **Configure → Sessions → Customize session token**:
   `{ "email": "{{user.primary_email_address}}" }`.
   This lets admins enrol students by email before they sign up.
4. **https://dashboard.clerk.com/setup/supabase → Activate**, and copy the
   Clerk domain.
5. The publishable key (`pk_test_…`) goes in `lms.js` → `CONFIG.clerkKey`.

### Supabase
1. **Authentication → Sign In / Providers → Third-Party Auth → Add provider
   → Clerk**. Paste the Clerk domain with no trailing `/`.
2. **SQL Editor**: run `lms.sql`. It's safe to run again after updates.
3. **SQL Editor**: run `seed-tutor-courses.sql`. That brings in the 4 Tutor
   LMS courses, and it skips any course that already exists.
4. Sign in on `teach.html`. It shows a one-line SQL statement that makes you
   an admin. Run it in the SQL Editor, then refresh.

## Day to day

- **Free course**: students press "Start this course".
- **Paid course**: the student pays by M-Pesa (Till 3022049) and sends the
  confirmation on WhatsApp. The course page pre-fills that message with
  their account email. In **teach.html → Students**, enrol that email. If
  they haven't signed up yet, the course unlocks the first time they do.
- **Quizzes**: students need 60% to finish a lesson. They can retry, and the
  best score is kept. Answers are marked in the database, never in the page.
- **Pictures**: use "Add picture" in the lesson editor. Files go to the
  public `lms-media` bucket, and only admins can upload.

## Moving off WordPress

`import_tutor.py` rebuilt `seed-tutor-courses.sql` from the WordPress export.
A WordPress export doesn't include:

- **Quiz questions.** Tutor stores them in its own tables. Re-enter the 9
  quizzes in teach.html; the importer prints the list.
- **Pictures.** They still point at `tinkerwith.me/wp-content/…`. Re-upload
  the cover pictures and the 2 lesson pictures before WordPress is switched off.

Prices: Tutor had paid courses at "10", which looks like dollars. They were
imported at KES 1,999. Change them per course in teach.html.

## Going live (Clerk production)

`pk_test_` keys are Clerk's development mode. Sign-in works on any site, but
the sign-in box shows a "Development mode" badge and there are user limits.
To launch:
1. In Clerk, create the **Production** instance and add the DNS records it
   lists for `tinkerwith.me` at your domain registrar.
2. In production, set up Google with your own Google OAuth client
   (Clerk's guide shows how), and add the session-token email claim again.
3. Activate the Supabase integration for production, and add the production
   Clerk domain as a second Clerk provider in Supabase.
4. Put the `pk_live_…` key in `lms.js`.

Accounts made in development don't carry over, so switch before real
students sign up.
