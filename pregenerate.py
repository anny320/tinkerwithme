#!/usr/bin/env python3
"""
Pre-generate core lesson content for every TinkerWithMe project.

Run once:  ANTHROPIC_API_KEY=sk-... python pregenerate.py

Saves project_content/{id}.json for all 24 projects.
generate_curriculum.py reads these at request time and only asks Claude
to personalise/assemble — cutting generation time from ~3 min to ~30 s.
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path
from anthropic import Anthropic


def git_push_file(path):
    """Commit and push a single generated file so progress is durable.

    Enabled only when COMMIT_EACH=1 (set by the GitHub Actions workflow); a
    no-op for local runs. Best-effort: on a push race it rebases and retries.
    """
    if os.getenv("COMMIT_EACH") != "1":
        return
    for _ in range(3):
        try:
            subprocess.run(["git", "add", str(path)], check=True)
            if subprocess.run(["git", "diff", "--cached", "--quiet"]).returncode == 0:
                return  # nothing new to commit
            subprocess.run(["git", "commit", "-m", f"Pre-generate {path.name}"], check=True)
            subprocess.run(["git", "push", "origin", "HEAD:main"], check=True)
            return
        except subprocess.CalledProcessError:
            # Likely a push race with another commit to main — rebase and retry.
            subprocess.run(["git", "pull", "--rebase", "origin", "main"])
            time.sleep(2)
    print(f"    ⚠️  could not push {path.name} after retries (will retry on next run)")

def load_courses():
    """Return {track: [project, ...]} from the shared courses.json catalogue."""
    path = Path(__file__).with_name("courses.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return {track: info.get("projects", []) for track, info in data.items()}


COURSE_DATA = load_courses()

ARDUINO_PROMPT = """\
You are an expert STEM educator writing reusable lesson content for TinkerWithMe, a hands-on Arduino programme for children in Nairobi.

Generate comprehensive, self-contained lesson content for the project below. This content will be stored and later assembled into personalised PDFs, so write it as neutral, teacher-facing reference material — no specific age group or audience framing yet.

Project: {title} ({diff})
Description: {desc}
Typical duration: {time} minutes

Include ALL of the following sections as clean HTML (no markdown, no inline styles):

<h2>Materials</h2>
Full component list with quantities. For each item include the local supplier in parentheses — use Nerokas (nerokas.co.ke) or Pixel Electronics (pixelelectronics.co.ke) for Nairobi.

<h2>How It Works</h2>
Plain-English explanation of the electronics/code concept. No jargon — explain as if to an intelligent 10-year-old.

<h2>Step-by-Step Instructions</h2>
Numbered steps a teacher can follow live with students. Each step on its own <li>. Include wiring notes and what students should observe.

<h2>Full Code</h2>
Complete, working Arduino sketch inside <pre><code> tags. Add inline comments on every non-obvious line. Do NOT truncate — the full sketch must compile and run.

<h2>Common Mistakes & Fixes</h2>
A <table> with columns: Symptom | Likely Cause | Fix. Include at least 4 rows covering the most frequent issues for this specific project.

<h2>Discussion Questions</h2>
5 questions that check understanding and spark curiosity. Mix recall and open-ended.

<h2>Extension Challenges</h2>
3 progressively harder challenges for students who finish early. Label them Easy / Medium / Hard.

Output only the HTML sections above — no DOCTYPE, no <html>, no <body>, no <head>."""

AI_PROMPT = """\
You are an expert STEM educator writing reusable lesson content for TinkerWithMe, an AI literacy programme for children in Nairobi.

Generate comprehensive, self-contained lesson content for the project below. This content will be stored and later assembled into personalised PDFs, so write it as neutral, teacher-facing reference material — no specific age group or audience framing yet.

Project: {title} ({diff})
Description: {desc}
Typical duration: {time} minutes

Include ALL of the following sections as clean HTML (no markdown, no inline styles):

<h2>What We're Doing</h2>
A clear, engaging explanation of the activity and what students will create or explore.

<h2>Tools & Resources</h2>
List of AI tools, websites, or apps used — with URLs. Note any free-tier limits to watch for.

<h2>Step-by-Step Activity</h2>
Numbered steps a teacher can follow live. Include exact prompts or inputs where relevant. Each step on its own <li>.

<h2>Example Outputs</h2>
2–3 concrete examples of what good student work looks like for this activity.

<h2>Facilitation Tips</h2>
Practical advice for managing the activity in a group setting — pacing, common confusions, how to handle unexpected AI outputs.

<h2>Discussion Questions</h2>
5 questions that check understanding and spark critical thinking about AI. Mix factual and open-ended.

<h2>Extension Challenges</h2>
3 progressively harder challenges. Label them Easy / Medium / Hard.

Output only the HTML sections above — no DOCTYPE, no <html>, no <body>, no <head>."""


def generate_project(client, track, project, out_dir, force=False):
    out_file = out_dir / f"{project['id']}.json"
    if out_file.exists() and not force:
        print(f"  ✓ {project['id']} already exists, skipping")
        return

    prompt_template = ARDUINO_PROMPT if track == "arduino" else AI_PROMPT
    prompt = prompt_template.format(**project)

    print(f"  → Generating {project['id']}: {project['title']}...", end="", flush=True)
    try:
        # thinking disabled + a generous budget so the whole allowance goes to
        # the HTML. (Sonnet 5 runs adaptive thinking by default, which on a
        # complex prompt could eat the budget and return no text block — that's
        # what produced an empty "Smart city" file.)
        message = client.messages.create(
            model="claude-sonnet-5",
            max_tokens=12000,
            thinking={"type": "disabled"},
            messages=[{"role": "user", "content": prompt}],
        )
        content_html = next(
            (block.text for block in message.content if block.type == "text"), ""
        )
        # Strip any accidental markdown fences
        content_html = content_html.strip()
        if content_html.startswith("```"):
            content_html = content_html.split("\n", 1)[1].rsplit("```", 1)[0].strip()

        # Never cache an empty result — leave the file absent so a re-run retries
        # instead of a blank being treated as "already done".
        if not content_html:
            print(f" FAILED: empty response (stop_reason={message.stop_reason})")
            return

        data = {
            "id": project["id"],
            "track": track,
            "title": project["title"],
            "diff": project["diff"],
            "age": project["age"],
            "time": project["time"],
            "desc": project["desc"],
            "content_html": content_html,
        }
        with open(out_file, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f" done ({len(content_html)} chars)")
        # Persist immediately so a cancel/timeout never loses completed work.
        git_push_file(out_file)
    except Exception as e:
        print(f" FAILED: {e}")


def main():
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        print("❌  Set ANTHROPIC_API_KEY first.")
        sys.exit(1)

    force = "--force" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]  # e.g. ar1 a3

    client = Anthropic(api_key=api_key)
    out_dir = Path("project_content")
    out_dir.mkdir(exist_ok=True)

    total = 0
    for track, projects in COURSE_DATA.items():
        print(f"\n{'='*50}")
        print(f"Track: {track.upper()}")
        print(f"{'='*50}")
        for project in projects:
            if only and project["id"] not in only:
                continue
            generate_project(client, track, project, out_dir, force=force)
            total += 1
            time.sleep(1)  # avoid rate limits

    print(f"\n✅  Done — {total} project(s) processed → project_content/")


if __name__ == "__main__":
    main()
