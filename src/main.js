// Main application entry point
import { authManager } from './utils/auth.js'
import { campManager } from './utils/camps.js'

// Initialize the application
document.addEventListener('DOMContentLoaded', async () => {
  console.log('🌊 Flood Rehabilitation Project initialized')
  
  // Load initial data if user is logged in
  if (authManager.isLoggedIn()) {
    await campManager.loadCamps()
    await campManager.loadUserSelection()
  }
})

// Make utilities available globally for HTML scripts
window.authManager = authManager
window.campManager = campManager