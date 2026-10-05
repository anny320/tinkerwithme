#!/usr/bin/env python3
"""
Turn premium courses into self-paced online courses on the course platform.

Reads premium_courses.json and, for each course asked for, asks Claude once for
a kid-facing online course: lessons written for the student (not a facilitator
plan), each with a short quiz. The result is saved as a DRAFT paid course in
Supabase (lms_courses + lms_lessons), so it appears in teach.html for review
but stays hidden from students until it is published there.

A course whose slug already exists in Supabase is skipped, so nothing you have
edited is ever overwritten. Delete the draft in teach.html to regenerate it.

Run (normally via the elearning-generator.yml workflow):
    ANTHROPIC_API_KEY=... SUPABASE_URL=... SUPABASE_SECRET_KEY=... \
        python generate_elearning.py smart-home-builder deepfake-detective
    python generate_elearning.py --price 3000 smart-home-builder   # set the price
    python generate_elearning.py --no-upload smart-home-builder    # write JSON only
    python generate_elearning.py --from-json smart-home-builder    # upload saved JSON
    python generate_elearning.py --curriculum smart-home-builder   # + full curriculum PDF

With --curriculum, each course also gets the full premium curriculum (written
to the current premium_courses.json timings by pregenerate_premium.py and
rendered by generate_premium.py) attached to its private Downloads
(storage bucket lms-files/<course id>/), so students can download it once
they have access. Courses that already have it are left alone.

Each course is also saved to elearning_drafts/<id>.json (git-ignored: paid content).
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from urllib.parse import quote

import requests
from anthropic import Anthropic

HERE = Path(__file__).parent
DRAFTS = HERE / "elearning_drafts"
MODEL = "claude-opus-5-5"

SYSTEM_PROMPT = """\
You write self-paced online courses for Tinkerwith, a hands-on STEM programme \
in Nairobi, Kenya. The reader is the child taking the course, learning on their \
own at home (a parent may help). There is no teacher in the room, so every \
lesson must be complete on its own: the child should be able to follow it start \
to finish and end up with something that works.

