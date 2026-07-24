#!/usr/bin/env python3
"""
TinkerWithMe Full-Day Camp Planner

Plans a whole-camp day for a mixed-age intake broken into age bands with a
head-count per band — e.g. a 51-child camp split 7-9 (20), 10-12 (19),
13-15 (12). It works out how many parallel groups each band needs, the
staffing and adult-to-child ratios, a master day timetable that keeps every
group moving, and a scaled materials plan — then asks Claude to fill in the
age-appropriate programme for each band so every child gets a full, rich day.

Deterministic scaffolding (group splits, staffing, timetable, scaling) is
computed in Python so the numbers are always right; the per-band programme,
facilitator briefs, materials and safety notes come from Claude.

Triggered via .github/workflows/camp-planner.yml (repository_dispatch or
workflow_dispatch). Outputs a branded PDF, identical chrome to the curriculum
generator, via pdf_template.

Run locally:
    ANTHROPIC_API_KEY=sk-... \\
    CAMP_THEME="Arduino Robotics & Electronics" \\
    AGE_BANDS="7-9:20,10-12:19,13-15:12" \\
    python generate_camp_plan.py
"""

import math
import os
import re
import sys
from datetime import datetime
from pathlib import Path

import pdf_template

# Reuse the curriculum catalogue so, for the standard tracks, we can tell Claude
# exactly which pre-built TinkerWithMe projects fit each band.
try:
    from generate_curriculum import COURSE_DATA
except Exception:  # pragma: no cover - only if catalogue import fails
    COURSE_DATA = {}


# ─── Deterministic planning (pure, unit-testable — no AI, no PDF) ────────────

def parse_age_bands(raw):
    """Parse "7-9:20,10-12:19,13-15:12" into a list of band dicts.

    Also accepts newlines and " children"/"kids" suffixes so it copes with a
    request pasted straight from an email. Raises ValueError on bad input.
    """
    bands = []
    # Normalise separators: commas, semicolons and newlines all split entries.
    for chunk in re.split(r"[\n,;]+", raw.strip()):
        chunk = chunk.strip()
        if not chunk:
            continue
        m = re.match(r"^\s*([0-9]{1,2}\s*[-–]\s*[0-9]{1,2})\s*(?:yrs|years)?\s*[:=]\s*(\d+)", chunk)
        if not m:
            raise ValueError(
                f"Couldn't read age band {chunk!r}. Use e.g. '7-9:20,10-12:19'."
            )
        label = re.sub(r"\s*[-–]\s*", "-", m.group(1)) + " yrs"
        count = int(m.group(2))
        if count <= 0:
            raise ValueError(f"Band {label} has a non-positive head-count.")
        bands.append({"label": label, "count": count})
    if not bands:
        raise ValueError("No age bands provided.")
    return bands


def split_into_groups(bands, max_group_size=10):
    """Split each band into as-even-as-possible groups of at most max_group_size.

    A band of 20 with max 10 -> two groups of 10; 19 -> 10 + 9; 12 -> 6 + 6.
    Returns a flat list of group dicts, each labelled within its band.
    """
    if max_group_size < 1:
        raise ValueError("max_group_size must be at least 1.")
    groups = []
    for band in bands:
        count = band["count"]
        n_groups = max(1, math.ceil(count / max_group_size))
        base, extra = divmod(count, n_groups)
        for i in range(n_groups):
            size = base + (1 if i < extra else 0)
            groups.append({
                "band": band["label"],
                "name": f"{band['label']} · Group {chr(ord('A') + i)}",
                "size": size,
            })
    return groups


