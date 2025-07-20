// Camp management utilities
import { dbHelpers, subscriptions } from '../lib/supabase.js'
import { authManager } from './auth.js'

export class CampManager {
  constructor() {
    this.camps = []
    this.userSelection = null
    this.subscribers = new Set()
    this.setupRealtimeSubscriptions()
  }

  setupRealtimeSubscriptions() {
    // Subscribe to camp changes
    subscriptions.subscribeToCamps((payload) => {
      console.log('Camp change detected:', payload)
      this.loadCamps()
    })

    // Subscribe to camp selection changes
    subscriptions.subscribeToCampSelections((payload) => {
      console.log('Camp selection change detected:', payload)
      if (authManager.getCurrentUser()?.id === payload.new?.user_id || 
          authManager.getCurrentUser()?.id === payload.old?.user_id) {
        this.loadUserSelection()
      }
    })
  }

  subscribe(callback) {
    this.subscribers.add(callback)
    return () => this.subscribers.delete(callback)
  }

  notify() {
    this.subscribers.forEach(callback => callback())
  }

  async loadCamps() {
    try {
      const { data: camps, error } = await dbHelpers.getCamps()
      if (error) throw error
      
      this.camps = camps
      this.notify()
      return { success: true, camps }
    } catch (error) {
      console.error('Error loading camps:', error)
      return { success: false, error: error.message }
    }
  }

  async loadUserSelection() {
    try {
      const currentUser = authManager.getCurrentUser()
      if (!currentUser) {
        this.userSelection = null
        this.notify()
        return { success: true, selection: null }
      }

      const { data: selection, error } = await dbHelpers.getUserCampSelection(currentUser.id)
      if (error && error.code !== 'PGRST116') { // PGRST116 is "not found" error
        throw error
      }
      
      this.userSelection = selection
      this.notify()
      return { success: true, selection }
    } catch (error) {
      console.error('Error loading user selection:', error)
      return { success: false, error: error.message }
    }
  }

  async selectCamp(campId) {
    try {
      const currentUser = authManager.getCurrentUser()
      if (!currentUser) {
        throw new Error('User must be logged in to select a camp')
      }

      if (this.userSelection) {
        throw new Error('You already have a camp selected. Please cancel your current selection first.')
      }

      const camp = this.camps.find(c => c.id === campId)
      if (!camp) {
        throw new Error('Camp not found')
      }

      if (camp.beds <= 0) {
        throw new Error('This camp is full')
      }

      // Create camp selection
      const selectionData = {
        user_id: currentUser.id,
        camp_id: campId,
        status: 'active'
      }

      const { data: selection, error: selectionError } = await dbHelpers.createCampSelection(selectionData)
      if (selectionError) throw selectionError

      // Decrease bed count
      const { data: updatedCamp, error: updateError } = await dbHelpers.updateCamp(campId, {
        beds: camp.beds - 1
      })
      if (updateError) throw updateError

      // Reload data
      await this.loadCamps()
      await this.loadUserSelection()

      return { success: true, selection, camp: updatedCamp }
    } catch (error) {
      console.error('Error selecting camp:', error)
      return { success: false, error: error.message }
    }
  }

  async cancelSelection() {
    try {
      const currentUser = authManager.getCurrentUser()
      if (!currentUser || !this.userSelection) {
        throw new Error('No active camp selection found')
      }

      const campId = this.userSelection.camp_id
      const camp = this.camps.find(c => c.id === campId)

      // Cancel the selection
      const { error: cancelError } = await dbHelpers.cancelCampSelection(currentUser.id)
      if (cancelError) throw cancelError

      // Increase bed count back
      if (camp) {
        const { error: updateError } = await dbHelpers.updateCamp(campId, {
          beds: camp.beds + 1
        })
        if (updateError) throw updateError
      }

      // Reload data
      await this.loadCamps()
      await this.loadUserSelection()

      return { success: true }
    } catch (error) {
      console.error('Error cancelling selection:', error)
      return { success: false, error: error.message }
    }
  }

  async addCamp(campData) {
    try {
      const currentUser = authManager.getCurrentUser()
      if (!currentUser || currentUser.role !== 'volunteer') {
        throw new Error('Only volunteers can add camps')
      }

      const newCampData = {
        ...campData,
        added_by: currentUser.id,
        type: 'volunteer-added',
        original_beds: campData.beds
      }

      const { data: newCamp, error } = await dbHelpers.createCamp(newCampData)
      if (error) throw error

      await this.loadCamps()
      return { success: true, camp: newCamp }
    } catch (error) {
      console.error('Error adding camp:', error)
      return { success: false, error: error.message }
    }
  }

  async deleteCamp(campId) {
    try {
      const currentUser = authManager.getCurrentUser()
      if (!currentUser || currentUser.role !== 'volunteer') {
        throw new Error('Only volunteers can delete camps')
      }

      const { error } = await dbHelpers.deleteCamp(campId)
      if (error) throw error

      await this.loadCamps()
      return { success: true }
    } catch (error) {
      console.error('Error deleting camp:', error)
      return { success: false, error: error.message }
    }
  }

  async addVolunteerAssignment(campId) {
    try {
      const currentUser = authManager.getCurrentUser()
      if (!currentUser || currentUser.role !== 'volunteer') {
        throw new Error('Only volunteers can be assigned to camps')
      }

      const assignmentData = {
        volunteer_id: currentUser.id,
        camp_id: campId
      }

      const { data: assignment, error } = await dbHelpers.createVolunteerAssignment(assignmentData)
      if (error) throw error

      return { success: true, assignment }
    } catch (error) {
      console.error('Error adding volunteer assignment:', error)
      return { success: false, error: error.message }
    }
  }

  async getVolunteerHistory() {
    try {
      const currentUser = authManager.getCurrentUser()
      if (!currentUser || currentUser.role !== 'volunteer') {
        return { success: true, assignments: [] }
      }

      const { data: assignments, error } = await dbHelpers.getVolunteerAssignments(currentUser.id)
      if (error) throw error

      return { success: true, assignments }
    } catch (error) {
      console.error('Error loading volunteer history:', error)
      return { success: false, error: error.message }
    }
  }

  getCamps() {
    return this.camps
  }

  getUserSelection() {
    return this.userSelection
  }
}

// Create singleton instance
export const campManager = new CampManager()