-- Missing RLS Policies for Device and Baseline Data
-- Add these policies to ensure proper user data separation

-- ========================================
-- ENABLE RLS ON DEVICE-RELATED TABLES
-- ========================================
ALTER TABLE public.wearable_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.baseline_heart_rates ENABLE ROW LEVEL SECURITY;

-- ========================================
-- WEARABLE DEVICES POLICIES
-- ========================================

-- Users can only view devices assigned to them
CREATE POLICY "Users can view assigned devices" ON public.wearable_devices
    FOR SELECT USING (
        user_id = auth.uid() OR 
        assignment_status = 'available'
    );

-- Users can update session status of their assigned devices  
CREATE POLICY "Users can update own device sessions" ON public.wearable_devices
    FOR UPDATE USING (user_id = auth.uid());

-- Admin functions can manage all devices (for admin assignment system)
-- This allows the admin functions to work while maintaining user separation
CREATE POLICY "Admin functions can manage devices" ON public.wearable_devices
    FOR ALL USING (
        -- Allow if user has admin role or is using admin functions
        (auth.jwt() ->> 'role') = 'admin' OR
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    );

-- System can insert new devices (for device registration)
CREATE POLICY "System can register new devices" ON public.wearable_devices
    FOR INSERT WITH CHECK (true);

-- ========================================
-- BASELINE HEART RATES POLICIES  
-- ========================================

-- Users can only access their own baseline data
CREATE POLICY "Users can manage own baselines" ON public.baseline_heart_rates
    FOR ALL USING (user_id = auth.uid());

-- Psychologists can view baseline data of their assigned patients
CREATE POLICY "Psychologists can view patient baselines" ON public.baseline_heart_rates
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.psychologists p
            WHERE p.user_id = auth.uid() 
            AND p.id = (
                SELECT up.assigned_psychologist_id 
                FROM public.user_profiles up 
                WHERE up.id = baseline_heart_rates.user_id
            )
        )
    );

-- ========================================
-- UPDATED POLICIES FOR BETTER ADMIN SUPPORT
-- ========================================

-- Drop and recreate more permissive device policies for admin system
DROP POLICY IF EXISTS "Users can view assigned devices" ON public.wearable_devices;
DROP POLICY IF EXISTS "Users can update own device sessions" ON public.wearable_devices;
DROP POLICY IF EXISTS "Admin functions can manage devices" ON public.wearable_devices;
DROP POLICY IF EXISTS "System can register new devices" ON public.wearable_devices;

-- More comprehensive device policies
CREATE POLICY "Device access policy" ON public.wearable_devices
    FOR ALL USING (
        -- Users can access devices assigned to them
        user_id = auth.uid() OR
        -- Available devices can be viewed by anyone (for assignment)
        assignment_status = 'available' OR
        -- Admin users can access all devices
        (auth.jwt() ->> 'role') = 'admin' OR
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
        -- Allow admin functions to work (they use SECURITY DEFINER)
        current_setting('role', true) = 'supabase_admin'
    );

-- ========================================
-- VERIFY POLICIES ARE WORKING
-- ========================================

-- Test query to verify baseline separation (run as different users)
-- This should only return baselines for the current user
SELECT 
    user_id,
    device_id, 
    baseline_hr,
    recording_start_time,
    CASE 
        WHEN user_id = auth.uid() THEN 'Own data ✓'
        ELSE 'Other user data ❌'
    END as data_ownership
FROM baseline_heart_rates 
ORDER BY recording_start_time DESC;

-- Test query to verify device assignment separation
-- Users should only see their assigned devices or available devices
SELECT 
    device_id,
    user_id,
    assignment_status,
    session_status,
    CASE 
        WHEN user_id = auth.uid() THEN 'Own device ✓'
        WHEN assignment_status = 'available' THEN 'Available device ✓'
        WHEN user_id IS NULL THEN 'Unassigned device ✓'
        ELSE 'Other user device ❌'
    END as access_status
FROM wearable_devices
ORDER BY device_id;

-- ========================================
-- ADMIN HELPER FUNCTIONS
-- ========================================

-- Function to check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
    RETURN (
        (auth.jwt() ->> 'role') = 'admin' OR
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
        -- Check if user has admin flag in user_profiles (if you add this field)
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to safely get user device assignment
CREATE OR REPLACE FUNCTION public.get_user_device_assignment(p_user_id uuid)
RETURNS TABLE (
    device_id text,
    assignment_status text,
    session_status text,
    assigned_at timestamptz,
    expires_at timestamptz
) AS $$
BEGIN
    -- Only return device info if user has access
    RETURN QUERY
    SELECT 
        wd.device_id,
        wd.assignment_status,
        wd.session_status,
        wd.assigned_at,
        wd.expires_at
    FROM wearable_devices wd
    WHERE wd.user_id = p_user_id
    AND (
        -- User requesting their own data
        p_user_id = auth.uid() OR
        -- Admin user
        public.is_admin() OR
        -- Psychologist accessing patient data
        EXISTS (
            SELECT 1 FROM public.psychologists p
            WHERE p.user_id = auth.uid() 
            AND p.id = (
                SELECT up.assigned_psychologist_id 
                FROM public.user_profiles up 
                WHERE up.id = p_user_id
            )
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON POLICY "Device access policy" ON public.wearable_devices IS 
'Comprehensive device access policy supporting user isolation, admin management, and psychologist access';

COMMENT ON POLICY "Users can manage own baselines" ON public.baseline_heart_rates IS
'Users can only access baseline heart rate data they recorded themselves';

COMMENT ON POLICY "Psychologists can view patient baselines" ON public.baseline_heart_rates IS  
'Psychologists can view baseline data for their assigned patients only';