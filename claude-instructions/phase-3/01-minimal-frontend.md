# Phase 3 — Step 1: Minimal HTML Frontend

## What this step covers
Build the first frontend — a simple HTML page that calls the backend API using vanilla JavaScript `fetch()`. No framework, no build tools. Just HTML, CSS, and JS files served statically.

---

## Pre-step checklist (Claude must do before any code)

- [ ] Create `docs/007-frontend-plan.md` first
- [ ] Explain WHY we use plain HTML/JS instead of React (learning fundamentals first)
- [ ] Confirm backend is stable: Phase 1 and Phase 2 endpoints all work via Swagger

---

## Why this step exists

Until now, the user has only interacted with the API through Swagger UI. Swagger is a developer tool, not a user interface. This step creates the first real UI — minimal enough to understand the browser/API relationship, without the complexity of a JavaScript framework.

Building in plain HTML+JS also prepares the user to understand what React, Vue, etc. actually do for you — you can only appreciate a framework after you've felt the pain it solves.

---

## What to implement

### `frontend/` folder structure
```
frontend/
├── index.html          ← landing / note list page
├── create-note.html    ← simple form to create a note
├── styles.css          ← minimal styling (readable, not pretty)
└── app.js              ← all JavaScript logic
```

### Features in v1 frontend (keep minimal)
- List all notes for user_id=1 (hardcoded user for now — auth comes in Phase 4)
- Form to create a new note
- Delete button per note
- No login page yet

### Serving the frontend
For now, serve it as FastAPI static files:
```python
app.mount("/", StaticFiles(directory="frontend", html=True), name="frontend")
```

---

## Concepts to teach during this step

- **How browsers load HTML**: HTML → browser parses → CSS applied → JS executed
- **`fetch()` API**: The browser's built-in way to make HTTP requests from JavaScript. Show: fetch returns a Promise.
- **Promises and async/await**: Brief explanation — "JavaScript is asynchronous because waiting for a server response would freeze the page"
- **DOM manipulation**: `document.getElementById`, `innerHTML`, `appendChild` — how JS changes what's on the screen
- **HTML form basics**: `<form>`, `<input>`, `<button>`, `<textarea>` — what each does
- **`event.preventDefault()`**: Why forms need this when you handle submission in JS
- **Static files in FastAPI**: What `StaticFiles` mount does — FastAPI serves the HTML/CSS/JS files directly
- **Same-origin**: Browser + API on same `localhost:8000` — no CORS issue yet (CORS is introduced in Phase 4 when they're on different ports)

---

## Teaching moment: Open DevTools here

This is the first time DevTools should be introduced:
1. Open `http://localhost:8000` in Chrome
2. Press `F12` → open DevTools
3. Go to **Network tab**
4. Click something in the UI
5. Show the request appearing in the Network tab
6. Click the request → show Headers, Request body, Response body
7. "This is how you debug API calls in a real frontend"

Teach only: Network tab and Console tab at this point. Save Elements and Application tabs for later.

---

## What NOT to do in this step

- Do NOT use any JS framework (React, Vue, Angular)
- Do NOT use npm or a bundler
- Do NOT build a full UI for passwords (notes only — keep scope small)
- Do NOT add login/logout UI (that's Phase 4)
- Do NOT make it look beautiful — readable is enough

---

## File changes

| File | Action |
|---|---|
| `frontend/index.html` | Create |
| `frontend/create-note.html` | Create |
| `frontend/styles.css` | Create |
| `frontend/app.js` | Create |
| `app/main.py` | Modify — mount StaticFiles |
| `requirements.txt` | No change (StaticFiles is built into FastAPI) |

---

## Success criteria

1. Open `http://localhost:8000` → list of notes appears (from the DB)
2. Click "New Note" → fill form → submit → note appears in list without page reload
3. Click "Delete" on a note → note disappears
4. Open DevTools Network tab → see the `GET /notes` and `POST /notes` requests
5. No page refreshes — all interactions happen via `fetch()`
