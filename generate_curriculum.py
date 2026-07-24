#!/usr/bin/env python3
"""
TinkerWithMe Curriculum Generator Agent

Generates detailed lesson plans using Claude AI based on selected projects.
Outputs professional PDF with TinkerWithMe branding and footer.
Triggered via button click from curriculumgenerator.html (password-gated).
"""

import json
import os
import re
import sys
from pathlib import Path
from datetime import datetime
from anthropic import Anthropic

import pdf_template


def stream_html(system_prompt, user_message, max_tokens, model="claude-sonnet-5"):
    """Call Claude and return cleaned HTML, always via streaming.

    The Anthropic SDK refuses a NON-streaming request whenever it estimates the
    call could run past ~10 minutes (large max_tokens trips this and raises
    "Streaming is required..."). Streaming avoids that guard and the idle-timeout
    disconnects, so every generation here goes through messages.stream().
    """
    client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    with client.messages.stream(
        model=model,
        max_tokens=max_tokens,
        system=system_prompt,
        messages=[{"role": "user", "content": user_message}],
    ) as stream:
        message = stream.get_final_message()
    if message.stop_reason == "max_tokens":
        print("⚠️  Response truncated at max_tokens.")
    html = next(block.text for block in message.content if block.type == "text")
    html = re.sub(r"^```(?:html)?\s*\n?", "", html.strip())
    html = re.sub(r"\n?```\s*$", "", html)
    return html


# Course catalogue — single source of truth in courses.json (shared with the
# HTML pages and pregenerate.py). Add a project there once, not in five files.
def load_courses():
    """Load the course catalogue from courses.json next to this script."""
    path = Path(__file__).with_name("courses.json")
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        print(f"\u26a0\ufe0f  Could not load courses.json ({e}); catalogue is empty.")
        return {}


COURSE_DATA = load_courses()

def get_project_details(track, project_ids):
    projects = []
    track_projects = COURSE_DATA.get(track, {}).get("projects", [])
    for pid in project_ids:
        project = next((p for p in track_projects if p["id"] == pid), None)
        if project:
            projects.append(project)
    return projects


def load_pregenerated(project_id):
    """Return pre-generated content HTML for a project, or None if not available."""
    import json
    path = Path("project_content") / f"{project_id}.json"
    if path.exists():
        with open(path) as f:
            return json.load(f).get("content_html")
    return None


def build_static_curriculum(projects, pregenerated, age_group, duration_mins,
                            duration_label, is_homeschool):
    """Assemble a complete curriculum HTML from pre-generated project content.

    Fully deterministic — makes NO AI call. Used whenever every selected
    project already has cached content in project_content/.
    """
    n = len(projects)
    titles = ", ".join(p["title"] for p in projects)

    overview = (
        "<h2>Session Overview</h2>\n"
        f"<p>This session covers {n} hands-on project"
        f"{'s' if n != 1 else ''} for <strong>{age_group}</strong>: "
        f"<strong>{titles}</strong>. Total planned time is {duration_label}. "
        "Each project below includes materials, step-by-step instructions, "
        "full code or prompts, common mistakes, discussion questions, and "
        "extension challenges.</p>\n"
    )

    # Schedule — distribute the session time across projects, weighted by each
    # project's typical duration, reserving a little for intro and wrap-up.
    total_weight = sum(p.get("time", 60) for p in projects) or 1
    intro = max(5, round(duration_mins * 0.08))
    wrap = max(5, round(duration_mins * 0.07))
    body_mins = max(1, duration_mins - intro - wrap)
    rows = f"<tr><td>Welcome &amp; setup</td><td>{intro} min</td></tr>\n"
    for p in projects:
        alloc = max(1, round(body_mins * p.get("time", 60) / total_weight))
        rows += f"<tr><td>{p['title']}</td><td>{alloc} min</td></tr>\n"
    rows += f"<tr><td>Wrap-up &amp; reflection</td><td>{wrap} min</td></tr>\n"
    schedule = (
        "<h2>Schedule</h2>\n"
        "<table><thead><tr><th>Activity</th><th>Suggested time</th></tr></thead>"
        f"<tbody>{rows}</tbody></table>\n"
    )

    body = ""
    for p in projects:
        body += f"<h1>{p['title']}</h1>\n"
        body += f"<p><em>{p['diff']} · {p['age']} · ~{p['time']} min</em></p>\n"
        body += (pregenerated[p["id"]] or "") + "\n"

    if is_homeschool:
        tips = (
            "<h2>Parent Guidance Tips</h2>\n<ul>"
            "<li>Let your child lead — step in only when they're stuck for more than a minute or two.</li>"
            "<li>Ask \"what do you think will happen?\" before each step to build prediction skills.</li>"
            "<li>Mistakes are part of it — a project that doesn't work first time is a learning moment, not a failure.</li>"
            "<li>Take a short break between projects to keep energy up.</li>"
            "<li>Celebrate the finished build — take a photo and talk about what they'd change next time.</li>"
            "</ul>\n"
        )
    else:
        tips = (
            "<h2>Classroom Management Tips</h2>\n<ul>"
            "<li>Pair students so faster finishers can buddy up with those who need more time.</li>"
            "<li>Set a visible timer for each activity block to keep the session on track.</li>"
            "<li>Circulate during build steps — most issues are wiring or a missing semicolon.</li>"
            "<li>Use the extension challenges to keep early finishers engaged.</li>"
            "<li>End with a quick show-and-tell so every group demonstrates their build.</li>"
            "</ul>\n"
        )

    return overview + schedule + body + tips


