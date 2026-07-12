/**
 * TinkerWithMe — Curriculum Generator API (Cloudflare Worker)
 *
 * The site is hosted statically on GitHub Pages, which has no backend. This
 * Worker is the missing API. The browser POSTs the curriculum request here;
 * the Worker fires a GitHub `repository_dispatch` event that triggers the
 * `curriculumgenerator.yml` workflow, which runs `generate_curriculum.py`
 * (Claude + WeasyPrint) to build the PDF.
 *
 * Because the workflow is asynchronous (2-3 min) there is no immediate
 * download URL — the Worker returns `{ success: true }` and the browser tells
 * the user the PDF is being generated.
 *
 * Required secret (set with `wrangler secret put GITHUB_TOKEN`):
 *   GITHUB_TOKEN  — a fine-grained PAT with "Contents: read" + "Actions: write"
 *                   (or a classic PAT with the `repo` scope) on anny320/tinkerwithme.
 *
 * Plain vars (in wrangler.toml [vars]):
 *   GITHUB_OWNER, GITHUB_REPO, ALLOWED_ORIGIN
 */

const VALID_TRACKS = ["arduino", "ai"];
const VALID_DURATIONS = ["90", "120", "180", "full"];
const VALID_AUDIENCES = ["classroom", "homeschool"];
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function corsHeaders(env) {
  return {
    "Access-Control-Allow-Origin": env.ALLOWED_ORIGIN || "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
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

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(env) });
    }

    if (request.method !== "POST") {
      return json({ success: false, error: "Method not allowed." }, 405, env);
    }

    let payload;
    try {
      payload = await request.json();
    } catch (_) {
      return json({ success: false, error: "Invalid JSON body." }, 400, env);
    }

    // --- Validate the request before spending a workflow run ---
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
      return json(
        { success: false, error: "Server misconfigured: missing GITHUB_TOKEN." },
        500,
        env
      );
    }

    // --- Fire the GitHub repository_dispatch that runs the workflow ---
    const owner = env.GITHUB_OWNER || "anny320";
    const repo = env.GITHUB_REPO || "tinkerwithme";
    const url = `https://api.github.com/repos/${owner}/${repo}/dispatches`;

    let ghRes;
    try {
      ghRes = await fetch(url, {
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
          message:
            "✅ Your curriculum is being generated. It takes 2-3 minutes and will be " +
            `sent to ${email}. You can close this page.`,
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
