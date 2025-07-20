// Supabase client configuration
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase environment variables. Please set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Database helper functions
export const dbHelpers = {
  // Users
  async createUser(userData) {
    const { data, error } = await supabase
      .from('users')
      .insert([userData])
      .select()
    return { data: data?.[0], error }
  },

  async getUserByEmail(email) {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('email', email)
      .single()
    return { data, error }
  },

  async updateUser(id, updates) {
    const { data, error } = await supabase
      .from('users')
      .update(updates)
      .eq('id', id)
      .select()
    return { data: data?.[0], error }
  },

  // Camps
  async getCamps() {
    const { data, error } = await supabase
      .from('camps')
      .select('*')
      .order('created_at', { ascending: false })
    return { data: data || [], error }
  },

  async createCamp(campData) {
    const { data, error } = await supabase
      .from('camps')
      .insert([campData])
      .select()
    return { data: data?.[0], error }
  },

  async updateCamp(id, updates) {
    const { data, error } = await supabase
      .from('camps')
      .update(updates)
      .eq('id', id)
      .select()
    return { data: data?.[0], error }
  },

  async deleteCamp(id) {
    const { data, error } = await supabase
      .from('camps')
      .delete()
      .eq('id', id)
    return { data, error }
  },

  // Camp Selections
  async createCampSelection(selectionData) {
    const { data, error } = await supabase
      .from('camp_selections')
      .insert([selectionData])
      .select()
    return { data: data?.[0], error }
  },

  async getUserCampSelection(userId) {
    const { data, error } = await supabase
      .from('camp_selections')
      .select(`
        *,
        camps (
          id,
          name,
          beds,
          resources,
          contact,
          ambulance
        )
      `)
      .eq('user_id', userId)
      .eq('status', 'active')
      .single()
    return { data, error }
  },

  async cancelCampSelection(userId) {
    const { data, error } = await supabase
      .from('camp_selections')
      .update({ status: 'cancelled', cancelled_at: new Date().toISOString() })
      .eq('user_id', userId)
      .eq('status', 'active')
    return { data, error }
  },

  // Volunteer Assignments
  async createVolunteerAssignment(assignmentData) {
    const { data, error } = await supabase
      .from('volunteer_assignments')
      .insert([assignmentData])
      .select()
    return { data: data?.[0], error }
  },

  async getVolunteerAssignments(volunteerId) {
    const { data, error } = await supabase
      .from('volunteer_assignments')
      .select(`
        *,
        camps (
          id,
          name
        )
      `)
      .eq('volunteer_id', volunteerId)
      .order('created_at', { ascending: false })
    return { data: data || [], error }
  }
}

// Real-time subscriptions
export const subscriptions = {
  subscribeToCamps(callback) {
    return supabase
      .channel('camps_changes')
      .on('postgres_changes', 
        { event: '*', schema: 'public', table: 'camps' }, 
        callback
      )
      .subscribe()
  },

  subscribeToCampSelections(callback) {
    return supabase
      .channel('camp_selections_changes')
      .on('postgres_changes', 
        { event: '*', schema: 'public', table: 'camp_selections' }, 
        callback
      )
      .subscribe()
  }
}