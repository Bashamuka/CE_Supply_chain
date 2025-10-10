/*
  # Add INSERT policy for profiles table

  1. Changes
    - Add policy to allow users to insert their own profile during registration
    - This is necessary for the signup process to work correctly
  
  2. Security
    - Users can only insert a profile for themselves (auth.uid() = id)
    - The policy ensures users cannot create profiles for other users
*/

CREATE POLICY "Users can insert own profile"
  ON profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);
