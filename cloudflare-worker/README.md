# Curriculum Generator API — Cloudflare Worker + R2

The TinkerWithMe site is hosted statically on **GitHub Pages**, which has no
backend. This Worker is the API behind the **Generate PDF Curriculum** button.

```
Browser (anny320.github.io)
   │ 1. POST { track, projects, age_group, duration, audience, user_email }
   ▼
Cloudflare Worker ── fires repository_dispatch ──▶ GitHub Actions
   ▲                                                (generate_curriculum.py)
   │ 3. GET ?action=status  (poll)                        │
   │ 4. GET ?action=download                              │ 2. upload PDF
   │                                                       ▼
   └──────────────── reads PDF ◀──────────────── Cloudflare R2 bucket
```

1. The browser POSTs the request; the Worker mints a random `job_id` and
   triggers the `curriculumgenerator.yml` workflow.
2. The workflow builds the PDF (Claude + WeasyPrint) and uploads it to R2 at
   `curricula/<job_id>.pdf`.
3. The browser polls `?action=status` until the PDF exists.
4. The browser downloads it via `?action=download` — the Worker streams it
   from the **private** R2 bucket. The unguessable `job_id` is the download key.

---

## One-time setup (all in the Cloudflare dashboard + GitHub)

### A. GitHub token (for triggering the workflow)
1. github.com → **Settings → Developer settings → Personal access tokens →
   Fine-grained tokens → Generate new token**.
2. Repository access: **only** `anny320/tinkerwithme`.
3. Repository permissions: **Contents: Read-only**, **Actions: Read and write**.
4. Generate and copy the `github_pat_…` value.

### B. Create the R2 bucket
1. Cloudflare dashboard → **R2** → **Create bucket**.
2. Name it **`tinkerwithme-curricula`**. Leave it **private** (no public access).
3. (Optional) Bucket → **Settings → Object lifecycle rules** → add a rule to
   delete objects after e.g. 7 days, so old PDFs are cleaned up automatically.

### C. R2 S3 API token (so the workflow can upload)
1. R2 → **Manage R2 API Tokens** → **Create API token**.
2. Permissions: **Object Read & Write**, scoped to the `tinkerwithme-curricula`
   bucket.
3. Create it, then copy the **Access Key ID** and **Secret Access Key**.
4. Note your **Account ID** (shown on the R2 overview / any bucket page).

### D. Create the Worker
1. Dashboard → **Workers & Pages** → **Create** → **Workers** →
   **Start with Hello World!** → name it **`tinkerwithme-curriculum`** →
   **Deploy**.
2. Open **Edit code**, delete the placeholder, paste all of `worker.js`,
   **Deploy**.
3. Worker → **Settings → Variables and Secrets**:
   - Plaintext variables:
     | Name | Value |
     |---|---|
     | `GITHUB_OWNER` | `anny320` |
     | `GITHUB_REPO` | `tinkerwithme` |
     | `ALLOWED_ORIGIN` | `https://anny320.github.io` |
   - Secret: `GITHUB_TOKEN` = the token from step A.
4. Worker → **Settings → Bindings → Add → R2 bucket**:
   - Variable name: **`CURRICULUM_BUCKET`** (must match exactly)
   - Bucket: `tinkerwithme-curricula`
5. **Deploy** again so the binding takes effect. Copy the Worker URL
   (`https://tinkerwithme-curriculum.<subdomain>.workers.dev`).

### E. Point the site at the Worker
In `curriculumgenerator.html`, set `CURRICULUM_API` (top of the `<script>`) to
the Worker URL from step D5. Commit + push; GitHub Pages redeploys.

### F. GitHub repo secrets (for the workflow)
Repo → **Settings → Secrets and variables → Actions** → add:

| Secret | Value |
|---|---|
| `ANTHROPIC_API_KEY` | Your Claude API key (already needed by the generator). |
| `R2_ACCOUNT_ID` | Cloudflare account ID (step C4). |
| `R2_BUCKET` | `tinkerwithme-curricula`. |
| `R2_ACCESS_KEY_ID` | R2 access key ID (step C3). |
| `R2_SECRET_ACCESS_KEY` | R2 secret access key (step C3). |

---

## CLI alternative

If you prefer the CLI over the dashboard for the Worker:

```bash
npm install -g wrangler
wrangler login
cd cloudflare-worker
wrangler deploy
wrangler secret put GITHUB_TOKEN
```

`wrangler.toml` already declares the `CURRICULUM_BUCKET` R2 binding and the
plaintext vars.

---

## Notes

- The bucket is **private**; PDFs are only reachable through the Worker with a
  valid `job_id`. Treat the lifecycle rule (step B3) as the retention policy.
- Only `repository_dispatch` runs upload to R2. Manual `workflow_dispatch` runs
  still produce a downloadable **Actions artifact** but won't push to R2 (no
  `job_id`).
- If you move the site to a custom domain, update `ALLOWED_ORIGIN` and redeploy.
