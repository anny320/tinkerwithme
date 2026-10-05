/* ─────────────────────────────────────────────────────────────
   Website content (course picker catalogue, testimonials, blog posts).
   Saved from the Course editor (admin.html) into Supabase; pages read it with
       SiteData.get('courses' | 'testimonials' | 'posts')  →  Promise<object>
   which resolves to the same shape as courses.json / testimonials.json /
   posts.json. If Supabase can't be reached, it falls back to those files.
   Only published testimonials are ever returned (supabase/site-content.sql).
   ───────────────────────────────────────────────────────────── */
(function () {
  var URL = 'https://xithafmrpqzwhkqzwfmk.supabase.co/rest/v1/rpc/site_content_public';
  var KEY = 'sb_publishable__mlDCy3NdYIp9iRhDRfcpw_OhhsyHOT';  // public by design
  var cache = {};

  function fromFile(key) {
    return fetch(key + '.json', { cache: 'no-store' }).then(function (r) {
      if (!r.ok) throw new Error(key + '.json: ' + r.status);
      return r.json();
    });
  }

  function fromSupabase(key) {
    var ctl = window.AbortController ? new AbortController() : null;
    var timer = ctl && setTimeout(function () { ctl.abort(); }, 5000);
    return fetch(URL, {
      method: 'POST',
      headers: { apikey: KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_key: key }),
      signal: ctl ? ctl.signal : undefined,
    }).then(function (r) {
      if (!r.ok) throw new Error('Supabase ' + r.status);
      return r.json();
    }).then(function (d) {
      if (!d || typeof d !== 'object') throw new Error('no ' + key + ' saved yet');
      return d;
    }).finally(function () { if (timer) clearTimeout(timer); });
  }

  window.SiteData = {
    get: function (key) {
      if (!cache[key]) {
        cache[key] = fromSupabase(key).catch(function (e) {
          console.warn('SiteData: using ' + key + '.json (' + e.message + ')');
          return fromFile(key);
        });
      }
      return cache[key];
    },
  };
})();
