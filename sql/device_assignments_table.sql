-- Enhanced wearable_devices table for admin-controlled device assignments
-- Add these columns to your existing wearable_devices table

-- Add admin management columns to existing wearable_devices table
ALTER TABLE public.wearable_devices 
ADD COLUMN IF NOT EXISTS assigned_by UUID REFERENCES auth.users(id), -- Admin who assigned
ADD COLUMN IF NOT EXISTS assignment_status TEXT DEFAULT 'available', -- 'available', 'assigned', 'active', 'completed'
ADD COLUMN IF NOT EXISTS session_status TEXT DEFAULT 'idle', -- 'idle', 'pending', 'in_progress', 'completed'
ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS admin_notes TEXT,
ADD COLUMN IF NOT EXISTS session_notes TEXT;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_wearable_devices_assignment_status 
ON public.wearable_devices(assignment_status);

CREATE INDEX IF NOT EXISTS idx_wearable_devices_assigned_by 
ON public.wearable_devices(assigned_by);

-- Update existing RLS policies if they exist, or create new ones
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own devices" ON wearable_devices;
DROP POLICY IF EXISTS "Users can update own devices" ON wearable_devices;
DROP POLICY IF EXISTS "Admins can manage all devices" ON wearable_devices;

-- Enable RLS
ALTER TABLE wearable_devices ENABLE ROW LEVEL SECURITY;

-- Users can only see devices assigned to them
CREATE POLICY "Users can view assigned devices" ON wearable_devices
    FOR SELECT USING (
        auth.uid() = user_id OR 
        assignment_status = 'available'
    );

-- Users can update their own device session status
CREATE POLICY "Users can update own device sessions" ON wearable_devices
    FOR UPDATE USING (auth.uid() = user_id);

-- Admins can manage all devices
CREATE POLICY "Admins can manage all devices" ON wearable_devices
    FOR ALL USING (
        (auth.jwt() ->> 'role') = 'admin' OR
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

-- Function to assign device to user (for admin use)
CREATE OR REPLACE FUNCTION assign_device_to_user(
    p_device_id TEXT,
    p_user_id UUID,
    p_expires_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if device exists and is available
    IF NOT EXISTS (
        SELECT 1 FROM wearable_devices 
        WHERE device_id = p_device_id 
        AND (assignment_status = 'available' OR assignment_status IS NULL)
    ) THEN
        RAISE EXCEPTION 'Device not available for assignment';
    END IF;
    
    -- Assign device to user
    UPDATE wearable_devices 
    SET 
        user_id = p_user_id,
        assigned_by = auth.uid(),
        assignment_status = 'assigned',
        session_status = 'pending',
        assigned_at = NOW(),
        expires_at = p_expires_at,
        admin_notes = p_admin_notes,
        linked_at = NOW(),
        is_active = true,
        updated_at = NOW()
    WHERE device_id = p_device_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to release device assignment
CREATE OR REPLACE FUNCTION release_device_assignment(
    p_device_id TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE wearable_devices 
    SET 
        user_id = NULL,
        assignment_status = 'available',
        session_status = 'idle',
        linked_at = NULL,
        is_active = false,
        session_notes = NULL,
        updated_at = NOW()
    WHERE device_id = p_device_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update session status (for mobile app)
CREATE OR REPLACE FUNCTION update_session_status(
    p_device_id TEXT,
    p_session_status TEXT,
    p_session_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Only allow user to update their own device
    IF NOT EXISTS (
        SELECT 1 FROM wearable_devices 
        WHERE device_id = p_device_id 
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Device not assigned to current user';
    END IF;
    
    UPDATE wearable_devices 
    SET 
        session_status = p_session_status,
        session_notes = p_session_notes,
        last_seen_at = NOW(),
        updated_at = NOW()
    WHERE device_id = p_device_id AND user_id = auth.uid();
    
    -- If session is completed, mark assignment as completed
    IF p_session_status = 'completed' THEN
        UPDATE wearable_devices 
        SET assignment_status = 'completed'
        WHERE device_id = p_device_id AND user_id = auth.uid();
    ELSIF p_session_status = 'in_progress' THEN
        UPDATE wearable_devices 
        SET assignment_status = 'active'
        WHERE device_id = p_device_id AND user_id = auth.uid();
    END IF;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the main testing device if it doesn't exist
INSERT INTO wearable_devices (
    device_id, 
    device_name, 
    assignment_status,
    session_status,
    is_active,
    created_at
) VALUES (
    'AnxieEase001',
    'AnxieEase Testing Device',
    'available',
    'idle',
    false,
    NOW()
) ON CONFLICT (device_id) DO UPDATE SET
    assignment_status = COALESCE(wearable_devices.assignment_status, 'available'),
    session_status = COALESCE(wearable_devices.session_status, 'idle');

-- Example usage:
-- To assign device: SELECT assign_device_to_user('AnxieEase001', 'user-uuid', NOW() + INTERVAL '2 hours', 'Testing session');
-- To release device: SELECT release_device_assignment('AnxieEase001');
-- To update session: SELECT update_session_status('AnxieEase001', 'in_progress', 'Started testing');