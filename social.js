/* ─────────────────────────────────────────────────────────────
   Site-wide social share + follow widget.
   Loaded on every page via analytics.js. Injects a floating button
   (bottom-right): "Share this page" (native share where available, else
   WhatsApp / X / Facebook / copy-link) and a "Follow Tinkerwith" row
   (Instagram, TikTok, WhatsApp). Self-contained — styles injected here.
   Handles: Instagram @tinkerwith_anne · TikTok @tinkerwith_anne.
   ───────────────────────────────────────────────────────────── */
(function () {
  "use strict";
  // Don't show inside an embedded iframe (e.g. the school-dashboard teaser).
  try { if (window.top !== window.self) return; } catch (e) { return; }
  if (document.getElementById('tw-social')) return;

  var FOLLOW = {
    instagram: 'https://instagram.com/tinkerwith_anne',
    tiktok:    'https://www.tiktok.com/@tinkerwith_anne',
    whatsapp:  'https://wa.me/254117784724'
  };

  var css = ''
    + '#tw-social{position:fixed;right:max(16px,env(safe-area-inset-right,0px));bottom:max(16px,env(safe-area-inset-bottom,0px));z-index:9000;font-family:Jost,"Segoe UI",system-ui,sans-serif}'
    + '#tw-social *{box-sizing:border-box}'
    + '.tw-social-fab{width:52px;height:52px;border-radius:50%;border:2.5px solid #220111;background:#FF7F32;color:#fff;box-shadow:3px 3px 0 #220111;cursor:pointer;display:grid;place-items:center;transition:transform .12s ease,box-shadow .12s ease}'
    + '.tw-social-fab:hover{transform:translate(-1px,-1px);box-shadow:4px 4px 0 #220111}'
    + '.tw-social-fab:active{transform:translate(1px,1px);box-shadow:1px 1px 0 #220111}'
    + '.tw-social-fab:focus-visible{outline:3px solid #004C97;outline-offset:2px}'
    + '.tw-social-panel{position:absolute;right:0;bottom:62px;width:230px;background:#fff;border:2.5px solid #220111;border-radius:16px;box-shadow:5px 5px 0 #220111;padding:12px;display:none;animation:twsp .14s ease}'
    + '#tw-social.open .tw-social-panel{display:block}'
    + '@keyframes twsp{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:none}}'
    + '.tw-social-h{font:700 10.5px/1 "Space Mono",monospace;letter-spacing:.09em;text-transform:uppercase;color:#5A4A50;margin:2px 2px 8px}'
    + '.tw-social-row{display:flex;gap:7px;flex-wrap:wrap}'
    + '.tw-social-row+.tw-social-h{margin-top:13px}'
    + '.tw-social-b{flex:1 1 auto;min-width:0;display:flex;align-items:center;gap:7px;cursor:pointer;font:600 13px/1 Jost,"Segoe UI",sans-serif;color:#220111;background:#F7F3F0;border:1.5px solid #220111;border-radius:10px;padding:9px 10px;text-decoration:none}'
    + '.tw-social-b:hover{background:#FFEDE0}'
    + '.tw-social-ic{width:28px;height:28px;border-radius:9px;border:1.5px solid #220111;display:grid;place-items:center;color:#fff;text-decoration:none;flex:none}'
    + '.tw-social-ic svg,.tw-social-b svg{display:block}'
    + '.tw-social-note{font:12px/1.3 Jost,sans-serif;color:#5A4A50;margin-top:9px;text-align:center}'
    + '@media print{#tw-social{display:none}}';

  var st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);

  // tiny inline icons
  var I = {
    share: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.6 13.5l6.8 4M15.4 6.5l-6.8 4"/></svg>',
    wa: '<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 0 0-8.6 15l-1.3 4.7 4.8-1.3A10 10 0 1 0 12 2zm0 2a8 8 0 0 1 0 16 8 8 0 0 1-4.1-1.1l-.3-.2-2.8.8.8-2.7-.2-.3A8 8 0 0 1 12 4zm4.5 9.7c-.2-.1-1.4-.7-1.6-.8-.2-.1-.4-.1-.5.1l-.7.9c-.1.1-.3.2-.5 0a6.6 6.6 0 0 1-3.2-2.8c-.2-.4.2-.4.6-1.2l-.1-.5-.8-1.8c-.2-.4-.4-.4-.5-.4h-.5c-.2 0-.4 0-.6.3-.8.9-.8 2 .1 3.4a9.6 9.6 0 0 0 4.2 3.7c1.6.7 2.2.6 3 .5.4-.1 1.4-.6 1.6-1.1.2-.5.2-1 .1-1.1l-.5-.3z"/></svg>',
    x: '<svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor"><path d="M18.9 2H22l-7.3 8.3L23 22h-6.8l-5-6.5L5.4 22H2.3l7.8-8.9L1.5 2h6.9l4.6 6 5.9-6zm-1.2 18h1.7L7.1 3.8H5.3L17.7 20z"/></svg>',
    fb: '<svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor"><path d="M22 12a10 10 0 1 0-11.6 9.9v-7H7.9V12h2.5V9.8c0-2.5 1.5-3.9 3.8-3.9 1.1 0 2.2.2 2.2.2v2.5h-1.2c-1.2 0-1.6.8-1.6 1.6V12h2.7l-.4 2.9h-2.3v7A10 10 0 0 0 22 12z"/></svg>',
    link: '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7 0l2-2a5 5 0 0 0-7-7l-1 1"/><path d="M14 11a5 5 0 0 0-7 0l-2 2a5 5 0 0 0 7 7l1-1"/></svg>',
    ig: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.5" r="1.2" fill="currentColor" stroke="none"/></svg>',
    tt: '<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M16 3c.3 2.1 1.5 3.6 3.6 3.8v2.4c-1.3.1-2.5-.3-3.6-1v5.9c0 3-2.1 5.4-5.1 5.4a5 5 0 0 1-5-5c0-2.9 2.4-5.1 5.4-4.9v2.5c-.3-.1-.6-.1-.9-.1a2.5 2.5 0 1 0 2.5 2.5V3H16z"/></svg>'
  };

  var el = document.createElement('div');
  el.id = 'tw-social';
  var url = location.href, title = document.title || 'Tinkerwith_';
  var enc = encodeURIComponent;
  el.innerHTML = ''
    + '<div class="tw-social-panel" role="menu" aria-label="Share and follow">'
    + '  <div class="tw-social-h">Share this page</div>'
    + '  <div class="tw-social-row">'
    + '    <a class="tw-social-b" target="_blank" rel="noopener" href="https://wa.me/?text=' + enc(title + ' ' + url) + '">' + I.wa + ' WhatsApp</a>'
    + '  </div>'
    + '  <div class="tw-social-row" style="margin-top:7px">'
    + '    <a class="tw-social-ic" style="background:#111" target="_blank" rel="noopener" href="https://twitter.com/intent/tweet?text=' + enc(title) + '&url=' + enc(url) + '" aria-label="Share on X">' + I.x + '</a>'
    + '    <a class="tw-social-ic" style="background:#1877F2" target="_blank" rel="noopener" href="https://www.facebook.com/sharer/sharer.php?u=' + enc(url) + '" aria-label="Share on Facebook">' + I.fb + '</a>'
    + '    <button class="tw-social-ic" style="background:#5E8700" id="tw-social-copy" aria-label="Copy link">' + I.link + '</button>'
    + '  </div>'
    + '  <div class="tw-social-h">Follow Tinkerwith</div>'
    + '  <div class="tw-social-row">'
    + '    <a class="tw-social-ic" style="background:#E1306C" target="_blank" rel="noopener" href="' + FOLLOW.instagram + '" aria-label="Instagram">' + I.ig + '</a>'
    + '    <a class="tw-social-ic" style="background:#010101" target="_blank" rel="noopener" href="' + FOLLOW.tiktok + '" aria-label="TikTok">' + I.tt + '</a>'
    + '    <a class="tw-social-ic" style="background:#25D366" target="_blank" rel="noopener" href="' + FOLLOW.whatsapp + '" aria-label="WhatsApp">' + I.wa + '</a>'
    + '  </div>'
    + '  <div class="tw-social-note" id="tw-social-msg">@tinkerwith_anne</div>'
    + '</div>'
    + '<button class="tw-social-fab" id="tw-social-fab" aria-label="Share this page" aria-expanded="false" aria-haspopup="true">' + I.share + '</button>';
  document.body.appendChild(el);

  var fab = document.getElementById('tw-social-fab');
  function openPanel(o){ el.classList.toggle('open', o); fab.setAttribute('aria-expanded', o ? 'true' : 'false'); }

  fab.addEventListener('click', function () {
    // Prefer the OS share sheet on phones; fall back to the panel.
    if (navigator.share) {
      navigator.share({ title: title, url: url }).catch(function(){ openPanel(!el.classList.contains('open')); });
    } else {
      openPanel(!el.classList.contains('open'));
    }
  });
  document.addEventListener('click', function (e) { if (!el.contains(e.target)) openPanel(false); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') openPanel(false); });

  var copy = document.getElementById('tw-social-copy');
  if (copy) copy.addEventListener('click', function () {
    var msg = document.getElementById('tw-social-msg');
    var done = function () { var t = msg.textContent; msg.textContent = 'Link copied ✓'; setTimeout(function(){ msg.textContent = t; }, 1400); };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(url).then(done).catch(done);
    else { var ta = document.createElement('textarea'); ta.value = url; document.body.appendChild(ta); ta.select(); try { document.execCommand('copy'); } catch (e) {} ta.remove(); done(); }
  });
})();
