#!/usr/bin/env python3
"""
Pre-generate the FULL facilitator curriculum for every premium course.

Reads premium_courses.json and, for each course, asks Claude once for a complete
multi-session teaching curriculum (per-session lesson plans with objectives,
materials, step-by-step instructions, full Arduino code / exact AI tool
workflows, assessment and extensions). The result is cached to
premium_content/<id>.json so PDFs can be assembled later with ZERO further
tokens — the same cache pattern as pregenerate.py for the free projects.

Run (needs a key; normally via the pregenerate-premium.yml workflow):
    ANTHROPIC_API_KEY=sk-... python pregenerate_premium.py
    python pregenerate_premium.py smart-city ai-movie-studio   # only these
    python pregenerate_premium.py --force                      # regenerate all
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

from generate_curriculum import stream_html  # streaming Claude helper


def git_push_file(path):
    """Commit + push one generated file so progress is durable (COMMIT_EACH=1)."""
    if os.getenv("COMMIT_EACH") != "1":
        return
    for _ in range(3):
        try:
            subprocess.run(["git", "add", str(path)], check=True)
            if subprocess.run(["git", "diff", "--cached", "--quiet"]).returncode == 0:
                return
            subprocess.run(["git", "commit", "-m", f"Pre-generate premium {path.name}"], check=True)
            subprocess.run(["git", "push", "origin", "HEAD:main"], check=True)
            return
        except subprocess.CalledProcessError:
            subprocess.run(["git", "pull", "--rebase", "origin", "main"])
            time.sleep(2)
    print(f"    ⚠️  could not push {path.name} after retries")


SYSTEM_PROMPT = (
    "You are the lead curriculum designer for TinkerWithMe, a hands-on STEM "
    "programme in Nairobi. You write complete, ready-to-teach curriculums for "
    "premium courses — a facilitator should be able to run every session straight "
    "from your document with no extra prep. Be concrete and specific. Do NOT "
    "include purchase links or URLs; name materials by item, spec and quantity "
    "(local suppliers such as Nerokas or Pixel Electronics may be named in plain "
    "text). Output clean HTML only (no markdown, no inline styles): use <h2>, "
    "<h3>, <h4>, <p>, <ul>/<ol>/<li>, <table>, <strong>, <em>, and <pre><code> "
    "for any code. Never write \"standard sketch\" or otherwise abbreviate code — "
    "include the complete, working program every time."
)


def build_user_message(course):
    sessions = "\n".join(
        f"  {i+1}. {s['title']} — {s['desc']}" for i, s in enumerate(course["sessions"])
    )
    track = course["track"]
    if track == "ai":
        per_session = (
            "the exact AI tools/websites and how to set them up, the precise "
            "step-by-step workflow, the exact example prompts / sample inputs to "
            "use, what a good result looks like, and how students test/iterate"
        )
    elif track == "combo":
        per_session = (
            "for the hardware parts a wiring list (component → pin) and the COMPLETE "
            "working Arduino code inside <pre><code>; for the AI parts the exact "
            "tools, step-by-step workflow and example prompts; plus how the two "
            "halves connect"
        )
    else:  # arduino
        per_session = (
            "a materials list, a wiring/assembly list (component → pin) and the "
            "COMPLETE working Arduino sketch inside <pre><code> with inline comments"
        )

    return f"""Write the complete facilitator curriculum for this premium TinkerWithMe course.

**Course:** {course['title']}
**Track:** {track}
**Format:** {course['format']}
**Ages:** {course['age']}  ·  **Level:** {course['level']}
**Summary:** {course['summary']}
**Take-home:** {course['takeaway']}
**Sessions/parts (expand each into a full lesson):**
{sessions}

Produce these HTML sections in order:

<h2>Course Overview</h2>
2–3 short paragraphs: what the course is, the arc across the sessions, and the final outcome/take-home.

<h2>Learning Outcomes</h2>
5–7 bullet points — concrete skills and knowledge students leave with.

<h2>Materials Master List</h2>
A <table> (Item | Spec | Qty per student/group | Notes) covering everything needed across all sessions.

<h2>Session Plans</h2>
For EACH session/part above, a <h3> with the session title, then:
- <strong>Objectives</strong> (2–3 bullets)
- <strong>Timing</strong> (a rough minute-by-minute breakdown for the session length)
- <strong>Step-by-step</strong> teaching instructions the facilitator follows live
- <strong>Build detail:</strong> {per_session}
- <strong>Checks for understanding</strong> (2–3 quick questions)
- <strong>Common mistakes &amp; fixes</strong> (a short <table>)

<h2>Assessment &amp; Showcase</h2>
How to assess progress and run the final share/demo; what "done" looks like.

<h2>Extension &amp; Home Challenges</h2>
3 progressively harder challenges (Easy / Medium / Hard) for fast finishers or homework.

Output only these HTML sections — no DOCTYPE, <html>, <head> or <body> tags."""


def generate_course(course, out_dir, force=False):
    out_file = out_dir / f"{course['id']}.json"
    if out_file.exists() and not force:
        print(f"  ✓ {course['id']} already exists, skipping")
        return
    print(f"  → Generating {course['id']}: {course['title']}…", flush=True)
    try:
        # Scale the budget with the number of sessions; full code per session
        # needs room. stream_html uses messages.stream() so large budgets are OK.
        max_tokens = min(32000, 14000 + len(course["sessions"]) * 6000)
        html = stream_html(SYSTEM_PROMPT, build_user_message(course), max_tokens=max_tokens)
        if not html or not html.strip():
            print(f"    FAILED: empty response")
            return
        data = {
            "id": course["id"], "track": course["track"], "title": course["title"],
            "format": course["format"], "age": course["age"], "level": course["level"],
            "content_html": html.strip(),
        }
        out_file.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"    done ({len(html)} chars)")
        git_push_file(out_file)
    except Exception as e:
        print(f"    FAILED: {e}")


def main():
    if not os.getenv("ANTHROPIC_API_KEY"):
        print("❌  Set ANTHROPIC_API_KEY first (this generation uses the Anthropic API).")
        sys.exit(1)
    force = "--force" in sys.argv
    only = {a for a in sys.argv[1:] if not a.startswith("--")}

    data = json.loads(Path("premium_courses.json").read_text(encoding="utf-8"))
    out_dir = Path("premium_content")
    out_dir.mkdir(exist_ok=True)

    n = 0
    for course in data["courses"]:
        if only and course["id"] not in only:
            continue
        generate_course(course, out_dir, force=force)
        n += 1
        time.sleep(1)
    print(f"\n✅  Done — {n} course(s) processed → premium_content/")


if __name__ == "__main__":
    main()
