// Authentication utilities
import { dbHelpers } from '../lib/supabase.js'

export class AuthManager {
  constructor() {
    this.currentUser = null
    this.loadCurrentUser()
  }

  loadCurrentUser() {
    try {
      const userData = localStorage.getItem('currentUser')
      this.currentUser = userData ? JSON.parse(userData) : null
    } catch (error) {
      console.error('Error loading user data:', error)
      this.currentUser = null
    }
  }

  setCurrentUser(userData) {
    try {
      this.currentUser = userData
      localStorage.setItem('currentUser', JSON.stringify(userData))
      return true
    } catch (error) {
      console.error('Error saving user data:', error)
      return false
    }
  }

  getCurrentUser() {
    return this.currentUser
  }

  clearCurrentUser() {
    try {
      this.currentUser = null
      localStorage.removeItem('currentUser')
      return true
    } catch (error) {
      console.error('Error clearing user data:', error)
      return false
    }
  }

  async register(userData) {
    try {
      // Check if user already exists
      const { data: existingUser } = await dbHelpers.getUserByEmail(userData.email)
      if (existingUser) {
        throw new Error('User with this email already exists')
      }

      // Create new user
      const { data: newUser, error } = await dbHelpers.createUser(userData)
      if (error) throw error

      // Set as current user (excluding sensitive data)
      const { password, ...userToStore } = newUser
      this.setCurrentUser(userToStore)
      
      return { success: true, user: userToStore }
    } catch (error) {
      console.error('Registration error:', error)
      return { success: false, error: error.message }
    }
  }

  async login(email, password) {
    try {
      // Get user by email
      const { data: user, error } = await dbHelpers.getUserByEmail(email)
      if (error || !user) {
        throw new Error('Invalid email or password')
      }

      // In a real app, you'd verify the password here
      // For demo purposes, we'll accept any password
      
      // Set as current user (excluding sensitive data)
      const { password: _, ...userToStore } = user
      this.setCurrentUser(userToStore)
      
      return { success: true, user: userToStore }
    } catch (error) {
      console.error('Login error:', error)
      return { success: false, error: error.message }
    }
  }

  logout() {
    this.clearCurrentUser()
    return { success: true }
  }

  isLoggedIn() {
    return this.currentUser !== null
  }

  isVolunteer() {
    return this.currentUser?.role === 'volunteer'
  }

  isRefugee() {
    return this.currentUser?.role === 'refugee'
  }
}

// Create singleton instance
export const authManager = new AuthManager()