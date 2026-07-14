-- 1RM — gender on profiles.
-- Run this in: Supabase Dashboard > SQL Editor > New query > Run.
--
-- Mifflin-St Jeor is two equations, not one. The male form ends `+ 5`, the
-- female form ends `- 161`, and that 166 kcal gap is multiplied by the activity
-- factor and carried into every calorie and carb target the Nutrition tab
-- shows. Without this column the app scored every lifter on the male equation,
-- which over-feeds a female lifter by a few hundred kcal a day — so gender is
-- an INPUT to the targets, not a demographic field.
--
-- It belongs on `profiles` for the same reason the language and the bench goal
-- do: it is a preference that must SYNC. Set it on the desktop, see the same
-- targets on the phone.
--
-- Existing rows keep working: the default is the same one Profile() falls back
-- to in Dart, so a row written before this migration computes exactly the
-- targets it computed yesterday.

alter table public.profiles
  -- Stored as the label, not the constant: -161 is a tuning value from the
  -- paper, 'Female' is what the user chose. Same convention as `goal` and
  -- `activity_level`, and the CHECK is the backstop that holds even if a future
  -- client forgets to validate. Adding an option means extending both this
  -- CHECK and the Gender enum in Dart.
  add column if not exists gender text not null default 'Male'
    check (gender in ('Male', 'Female'));
