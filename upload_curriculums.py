"""
Upload rendered full-curriculum PDFs (curriculums/<id>.pdf) straight to the
private Supabase bucket, where buyers download them on curriculum.html
(lms-files/curriculum/<id>/). Used by the "Pre-generate Premium Curriculums"
workflow so paid PDFs never become a public download on this public repo.

    SUPABASE_URL=... SUPABASE_SECRET_KEY=... python upload_curriculums.py
"""
import json, os, sys
from pathlib import Path

from generate_elearning import Supabase, curriculum_name

HERE = Path(__file__).resolve().parent


def main():
    url, key = os.getenv("SUPABASE_URL"), os.getenv("SUPABASE_SECRET_KEY")
    if not (url and key):
        sys.exit("Set SUPABASE_URL and SUPABASE_SECRET_KEY.")
    db = Supabase(url, key)
    courses = {c["id"]: c for c in json.loads((HERE / "premium_courses.json").read_text())["courses"]}
    pdfs = sorted((HERE / "curriculums").glob("*.pdf"))
    if not pdfs:
        sys.exit("No PDFs in curriculums/.")
    for pdf in pdfs:
        course = courses.get(pdf.stem)
        if not course:
            print(f"  skipped {pdf.name}: not in premium_courses.json")
            continue
        db.upload_file("lms-files", f"curriculum/{course['id']}/{curriculum_name(course)}", pdf, "application/pdf")
        print(f"  📚 {course['id']} → curriculum shop")
    print(f"Uploaded {len(pdfs)} curriculum PDF(s).")


if __name__ == "__main__":
    main()
