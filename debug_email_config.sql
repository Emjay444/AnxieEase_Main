-- Test script to check Supabase email configuration
-- Run this in your Supabase SQL Editor to verify email settings

-- Check recent auth attempts and email confirmation status (updated to include new test email)
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at,
  confirmation_sent_at,
  last_sign_in_at,
  phone_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data
FROM auth.users 
WHERE email LIKE '%mjmolina444%' OR email LIKE '%markmolina544%' OR email LIKE '%molinamark444%' OR email LIKE '%test%'
ORDER BY created_at DESC 
LIMIT 15;

-- Check if there are any email confirmation identities
SELECT 
  id,
  user_id,
  provider,
  identity_data,
  created_at,
  updated_at
FROM auth.identities 
WHERE user_id IN (
  SELECT id FROM auth.users 
  WHERE email LIKE '%mjmolina444%' OR email LIKE '%markmolina544%' OR email LIKE '%molinamark444%'
)
ORDER BY created_at DESC;

-- Note: Email configuration settings like enable_confirmations, site_url, 
-- and SMTP settings are not stored in the database but are configured 
-- in your Supabase Dashboard → Authentication → Settings
-- 
-- To debug email delivery issues, check:
-- 1. Supabase Dashboard → Authentication → Settings → Email
-- 2. Enable email confirmations should be ON
-- 3. Site URL should match your redirect URL (anxiease://verify)
-- 4. Email provider configuration (default SMTP vs custom)
-- 5. Check spam folder in email client