-- ============================================================================
-- Point every course's cover_url at its illustrative cover SVG.
--
-- The cover image files live in the repo (assets/courses/...). learn.html and
-- the free-page "curated" cards read cover_url FROM THE DATABASE, so replacing
-- the files alone isn't enough — this updates the DB to match. (The three free
-- "classics" hardcode their path in free-for-kids.html, so they already show
-- the new covers; this also sets their DB value for learn.html.)
--
-- Apply in the Supabase SQL editor. Safe to re-run. A slug that doesn't exist
-- simply isn't updated — no error.
-- ============================================================================

-- Free courses → assets/courses/free/<slug>.svg
update public.lms_courses
  set cover_url = 'assets/courses/free/' || slug || '.svg'
  where slug in (
    'ai-skills-for-kids','what-is-ai','robotics-101',
    'first-circuits-lights','sound-sensors-signals','machines-movement',
    'robots-smart-builds','ai-creator-studio','how-ai-really-works','ai-and-your-future'
  );

-- Premium courses → assets/courses/<slug>.svg
update public.lms_courses
  set cover_url = 'assets/courses/' || slug || '.svg'
  where slug in (
    'smart-home-builder','self-driving-car','smart-city','robot-arm-claw',
    'wearable-tech-lab','iot-garden-monitor','musical-instrument-builder',
    'smart-plant-carer','bluetooth-control-lab',
    'ai-game-designer','ai-movie-studio','ai-entrepreneur','deepfake-detective',
    'ai-music-producer','computer-vision-explorer','ai-for-social-good','smart-city-2-ai-powered'
  );

-- Review the result:
--   select slug, cover_url from public.lms_courses order by slug;
