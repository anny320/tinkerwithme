/**
 * TinkerWith_ — shared form submission
 *
 * One place to configure where every form on the site sends its data.
 *
 * Why this exists: the old Google Forms path posted with mode:'no-cors',
 * which makes the response opaque — the browser cannot read the status, so
 * the page can never tell a success from a failure. Submissions disappeared
 * with no error. Formspree returns readable JSON, so failures surface.
 *
 * ── SETUP ──────────────────────────────────────────────────────────────
 * 1. Create a free account at https://formspree.io
 * 2. Create two forms: "Leads" and "Newsletter"
 * 3. Copy each form's endpoint (looks like https://formspree.io/f/abcdwxyz)
 *    into ENDPOINTS below.
 * Nothing else needs to change — every page reads this file.
 */
window.TW_FORMS = {
  // 'formspree' once the endpoints below are filled in.
  // 'google' keeps the old behaviour. 'none' disables submission entirely.
  provider: 'formspree',

  ENDPOINTS: {
    // ⚠ REPLACE THESE with your real Formspree endpoints.
    lead:       'https://formspree.io/f/REPLACE_LEAD_ID',
    newsletter: 'https://formspree.io/f/REPLACE_NEWSLETTER_ID',
  },

  // Legacy fallback — only used when provider is 'google'.
  google: {
    formId: '1FAIpQLSdk2owabXMyT77go8Md4GDziEyG6ICxJ9fEPHmM_lZM4Q_wLQ',
    fields: {
      name: 'entry.2112029396', email: 'entry.1021403262',
      org: 'entry.959896618', country: 'entry.710652329', role: 'entry.531199886',
    },
  },
};

(function () {
  const CFG = window.TW_FORMS;

  const configured = kind => {
    const url = CFG.ENDPOINTS[kind];
    return !!url && !url.includes('REPLACE_');
  };

  function withTimeout(url, opts, ms) {
    const ctrl = new AbortController();
    const tid = setTimeout(() => ctrl.abort(), ms);
    return fetch(url, { ...opts, signal: ctrl.signal }).finally(() => clearTimeout(tid));
  }

  /**
   * Submit a form.
   * @param {string} kind  'lead' | 'newsletter'
   * @param {object} data  field name -> value
   * @returns {Promise<{ok:boolean, skipped?:boolean}>}  rejects with an Error the caller can show
   */
  window.twSubmitForm = async function (kind, data, { timeout = 10000 } = {}) {
    if (CFG.provider === 'none') return { ok: true, skipped: true };

    if (CFG.provider === 'google') {
      // Fire-and-forget: the response is opaque, so this can only ever
      // report "sent", never "delivered". Kept for the legacy pages.
      const g = CFG.google;
      const body = new URLSearchParams();
      for (const [k, v] of Object.entries(data)) {
        if (g.fields[k]) body.append(g.fields[k], v ?? '');
      }
      withTimeout(`https://docs.google.com/forms/d/e/${g.formId}/formResponse`,
        { method: 'POST', mode: 'no-cors', body }, timeout).catch(() => {});
      return { ok: true, skipped: false };
    }

    if (!configured(kind)) {
      throw new Error('This form is not connected yet. Please email tinkerwithanne@gmail.com.');
    }

    let res;
    try {
      res = await withTimeout(CFG.ENDPOINTS[kind], {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify(data),
      }, timeout);
    } catch (e) {
      throw new Error(e.name === 'AbortError'
        ? 'That took too long. Check your connection and try again.'
        : 'We could not reach the server. Please try again.');
    }

    if (res.ok) return { ok: true };

    // Formspree returns { errors: [{ message }] } on validation problems.
    let msg = 'Something went wrong. Please try again, or email tinkerwithanne@gmail.com.';
    try {
      const j = await res.json();
      if (j.errors && j.errors.length) msg = j.errors.map(e => e.message).join(', ');
    } catch (e) { /* keep the default */ }
    throw new Error(msg);
  };

  /**
   * Wire up a newsletter signup form.
   * Expects: form[data-tw-newsletter] containing input[name=email]
   *          and an element [data-tw-status] for feedback.
   */
  window.twWireNewsletter = function (form) {
    const status = form.querySelector('[data-tw-status]');
    const button = form.querySelector('button[type=submit]');
    const say = (msg, kind) => {
      status.textContent = msg;
      status.dataset.kind = kind;
    };

    form.addEventListener('submit', async e => {
      e.preventDefault();
      // Honeypot: real people leave this empty; bots fill everything in.
      if (form.querySelector('input[name=_gotcha]')?.value) return;

      const email = form.querySelector('input[name=email]').value.trim();
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
        say('That email address does not look right.', 'error');
        return;
      }

      const original = button.textContent;
      button.disabled = true;
      button.textContent = 'Signing up…';
      say('', '');

      try {
        await window.twSubmitForm('newsletter', {
          email,
          source: location.pathname,
          _subject: 'New TinkerWith_ mailing list signup',
        });
        form.reset();
        say('You are on the list. Watch your inbox for the next project.', 'ok');
      } catch (err) {
        say(err.message, 'error');
      } finally {
        button.disabled = false;
        button.textContent = original;
      }
    });
  };

  document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('form[data-tw-newsletter]').forEach(window.twWireNewsletter);
  });
})();
