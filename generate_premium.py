#!/usr/bin/env python3
"""
Render a branded one-page(ish) outline PDF for every TinkerWithMe PREMIUM course.

Reads premium_courses.json (the single source of truth) and writes
proposals/<id>.pdf for each course using the shared pdf_template chrome — the
same look as the curriculum generator and camp planner.

These outlines are fully authored (no AI, no personalisation), so they are
generated once and committed; courses.html links straight to the static files,
so a parent downloads instantly with no workflow trigger.

Run:  python generate_premium.py            # all courses
      python generate_premium.py smart-city # just one (by id)
"""

import json
import sys
from pathlib import Path

import pdf_template

TRACK_LABEL = {
    "arduino": "Arduino Robotics & Electronics",
    "ai": "AI Skills for Kids",
    "combo": "Combo · Arduino + AI",
}


def _facts_table(course):
    prereq = ", ".join(course["prereqs"]) if course["prereqs"] else "None — standalone"
    rows = [
        ("Track", TRACK_LABEL.get(course["track"], course["track"])),
        ("Format", course["format"]),
        ("Ages", course["age"]),
        ("Level", course["level"]),
        ("Price", f"from KES {course['price']:,}"),
        ("Standalone", "Yes" if course["standalone"] else "No"),
        ("Prerequisites", prereq),
    ]
    body = "".join(f"<tr><td><strong>{k}</strong></td><td>{v}</td></tr>" for k, v in rows)
    return ("<table><thead><tr><th>Detail</th><th></th></tr></thead>"
            f"<tbody>{body}</tbody></table>\n")


def _programme(course):
    items = "".join(
        f"<li><strong>{s['title']}.</strong> {s['desc']}</li>" for s in course["sessions"]
    )
    return f"<h2>Programme</h2>\n<ol>{items}</ol>\n"


def build_body(course):
    return (
        "<h2>Overview</h2>\n"
        f"<p>{course['summary']}</p>\n"
        + _facts_table(course)
        + _programme(course)
        + "<h2>What they take home</h2>\n"
        f"<p>🎁 {course['takeaway']}</p>\n"
        + "<h2>Why parents love it</h2>\n"
        f"<p><em>“{course['pitch']}”</em></p>\n"
        + "<h2>How to book</h2>\n"
        "<p>Places are limited and run on scheduled dates. To book or ask a "
        "question, email <strong>tinkerwithanne@gmail.com</strong> with the course "
        f"name (<strong>{course['title']}</strong>), your child's age, and your "
        "preferred dates. Prices start from the amount above and may vary with group "
        "size and materials.</p>\n"
    )


def generate_one(course, out_dir):
    body_html = build_body(course)
    prepared_html = ('Premium course outline'
                     '<span class="session-badge">Premium</span>')
    header_html = pdf_template.build_header(
        title_line=f"{course['title']} · Premium Course",
        subtitle_line=f"{course['format']} · {course['age']} · from KES {course['price']:,}",
        prepared_html=prepared_html,
        current_date="",
    )
    full_html = pdf_template.render_document(
        title=f"TinkerWithMe Premium - {course['title']}",
        header_html=header_html,
        body_html=body_html,
    )
    out_file = out_dir / f"{course['id']}.pdf"
    pdf_template.write_pdf(full_html, out_file)
    print(f"  ✅ {course['id']}.pdf")
    return out_file


def build_curriculum_body(course, content_html):
    """Full facilitator curriculum: the course facts, then the cached lesson HTML."""
    return (
        "<h2>Overview</h2>\n"
        f"<p>{course['summary']}</p>\n"
        + _facts_table(course)
        + content_html
    )


def generate_curriculum_one(course, content_dir, out_dir):
    """Render a full-curriculum PDF from cached premium_content, if present."""
    cache = content_dir / f"{course['id']}.json"
    if not cache.exists():
        return None
    content = json.loads(cache.read_text(encoding="utf-8")).get("content_html", "")
    if not content.strip():
        return None
    prepared_html = ('Full facilitator curriculum'
                     '<span class="session-badge">Premium</span>')
    header_html = pdf_template.build_header(
        title_line=f"{course['title']} · Full Curriculum",
        subtitle_line=f"{course['format']} · {course['age']} · {course['level']}",
        prepared_html=prepared_html,
        current_date="",
    )
    full_html = pdf_template.render_document(
        title=f"TinkerWithMe Premium Curriculum - {course['title']}",
        header_html=header_html,
        body_html=build_curriculum_body(course, content),
    )
    out_file = out_dir / f"{course['id']}.pdf"
    pdf_template.write_pdf(full_html, out_file)
    print(f"  📚 {course['id']}.pdf")
    return out_file


def main():
    data = json.loads(Path("premium_courses.json").read_text(encoding="utf-8"))
    args = sys.argv[1:]
    curriculum_mode = "--curriculums" in args
    only = {a for a in args if not a.startswith("--")}

    if curriculum_mode:
        # Render full-curriculum PDFs from whatever premium_content is cached, and
        # write an index so courses.html knows which courses have a curriculum.
        content_dir = Path("premium_content")
        out_dir = Path("curriculums")
        out_dir.mkdir(exist_ok=True)
        available = []
        for course in data["courses"]:
            if only and course["id"] not in only:
                continue
            if generate_curriculum_one(course, content_dir, out_dir):
                available.append(course["id"])
        (out_dir / "index.json").write_text(
            json.dumps({"available": available}, indent=2), encoding="utf-8")
        print(f"\nGenerated {len(available)} full-curriculum PDF(s) → curriculums/")
        return

    out_dir = Path("proposals")
    out_dir.mkdir(exist_ok=True)
    n = 0
    for course in data["courses"]:
        if only and course["id"] not in only:
            continue
        generate_one(course, out_dir)
        n += 1
    print(f"\nGenerated {n} premium outline PDF(s) → proposals/")


if __name__ == "__main__":
    main()
