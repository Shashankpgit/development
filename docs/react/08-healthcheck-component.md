# HealthCheck Component

## Stage 1 — What we are building

A `HealthCheck` component that:
- Shows a "Check Health" button
- On click, calls `GET /health` on the FastAPI API
- Displays the response: status, database, version

This is the React equivalent of the health check we built in vanilla JS.

### Vanilla JS equivalent (for comparison)
```javascript
document.getElementById("check-health-btn").addEventListener("click", async () => {
  const response = await fetch("/health");
  const data = await response.json();
  result.textContent = `Status: ${data.status} | DB: ${data.database}`;
});
```

### React version (what we will write)
```jsx
function HealthCheck() {
  const [status, setStatus] = useState(null);

  async function checkHealth() {
    const response = await fetch(`${API_URL}/health`);
    const data = await response.json();
    setStatus(data);
  }

  return (
    <div>
      <button onClick={checkHealth}>Check Health</button>
      {status && <p>Status: {status.status} | DB: {status.database}</p>}
    </div>
  );
}
```

### Files
- `vault/frontend/src/components/HealthCheck.jsx` ← new
- `vault/frontend/.env` ← new (API base URL)
- `vault/frontend/src/App.jsx` ← updated (import HealthCheck)

---

## Stage 2 — KT: New concepts in this component

### 1. VITE_API_URL — frontend environment variable

We never hardcode the API URL in code because:
- In development the API is at `http://localhost:8000`
- In production it will be at `https://yourdomain.com`

Vite reads from a `.env` file in the frontend folder:
```
VITE_API_URL=http://localhost:8000
```

In code, access it with:
```javascript
import.meta.env.VITE_API_URL
```

Rules:
- Must start with `VITE_` — Vite only exposes variables with this prefix to the browser
- Never put secrets here — this gets bundled into the JS the browser downloads

### 2. Conditional rendering — `{status && <p>...</p>}`

```jsx
{status && <p>Status: {status.status}</p>}
```

If `status` is `null` (before the button is clicked), nothing renders.
Once `status` has data, the `<p>` appears.

This is the React equivalent of:
```javascript
if (status) {
  element.textContent = status.status;
}
```

### 3. onClick on a button

```jsx
<button onClick={checkHealth}>Check Health</button>
```

`onClick` is React's event handler — equivalent to `addEventListener("click", ...)`.
You pass the function reference directly — no need to find the element by id first.

### 4. DevTools to watch during this component

| Tab | What to look for |
|---|---|
| Network | `GET /health` request — status 200, response JSON |
| Components | Click `HealthCheck` in tree — watch `status` state change from null to object after button click |
| Console | Any fetch errors will appear here |
