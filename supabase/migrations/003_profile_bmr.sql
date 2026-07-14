-- Bench Tracker — age, height and activity level on profiles.
-- Run this in: Supabase Dashboard > SQL Editor > New query > Run.
--
-- The daily targets moved from a flat kcal-per-kg table to Mifflin-St Jeor,
-- which needs three inputs the profile did not carry: age, height and how much
-- the lifter moves outside the gym.
--
-- Existing rows keep working: the defaults below are the same ones Profile()
-- falls back to in Dart, so a profile written before this migration and one
-- written after compute the same targets.

alter table public.profiles
  add column if not exists height_cm double precision not null default 180
    check (height_cm > 0),
  add column if not exists age integer not null default 30
    check (age > 0),
  -- Stored as the label, not the multiplier: the multiplier is a tuning
  -- constant that may be revised, the label is what the user chose.
  add column if not exists activity_level text not null default 'Moderately Active'
    check (activity_level in (
      'Sedentary',
      'Lightly Active',
      'Moderately Active',
      'Very Active'));
