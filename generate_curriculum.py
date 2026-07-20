#!/usr/bin/env python3
"""
TinkerWithMe Curriculum Generator Agent

Generates detailed lesson plans using Claude AI based on selected projects.
Outputs professional PDF with TinkerWithMe branding and footer.
Triggered via button click from curriculumgenerator.html (password-gated).
"""

import os
import re
import sys
from pathlib import Path
from datetime import datetime
from anthropic import Anthropic

from weasyprint import HTML

# Course data matching index.html
COURSE_DATA = {
    "arduino": {
        "ages": ["6-9 yrs", "10-12 yrs", "13-15 yrs", "All ages"],
        "projects": [
            {"id": "ar1", "title": "Traffic light simulation", "diff": "Beginner", "age": "6-9 yrs", "time": 60, "desc": "3 LEDs mimic real traffic light sequences"},
            {"id": "ar2", "title": "Button controlled LED", "diff": "Beginner", "age": "6-9 yrs", "time": 45, "desc": "Push button toggles LED on/off"},
            {"id": "ar3", "title": "Fade an LED", "diff": "Beginner", "age": "6-9 yrs", "time": 45, "desc": "PWM & analogWrite() to dim LED smoothly"},
            {"id": "ar4", "title": "RGB LED colour mixer", "diff": "Beginner", "age": "6-9 yrs", "time": 60, "desc": "3 potentiometers mix red, green & blue"},
            {"id": "ar5", "title": "Capacitive touch sensor", "diff": "Beginner", "age": "10-12 yrs", "time": 60, "desc": "Touch sensor module toggles an LED"},
            {"id": "ar6", "title": "Buzzer melody", "diff": "Beginner", "age": "6-9 yrs", "time": 60, "desc": "Piezo buzzer plays tunes like Ode to Joy"},
            {"id": "ar7", "title": "Morse code blinker", "diff": "Intermediate", "age": "10-12 yrs", "time": 75, "desc": "LED blinks out Morse code messages"},
            {"id": "ar8", "title": "Temperature logger", "diff": "Intermediate", "age": "10-12 yrs", "time": 90, "desc": "DHT11 reads & displays temperature"},
            {"id": "ar9", "title": "Ultrasonic distance sensor", "diff": "Intermediate", "age": "10-12 yrs", "time": 75, "desc": "HC-SR04 measures distance, LED warns on proximity"},
            {"id": "ar10", "title": "Servo motor control", "diff": "Intermediate", "age": "10-12 yrs", "time": 75, "desc": "Potentiometer steers servo to any position"},
            {"id": "ar11", "title": "Light-activated LED", "diff": "Beginner", "age": "6-9 yrs", "time": 60, "desc": "Photoresistor auto-lights LED when dark"},
            {"id": "ar12", "title": "Digital dice", "diff": "Intermediate", "age": "10-12 yrs", "time": 90, "desc": "Multiple LEDs randomly show a dice roll"},
            {"id": "ar13", "title": "Basic alarm system", "diff": "Intermediate", "age": "10-12 yrs", "time": 90, "desc": "Motion sensor triggers buzzer & LED alarm"},
            {"id": "ar14", "title": "Fan control", "diff": "Advanced", "age": "13-15 yrs", "time": 90, "desc": "Temperature sensor controls relay-powered fan"},
            {"id": "ar15", "title": "Simon says game", "diff": "Advanced", "age": "13-15 yrs", "time": 120, "desc": "Classic memory game with LEDs, buttons & buzzer"},
        ]
    },
    "ai": {
        "ages": ["7-10 yrs", "10-13 yrs", "13-16 yrs", "All ages"],
        "projects": [
            {"id": "a1", "title": "Prompting power", "diff": "Beginner", "age": "7-10 yrs", "time": 60, "desc": "ChatGPT basics — ask better questions"},
            {"id": "a2", "title": "AI art studio", "diff": "Beginner", "age": "7-10 yrs", "time": 60, "desc": "DALL-E image generation workshop"},
            {"id": "a3", "title": "AI music & sound", "diff": "Beginner", "age": "7-10 yrs", "time": 60, "desc": "Generate soundtracks and beats"},
            {"id": "a4", "title": "AI storytelling", "diff": "Beginner", "age": "10-13 yrs", "time": 75, "desc": "Write illustrated stories with AI"},
            {"id": "a5", "title": "Teachable Machine", "diff": "Intermediate", "age": "10-13 yrs", "time": 90, "desc": "Train your own image classifier"},
            {"id": "a6", "title": "Mashup madness", "diff": "Intermediate", "age": "10-13 yrs", "time": 90, "desc": "Combine multiple AI tools creatively"},
            {"id": "a7", "title": "Bias detective", "diff": "Intermediate", "age": "13-16 yrs", "time": 75, "desc": "Find and discuss bias in AI tools"},
            {"id": "a8", "title": "AI careers deep dive", "diff": "Intermediate", "age": "13-16 yrs", "time": 60, "desc": "ML engineers, ethicists, data scientists"},
            {"id": "a9", "title": "Build your portfolio", "diff": "Advanced", "age": "13-16 yrs", "time": 120, "desc": "GitHub, pitch deck, and showcase prep"},
        ]
    }
}

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


