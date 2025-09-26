// app/javascript/application.js
import React from 'react'
import { createRoot } from 'react-dom/client'
import SalesforceApp from './components/SalesforceApp.jsx'

// Wait for DOM to be ready
document.addEventListener('DOMContentLoaded', () => {
  const container = document.getElementById('react-root')
  if (container) {
    const root = createRoot(container)
    root.render(React.createElement(SalesforceApp))
  }
})

export default SalesforceApp
