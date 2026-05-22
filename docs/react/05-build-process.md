# The Build Process — Why React Needs a Build Step

## Vanilla JS needs no build step

With vanilla JS, you write `app.js` and the browser runs it directly.
No compilation, no tools, no setup.

```
You write app.js → browser runs app.js
```

## React cannot run in the browser directly

React uses JSX — HTML inside JavaScript. Browsers do not understand JSX.

```jsx
// This is JSX — the browser cannot run this
function Header() {
  return <h1>Personal Vault</h1>;
}
```

Before the browser can run this, it must be **compiled** into plain JavaScript:

```javascript
// This is what the browser actually runs — compiled output
function Header() {
  return React.createElement("h1", null, "Personal Vault");
}
```

A build tool does this compilation automatically.

---

## Vite — the build tool we will use

Vite (pronounced "veet") is the modern standard for React projects.
It does two things:

1. **Development mode** (`npm run dev`)
   - Starts a local server (default: http://localhost:5173)
   - Compiles JSX on the fly as you save files
   - Hot reload — changes appear in the browser instantly without refresh

2. **Production build** (`npm run build`)
   - Compiles all JSX to plain JS
   - Bundles all files into a few optimized files in a `dist/` folder
   - Those files can be served by Nginx or FastAPI in production

---

## Development setup (two terminals)

Once we migrate to React, the development workflow becomes:

```
Terminal 1:
  cd vault && uvicorn app.main:app --reload
  → FastAPI running at http://localhost:8000

Terminal 2:
  cd vault/frontend && npm run dev
  → React dev server at http://localhost:5173
```

You open http://localhost:5173 in the browser.
React page loads. JS makes fetch() calls to http://localhost:8000.

Two different ports = two different origins = **CORS**.

The browser will block those API calls unless FastAPI explicitly allows
requests from http://localhost:5173. This is the CORS error you will
hit naturally — and then fix.

---

## Production setup (after Phase 7 — Nginx)

In production, Nginx takes over:

```
Browser → Nginx :80
            ├── /          → serves React's dist/ folder (static files)
            └── /api/*     → proxies to FastAPI :8000
```

React is compiled to static files. FastAPI only handles API calls.
No Node.js needed in production — just the compiled output.

---

## File structure after adding React

```
vault/
├── app/              ← FastAPI (unchanged)
├── frontend/         ← React app (replaces the old HTML/CSS/JS)
│   ├── src/
│   │   ├── main.jsx       ← entry point
│   │   ├── App.jsx        ← root component
│   │   └── components/
│   │       ├── NoteList.jsx
│   │       ├── NoteForm.jsx
│   │       └── NoteCard.jsx
│   ├── package.json
│   └── vite.config.js
└── requirements.txt
```