def generate_custom_curriculum_html(topic, custom_request, age_group,
                                    duration_label, is_homeschool):
    """Generate a full lesson plan for a topic that isn't in the predefined
    project catalogue (e.g. "Scratch game design", "Solar-powered gadgets").

    Always makes a live AI call — there is no pre-generated cache for custom
    topics. Returns the inner HTML for the <main> body.
    """
    setting = ("a HOMESCHOOL setting where one parent or guardian guides one "
               "child at home" if is_homeschool
               else "a CLASSROOM / group setting")
    schedule_line = ("Make the schedule flexible — suggest time ranges rather "
                     "than rigid minute-by-minute timings."
                     if is_homeschool
                     else "Include a detailed minute-by-minute schedule with "
                          "breaks and transitions.")
    tips_section = ("Parent Guidance Tips — how to guide without over-helping, "
                    "when to step back, how to handle frustration"
                    if is_homeschool
                    else "Classroom Management Tips — group dynamics, pacing, "
                         "handling mixed abilities")

    system_prompt = f"""You are an expert STEM educator specialising in hands-on learning for ages 6-16.
You work for TinkerWithMe, a hands-on education program in Nairobi.
You are being asked to build a lesson plan for a CUSTOM topic that is not in the standard catalogue, so design it from scratch.
This plan is for {setting}.
Design an engaging, safe, age-appropriate, hands-on session on the requested topic.
Tailor everything to the specific age group and time available.
Do not include purchase links or URLs of any kind — list any materials by name, spec, and quantity only.
For any Nairobi-sourced components, you may name local suppliers (Nerokas, Pixel Electronics) in plain text without links.
Format output as clean HTML (not markdown) for PDF conversion — use <h2>/<h3>, <ul>/<li>, <table>, <strong>, <em>, <p>, and <pre><code> for any code. NO inline styles."""

    request_block = f"\n\n**Educator's request (verbatim):**\n{custom_request}" if custom_request else ""

    user_message = f"""Design a detailed, hands-on lesson plan for this CUSTOM topic. Format your response as clean HTML suitable for PDF printing.

**Session Details:**
- Topic: {topic}
- Age Group: {age_group}
- Duration: {duration_label}{request_block}

**Required Sections (use semantic HTML tags):**
1. <h2>Session Overview</h2> — what learners will build/explore and why it's exciting
2. <h2>Learning Objectives</h2> — 3-5 specific, measurable outcomes
3. <h2>Materials &amp; Setup</h2> — complete checklist with item name, spec and quantity (no links)
4. <h2>Schedule</h2> — {schedule_line}
5. <h2>Activity Breakdown</h2> — step-by-step instructions; include any full code inside <pre><code> with comments, or exact prompts/tool steps where relevant
6. <h2>Common Mistakes &amp; Fixes</h2>
7. <h2>Assessment &amp; Success Criteria</h2>
8. <h2>Extensions &amp; Challenges</h2> — for early finishers and deeper dives
9. <h2>Troubleshooting Guide</h2>
10. <h2>{tips_section}</h2>
11. <h2>Follow-up Activities</h2>

If the topic is unsafe or unsuitable for children, still respond helpfully: adapt it into the closest safe, age-appropriate hands-on activity and note the adaptation in the Session Overview.

Output only the HTML body sections above — no DOCTYPE, no <html>, <head> or <body> tags."""

    return stream_html(system_prompt, user_message, max_tokens=12000)


