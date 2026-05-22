# Setup — React Playground

## Pre-requisites

| Tool | What it is | Check if installed |
|---|---|---|
| Node.js | JavaScript runtime — runs JS outside the browser | `node --version` |
| npm | Package manager for JS (comes with Node.js) | `npm --version` |
| Vite | Build tool + dev server for React | installed per project |

Node.js is to JavaScript what Python is to your FastAPI app.
npm is to Node.js what pip is to Python.
Vite is the tool that compiles JSX and runs the dev server.

---

## One-time setup — create the React playground

Run these commands once:

```bash
cd /home/sanketika7420/Learn/dev/development/react-playground

npm create vite@latest . -- --template react
# When prompted:
#   "Current directory is not empty" → select: Ignore files and continue
#   Framework → React
#   Variant → JavaScript

npm install
```

Then start the dev server:

```bash
npm run dev
```

Open http://localhost:5173 in the browser.
You should see the default Vite + React page.

---

## What got created

```
react-playground/
├── src/
│   ├── main.jsx       ← entry point — mounts the app into index.html
│   ├── App.jsx        ← root component — this is where we will work
│   └── App.css        ← styles for App
├── index.html         ← the one HTML file (has <div id="root">)
├── package.json       ← project metadata + dependencies
└── vite.config.js     ← Vite configuration
```

### index.html — the only HTML file

```html
<div id="root"></div>
<script type="module" src="/src/main.jsx"></script>
```

This is the entire HTML body. Just one empty div. React will fill it.

### main.jsx — entry point

```jsx
ReactDOM.createRoot(document.getElementById('root')).render(<App />)
```

This finds the `<div id="root">` and mounts the `<App />` component into it.
Everything you see on screen comes from `<App />` and its children.

### App.jsx — where we work

This is the file we will edit for every hands-on exercise.

---

## Workflow for each topic

1. Edit `src/App.jsx`
2. Save — browser updates instantly (no refresh needed)
3. Observe the result
4. Compare with the vanilla JS equivalent

---

## Stopping and starting

```bash
# Start dev server
npm run dev

# Stop: Ctrl+C
```
