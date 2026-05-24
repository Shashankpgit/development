# Phase 3.3 — Migration Plan: Vanilla JS → React

## What we are doing

Replacing the old plain HTML + JS frontend with a React app built with Vite.
The vault API (FastAPI) stays unchanged — only the frontend changes.

---

## Why this structure

In development — two servers run side by side:
```
Terminal 1: uvicorn (port 8000)    ← API
Terminal 2: npm run dev (port 5173) ← React frontend
```

React calls the API directly at http://localhost:8000.
CORS middleware on FastAPI allows requests from port 5173.

In production (Phase 7) — Nginx will serve the React build and proxy API calls.

---

## Folder structure after migration

```
vault/
├── app/                   ← FastAPI (unchanged)
└── frontend/              ← React app (Vite)
    ├── src/
    │   ├── main.jsx       ← entry point
    │   ├── App.jsx        ← root component
    │   └── components/
    │       ├── Header.jsx
    │       ├── HealthCheck.jsx
    │       ├── NoteList.jsx
    │       ├── NoteForm.jsx
    │       └── NoteCard.jsx
    ├── index.html
    ├── package.json
    └── vite.config.js
```

---

## Features to rebuild (same as vanilla JS, now in React)

| Feature | Vanilla JS | React |
|---|---|---|
| Health check | button + fetch + innerHTML | HealthCheck component with useState |
| Load notes | fetch + map to HTML string | NoteList component with useEffect |
| Create note | form + POST fetch | NoteForm component with controlled inputs |
| Delete note | DELETE fetch + reload | delete handler in NoteList |

---

## Steps

1. `npm install` — install dependencies
2. Clean App.jsx — remove Vite default code
3. Build Header component
4. Build HealthCheck component
5. Build NoteList component (load notes)
6. Build NoteForm component (create note)
7. Add delete to NoteList

---

## Dev server commands

```bash
# Start React dev server
cd vault/frontend
npm run dev        → http://localhost:5173

# Build for production
npm run build      → generates vault/frontend/dist/
```
