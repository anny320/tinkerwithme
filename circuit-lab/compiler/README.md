# Circuit Lab compiler

A tiny service that turns an Arduino sketch into an Intel-HEX file for the
Uno R3 (and Nano/Mega). The Circuit Lab page (`/circuit-lab/`) calls it
**directly** — there is no Supabase Edge Function and no `supabase` CLI in
this path. The browser then runs the hex on a simulated ATmega328P (avr8js).

```
Browser ──POST /compile {board, source}──▶  this service (arduino-cli)
        ◀──────── {hex, cached} ──────────
Browser runs the hex on avr8js (in the page)
```

## What it does for you
- Compiles with `arduino-cli` (the real Arduino toolchain).
- **Caches** every result by a SHA-256 of the sketch, so identical sketches
  (most kids' blink/traffic/… sketches are identical) return instantly and
  never recompile.
- Protects itself: CORS locked to your site, per-IP rate limit, source-size
  cap, compile timeout, and a small concurrency limit.
- No npm dependencies — just Node's standard library + `arduino-cli`.

Compiling is **cross-compilation**: the sketch is turned into AVR machine
code, never executed on the server. It runs only in the browser sandbox.

## Files
| File | Purpose |
|---|---|
| `server.js` | The HTTP server (zero deps). |
| `Dockerfile` | Node + `arduino-cli` + AVR core + Adafruit OLED libs. |
| `fly.toml` | Fly.io config (scales to zero when idle). |

## Deploy — Fly.io (recommended, free-friendly)
Runs on your machine, where you're logged in. One-time: install flyctl and
`fly auth login`.

```bash
cd circuit-lab/compiler
# edit fly.toml: set a unique `app` name and your region
fly launch --no-deploy        # creates the app from fly.toml (first time only)
fly deploy                     # builds the image and ships it
fly status                     # shows the public URL, e.g. https://<app>.fly.dev
```
Set CORS to your site (also settable in `fly.toml`):
```bash
fly secrets set ALLOW_ORIGIN=https://tinkerwith.me
```

## Deploy — Render (alternative)
New → **Web Service** → point at this folder → Runtime **Docker**. Add an
env var `ALLOW_ORIGIN=https://tinkerwith.me`. Render gives you a
`https://<name>.onrender.com` URL. (Free Render services sleep when idle and
cold-start on the next request — the cache keeps later compiles fast.)

## Connect the page
Put the service URL into `circuit-lab/index.html`:
```js
const COMPILE_ENDPOINT = 'https://<your-app>.fly.dev/compile';
```
Commit and push. Code mode now compiles for real.

## Test it
```bash
curl -s -X POST https://<your-app>.fly.dev/compile \
  -H 'Content-Type: application/json' \
  --data '{"board":"arduino:avr:uno","source":"void setup(){pinMode(13,OUTPUT);} void loop(){digitalWrite(13,HIGH);delay(500);digitalWrite(13,LOW);delay(500);}"}' \
  | head -c 120
# → {"hex":":100000000C9434000C9446000C94...","cached":false}
```

## Config (env vars)
| Var | Default | Meaning |
|---|---|---|
| `PORT` | `8080` | Listen port. |
| `ALLOW_ORIGIN` | `*` | CORS origin — set to your site. |
| `MAX_SOURCE` | `60000` | Max sketch bytes. |
| `RATE_PER_MIN` | `30` | Compiles per IP per minute. |
| `MAX_CONCURRENT` | `2` | Simultaneous compiles. |
| `COMPILE_TIMEOUT` | `25000` | ms per compile. |
| `CACHE_DIR` | `/tmp/hexcache` | Where hex is cached (ephemeral on scale-to-zero; that's fine). |

## Security note
CORS stops other *websites* using your compiler, but anyone with the URL can
still `curl` it. The rate limit, size cap and timeout keep that bounded and
cheap. If abuse ever becomes a problem, put the Supabase Edge Function in
front (adds Clerk auth + a shared cache) — the page's compile contract is
identical, so only `COMPILE_ENDPOINT` changes.
