# Supabase Database Schema Analysis

## Current Issues Identified

### 1. Duplicate User Management
You have both `auth.users` (Supabase Auth) and `public.users` tables, which creates confusion and potential data inconsistency.

**Problem:**
- `auth.users` is managed by Supabase Auth automatically
- `public.users` duplicates user information
- Foreign keys reference both tables inconsistently

### 2. Inconsistent Foreign Key References
- Most tables reference `auth.users(id)` 
- `patient_notes` references `public.users(id)`
- `appointments` doesn't reference users directly (missing user_id FK)

### 3. Missing Relationships
- No direct relationship between `appointments` and `auth.users`
- `psychologists` table references both `auth.users` and has its own ID system

## Recommended Database Structure

### Option 1: Use Only Supabase Auth (Recommended)

```sql
-- Remove public.users table entirely
-- Extend auth.users with a profiles table instead

CREATE TABLE public.user_profiles (
  id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name text,
  middle_name text,
  last_name text,
  contact_number text,
  emergency_contact text,
  birth_date date,
  gender text,
  role character varying NOT NULL DEFAULT 'patient',
  assigned_psychologist_id uuid,
  is_email_verified boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT user_profiles_assigned_psychologist_id_fkey 
    FOREIGN KEY (assigned_psychologist_id) REFERENCES public.psychologists(id)
);

-- Update psychologists table
CREATE TABLE public.psychologists (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  contact text,
  license_number text UNIQUE,
  sex text,
  avatar_url text,
  bio text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT psychologists_pkey PRIMARY KEY (id),
  CONSTRAINT psychologists_user_id_unique UNIQUE (user_id)
);

-- Update appointments table to include user_id
CREATE TABLE public.appointments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  psychologist_id uuid NOT NULL REFERENCES public.psychologists(id),
  appointment_date timestamp with time zone NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  response_message text,
  completion_notes text,
  completion_date timestamp with time zone,
  completed boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT appointments_pkey PRIMARY KEY (id)
);

-- Update patient_notes to reference auth.users
CREATE TABLE public.patient_notes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  psychologist_id uuid REFERENCES public.psychologists(id),
  note_content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT patient_notes_pkey PRIMARY KEY (id)
);
```

### Option 2: Use Public Users Only (Alternative)

If you prefer to manage users entirely in your public schema:

```sql
-- Remove all references to auth.users
-- Update all foreign keys to reference public.users(id)
-- Handle authentication separately
```

## Key Improvements Made

### 1. Single Source of Truth for Users
- Use `auth.users` as the primary user table
- Create `user_profiles` for additional user data
- Remove duplicate `public.users` table

### 2. Proper Relationships
- All user-related tables now properly reference `auth.users(id)`
- Added missing `user_id` to appointments table
- Added `psychologist_id` to patient_notes for better tracking

### 3. Better Data Integrity
- Added CASCADE deletes for cleanup
- Added UNIQUE constraints where needed
- Consistent naming conventions

### 4. Enhanced Functionality
- `patient_notes` now tracks which psychologist wrote the note
- `appointments` properly links users and psychologists
- `user_profiles` separates auth data from profile data

## Migration Strategy

1. **Backup existing data**
2. **Create new tables with proper structure**
3. **Migrate data from old tables to new structure**
4. **Update application code to use new schema**
5. **Drop old tables after verification**

## Row Level Security (RLS) Considerations

With this structure, you can implement proper RLS policies:

```sql
-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE anxiety_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
-- etc.

-- Example policies
CREATE POLICY "Users can view own profile" ON user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Psychologists can view assigned patients" ON user_profiles
  FOR SELECT USING (
    assigned_psychologist_id IN (
      SELECT id FROM psychologists WHERE user_id = auth.uid()
    )
  );
```

This structure provides better data integrity, clearer relationships, and easier maintenance.
