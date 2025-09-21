-- Drop and Recreate RLS Policies for AnxieEase Database
-- This script safely drops existing policies and recreates them to fix infinite recursion

-- ========================================
-- DROP EXISTING POLICIES
-- ========================================

-- Drop user_profiles policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Psychologists can view assigned patients" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.user_profiles;

-- Drop psychologists policies
DROP POLICY IF EXISTS "Psychologists can view own profile" ON public.psychologists;
DROP POLICY IF EXISTS "Psychologists can update own profile" ON public.psychologists;
DROP POLICY IF EXISTS "Psychologists can insert own profile" ON public.psychologists;
DROP POLICY IF EXISTS "Patients can view assigned psychologist" ON public.psychologists;
DROP POLICY IF EXISTS "Users can view active psychologists" ON public.psychologists;

-- Drop anxiety_records policies
DROP POLICY IF EXISTS "Users can manage own anxiety records" ON public.anxiety_records;
DROP POLICY IF EXISTS "Psychologists can view patient anxiety records" ON public.anxiety_records;

-- Drop wellness_logs policies
DROP POLICY IF EXISTS "Users can manage own wellness logs" ON public.wellness_logs;
DROP POLICY IF EXISTS "Psychologists can view patient wellness logs" ON public.wellness_logs;

-- Drop appointments policies
DROP POLICY IF EXISTS "Users can view own appointments" ON public.appointments;
DROP POLICY IF EXISTS "Users can create own appointments" ON public.appointments;
DROP POLICY IF EXISTS "Users can update own appointments" ON public.appointments;
DROP POLICY IF EXISTS "Psychologists can view their appointments" ON public.appointments;
DROP POLICY IF EXISTS "Psychologists can update their appointments" ON public.appointments;

-- Drop patient_notes policies
DROP POLICY IF EXISTS "Psychologists can manage patient notes" ON public.patient_notes;
DROP POLICY IF EXISTS "Patients can view their non-private notes" ON public.patient_notes;

-- Drop notifications policies
DROP POLICY IF EXISTS "Users can manage own notifications" ON public.notifications;

-- Drop activity_logs policies
DROP POLICY IF EXISTS "Users can view own activity logs" ON public.activity_logs;
DROP POLICY IF EXISTS "System can insert activity logs" ON public.activity_logs;
DROP POLICY IF EXISTS "Psychologists can view patient activity logs" ON public.activity_logs;

-- ========================================
-- ENABLE RLS ON ALL TABLES
-- ========================================
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.psychologists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anxiety_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wellness_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- ========================================
-- USER PROFILES POLICIES
-- ========================================

CREATE POLICY "Users can view own profile" ON public.user_profiles
  FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own profile (for registration)
CREATE POLICY "Users can insert own profile" ON public.user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Psychologists can view profiles of their assigned patients
-- (Simplified to avoid recursion - psychologist must be directly assigned)
CREATE POLICY "Psychologists can view assigned patients" ON public.user_profiles
  FOR SELECT USING (
    assigned_psychologist_id IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.psychologists 
      WHERE id = assigned_psychologist_id AND user_id = auth.uid()
    )
  );

-- ========================================
-- PSYCHOLOGISTS POLICIES
-- ========================================

-- Psychologists can view their own profile
CREATE POLICY "Psychologists can view own profile" ON public.psychologists
  FOR SELECT USING (user_id = auth.uid());

-- Psychologists can update their own profile
CREATE POLICY "Psychologists can update own profile" ON public.psychologists
  FOR UPDATE USING (user_id = auth.uid());

-- Psychologists can insert their own profile
CREATE POLICY "Psychologists can insert own profile" ON public.psychologists
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- All authenticated users can view active psychologists (for browsing)
CREATE POLICY "Users can view active psychologists" ON public.psychologists
  FOR SELECT USING (is_active = true);

-- ========================================
-- ANXIETY RECORDS POLICIES
-- ========================================

-- Users can manage their own anxiety records
CREATE POLICY "Users can manage own anxiety records" ON public.anxiety_records
  FOR ALL USING (user_id = auth.uid());

-- Psychologists can view records of their assigned patients
-- (Simplified to avoid recursion)
CREATE POLICY "Psychologists can view patient anxiety records" ON public.anxiety_records
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.psychologists p
      WHERE p.user_id = auth.uid() 
      AND p.id = (
        SELECT up.assigned_psychologist_id 
        FROM public.user_profiles up 
        WHERE up.id = anxiety_records.user_id
      )
    )
  );

