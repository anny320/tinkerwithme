# Curriculum Generator API — Cloudflare Worker

The TinkerWithMe site is hosted statically on **GitHub Pages**, which has no
backend. This Worker is the API that the **Generate PDF Curriculum** button
calls. It fires a GitHub `repository_dispatch` event that triggers the
`curriculumgenerator.yml` workflow (Claude + WeasyPrint → PDF).

```
Browser (anny320.github.io)
   │  POST { track, projects, age_group, duration, audience, user_email }
   ▼
Cloudflare Worker  ──fires repository_dispatch──▶  GitHub Actions
                                                   (generate_curriculum.py)
```

Because generation is asynchronous (2–3 min), the Worker responds immediately
with `{ success: true }` and the browser tells the user the PDF is on its way.

---

## One-time setup

### 1. Install Wrangler & log in

```bash
npm install -g wrangler
wrangler login
```

### 2. Create a GitHub token

Create a **fine-grained personal access token** scoped to
`anny320/tinkerwithme` with these repository permissions:

- **Contents:** Read-only
- **Actions:** Read and write

(A classic PAT with the `repo` scope also works.)

### 3. Deploy the Worker and set the secret

From this `cloudflare-worker/` directory:

```bash
wrangler deploy
wrangler secret put GITHUB_TOKEN   # paste the token when prompted
```

`wrangler deploy` prints the Worker URL, e.g.
`https://tinkerwithme-curriculum.<your-subdomain>.workers.dev`.

### 4. Point the site at the Worker

Open `curriculumgenerator.html` and set `CURRICULUM_API` (near the top of the
`<script>`) to the URL from step 3:

```js
const CURRICULUM_API = "https://tinkerwithme-curriculum.<your-subdomain>.workers.dev";
```

Commit and push — GitHub Pages redeploys automatically.

### 5. Make sure the workflow can run

The `curriculumgenerator.yml` workflow needs the `ANTHROPIC_API_KEY` repo
secret (Settings → Secrets and variables → Actions). Without it the workflow
will start but the PDF step fails.

---

## Configuration reference

Set in `wrangler.toml` under `[vars]`:

| Variable         | Purpose                                                        |
|------------------|----------------------------------------------------------------|
| `GITHUB_OWNER`   | Repo owner (`anny320`).                                         |
| `GITHUB_REPO`    | Repo name (`tinkerwithme`).                                     |
| `ALLOWED_ORIGIN` | Exact site origin for CORS (`https://anny320.github.io`).       |

Secret (via `wrangler secret put`):

| Secret         | Purpose                                              |
|----------------|------------------------------------------------------|
| `GITHUB_TOKEN` | PAT used to trigger the workflow. **Never commit it.** |

---

## Notes & known gaps

- **No email is actually sent yet.** The Worker triggers the workflow, and the
  workflow currently only *uploads the PDF as an artifact* and echoes a success
  message — it does not email the user. To truly deliver the PDF you'll need to
  add an email step (e.g. Resend/SendGrid) to `curriculumgenerator.yml`. Until
  then the PDF is downloadable from the workflow run's **Artifacts**.
- The Worker validates the payload before triggering, so bad requests don't
  waste workflow minutes.
- CORS is locked to `ALLOWED_ORIGIN`. If you move the site to a custom domain,
  update that var and redeploy.
