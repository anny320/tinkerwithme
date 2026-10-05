/* ─────────────────────────────────────────────────────────────
   KES or US$ prices. Visitors in Kenya's time zone see KES, everyone else
   US$; a switch (TWPrice.switcher()) lets them change it, remembered in
   this browser. Pages call TWPrice.fmt(kes, usd) and re-render on the
   'tw:currency' event.
   USD prices are set per course (premium_courses.json price_usd, or
   lms_courses.price_usd); TWPrice.usdFor() is the fallback ladder for
   online courses without one.
   ───────────────────────────────────────────────────────────── */
(function () {
  var KEY = 'tw_currency';
  function detect() {
    try { var s = localStorage.getItem(KEY); if (s === 'KES' || s === 'USD') return s; } catch (_) {}
    try { return Intl.DateTimeFormat().resolvedOptions().timeZone === 'Africa/Nairobi' ? 'KES' : 'USD'; } catch (_) { return 'KES'; }
  }
  var current = detect();

  // Self-paced online courses: KES price → US$ (×1.5 international ladder).
  var LADDER = { 1999: 29, 3000: 39, 3500: 45, 5000: 59 };
  function usdFor(kes) {
    if (!kes) return 0;
    if (LADDER[kes]) return LADDER[kes];
    var u = Math.round(kes / 130 * 1.5);
    return Math.max(9, Math.ceil(u / 10) * 10 - 1);   // round up to …9
  }

  function fmt(kes, usd) {
    if (current === 'USD') return 'US$' + Number(usd || usdFor(kes)).toLocaleString();
    return 'KES ' + Number(kes).toLocaleString();
  }

  function set(c) {
    if (c !== 'KES' && c !== 'USD' || c === current) return;
    current = c;
    try { localStorage.setItem(KEY, c); } catch (_) {}
    document.querySelectorAll('.cur-switch button').forEach(function (b) { b.classList.toggle('on', b.dataset.cur === c); });
    document.dispatchEvent(new CustomEvent('tw:currency', { detail: c }));
  }

  // A small "KES | US$" switch.
  function switcher() {
    return '<span class="cur-switch" role="group" aria-label="Currency">' +
      ['KES', 'USD'].map(function (c) {
        return '<button type="button" data-cur="' + c + '" class="' + (c === current ? 'on' : '') + '">' + (c === 'USD' ? 'US$' : 'KES') + '</button>';
      }).join('') + '</span>';
  }
  document.addEventListener('click', function (e) {
    var b = e.target.closest && e.target.closest('.cur-switch button');
    if (b) set(b.dataset.cur);
  });

  var css = document.createElement('style');
  css.textContent = '.cur-switch{display:inline-flex;border:1.5px solid currentColor;border-radius:99px;overflow:hidden;vertical-align:middle;font-size:12px}' +
    '.cur-switch button{font:inherit;font-weight:700;padding:3px 10px;border:0;background:transparent;color:inherit;cursor:pointer;opacity:.6}' +
    '.cur-switch button.on{background:#220111;color:#fff;opacity:1}';
  document.head.appendChild(css);

  window.TWPrice = { get currency() { return current; }, fmt: fmt, usdFor: usdFor, set: set, switcher: switcher };
})();
