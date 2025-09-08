-- Fix RLS Policies for user_profiles table
-- This script resolves the infinite recursion error by removing ALL existing
-- policies on user_profiles and recreating minimal, non-recursive ones.

-- 1) Show current policies on user_profiles (for visibility)
SELECT schemaname, tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'user_profiles';

-- 2) Drop ALL existing policies on user_profiles (regardless of name)
DO $$
DECLARE r record;
BEGIN
    FOR r IN (
    SELECT policyname FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_profiles'
    ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.user_profiles;', r.policyname);
    END LOOP;
END$$;

-- 3) Ensure RLS is enabled (do not force; keep default behavior)
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- 4) Create only safe, non-recursive self-access policies
-- These policies must NOT reference user_profiles in their expressions
CREATE POLICY user_profiles_select_policy
    ON public.user_profiles
    FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY user_profiles_insert_policy
    ON public.user_profiles
    FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY user_profiles_update_policy
    ON public.user_profiles
    FOR UPDATE
    USING (auth.uid() = id);

-- 5) Show resulting policies to confirm
SELECT schemaname, tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'user_profiles';

-- 6) Optional: nudge PostgREST to reload schema/policies (usually auto)
-- SELECT pg_notify('pgrst', 'reload schema');

-- 7) Status line
SELECT 'RLS policies fixed successfully (user_profiles)' AS status;