def generate_curriculum_pdf(track, project_ids, age_group, duration, user_email,
                            audience="classroom", user_name=""):
    """
    Main curriculum generation function using Claude AI.
    Outputs professional PDF with TinkerWithMe branding and footer.
    audience: "classroom" (default) or "homeschool"
    user_name: person the plan is prepared for (shown in the header)
    """

    # Get project metadata
    projects = get_project_details(track, project_ids)
    
    if not projects:
        valid_ids = ", ".join(p["id"] for p in COURSE_DATA.get(track, {}).get("projects", []))
        print(f"❌ Error: No matching projects for IDs {project_ids} in track '{track}'. Valid IDs: {valid_ids}")
        return None
    
    # Convert duration to minutes
    duration_mins = 330 if duration == "full" else int(duration)
    duration_label = f"{duration_mins} minutes" if duration != "full" else "full day (5-6 hours)"
    
    # Build project summary for Claude
    projects_summary = "\n".join([
        f"- **{p['title']}** ({p['diff']}) - {p['time']}min: {p['desc']}"
        for p in projects
    ])
    
    track_label = "Arduino Robotics & Electronics" if track == "arduino" else "AI Skills for Kids"
    is_homeschool = audience.lower() == "homeschool"

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
        if has_pregenerated:
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
            client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
            message = client.messages.create(
                model="claude-sonnet-5",
                max_tokens=4000 + len(projects) * 6000,
                system=system_prompt,
                messages=[{"role": "user", "content": user_message}],
            )
            if message.stop_reason == "max_tokens":
                print("⚠️  Response truncated at max_tokens.")
            curriculum_html = next(block.text for block in message.content if block.type == "text")
            curriculum_html = re.sub(r"^```(?:html)?\s*\n?", "", curriculum_html.strip())
            curriculum_html = re.sub(r"\n?```\s*$", "", curriculum_html)

        # Generate full HTML with TinkerWithMe branding and footer
        current_date = datetime.now().strftime("%d %B %Y")
        full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TinkerWithMe Curriculum - {track_label}</title>
    <style>
        @page {{
            size: A4;
            margin: 18mm 16mm;
            @bottom-center {{
                content: "TinkerWithMe · Nairobi, Kenya · tinkerwithanne@gmail.com";
                font-size: 9pt;
                color: #B08060;
            }}
            @bottom-right {{
                content: "Page " counter(page) " of " counter(pages);
                font-size: 9pt;
                color: #B08060;
            }}
        }}
        
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: 'Inter', 'Segoe UI', sans-serif;
            line-height: 1.6;
            color: #2A1A0E;
            background: white;
        }}
        
        /* Print styles */
        @media print {{
            body {{ background: white; }}
            a {{ color: #F07B1D; text-decoration: none; }}
        }}
        
        header {{
            position: relative;
            border-bottom: 2.5px solid #F07B1D;
            padding-bottom: 1rem;
            margin-bottom: 2rem;
        }}
        
        .header-brand {{
            font-size: 18px;
            font-weight: 700;
            color: #2A1A0E;
            letter-spacing: -0.01em;
            margin-bottom: 0.5rem;
        }}
        
        .header-title {{
            font-size: 13px;
            color: #6B4C30;
            margin-bottom: 0.25rem;
        }}
        
        .header-subtitle {{
            font-size: 11px;
            color: #B08060;
        }}

        .header-prepared {{
            margin-top: 0.6rem;
            font-size: 12px;
            color: #2A1A0E;
        }}

        .session-badge {{
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
        }}
        
        .header-meta {{
            font-size: 11px;
            color: #6B4C30;
            text-align: right;
            line-height: 1.7;
            position: absolute;
            right: 0;
            top: 0;
        }}
        
        h1 {{
            font-size: 28px;
            font-weight: 700;
            margin: 1.5rem 0 0.5rem;
            color: #2A1A0E;
            border-bottom: 1px solid #ddd;
            padding-bottom: 0.5rem;
        }}
        
        h2 {{
            font-size: 18px;
            font-weight: 700;
            margin: 1.5rem 0 0.75rem;
            color: #2A1A0E;
            border-bottom: 1px solid #eee;
            padding-bottom: 0.35rem;
        }}
        
        h3 {{
            font-size: 14px;
            font-weight: 700;
            margin: 1rem 0 0.5rem;
            color: #2A1A0E;
        }}
        
        p {{
            margin-bottom: 0.75rem;
            line-height: 1.75;
        }}
        
        ul, ol {{
            margin: 0.75rem 0 0.75rem 1.4rem;
        }}
        
        li {{
            margin-bottom: 0.4rem;
        }}
        
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 1rem 0;
            font-size: 12px;
        }}
        
        th {{
            background: #FAFAF7;
            padding: 0.5rem;
            text-align: left;
            font-weight: 700;
            border-bottom: 2px solid #B08060;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: #B08060;
        }}
        
        td {{
            padding: 0.5rem;
            border-bottom: 1px solid #ddd;
            vertical-align: top;
        }}
        
        tr:hover td {{
            background: rgba(42, 26, 14, 0.02);
        }}
        
        strong {{
            font-weight: 600;
            color: #2A1A0E;
        }}
        
        em {{
            font-style: italic;
            color: #6B4C30;
        }}
        
        .print-tag {{
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
        }}
        
        .content {{
            page-break-inside: avoid;
        }}

        pre {{
            background: #F5F0EB;
            border-left: 3px solid #F07B1D;
            padding: 0.75rem 1rem;
            margin: 0.75rem 0;
            font-size: 10px;
            line-height: 1.55;
            overflow-x: auto;
            white-space: pre-wrap;
            word-break: break-word;
        }}

        code {{
            font-family: 'Courier New', Courier, monospace;
            font-size: 10px;
            background: #F5F0EB;
            padding: 0 3px;
            border-radius: 2px;
        }}

        pre code {{
            background: none;
            padding: 0;
        }}
    </style>
