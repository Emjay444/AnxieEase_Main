-- Add avatar_url column to user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Add a comment to the column
COMMENT ON COLUMN user_profiles.avatar_url IS 'URL to the user''s profile picture stored in Supabase storage';

-- Update any existing records to have NULL avatar_url (optional, should already be NULL)
-- UPDATE user_profiles SET avatar_url = NULL WHERE avatar_url IS NOT NULL;

-- Verify the column was added
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND column_name = 'avatar_url';