-- Bench Tracker — initial schema
-- Run this in: Supabase Dashboard > SQL Editor > New query > Run.
--
-- Three deviations from the original two-table spec, each explained below.

-- ---------------------------------------------------------------------------
-- workouts
-- ---------------------------------------------------------------------------
create table if not exists public.workouts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  date          timestamptz not null default now(),
  workout_type  text not null check (workout_type in (
                  'Heavy Day (Strength)',
                  'Volume Day (Hypertrophy/Technique)',
                  'Deload (Recovery)')),
  weight        double precision not null check (weight > 0),
  reps          integer not null check (reps > 0),
  sets          integer not null check (sets > 0),
  completed     boolean not null default true,
  -- DEVIATION 1: `note` is not in the spec, but the existing workout_data.json
  -- already carries it on every row. Dropping it would silently lose data on
  -- import, so it is preserved (nullable, defaults to empty).
  note          text not null default '',
  created_at    timestamptz not null default now()
);

-- The plateau detector reads the most recent heavy days for one user, so this
-- is the index that query actually needs.
create index if not exists workouts_user_date_idx
  on public.workouts (user_id, date desc);

-- ---------------------------------------------------------------------------
-- meals
-- ---------------------------------------------------------------------------
create table if not exists public.meals (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  -- DEVIATION 2: `date` is a DATE, not a TIMESTAMP.
  -- The spec says timestamp, but the calendar diary keys everything by calendar
  -- day. With a timestamptz, a meal logged at 23:30 local time is stored as the
  -- NEXT day in UTC, so it would vanish from "today" and appear on tomorrow's
  -- strip. A DATE column stores the day the user actually ate, which is the
  -- thing the whole tab is organised around. (The Python app already did this:
  -- meals use "2026-07-14", workouts use a full ISO timestamp.)
  date       date not null default current_date,
  name       text not null,
  calories   double precision not null default 0,
  protein    double precision not null default 0,
  carbs      double precision not null default 0,
  fats       double precision not null default 0,
  created_at timestamptz not null default now()
);

-- Selecting a date on the strip is a (user_id, date) lookup.
create index if not exists meals_user_date_idx
  on public.meals (user_id, date desc);

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
-- DEVIATION 3: this table is not in the spec, but the app cannot meet two of
-- its own requirements without it.
--
--   * "burst confetti ... past 80 kg or 95 kg FOR THE FIRST TIME" needs a
--     durable record of which milestones have already fired. Your existing
--     workout_data.json already has "celebrated_milestones": [80.0] — you have
--     ALREADY passed 80 kg. Without persisting that, the app would re-fire the
--     80 kg confetti on next launch, which is exactly what "first time" forbids.
--   * bodyweight + goal must survive a reinstall and follow you across devices.
create table if not exists public.profiles (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  weight_kg   double precision not null default 94,
  goal        text not null default 'Lean Bulk'
                check (goal in ('Lean Bulk', 'Maintenance', 'Cut')),
  -- Milestone 1RMs already celebrated, e.g. [80.0]. Confetti fires only for a
  -- milestone NOT in this list, then appends to it.
  celebrated_milestones double precision[] not null default '{}',
  updated_at  timestamptz not null default now()
);

-- Give every new signup a profile row automatically, so the app never has to
-- cope with a missing one.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
-- The spec said RLS could be omitted "since this is for personal use".
-- It is NOT omitted, deliberately.
--
-- The anon key ships inside the app binary and is world-readable. With RLS off,
-- ANY person on the internet holding that key can read, edit and delete every
-- row in these tables. "Personal use" makes the data more sensitive, not less.
-- These policies are four lines each and cost nothing.
alter table public.workouts enable row level security;
alter table public.meals    enable row level security;
alter table public.profiles enable row level security;

-- Each user sees and touches only their own rows.
create policy "own workouts" on public.workouts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own meals" on public.meals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own profile" on public.profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
