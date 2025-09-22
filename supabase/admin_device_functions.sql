-- Admin Device Management Functions for AnxieEase
-- Run these in your Supabase SQL editor to enable admin device control

-- Function to assign device to user (admin only)
CREATE OR REPLACE FUNCTION assign_device_to_user(
  p_device_id TEXT,
  p_user_id UUID,
  p_expires_at TIMESTAMPTZ DEFAULT NULL,
  p_admin_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  device_record JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  existing_device RECORD;
  new_device_record RECORD;
BEGIN
  -- Check if device is already assigned to someone else
  SELECT * INTO existing_device 
  FROM wearable_devices 
  WHERE device_id = p_device_id 
    AND user_id IS NOT NULL 
    AND user_id != p_user_id
    AND (assignment_status = 'assigned' OR assignment_status = 'active');

  IF FOUND THEN
    RETURN QUERY SELECT 
      FALSE, 
      'Device is already assigned to another user', 
      NULL::JSONB;
    RETURN;
  END IF;

  -- Insert or update device record
  INSERT INTO wearable_devices (
    device_id,
    device_name,
    user_id,
    linked_at,
    assigned_at,
    expires_at,
    assignment_status,
    session_status,
    admin_notes,
    is_active,
    last_seen_at
  ) VALUES (
    p_device_id,
    'AnxieEase Wearable Device',
    p_user_id,
    NOW(),
    NOW(),
    p_expires_at,
    'assigned',
    'pending',
    p_admin_notes,
    TRUE,
    NOW()
  )
  ON CONFLICT (device_id) 
  DO UPDATE SET
    user_id = p_user_id,
    assigned_at = NOW(),
    expires_at = p_expires_at,
    assignment_status = 'assigned',
    session_status = 'pending',
    admin_notes = p_admin_notes,
    is_active = TRUE,
    last_seen_at = NOW()
  RETURNING * INTO new_device_record;

  -- Return success
  RETURN QUERY SELECT 
    TRUE, 
    'Device assigned successfully', 
    to_jsonb(new_device_record);
END;
$$;

-- Function to release device assignment (admin only)
CREATE OR REPLACE FUNCTION release_device_assignment(
  p_device_id TEXT
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update device to release assignment
  UPDATE wearable_devices 
  SET 
    user_id = NULL,
    assignment_status = 'available',
    session_status = 'completed',
    assigned_at = NULL,
    expires_at = NULL,
    admin_notes = NULL
  WHERE device_id = p_device_id;

  IF FOUND THEN
    RETURN QUERY SELECT TRUE, 'Device released successfully';
  ELSE
    RETURN QUERY SELECT FALSE, 'Device not found';
  END IF;
END;
$$;

-- Function to update session status (called by mobile app)
CREATE OR REPLACE FUNCTION update_session_status(
  p_device_id TEXT,
  p_session_status TEXT,
  p_session_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_id UUID;
BEGIN
  -- Get current authenticated user
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'User not authenticated';
    RETURN;
  END IF;

  -- Update session status for current user's device
  UPDATE wearable_devices 
  SET 
    session_status = p_session_status,
    session_notes = p_session_notes,
    last_seen_at = NOW()
  WHERE device_id = p_device_id 
    AND user_id = current_user_id;

  IF FOUND THEN
    RETURN QUERY SELECT TRUE, 'Session status updated';
  ELSE
    RETURN QUERY SELECT FALSE, 'Device not assigned to current user';
  END IF;
END;
$$;

-- Function to get device assignment status for admin dashboard
CREATE OR REPLACE FUNCTION get_device_assignment_status(
  p_device_id TEXT
)
RETURNS TABLE (
  device_id TEXT,
  user_id UUID,
  user_name TEXT,
  user_email TEXT,
  assignment_status TEXT,
  session_status TEXT,
  assigned_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  admin_notes TEXT,
  session_notes TEXT,
  last_seen_at TIMESTAMPTZ,
  is_expired BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    wd.device_id,
    wd.user_id,
    p.full_name as user_name,
    au.email as user_email,
    wd.assignment_status,
    wd.session_status,
    wd.assigned_at,
    wd.expires_at,
    wd.admin_notes,
    wd.session_notes,
    wd.last_seen_at,
    CASE 
      WHEN wd.expires_at IS NOT NULL AND wd.expires_at < NOW() THEN TRUE
      ELSE FALSE
    END as is_expired
  FROM wearable_devices wd
  LEFT JOIN profiles p ON wd.user_id = p.id
  LEFT JOIN auth.users au ON wd.user_id = au.id
  WHERE wd.device_id = p_device_id;
END;
$$;

-- Function to list all users for admin dropdown
CREATE OR REPLACE FUNCTION get_users_for_admin()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    au.email,
    p.created_at
  FROM profiles p
  JOIN auth.users au ON p.id = au.id
  WHERE au.email_confirmed_at IS NOT NULL
  ORDER BY p.full_name;
END;
$$;

-- Function to get device usage history
CREATE OR REPLACE FUNCTION get_device_usage_history(
  p_device_id TEXT,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  user_name TEXT,
  user_email TEXT,
  assigned_at TIMESTAMPTZ,
  session_duration INTERVAL,
  session_status TEXT,
  admin_notes TEXT,
  session_notes TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.full_name as user_name,
    au.email as user_email,
    wd.assigned_at,
    CASE 
      WHEN wd.session_status = 'completed' AND wd.assigned_at IS NOT NULL 
      THEN wd.last_seen_at - wd.assigned_at
      ELSE NULL
    END as session_duration,
    wd.session_status,
    wd.admin_notes,
    wd.session_notes
  FROM wearable_devices wd
  LEFT JOIN profiles p ON wd.user_id = p.id
  LEFT JOIN auth.users au ON wd.user_id = au.id
  WHERE wd.device_id = p_device_id
    AND wd.assigned_at IS NOT NULL
  ORDER BY wd.assigned_at DESC
  LIMIT p_limit;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION assign_device_to_user TO authenticated;
GRANT EXECUTE ON FUNCTION release_device_assignment TO authenticated;
GRANT EXECUTE ON FUNCTION update_session_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_device_assignment_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_users_for_admin TO authenticated;
GRANT EXECUTE ON FUNCTION get_device_usage_history TO authenticated;

-- Create admin role and policy (optional - for enhanced security)
-- You can create an admin role and restrict some functions to admin users only

COMMENT ON FUNCTION assign_device_to_user IS 'Admin function to assign AnxieEase device to a user for testing';
COMMENT ON FUNCTION release_device_assignment IS 'Admin function to release device assignment';
COMMENT ON FUNCTION update_session_status IS 'App function to update session status during testing';
COMMENT ON FUNCTION get_device_assignment_status IS 'Get current device assignment status for admin dashboard';
COMMENT ON FUNCTION get_users_for_admin IS 'Get list of users for admin device assignment dropdown';
COMMENT ON FUNCTION get_device_usage_history IS 'Get device usage history for admin dashboard';