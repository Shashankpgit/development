# Personal Vault — API Reference

All API documentation lives in this directory. One file per resource.

---

## Base URL

| Environment | URL |
|---|---|
| Local development | `http://localhost:8000` |
| Docker (Phase 6+) | `http://localhost` |
| Production (Phase 7+) | `https://yourdomain.com` |

---

## Authentication

- **Phase 1–2:** No authentication. All endpoints are open.
- **Phase 4+:** JWT Bearer token required on protected endpoints.
  ```
  Authorization: Bearer <token>
  ```

---

## Response format

All responses are JSON. Errors follow this shape:
```json
{
  "detail": "human readable error message"
}
```

---

## API files

| File | Resource | Added in |
|---|---|---|
| [health.md](health.md) | Server health | Phase 1 |
| [users.md](users.md) | User accounts | Phase 2 |
| [notes.md](notes.md) | Text notes | Phase 2 |
| [passwords.md](passwords.md) | Password entries | Phase 2 |
| [auth.md](auth.md) | Register + Login | Phase 4 |

---

## HTTP status codes used in this project

| Code | Meaning | When you see it |
|---|---|---|
| `200 OK` | Success | GET, PUT returned data |
| `201 Created` | Resource created | POST created a new record |
| `204 No Content` | Success, nothing to return | DELETE |
| `400 Bad Request` | Invalid input | Missing required field, wrong type |
| `401 Unauthorized` | Not authenticated | No token or invalid token |
| `403 Forbidden` | Authenticated but not allowed | Trying to access another user's data |
| `404 Not Found` | Resource doesn't exist | Note ID that doesn't exist |
| `422 Unprocessable Entity` | Validation failed | FastAPI's automatic input validation error |
| `500 Internal Server Error` | Server crashed | Bug in the code |
