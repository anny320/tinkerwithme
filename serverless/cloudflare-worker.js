/**
 * TinkerWithMe dispatch proxy (Cloudflare Worker)
 *
 * Lets the public web forms trigger the GitHub Actions workflows WITHOUT ever
 * putting a GitHub token in the browser. The page POSTs { event_type,
 * client_payload } here; this Worker adds the secret token (stored as an
 * encrypted env var) and forwards it to the GitHub repository_dispatch API.
 *
 *   Browser  ──POST──▶  this Worker (holds token)  ──▶  GitHub dispatch API
 *
 * ── Setup ──────────────────────────────────────────────────────────────────
 * 1. Create a fine-grained PAT (repo: anny320/tinkerwithme, Contents: R/W).
 * 2. Deploy this Worker (see serverless/README.md), then set secrets/vars:
 *      wrangler secret put GITHUB_TOKEN         # paste the PAT
 *      # vars (wrangler.toml or dashboard):
 *      GITHUB_REPO   = "anny320/tinkerwithme"
 *      ALLOWED_ORIGIN = "https://anny320.github.io"
 * 3. Put the Worker URL into DISPATCH_PROXY in the two HTML pages.
 *
 * The token stays server-side; if the URL is abused the only capability exposed
 * is triggering these two specific workflows, and you can rotate the secret or
 * tighten ALLOWED_ORIGIN at any time.
 */

const ALLOWED_EVENTS = new Set(["generate-curriculum", "plan-camp"]);

export default {
  async fetch(request, env) {
    const origin = env.ALLOWED_ORIGIN || "*";
    const cors = {
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }
    if (request.method !== "POST") {
      return json({ error: "Use POST" }, 405, cors);
    }

    let body;
    try {
      body = await request.json();
    } catch (_) {
      return json({ error: "Invalid JSON" }, 400, cors);
    }

    const eventType = body.event_type;
    if (!ALLOWED_EVENTS.has(eventType)) {
      return json({ error: "Unknown event_type" }, 400, cors);
    }
    const clientPayload =
      body.client_payload && typeof body.client_payload === "object"
        ? body.client_payload
        : {};

    const repo = env.GITHUB_REPO;
    const token = env.GITHUB_TOKEN;
    if (!repo || !token) {
      return json({ error: "Proxy not configured" }, 500, cors);
    }

    const ghRes = await fetch(`https://api.github.com/repos/${repo}/dispatches`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "Content-Type": "application/json",
        "User-Agent": "tinkerwithme-dispatch-proxy",
      },
      body: JSON.stringify({ event_type: eventType, client_payload: clientPayload }),
    });

    if (ghRes.status === 204) {
      return json({ ok: true }, 200, cors);
    }
    const detail = await ghRes.text();
    return json({ error: "GitHub dispatch failed", status: ghRes.status, detail }, 502, cors);
  },
};

function json(obj, status, cors) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}
