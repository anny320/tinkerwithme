-- Leaderboard for the Train an AI game (train-an-ai.html).
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.
-- Safe to run again; it replaces the function and keeps existing scores.
--
-- The page talks to Supabase with the public (anon / publishable) key, so:
--   * anyone may READ the scores table (it holds only nicknames and numbers);
--   * nobody may write to it directly — scores go in only through
--     submit_train_ai_score(), which checks the nickname and works out the
--     score itself, so a player can't post a made-up score.
-- To remove a nickname: Table Editor → train_ai_scores → delete the row.

create table if not exists public.train_ai_scores (
  id         bigint generated always as identity primary key,
  nickname   text        not null check (char_length(nickname) between 2 and 16),
  tests      int         not null check (tests between 3 and 200),
  seconds    int         not null check (seconds between 30 and 36000),
  score      int         not null,
  created_at timestamptz not null default now()
);
create index if not exists train_ai_scores_rank on public.train_ai_scores (score desc, id);

alter table public.train_ai_scores enable row level security;
drop policy if exists "Anyone can read the leaderboard" on public.train_ai_scores;
create policy "Anyone can read the leaderboard" on public.train_ai_scores
  for select to anon, authenticated using (true);
revoke insert, update, delete on public.train_ai_scores from anon, authenticated;
grant select on public.train_ai_scores to anon, authenticated;

-- Score rules (keep in step with trainScore() in train-an-ai.html):
--   3,000 points for finishing all 3 missions in 3 tests, minus 250 for each
--   extra test, plus a speed bonus of 1,000 minus 2 per second (0 after 8m20s).
create or replace function public.submit_train_ai_score(p_nickname text, p_tests int, p_seconds int)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  n      text := btrim(regexp_replace(coalesce(p_nickname, ''), '\s+', ' ', 'g'));
  s      int;
  new_id bigint;
  r      bigint;
begin
  if n !~ '^[A-Za-z0-9 ]{2,16}$' then
    raise exception 'Nicknames are 2 to 16 letters or numbers.';
  end if;
  if n ~ '[0-9]{4,}' then
    raise exception 'Please leave long numbers out of your nickname.';
  end if;
  -- A short list of words kids shouldn't see on the board. Extend as needed.
  if lower(n) ~ '(fuck|shit|bitch|cunt|pussy|porn|sex|nigg|fag|slut|whore|bastard|penis|vagina|boob|rape|nazi|asshole|crap|mavi|msenge|malaya|mkundu)' then
    raise exception 'Please pick a different nickname.';
  end if;
  if p_tests is null or p_seconds is null or p_tests < 3 or p_tests > 200 or p_seconds < 30 or p_seconds > 36000 then
    raise exception 'That run doesn''t look right.';
  end if;
  -- Flood guard: at most 30 new scores a minute across everyone.
  if (select count(*) from train_ai_scores where created_at > now() - interval '1 minute') >= 30 then
    raise exception 'Lots of scores coming in, try again in a minute.';
  end if;

  s := greatest(0, 3000 - 250 * (p_tests - 3)) + greatest(0, 1000 - 2 * p_seconds);
  insert into train_ai_scores (nickname, tests, seconds, score)
    values (n, p_tests, p_seconds, s) returning id into new_id;
  select count(*) + 1 into r from train_ai_scores t
    where t.score > s or (t.score = s and t.id < new_id);
  return json_build_object('id', new_id, 'score', s, 'rank', r);
end;
$$;

revoke all on function public.submit_train_ai_score(text, int, int) from public;
grant execute on function public.submit_train_ai_score(text, int, int) to anon, authenticated;
