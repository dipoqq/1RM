-- Bench Tracker — import history from workout_data.json
--
-- PREREQUISITES
--   1. 001_init.sql has been run.
--   2. You have signed up in the app at least once (that creates your auth user
--      and, via the trigger, your profiles row).
--
-- HOW TO RUN
--   Supabase Dashboard > SQL Editor > New query > paste this whole file > Run.
--
--   Set your email on the next line. Everything below resolves your user_id from
--   it, so no IDs need to be copied by hand.
--
-- SAFETY
--   Re-running this file will NOT duplicate rows: each insert is guarded by a
--   `where not exists` on the same natural key. It is safe to run twice.

do $$
declare
  -- ▼▼▼ CHANGE THIS to the email you signed up with ▼▼▼
  v_email text := 'you@example.com';
  v_uid   uuid;
begin
  select id into v_uid from auth.users where email = v_email;

  if v_uid is null then
    raise exception
      'No auth user found for %. Sign up in the app first, then re-run.', v_email;
  end if;

  -- -- workouts ---------------------------------------------------------------
  -- Both sessions from workout_data.json. Your current PR: 70 kg x 1
  -- (Epley estimated 1RM 72.3 kg).
  insert into public.workouts (user_id, date, workout_type, weight, reps, sets, completed, note)
  select v_uid, t.date, t.workout_type, t.weight, t.reps, t.sets, t.completed, t.note
    from (values
      ('2026-07-14T15:45:19'::timestamptz, 'Heavy Day (Strength)', 70.0::double precision, 1, 1, true,  ''),
      ('2026-07-14T15:45:08'::timestamptz, 'Heavy Day (Strength)', 60.0::double precision, 5, 1, true,  '')
    ) as t(date, workout_type, weight, reps, sets, completed, note)
   where not exists (
     select 1 from public.workouts w
      where w.user_id = v_uid and w.date = t.date and w.weight = t.weight
   );

  -- -- meals ------------------------------------------------------------------
  -- All three logged on 2026-07-14. Totals: 2805 kcal, 179 g protein.
  insert into public.meals (user_id, date, name, calories, protein, carbs, fats)
  select v_uid, m.date, m.name, m.calories, m.protein, m.carbs, m.fats
    from (values
      ('2026-07-14'::date, 'Protein Pancake Feast',          1570.0::double precision,  65.0::double precision, 232.0::double precision, 41.0::double precision),
      ('2026-07-14'::date, 'Chicken Pasta and OJ',            775.0::double precision,  77.0::double precision,  94.0::double precision,  9.0::double precision),
      ('2026-07-14'::date, 'Cottage Cheese and Banana Bowl',  460.0::double precision,  37.0::double precision,  55.0::double precision, 11.0::double precision)
    ) as m(date, name, calories, protein, carbs, fats)
   where not exists (
     select 1 from public.meals x
      where x.user_id = v_uid and x.date = m.date and x.name = m.name
   );

  -- -- profile ----------------------------------------------------------------
  -- celebrated_milestones is deliberately left EMPTY.
  --
  -- workout_data.json carried [80.0], but the logged history peaks at a 72.3 kg
  -- estimated 1RM — that 80 kg entry was a test fire, not a real lift. Seeding it
  -- would permanently rob you of the celebration when you actually clear 80 kg.
  --
  -- Bodyweight is set to 94 kg (your stated weight, and the figure the Gemini
  -- nutritionist persona is built around). workout_data.json still says 92 kg —
  -- a stale value. Either way it is editable in the Nutrition tab.
  insert into public.profiles (user_id, weight_kg, goal, celebrated_milestones)
  values (v_uid, 94, 'Lean Bulk', '{}')
  on conflict (user_id) do update
    set weight_kg = excluded.weight_kg,
        goal      = excluded.goal,
        updated_at = now();
  -- NB: the update branch deliberately does NOT touch celebrated_milestones, so
  -- re-running this file can never wipe a celebration you have since earned.

  raise notice 'Imported history for % (user_id %).', v_email, v_uid;
end $$;

-- Verify:
--   select count(*) from public.workouts;   -- expect 2
--   select count(*) from public.meals;      -- expect 3
--   select * from public.profiles;
