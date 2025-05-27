-- Direct creation of appointments table without using a function

-- Check if the table already exists and drop it if it does
DROP TABLE IF EXISTS public.appointments;

-- Create the appointments table
CREATE TABLE public.appointments (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  psychologist_id uuid REFERENCES public.psychologists(id) NOT NULL,
  appointment_date timestamp with time zone NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  response_message text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now()
);

-- Set up RLS (Row Level Security)
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- Create policy for users to view their own appointments
CREATE POLICY "Users can view their own appointments"
  ON public.appointments
  FOR SELECT
  USING (auth.uid() = user_id);

-- Create policy for users to insert their own appointments
CREATE POLICY "Users can insert their own appointments"
  ON public.appointments
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Create policy for users to update their own appointments
CREATE POLICY "Users can update their own appointments"
  ON public.appointments
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Create policy for psychologists to view appointments assigned to them
CREATE POLICY "Psychologists can view appointments assigned to them"
  ON public.appointments
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.psychologists 
    WHERE public.psychologists.id = psychologist_id 
    AND public.psychologists.user_id = auth.uid()
  ));

-- Create policy for psychologists to update appointments assigned to them
CREATE POLICY "Psychologists can update appointments assigned to them"
  ON public.appointments
  FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM public.psychologists 
    WHERE public.psychologists.id = psychologist_id 
    AND public.psychologists.user_id = auth.uid()
  ));

-- Create indexes for better performance
CREATE INDEX appointments_user_id_idx ON public.appointments(user_id);
CREATE INDEX appointments_psychologist_id_idx ON public.appointments(psychologist_id);
CREATE INDEX appointments_status_idx ON public.appointments(status);
CREATE INDEX appointments_appointment_date_idx ON public.appointments(appointment_date); 