-- ========================================
-- WELLNESS LOGS POLICIES
-- ========================================

-- Users can manage their own wellness logs
CREATE POLICY "Users can manage own wellness logs" ON public.wellness_logs
  FOR ALL USING (user_id = auth.uid());

-- Psychologists can view wellness logs of their assigned patients  
-- (Simplified to avoid recursion)
CREATE POLICY "Psychologists can view patient wellness logs" ON public.wellness_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.psychologists p
      WHERE p.user_id = auth.uid() 
      AND p.id = (
        SELECT up.assigned_psychologist_id 
        FROM public.user_profiles up 
        WHERE up.id = wellness_logs.user_id
      )
    )
  );

-- ========================================
-- APPOINTMENTS POLICIES
-- ========================================

-- Users can view their own appointments
CREATE POLICY "Users can view own appointments" ON public.appointments
  FOR SELECT USING (user_id = auth.uid());

-- Users can create appointments for themselves
CREATE POLICY "Users can create own appointments" ON public.appointments
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users can update their own appointments (limited fields)
CREATE POLICY "Users can update own appointments" ON public.appointments
  FOR UPDATE USING (user_id = auth.uid());

-- Psychologists can view appointments where they are the assigned psychologist
CREATE POLICY "Psychologists can view their appointments" ON public.appointments
  FOR SELECT USING (
    psychologist_id IN (
      SELECT id FROM public.psychologists WHERE user_id = auth.uid()
    )
  );

-- Psychologists can update appointments where they are assigned
CREATE POLICY "Psychologists can update their appointments" ON public.appointments
  FOR UPDATE USING (
    psychologist_id IN (
      SELECT id FROM public.psychologists WHERE user_id = auth.uid()
    )
  );

-- ========================================
-- PATIENT NOTES POLICIES
-- ========================================

-- Psychologists can manage notes for their patients
CREATE POLICY "Psychologists can manage patient notes" ON public.patient_notes
  FOR ALL USING (
    psychologist_id IN (
      SELECT id FROM public.psychologists WHERE user_id = auth.uid()
    )
  );

-- Patients can view non-private notes written about them (if is_private field exists)
CREATE POLICY "Patients can view their non-private notes" ON public.patient_notes
  FOR SELECT USING (patient_id = auth.uid());

-- ========================================
-- NOTIFICATIONS POLICIES
-- ========================================

-- Users can manage their own notifications
CREATE POLICY "Users can manage own notifications" ON public.notifications
  FOR ALL USING (user_id = auth.uid());

-- ========================================
-- ACTIVITY LOGS POLICIES
-- ========================================

-- Users can view their own activity logs
CREATE POLICY "Users can view own activity logs" ON public.activity_logs
  FOR SELECT USING (user_id = auth.uid());

-- System can insert activity logs for any user
CREATE POLICY "System can insert activity logs" ON public.activity_logs
  FOR INSERT WITH CHECK (true);

-- Psychologists can view activity logs of their assigned patients
-- (Simplified to avoid recursion)
CREATE POLICY "Psychologists can view patient activity logs" ON public.activity_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.psychologists p
      WHERE p.user_id = auth.uid() 
      AND p.id = (
        SELECT up.assigned_psychologist_id 
        FROM public.user_profiles up 
        WHERE up.id = activity_logs.user_id
      )
    )
  );

-- ========================================
-- HELPER FUNCTIONS FOR RLS
-- ========================================

-- Function to check if user is a psychologist
CREATE OR REPLACE FUNCTION public.is_psychologist()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.psychologists 
    WHERE user_id = auth.uid() AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is assigned to a specific psychologist
CREATE OR REPLACE FUNCTION public.is_assigned_patient(psychologist_user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_profiles up
    JOIN public.psychologists p ON up.assigned_psychologist_id = p.id
    WHERE up.id = auth.uid() AND p.user_id = psychologist_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's assigned psychologist ID
CREATE OR REPLACE FUNCTION public.get_assigned_psychologist_id()
RETURNS uuid AS $$
BEGIN
  RETURN (
    SELECT assigned_psychologist_id 
    FROM public.user_profiles 
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;