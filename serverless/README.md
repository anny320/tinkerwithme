# Dispatch proxy (keeps the GitHub token secret)

The web forms (`camp-planner.html`, `curriculumgenerator.html`) can trigger the
GitHub Actions workflows directly — but a public static site can't hold a GitHub
token without exposing it. This tiny proxy solves that: the browser calls the
proxy, and the proxy (which holds the token as a server-side secret) calls
GitHub.

```
Browser ──POST { event_type, client_payload }──▶ Worker (has token) ──▶ GitHub dispatch API
```

Only two `event_type`s are allowed (`generate-curriculum`, `plan-camp`), so the
worst a leaked URL can do is trigger these two workflows.

## Deploy on Cloudflare Workers (free tier)

1. **Create a fine-grained PAT**
   - https://github.com/settings/personal-access-tokens → Generate (fine-grained)
   - Resource owner: `anny320`; Repository access: only `tinkerwithme`
   - Permissions → Repository → **Contents: Read and write** (repository_dispatch lives under Contents)

2. **Deploy the worker**
   ```bash
   npm install -g wrangler
   wrangler login
   # from this serverless/ folder:
   wrangler deploy cloudflare-worker.js --name tinkerwithme-dispatch
   ```
   (Or paste `cloudflare-worker.js` into the Cloudflare dashboard → Workers → Create.)

3. **Set the secret and vars**
   ```bash
   wrangler secret put GITHUB_TOKEN          # paste the PAT
   ```
   Add these vars (dashboard → Settings → Variables, or in `wrangler.toml`):
   - `GITHUB_REPO` = `anny320/tinkerwithme`
   - `ALLOWED_ORIGIN` = `https://anny320.github.io`  (lock CORS to your site)

4. **Point the pages at it**
   In both `camp-planner.html` and `curriculumgenerator.html`, set:
   ```js
   const DISPATCH_PROXY = 'https://tinkerwithme-dispatch.<your-subdomain>.workers.dev';
   ```
   Commit and push. The forms now trigger workflows with no token in the browser.

## Netlify / Vercel

The same logic works as a Netlify/Vercel function — read `event_type` +
`client_payload` from the request body, add `Authorization: Bearer <token>` from
an env var, and POST to `https://api.github.com/repos/<repo>/dispatches`. Store
the token as an environment variable in the platform's dashboard.

## Rotating / revoking

Revoke or regenerate the PAT at the same GitHub settings page and run
`wrangler secret put GITHUB_TOKEN` again. Nothing in the repo or the pages needs
to change.
