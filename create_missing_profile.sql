-- Check existing RLS policies and fix them
-- Run this in Supabase SQL Editor

-- First, check what policies exist
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'user_profiles';

-- Check if we can see the profile (should fail due to RLS)
SELECT * FROM user_profiles 
WHERE id = 'e0997cb7-68df-41e6-923f-48107872d434';
