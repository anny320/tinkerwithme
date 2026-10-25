// ════════════════════════════════════════════════════════════════════════
// Paystack webhook → membership auto-renew.
//
// Paystack POSTs subscription + charge events here. We:
//   1. Verify the x-paystack-signature HMAC (SHA-512 of the RAW body, keyed
//      with the Paystack SECRET key). Reject anything that doesn't match.
//   2. Pull out the customer email, plan code, next payment date, and (on the
//      first charge) the metadata we attached at checkout (our Clerk user id,
//      tier, cycle).
//   3. Call lms_apply_paystack_membership with the SERVICE ROLE key — the one
//      place a membership is written without a human approving it. That RPC is
//      granted to service_role only, so no browser can reach it.
//
// Deploy:  supabase functions deploy paystack-webhook --no-verify-jwt
//   (--no-verify-jwt because Paystack can't send a Supabase JWT; we do our own
//    signature check instead, which is stronger here.)
//
// Secrets (supabase secrets set …):
//   PAYSTACK_SECRET_KEY        sk_live_… (or sk_test_… while testing)
//   SUPABASE_URL               your project URL      (usually auto-injected)
//   SUPABASE_SERVICE_ROLE_KEY  service role key      (usually auto-injected)
//
// See README.md in this folder for the full dashboard setup.
// ════════════════════════════════════════════════════════════════════════

const SECRET = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
const SB_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const enc = new TextEncoder();

/** Hex HMAC-SHA512 of `body` keyed with the Paystack secret. */
async function sign(body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(SECRET), { name: "HMAC", hash: "SHA-512" }, false, ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, enc.encode(body));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Constant-time compare of two equal-length hex strings. */
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Paystack sometimes sends metadata as a JSON string; normalise to an object. */
function asObject(v: unknown): Record<string, unknown> {
  if (v && typeof v === "object") return v as Record<string, unknown>;
  if (typeof v === "string") { try { return JSON.parse(v); } catch { /* ignore */ } }
  return {};
}

function str(v: unknown): string { return typeof v === "string" ? v : v == null ? "" : String(v); }

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (!SECRET || !SB_URL || !SB_KEY) return new Response("Not configured", { status: 500 });

  const raw = await req.text();
  const given = req.headers.get("x-paystack-signature") ?? "";
  const expected = await sign(raw);
  if (!given || !safeEqual(given.toLowerCase(), expected)) {
    return new Response("Invalid signature", { status: 401 });
  }

  let evt: { event?: string; data?: Record<string, unknown> };
  try { evt = JSON.parse(raw); } catch { return new Response("Bad JSON", { status: 400 }); }

  const event = str(evt.event);
  const data = asObject(evt.data);

  // Which events move a membership. Everything else (one-time course/curriculum
  // charges, failed charges, etc.) we acknowledge and ignore.
  const EXTEND = new Set(["charge.success", "subscription.create", "invoice.create", "invoice.update"]);
  const STOP = new Set(["subscription.disable", "subscription.not_renew"]);
  if (!EXTEND.has(event) && !STOP.has(event)) return new Response("ignored", { status: 200 });

  const customer = asObject(data.customer);
  const planObj = asObject(data.plan);
  const sub = asObject(data.subscription);
  const subPlan = asObject(sub.plan);
  const meta = asObject(data.metadata);

  const email = str(customer.email) || str(data.email);
  const planCode = str(planObj.plan_code) || str(subPlan.plan_code) || str(data.plan) || str(sub.plan);
  const subscriptionCode = str(data.subscription_code) || str(sub.subscription_code);
  const customerCode = str(customer.customer_code);
  const reference = str(data.reference) || str(sub.reference);
  const nextPay = str(data.next_payment_date) || str(sub.next_payment_date);

  // A charge.success with no plan is a one-time payment (course/curriculum) —
  // handled by the manual-approve flow, not here.
  if (EXTEND.has(event) && !planCode && !str(meta.tier)) return new Response("ignored (no plan)", { status: 200 });

  // Amount is in the smallest unit; only trust it for KES.
  const currency = str(data.currency) || str(sub.currency);
  const amountMinor = Number(data.amount ?? sub.amount ?? 0);
  const amountKes = currency === "KES" && amountMinor > 0 ? Math.round(amountMinor / 100) : null;

  const payload = {
    p_user_id: str(meta.user_id),
    p_email: email,
    p_plan_code: planCode,
    p_tier: str(meta.tier),
    p_cycle: str(meta.cycle),
    p_event: STOP.has(event) ? "disable" : "charge",
    p_reference: reference,
    p_subscription_code: subscriptionCode,
    p_customer_code: customerCode,
    p_paid_until: nextPay || null,
    p_amount_kes: amountKes,
  };

  const res = await fetch(`${SB_URL}/rest/v1/rpc/lms_apply_paystack_membership`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": SB_KEY,
      "Authorization": `Bearer ${SB_KEY}`,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    // Return 5xx so Paystack retries (transient DB/network issue).
    const detail = await res.text().catch(() => "");
    console.error("rpc failed", res.status, detail);
    return new Response("rpc failed", { status: 502 });
  }
  return new Response("ok", { status: 200 });
});