How to write:
- Talk to the child directly ("you"), warmly and plainly. Short sentences, short \
paragraphs. Explain every new word the first time you use it.
- Each lesson is a small step: one idea or one build, about 15–25 minutes.
- Use Markdown: ## and ### headings, numbered steps, bullet lists, **bold** for \
key words, tables for wiring (component → Arduino pin), and fenced code blocks \
(```cpp) for code. No HTML and no images.
- Arduino lessons: start with a "What you need" list (parts and quantities), \
then wiring, then the COMPLETE working sketch with comments a child can follow — \
never abbreviate code — then how to test it and what to do if it doesn't work. \
Mention that the circuit can also be built for free in the Tinkercad Circuits \
simulator (tinkercad.com) for anyone without the parts yet.
- AI lessons: name the free tool and exactly what to click and type, with example \
prompts or inputs, and what a good result looks like. Only use free tools that \
need no payment. Remind children under 13 to ask a parent before signing up for \
anything.
- Keep children safe: no sharing personal details or photos of real people \
online; mains electricity is never used (batteries and USB only).
- End each lesson with a short "Try this" challenge.
- Use Kenyan context where it fits naturally (places, names, everyday examples).
- No purchase links. Name parts plainly (local shops such as Nerokas or Pixel \
Electronics may be named in plain text).

Quizzes: every lesson has 3–4 multiple-choice questions that check \
understanding of that lesson (not trivia). Each question has 3 or 4 options, \
exactly one correct; "answer" is the 0-based index of the correct option. Vary \
the position of the correct answer.
"""

COURSE_SCHEMA = {
    "type": "object",
    "properties": {
        "summary": {"type": "string", "description": "One sentence for the course card, under 160 characters."},
        "description": {"type": "string", "description": "Course page intro in Markdown: what you'll build, what you need, how the course works."},
        "lessons": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "section": {"type": "string", "description": "e.g. 'Part 1: Smart Lighting'"},
                    "title": {"type": "string"},
                    "body": {"type": "string", "description": "The lesson in Markdown."},
                    "quiz": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "q": {"type": "string"},
                                "options": {"type": "array", "items": {"type": "string"}},
                                "answer": {"type": "integer"},
                            },
                            "required": ["q", "options", "answer"],
                            "additionalProperties": False,
                        },
                    },
                },
                "required": ["section", "title", "body", "quiz"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["summary", "description", "lessons"],
    "additionalProperties": False,
}


def build_user_message(course):
    parts = "\n".join(f"  Part {i+1}. {s['title']}: {s['desc']}" for i, s in enumerate(course["sessions"]))
    prereqs = "; ".join(course.get("prereqs") or []) or "none"
    return f"""\
Turn this live premium course into a self-paced online course.

Title: {course['title']}
Track: {course['track']}
Ages: {course['age']}  ·  Level: {course['level']}
Live format: {course['format']}
Summary: {course['summary']}
Parts (one per live session or activity):
{parts}
What students finish with: {course['takeaway']}
Recommended before this course: {prereqs}

Write 2–4 lessons for each part, in order, with "section" set to \
"Part N: <part title>". Begin the first lesson with a short welcome and what \
the child will build; if there are recommended earlier courses, say what the \
child should already know and give a quick refresher. Finish the last lesson \
with a wrap-up of what they built and learned and ideas to keep going.
"""


def write_course(client, course):
    """One Claude call → {summary, description, lessons[]}."""
    with client.beta.messages.stream(
        model=MODEL,
        max_tokens=64000,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": build_user_message(course)}],
        output_config={"effort": "high", "format": {"type": "json_schema", "schema": COURSE_SCHEMA}},
        # If a request is declined, the API re-runs it on Anthropic's
        # recommended fallback model in the same call.
        betas=["server-side-fallback-2026-07-01"],
        fallbacks="default",
    ) as stream:
        message = stream.get_final_message()
    if message.stop_reason == "refusal":
        raise RuntimeError("Claude declined to write this course")
    if message.stop_reason == "max_tokens":
        raise RuntimeError("the course was too long and got cut off")
    text = next(b.text for b in message.content if b.type == "text")
    u = message.usage
    print(f"    tokens: {u.input_tokens} in, {u.output_tokens} out")
    return json.loads(text)


def check(data):
    """Catch anything the course platform would reject or show wrongly."""
    problems = []
    if not data.get("lessons"):
        problems.append("no lessons")
    for i, l in enumerate(data.get("lessons", []), 1):
        if not 1 <= len(l["title"]) <= 160:
            problems.append(f"lesson {i}: title length")
        for j, q in enumerate(l["quiz"], 1):
            if len(q["options"]) < 2 or not 0 <= q["answer"] < len(q["options"]):
                problems.append(f"lesson {i} question {j}: bad answer index")
    return problems


class Supabase:
    def __init__(self, url, key):
        self.base = url.rstrip("/") + "/rest/v1/"
        self.storage = url.rstrip("/") + "/storage/v1/"
        self.h = {"apikey": key, "Content-Type": "application/json"}
        # Legacy service_role keys are JWTs and go in Authorization too; the
        # newer sb_secret_ keys must only be sent as apikey.
        if key.count(".") == 2:
            self.h["Authorization"] = f"Bearer {key}"

    def get(self, table, **params):
        r = requests.get(self.base + table, headers=self.h, params=params, timeout=30)
        r.raise_for_status()
        return r.json()

    def insert(self, table, rows):
        r = requests.post(self.base + table, headers={**self.h, "Prefer": "return=representation"},
                          json=rows, timeout=60)
        if not r.ok:
            raise RuntimeError(f"Supabase {table}: {r.status_code} {r.text[:300]}")
        return r.json()

    def delete(self, table, **params):
        requests.delete(self.base + table, headers=self.h, params=params, timeout=30)

    def list_files(self, bucket, folder):
        r = requests.post(f"{self.storage}object/list/{bucket}", headers=self.h,
                          json={"prefix": folder + "/", "limit": 100}, timeout=30)
        if not r.ok:
            raise RuntimeError(f"Storage list: {r.status_code} {r.text[:300]}")
        return [f["name"] for f in r.json() if f.get("id")]

    def upload_file(self, bucket, path, local, content_type):
        h = {k: v for k, v in self.h.items() if k != "Content-Type"}
        r = requests.post(f"{self.storage}object/{bucket}/{quote(path)}", data=Path(local).read_bytes(),
                          headers={**h, "Content-Type": content_type, "x-upsert": "true"}, timeout=120)
        if not r.ok:
            raise RuntimeError(f"Storage upload: {r.status_code} {r.text[:300]}")


def curriculum_name(course):
    return re.sub(r"[^\w.() -]+", "-", f"{course['title']} - full curriculum.pdf")


def attach_curriculum(db, course, course_uuid, maker_kit):
    """Write the full curriculum (new AI call), render it, and add it to the
    course's Downloads and to the teach-it-yourself shop (curriculum/<id>/)."""
    name = curriculum_name(course)
    targets = [f"{course_uuid}/{name}", f"curriculum/{course['id']}/{name}"]
    missing = [t for t in targets if t.rsplit("/", 1)[1] not in db.list_files("lms-files", t.rsplit("/", 1)[0])]
    if not missing:
        print("    curriculum PDF already in Downloads and the curriculum shop — left as is")
        return
    import generate_premium, pregenerate_premium  # need weasyprint; only loaded for --curriculum
    content_dir, out_dir = HERE / "premium_content", HERE / "curriculums"
    content_dir.mkdir(exist_ok=True); out_dir.mkdir(exist_ok=True)
    pdf = out_dir / f"{course['id']}.pdf"
    if not pdf.exists():
        pregenerate_premium.generate_course(course, content_dir, force=True)
        generate_premium.MAKER_KIT = maker_kit
        pdf = generate_premium.generate_curriculum_one(course, content_dir, out_dir)
    if not pdf:
        raise RuntimeError("the full curriculum couldn't be written")
    for t in missing:
        db.upload_file("lms-files", t, pdf, "application/pdf")
    print(f"    full curriculum PDF added ({name}): course Downloads and curriculum shop")


def upload(db, course, data, price):
    row = db.insert("lms_courses", {
        "slug": course["id"],
        "title": course["title"][:120],
        "summary": data["summary"],
        "description": data["description"],
        "age_range": course["age"].replace(" yrs", "").strip(),
        "price_kes": price,
        "price_usd": course.get("self_paced_price_usd"),
        "is_published": False,
        "position": 100,
    })[0]
    try:
        db.insert("lms_lessons", [
            {"course_id": row["id"], "position": i, "section": l["section"], "title": l["title"],
             "body": l["body"], "quiz": l["quiz"]}
            for i, l in enumerate(data["lessons"], 1)
        ])
    except Exception:
        db.delete("lms_courses", id=f"eq.{row['id']}")  # don't leave a half-made course
        raise
    return row["id"]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ids", nargs="+", help="premium course IDs from premium_courses.json")
    ap.add_argument("--price", type=int, help="price in KES (default: the course's self_paced_price)")
    ap.add_argument("--no-upload", action="store_true", help="only write elearning_drafts/<id>.json")
    ap.add_argument("--from-json", action="store_true", help="upload the saved JSON instead of calling Claude")
    ap.add_argument("--curriculum", action="store_true", help="also attach the full curriculum PDF to the course's Downloads")
    args = ap.parse_args()

    premium = json.loads((HERE / "premium_courses.json").read_text())
    catalogue = {c["id"]: c for c in premium["courses"]}
    unknown = [i for i in args.ids if i not in catalogue]
    if unknown:
        sys.exit(f"Unknown course IDs: {', '.join(unknown)}")

    db = None
    if not args.no_upload:
        url, key = os.getenv("SUPABASE_URL"), os.getenv("SUPABASE_SECRET_KEY")
        if not url or not key:
            sys.exit("Set SUPABASE_URL and SUPABASE_SECRET_KEY (or use --no-upload).")
        db = Supabase(url, key)
    client = None if args.from_json else Anthropic()
    DRAFTS.mkdir(exist_ok=True)

    failed = []
    for cid in args.ids:
        course = catalogue[cid]
        print(f"\n▶ {course['title']} ({cid})")
        path = DRAFTS / f"{cid}.json"
        try:
            existing = db.get("lms_courses", slug=f"eq.{cid}", select="id") if db else []
            if existing:
                print("    already on the course platform — lessons left as they are (delete the draft in teach.html to redo them)")
                if args.curriculum:
                    attach_curriculum(db, course, existing[0]["id"], premium.get("maker_kit", {}))
                continue
            if args.from_json:
                data = json.loads(path.read_text())
            else:
                data = write_course(client, course)
                path.write_text(json.dumps(data, indent=1, ensure_ascii=False))
            problems = check(data)
            if problems:
                raise RuntimeError("; ".join(problems))
            n_q = sum(len(l["quiz"]) for l in data["lessons"])
            print(f"    {len(data['lessons'])} lessons, {n_q} quiz questions → {path.relative_to(HERE)}")
            if db:
                price = args.price if args.price is not None else int(course.get("self_paced_price") or course["price"])
                if args.curriculum:
                    data["description"] += ("\n\n📥 **Includes the full course curriculum as a PDF download**, "
                                            "ready once you're signed in with access to the course.")
                course_uuid = upload(db, course, data, price)
                print(f"    saved as a DRAFT at KES {price:,} — review it in teach.html")
                if args.curriculum:
                    attach_curriculum(db, course, course_uuid, premium.get("maker_kit", {}))
        except Exception as e:
            print(f"    ✗ {e}")
            failed.append(cid)

    if failed:
        sys.exit(f"\nFailed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
