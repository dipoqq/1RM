-- 010 — permanent unlocked-achievement ledger.
-- Run this in: Supabase Dashboard > SQL Editor > New query > Run.
--
-- Problem this solves: achievement "unlocked" state is DERIVED from workout
-- history (AchievementsEngine.evaluate). So if a lifter deletes the workout that
-- earned an achievement and logs it again, the engine sees it flip
-- locked -> unlocked a second time and the toast + confetti fire again.
--
-- This table is the durable record of "this has been celebrated before, ever".
-- The celebration path checks it first and stays silent on anything already
-- listed. It is append-only and permanent by design: deleting a workout removes
-- the achievement from the *display* (which is still history-derived) but never
-- from this ledger, so re-earning it is quiet.
--
-- The primary key (user_id, achievement_id) is what makes recording idempotent:
-- an insert that conflicts is a no-op, and RETURNING then tells the client
-- whether THIS insert was the first (a row came back) or a duplicate (none did).
create table if not exists public.unlocked_achievements (
  user_id        uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null,
  unlocked_at    timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

alter table public.unlocked_achievements enable row level security;

-- Same shape as the 009 policies: scalar sub-select for a once-per-statement
-- initPlan, scoped to `authenticated` so the anon role is skipped entirely.
create policy "own achievements" on public.unlocked_achievements
  for all to authenticated
  using ( (select auth.uid()) = user_id )
  with check ( (select auth.uid()) = user_id );

-- Verify:
--   select achievement_id, unlocked_at
--     from public.unlocked_achievements
--    where user_id = auth.uid()
--    order by unlocked_at;
