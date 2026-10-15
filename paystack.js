/* paystack.js — card / M-Pesa checkout via Paystack Inline.
 *
 * Loads Paystack's inline script on demand and opens the popup with the right
 * amount, currency and the buyer's email. On success it hands back the
 * transaction reference, which the page records as a pending payment
 * (method = 'paystack') for the admin to verify and approve — same manual
 * flow as M-Pesa and card today. No secret key is ever used client-side.
 *
 * The public key lives in lms.js CONFIG.paystackKey. While it is blank, the
 * "Pay with Paystack" buttons stay hidden, so nothing changes until a key is set.
 */
(function () {
  var SRC = 'https://js.paystack.co/v2/inline.js';
  var loading;
  function load() {
    return loading || (loading = new Promise(function (res, rej) {
      if (window.PaystackPop) return res();
      var s = document.createElement('script');
      s.src = SRC; s.async = true;
      s.onload = function () { window.PaystackPop ? res() : rej(new Error('Paystack didn’t load.')); };
      s.onerror = function () { loading = null; rej(new Error('Could not reach Paystack. Check your connection.')); };
      document.head.appendChild(s);
    }));
  }

  function key() { return (window.LMS && LMS.paystackKey) || ''; }
  function enabled() { return !!key(); }

  // A short, unique reference we can trace in the Paystack dashboard.
  function makeRef(tag) {
    var r = (Date.now().toString(36) + Math.random().toString(36).slice(2, 8)).toUpperCase();
    return ('TW-' + (tag ? tag.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10) + '-' : '') + r).slice(0, 50);
  }

  /* pay(opts):
   *   amountKES, amountUSD : price in each currency (whole units)
   *   currency             : 'KES' | 'USD' (defaults to the current TWPrice choice)
   *   email                : buyer email (defaults to LMS.email)
   *   tag                  : short label woven into the reference (e.g. a slug)
   *   metadata             : object stored on the Paystack transaction
   *   onSuccess(reference) : called with the reference after a successful charge
   *   onCancel()           : called if the buyer closes the popup
   */
  async function pay(opts) {
    if (!enabled()) throw new Error('Paystack isn’t switched on yet.');
    await load();
    var cur = opts.currency || (window.TWPrice && TWPrice.currency) || 'KES';
    var whole = cur === 'USD' ? opts.amountUSD : opts.amountKES;
    if (!whole || whole <= 0) throw new Error('This item has no price set for ' + cur + '.');
    var email = opts.email || (window.LMS && LMS.email) || '';
    if (!email) throw new Error('Please sign in so we can email your receipt.');
    var ref = opts.reference || makeRef(opts.tag);
    var pop = new window.PaystackPop();
    pop.newTransaction({
      key: key(),
      email: email,
      amount: Math.round(whole * 100),   // Paystack takes the smallest unit
      currency: cur,
      reference: ref,
      metadata: opts.metadata || {},
      onSuccess: function (tx) { if (opts.onSuccess) opts.onSuccess((tx && (tx.reference || tx.trxref)) || ref, tx); },
      onCancel: function () { if (opts.onCancel) opts.onCancel(); },
    });
    return ref;
  }

  window.TWPaystack = { pay: pay, enabled: enabled, makeRef: makeRef };
})();
