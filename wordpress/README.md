# tinkerwith.me homepage (WordPress + Elementor)

`elementor-homepage.html` is the makers.tinkerwith.me homepage as one block of
HTML for an Elementor **HTML** widget. It is generated, so don't edit it by hand:

```
python wordpress/build_elementor_home.py
```

Re-run that after any change to `index.html` or `brand.css`, then paste the new
file into the same widget. Testimonials, the project count and the mini course
picker load live from makers.tinkerwith.me, so those never need a re-paste.

## Putting it on WordPress

1. **Pages → Add New**, title it `Home`, click **Edit with Elementor**.
2. Bottom-left gear (**Page Settings**) → **Page Layout: Elementor Canvas**.
   This hides the WordPress theme's own header and footer; the snippet has its own.
3. Add a **Container** (or Section). In its **Layout** tab set
   **Content Width: Full Width**, **Width: 100%**, and in **Advanced** set
   **Padding: 0** on all sides.
4. Drag in an **HTML** widget, paste the whole of `elementor-homepage.html`.
   In the widget's **Advanced** tab set **Margin: 0** and **Padding: 0**.
5. **Publish**.
6. **Settings → Reading → Your homepage displays: A static page**, choose `Home`.
7. If you added the temporary `.htaccess` redirect for the homepage, remove it.
8. If a caching plugin is installed, clear its cache.

## Notes

- All styles are scoped under `#twm`, so they don't touch the rest of the
  WordPress site (courses, lessons, shop), and theme styles don't leak in.
- The snippet does **not** include Google Analytics. Add it once for the whole
  WordPress site instead (next section), so every page is tracked and the
  homepage isn't counted twice.
- Course and shop buttons point at the WordPress courses and products, as on makers.
  Other links (Plan a session, coloring book, camp planner…) go to makers.tinkerwith.me.

## Google Analytics on the whole WordPress site

The free version of Elementor has no place for site-wide code, so use the free
**WPCode** plugin (by WPCode, "Insert Headers and Footers"):

1. **Plugins → Add New**, search `WPCode`, **Install Now**, **Activate**.
2. **Code Snippets → Header & Footer**.
3. Paste this into the **Header** box and click **Save Changes**:

   ```html
   <script src="https://makers.tinkerwith.me/analytics.js"></script>
   ```

This loads the same tag as makers (property `G-26H8GCM572`) with the same click
events, so both sites report to one place. Remove any other Google Analytics
plugin (Site Kit, MonsterInsights…) so visits aren't counted twice.

In Google Analytics, **Admin → Data streams → (the stream) → Configure tag
settings → Configure your domains**: add `tinkerwith.me` and
`makers.tinkerwith.me`, so moving between the two sites counts as one visit.
Use the **Hostname** dimension in reports to tell the two sites apart.
