-- Bench Tracker — UI language and a custom bench press goal on profiles.
-- Run this in: Supabase Dashboard > SQL Editor > New query > Run.
--
-- Both columns are preferences, and both belong on `profiles` for the same
-- reason: the requirement is that they SYNC. A language toggle or a bench goal
-- kept in local storage would have to be set once on Windows and again on
-- Android, and the two could then disagree forever. One row, keyed to
-- auth.uid(), is what makes "set it on the desktop, see it on the phone" true.
--
-- Existing rows keep working: both defaults are the same ones Profile() falls
-- back to in Dart, so a profile written before this migration and one written
-- after behave identically.

alter table public.profiles
  -- The lifter's own target 1RM. Drives the Training tab's progress bar, the
  -- "kg to go" line, the completion percentage and the final confetti
  -- milestone. Bounded, not free: the floor is the empty Olympic bar (a goal
  -- below it is not a goal) and the ceiling is well past the raw world record,
  -- so the CHECK only ever catches a typo — 950 for 95. The same bounds are
  -- enforced client-side in Profile.clampGoal, and this is the backstop that
  -- holds even if a future client forgets to.
  add column if not exists bench_goal_kg double precision not null default 95
    check (bench_goal_kg >= 20 and bench_goal_kg <= 500),

  -- Stored as the BCP-47 language subtag, not a display name: 'Русский' is
  -- what the user reads, 'ru' is what the code switches on. Adding a language
  -- means extending both this CHECK and the AppLocale enum.
  add column if not exists language text not null default 'en'
    check (language in ('en', 'ru'));
