-- Check user profile record
-- Run this in Supabase SQL Editor

-- First, check the table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
ORDER BY ordinal_position;

-- Check if profile exists for your user
SELECT *
FROM user_profiles 
WHERE id = 'e0997cb7-68df-41e6-923f-48107872d434';

-- Also check what's in auth.users for comparison
SELECT 
    id,
    email,
    email_confirmed_at,
    raw_user_meta_data,
    created_at
FROM auth.users 
WHERE id = 'e0997cb7-68df-41e6-923f-48107872d434';
