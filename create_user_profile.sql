-- Check and create user profile record if missing
-- Run this in Supabase SQL Editor

-- First, check if profile exists for your user
SELECT 
    id, 
    email, 
    first_name, 
    last_name,
    created_at
FROM user_profiles 
WHERE id = 'e0997cb7-68df-41e6-923f-48107872d434';

-- If no record exists, create one using auth.users data
INSERT INTO user_profiles (
    id, 
    email, 
    first_name, 
    last_name,
    role,
    created_at,
    updated_at,
    is_email_verified
)
SELECT 
    au.id,
    au.email,
    COALESCE(au.raw_user_meta_data->>'first_name', 'Mark') as first_name,
    COALESCE(au.raw_user_meta_data->>'last_name', 'Molina') as last_name,
    'patient' as role,
    au.created_at,
    NOW() as updated_at,
    au.email_confirmed_at IS NOT NULL as is_email_verified
FROM auth.users au
WHERE au.id = 'e0997cb7-68df-41e6-923f-48107872d434'
AND NOT EXISTS (
    SELECT 1 FROM user_profiles up WHERE up.id = au.id
);

-- Verify the record was created
SELECT 
    id, 
    email, 
    first_name, 
    last_name,
    role,
    is_email_verified,
    created_at
FROM user_profiles 
WHERE id = 'e0997cb7-68df-41e6-923f-48107872d434';
