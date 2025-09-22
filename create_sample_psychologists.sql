-- Create sample psychologist records
-- Run this in your Supabase SQL editor if no psychologists exist

INSERT INTO public.psychologists (
    id,
    first_name,
    middle_name,
    last_name,
    specialization,
    email,
    contact,
    bio,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    'psy-001',
    'Dr. Sarah',
    'Marie',
    'Johnson',
    'Clinical Psychologist, Anxiety Specialist',
    'sarah.johnson@anxiease.com',
    '09122223123',
    'Dr. Sarah Johnson is a licensed clinical psychologist with over 15 years of experience specializing in anxiety disorders, panic attacks, and stress management.',
    true,
    NOW(),
    NOW()
),
(
    'psy-002',
    'Dr. Michael',
    'James',
    'Chen',
    'Cognitive Behavioral Therapist',
    'michael.chen@anxiease.com',
    '09123334567',
    'Dr. Michael Chen specializes in cognitive behavioral therapy and has extensive experience helping patients manage anxiety through evidence-based techniques.',
    true,
    NOW(),
    NOW()
);

-- Assign the first psychologist to your current user (update with your actual user ID)
-- You can get your user ID from the auth.users table or your app
UPDATE public.user_profiles 
SET assigned_psychologist_id = 'psy-001'
WHERE id = auth.uid();  -- This will update for the currently authenticated user