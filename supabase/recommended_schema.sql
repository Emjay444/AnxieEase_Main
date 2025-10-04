-- Recommended Database Schema for AnxieEase
-- This schema uses Supabase Auth as the single source of truth for users

-- ========================================
-- 1. USER PROFILES TABLE
-- Extends auth.users with additional profile information
-- ========================================
CREATE TABLE public.user_profiles (
  id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name text,
  middle_name text,
  last_name text,
  contact_number text,
  emergency_contact text,
  birth_date date,
  sex text CHECK (sex IN ('male', 'female', 'other', 'prefer_not_to_say')),
  role character varying NOT NULL DEFAULT 'patient' CHECK (role IN ('patient', 'psychologist', 'admin')),
  assigned_psychologist_id uuid,
  is_email_verified boolean DEFAULT false,
  avatar_url text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_profiles_pkey PRIMARY KEY (id)
);

-- ========================================
-- 2. PSYCHOLOGISTS TABLE
-- Professional information for psychologists
-- ========================================
CREATE TABLE public.psychologists (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  license_number text UNIQUE NOT NULL,
  specializations text[],
  years_of_experience integer,
  education text,
  certifications text[],
  consultation_fee decimal(10,2),
  availability_schedule jsonb, -- Store weekly schedule as JSON
  is_active boolean DEFAULT true,
  is_verified boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT psychologists_pkey PRIMARY KEY (id),
  CONSTRAINT psychologists_user_id_unique UNIQUE (user_id)
);

-- Add foreign key constraint after psychologists table is created
ALTER TABLE public.user_profiles 
ADD CONSTRAINT user_profiles_assigned_psychologist_id_fkey 
FOREIGN KEY (assigned_psychologist_id) REFERENCES public.psychologists(id);

-- ========================================
-- 3. ANXIETY RECORDS TABLE
-- Track anxiety episodes and measurements
-- ========================================
CREATE TABLE public.anxiety_records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  severity_level character varying NOT NULL CHECK (
    severity_level IN ('mild', 'moderate', 'severe', 'unknown')
  ),
  heart_rate integer CHECK (heart_rate > 0 AND heart_rate < 300),
  triggers text[], -- Array of trigger factors
  symptoms text[], -- Array of symptoms experienced
  coping_methods_used text[], -- Array of coping strategies used
  source character varying DEFAULT 'app' CHECK (source IN ('app', 'wearable', 'manual')),
  is_manual boolean NOT NULL DEFAULT false,
  details text DEFAULT '',
  location_context text, -- Where the episode occurred
  duration_minutes integer, -- How long the episode lasted
  timestamp timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT anxiety_records_pkey PRIMARY KEY (id)
);

-- ========================================
-- 4. WELLNESS LOGS TABLE
-- Daily wellness tracking
-- ========================================
CREATE TABLE public.wellness_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date date NOT NULL,
  mood_score integer CHECK (mood_score >= 1 AND mood_score <= 10),
  stress_level double precision CHECK (stress_level >= 0 AND stress_level <= 10),
  energy_level integer CHECK (energy_level >= 1 AND energy_level <= 10),
  sleep_hours double precision CHECK (sleep_hours >= 0 AND sleep_hours <= 24),
  sleep_quality integer CHECK (sleep_quality >= 1 AND sleep_quality <= 5),
  feelings jsonb NOT NULL, -- Store as structured data
  symptoms jsonb, -- Physical/mental symptoms
  activities jsonb, -- Daily activities that might affect wellness
  journal text,
  gratitude_notes text,
  goals_achieved text[],
  medications_taken jsonb, -- Track medication adherence
  timestamp timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT wellness_logs_pkey PRIMARY KEY (id),
  CONSTRAINT wellness_logs_user_date_unique UNIQUE (user_id, date)
);

-- ========================================
-- 5. APPOINTMENTS TABLE
-- Manage appointments between users and psychologists
-- ========================================
CREATE TABLE public.appointments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  psychologist_id uuid NOT NULL REFERENCES public.psychologists(id),
  appointment_date timestamp with time zone NOT NULL,
  duration_minutes integer DEFAULT 60,
  appointment_type character varying DEFAULT 'consultation' CHECK (
    appointment_type IN ('consultation', 'therapy', 'follow_up', 'assessment')
  ),
  status text NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'confirmed', 'cancelled', 'completed', 'no_show')
  ),
  reason text NOT NULL,
  urgency_level character varying DEFAULT 'normal' CHECK (
    urgency_level IN ('low', 'normal', 'high', 'emergency')
  ),
  preferred_format character varying DEFAULT 'video' CHECK (
    preferred_format IN ('video', 'audio', 'in_person', 'chat')
  ),
  response_message text,
  completion_notes text,
  completion_date timestamp with time zone,
  completed boolean DEFAULT false,
  reminder_sent boolean DEFAULT false,
  meeting_link text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT appointments_pkey PRIMARY KEY (id)
);

-- ========================================
-- 6. PATIENT NOTES TABLE
-- Clinical notes by psychologists about their patients
-- ========================================
CREATE TABLE public.patient_notes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  psychologist_id uuid NOT NULL REFERENCES public.psychologists(id),
  appointment_id uuid REFERENCES public.appointments(id),
  note_type character varying DEFAULT 'session' CHECK (
    note_type IN ('session', 'assessment', 'treatment_plan', 'progress', 'medication', 'other')
  ),
  title text,
  note_content text NOT NULL,
  tags text[], -- For categorization and search
  is_private boolean DEFAULT true, -- Whether patient can see this note
  risk_assessment jsonb, -- Structured risk assessment data
  treatment_goals text[],
  homework_assigned text,
  next_session_focus text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT patient_notes_pkey PRIMARY KEY (id)
);

