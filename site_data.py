"""
The course picker catalogue as saved from the Course editor (admin.html).

It lives in Supabase (supabase/site-content.sql). If Supabase can't be reached
this falls back to courses.json in the repo, so the agents always have a
catalogue. Uses the public read function, so no secret key is needed.
"""

import json
import urllib.request
from pathlib import Path

SUPABASE_URL = "https://xithafmrpqzwhkqzwfmk.supabase.co"
PUBLISHABLE_KEY = "sb_publishable__mlDCy3NdYIp9iRhDRfcpw_OhhsyHOT"  # public by design


def load_courses():
    """Return the catalogue in the courses.json shape: {track: {ages, projects}}."""
    try:
        req = urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/rpc/site_content_public",
            data=json.dumps({"p_key": "courses"}).encode(),
            headers={"apikey": PUBLISHABLE_KEY, "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            data = json.load(r)
        if isinstance(data, dict) and data.get("arduino"):
            return data
        reason = "nothing saved yet"
    except Exception as e:  # network, Supabase down, table not created yet
        reason = str(e)
    print(f"ℹ️  Using courses.json ({reason})")
    with open(Path(__file__).with_name("courses.json"), encoding="utf-8") as f:
        return json.load(f)