def plan_staffing(groups, target_ratio=10):
    """Work out the adult team from the group list.

    One lead facilitator per group, plus a roving camp coordinator, plus one
    floating helper per three groups, plus a dedicated first-aider. Also
    reports the overall adult-to-child ratio.
    """
    total_children = sum(g["size"] for g in groups)
    n_groups = len(groups)
    lead_facilitators = n_groups
    floating_helpers = max(1, math.ceil(n_groups / 3))
    coordinators = 1
    first_aiders = 1
    total_adults = lead_facilitators + floating_helpers + coordinators + first_aiders
    ratio = round(total_children / total_adults, 1) if total_adults else 0
    return {
        "total_children": total_children,
        "n_groups": n_groups,
        "lead_facilitators": lead_facilitators,
        "floating_helpers": floating_helpers,
        "coordinators": coordinators,
        "first_aiders": first_aiders,
        "total_adults": total_adults,
        "ratio": ratio,
        "target_ratio": target_ratio,
    }


def build_master_timetable(is_full_day, duration_mins=330):
    """Return a list of (time, activity) rows for the whole-camp day.

    A full day is a fixed, field-tested 08:30–15:30 shape with three project
    blocks, breaks and a showcase. A shorter session collapses to a single
    focused block so the planner still works for half-day bookings.
    """
    if is_full_day:
        return [
            ("08:30 – 09:00", "Arrival, registration &amp; name badges"),
            ("09:00 – 09:20", "Opening assembly — welcome, safety brief, split into groups (all bands together)"),
            ("09:20 – 10:45", "<strong>Project Block 1</strong> — each group in its own space"),
            ("10:45 – 11:05", "Morning break &amp; snack (staggered so the space doesn't crowd)"),
            ("11:05 – 12:30", "<strong>Project Block 2</strong> — build continues / next activity"),
            ("12:30 – 13:15", "Lunch &amp; free play (supervised, outdoors if possible)"),
            ("13:15 – 14:30", "<strong>Project Block 3</strong> — finish builds, test &amp; debug"),
            ("14:30 – 14:50", "Showcase prep — groups tidy kits and rehearse a 60-second demo"),
            ("14:50 – 15:20", "Showcase &amp; demos — every group presents to the whole camp"),
            ("15:20 – 15:30", "Closing circle, certificates &amp; departure"),
        ]
    # Shorter booking: single block bookended by a welcome and a showcase.
    # Labels are relative (offset from the start) since there's no fixed clock.
    body = max(30, duration_mins - 40)
    return [
        ("First 15 min", "Welcome, safety brief &amp; split into groups"),
        (f"Next {body} min", "<strong>Project Block</strong> — age-band groups work in parallel"),
        ("Last 25 min", "Showcase, tidy-up &amp; closing circle"),
    ]


AI_KEYWORDS = (
    "teachable machine", "machine learning", "artificial intelligence",
    "chatgpt", "dall-e", "dall e", "chatbot", "neural network",
    "generative ai", "ai skills", "ai literacy", "prompt engineering",
)
ARDUINO_KEYWORDS = (
    "arduino", "robot", "electronic", "circuit", "microcontroller",
    "micro:bit", "microbit", "sensor", "soldering",
)


def resolve_track(theme):
    """Map a free-text theme to a catalogue track, or 'custom' if it isn't one."""
    t = theme.lower()
    if any(k in t for k in ARDUINO_KEYWORDS):
        return "arduino"
    # \bai\b so we match "AI Skills" but not words that merely contain "ai".
    if re.search(r"\ba\.?i\.?\b", t) or any(k in t for k in AI_KEYWORDS):
        return "ai"
    # Last resort: if the theme names a specific catalogue project, use its track.
    for track, data in COURSE_DATA.items():
        for p in data.get("projects", []):
            if p["title"].lower() in t:
                return track
    return "custom"


def find_age_bands_in_text(text):
    """Pull age bands + head-counts out of a free-text request.

    Recognises forms like "7-9 years: 20 children", "10 to 12 (19)",
    "ages 13-15 — 12 kids". Returns a list of band dicts (same shape as
    parse_age_bands) or None if nothing band-like is found.
    """
    bands = []
    pattern = re.compile(
        r"(\d{1,2})\s*(?:-|–|to)\s*(\d{1,2})\s*(?:year|yr)s?\b"   # 7-9 years / 7 to 9 yrs
        r"[^\d]{0,20}?"                                            # ": ", " (", " — ", "with"
        r"(\d{1,3})\b",                                           # 20
        re.IGNORECASE,
    )
    for lo, hi, count in pattern.findall(text):
        c = int(count)
        if c <= 0:
            continue
        bands.append({"label": f"{int(lo)}-{int(hi)} yrs", "count": c})
    return bands or None


