# KT — Browser DevTools

---

## What is DevTools?

DevTools is a set of built-in developer tools in every modern browser (Chrome, Firefox, Edge). It lets you inspect everything that is happening inside the browser — the HTML structure, JavaScript errors, network requests, cookies, storage, and performance.

Open it with: `F12` or `Right click → Inspect`

---

## The Tabs — What Each One Is For

| Tab | What it shows | When you use it |
|---|---|---|
| **Elements** | The live HTML/CSS of the page | Debugging layout, styles, DOM structure |
| **Console** | JS errors, logs, run JS manually | Debugging JS, seeing `console.log()` output |
| **Sources** | Your actual JS/CSS source files | Setting breakpoints, debugging JS step by step |
| **Network** | Every HTTP request the browser makes | Debugging API calls, checking payloads, headers |
| **Performance** | Page load and rendering timeline | Diagnosing slow pages |
| **Memory** | JavaScript heap memory usage | Debugging memory leaks |
| **Application** | Cookies, localStorage, sessionStorage | Inspecting stored data, clearing sessions |
| **Security** | SSL certificate details | Checking HTTPS is valid |

As a backend/full-stack developer, you will live in **Network** and **Console** 90% of the time. **Application** is useful for auth debugging (checking JWT tokens in storage).

---

## Network Tab — Deep Dive

### The request list (left side)

When you open the Network tab and use your app, every HTTP request appears as a row. The columns:

| Column | What it means |
|---|---|
| **Name** | Last segment of the URL path (explained below) |
| **Status** | HTTP response code — 200, 401, 404, 500 |
| **Type** | What kind of resource — fetch, xhr, document, script, img |
| **Initiator** | What triggered this request |
| **Size** | Response size (bytes) |
| **Time** | Total time from request sent to response received |
| **Waterfall** | Visual bar showing when this request happened relative to others |

### Where the "Name" comes from

The Name column shows the **last segment of the URL path**. It comes directly from the URL — you do not set it anywhere.

```
URL: http://localhost/api/auth/login   → Name: login
URL: http://localhost/api/notes/       → Name: notes
URL: http://localhost/                 → Name: localhost
URL: http://localhost/assets/index.js  → Name: index.js
```

If the name looks cryptic (like `index-Bx3kP9.js`), that is a hashed filename — the build tool (Vite/Webpack) adds a hash to the filename for cache busting. It is still just the last part of the URL.

### Filters

At the top of the Network tab you can filter by type:
- **All** — everything
- **Fetch/XHR** — only API calls (what you care about most)
- **Doc** — HTML documents
- **JS** — JavaScript files
- **CSS** — stylesheets
- **Img** — images
- **Font** — fonts
- **WS** — WebSocket connections

For API debugging, always switch to **Fetch/XHR** so you only see your API calls.

---

## When You Click a Request — The Sub-tabs

### Headers

Shows two things:

**Request Headers** — what the browser sent to the server:
```
Authorization: Bearer eyJhbGc...    ← JWT token
Content-Type: application/json      ← telling server the body is JSON
Host: localhost
```

**Response Headers** — what the server sent back:
```
X-Kong-Upstream-Latency: 4         ← time Kong spent waiting for FastAPI
X-Kong-Proxy-Latency: 1            ← time Kong itself spent processing
Content-Type: application/json
```

### Payload

Shows the **request body** — what the browser sent to the server. Only present for POST, PUT, PATCH requests.

```json
{
  "username": "alice",
  "password": "secret123"
}
```

This is where you see the raw password during login (before TLS encrypts it on the wire).

### Preview

The **response body formatted** — JSON is shown as a collapsible tree. Easier to read than raw text.

### Response

The **raw response body** as text. Useful when Preview fails to format it correctly.

### Initiator

Shows **what triggered this request** — the call stack inside your JavaScript that led to this HTTP request being made.

Example:
```
app.js:47   fetch('/api/auth/login', ...)
app.js:112  handleLoginSubmit()
(anonymous) onClick event
```

This tells you: the login button's onClick handler called `handleLoginSubmit()` on line 112, which called `fetch()` on line 47. Useful for tracing where a request comes from when you have a large codebase.

### Timing

Shows a **breakdown of time** spent on each phase of the request:

| Phase | What it means |
|---|---|
| **Queueing** | Browser queued the request (waiting for a connection slot) |
| **Stalled** | Request was ready but waiting to be sent |
| **DNS Lookup** | Time to resolve the domain name to an IP |
| **Initial connection** | TCP handshake — establishing the connection |
| **SSL** | TLS handshake — encrypting the connection (HTTPS only) |
| **Request sent** | Time to send the request bytes to the server |
| **Waiting (TTFB)** | **Time To First Byte** — server is processing, you are waiting |
| **Content Download** | Time to download the response body |

**TTFB is the most important one.** If TTFB is high (hundreds of ms), your server is slow — database query is slow, or the server is under load. If Content Download is high, the response payload is large.

---

## Console Tab

Shows:
- `console.log()` output from your JavaScript
- JavaScript errors (in red) with file and line number
- Network errors ("Failed to fetch", CORS errors)
- Warnings (in yellow)

You can also type JavaScript directly into the console and run it — useful for quick debugging.

CORS errors always appear here first:
```
Access to fetch at 'http://localhost/api/login' from origin 'http://localhost' 
has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header
```

---

## Application Tab

### localStorage

Key-value storage in the browser that persists across page refreshes. Your frontend stores the JWT token here after login.

```
Key: token
Value: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

You can expand the token at jwt.io to read its contents. This is useful when debugging auth issues.

### sessionStorage

Same as localStorage but cleared when the browser tab is closed.

### Cookies

HTTP cookies set by the server. If your app used cookie-based sessions instead of JWT, you would see the session token here.

---

## Practical Debugging Workflow

**API call not working?**
1. Open Network tab → filter by Fetch/XHR
2. Find the failing request → check Status code
3. Click it → check Payload (did the browser send the right data?)
4. Check Response (what did the server return? Is there an error message?)
5. Check Headers (is the Authorization header present?)

**CORS error?**
1. Open Console → read the full error message
2. Open Network tab → find the OPTIONS preflight request
3. Check Response Headers — is `Access-Control-Allow-Origin` present?

**Slow API call?**
1. Click the request → Timing tab
2. Check TTFB — if high, server is slow
3. Check Content Download — if high, response is too large

**JWT token missing or expired?**
1. Application tab → localStorage
2. Find the token key — is it there?
3. Copy the value → paste at jwt.io → check expiry
