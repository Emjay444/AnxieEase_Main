-- Update profile name to match your email
-- Run this in Supabase SQL Editor

UPDATE user_profiles 
SET 
    first_name = 'Mark',
    middle_name = NULL,
    last_name = 'Molina',
    updated_at = NOW()
WHERE id = 'e0997cb7-68df-41e6-923f-48107872d434';

-- Verify the update
SELECT id, first_name, middle_name, last_name, role
FROM user_profiles 
WHERE id = 'e0997cb7-68df-41e6-923f-48107872d434';