# ─── Zero-token catalogue assembly ──────────────────────────────────────────
# For Arduino/AI camps we reuse the pre-generated project content (project_content
# /*.json) — full code, materials, steps — instead of paying the model to
# re-write it. Only genuinely custom themes fall through to a live AI call.

_SAFETY_HTML = (
    "<h2>Safety, Logistics &amp; Contingencies</h2>\n"
    "<ul>"
    "<li><strong>Space:</strong> one table per group with room to move; keep walkways clear "
    "and power leads taped down.</li>"
    "<li><strong>Movement:</strong> groups start and stop together on the master timetable — "
    "stagger the break and lunch queues so the space never crowds.</li>"
    "<li><strong>First aid &amp; allergies:</strong> collect allergy info at registration; the "
    "first-aider holds the kit and the contact list all day.</li>"
    "<li><strong>Wet weather:</strong> move outdoor free-play to the hall; keep one indoor "
    "back-up game ready.</li>"
    "<li><strong>Early finishers:</strong> use each project's extension challenges (listed in "
    "the project pages below).</li>"
    "<li><strong>Equipment failure:</strong> keep one spare kit per band; a failed build "
    "becomes a debugging lesson, not a lost hour.</li>"
    "</ul>\n"
)

_STAFF_CHECKLIST_HTML = (
    "<h2>Staff Briefing Checklist</h2>\n"
    "<ul>"
    "<li>Every facilitator knows their group, their band, and their room.</li>"
    "<li>Kits counted and laid out per group before doors open.</li>"
    "<li>Registration desk has the sign-in sheet, badges, and allergy list.</li>"
    "<li>Timekeeper owns the master timetable and calls transitions out loud.</li>"
    "<li>Floating helpers know which groups they cover during breaks.</li>"
    "<li>Showcase space and closing certificates ready before the last block.</li>"
    "</ul>\n"
)


def _age_range(label):
    """Parse '7-9 yrs' (or '6-9 yrs') into an (lo, hi) integer tuple."""
    m = re.search(r"(\d+)\s*[-–]\s*(\d+)", label)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 99)


def _range_overlap(a, b):
    return max(0, min(a[1], b[1]) - max(a[0], b[0]) + 1)


def assign_catalogue_projects(band_label, track, n, brief="", selected_ids=None):
    """Pick up to n age-appropriate catalogue projects for a band.

    When ``selected_ids`` is given the pool is restricted to exactly those
    catalogue projects (the organiser hand-picked the camp's projects); each
    band then gets the best-fitting subset of that pool. Otherwise the whole
    track catalogue is the pool.

    Ranked by age-band overlap, then boosted when the project matches keywords in
    the organiser's brief (so "focus on Teachable Machine" surfaces that project).
    """
    projects = COURSE_DATA.get(track, {}).get("projects", [])
    if not projects:
        return []
    if selected_ids:
        chosen = [p for p in projects if p["id"] in selected_ids]
        if chosen:
            projects = chosen
    band_rng = _age_range(band_label)
    keywords = [w for w in re.findall(r"[a-z]{4,}", brief.lower())]

    def score(p):
        s = _range_overlap(band_rng, _age_range(p["age"])) * 10
        text = (p["title"] + " " + p["desc"]).lower()
        if keywords and any(k in text for k in keywords):
            s += 1000
        return s

    ranked = sorted(projects, key=score, reverse=True)
    return ranked[:n]