-- ========================================
-- 7. NOTIFICATIONS TABLE
-- System notifications for users
-- ========================================
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  message text NOT NULL,
  type character varying NOT NULL CHECK (
    type IN ('appointment', 'reminder', 'wellness', 'system', 'emergency', 'medication')
  ),
  priority character varying DEFAULT 'normal' CHECK (
    priority IN ('low', 'normal', 'high', 'urgent')
  ),
  related_screen text,
  related_id uuid,
  action_required boolean DEFAULT false,
  action_url text,
  read boolean DEFAULT false,
  read_at timestamp with time zone,
  scheduled_for timestamp with time zone, -- For scheduled notifications
  expires_at timestamp with time zone, -- When notification becomes irrelevant
  sent_via character varying[] DEFAULT ARRAY['app'], -- Methods used to send
  created_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT notifications_pkey PRIMARY KEY (id)
);

-- ========================================
-- 8. ACTIVITY LOGS TABLE
-- Track user actions for analytics and debugging
-- ========================================
CREATE TABLE public.activity_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id uuid, -- Track user sessions
  action text NOT NULL,
  screen text, -- Which screen/page
  feature_used text, -- Specific feature
  details jsonb, -- Structured additional data
  user_agent text,
  ip_address inet,
  device_info jsonb,
  performance_metrics jsonb, -- App performance data
  timestamp timestamp with time zone DEFAULT now(),
  CONSTRAINT activity_logs_pkey PRIMARY KEY (id)
);

-- ========================================
-- 9. EMERGENCY CONTACTS TABLE
-- Store emergency contact information
-- ========================================
CREATE TABLE public.emergency_contacts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  relationship text NOT NULL,
  phone_number text NOT NULL,
  email text,
  address text,
  is_primary boolean DEFAULT false,
  can_be_contacted_anytime boolean DEFAULT true,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT emergency_contacts_pkey PRIMARY KEY (id)
);

-- ========================================
-- 10. COPING STRATEGIES TABLE
-- Store and track coping strategies
-- ========================================
CREATE TABLE public.coping_strategies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  category character varying CHECK (
    category IN ('breathing', 'grounding', 'physical', 'cognitive', 'social', 'creative', 'other')
  ),
  instructions text,
  duration_minutes integer,
  effectiveness_rating integer CHECK (effectiveness_rating >= 1 AND effectiveness_rating <= 5),
  times_used integer DEFAULT 0,
  is_favorite boolean DEFAULT false,
  is_custom boolean DEFAULT true, -- User-created vs system-provided
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT coping_strategies_pkey PRIMARY KEY (id)
);

-- ========================================
-- INDEXES FOR PERFORMANCE
-- ========================================

-- User profiles
CREATE INDEX idx_user_profiles_role ON public.user_profiles(role);
CREATE INDEX idx_user_profiles_psychologist ON public.user_profiles(assigned_psychologist_id);

-- Anxiety records
CREATE INDEX idx_anxiety_records_user_timestamp ON public.anxiety_records(user_id, timestamp DESC);
CREATE INDEX idx_anxiety_records_severity ON public.anxiety_records(severity_level);
CREATE INDEX idx_anxiety_records_source ON public.anxiety_records(source);

-- Wellness logs
CREATE INDEX idx_wellness_logs_user_date ON public.wellness_logs(user_id, date DESC);

-- Appointments
CREATE INDEX idx_appointments_user ON public.appointments(user_id);
CREATE INDEX idx_appointments_psychologist ON public.appointments(psychologist_id);
CREATE INDEX idx_appointments_date ON public.appointments(appointment_date);
CREATE INDEX idx_appointments_status ON public.appointments(status);

-- Patient notes
CREATE INDEX idx_patient_notes_patient ON public.patient_notes(patient_id);
CREATE INDEX idx_patient_notes_psychologist ON public.patient_notes(psychologist_id);
CREATE INDEX idx_patient_notes_appointment ON public.patient_notes(appointment_id);

-- Notifications
CREATE INDEX idx_notifications_user_read ON public.notifications(user_id, read);
CREATE INDEX idx_notifications_type ON public.notifications(type);
CREATE INDEX idx_notifications_created ON public.notifications(created_at DESC);

-- Activity logs
CREATE INDEX idx_activity_logs_user_timestamp ON public.activity_logs(user_id, timestamp DESC);
CREATE INDEX idx_activity_logs_action ON public.activity_logs(action);

-- ========================================
-- FUNCTIONS AND TRIGGERS
-- ========================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language plpgsql;

-- Add updated_at triggers to relevant tables
CREATE TRIGGER update_user_profiles_updated_at 
  BEFORE UPDATE ON public.user_profiles 
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_psychologists_updated_at 
  BEFORE UPDATE ON public.psychologists 
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_appointments_updated_at 
  BEFORE UPDATE ON public.appointments 
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_patient_notes_updated_at 
  BEFORE UPDATE ON public.patient_notes 
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_emergency_contacts_updated_at 
  BEFORE UPDATE ON public.emergency_contacts 
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_coping_strategies_updated_at 
  BEFORE UPDATE ON public.coping_strategies 
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
