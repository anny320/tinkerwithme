// ════════════════════════════════════════════════════════════════════════
// Circuit Lab — Arduino compile server
//
// The browser (circuit-lab/index.html) calls this directly:
//     POST /compile   { "board": "arduino:avr:uno", "source": "<.ino text>" }
//  →  200             { "hex": "<Intel HEX>", "cached": true|false }
//  →  400             { "error": "<compiler message>" }
//
// It shells out to `arduino-cli`, caches each result by a SHA-256 of the
// sketch (so repeated/identical sketches are instant and free), and guards
// itself with CORS, a per-IP rate limit, a source-size cap, a compile
// timeout and a small concurrency limit. Zero npm dependencies — only the
// Node standard library — so the container stays tiny.
//
// Env (all optional):
//   PORT              listen port                         (default 8080)
//   ALLOW_ORIGIN      CORS origin, e.g. https://tinkerwith.me  (default *)
//   MAX_SOURCE        max sketch bytes                    (default 60000)
//   RATE_PER_MIN      compiles per IP per minute          (default 30)
//   MAX_CONCURRENT    simultaneous compiles               (default 2)
//   COMPILE_TIMEOUT   ms per compile                      (default 25000)
//   CACHE_DIR         where hex is cached                 (default /tmp/hexcache)
// ════════════════════════════════════════════════════════════════════════
"use strict";
const http = require("http");
const crypto = require("crypto");
const { execFile } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const PORT = Number(process.env.PORT || 8080);
const ALLOW_ORIGIN = process.env.ALLOW_ORIGIN || "*";
const MAX_SOURCE = Number(process.env.MAX_SOURCE || 60000);
const RATE_PER_MIN = Number(process.env.RATE_PER_MIN || 30);
const MAX_CONCURRENT = Number(process.env.MAX_CONCURRENT || 2);
const COMPILE_TIMEOUT = Number(process.env.COMPILE_TIMEOUT || 25000);
const CACHE_DIR = process.env.CACHE_DIR || path.join(os.tmpdir(), "hexcache");

// Only boards we trust / have cores for.
const ALLOWED_BOARDS = new Set(["arduino:avr:uno", "arduino:avr:nano", "arduino:avr:mega"]);

fs.mkdirSync(CACHE_DIR, { recursive: true });

// ── Tiny per-IP rate limiter (in memory) ──────────────────────────────────
const hits = new Map(); // ip -> number[] (ms timestamps in the last minute)
function rateLimited(ip) {
  const now = Date.now();
  const arr = (hits.get(ip) || []).filter((t) => now - t < 60000);
  arr.push(now);
  hits.set(ip, arr);
  return arr.length > RATE_PER_MIN;
}

// ── Concurrency gate ──────────────────────────────────────────────────────
let active = 0;
const queue = [];
function acquire() {
  return new Promise((res) => {
    if (active < MAX_CONCURRENT) { active++; res(); }
    else queue.push(res);
  });
}
function release() {
  active--;
  const next = queue.shift();
  if (next) { active++; next(); }
}

function cors(res) {
  res.setHeader("Access-Control-Allow-Origin", ALLOW_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  res.setHeader("Vary", "Origin");
}
function send(res, code, obj) {
  cors(res);
  res.writeHead(code, { "Content-Type": "application/json" });
  res.end(JSON.stringify(obj));
}

// ── Compile one sketch with arduino-cli ────────────────────────────────────
function compile(board, source) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256").update(board + "\n" + source).digest("hex").slice(0, 32);
    const name = "sk_" + hash;
    const dir = path.join(os.tmpdir(), name);
    const out = path.join(dir, "build");
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, name + ".ino"), source);
    // arduino-cli names the artifact <sketch>.ino.hex inside --output-dir
    execFile(
      "arduino-cli",
      ["compile", "--fqbn", board, "--output-dir", out, "--warnings", "none", dir],
      { timeout: COMPILE_TIMEOUT, maxBuffer: 8 * 1024 * 1024 },
      (err, stdout, stderr) => {
        try {
          if (err) {
            const msg = (stderr || stdout || err.message || "compile failed").toString().slice(0, 4000);
            return reject(new Error(msg));
          }
          const hexPath = path.join(out, name + ".ino.hex");
          const hex = fs.readFileSync(hexPath, "utf8");
          resolve({ hash, hex });
        } catch (e) {
          reject(new Error((stderr || e.message).toString().slice(0, 4000)));
        } finally {
          fs.rm(dir, { recursive: true, force: true }, () => {});
        }
      }
    );
  });
}

const server = http.createServer(async (req, res) => {
  const ip = (req.headers["x-forwarded-for"] || req.socket.remoteAddress || "?").toString().split(",")[0].trim();

  if (req.method === "OPTIONS") { cors(res); res.writeHead(204); return res.end(); }
  if (req.method === "GET" && (req.url === "/" || req.url === "/health")) {
    cors(res); res.writeHead(200, { "Content-Type": "text/plain" }); return res.end("Circuit Lab compiler: ok");
  }
  if (req.method !== "POST" || req.url !== "/compile") return send(res, 404, { error: "Not found" });
  if (rateLimited(ip)) return send(res, 429, { error: "Too many compiles, slow down a moment." });

  let body = "";
  let tooBig = false;
  req.on("data", (c) => {
    body += c;
    if (body.length > MAX_SOURCE + 2000) { tooBig = true; req.destroy(); }
  });
  req.on("end", async () => {
    if (tooBig) return send(res, 413, { error: "Sketch is too large." });
    let data;
    try { data = JSON.parse(body); } catch { return send(res, 400, { error: "Bad JSON." }); }
    const board = String(data.board || "arduino:avr:uno");
    const source = String(data.source || "");
    if (!ALLOWED_BOARDS.has(board)) return send(res, 400, { error: "Unsupported board: " + board });
    if (!source.trim()) return send(res, 400, { error: "Empty sketch." });
    if (source.length > MAX_SOURCE) return send(res, 413, { error: "Sketch is too large." });

    const hash = crypto.createHash("sha256").update(board + "\n" + source).digest("hex").slice(0, 32);
    const cacheFile = path.join(CACHE_DIR, hash + ".hex");
    try {
      const cached = fs.readFileSync(cacheFile, "utf8");
      return send(res, 200, { hex: cached, cached: true });
    } catch { /* cache miss */ }

    await acquire();
    try {
      const { hex } = await compile(board, source);
      fs.writeFile(cacheFile, hex, () => {});
      send(res, 200, { hex, cached: false });
    } catch (e) {
      send(res, 400, { error: e.message });
    } finally {
      release();
    }
  });
});

server.listen(PORT, () => console.log("Circuit Lab compiler listening on :" + PORT + " (origin " + ALLOW_ORIGIN + ")"));
