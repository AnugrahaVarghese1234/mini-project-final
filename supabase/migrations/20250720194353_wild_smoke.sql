/*
  # Create flood relief database schema

  1. New Tables
    - `users`
      - `id` (uuid, primary key)
      - `name` (text, required)
      - `email` (text, unique, required)
      - `password` (text, required)
      - `role` (text, required, default 'refugee')
      - `age` (integer, optional)
      - `contact` (text, optional)
      - `address` (text, optional)
      - `needs` (text, optional)
      - `skills` (text, optional)
      - `availability` (text, optional)
      - `created_at` (timestamp)

    - `camps`
      - `id` (uuid, primary key)
      - `name` (text, required)
      - `beds` (integer, required, default 0)
      - `resources` (text array, optional)
      - `contact` (text, optional)
      - `ambulance` (text, optional)
      - `added_by` (uuid, foreign key to users)
      - `type` (text, default 'default')
      - `original_beds` (integer, optional)
      - `created_at` (timestamp)

    - `camp_selections`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to users)
      - `camp_id` (uuid, foreign key to camps)
      - `status` (text, default 'active')
      - `selected_at` (timestamp)
      - `cancelled_at` (timestamp, optional)
      - `created_at` (timestamp)

    - `volunteer_assignments`
      - `id` (uuid, primary key)
      - `volunteer_id` (uuid, foreign key to users)
      - `camp_id` (uuid, foreign key to camps)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users to manage their own data
    - Add policies for volunteers to manage camps and assignments
    - Add policies for public read access to camps
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
  added_by uuid,
  type text DEFAULT 'default',
  original_beds integer,
  created_at timestamptz DEFAULT now()
);

-- Create camp_selections table
CREATE TABLE IF NOT EXISTS camp_selections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  camp_id uuid,
  status text NOT NULL DEFAULT 'active',
  selected_at timestamptz DEFAULT now(),
  cancelled_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Create volunteer_assignments table
CREATE TABLE IF NOT EXISTS volunteer_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  volunteer_id uuid,
  camp_id uuid,
  created_at timestamptz DEFAULT now()
);

-- Add foreign key constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'camps_added_by_fkey'
  ) THEN
    ALTER TABLE camps ADD CONSTRAINT camps_added_by_fkey 
    FOREIGN KEY (added_by) REFERENCES users(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'camp_selections_user_id_fkey'
  ) THEN
    ALTER TABLE camp_selections ADD CONSTRAINT camp_selections_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'camp_selections_camp_id_fkey'
  ) THEN
    ALTER TABLE camp_selections ADD CONSTRAINT camp_selections_camp_id_fkey 
    FOREIGN KEY (camp_id) REFERENCES camps(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'volunteer_assignments_volunteer_id_fkey'
  ) THEN
    ALTER TABLE volunteer_assignments ADD CONSTRAINT volunteer_assignments_volunteer_id_fkey 
    FOREIGN KEY (volunteer_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'volunteer_assignments_camp_id_fkey'
  ) THEN
    ALTER TABLE volunteer_assignments ADD CONSTRAINT volunteer_assignments_camp_id_fkey 
    FOREIGN KEY (camp_id) REFERENCES camps(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Add unique constraint for active camp selections
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'unique_active_selection'
  ) THEN
    ALTER TABLE camp_selections ADD CONSTRAINT unique_active_selection 
    UNIQUE (user_id) DEFERRABLE INITIALLY DEFERRED;
  END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE camps ENABLE ROW LEVEL SECURITY;
ALTER TABLE camp_selections ENABLE ROW LEVEL SECURITY;
ALTER TABLE volunteer_assignments ENABLE ROW LEVEL SECURITY;

-- Create policies for users table
CREATE POLICY "Anyone can create user accounts" ON users
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Users can read own data" ON users
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own data" ON users
  FOR UPDATE TO authenticated
  USING (auth.uid() = id);

-- Create policies for camps table
CREATE POLICY "Anyone can read camps" ON camps
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "Volunteers can create camps" ON camps
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'volunteer'
    )
  );

CREATE POLICY "Volunteers can update camps they added" ON camps
  FOR UPDATE TO authenticated
  USING (
    added_by = auth.uid() 
    AND EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'volunteer'
    )
  );

CREATE POLICY "Volunteers can delete camps they added" ON camps
  FOR DELETE TO authenticated
  USING (
    added_by = auth.uid() 
    AND EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'volunteer'
    )
  );

-- Create policies for camp_selections table
CREATE POLICY "Users can read own selections" ON camp_selections
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create own selections" ON camp_selections
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own selections" ON camp_selections
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

-- Create policies for volunteer_assignments table
CREATE POLICY "Volunteers can read own assignments" ON volunteer_assignments
  FOR SELECT TO authenticated
  USING (volunteer_id = auth.uid());

CREATE POLICY "Volunteers can create own assignments" ON volunteer_assignments
  FOR INSERT TO authenticated
  WITH CHECK (
    volunteer_id = auth.uid() 
    AND EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'volunteer'
    )
  );

-- Insert some default camps
INSERT INTO camps (name, beds, resources, contact, ambulance, type, original_beds) VALUES
  ('Central School Grounds', 24, ARRAY['Food', 'Water', 'Medical Aid', 'Blankets'], '+91 98765 43210', 'Yes', 'default', 24),
  ('Community Hall', 12, ARRAY['Food', 'Water', 'Blankets', 'Clothing'], '+91 98765 11223', 'Nearby', 'default', 12),
  ('Government High School', 30, ARRAY['Food', 'Water', 'First Aid', 'Hygiene Kits'], '+91 98765 77889', 'Yes', 'default', 30)
ON CONFLICT DO NOTHING;