def plan_band_projects(track, bands, is_full_day, brief="", selected_ids=None):
    """Decide each band's projects — shared by the topic index and the programme.

    Returns a list of (band, picks). ``selected_ids`` restricts the pool to
    projects the organiser explicitly chose.
    """
    n_projects = 3 if is_full_day else 2
    return [
        (b, assign_catalogue_projects(b["label"], track, n_projects, brief,
                                      selected_ids=selected_ids))
        for b in bands
    ]


def build_topic_index(plan):
    """A numbered contents table (band → topics) that matches the project cards.

    Each topic's number is the same as its numbered header in the programme, so a
    reader can find any topic at a glance.
    """
    rows = ""
    n = 0
    for b, picks in plan:
        items = []
        for p in picks:
            n += 1
            items.append(f"{n}. {p['title']} <em>({p['diff']} · ~{p['time']} min)</em>")
        rows += (f"<tr><td><strong>{b['label']}</strong><br>"
                 f"<span style='color:#B08060;font-size:11px'>{b['count']} children</span></td>"
                 f"<td>{'<br>'.join(items)}</td></tr>")
    return (
        "<h2>Topics in This Plan</h2>\n"
        "<p>Every numbered topic matches a numbered project card in the programme "
        "below, so you can jump straight to it.</p>\n"
        "<table><thead><tr><th>Age band</th><th>Topics (in order)</th></tr></thead>"
        f"<tbody>{rows}</tbody></table>\n"
    )


def build_camp_programme_from_cache(track, plan, groups, brief=""):
    """Assemble the per-band programme from cached project content — no AI call.

    Takes the shared ``plan`` (list of (band, picks)). Returns the programme HTML,
    or None if any needed project isn't cached (so the caller can fall back to AI).
    """
    from generate_curriculum import load_pregenerated

    # Confirm every project is cached before we commit to the zero-token path.
    loaded = []
    for b, picks in plan:
        if not picks:
            return None
        contents = {p["id"]: load_pregenerated(p["id"]) for p in picks}
        if any(v is None for v in contents.values()):
            return None
        loaded.append((b, picks, contents))

    body = ("<h2>Programme by Age Band</h2>\n"
            "<p>Each band works through age-appropriate TinkerWithMe projects. Every "
            "project below is a self-contained topic card with its materials, "
            "step-by-step instructions and full code/build steps so a facilitator can "
            "run it directly.</p>\n")
    n = 0
    for b, picks, contents in loaded:
        n_groups = sum(1 for g in groups if g["band"] == b["label"])
        titles = ", ".join(p["title"] for p in picks)
        body += (f'<h2 class="band-head">{b["label"]} — {b["count"]} children in '
                 f'{n_groups} group(s)</h2>\n'
                 f"<p><strong>Topics for this band:</strong> {titles}. Each group's lead "
                 "facilitator preps the kit, keeps the group to the master timetable, and "
                 "watches for the common mistakes noted in each topic.</p>\n")
        for p in picks:
            n += 1
            body += (
                '<section class="project">\n'
                f'<div class="project-head"><span class="num">{n}</span>'
                f'<span class="title">{p["title"]}</span>'
                f'<span class="meta">{p["diff"]} · ~{p["time"]} min · {b["label"]}</span></div>\n'
                f'<div class="project-body">{contents[p["id"]]}</div>\n'
                '</section>\n'
            )

    body += (
        "<h2>Materials — Scaling</h2>\n"
        "<p>Each project's materials list above is <strong>per group</strong>. Multiply it "
        "by the number of groups in that band to get the totals to prepare. Shared kit "
        "(laptops, power strips, extension leads) can rotate between groups rather than be "
        "bought per group.</p>\n"
    )
    body += _SAFETY_HTML
    body += _STAFF_CHECKLIST_HTML
    if brief:
        body += ("<h2>Organiser Notes</h2>\n<p>Projects were chosen to fit your notes where "
                 f"possible: <em>{brief}</em></p>\n")
    return body


