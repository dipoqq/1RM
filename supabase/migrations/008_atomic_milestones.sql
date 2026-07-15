-- 008 — atomic milestone claiming.
-- Run this in: Supabase Dashboard > SQL Editor > New query > Run.
--
-- Replaces the read-then-write claim in SupabaseService.claimMilestone, which
-- was NOT atomic despite its comment: it did fetchProfile() then saveProfile(),
-- so two devices crossing the same milestone at once could both read "not
-- celebrated", both write, and both fire the confetti — breaking the "for the
-- first time" guarantee that migration 006 exists to protect.
--
-- This function folds the check and the append into a single UPDATE. The row
-- lock the UPDATE takes means the second caller blocks until the first commits,
-- then re-evaluates its WHERE against the freshly-appended array and matches no
-- rows — so it returns false and nothing fires. Atomic, by construction.
--
-- security definer so the function runs with the definer's rights, but the
-- WHERE is pinned to (select auth.uid()): a caller can only ever claim a
-- milestone on their OWN profile row, never anyone else's. search_path is
-- emptied so nothing on the caller's path can shadow public/pg_catalog.
create or replace function public.claim_milestone(p_kg double precision)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  claimed boolean;
begin
  update public.profiles
     set celebrated_milestones = celebrated_milestones || p_kg
   where user_id = (select auth.uid())
     -- Only when this milestone is NOT already in the array. @> is the array
     -- "contains" operator; the negation is the "absent" guard.
     and not (celebrated_milestones @> array[p_kg])
  returning true into claimed;

  -- No row updated -> either already celebrated, or (defensively) no profile
  -- row for this user. Either way this call did not claim it.
  return coalesce(claimed, false);
end;
$$;

-- Lock the function down: only signed-in users may call it, and only for
-- themselves (enforced by the auth.uid() predicate above).
revoke all on function public.claim_milestone(double precision) from public, anon;
grant execute on function public.claim_milestone(double precision) to authenticated;

-- Verify:
--   select public.claim_milestone(80);   -- true  the first time
--   select public.claim_milestone(80);   -- false every time after
--   select celebrated_milestones from public.profiles where user_id = auth.uid();