def generate_freeform_curriculum_html(request_text, is_homeschool):
    """Generate a single-session lesson plan straight from a free-text request.

    The educator just describes what they want in their own words; Claude infers
    the topic, age group and timing from the text and designs the plan, including
    the complete code / build steps needed to actually run it.
    """
    setting = ("a HOMESCHOOL setting (one parent/guardian guiding one child)"
               if is_homeschool else "a CLASSROOM / group setting")
    tips_section = ("Parent Guidance Tips" if is_homeschool
                    else "Classroom Management Tips")

    system_prompt = f"""You are an expert STEM educator for TinkerWithMe, a hands-on education programme in Nairobi (ages 6-16).
An educator has described, in their own words, the session they want. Design a complete, safe, age-appropriate, hands-on lesson plan that matches their description as closely as possible.
This plan is for {setting}.
Infer the topic, age group and duration from their request; if something isn't stated, choose sensible defaults and say what you assumed.
Do not include purchase links or URLs — list materials by name, spec and quantity only (local suppliers such as Nerokas or Pixel Electronics may be named in plain text).
Always include the COMPLETE code or build steps needed to actually run each activity — never summarise them away. For Arduino/electronics put the full sketch in <pre><code> with comments; for AI activities give the exact tools, step-by-step workflow and example prompts/data.
Output clean HTML (no markdown, no inline styles): <h2>/<h3>, <ul>/<li>, <table>, <strong>, <em>, <p>, <pre><code>."""

    user_message = f"""Here is the educator's request, verbatim:

\"\"\"
{request_text}
\"\"\"

Design the lesson plan as HTML with these sections (adapt sensibly to what they asked for):
1. <h2>Session Overview</h2> — including a one-line note of anything you assumed (age, duration, topic)
2. <h2>Learning Objectives</h2>
3. <h2>Materials &amp; Setup</h2> — item, spec, quantity (no links)
4. <h2>Schedule</h2>
5. <h2>Activity Breakdown</h2> — step-by-step, with the FULL code in <pre><code>, or exact tool steps/prompts
6. <h2>Common Mistakes &amp; Fixes</h2>
7. <h2>Assessment &amp; Success Criteria</h2>
8. <h2>Extensions &amp; Challenges</h2>
9. <h2>Troubleshooting Guide</h2>
10. <h2>{tips_section}</h2>
11. <h2>Follow-up Activities</h2>

If the request is unsafe or unsuitable for children, adapt it into the closest safe activity and note the change in the Session Overview.

Output only the HTML body sections — no DOCTYPE, <html>, <head> or <body> tags."""

    return stream_html(system_prompt, user_message, max_tokens=16000)


