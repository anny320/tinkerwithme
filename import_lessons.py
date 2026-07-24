#!/usr/bin/env python3
"""
Import authored lesson markdown into project_content/<id>.json — with ZERO AI
tokens. Use this to seed catalogue projects from lesson copy you've already
written (e.g. content_source/ai_lessons.md), instead of AI-generating them.

Run:  python import_lessons.py content_source/ai_lessons.md

Markdown format (see content_source/ai_lessons.md for a worked example):

    ## Lesson: <title>
    project: <catalogue id>          # metadata is looked up from courses.json
    **What you'll learn**  … text …
    **Key idea**  … text …
    **Activity**  … text (bullet lines with "- " become a list) …
    **Reflection** / **Remember**  … optional …
    **Quiz**
    Q: <question>
    - option
    - option [correct]

Each lesson is written to project_content/<id>.json in the same shape as
pregenerate.py, so the generators pick it up as cached content automatically.
"""

import json
import re
import sys
from pathlib import Path

# Map a lesson's section label -> the <h2> heading used in the rendered content.
SECTION_HEADINGS = {
    "what you'll learn": "What we're doing",
    "what you will learn": "What we're doing",
    "key idea": "The big idea",
    "activity": "Activity",
    "reflection": "Reflection",
    "remember": "Key takeaway",
    "facilitation tips": "Facilitation tips",
}


def load_catalogue():
    path = Path(__file__).with_name("courses.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    index = {}
    for track, info in data.items():
        for p in info.get("projects", []):
            index[p["id"]] = {**p, "track": track}
    return index


def esc(text):
    return (text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def split_lessons(md):
    """Yield (title, body_lines) per '## Lesson: <title>' block."""
    lines = md.splitlines()
    blocks, cur, title = [], None, None
    for line in lines:
        m = re.match(r"^##\s+Lesson:\s*(.+?)\s*$", line)
        if m:
            if cur is not None:
                blocks.append((title, cur))
            title, cur = m.group(1), []
        elif cur is not None:
            cur.append(line)
    if cur is not None:
        blocks.append((title, cur))
    return blocks


def parse_lesson(body_lines):
    """Return (project_id, sections dict, quiz dict) from a lesson body."""
    project_id, sections, quiz = None, [], None
    label, buf = None, []

    def flush():
        if label is not None:
            sections.append((label, "\n".join(buf).strip()))

    for line in body_lines:
        pm = re.match(r"^project:\s*([A-Za-z0-9_-]+)\s*$", line.strip())
        if pm:
            project_id = pm.group(1)
            continue
        hm = re.match(r"^\*\*(.+?)\*\*\s*(.*)$", line.strip())
        if hm:
            flush()
            label = hm.group(1).strip().lower().rstrip(":")
            buf = [hm.group(2)] if hm.group(2).strip() else []
            if label == "quiz":
                label = None  # quiz handled separately below
                quiz = {"question": None, "options": []}
            continue
        if quiz is not None:
            qm = re.match(r"^Q:\s*(.+)$", line.strip())
            if qm:
                quiz["question"] = qm.group(1).strip()
                continue
            om = re.match(r"^-\s*(.+?)\s*$", line.strip())
            if om:
                opt = om.group(1)
                correct = "[correct]" in opt.lower()
                opt = re.sub(r"\s*\[correct\]\s*", "", opt, flags=re.I).strip()
                quiz["options"].append((opt, correct))
                continue
        elif label is not None:
            buf.append(line)
    flush()
    return project_id, sections, quiz


def render_html(sections, quiz):
    parts = []
    combined_intro = {}
    for label, text in sections:
        if not text:
            continue
        if label in ("what you'll learn", "what you will learn", "key idea"):
            combined_intro[label] = text
            continue
        heading = SECTION_HEADINGS.get(label, label.title())
        parts.append(_section_html(heading, text))
    # Merge the two intro blurbs into one "What we're doing".
    intro = " ".join(
        combined_intro.get(k, "")
        for k in ("what you'll learn", "what you will learn", "key idea")
    ).strip()
    if intro:
        parts.insert(0, f"<h2>What we're doing</h2>\n<p>{esc(intro)}</p>")

    if quiz and quiz.get("question"):
        opts = "".join(
            f"<li>{'<strong>' if c else ''}{esc(o)}{' ✔' if c else ''}{'</strong>' if c else ''}</li>"
            for o, c in quiz["options"]
        )
        parts.append(
            "<h2>Quick check</h2>\n"
            f"<p><strong>{esc(quiz['question'])}</strong></p>\n<ul>{opts}</ul>"
        )
    return "\n".join(parts) + "\n"


def _section_html(heading, text):
    bullet_lines = [l for l in text.splitlines() if l.strip().startswith("- ")]
    if bullet_lines:
        items = "".join(f"<li>{esc(l.strip()[2:])}</li>" for l in bullet_lines)
        return f"<h2>{esc(heading)}</h2>\n<ul>{items}</ul>"
    return f"<h2>{esc(heading)}</h2>\n<p>{esc(text)}</p>"


def main():
    if len(sys.argv) < 2:
        print("usage: python import_lessons.py <lessons.md>")
        sys.exit(1)
    src = Path(sys.argv[1])
    catalogue = load_catalogue()
    out_dir = Path(__file__).with_name("project_content")
    out_dir.mkdir(exist_ok=True)

    md = src.read_text(encoding="utf-8")
    written = 0
    for title, body in split_lessons(md):
        pid, sections, quiz = parse_lesson(body)
        if not pid:
            print(f"  ⚠️  '{title}' has no 'project:' id — skipped")
            continue
        meta = catalogue.get(pid)
        if not meta:
            print(f"  ⚠️  '{title}' → id {pid} not in courses.json — skipped")
            continue
        data = {
            "id": pid,
            "track": meta["track"],
            "title": meta["title"],
            "diff": meta["diff"],
            "age": meta["age"],
            "time": meta["time"],
            "desc": meta["desc"],
            "content_html": render_html(sections, quiz),
        }
        out = out_dir / f"{pid}.json"
        with open(out, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"  ✓ {pid}  ({meta['title']}) → {out.name}")
        written += 1

    print(f"\n✅  Imported {written} lesson(s) → project_content/ (0 AI tokens)")


if __name__ == "__main__":
    main()
