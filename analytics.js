/* ─────────────────────────────────────────────────────────────
   Google Analytics (GA4) for every page on the site.
   Include in <head> with:  <script src="analytics.js"></script>
   The WordPress site (tinkerwith.me) loads this same file from makers,
   site-wide, via the WPCode plugin; see wordpress/README.md.
   The measurement ID lives here only — change it in one place.

   Besides page views it records clicks that matter for the business:
     whatsapp_click   any wa.me link        (link_text, page)
     community_join_click  the WhatsApp community group invite link
     email_click      any mailto: link
     shop_click       a link to the HustleSasa store (product purchases)
     promo_click      elements with data-ga="promo-…" (the monthly
                      promo ribbon and banner on the homepage)
     outbound_click   links from makers to the WordPress courses / shop
                      (not fired on tinkerwith.me itself, where they're internal)
   PDF downloads are counted by GA's built-in file_download event.
   ───────────────────────────────────────────────────────────── */
(function () {
  var GA_ID = 'G-26H8GCM572';

  var s = document.createElement('script');
  s.async = true;
  s.src = 'https://www.googletagmanager.com/gtag/js?id=' + GA_ID;
  document.head.appendChild(s);

  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () { dataLayer.push(arguments); };
  gtag('js', new Date());
  gtag('config', GA_ID);

  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a, [data-ga]');
    if (!a) return;
    var href = a.getAttribute('href') || '';
    var text = (a.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 80);
    var page = location.pathname;
    try {
      if (a.dataset && a.dataset.ga) {
        gtag('event', 'promo_click', { promo_id: a.dataset.ga, link_text: text, link_url: href, page: page });
      }
      if (/^https?:\/\/chat\.whatsapp\.com\//.test(href)) {
        gtag('event', 'community_join_click', { link_text: text, page: page });
      } else if (/^https?:\/\/(wa\.me|api\.whatsapp\.com)\//.test(href)) {
        gtag('event', 'whatsapp_click', { link_text: text, page: page });
      } else if (/^https?:\/\/[a-z0-9-]+\.hustlesasa\.shop\//.test(href)) {
        gtag('event', 'shop_click', { link_text: text, link_url: href, page: page });
      } else if (href.indexOf('mailto:') === 0) {
        gtag('event', 'email_click', { link_text: text, page: page });
      } else if (/^https?:\/\/(www\.)?tinkerwith\.me\//.test(href) &&
                 location.hostname.replace(/^www\./, '') !== 'tinkerwith.me') {
        gtag('event', 'outbound_click', { link_text: text, link_url: href, page: page });
      }
    } catch (err) {}
  }, true);
})();
