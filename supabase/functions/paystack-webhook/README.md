# Paystack membership auto-renew — setup

This turns a Paystack subscription into an automatic membership. When a member
pays (or renews), Paystack calls the `paystack-webhook` Edge Function, which
verifies the request and flips the member's `lms_memberships` row on.

**This is the only place a membership is granted without a human approving it.**
The write happens through `lms_apply_paystack_membership`, a function granted to
the **service role only** — no browser can call it. The Edge Function
authenticates with the service key, and only after it has verified Paystack's
`x-paystack-signature` over the raw request body.

Until this is live, members still join the manual way: M-Pesa Till → paste
reference → you approve in `teach.html` (which calls `lms_grant_membership`).

---

## One-time setup

### 1. Run the SQL
In the Supabase SQL editor, run (in order, if not already):
`lms.sql` → `membership.sql` → **`paystack-subscriptions.sql`**.

### 2. Create the 4 Plans in Paystack
Dashboard → **Plans** → create one per tier × cycle, at the locked prices:

| Plan name            | Amount (KES) | Interval |
|----------------------|-------------:|----------|
| Tinkerwith Club — monthly    | 2,000  | Monthly  |
| Tinkerwith Club — annual     | 20,000 | Annually |
| Tinkerwith Premium — monthly | 6,500  | Monthly  |
| Tinkerwith Premium — annual  | 65,000 | Annually |

Copy each **Plan code** (`PLN_…`).

### 3. Tell both sides which plan is which
**a. Database** — in the SQL editor, seed the map (also at the bottom of
`paystack-subscriptions.sql`):
```sql
insert into public.lms_paystack_plans (plan_code, tier, cycle) values
  ('PLN_club_monthly',    'club',    'monthly'),
  ('PLN_club_annual',     'club',    'annual'),
  ('PLN_premium_monthly', 'premium', 'monthly'),
  ('PLN_premium_annual',  'premium', 'annual')
on conflict (plan_code) do update set tier = excluded.tier, cycle = excluded.cycle;
```
**b. Frontend** — in `lms.js`, fill `CONFIG.paystackPlans` with the same codes
and set `CONFIG.paystackKey` to your `pk_live_…` (or `pk_test_…` while testing):
```js
paystackKey: 'pk_live_xxxxxxxx',
paystackPlans: {
  'club-monthly':    'PLN_club_monthly',
  'club-annual':     'PLN_club_annual',
  'premium-monthly': 'PLN_premium_monthly',
  'premium-annual':  'PLN_premium_annual',
},
```
With these set, the membership page shows **“Subscribe — auto-renew”**; blank,
it stays hidden and only the M-Pesa flow shows. Nothing else changes.

### 4. Deploy the function and set its secrets
```sh
supabase functions deploy paystack-webhook --no-verify-jwt
supabase secrets set PAYSTACK_SECRET_KEY=sk_live_xxxxxxxx
# SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically on
# Supabase-hosted functions; set them only for local `supabase functions serve`.
```
`--no-verify-jwt` is required: Paystack can't send a Supabase JWT. The function
does its own signature check, which is the right guard here.

### 5. Point Paystack at the function
Dashboard → **Settings → API Keys & Webhooks → Webhook URL**:
```
https://<your-project-ref>.functions.supabase.co/paystack-webhook
```
Use the matching key mode (test URL/keys together, live together).

---

## How it maps events

| Paystack event        | What the function does                                  |
|-----------------------|---------------------------------------------------------|
| `charge.success` (with a plan) | activate + extend the membership            |
| `subscription.create` | bind the subscription/customer codes, set next payment  |
| `invoice.create` / `invoice.update` | renewal → extend to the new next-payment date |
| `subscription.disable` / `subscription.not_renew` | stop auto-renew; access lapses at `expires_at` (not yanked mid-term) |
| `charge.success` **without** a plan | ignored (one-time course/curriculum payment) |

- **First payment** carries our metadata (`user_id`, `tier`, `cycle`), so the
  member is matched exactly. **Renewals** carry no metadata, so they're matched
  by the Paystack customer **email** stored on the membership from the first
  charge.
- **Retry-safe:** Paystack re-delivers until it gets a `200`. Charges are
  deduped by their unique transaction reference, and `expires_at` is set to
  Paystack's `next_payment_date` (absolute), so a re-delivery changes nothing.
- An **unmatched** payment (email we don't recognise) is parked as a *pending*
  `lms_payments` row tagged for manual follow-up, rather than lost.

## Test it

1. Test mode: `pk_test_`/`sk_test_`, test plan codes, the test webhook URL.
2. On `membership.html`, pick a tier, **Subscribe**, pay with a
   [Paystack test card](https://paystack.com/docs/payments/test-payments/).
3. Check: the member's `lms_memberships` row is `active` with an `expires_at`,
   and an `approved` `lms_payments` row (`kind='membership'`, `method='paystack'`)
   appears. The member banner shows on reload.
4. Flip to live keys/URL when it all works.

## Security notes

- The secret key lives only in the function's secrets — never in the repo or any
  page. The browser only ever sees the **public** key.
- `lms_apply_paystack_membership` is `revoke`d from `anon`/`authenticated` and
  granted to `service_role` only. Even with the anon key, a browser can't grant
  a membership.
- Optional defence-in-depth: Paystack also publishes fixed source IPs you can
  allowlist in front of the function.