def catalogue_hint(track, selected_ids=None):
    """Build a plain-text list of catalogue projects to steer Claude's picks.

    When ``selected_ids`` is given, only those projects are offered so the AI
    honours the organiser's hand-picked selection.
    """
    projects = COURSE_DATA.get(track, {}).get("projects", [])
    if selected_ids:
        chosen = [p for p in projects if p["id"] in selected_ids]
        if chosen:
            projects = chosen
    if not projects:
        return ""
    lines = [
        f"- {p['title']} ({p['diff']}, ~{p['time']} min, suits {p['age']}): {p['desc']}"
        for p in projects
    ]
    return "\n".join(lines)


# ─── HTML assembly ──────────────────────────────────────────────────────────

def _groups_table(groups):
    rows = "".join(
        f"<tr><td>{g['band']}</td><td>{g['name']}</td><td>{g['size']} children</td></tr>"
        for g in groups
    )
    return (
        "<h2>Groups at a Glance</h2>\n"
        "<p>Each group stays together all day with its own lead facilitator, so "
        "no child is ever in a group larger than the target size.</p>\n"
        "<table><thead><tr><th>Age band</th><th>Group</th><th>Size</th></tr></thead>"
        f"<tbody>{rows}</tbody></table>\n"
    )


def _staffing_table(staff):
    rows = (
        f"<tr><td>Lead facilitators (one per group)</td><td>{staff['lead_facilitators']}</td></tr>"
        f"<tr><td>Floating helpers</td><td>{staff['floating_helpers']}</td></tr>"
        f"<tr><td>Camp coordinator</td><td>{staff['coordinators']}</td></tr>"
        f"<tr><td>First-aider</td><td>{staff['first_aiders']}</td></tr>"
        f"<tr><td><strong>Total adults</strong></td><td><strong>{staff['total_adults']}</strong></td></tr>"
    )
    return (
        "<h2>Staffing &amp; Ratios</h2>\n"
        f"<p>With <strong>{staff['total_children']} children</strong> in "
        f"<strong>{staff['n_groups']} groups</strong>, this plan needs "
        f"<strong>{staff['total_adults']} adults</strong> on the day — an "
        f"overall ratio of about <strong>1 adult to {staff['ratio']} children</strong> "
        f"(target 1:{staff['target_ratio']} or better).</p>\n"
        "<table><thead><tr><th>Role</th><th>People</th></tr></thead>"
        f"<tbody>{rows}</tbody></table>\n"
    )


def _timetable_table(rows):
    body = "".join(f"<tr><td>{t}</td><td>{a}</td></tr>" for t, a in rows)
    return (
        "<h2>Master Day Timetable</h2>\n"
        "<p>The whole camp runs on one clock. Groups start and stop together so "
        "breaks, lunch and the showcase stay in sync.</p>\n"
        "<table><thead><tr><th>Time</th><th>Activity</th></tr></thead>"
        f"<tbody>{body}</tbody></table>\n"
    )


