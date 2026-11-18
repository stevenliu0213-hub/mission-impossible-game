-- Mission Impossible public leaderboard. Run once in a Supabase project's SQL editor.
-- The browser uses ONLY the public publishable key. No login is required.
-- Client-reported scores are not cheat-proof. Anonymous clients cannot modify/delete records.
create table if not exists public.mission_runs (
  id uuid primary key,
  name text not null check (char_length(name) between 1 and 24),
  score integer not null check (score between 0 and 10000000),
  level integer not null check (level between 1 and 5),
  win boolean not null,
  elapsed_ms integer not null check (elapsed_ms between 0 and 86400000),
  created_at timestamptz not null default now(),
  check (not win or level = 5)
);
alter table public.mission_runs enable row level security;
revoke all on public.mission_runs from anon, authenticated;
create or replace function public.submit_mission_run(
  run_id uuid, player_name text, points integer, reached_level integer,
  completed boolean, duration_ms integer
) returns boolean language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.mission_runs(id,name,score,level,win,elapsed_ms)
  values(run_id,trim(player_name),points,reached_level,completed,duration_ms)
  on conflict(id) do nothing;
  return true;
end;
$$;
revoke all on function public.submit_mission_run(uuid,text,integer,integer,boolean,integer) from public;
grant execute on function public.submit_mission_run(uuid,text,integer,integer,boolean,integer) to anon, authenticated;
create or replace function public.mission_leaderboard()
returns table(name text, score integer, level integer, win boolean, elapsed_ms integer)
language sql stable security definer set search_path = ''
as $$
  select r.name,r.score,r.level,r.win,r.elapsed_ms from public.mission_runs r
  order by r.win desc,
    case when r.win then r.elapsed_ms end asc nulls last,
    case when not r.win then r.level end desc nulls last,
    case when not r.win then r.elapsed_ms end asc nulls last,
    r.score desc,r.created_at asc,r.id asc
  limit 10;
$$;
revoke all on function public.mission_leaderboard() from public;
grant execute on function public.mission_leaderboard() to anon, authenticated;
