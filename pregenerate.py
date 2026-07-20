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

COURSE_DATA = {
    "arduino": [
        {"id": "ar1",  "title": "Traffic light simulation",    "diff": "Beginner",     "age": "6-9 yrs",   "time": 60,  "desc": "3 LEDs mimic real traffic light sequences"},
        {"id": "ar2",  "title": "Button controlled LED",       "diff": "Beginner",     "age": "6-9 yrs",   "time": 45,  "desc": "Push button toggles LED on/off"},
        {"id": "ar3",  "title": "Fade an LED",                 "diff": "Beginner",     "age": "6-9 yrs",   "time": 45,  "desc": "PWM & analogWrite() to dim LED smoothly"},
        {"id": "ar4",  "title": "RGB LED colour mixer",        "diff": "Beginner",     "age": "6-9 yrs",   "time": 60,  "desc": "3 potentiometers mix red, green & blue"},
        {"id": "ar5",  "title": "Capacitive touch sensor",     "diff": "Beginner",     "age": "10-12 yrs", "time": 60,  "desc": "Touch sensor module toggles an LED"},
        {"id": "ar6",  "title": "Buzzer melody",               "diff": "Beginner",     "age": "6-9 yrs",   "time": 60,  "desc": "Piezo buzzer plays tunes like Ode to Joy"},
        {"id": "ar7",  "title": "Morse code blinker",          "diff": "Intermediate", "age": "10-12 yrs", "time": 75,  "desc": "LED blinks out Morse code messages"},
        {"id": "ar8",  "title": "Temperature logger",          "diff": "Intermediate", "age": "10-12 yrs", "time": 90,  "desc": "DHT11 reads & displays temperature"},
        {"id": "ar9",  "title": "Ultrasonic distance sensor",  "diff": "Intermediate", "age": "10-12 yrs", "time": 75,  "desc": "HC-SR04 measures distance, LED warns on proximity"},
        {"id": "ar10", "title": "Servo motor control",         "diff": "Intermediate", "age": "10-12 yrs", "time": 75,  "desc": "Potentiometer steers servo to any position"},
        {"id": "ar11", "title": "Light-activated LED",         "diff": "Beginner",     "age": "6-9 yrs",   "time": 60,  "desc": "Photoresistor auto-lights LED when dark"},
        {"id": "ar12", "title": "Digital dice",                "diff": "Intermediate", "age": "10-12 yrs", "time": 90,  "desc": "Multiple LEDs randomly show a dice roll"},
        {"id": "ar13", "title": "Basic alarm system",          "diff": "Intermediate", "age": "10-12 yrs", "time": 90,  "desc": "Motion sensor triggers buzzer & LED alarm"},
        {"id": "ar14", "title": "Fan control",                 "diff": "Advanced",     "age": "13-15 yrs", "time": 90,  "desc": "Temperature sensor controls relay-powered fan"},
        {"id": "ar15", "title": "Simon says game",             "diff": "Advanced",     "age": "13-15 yrs", "time": 120, "desc": "Classic memory game with LEDs, buttons & buzzer"},
    ],
    "ai": [
        {"id": "a1", "title": "Prompting power",      "diff": "Beginner",     "age": "7-10 yrs",  "time": 60,  "desc": "ChatGPT basics — ask better questions"},
        {"id": "a2", "title": "AI art studio",        "diff": "Beginner",     "age": "7-10 yrs",  "time": 60,  "desc": "DALL-E image generation workshop"},
        {"id": "a3", "title": "AI music & sound",     "diff": "Beginner",     "age": "7-10 yrs",  "time": 60,  "desc": "Generate soundtracks and beats"},
        {"id": "a4", "title": "AI storytelling",      "diff": "Beginner",     "age": "10-13 yrs", "time": 75,  "desc": "Write illustrated stories with AI"},
        {"id": "a5", "title": "Teachable Machine",    "diff": "Intermediate", "age": "10-13 yrs", "time": 90,  "desc": "Train your own image classifier"},
        {"id": "a6", "title": "Mashup madness",       "diff": "Intermediate", "age": "10-13 yrs", "time": 90,  "desc": "Combine multiple AI tools creatively"},
        {"id": "a7", "title": "Bias detective",       "diff": "Intermediate", "age": "13-16 yrs", "time": 75,  "desc": "Find and discuss bias in AI tools"},
        {"id": "a8", "title": "AI careers deep dive", "diff": "Intermediate", "age": "13-16 yrs", "time": 60,  "desc": "ML engineers, ethicists, data scientists"},
        {"id": "a9", "title": "Build your portfolio", "diff": "Advanced",     "age": "13-16 yrs", "time": 120, "desc": "GitHub, pitch deck, and showcase prep"},
    ],
}

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
        message = client.messages.create(
            model="claude-sonnet-5",
            max_tokens=6000,
            messages=[{"role": "user", "content": prompt}],
        )
        content_html = next(
            (block.text for block in message.content if block.type == "text"), ""
        )
        # Strip any accidental markdown fences
        content_html = content_html.strip()
        if content_html.startswith("```"):
            content_html = content_html.split("\n", 1)[1].rsplit("```", 1)[0].strip()

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