def build_ai_programme(theme, track, bands, groups, staff, timetable_rows,
                       duration_label, camp_date, brief="", selected_ids=None):
    """Ask Claude for the age-appropriate programme and supporting sections.

    Returns the inner HTML that slots in after the deterministic tables.
    `brief` carries any free-text organiser notes/requirements to honour.
    `selected_ids` restricts the catalogue hint to the organiser's picks.
    """
    from generate_curriculum import stream_html

    band_lines = "\n".join(
        f"- {b['label']}: {b['count']} children, split into "
        f"{sum(1 for g in groups if g['band'] == b['label'])} group(s)"
        for b in bands
    )
    timetable_txt = "\n".join(f"{t}: {re.sub('<[^>]+>', '', a)}" for t, a in timetable_rows)
    hint = catalogue_hint(track, selected_ids=selected_ids)
    if selected_ids and hint:
        hint_block = (
            f"\n\nThe organiser hand-picked these TinkerWithMe projects for the camp — "
            f"use ONLY these, and assign each band the ones that best fit its age:\n{hint}"
        )
    else:
        hint_block = (
            f"\n\nTinkerWithMe already has these ready-made projects for this theme — "
            f"prefer them where they fit, and say which project each group does:\n{hint}"
            if hint else
            "\n\nThis theme is outside the standard catalogue, so design fresh, "
            "safe, hands-on activities for it."
        )
    brief_block = (
        f"\n\n**Organiser's notes / special requirements (honour these closely):**\n{brief}"
        if brief else ""
    )

    # Track-specific instruction for what "complete build detail" means so the
    # PDF actually contains everything needed to run each project on the day.
    if track == "ai":
        build_detail = (
            "For each project include a <strong>Build &amp; Run steps</strong> block with: "
            "the exact tool/website to open and how to set it up, the step-by-step "
            "workflow (e.g. for Teachable Machine: create classes, collect/upload "
            "sample images, train, preview, export the model), the precise example "
            "prompts or sample training data to use, and how the group tests their result."
        )
    else:
        build_detail = (
            "For each project include a <strong>Full Build Code &amp; Assembly</strong> block: "
            "a wiring/assembly list (component → pin), then the COMPLETE working code "
            "inside <pre><code> with inline comments. Do not abbreviate or write "
            "\"standard sketch\" — include the entire sketch/program a facilitator "
            "can type in and run."
        )

    system_prompt = (
        "You are the lead programme designer for TinkerWithMe, a hands-on STEM "
        "education programme in Nairobi. You are planning a full-day holiday camp "
        "for a mixed-age intake. Design an age-appropriate programme for EACH age "
        "band so every child is challenged at the right level and no group is idle. "
        "Do not include purchase links or URLs — name any materials by item, spec "
        "and quantity only (local suppliers such as Nerokas or Pixel Electronics "
        "may be named in plain text). Output clean HTML (no markdown, no inline "
        "styles): use <h2>, <h3>, <ul>/<li>, <table>, <strong>, <em>, <p>, and "
        "<pre><code> for any code. Always include the complete code or build steps "
        "needed to actually make each project — never summarise them away."
    )

    user_message = f"""Design the programme content for this full-day camp. The group splits, staffing and master timetable are ALREADY decided (shown below) — do not restate them; build the activities that fill the three project blocks.

**Camp:** {theme}
**Date:** {camp_date or 'TBC'}
**Length:** {duration_label}
**Age bands and groups:**
{band_lines}
**Total:** {staff['total_children']} children in {staff['n_groups']} groups, {staff['total_adults']} adults.

**Master timetable (fixed):**
{timetable_txt}{hint_block}{brief_block}

Produce these sections as HTML, in this order:

<h2>Programme by Age Band</h2>
For EACH age band, a <h3> with the band name, then:
- The project(s) for Block 1, Block 2 and Block 3 (age-appropriate; younger bands get simpler, more guided builds, older bands get more independence and challenge). A project may span more than one block.
- 2-3 learning goals for the band.
- {build_detail} If a project runs across multiple blocks, give its full code/build steps once. Every project a group builds must have its complete code/build steps somewhere in the plan.
- A short "Facilitator brief" paragraph: what the group's lead should prepare and watch for.

<h2>Materials Master List</h2>
A <table> with columns: Item | Spec | Per group | Groups | Total needed. Compute the Total column as per-group quantity × number of groups that use it. Include a short note on shared kit (e.g. laptops, power strips).

<h2>Safety, Logistics &amp; Contingencies</h2>
Room/space plan, movement between blocks, allergy/first-aid notes, and a wet-weather / early-finisher / equipment-failure contingency each.

<h2>Staff Briefing Checklist</h2>
A checklist the coordinator runs through with the team before doors open.

Output only these HTML sections — no DOCTYPE, <html>, <head> or <body> tags."""

    # Scale tokens with band count; full code/build steps per project need room.
    # Streaming (via stream_html) is required at these token sizes — a plain
    # non-streaming call raises "Streaming is required..." past ~10 min of work.
    return stream_html(
        system_prompt, user_message,
        max_tokens=min(32000, 10000 + len(bands) * 6000),
    )


