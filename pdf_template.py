#!/usr/bin/env python3
"""
Shared PDF shell for TinkerWithMe generators.

Both generate_curriculum.py and generate_camp_plan.py render their content
into this single branded document so every PDF looks the same: TinkerWithMe
header, orange accents, page footer with the running-order and page numbers.

The body HTML (everything inside <main>) is produced by each generator; this
module only owns the branded chrome.
"""

# NOTE: kept as a plain string (single braces) so it can be dropped straight
# into an HTML document without any f-string escaping.
CSS = """
        @page {
            size: A4;
            margin: 18mm 16mm;
            @bottom-center {
                content: "TinkerWithMe · Nairobi, Kenya · tinkerwithanne@gmail.com";
                font-size: 9pt;
                color: #B08060;
            }
            @bottom-right {
                content: "Page " counter(page) " of " counter(pages);
                font-size: 9pt;
                color: #B08060;
            }
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Inter', 'Segoe UI', sans-serif;
            line-height: 1.6;
            color: #2A1A0E;
            background: white;
        }

        /* Print styles */
        @media print {
            body { background: white; }
            a { color: #F07B1D; text-decoration: none; }
        }

        header {
            position: relative;
            border-bottom: 2.5px solid #F07B1D;
            padding-bottom: 1rem;
            margin-bottom: 2rem;
        }

        .header-brand {
            font-size: 18px;
            font-weight: 700;
            color: #2A1A0E;
            letter-spacing: -0.01em;
            margin-bottom: 0.5rem;
        }

        .header-title {
            font-size: 13px;
            color: #6B4C30;
            margin-bottom: 0.25rem;
        }

        .header-subtitle {
            font-size: 11px;
            color: #B08060;
        }

        .header-prepared {
            margin-top: 0.6rem;
            font-size: 12px;
            color: #2A1A0E;
        }

        .session-badge {
            display: inline-block;
            background: #FEF0E0;
            color: #C45C00;
            font-size: 10px;
            font-weight: 700;
            padding: 3px 10px;
            border-radius: 99px;
            letter-spacing: 0.05em;
            text-transform: uppercase;
            margin-left: 6px;
            vertical-align: middle;
        }

        .header-meta {
            font-size: 11px;
            color: #6B4C30;
            text-align: right;
            line-height: 1.7;
            position: absolute;
            right: 0;
            top: 0;
        }

        h1 {
            font-size: 28px;
            font-weight: 700;
            margin: 1.5rem 0 0.5rem;
            color: #2A1A0E;
            border-bottom: 1px solid #ddd;
            padding-bottom: 0.5rem;
        }

        h2 {
            font-size: 18px;
            font-weight: 700;
            margin: 1.5rem 0 0.75rem;
            color: #2A1A0E;
            border-bottom: 1px solid #eee;
            padding-bottom: 0.35rem;
        }

        h3 {
            font-size: 14px;
            font-weight: 700;
            margin: 1rem 0 0.5rem;
            color: #2A1A0E;
        }

        p {
            margin-bottom: 0.75rem;
            line-height: 1.75;
        }

        ul, ol {
            margin: 0.75rem 0 0.75rem 1.4rem;
        }

        li {
            margin-bottom: 0.4rem;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin: 1rem 0;
            font-size: 12px;
        }

        th {
            background: #FAFAF7;
            padding: 0.5rem;
            text-align: left;
            font-weight: 700;
            border-bottom: 2px solid #B08060;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: #B08060;
        }

        td {
            padding: 0.5rem;
            border-bottom: 1px solid #ddd;
            vertical-align: top;
        }

        tr:hover td {
            background: rgba(42, 26, 14, 0.02);
        }

        strong {
            font-weight: 600;
            color: #2A1A0E;
        }

        em {
            font-style: italic;
            color: #6B4C30;
        }

        .print-tag {
            display: inline-block;
            background: #FEF0E0;
            color: #C45C00;
            font-size: 9px;
            font-weight: 700;
            padding: 2px 8px;
            border-radius: 99px;
            margin-top: 0.5rem;
            letter-spacing: 0.06em;
            text-transform: uppercase;
        }

        .content {
            page-break-inside: avoid;
        }

        pre {
            background: #F5F0EB;
            border-left: 3px solid #F07B1D;
            padding: 0.75rem 1rem;
            margin: 0.75rem 0;
            font-size: 10px;
            line-height: 1.55;
            overflow-x: auto;
            white-space: pre-wrap;
            word-break: break-word;
        }

        code {
            font-family: 'Courier New', Courier, monospace;
            font-size: 10px;
            background: #F5F0EB;
            padding: 0 3px;
            border-radius: 2px;
        }

        pre code {
            background: none;
            padding: 0;
        }

        /* ── Executive summary ─────────────────────────────────────────── */
        .exec-summary {
            background: #FAFAF7;
            border: 1px solid #eee;
            border-left: 4px solid #F07B1D;
            border-radius: 8px;
            padding: 1rem 1.2rem 1.2rem;
            margin-bottom: 1.5rem;
        }
        .exec-summary h2 { margin-top: 0.5rem; }
        .exec-summary h2:first-child { margin-top: 0; }

        .stats {
            margin: 0.9rem 0 0.3rem;
        }
        .stat {
            display: inline-block;
            background: #fff;
            border: 1px solid #eee;
            border-radius: 6px;
            padding: 0.45rem 0.7rem;
            margin: 0 0.4rem 0.4rem 0;
            min-width: 78px;
            text-align: center;
            vertical-align: top;
        }
        .stat .n {
            display: block;
            font-size: 18px;
            font-weight: 700;
            color: #C45C00;
            line-height: 1.2;
        }
        .stat .l {
            display: block;
            font-size: 9px;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: #B08060;
            margin-top: 2px;
        }

        /* ── Programme: per-topic cards ────────────────────────────────── */
        .band-head {
            border-bottom: 2px solid #F07B1D;
            padding-bottom: 0.35rem;
            margin-top: 1.8rem;
        }

        .project {
            margin: 1rem 0 1.4rem;
        }
        .project-head {
            background: #2A1A0E;
            color: #fff;
            border-radius: 8px;
            padding: 0.55rem 0.85rem;
            margin: 1.3rem 0 0.8rem;
            break-after: avoid;
            page-break-after: avoid;
            break-inside: avoid;
            page-break-inside: avoid;
        }
        .project-head .num {
            display: inline-block;
            background: #F07B1D;
            color: #fff;
            font-weight: 700;
            font-size: 12px;
            width: 22px;
            height: 22px;
            line-height: 22px;
            text-align: center;
            border-radius: 50%;
            margin-right: 8px;
            vertical-align: middle;
        }
        .project-head .title {
            font-size: 15px;
            font-weight: 700;
            vertical-align: middle;
        }
        .project-head .meta {
            display: block;
            font-size: 9.5px;
            color: #FFB870;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-top: 3px;
            margin-left: 30px;
        }
        /* Demote each project's internal section headers so the topic title
           (the dark bar above) is clearly the dominant heading. */
        .project-body h2 {
            font-size: 12px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            color: #C45C00;
            border: none;
            margin: 0.9rem 0 0.35rem;
            padding: 0;
        }
        .project-body h3 { font-size: 12.5px; }
"""


