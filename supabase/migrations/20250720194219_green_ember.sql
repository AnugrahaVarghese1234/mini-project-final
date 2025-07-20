/*
  # Create flood relief database schema

  1. New Tables
    - `users`
      - `id` (uuid, primary key)
      - `name` (text, not null)
      - `email` (text, unique, not null)
      - `password` (text, not null)
      - `role` (text, default 'refugee')
      - `age` (integer)
      - `contact` (text)
      - `address` (text)
      - `needs` (text)
      - `skills` (text)
      - `availability` (text)
      - `created_at` (timestamptz, default now)
    
    - `camps`
      - `id` (uuid, primary key)
      - `name` (text, not null)
      - `beds` (integer, not null)
      - `resources` (text array)
      - `contact` (text)
      - `ambulance` (text)
      - `added_by` (uuid, foreign key to users)
      - `type` (text, default 'default')
      - `original_beds` (integer)
      - `created_at` (timestamptz, default now)
    
    - `camp_selections`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to users)
      - `camp_id` (uuid, foreign key to camps)
      - `status` (text, default 'active')
      - `selected_at` (timestamptz, default now)
      - `cancelled_at` (timestamptz)
      - Unique constraint on user_id for active selections
    
    - `volunteer_assignments`
      - `id` (uuid, primary key)
      - `volunteer_id` (uuid, foreign key to users)
      - `camp_id` (uuid, foreign key to camps)
      - `created_at` (timestamptz, default now)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users to manage their own data
    - Add policies for volunteers to manage camps and assignments
*/

-- Create users table
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text UNIQUE NOT NULL,
  password text NOT NULL,
  role text NOT NULL DEFAULT 'refugee',
  age integer,
  contact text,
  address text,
  needs text,
  skills text,
  availability text,
  created_at timestamptz DEFAULT now()
);

-- Create camps table
CREATE TABLE IF NOT EXISTS camps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  beds integer NOT NULL DEFAULT 0,
  resources text[] DEFAULT '{}',
  contact text,
  ambulance text,
  added_by uuid REFERENCES users(id) ON DELETE SET NULL,
  type text DEFAULT 'default',
  original_beds integer,
  created_at timestamptz DEFAULT now()
);

-- Create camp_selections table
CREATE TABLE IF NOT EXISTS camp_selections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  camp_id uuid REFERENCES camps(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active',
  selected_at timestamptz DEFAULT now(),
  cancelled_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Create volunteer_assignments table
CREATE TABLE IF NOT EXISTS volunteer_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  volunteer_id uuid REFERENCES users(id) ON DELETE CASCADE,
  camp_id uuid REFERENCES camps(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

-- Add unique constraint for active camp selections (one active selection per user)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'unique_active_selection' 
    AND table_name = 'camp_selections'
  ) THEN
    ALTER TABLE camp_selections 
    ADD CONSTRAINT unique_active_selection 
    UNIQUE (user_id) 
    DEFERRABLE INITIALLY DEFERRED;
  END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE camps ENABLE ROW LEVEL SECURITY;
ALTER TABLE camp_selections ENABLE ROW LEVEL SECURITY;
ALTER TABLE volunteer_assignments ENABLE ROW LEVEL SECURITY;

-- Create policies for users table
CREATE POLICY "Users can read own data"
  ON users
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own data"
  ON users
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Anyone can create user accounts"
  ON users
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Create policies for camps table
CREATE POLICY "Anyone can read camps"
  ON camps
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Volunteers can create camps"
  ON camps
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'volunteer'
    )
  );

CREATE POLICY "Volunteers can update camps they added"
  ON camps
  FOR UPDATE
  TO authenticated
  USING (
    added_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'volunteer'
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
      WHERE users.id = auth.uid() 
      AND users.role = 'volunteer'
    )
  );

-- Create policies for camp_selections table
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

-- Create policies for volunteer_assignments table
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
      WHERE users.id = auth.uid() 
      AND users.role = 'volunteer'
    )
  );

-- Insert default camps
INSERT INTO camps (name, beds, original_beds, resources, contact, ambulance, type) VALUES
  ('Central School Grounds', 24, 24, ARRAY['Food', 'Water', 'Medical Aid', 'Blankets'], '+91 98765 43210', 'Yes', 'default'),
  ('Community Hall', 12, 12, ARRAY['Food', 'Water', 'Blankets', 'Clothing'], '+91 98765 11223', 'Nearby', 'default'),
  ('Government High School', 30, 30, ARRAY['Food', 'Water', 'First Aid', 'Hygiene Kits'], '+91 98765 77889', 'Yes', 'default')
ON CONFLICT DO NOTHING;