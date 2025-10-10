/*
  # Create automatic profile creation trigger

  1. Changes
    - Create a function that automatically creates a profile when a new user signs up
    - Create a trigger that calls this function on user creation
    - Drop the existing INSERT policy since we'll use a trigger instead
  
  2. Security
    - Profiles are created automatically by the database trigger
    - Users cannot manually insert profiles, preventing security issues
*/

-- Drop the previously created INSERT policy
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- Create function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'employee')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
