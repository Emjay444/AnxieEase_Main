-- Admin-only device assignment model for public.wearable_devices
--
-- Live columns (confirmed 2026-06-27 via PostgREST schema introspection
-- against pglfqtwjithjalwopcdm): device_id, device_name, user_id,
-- baseline_hr, linked_at, baseline_updated_at, is_active,
-- firmware_version, battery_level, last_seen_at.
-- Deliberately does NOT reference user_profiles or columns like
-- assignment_status/session_status/assigned_at/expires_at/session_notes/
-- status/is_primary -- none of those exist on this table.
--
-- Run this in the Supabase SQL editor for the live project. Safe to
-- re-run: drops whatever policies currently exist on this table first.

ALTER TABLE public.wearable_devices ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'wearable_devices'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.wearable_devices', pol.policyname);
  END LOOP;
END $$;

-- Admin check: true for admins and for psychologists granted admin access
-- (both are represented by a row in admin_profiles). SECURITY DEFINER so
-- it can't be defeated by RLS on admin_profiles itself. Named uniquely so
-- it never collides with the unrelated, never-applied public.is_admin()
-- in supabase/admin_device_functions.sql / device_rls_policies.sql,
-- which reference a nonexistent user_profiles table -- do not run those
-- two files against this database.
CREATE OR REPLACE FUNCTION public.is_wearable_device_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_profiles ap WHERE ap.id = auth.uid()
  );
$$;

-- SELECT: patients see only their own assigned device; admins see all.
CREATE POLICY "wearable_devices_select" ON public.wearable_devices
  FOR SELECT USING (
    user_id = auth.uid() OR public.is_wearable_device_admin()
  );

-- INSERT: admin only. Patients can never register/claim a device row.
CREATE POLICY "wearable_devices_insert_admin_only" ON public.wearable_devices
  FOR INSERT WITH CHECK (
    public.is_wearable_device_admin()
  );

-- UPDATE: admin only. Patients cannot update anything on this table,
-- including their own row (no user_id, no battery_level, no baseline
-- mirror -- baseline writes go to baseline_heart_rates instead).
CREATE POLICY "wearable_devices_update_admin_only" ON public.wearable_devices
  FOR UPDATE USING (
    public.is_wearable_device_admin()
  ) WITH CHECK (
    public.is_wearable_device_admin()
  );

-- DELETE: admin only.
CREATE POLICY "wearable_devices_delete_admin_only" ON public.wearable_devices
  FOR DELETE USING (
    public.is_wearable_device_admin()
  );