def build_header(title_line, subtitle_line, prepared_html, current_date):
    """Build the branded <header> block.

    title_line     — bold line under the brand (e.g. track · age group)
    subtitle_line  — smaller line (e.g. "3 projects · full day")
    prepared_html  — right-hand "Prepared for ... [badge]" block (already HTML)
    current_date   — formatted date string shown top-right
    """
    return f"""    <header>
        <div class="header-meta">
            tinkerwithanne@gmail.com<br>
            Nairobi, Kenya<br>
            {current_date}
        </div>
        <div class="header-brand">TinkerWithMe</div>
        <div class="header-title">{title_line}</div>
        <div class="header-subtitle">{subtitle_line}</div>
        <div class="header-prepared">
            {prepared_html}
        </div>
    </header>"""


def render_document(title, header_html, body_html):
    """Wrap a header + body in the full branded HTML document."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>{CSS}    </style>
</head>
<body>
{header_html}

    <main>
        {body_html}
    </main>
</body>
</html>
"""


def write_pdf(full_html, pdf_path):
    """Render an HTML string to a PDF at pdf_path.

    WeasyPrint is imported lazily so the pure planning logic in the generator
    scripts can be imported and unit-tested without the native PDF stack.
    """
    from weasyprint import HTML

    HTML(string=full_html).write_pdf(pdf_path)
    return str(pdf_path)
