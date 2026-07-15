-- 009 — RLS performance tuning.
-- Run this in: Supabase Dashboard > SQL Editor > New query > Run.
--
-- The policies from 001_init.sql are CORRECT — a user can only ever touch their
-- own rows. This migration does not change who can see what; it only changes how
-- fast Postgres decides it. Two mechanical rewrites, both from the Supabase RLS
-- performance guidance:
--
--   1. Wrap auth.uid() in a scalar sub-select: (select auth.uid()).
--      Bare auth.uid() is re-evaluated for EVERY row a query scans. Wrapped in a
--      sub-select the planner hoists it into an initPlan and runs it once per
--      statement, then compares the cached result against each row. On the
--      workouts table — which workouts_user_date_idx can return many rows from —
--      that is the difference between N function calls and one.
--
--   2. Scope each policy `to authenticated`.
--      Without a role, a policy is also evaluated for the `anon` role on every
--      anonymous request. These tables are never legitimately read anonymously
--      (every row is keyed to auth.uid(), which is null for anon), so pinning
--      the policy to `authenticated` lets Postgres skip it entirely for anon.
--
-- Policy names are unchanged, so this is a drop-and-recreate of the same three
-- (plus water_intake / reminders, IF a future migration has created them — the
-- guarded block below is a no-op when they are absent). Idempotent: safe to run
-- more than once.

-- ---------------------------------------------------------------------------
-- workouts
-- ---------------------------------------------------------------------------
drop policy if exists "own workouts" on public.workouts;
create policy "own workouts" on public.workouts
  for all to authenticated
  using ( (select auth.uid()) = user_id )
  with check ( (select auth.uid()) = user_id );

-- ---------------------------------------------------------------------------
-- meals
-- ---------------------------------------------------------------------------
drop policy if exists "own meals" on public.meals;
create policy "own meals" on public.meals
  for all to authenticated
  using ( (select auth.uid()) = user_id )
  with check ( (select auth.uid()) = user_id );

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles
  for all to authenticated
  using ( (select auth.uid()) = user_id )
  with check ( (select auth.uid()) = user_id );

-- ---------------------------------------------------------------------------
-- water_intake / reminders  (only if a future migration created them)
-- ---------------------------------------------------------------------------
-- Guarded so this migration also runs cleanly on a project that has not yet
-- promoted hydration/reminders to Supabase. If the tables are absent, skip.
do $$
begin
  if to_regclass('public.water_intake') is not null then
    execute 'drop policy if exists "own water" on public.water_intake';
    execute $p$
      create policy "own water" on public.water_intake
        for all to authenticated
        using ( (select auth.uid()) = user_id )
        with check ( (select auth.uid()) = user_id )
    $p$;
  end if;

  if to_regclass('public.reminders') is not null then
    execute 'drop policy if exists "own reminders" on public.reminders';
    execute $p$
      create policy "own reminders" on public.reminders
        for all to authenticated
        using ( (select auth.uid()) = user_id )
        with check ( (select auth.uid()) = user_id )
    $p$;
  end if;
end $$;

-- Verify: every policy below should show roles = {authenticated} and its
-- qual/with_check reading ( SELECT auth.uid() ) rather than a bare auth.uid().
--   select tablename, policyname, roles, qual, with_check
--     from pg_policies
--    where schemaname = 'public'
--    order by tablename;
