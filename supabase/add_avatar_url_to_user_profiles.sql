-- Migration: Ensure avatar_url column exists on user_profiles
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS avatar_url text;

-- Optional: If you want a default placeholder you could run:
-- UPDATE public.user_profiles SET avatar_url = 'https://your-cdn/placeholder.png' WHERE avatar_url IS NULL;