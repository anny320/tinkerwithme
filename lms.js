/* ─────────────────────────────────────────────────────────────
   Shared code for the course pages (learn.html, course.html, teach.html).
   Include after analytics.js:   <script src="lms.js"></script>

   Sign-in is Clerk; courses, lessons and progress live in Supabase.
   Both keys below are public by design (they go in every page):
     * the Clerk publishable key   (Clerk dashboard → API keys)
     * the Supabase publishable key (Supabase → Project Settings → API keys)
   What a visitor can actually read or change is decided by the database
   rules in supabase/lms.sql, keyed on the signed-in Clerk user.
   Setup steps: supabase/README.md.
   ───────────────────────────────────────────────────────────── */
(function () {
  var CONFIG = {
    clerkKey: 'pk_live_Y2xlcmsudGlua2Vyd2l0aC5tZSQ=',
    supabaseUrl: 'https://xithafmrpqzwhkqzwfmk.supabase.co',
    supabaseKey: 'sb_publishable__mlDCy3NdYIp9iRhDRfcpw_OhhsyHOT',
  };

  var LIBS = {
    supabase: 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js',
    marked: 'https://cdn.jsdelivr.net/npm/marked@12/marked.min.js',
    purify: 'https://cdn.jsdelivr.net/npm/dompurify@3/dist/purify.min.js',
  };

  function loadScript(src, attrs) {
    return new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = src; s.async = true; s.crossOrigin = 'anonymous';
      Object.keys(attrs || {}).forEach(function (k) { s.setAttribute(k, attrs[k]); });
      s.onload = resolve;
      s.onerror = function () { reject(new Error('Could not load ' + src)); };
      document.head.appendChild(s);
    });
  }

  // pk_test_<base64 of "xxx.clerk.accounts.dev$"> → the instance's own host,
  // which serves a clerk-js build matched to that instance.
  function clerkHost(pk) {
    try { return atob(pk.split('_')[2]).replace(/\$$/, ''); } catch (_) { return ''; }
  }

  var esc = function (t) {
    return String(t == null ? '' : t).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  };

  // Markdown → safe HTML. Links open in a new tab; scripts and handlers are stripped.
  function md(text) {
    if (!window.marked || !window.DOMPurify) return '<p>' + esc(text).replace(/\n/g, '<br>') + '</p>';
    var html = window.DOMPurify.sanitize(window.marked.parse(String(text || ''), { breaks: true }), { ADD_ATTR: ['target'] });
    var box = document.createElement('div'); box.innerHTML = html;
    box.querySelectorAll('a[href^="http"]').forEach(function (a) { a.target = '_blank'; a.rel = 'noopener'; });
    // A video link on its own line plays in place (YouTube, Vimeo, Google Drive).
    box.querySelectorAll('p').forEach(function (p) {
      var a = p.querySelector('a');
      if (!a || p.children.length !== 1 || p.textContent.trim() !== a.textContent.trim()) return;
      var src = videoEmbed(a.getAttribute('href'));
      if (!src) return;
      var wrap = document.createElement('div'); wrap.className = 'video';
      var f = document.createElement('iframe');
      f.src = src; f.title = 'Video'; f.loading = 'lazy'; f.allowFullscreen = true;
      f.setAttribute('allow', 'accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen');
      wrap.appendChild(f); p.replaceWith(wrap);
    });
    return box.innerHTML;
  }

  // YouTube watch / share / shorts link → privacy-friendly embed URL, else ''.
  function youtubeEmbed(url) {
    var m = String(url || '').match(/(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|shorts\/)|youtu\.be\/)([\w-]{11})/);
    return m ? 'https://www.youtube-nocookie.com/embed/' + m[1] : '';
  }

  // YouTube / Vimeo / Google Drive link → embed URL, else ''. Built from the
  // video id only, so a lesson can never embed an arbitrary page.
  function videoEmbed(url) {
    var u = String(url || ''), m;
    if ((m = u.match(/^https?:\/\/(?:www\.)?vimeo\.com\/(?:video\/)?(\d+)/))) return 'https://player.vimeo.com/video/' + m[1];
    if ((m = u.match(/^https?:\/\/drive\.google\.com\/file\/d\/([\w-]{10,})/))) return 'https://drive.google.com/file/d/' + m[1] + '/preview';
    return /^https?:\/\//.test(u) ? youtubeEmbed(u) : '';
  }

  var track = function (name, params) { try { if (typeof gtag === 'function') gtag('event', name, params || {}); } catch (_) {} };

  var state = { clerk: null, db: null, user: null, me: null };

  // Resolves once Supabase (and, if possible, Clerk) is ready. Never rejects:
  //   { ok: false, error }        nothing works (the course data can't load)
  //   { ok: true, signIn: false } courses can be browsed but sign-in is down
  //   { ok: true, signIn: true }  everything works
  var ready = (async function () {
    try {
      await Promise.all([loadScript(LIBS.supabase), loadScript(LIBS.marked), loadScript(LIBS.purify)]);
      state.db = window.supabase.createClient(CONFIG.supabaseUrl, CONFIG.supabaseKey, {
        accessToken: async function () {
          var c = state.clerk;
          return (c && c.session && await c.session.getToken()) || null;
        },
      });
    } catch (e) {
      console.error(e);
      return { ok: false, error: 'The courses couldn’t load. Check your connection and refresh the page.' };
    }
    try {
      if (!CONFIG.clerkKey) throw new Error('Sign-in isn’t switched on yet.');
      await loadScript('https://' + clerkHost(CONFIG.clerkKey) + '/npm/@clerk/clerk-js@5/dist/clerk.browser.js',
        { 'data-clerk-publishable-key': CONFIG.clerkKey });
      var clerk = window.Clerk;
      await clerk.load();
      state.clerk = clerk;
      state.user = clerk.user || null;
      if (state.user) {
        var name = state.user.fullName || state.user.firstName || '';
        var res = await state.db.rpc('lms_hello', { p_name: name });
        if (res.error) throw new Error(res.error.message);
        state.me = res.data;
      }
      // Reload when someone signs in or out, so every page shows the right data.
      var was = state.user && state.user.id;
      clerk.addListener(function (e) {
        var now = e.user && e.user.id;
        if ((now || null) !== (was || null)) location.reload();
      });
      return { ok: true, signIn: true };
    } catch (e) {
      console.error(e);
      return { ok: true, signIn: false, error: e.message || String(e) };
    }
  })();

  // Fills a nav slot with "Sign in" or the Clerk user button.
  function mountAccount(el) {
    ready.then(function (r) {
      if (!r.signIn || !el) return;
      el.innerHTML = '';
      if (state.user) state.clerk.mountUserButton(el, { afterSignOutUrl: 'learn.html' });
      else {
        var b = document.createElement('button');
        b.type = 'button'; b.className = 'tw-btn tw-btn-orange tw-btn-sm'; b.textContent = 'Sign in';
        b.onclick = signIn; el.appendChild(b);
      }
    });
  }

  function signIn() {
    track('lms_sign_in_open', { page: location.pathname });
    state.clerk.openSignIn({ forceRedirectUrl: location.href, signUpForceRedirectUrl: location.href });
  }

  async function rpc(name, args) {
    var res = await state.db.rpc(name, args || {});
    if (res.error) throw new Error(res.error.message);
    return res.data;
  }

  window.LMS = {
    ready: ready,
    state: state,
    get db() { return state.db; },
    get user() { return state.user; },
    get isAdmin() { return !!(state.me && state.me.is_admin); },
    signIn: signIn,
    mountAccount: mountAccount,
    rpc: rpc,
    md: md,
    esc: esc,
    youtubeEmbed: youtubeEmbed,
    track: track,
  };
})();