</head>
<body>
    <header>
        <div class="header-meta">
            tinkerwithanne@gmail.com<br>
            Nairobi, Kenya<br>
            {current_date}
        </div>
        <div class="header-brand">TinkerWithMe</div>
        <div class="header-title">{track_label} · {age_group}</div>
        <div class="header-subtitle">{len(projects)} project(s) · {duration_label}</div>
        <div class="header-prepared">
            {f'Prepared for <strong>{user_name}</strong>' if user_name else 'Lesson plan'}
            <span class="session-badge">{audience_label} session</span>
        </div>
    </header>
    
    <main>
        {curriculum_html}
    </main>
</body>
</html>
"""
        
        # Write PDF directly from HTML string
        output_dir = Path("output")
        output_dir.mkdir(exist_ok=True)
        if len(projects) == 1:
            project_slug = projects[0]["title"].replace(" ", "_")
        else:
            project_slug = projects[0]["title"].replace(" ", "_") + f"_and_{len(projects)-1}_more"
        safe_slug = re.sub(r"[^\w\-]", "", project_slug)
        pdf_file = output_dir / f"TinkerWithMe_{safe_slug}.pdf"
        HTML(string=full_html).write_pdf(pdf_file)
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

    result = generate_curriculum_pdf(
        track, projects, age_group, duration, user_email, audience, user_name
    )
    if result is None:
        sys.exit(1)
