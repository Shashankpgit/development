/*
 * The bridge between the HTML file and React.
 *
 * createRoot(el) tells React "this DOM element is yours to control".
 * render(<App />) builds the component tree and writes it into that element.
 * Everything the user sees flows from this one call.
 */
import React from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App.jsx'
import './styles.css'

createRoot(document.getElementById('root')).render(
  // StrictMode is a development-only helper: it deliberately runs some code
  // twice to surface bugs (like a fetch that is not safe to repeat). It is
  // stripped out of production builds.
  <React.StrictMode>
    {/* BrowserRouter makes the browser URL bar drive which page shows,
        WITHOUT a full page reload. Clicking a link swaps components in
        memory and rewrites the URL via the History API. */}
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>,
)
