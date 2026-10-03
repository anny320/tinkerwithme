# Supabase (Train an AI leaderboard)

The online courses use the same project. See [COURSES.md](COURSES.md).

The Train an AI game (`train-an-ai.html`) can show a shared leaderboard. The
site is static, so the scores live in a free Supabase project. The page talks
to it directly with the public key. No server or secret is needed in the repo.

```
Browser ──GET  /rest/v1/train_ai_scores (top 20)──────────▶ Supabase
        ──POST /rest/v1/rpc/submit_train_ai_score──────────▶ (checks nickname, computes score)
```

Until the URL and key are filled in, the leaderboard is hidden and the game
works as before.

## Set up (about 5 minutes)

1. **Create the project.** https://supabase.com/dashboard → New project →
   name it `tinkerwith`, pick the closest region (e.g. Frankfurt), save the
   database password somewhere safe.
2. **Create the table and function.** SQL Editor → New query → paste all of
   `train-an-ai-leaderboard.sql` → Run. Safe to run again later.
3. **Copy the public details.** Project Settings → API keys:
   - the **Project URL** (`https://<ref>.supabase.co`)
   - the **publishable** key (`sb_publishable_…`), or the legacy **anon** key
4. **Paste them into the page.** In `train-an-ai.html`:
   ```js
   const LEADERBOARD = { url: 'https://<ref>.supabase.co', key: 'sb_publishable_…' };
   ```
   Commit and push. The board appears below the lessons.

Never put the **secret** / **service_role** key in the page. It bypasses all
the protections below.

## What protects the board

- Players can **read** the table, and that's all. Inserts, edits and deletes
  from the page are refused.
- Scores go in only through `submit_train_ai_score(nickname, tests, seconds)`,
  which works out the score itself, so nobody can post "999999".
- Nicknames must be 2–16 letters or numbers, no long digit runs (phone
  numbers), and must pass a short rude-word list. Extend the list in the SQL
  and re-run it.
- Runs faster than 30 seconds, or with fewer than 3 tests, are rejected, and
  at most 30 scores a minute are accepted across everyone.

A determined person could still post a believable fake run, because the game
runs in the browser. That's acceptable for a kids' game. Remove a bad
entry in **Table Editor → train_ai_scores → delete row**.

## Scoring

`3,000 − 250 × (tests − 3)` (never below 0) `+ 1,000 − 2 × seconds` (never
below 0). Time counts only while the game tab is open and visible, from the
first label to the last mission. The rule lives in both the SQL function and
`trainScore()` in the page. Change both together.

## Privacy

The board stores only a nickname, the score, the test count, the seconds and
a timestamp. No names, emails or IP addresses. The page reminds kids to use
a made-up nickname, not their real name.
