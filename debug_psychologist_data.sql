-- Debug script to check psychologist data in the database

-- Check if psychologists table exists and its structure
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'psychologists' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check existing psychologist records
SELECT 
    id,
    first_name,
    middle_name,
    last_name,
    CONCAT(first_name, ' ', COALESCE(middle_name || ' ', ''), last_name) as full_name,
    specialization,
    email,
    contact,
    bio,
    avatar_url,
    is_active,
    created_at
FROM public.psychologists
ORDER BY created_at DESC;

-- Check user profiles with assigned psychologist IDs
SELECT 
    up.id as user_id,
    up.first_name,
    up.last_name,
    up.assigned_psychologist_id,
    CONCAT(p.first_name, ' ', COALESCE(p.middle_name || ' ', ''), p.last_name) as psychologist_name
FROM public.user_profiles up
LEFT JOIN public.psychologists p ON up.assigned_psychologist_id = p.id
WHERE up.assigned_psychologist_id IS NOT NULL;

-- Check if there are any records in psychologists table at all
SELECT COUNT(*) as total_psychologists FROM public.psychologists;