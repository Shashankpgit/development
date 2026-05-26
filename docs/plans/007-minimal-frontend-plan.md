# Plan 007 — Minimal Frontend

## Phase 3, Step 1

---

## What we are building

A single HTML page served by FastAPI that lets a user:
- See a health check status from the API
- List notes for a user
- Store a new note

No framework. No build tools. Plain HTML + CSS + vanilla JavaScript.

---

## Why this approach

Before React, Vue, or any framework — you need to understand what a browser actually does:
- It fetches an HTML file
- It runs JavaScript in that file
- JavaScript can make HTTP requests to APIs (fetch)
- JavaScript can update what's visible on screen (DOM)

Frameworks just automate these steps. If you understand the fundamentals, frameworks will make sense.

---

## What is new in this phase

### StaticFiles (FastAPI)
FastAPI normally returns JSON. To serve HTML/CSS/JS files, we mount a
`StaticFiles` directory — FastAPI will send those files as-is when the
browser requests them.

### JavaScript fetch()
`fetch()` is a browser built-in function that makes HTTP requests — the
JS equivalent of curl. It returns a Promise (async result). We use
`.then()` or `async/await` to handle the response.

### DOM manipulation
`document.getElementById("someId")` selects an HTML element.
`element.innerHTML = "..."` changes what's shown on the page.
This is how JS updates the page without a full reload.

---

## Steps

1. Create `vault/frontend/` with `index.html`, `styles.css`, `app.js`
2. Mount `StaticFiles` in `main.py` at path `/`
3. Open `http://localhost:8000` in browser — see the HTML page
4. Open DevTools → Network tab — watch the HTML request
5. Add JS `fetch("/health")` on button click
6. Display the JSON response on the page
7. Add notes list: fetch `/notes?user_id=1`, render them

---

## File layout after this phase

```
vault/
└── frontend/
    ├── index.html    ← the page structure
    ├── styles.css    ← minimal styles
    └── app.js        ← all JavaScript
```
