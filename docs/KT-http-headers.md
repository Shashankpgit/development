# KT — HTTP Headers

## What is an HTTP header?

Every HTTP request and response has two parts:

```
REQUEST
┌─────────────────────────────────────┐
│             HEADERS                 │
│  Content-Type: application/json     │
│  Authorization: Bearer abc123       │
│  Accept: application/json           │
├─────────────────────────────────────┤
│               BODY                  │
│  {"user_id": 1, "title": "Hello"}   │
└─────────────────────────────────────┘
```

Headers are **metadata** — information *about* the request, not the request data itself.
The body is the actual payload.

**Analogy:** Think of a parcel being shipped.
- Body = what's inside the box
- Headers = labels on the outside ("Fragile", "Contains glass", "Return address")

The server reads the labels before opening the box so it knows how to handle the contents.

---

## Common request headers

| Header | Purpose | Example |
|---|---|---|
| `Content-Type` | Format of the body being sent | `application/json`, `text/html`, `multipart/form-data` |
| `Accept` | Format the client wants back | `application/json` |
| `Authorization` | Credentials / token | `Bearer eyJhbGci...` |
| `Content-Length` | Size of the body in bytes | `42` |

---

## Why `Content-Type: application/json` is required

When a server receives a POST request, the body is raw bytes. Without `Content-Type`,
the server cannot know the format:

- Is it JSON? `{"user_id": 1}`
- Is it a URL-encoded form? `user_id=1&title=Hello`
- Is it a file upload?

`Content-Type: application/json` tells FastAPI:
> "Parse this body as JSON."

Without it, FastAPI returns `422 Unprocessable Entity` — it received the body but
couldn't parse it.

---

## The same header across all tools

All three tools we use send the same header — they just look different:

**curl:**
```bash
curl -X POST http://localhost:8000/notes \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "title": "Hello"}'
```

**Postman:**
When you select Body → raw → JSON, Postman adds this header automatically.
You can see it under the Headers tab in Postman.

**JavaScript fetch():**
```javascript
fetch("/notes", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ user_id: 1, title: "Hello" }),
})
```
`fetch()` does NOT add it automatically — you must include it yourself.

---

## How to see headers in DevTools

1. Open DevTools → Network tab
2. Make a POST request (e.g. click Save Note)
3. Click the request row
4. Click the **Headers** tab on the right

You will see:
- **Request Headers** — what your browser/JS sent to the server
- **Response Headers** — what the server sent back

`Content-Type: application/json` will appear under Request Headers.

---

## Response headers

The server also sends headers back with its response. FastAPI automatically adds:

```
Content-Type: application/json
```

...on all JSON responses. That's how your browser knows the response body is JSON
and can display it correctly in DevTools.

---

## Summary

- Headers = metadata about the request/response
- `Content-Type` tells the receiver the format of the body
- Without `Content-Type: application/json`, FastAPI cannot parse a POST body
- curl uses `-H`, Postman adds it automatically, `fetch()` requires you to set it manually
