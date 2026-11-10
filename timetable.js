/* timetable.js — renders the weekly live-session timetable.
 *
 * Two modes, both reading the Supabase RPCs in supabase/timetable.sql:
 *   TWTimetable.mountPublic(el)  — the weekly rhythm, no join links (homepage
 *                                   teaser / logged-out). Works on its own; it
 *                                   does NOT need lms.js (a light REST call).
 *   TWTimetable.mount(el)        — member view: if the signed-in visitor is an
 *                                   active member, their sessions + join links;
 *                                   otherwise the public teaser + a join nudge.
 *                                   Needs lms.js on the page (uses LMS.rpc).
 *
 * Times are stored in EAT (Africa/Nairobi, UTC+3, no DST); we also show each
 * session in the viewer's own local time.
 */
(function () {
  // Public, by design — same keys that ship in lms.js. Used only for the
  // anon public-teaser fetch when lms.js isn't on the page.
  var SB_URL = 'https://xithafmrpqzwhkqzwfmk.supabase.co';
  var SB_KEY = 'sb_publishable__mlDCy3NdYIp9iRhDRfcpw_OhhsyHOT';
  var EAT_OFFSET_MIN = 180;   // Africa/Nairobi is a fixed UTC+3
  var DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  var esc = function (t) {
    return String(t == null ? '' : t).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  };

  // A safe http(s) URL, else '' (never render a javascript: link).
  function safeUrl(u) {
    u = String(u || '').trim();
    return /^https?:\/\//i.test(u) ? u : '';
  }

  // An <img> src: allow http(s) or a relative path (no scheme → no javascript:).
  function imgUrl(u) {
    u = String(u || '').trim();
    if (!u) return '';
    if (/^https?:\/\//i.test(u)) return u;
    return /^[^:]*$/.test(u) ? u : '';   // relative path (contains no ':')
  }

  var styled = false;
  function injectStyle() {
    if (styled) return; styled = true;
    var css = [
      '.tw-tt{display:flex;flex-direction:column;gap:10px}',
      '.tw-tt-head{display:flex;align-items:baseline;justify-content:space-between;gap:10px;flex-wrap:wrap}',
      '.tw-tt-head h3{font-size:19px;font-weight:600;margin:0}',
      '.tw-tt-sub{font-size:13.5px;color:var(--text-2)}',
      '.tw-tt-row{display:flex;align-items:center;gap:12px;justify-content:space-between;background:var(--white);border:2px solid var(--ink);border-radius:var(--radius-sm,12px);padding:10px 13px}',
      '.tw-tt-row .grow{min-width:0;flex:1}',
      '.tw-tt-thumb{flex:none;width:66px;height:66px;border-radius:10px;border:2px solid var(--ink);object-fit:cover;background:var(--cream,#f3ece3)}',
      '@media(max-width:480px){.tw-tt-thumb{width:52px;height:52px}}',
      '.tw-tt-when{font-family:var(--font-mono,monospace);font-weight:700;font-size:14.5px}',
      '.tw-tt-cohort{font-weight:600;font-size:15px;margin-top:1px}',
      '.tw-tt-meta{font-size:13px;color:var(--text-2);margin-top:1px}',
      '.tw-tt-badge{display:inline-block;font-family:var(--font-mono,monospace);font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;border:1.5px solid var(--ink);border-radius:99px;padding:1px 7px;margin-left:6px;vertical-align:middle}',
      '.tw-tt-badge.club{background:var(--green,#8BD450)}',
      '.tw-tt-badge.premium{background:#FFD23F}',
      '.tw-tt-badge.all{background:var(--cream,#f3ece3)}',
      '.tw-tt-join{flex:none}',
      '.tw-tt-note{font-size:13px;color:var(--text-2);font-style:italic;margin-top:2px}',
      '.tw-tt-cta{font-size:14px;color:var(--text-2);margin-top:2px}',
      '.tw-tt-empty{font-size:14.5px;color:var(--text-2)}',
    ].join('');
    var s = document.createElement('style'); s.textContent = css; document.head.appendChild(s);
  }

  // Next upcoming instant for a weekly {weekday, 'HH:MM' in EAT}, as a real Date.
  function nextOccurrence(weekday, hhmm) {
    var parts = String(hhmm || '00:00').split(':');
    var h = +parts[0] || 0, mi = +parts[1] || 0;
    // "EAT wall clock" as a Date whose UTC fields read as EAT.
    var eat = new Date(Date.now() + EAT_OFFSET_MIN * 60000);
    var dow = eat.getUTCDay();
    var days = (weekday - dow + 7) % 7;
    var wall = new Date(Date.UTC(eat.getUTCFullYear(), eat.getUTCMonth(), eat.getUTCDate() + days, h, mi));
    var nowWall = new Date(Date.UTC(eat.getUTCFullYear(), eat.getUTCMonth(), eat.getUTCDate(), eat.getUTCHours(), eat.getUTCMinutes()));
    if (days === 0 && wall <= nowWall) wall = new Date(wall.getTime() + 7 * 86400000);
    // `wall` holds EAT wall-clock as if UTC; the real instant is 3h earlier.
    return new Date(wall.getTime() - EAT_OFFSET_MIN * 60000);
  }

  function localStr(date) {
    try {
      return date.toLocaleString(undefined, { weekday: 'short', hour: '2-digit', minute: '2-digit' });
    } catch (_) { return ''; }
  }

  // Is the viewer effectively on EAT? Then skip the redundant "your time" line.
  function viewerIsEAT() {
    return new Date().getTimezoneOffset() === -EAT_OFFSET_MIN;
  }

  function tierLabel(t) { return t === 'premium' ? 'Premium' : t === 'club' ? 'Club' : 'All members'; }

  function rowHtml(s, withJoin) {
    var when = DAYS[s.weekday] + ' · ' + s.start_time + (s.end_time ? '–' + s.end_time : '') + ' EAT';
    var local = '';
    if (!viewerIsEAT()) {
      var occ = nextOccurrence(s.weekday, s.start_time);
      var ls = localStr(occ);
      if (ls) local = '<div class="tw-tt-meta">your time: ' + esc(ls) + '</div>';
    }
    var url = withJoin ? safeUrl(s.join_url) : '';
    var join = url
      ? '<a class="tw-btn tw-btn-orange tw-btn-sm tw-tt-join" href="' + esc(url) + '" target="_blank" rel="noopener" data-ga="timetable-join">Join &rarr;</a>'
      : '';
    var img = imgUrl(s.image_url);
    var thumb = img ? '<img class="tw-tt-thumb" src="' + esc(img) + '" alt="" loading="lazy">' : '';
    return '<div class="tw-tt-row">' + thumb + '<div class="grow">' +
      '<div class="tw-tt-when">' + esc(when) + '</div>' +
      '<div class="tw-tt-cohort">' + esc(s.cohort) + '<span class="tw-tt-badge ' + esc(s.tier) + '">' + esc(tierLabel(s.tier)) + '</span></div>' +
      local +
      (s.note ? '<div class="tw-tt-note">' + esc(s.note) + '</div>' : '') +
      '</div>' + join + '</div>';
  }

  // Sort by the next upcoming occurrence, so the soonest session is first.
  function bySoonest(a, b) {
    return nextOccurrence(a.weekday, a.start_time) - nextOccurrence(b.weekday, b.start_time);
  }

  function renderList(el, rows, opts) {
    injectStyle();
    opts = opts || {};
    rows = (rows || []).slice().sort(bySoonest);
    var head = '<div class="tw-tt-head"><h3>' + esc(opts.title || 'This week’s live sessions') + '</h3>' +
      (opts.sub ? '<span class="tw-tt-sub">' + esc(opts.sub) + '</span>' : '') + '</div>';
    if (!rows.length) {
      el.innerHTML = '<div class="tw-tt">' + head + '<p class="tw-tt-empty">' + esc(opts.empty || 'The weekly timetable will appear here soon.') + '</p></div>';
      return;
    }
    var body = rows.map(function (s) { return rowHtml(s, !!opts.withJoin); }).join('');
    var cta = opts.cta ? '<p class="tw-tt-cta">' + opts.cta + '</p>' : '';
    el.innerHTML = '<div class="tw-tt">' + head + body + cta + '</div>';
  }

  function fetchPublic() {
    // Prefer lms.js's client when present; else a light anon REST call.
    if (window.LMS && LMS.rpc && LMS.ready) {
      return LMS.ready.then(function () { return LMS.rpc('lms_timetable_public'); });
    }
    return fetch(SB_URL + '/rest/v1/rpc/lms_timetable_public', {
      method: 'POST',
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json' },
      body: '{}',
    }).then(function (r) { return r.ok ? r.json() : []; });
  }

  // Public teaser — the weekly rhythm, no links. Great for the homepage.
  function mountPublic(el, opts) {
    if (!el) return;
    opts = opts || {};
    fetchPublic().then(function (rows) {
      renderList(el, rows, {
        title: opts.title || 'Live sessions, every week',
        sub: opts.sub || '',
        withJoin: false,
        empty: opts.empty || 'Our weekly live sessions are being scheduled — join to be first in.',
        cta: opts.cta || 'Members get the join links. <a href="membership.html" data-ga="timetable-see-plans">See plans &rarr;</a>',
      });
    }).catch(function () { el.innerHTML = ''; });
  }

  // Member view — needs lms.js. Active members see their sessions + join links;
  // everyone else sees the public teaser with a join nudge.
  function mount(el, opts) {
    if (!el || !(window.LMS && LMS.ready)) return;
    opts = opts || {};
    LMS.ready.then(async function (r) {
      var rows = [];
      if (r && r.signIn && LMS.user) {
        try { rows = await LMS.rpc('lms_my_timetable'); } catch (_) { rows = []; }
      }
      if (rows && rows.length) {
        renderList(el, rows, {
          title: opts.title || 'This week’s live sessions',
          sub: opts.sub || 'Tap Join at session time.',
          withJoin: true,
          empty: 'No sessions scheduled yet — check back soon.',
        });
        return;
      }
      // Not a member (or no entitled sessions) → public teaser + nudge.
      var pub = [];
      try { pub = await fetchPublic(); } catch (_) { pub = []; }
      if (!pub.length) { el.innerHTML = ''; return; }
      renderList(el, pub, {
        title: opts.title || 'Live sessions, every week',
        withJoin: false,
        cta: 'Join Club or Premium to get the session links. <a href="membership.html" data-ga="timetable-join-cta">See membership &rarr;</a>',
      });
    }).catch(function () { el.innerHTML = ''; });
  }

  window.TWTimetable = { mount: mount, mountPublic: mountPublic };
})();
