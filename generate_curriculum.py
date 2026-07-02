#!/usr/bin/env python3
"""
TinkerWithMe Curriculum Generator Agent

Generates detailed lesson plans using Claude AI based on selected projects.
Outputs professional PDF with TinkerWithMe branding and footer.
Triggered via button click from curriculum-generator.html (payment-gated).
"""

import os
import json
import re
import sys
from pathlib import Path
from datetime import datetime
from anthropic import Anthropic

try:
    from weasyprint import HTML, CSS
    HAS_WEASYPRINT = True
except (ImportError, OSError) as e:
    HAS_WEASYPRINT = False
    print(f"⚠️  WeasyPrint not available ({e}). Falling back to HTML output.")

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
    """Fetch project metadata from course data."""
    projects = []
    track_projects = COURSE_DATA.get(track, {}).get("projects", [])
    
    for pid in project_ids:
        project = next((p for p in track_projects if p["id"] == pid), None)
        if project:
            projects.append(project)
    
    return projects

def generate_curriculum_pdf(track, project_ids, age_group, duration, user_email, audience="classroom"):
    """
    Main curriculum generation function using Claude AI.
    Outputs professional PDF with TinkerWithMe branding and footer.
    audience: "classroom" (default) or "homeschool"
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

    # Initialize Claude client
    client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

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
    print(f"🤖 Generating {audience_label} curriculum for {track} ({age_group}, {duration_label})...")
    print(f"📧 User email: {user_email}")
    print("\n" + "="*60 + "\n")
    
    # Call Claude API
    try:
        message = client.messages.create(
            model="claude-sonnet-5",
            max_tokens=8000,
            system=system_prompt,
            messages=[
                {"role": "user", "content": user_message}
            ]
        )

        if message.stop_reason == "max_tokens":
            print("⚠️  Response was truncated at max_tokens — consider raising the limit further.")

        curriculum_html = next(block.text for block in message.content if block.type == "text")
        # Strip a leading/trailing markdown code fence (```html ... ```) if Claude added one
        curriculum_html = re.sub(r"^```(?:html)?\s*\n?", "", curriculum_html.strip())
        curriculum_html = re.sub(r"\n?```\s*$", "", curriculum_html)

        # Create output directory
        output_dir = Path("output")
        output_dir.mkdir(exist_ok=True)
        
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
        <div class="header-subtitle">{len(projects)} project(s) · {duration_label} · {audience_label}</div>
    </header>
    
    <main>
        {curriculum_html}
    </main>
</body>
</html>
"""
        
        # Save HTML first
        audience_slug = "homeschool" if is_homeschool else "classroom"
        html_file = output_dir / f"curriculum_{track}_{age_group.replace(' ', '_').replace('-', '')}_{audience_slug}.html"
        with open(html_file, "w") as f:
            f.write(full_html)
        
        # Convert to PDF if WeasyPrint is available
        pdf_file = None
        if HAS_WEASYPRINT:
            try:
                pdf_file = output_dir / f"curriculum_{track}_{age_group.replace(' ', '_').replace('-', '')}_{audience_slug}.pdf"
                HTML(string=full_html).write_pdf(pdf_file)
                print(f"✅ PDF generated: {pdf_file}")
            except Exception as e:
                print(f"⚠️  PDF generation failed: {e}")
                print("   HTML version saved instead.")
        else:
            print(f"⚠️  WeasyPrint not installed. Saved as HTML: {html_file}")
        
        # Save metadata
        metadata_file = output_dir / "metadata.json"
        metadata = {
            "track": track,
            "age_group": age_group,
            "duration": duration,
            "audience": audience,
            "projects": project_ids,
            "user_email": user_email,
            "html_file": str(html_file),
            "pdf_file": str(pdf_file) if pdf_file else None,
            "generated_at": datetime.now().isoformat()
        }
        
        with open(metadata_file, "w") as f:
            json.dump(metadata, f, indent=2)
        
        output_file = pdf_file if pdf_file else html_file
        print(f"\n📧 Ready to email to: {user_email}")
        
        return str(output_file)
    
    except Exception as e:
        print(f"❌ Error generating curriculum: {e}", file=sys.stderr)
        return None

if __name__ == "__main__":
    track = os.getenv("TRACK", "arduino").strip()
    projects = [p.strip() for p in os.getenv("PROJECTS", "ar1").split(",") if p.strip()]
    age_group = os.getenv("AGE_GROUP", "6-9 yrs")
    duration = os.getenv("DURATION", "90")
    user_email = os.getenv("USER_EMAIL", "user@example.com")
    audience = os.getenv("AUDIENCE", "classroom").strip()

    result = generate_curriculum_pdf(track, projects, age_group, duration, user_email, audience)
    if result is None:
        sys.exit(1)
