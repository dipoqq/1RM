-- 1RM — mandatory onboarding: mark when a profile was actually set up.
-- Run this in: Supabase Dashboard > SQL Editor > New query > Run.
--
-- The app now refuses to open the tabs until the lifter has entered their own
-- body metrics, so it needs to answer one question at boot: has this profile
-- ever been set up? That question CANNOT be answered from the metrics
-- themselves.
--
-- The tempting shortcut is "the metrics still equal the column defaults
-- (180 cm / 94 kg / 30 y), therefore this user is new". But those defaults are
-- a perfectly ordinary body. A lifter who genuinely is 180 cm, 94 kg and 30
-- years old would complete onboarding, save exactly those numbers, and be
-- forced straight back into onboarding on the next launch — forever, with no
-- way to reach the app. A user is new because they have never been through
-- setup, not because of what they weigh.
--
-- Hence an explicit timestamp. Null means "never onboarded" and nothing else.

alter table public.profiles
  -- Set once, by the client, when onboarding is completed and saved. Nullable
  -- BY DESIGN: null is the signal AuthGate routes on, so it has no default.
  add column if not exists onboarded_at timestamptz;

-- Backfill for rows that predate this column.
--
-- This is the one place the default-metrics heuristic is sound: it runs exactly
-- once, against history, where "these three columns were never written" really
-- does mean "this profile was never filled in". Anyone who has touched any of
-- the three is treated as already set up and is never shown onboarding.
--
-- The consequence, deliberately: an existing user still sitting on all three
-- untouched defaults IS shown onboarding, once. That is the point of the
-- milestone — those are the users starting from 180/94 who were never asked.
update public.profiles
   set onboarded_at = now()
 where onboarded_at is null
   and not (height_cm = 180 and weight_kg = 94 and age = 30);

-- ---------------------------------------------------------------------------
-- theme
-- ---------------------------------------------------------------------------
-- Dark or light, per account. On `profiles` for exactly the reason `language`
-- is: it is a preference the user expects to SET ONCE. A theme kept in local
-- storage has to be chosen again on every device, and the two can then disagree
-- forever.
--
-- No 'system' option, deliberately: "follow the device" is not a value that can
-- be synced between a phone in dark mode and a desktop in light mode — it would
-- mean two different things in the two places. The lifter picks a look.
alter table public.profiles
  add column if not exists theme text not null default 'dark'
    check (theme in ('dark', 'light'));

-- NB: existing rows land on 'dark', which is a visible change for anyone who
-- upgrades — v1.1.0 moves the app to the dark/mint identity, and the switch in
-- Settings is right there for anyone who wants the old light look back.

-- Verify:
--   select user_id, height_cm, weight_kg, age, theme, onboarded_at
--     from public.profiles;
--   -- onboarded_at null  -> will be sent through onboarding on next launch
--   -- onboarded_at set   -> goes straight to the dashboard
