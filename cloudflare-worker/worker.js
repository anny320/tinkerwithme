/**
 * TinkerWithMe — Curriculum Generator API (Cloudflare Worker)
 *
 * The site is hosted statically on GitHub Pages, which has no backend. This
 * Worker is that backend. It does three things on one URL:
 *
 *   POST  /                          -> validates the request, mints a job_id,
 *                                       and fires a GitHub `repository_dispatch`
 *                                       that runs curriculumgenerator.yml.
 *   GET   /?action=status&job_id=..  -> reports whether the PDF has landed in R2.
 *   GET   /?action=download&job_id=. -> streams the finished PDF from R2.
 *
 * The workflow (generate_curriculum.py) builds the PDF and uploads it to R2 at
 * key `curricula/<job_id>.pdf`. The browser polls status until ready, then
 * downloads. The bucket is private — only this Worker reads it, and the
 * unguessable job_id acts as the capability token for the download.
 *
 * Bindings / config:
 *   [secret] GITHUB_TOKEN      PAT with Contents:read + Actions:write on the repo.
 *   [var]    GITHUB_OWNER      Repo owner (anny320).
 *   [var]    GITHUB_REPO       Repo name (tinkerwithme).
 *   [var]    ALLOWED_ORIGIN    Site origin for CORS (https://anny320.github.io).
 *   [r2]     CURRICULUM_BUCKET R2 bucket binding holding the generated PDFs.
 */

const VALID_TRACKS = ["arduino", "ai"];
const VALID_DURATIONS = ["90", "120", "180", "full"];
const VALID_AUDIENCES = ["classroom", "homeschool"];
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const KEY_PREFIX = "curricula/";

function corsHeaders(env) {
  return {
    "Access-Control-Allow-Origin": env.ALLOWED_ORIGIN || "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

function json(body, status, env) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders(env) },
  });
}

function keyFor(jobId) {
  return KEY_PREFIX + jobId + ".pdf";
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(env) });
    }

    const url = new URL(request.url);
    const action = url.searchParams.get("action");

    // --- GET: status / download ---
    if (request.method === "GET") {
      const jobId = (url.searchParams.get("job_id") || "").trim();
      if (!UUID_RE.test(jobId)) {
        return json({ success: false, error: "Invalid job_id." }, 400, env);
      }
      if (!env.CURRICULUM_BUCKET) {
        return json({ success: false, error: "Server misconfigured: no storage bound." }, 500, env);
      }

      if (action === "status") {
        const obj = await env.CURRICULUM_BUCKET.head(keyFor(jobId));
        return json({ success: true, ready: !!obj }, 200, env);
      }

      if (action === "download") {
        const obj = await env.CURRICULUM_BUCKET.get(keyFor(jobId));
        if (!obj) {
          return json({ success: false, error: "Not ready yet." }, 404, env);
        }
        return new Response(obj.body, {
          status: 200,
          headers: {
            "Content-Type": "application/pdf",
            "Content-Disposition": 'attachment; filename="TinkerWithMe-Curriculum.pdf"',
            "Cache-Control": "no-store",
            ...corsHeaders(env),
          },
        });
      }

      return json({ success: false, error: "Unknown action." }, 400, env);
    }

    if (request.method !== "POST") {
      return json({ success: false, error: "Method not allowed." }, 405, env);
    }

    // --- POST: trigger a generation ---
    let payload;
    try {
      payload = await request.json();
    } catch (_) {
      return json({ success: false, error: "Invalid JSON body." }, 400, env);
    }

    const track = String(payload.track || "").trim();
    const projects = String(payload.projects || "").trim();
    const ageGroup = String(payload.age_group || "").trim();
    const duration = String(payload.duration || "").trim();
    const audience = String(payload.audience || "classroom").trim();
    const email = String(payload.user_email || "").trim();

    const errors = [];
    if (!VALID_TRACKS.includes(track)) errors.push("track");
    if (!projects) errors.push("projects");
    if (!ageGroup) errors.push("age_group");
    if (!VALID_DURATIONS.includes(duration)) errors.push("duration");
    if (!VALID_AUDIENCES.includes(audience)) errors.push("audience");
    if (!EMAIL_RE.test(email)) errors.push("user_email");

    if (errors.length) {
      return json(
        { success: false, error: `Invalid or missing field(s): ${errors.join(", ")}.` },
        400,
        env
      );
    }

    if (!env.GITHUB_TOKEN) {
      return json({ success: false, error: "Server misconfigured: missing GITHUB_TOKEN." }, 500, env);
    }

    const jobId = crypto.randomUUID();
    const owner = env.GITHUB_OWNER || "anny320";
    const repo = env.GITHUB_REPO || "tinkerwithme";
    const ghUrl = `https://api.github.com/repos/${owner}/${repo}/dispatches`;

    let ghRes;
    try {
      ghRes = await fetch(ghUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${env.GITHUB_TOKEN}`,
          Accept: "application/vnd.github+json",
          "X-GitHub-Api-Version": "2022-11-28",
          "User-Agent": "tinkerwithme-curriculum-worker",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          event_type: "generate-curriculum",
          client_payload: {
            job_id: jobId,
            track,
            projects,
            age_group: ageGroup,
            duration,
            audience,
            user_email: email,
          },
        }),
      });
    } catch (e) {
      return json({ success: false, error: "Could not reach GitHub. Try again." }, 502, env);
    }

    // GitHub returns 204 No Content on a successful dispatch.
    if (ghRes.status === 204) {
      return json(
        {
          success: true,
          job_id: jobId,
          message: "Your curriculum is being generated.",
        },
        202,
        env
      );
    }

    const detail = await ghRes.text().catch(() => "");
    return json(
      {
        success: false,
        error: `GitHub rejected the request (${ghRes.status}). ${detail.slice(0, 200)}`.trim(),
      },
      502,
      env
    );
  },
};