def build_executive_summary(theme, bands, groups, staff, duration_label,
                            camp_date, venue):
    """The high-level overview that opens the plan: what it is, the numbers at a
    glance, and the learning outcomes. Detailed schedule/tables follow it."""
    band_summary = ", ".join(f"{b['label']} ({b['count']})" for b in bands)
    intro = (
        f"<p>This is the full plan for a <strong>{theme}</strong> camp of "
        f"<strong>{staff['total_children']} children</strong>"
        f"{f' on {camp_date}' if camp_date else ''}"
        f"{f' at {venue}' if venue else ''}. The intake is split into age bands — "
        f"{band_summary} — and each band into small groups, so every child works at "
        "the right level and gets plenty of hands-on time. The schedule, staffing, "
        "topic index and full lesson content follow below.</p>\n"
    )

    stats = [
        (staff["total_children"], "Children"),
        (len(bands), "Age bands"),
        (staff["n_groups"], "Groups"),
        (staff["total_adults"], "Adults"),
        (f"1:{staff['ratio']}", "Ratio"),
        (duration_label.split("(")[0].strip().title(), "Length"),
    ]
    stat_html = "".join(
        f'<span class="stat"><span class="n">{n}</span><span class="l">{l}</span></span>'
        for n, l in stats
    )

    outcomes = [
        "Every child builds and tests real projects pitched at their age and level.",
        "Children work in small teams — sharing roles, debugging together and helping "
        "one another.",
        "Each group presents what they made at the end-of-day showcase, building "
        "confidence and communication.",
    ]
    outcomes_html = "".join(f"<li>{o}</li>" for o in outcomes)

    return (
        '<div class="exec-summary">\n'
        "<h2>Executive Summary</h2>\n"
        + intro
        + f'<div class="stats">{stat_html}</div>\n'
        + "<h3>Learning outcomes</h3>\n<ul>"
        + outcomes_html
        + "</ul>\n</div>\n"
    )


