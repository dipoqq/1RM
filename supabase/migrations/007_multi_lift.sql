-- Multi-lift architecture support
alter table public.profiles
  add column if not exists squat_goal_kg double precision not null default 100,
  add column if not exists deadlift_goal_kg double precision not null default 120;

alter table public.workouts
  add column if not exists exercise text not null default 'Bench Press'
  check (exercise in ('Bench Press', 'Squat', 'Deadlift'));