def run_freeform(request_text, user_name="", user_email="", audience="classroom"):
    """Route a free-text request to the right generator.

    If the text describes multiple age bands with head-counts (a camp), hand off
    to the camp planner so it gets proper group splits, staffing and a timetable
    (camps run a full day; the AI still reads the exact wording). Otherwise build
    a single-session lesson plan from the description, inferring timing from it.
    """
    # Lazy import avoids a circular dependency (generate_camp_plan imports
    # COURSE_DATA from this module at load time).
    import generate_camp_plan as camp

    bands = camp.find_age_bands_in_text(request_text)
    # Treat it as a camp when there are 2+ bands, or one sizeable band (>12).
    is_camp = bool(bands) and (len(bands) >= 2 or sum(b["count"] for b in bands) > 12)

    if is_camp:
        age_bands_raw = ",".join(
            f"{b['label'].replace(' yrs','')}:{b['count']}" for b in bands
        )
        total = sum(b["count"] for b in bands)
        theme_track = camp.resolve_track(request_text)
        theme = {
            "arduino": "Arduino Robotics & Electronics",
            "ai": "AI Skills for Kids",
        }.get(theme_track, "Full-Day Camp")
        print(f"🏕️  Free-text detected a camp — {total} children, "
              f"{len(bands)} band(s); routing to camp planner (theme: {theme}).")
        return camp.generate_camp_plan_pdf(
            theme, age_bands_raw, user_name=user_name,
            user_email=user_email, brief=request_text,
        )

    # Single session.
    print("📝 Free-text request — generating a single-session plan.")
    is_homeschool = audience.lower() == "homeschool"
    try:
        body_html = generate_freeform_curriculum_html(request_text, is_homeschool)
        current_date = datetime.now().strftime("%d %B %Y")
        audience_label = "Homeschool" if is_homeschool else "Classroom"
        prepared_html = (
            (f'Prepared for <strong>{user_name}</strong>' if user_name else 'Lesson plan')
            + f'<span class="session-badge">{audience_label} session</span>'
        )
        header_html = pdf_template.build_header(
            title_line="Custom Lesson Plan",
            subtitle_line="Generated from your description",
            prepared_html=prepared_html,
            current_date=current_date,
        )
        full_html = pdf_template.render_document(
            title="TinkerWithMe Custom Lesson Plan",
            header_html=header_html,
            body_html=body_html,
        )
        output_dir = Path("output")
        output_dir.mkdir(exist_ok=True)
        pdf_file = output_dir / "TinkerWithMe_Custom_Lesson_Plan.pdf"
        pdf_template.write_pdf(full_html, pdf_file)
        print(f"✅ PDF generated: {pdf_file}")
        print(f"\n📧 Ready to email to: {user_email}")
        return str(pdf_file)
    except Exception as e:
        print(f"❌ Error generating plan: {e}", file=sys.stderr)
        return None


