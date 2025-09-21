-- SQL function to create user profile during registration
-- This bypasses RLS restrictions and can be called from the client

-- Create a function that can be called by authenticated users to create their profile
CREATE OR REPLACE FUNCTION create_user_profile_on_signup()
RETURNS trigger AS $$
BEGIN
  -- This trigger automatically creates a user_profiles record when a user signs up
  INSERT INTO public.user_profiles (
    id,
    email,
    first_name,
    middle_name,
    last_name,
    role,
    created_at,
    updated_at,
    is_email_verified
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'middle_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
    'patient',
    NOW(),
    NOW(),
    NEW.email_confirmed_at IS NOT NULL
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger that fires when a new user is created in auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_user_profile_on_signup();

-- Also create a function that can be manually called to create missing profiles
CREATE OR REPLACE FUNCTION create_missing_user_profile(
  user_id UUID,
  user_email TEXT,
  first_name TEXT DEFAULT '',
  middle_name TEXT DEFAULT '',
  last_name TEXT DEFAULT '',
  birth_date TEXT DEFAULT NULL,
  contact_number TEXT DEFAULT '',
  emergency_contact TEXT DEFAULT '',
  gender TEXT DEFAULT ''
)
RETURNS void AS $$
BEGIN
  INSERT INTO public.user_profiles (
    id,
    email,
    first_name,
    middle_name,
    last_name,
    birth_date,
    contact_number,
    emergency_contact,
    gender,
    role,
    created_at,
    updated_at,
    is_email_verified
  )
  VALUES (
    user_id,
    user_email,
    first_name,
    middle_name,
    last_name,
    CASE WHEN birth_date IS NOT NULL AND birth_date != '' THEN birth_date::timestamp ELSE NULL END,
    contact_number,
    emergency_contact,
    gender,
    'patient',
    NOW(),
    NOW(),
    false
  )
  ON CONFLICT (id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    middle_name = EXCLUDED.middle_name,
    last_name = EXCLUDED.last_name,
    birth_date = EXCLUDED.birth_date,
    contact_number = EXCLUDED.contact_number,
    emergency_contact = EXCLUDED.emergency_contact,
    gender = EXCLUDED.gender,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION create_missing_user_profile TO authenticated;
