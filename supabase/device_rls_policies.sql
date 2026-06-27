-- Missing RLS Policies for Device and Baseline Data
-- Add these policies to ensure proper user data separation

-- ========================================
-- ADMIN HELPER FUNCTION (defined first: policies below reference it,
-- and CREATE POLICY resolves function calls immediately, unlike plpgsql
-- function bodies which resolve at call time)
-- ========================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
    RETURN (
        (auth.jwt() ->> 'role') = 'admin' OR
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' OR
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
DROP POLICY IF EXISTS "Device access policy" ON public.wearable_devices;

-- SELECT: a user can see their own device, any unclaimed/available device
-- (needed to discover a device before pairing with it), or every device if
-- they are an admin.
CREATE POLICY "Device select policy" ON public.wearable_devices
    FOR SELECT USING (
        user_id = auth.uid() OR
        assignment_status = 'available' OR
        public.is_admin()
    );

-- INSERT: a user may only register a brand-new device row under their own
-- user_id (first-time pairing) or leave it unassigned. Admins may insert
-- anything (e.g. pre-registering a device with no owner yet).
CREATE POLICY "Device insert policy" ON public.wearable_devices
    FOR INSERT WITH CHECK (
        user_id = auth.uid() OR
        user_id IS NULL OR
        public.is_admin()
    );

-- UPDATE: this is the policy that previously allowed device hijacking.
-- USING controls which existing rows can be targeted: a user's own device,
-- OR a currently-available/unclaimed device (this is what lib/services/
-- device_service.dart's linkDevice() relies on for first-time pairing --
-- the "approved patient self-claim flow"). WITH CHECK controls what the
-- row can become afterwards: the user may only set themselves as owner or
-- release it back to unowned (user_id = NULL, used by unlinkDevice()).
-- Critically, WITH CHECK no longer allows leaving an updated row owned by
-- someone other than the caller, which is what let any authenticated user
-- claim another user's "available" device for themselves.
CREATE POLICY "Device update policy" ON public.wearable_devices
    FOR UPDATE USING (
        user_id = auth.uid() OR
        assignment_status = 'available' OR
        public.is_admin()
    ) WITH CHECK (
        user_id = auth.uid() OR
        user_id IS NULL OR
        public.is_admin()
    );

-- DELETE: admin only. No current end-user flow deletes a device row, and
-- the previous FOR ALL policy let anyone delete any "available" device.
CREATE POLICY "Device delete policy" ON public.wearable_devices
    FOR DELETE USING (
        public.is_admin()
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
-- (public.is_admin() now lives at the top of this file -- moved there so
-- the policies above can reference it)
-- ========================================

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

COMMENT ON POLICY "Device select policy" ON public.wearable_devices IS
'Users see their own device, available/unclaimed devices, or all devices if admin';
COMMENT ON POLICY "Device insert policy" ON public.wearable_devices IS
'Users may register a new device only under their own user_id (or unassigned); admins may insert any row';
COMMENT ON POLICY "Device update policy" ON public.wearable_devices IS
'Users may update their own device or claim an available device for themselves, but can never assign it to someone else';
COMMENT ON POLICY "Device delete policy" ON public.wearable_devices IS
'Only admins may delete a device row';

COMMENT ON POLICY "Users can manage own baselines" ON public.baseline_heart_rates IS
'Users can only access baseline heart rate data they recorded themselves';

COMMENT ON POLICY "Psychologists can view patient baselines" ON public.baseline_heart_rates IS  
'Psychologists can view baseline data for their assigned patients only';