def generate_camp_plan_pdf(theme, age_bands_raw, camp_date="", duration="full",
                           max_group_size=10, user_name="", user_email="",
                           venue="", brief="", project_ids=""):
    """Plan the camp and write the branded PDF. Returns the PDF path or None.

    `brief` is optional free-text organiser notes fed to the AI (e.g. "focus on
    Teachable Machine", "kids are beginners", "we only have 6 laptops").
    `project_ids` is an optional comma/space-separated list of catalogue project
    IDs the organiser hand-picked (e.g. "ar1,ar16,ar17"); when given, the camp
    uses only those projects and each band gets the best-fitting subset.
    """
    selected_ids = [pid for pid in re.split(r"[\s,]+", project_ids.strip()) if pid]
    try:
        bands = parse_age_bands(age_bands_raw)
    except ValueError as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return None

    is_full_day = str(duration).lower() in ("full", "full day", "fullday")
    duration_mins = 330 if is_full_day else int(duration)
    duration_label = "full day (approx. 08:30–15:30)" if is_full_day else f"{duration_mins} minutes"

    groups = split_into_groups(bands, max_group_size=max_group_size)
    staff = plan_staffing(groups)
    timetable_rows = build_master_timetable(is_full_day, duration_mins)
    track = resolve_track(theme)

    print(f"📋 Camp: {theme} · {staff['total_children']} children · "
          f"{staff['n_groups']} groups · {staff['total_adults']} adults")
    print(f"📧 User email: {user_email}")
    if selected_ids:
        print(f"🎯 Organiser-selected projects: {', '.join(selected_ids)}")

    try:
        # Fast path: catalogue themes assemble from the pre-generated cache with
        # ZERO AI tokens (full code included). Custom themes fall through to AI.
        # The plan (band → picks) is decided once so the topic index and the
        # numbered project cards stay in lock-step.
        programme_html = None
        topic_index = ""
        if track in ("arduino", "ai"):
            plan = plan_band_projects(track, bands, is_full_day, brief, selected_ids)
            programme_html = build_camp_programme_from_cache(track, plan, groups, brief)
        if programme_html is not None:
            print(f"🟢 Static path — assembled from cache (track: {track}), no AI tokens used")
            topic_index = build_topic_index(plan)   # numbering matches the cards
        else:
            print(f"✨ AI path — generating programme (track: {track})…")
            programme_html = build_ai_programme(
                theme, track, bands, groups, staff, timetable_rows,
                duration_label, camp_date, brief=brief, selected_ids=selected_ids,
            )

        # Order: executive summary → schedule → logistics → topic index → lessons.
        exec_summary = build_executive_summary(
            theme, bands, groups, staff, duration_label, camp_date, venue,
        )
        body_html = (
            exec_summary
            + _timetable_table(timetable_rows)
            + _groups_table(groups)
            + _staffing_table(staff)
            + topic_index
            + programme_html
        )

        current_date = datetime.now().strftime("%d %B %Y")
        prepared_html = (
            (f'Prepared for <strong>{user_name}</strong>' if user_name else 'Camp plan')
            + '<span class="session-badge">Full-day camp</span>'
        )
        header_html = pdf_template.build_header(
            title_line=f"{theme} · Full-Day Camp",
            subtitle_line=(f"{staff['total_children']} children · "
                           f"{staff['n_groups']} groups · {duration_label}"),
            prepared_html=prepared_html,
            current_date=current_date,
        )
        full_html = pdf_template.render_document(
            title=f"TinkerWithMe Camp Plan - {theme}",
            header_html=header_html,
            body_html=body_html,
        )

        output_dir = Path("output")
        output_dir.mkdir(exist_ok=True)
        safe_slug = re.sub(r"[^\w\-]", "", theme.replace(" ", "_")) or "camp"
        pdf_file = output_dir / f"TinkerWithMe_Camp_{safe_slug}.pdf"
        pdf_template.write_pdf(full_html, pdf_file)
        print(f"✅ Camp plan generated: {pdf_file}")
        print(f"\n📧 Ready to email to: {user_email}")
        return str(pdf_file)

    except Exception as e:
        print(f"❌ Error generating camp plan: {e}", file=sys.stderr)
        return None


if __name__ == "__main__":
    theme = os.getenv("CAMP_THEME", "Arduino Robotics & Electronics").strip()
    age_bands = os.getenv("AGE_BANDS", "7-9:20,10-12:19,13-15:12").strip()
    camp_date = os.getenv("CAMP_DATE", "").strip()
    duration = os.getenv("DURATION", "full").strip()
    venue = os.getenv("VENUE", "").strip()
    user_name = os.getenv("USER_NAME", "").strip()
    user_email = os.getenv("USER_EMAIL", "user@example.com").strip()
    brief = os.getenv("BRIEF", "").strip()
    project_ids = os.getenv("PROJECT_IDS", "").strip()
    try:
        max_group_size = int(os.getenv("MAX_GROUP_SIZE", "10"))
    except ValueError:
        max_group_size = 10

    # If the age-band fields are blank but a free-text brief was supplied, try to
    # read the bands straight out of the brief (e.g. "7-9 years: 20 children…").
    if not age_bands and brief:
        detected = find_age_bands_in_text(brief)
        if detected:
            age_bands = ",".join(f"{b['label'].replace(' yrs','')}:{b['count']}" for b in detected)
            print(f"🔎 Read age bands from brief: {age_bands}")

    result = generate_camp_plan_pdf(
        theme, age_bands, camp_date=camp_date, duration=duration,
        max_group_size=max_group_size, user_name=user_name,
        user_email=user_email, venue=venue, brief=brief, project_ids=project_ids,
    )
    if result is None:
        sys.exit(1)
