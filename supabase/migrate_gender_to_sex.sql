-- Migration: Rename 'gender' column to 'sex' in user_profiles table
-- Run this in your Supabase SQL editor

-- 1. First, add the new 'sex' column
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS sex text;

-- 2. Copy data from 'gender' to 'sex' column and normalize to lowercase
UPDATE user_profiles 
SET sex = LOWER(gender) 
WHERE gender IS NOT NULL;

-- 3. Verify the data before adding constraint
-- SELECT DISTINCT sex, COUNT(*) FROM user_profiles GROUP BY sex;

-- 4. Add constraint to the new 'sex' column (allow NULL values)
ALTER TABLE user_profiles ADD CONSTRAINT check_sex 
CHECK (sex IN ('male', 'female', 'other', 'prefer_not_to_say') OR sex IS NULL);

-- 5. Drop the old 'gender' column
ALTER TABLE user_profiles DROP COLUMN IF EXISTS gender CASCADE;

-- 5. Update any indexes or triggers that might reference the old column
-- (Add specific index updates here if needed)

-- Verification query to check the migration
-- SELECT sex, COUNT(*) FROM user_profiles GROUP BY sex;

-- Note: This migration script assumes:
-- 1. Your table is named 'user_profiles'
-- 2. The gender column exists and has the expected constraint values
-- 3. You want to maintain the same constraint values for the sex column
--
-- Before running this migration:
-- 1. Backup your database
-- 2. Test this on a development environment first
-- 3. Ensure no applications are actively writing to the gender column
--
-- After running this migration:
-- 1. Update your application code to use 'sex' instead of 'gender'
-- 2. Update any RLS policies that reference the old column
-- 3. Update any functions that reference the old column