def generate_curriculum_pdf(track, project_ids, age_group, duration, user_email,
                            audience="classroom", user_name="",
                            custom_topic="", custom_request=""):
    """
    Main curriculum generation function using Claude AI.
    Outputs professional PDF with TinkerWithMe branding and footer.
    audience: "classroom" (default) or "homeschool"
    user_name: person the plan is prepared for (shown in the header)
    """

    # A custom request is anything outside the predefined catalogue: the caller
    # supplies a free-text topic (and optionally a longer description) instead of
    # a track + project IDs.
    is_custom = bool(custom_topic) or track == "custom"

    # Convert duration to minutes
    duration_mins = 330 if duration == "full" else int(duration)
    duration_label = f"{duration_mins} minutes" if duration != "full" else "full day (5-6 hours)"

    is_homeschool = audience.lower() == "homeschool"

    if is_custom:
        # No predefined projects — the whole plan comes from the topic/request.
        projects = []
        track_label = custom_topic or "Custom Topic"
        projects_summary = ""
    else:
        # Get project metadata
        projects = get_project_details(track, project_ids)

        if not projects:
            valid_ids = ", ".join(p["id"] for p in COURSE_DATA.get(track, {}).get("projects", []))
            print(f"❌ Error: No matching projects for IDs {project_ids} in track '{track}'. Valid IDs: {valid_ids}")
            return None

        # Build project summary for Claude
        projects_summary = "\n".join([
            f"- **{p['title']}** ({p['diff']}) - {p['time']}min: {p['desc']}"
            for p in projects
        ])

        track_label = "Arduino Robotics & Electronics" if track == "arduino" else "AI Skills for Kids"

    # Build prompt variants based on audience
    if is_homeschool:
        system_prompt = f"""You are an expert STEM educator specialising in hands-on learning for ages 6-16.
You create detailed, age-appropriate lesson plans with clear learning outcomes, flexible schedules, materials lists, and troubleshooting tips.

You work for TinkerWithMe, a hands-on education program in Nairobi teaching {track_label}.
This plan is for a HOMESCHOOL setting where one parent or guardian guides one child at home.
Always tailor content to the specific age group, difficulty level, and time constraints.
Do not include purchase links or URLs of any kind — list components by name, spec, and quantity only.
Use warm, encouraging language. Write parent guidance notes in plain English (no jargon).
Make the schedule flexible — suggest time ranges rather than rigid minute-by-minute timings.
Format output as clean HTML (not markdown) for PDF conversion."""

        user_message = f"""Generate a detailed, parent-friendly lesson plan for a home session. Format your response as clean HTML suitable for PDF printing.

**Session Details:**
- Track: {track_label}
- Age Group: {age_group}
- Duration: {duration_label}
- Projects:
{projects_summary}

**Required Sections (use semantic HTML tags):**
1. **Session Overview** - What the child will build/learn and why it's exciting
2. **Learning Objectives** - 3-5 specific, measurable outcomes (written for a parent to understand)
3. **Materials & Setup** - Complete checklist with item name, spec, and quantity (no purchase links or URLs)
4. **Flexible Schedule** - Suggested time ranges per activity (not rigid — let the child set the pace); include breaks
5. **Project Breakdowns** - For each project:
   - Step-by-step instructions the child can read themselves (with parent check-ins noted)
   - **Full working code** — for Arduino projects include the complete `.ino` sketch inside a <pre><code> block with line-by-line comments a child can follow; for AI projects include the exact prompts or tool steps to use
   - Common mistakes & how to fix them
   - Success criteria ("your child has got it when...")
6. **Conversation Starters & Check-ins** - Open-ended questions parents can ask to gauge understanding without quizzing
7. **Extensions & Challenges** - Extra activities if the child finishes early or wants to go deeper
8. **Troubleshooting Guide** - FAQ and common issues, written so a non-expert parent can help
9. **Parent Guidance Tips** - How to guide without over-helping, when to step back, how to handle frustration
10. **Follow-up Activities** - Take-home experiments or next steps the child can try independently

**HTML Formatting Guidelines:**
- Use <h2> for main sections, <h3> for subsections
- Use <ul><li> for lists
- Use <strong> and <em> for emphasis
- Use <table> for structured data (schedules, materials lists)
- Use <p> for paragraphs
- Keep it clean and printable
- NO inline styles - use semantic HTML only
"""
    else:
        system_prompt = f"""You are an expert STEM educator specialising in hands-on learning for ages 6-16.
You create detailed, age-appropriate lesson plans with clear learning outcomes, minute-by-minute schedules, materials lists, and troubleshooting tips.

You work for TinkerWithMe, a hands-on education program in Nairobi teaching {track_label}.
Always tailor content to the specific age group, difficulty level, and time constraints.
Do not include purchase links or URLs of any kind — list components by name, spec, and quantity only.
Make plans engaging, inclusive, and adaptable for mixed-ability groups.
Format output as clean HTML (not markdown) for PDF conversion."""

        user_message = f"""Generate a detailed, professional lesson plan for this session. Format your response as clean HTML suitable for PDF printing.

**Session Details:**
- Track: {track_label}
- Age Group: {age_group}
- Duration: {duration_label}
- Projects:
{projects_summary}

**Required Sections (use semantic HTML tags):**
1. **Session Overview** - What students will accomplish and why it matters
2. **Learning Objectives** - 3-5 specific, measurable outcomes (use Bloom's taxonomy)
3. **Materials & Setup** - Complete checklist with item name, spec, and quantity (no purchase links or URLs)
4. **Minute-by-Minute Schedule** - Detailed breakdown (include breaks, transitions)
5. **Project Breakdowns** - For each project:
   - Step-by-step instructions
   - **Full working code** — for Arduino projects include the complete `.ino` sketch inside a <pre><code> block with inline comments; for AI projects include the exact prompts or tool steps to use
   - Common mistakes & how to fix them
   - Success criteria
6. **Assessment** - How to check understanding (games, challenges, presentations)
7. **Extensions & Challenges** - For early finishers and advanced learners
8. **Troubleshooting Guide** - FAQ and common issues
9. **Classroom Management Tips** - Group dynamics, pacing adjustments
10. **Follow-up Activities** - Take-home challenges or next steps

**HTML Formatting Guidelines:**
- Use <h2> for main sections, <h3> for subsections
- Use <ul><li> for lists
- Use <strong> and <em> for emphasis
- Use <table> for structured data (schedules, materials lists)
- Use <p> for paragraphs
- Keep it clean and printable
- NO inline styles - use semantic HTML only
"""
    
    audience_label = "Homeschool" if is_homeschool else "Classroom"
    print(f"📧 User email: {user_email}")

    # Load pre-generated content for each project (fast path)
    pregenerated = {pid: load_pregenerated(pid) for pid in project_ids}
    has_pregenerated = all(v is not None for v in pregenerated.values())

    try:
        if is_custom:
            # Custom path: topic isn't in the catalogue, generate the whole plan.
            print(f"✨ Custom path — generating plan for topic: {track_label!r}")
            curriculum_html = generate_custom_curriculum_html(
                track_label, custom_request, age_group,
                duration_label, is_homeschool,
            )
        elif has_pregenerated:
            # Static path: assemble pre-generated content with NO AI call at all.
            print(f"🟢 Static path — assembling {len(projects)} pre-generated project(s), no AI tokens used")
            curriculum_html = build_static_curriculum(
                projects, pregenerated, age_group, duration_mins,
                duration_label, is_homeschool,
            )
        else:
            # Slow path: full AI generation (no pre-generated content available)
            missing = [pid for pid, v in pregenerated.items() if v is None]
            print(f"🤖 Slow path — generating from scratch (missing pre-generated content for: {missing})")
            curriculum_html = stream_html(
                system_prompt, user_message,
                max_tokens=min(32000, 4000 + len(projects) * 6000),
            )

        # Generate full HTML with TinkerWithMe branding and footer
        current_date = datetime.now().strftime("%d %B %Y")
        prepared_html = (
            (f'Prepared for <strong>{user_name}</strong>' if user_name else 'Lesson plan')
            + f'<span class="session-badge">{audience_label} session</span>'
        )
        subtitle = (
            f"Custom topic · {duration_label}" if is_custom
            else f"{len(projects)} project(s) · {duration_label}"
        )
        header_html = pdf_template.build_header(
            title_line=f"{track_label} · {age_group}",
            subtitle_line=subtitle,
            prepared_html=prepared_html,
            current_date=current_date,
        )
        full_html = pdf_template.render_document(
            title=f"TinkerWithMe Curriculum - {track_label}",
            header_html=header_html,
            body_html=curriculum_html,
        )
        
        # Write PDF directly from HTML string
        output_dir = Path("output")
        output_dir.mkdir(exist_ok=True)
        if is_custom:
            project_slug = track_label.replace(" ", "_")
        elif len(projects) == 1:
            project_slug = projects[0]["title"].replace(" ", "_")
        else:
            project_slug = projects[0]["title"].replace(" ", "_") + f"_and_{len(projects)-1}_more"
        safe_slug = re.sub(r"[^\w\-]", "", project_slug) or "curriculum"
        pdf_file = output_dir / f"TinkerWithMe_{safe_slug}.pdf"
        pdf_template.write_pdf(full_html, pdf_file)
        print(f"✅ PDF generated: {pdf_file}")
        print(f"\n📧 Ready to email to: {user_email}")
        return str(pdf_file)
    
    except Exception as e:
        print(f"❌ Error generating curriculum: {e}", file=sys.stderr)
        return None

if __name__ == "__main__":
    track = os.getenv("TRACK", "arduino").strip()
    projects = [p.strip() for p in os.getenv("PROJECTS", "ar1").split(",") if p.strip()]
    age_group = os.getenv("AGE_GROUP", "6-9 yrs")
    duration = os.getenv("DURATION", "90")
    user_name = os.getenv("USER_NAME", "").strip()
    user_email = os.getenv("USER_EMAIL", "user@example.com")
    audience = os.getenv("AUDIENCE", "classroom").strip()
    custom_topic = os.getenv("CUSTOM_TOPIC", "").strip()
    custom_request = os.getenv("CUSTOM_REQUEST", "").strip()
    freeform_request = os.getenv("FREEFORM_REQUEST", "").strip()

    # Free-text takes precedence: if the educator described the session in their
    # own words, route through the freeform handler (which may itself produce a
    # multi-band camp plan when the text describes one).
    if freeform_request:
        result = run_freeform(
            freeform_request, user_name=user_name, user_email=user_email,
            audience=audience,
        )
    else:
        result = generate_curriculum_pdf(
            track, projects, age_group, duration, user_email, audience, user_name,
            custom_topic=custom_topic, custom_request=custom_request,
        )
    if result is None:
        sys.exit(1)
