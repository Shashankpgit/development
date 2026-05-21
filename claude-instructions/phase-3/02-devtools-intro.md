# Phase 3 — Step 2: Chrome DevTools Introduction

## What this step covers
A dedicated hands-on session teaching Chrome DevTools using the running Personal Vault app. No new code — this is a guided exploration of the browser's built-in engineering tools.

---

## Pre-step checklist

- [ ] Confirm the frontend from Phase 3 Step 1 is running and accessible
- [ ] Create `docs/KT-chrome-devtools.md` as the reference KT document for this session

---

## Why this step exists

The user has never used browser DevTools. This is one of the most important tools in a frontend/full-stack developer's daily workflow. Without it:
- You cannot debug frontend JavaScript
- You cannot inspect what the browser is actually sending and receiving
- You cannot measure page performance
- You cannot diagnose CORS errors (coming in Phase 4)

This session builds the mental model for every frontend debugging session going forward.

---

## What to teach (in order)

### 1. Opening DevTools
- `F12` or `Cmd+Option+I` (Mac) / `Ctrl+Shift+I` (Linux/Windows)
- Right-click → Inspect
- Explain: "DevTools is built into every browser. It's not a plugin. Every developer uses this daily."

### 2. Network Tab (most important for backend devs)
Walk through each section using a live request from the app:
- **Requests list**: Every HTTP request the browser makes appears here
- **Status code column**: 200, 201, 404, 500 — what each color means
- **Request Headers**: What the browser sends with every request (method, content-type, etc.)
- **Response Headers**: What the server sends back (content-type, CORS headers later)
- **Request Payload**: The JSON body you sent in POST/PUT
- **Response body**: The JSON the server returned
- **Timing**: How long each request took (useful for performance later)

Hands-on exercise: Create a note via the UI → watch the `POST /notes` request → inspect every field.

### 3. Console Tab
- Where JavaScript errors appear
- `console.log()` output appears here
- "When the UI breaks silently, check Console first"
- Show: intentionally break something → see the error → fix it

### 4. Elements Tab (brief)
- Shows the live HTML of the page
- You can edit HTML/CSS directly in the browser (changes are temporary, not saved)
- Useful for: "Why is this div not showing up?"

### 5. Application Tab (brief — more relevant in Phase 4)
- LocalStorage, SessionStorage, Cookies
- This is where auth tokens will live in Phase 4
- "Note this tab — we'll come back when we add login"

---

## Concepts to teach

- **What a browser does when you open a URL**: DNS → TCP → HTTP request → response → parse HTML → load JS/CSS → render
- **HTTP is text**: Show in Network tab that HTTP is just text headers + body
- **Why DevTools matters to backend engineers**: "You built the API. DevTools lets you verify the frontend is calling it correctly. When a bug is reported, this is step one."
- **CORS errors appear here**: Preview for Phase 4 — "In the next phase, we'll move the frontend to a different port and you'll see a red CORS error in the console. That's normal. We'll fix it."

---

## KT Document to create: `docs/KT-chrome-devtools.md`

Structure:
1. What DevTools is
2. How to open it
3. Network tab walkthrough (with diagrams)
4. Console tab
5. Elements tab
6. Application tab
7. Common debugging workflows
8. Tips for diagnosing API issues

---

## What NOT to do in this step

- Do NOT add new features to the app
- Do NOT introduce new concepts beyond DevTools
- Keep this as a pure learning/exploration session

---

## Success criteria

The user can:
1. Open DevTools independently
2. Find a specific API request in the Network tab
3. Inspect request headers, response headers, and response body
4. See a JavaScript error in the Console tab
5. Locate where localStorage/cookies would be stored (Application tab)
