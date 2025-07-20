/*
  # Initial Schema for Flood Rehabilitation Project

  1. New Tables
    - `users`
      - `id` (uuid, primary key)
      - `name` (text)
      - `email` (text, unique)
      - `role` (text) - 'refugee' or 'volunteer'
      - `age` (integer)
      - `contact` (text)
      - `address` (text, nullable)
      - `needs` (text, nullable)
      - `skills` (text, nullable)
      - `availability` (text, nullable)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

    - `camps`
      - `id` (uuid, primary key)
      - `name` (text)
      - `beds` (integer)
      - `original_beds` (integer)
      - `resources` (text array)
      - `contact` (text, nullable)
      - `ambulance` (text)
      - `added_by` (uuid, foreign key to users)
      - `type` (text) - 'default' or 'volunteer-added'
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

    - `camp_selections`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to users)
      - `camp_id` (uuid, foreign key to camps)
      - `status` (text) - 'active' or 'cancelled'
      - `selected_at` (timestamp)
      - `cancelled_at` (timestamp, nullable)

    - `volunteer_assignments`
      - `id` (uuid, primary key)
      - `volunteer_id` (uuid, foreign key to users)
      - `camp_id` (uuid, foreign key to camps)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users to manage their own data
    - Add policies for volunteers to manage camps
*/

-- Create users table
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text UNIQUE NOT NULL,
  role text NOT NULL CHECK (role IN ('refugee', 'volunteer')),
  age integer NOT NULL,
  contact text NOT NULL,
  address text,
  needs text,
  skills text,
  availability text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create camps table
CREATE TABLE IF NOT EXISTS camps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  beds integer NOT NULL DEFAULT 0,
  original_beds integer NOT NULL DEFAULT 0,
  resources text[] DEFAULT '{}',
  contact text,
  ambulance text DEFAULT 'No',
  added_by uuid REFERENCES users(id),
  type text DEFAULT 'default' CHECK (type IN ('default', 'volunteer-added')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create camp_selections table
CREATE TABLE IF NOT EXISTS camp_selections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  camp_id uuid NOT NULL REFERENCES camps(id) ON DELETE CASCADE,
  status text DEFAULT 'active' CHECK (status IN ('active', 'cancelled')),
  selected_at timestamptz DEFAULT now(),
  cancelled_at timestamptz,
  UNIQUE(user_id, status) DEFERRABLE INITIALLY DEFERRED
);

-- Create volunteer_assignments table
CREATE TABLE IF NOT EXISTS volunteer_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  volunteer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  camp_id uuid NOT NULL REFERENCES camps(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE camps ENABLE ROW LEVEL SECURITY;
ALTER TABLE camp_selections ENABLE ROW LEVEL SECURITY;
ALTER TABLE volunteer_assignments ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can read own data"
  ON users
  FOR SELECT
  TO authenticated
  USING (auth.uid()::text = id::text);

CREATE POLICY "Users can update own data"
  ON users
  FOR UPDATE
  TO authenticated
  USING (auth.uid()::text = id::text);

CREATE POLICY "Anyone can create user"
  ON users
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Camps policies
CREATE POLICY "Anyone can read camps"
  ON camps
  FOR SELECT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Volunteers can create camps"
  ON camps
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'volunteer'
    )
  );

CREATE POLICY "Volunteers can update camps"
  ON camps
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'volunteer'
    )
  );

CREATE POLICY "Volunteers can delete camps they added"
  ON camps
  FOR DELETE
  TO authenticated
  USING (
    added_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'volunteer'
    )
  );

-- Camp selections policies
CREATE POLICY "Users can read own selections"
  ON camp_selections
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create own selections"
  ON camp_selections
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own selections"
  ON camp_selections
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

-- Volunteer assignments policies
CREATE POLICY "Volunteers can read own assignments"
  ON volunteer_assignments
  FOR SELECT
  TO authenticated
  USING (volunteer_id = auth.uid());

CREATE POLICY "Volunteers can create own assignments"
  ON volunteer_assignments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    volunteer_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'volunteer'
    )
  );

-- Insert default camps
INSERT INTO camps (name, beds, original_beds, resources, contact, ambulance, type) VALUES
  ('Central School Grounds', 24, 24, ARRAY['Food', 'Water', 'Medical Aid', 'Blankets'], '+91 98765 43210', 'Yes', 'default'),
  ('Community Hall', 12, 12, ARRAY['Food', 'Water', 'Blankets', 'Clothing'], '+91 98765 11223', 'Nearby', 'default'),
  ('Government High School', 30, 30, ARRAY['Food', 'Water', 'First Aid', 'Hygiene Kits'], '+91 98765 77889', 'Yes', 'default')
ON CONFLICT DO NOTHING;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_camps_updated_at BEFORE UPDATE ON camps FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to handle camp selection constraints
CREATE OR REPLACE FUNCTION check_single_active_selection()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if user already has an active selection
  IF NEW.status = 'active' AND EXISTS (
    SELECT 1 FROM camp_selections 
    WHERE user_id = NEW.user_id 
    AND status = 'active' 
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
  ) THEN
    RAISE EXCEPTION 'User already has an active camp selection';
  END IF;
  
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for camp selection constraint
CREATE TRIGGER check_single_active_selection_trigger
  BEFORE INSERT OR UPDATE ON camp_selections
  FOR EACH ROW EXECUTE FUNCTION check_single_active_selection();