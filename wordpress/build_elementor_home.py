"""Build a paste-in copy of the makers homepage for the WordPress site.

tinkerwith.me runs WordPress + Elementor. Rather than rebuild the makers
homepage by hand in Elementor, this turns index.html + brand.css into one
block of HTML for Elementor's HTML widget:

  * every CSS rule is scoped under #twm, so it can't restyle the rest of
    the WordPress site and Elementor/theme styles can't override it;
  * relative links, images and data files point at https://makers.tinkerwith.me,
    so testimonials, the project count and the mini picker stay live;
  * links back to the homepage itself point at tinkerwith.me.

Run from the repo root:   python wordpress/build_elementor_home.py
Output:                   wordpress/elementor-homepage.html
Paste the whole output file into one Elementor HTML widget (see README.md).
"""
import re
from pathlib import Path

MAKERS = "https://makers.tinkerwith.me/"
WP_HOME = "https://tinkerwith.me/"
SCOPE = "#twm"

root = Path(__file__).resolve().parent.parent
index = (root / "index.html").read_text(encoding="utf-8")
brand = (root / "brand.css").read_text(encoding="utf-8")


# ── CSS scoping ─────────────────────────────────────────────────────────
def scope_selector(sel: str) -> str:
    sel = sel.strip()
    if not sel:
        return sel
    # Page-level selectors become the wrapper itself.
    m = re.match(r"^(:root|html|body)\b(.*)$", sel)
    if m:
        rest = m.group(2).strip()
        if not rest:
            return SCOPE
        # "html body .x" / "body .x" → "#twm .x"; "body.cls" → "#twm.cls"
        rest = re.sub(r"^(html|body)\b\s*", "", rest)
        return f"{SCOPE}{rest}" if rest[:1] in ".:#[" else f"{SCOPE} {rest}"
    return f"{SCOPE} {sel}"


def scope_css(css: str) -> str:
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    out, i, n = [], 0, len(css)
    while i < n:
        j = css.find("{", i)
        if j == -1:
            break
        head = css[i:j].strip()
        # Find the matching closing brace.
        depth, k = 1, j + 1
        while k < n and depth:
            if css[k] == "{":
                depth += 1
            elif css[k] == "}":
                depth -= 1
            k += 1
        body = css[j + 1 : k - 1]
        if head.startswith("@media") or head.startswith("@supports"):
            out.append(f"{head}{{{scope_css(body)}}}")
        elif head.startswith("@"):  # @keyframes, @font-face: leave alone
            out.append(f"{head}{{{body}}}")
        else:
            sels = ",".join(scope_selector(s) for s in head.split(","))
            out.append(f"{sels}{{{body.strip()}}}")
        i = k
    return "\n".join(out)


page_css = re.search(r"<style>(.*?)</style>", index, re.S).group(1)
# Elementor and themes add margins/padding of their own; reset the wrapper.
reset = (
    f"{SCOPE}{{margin:0;padding:0;width:100%;overflow-x:clip}}"
    f"{SCOPE} a{{text-decoration:none}}"
    f"{SCOPE} p,{SCOPE} h1,{SCOPE} h2,{SCOPE} h3,{SCOPE} ul,{SCOPE} ol,{SCOPE} figure,{SCOPE} blockquote{{margin:0}}"
    f"{SCOPE} img{{border:0;box-shadow:none}}"
    # Elementor kits often set heading fonts with !important; hold ours.
    f"{SCOPE} h1,{SCOPE} h2,{SCOPE} h3,{SCOPE} h4{{font-family:var(--font-display)!important}}"
)
css = scope_css(brand) + "\n" + scope_css(page_css) + "\n" + reset

# ── Markup ──────────────────────────────────────────────────────────────
body = index.split("<body>", 1)[1]
body = re.sub(r"<!-- ═+.*?═+ -->", "", body, count=1, flags=re.S)  # dev note
markup, script = body.split("\n<script>", 1)
script = script.split("</script>", 1)[0]


def absolute(url: str) -> str:
    if re.match(r"^(https?:|//|mailto:|tel:|#|data:|javascript:)", url):
        return url
    if url in ("index.html", "./", "/"):
        return WP_HOME
    if url.startswith("index.html#"):
        return url[len("index.html") :]
    return MAKERS + url.lstrip("./")


def rewrite_attrs(html: str) -> str:
    return re.sub(
        r'\b(href|src)="([^"]*)"',
        lambda m: f'{m.group(1)}="{absolute(m.group(2))}"',
        html,
    )


markup = rewrite_attrs(markup)
script = rewrite_attrs(script)
script = script.replace("fetch('testimonials.json')", f"fetch('{MAKERS}testimonials.json')")
script = script.replace("fetch('courses.json')", f"fetch('{MAKERS}courses.json')")
script = script.replace("$go.href = 'picker.html?'", f"$go.href = '{MAKERS}picker.html?'")
for leftover in ("'testimonials.json'", "'courses.json'", "'picker.html?'"):
    assert leftover not in script, f"unrewritten path in script: {leftover}"

fonts = re.search(r'<link href="https://fonts\.googleapis\.com/css2[^"]*" rel="stylesheet">', index).group(0)

snippet = f"""<!-- TinkerWith_ homepage — generated from makers.tinkerwith.me by
     wordpress/build_elementor_home.py. Don't edit here: change the makers
     site, re-run the script, and paste the new output. -->
{fonts}
<script src="{MAKERS}analytics.js"></script>
<script src="{MAKERS}forms.js" defer></script>
<style>
{css}
</style>
<div id="twm">
{markup.strip()}
</div>
<script>
(function(){{
{script.strip()}
}})();
</script>
"""

out = root / "wordpress" / "elementor-homepage.html"
out.write_text(snippet, encoding="utf-8")
print(f"Wrote {out.relative_to(root)} ({len(snippet):,} characters)")
