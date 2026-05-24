# NoteForm Component

## Stage 1 — What we are building

A form with title and body inputs. On submit, calls `POST /notes` and
tells NoteList to refresh so the new note appears immediately.

### Files
- `vault/frontend/src/components/NoteForm.jsx` ← new
- `vault/frontend/src/components/NoteList.jsx` ← updated (receives onNoteAdded callback)
- `vault/frontend/src/App.jsx` ← updated (wires NoteForm and NoteList together)

---

## Stage 2 — KT: New concepts in this component

### 1. Controlled inputs

Every input's value is stored in state and kept in sync:

```jsx
const [title, setTitle] = useState('');

<input value={title} onChange={e => setTitle(e.target.value)} />
```

React owns the value — not the browser. This is called a controlled input.

### 2. Lifting state up — callback props

NoteForm creates a note. NoteList shows notes. They are siblings — neither
is parent of the other. How does NoteList know to refresh after NoteForm submits?

Answer: lift the responsibility up to App, pass a callback down:

```
App
├── NoteForm  onNoteAdded={refresh}  ← calls refresh after POST
└── NoteList  onNoteAdded={refresh}  ← refresh re-fetches notes
```

App owns the refresh function and passes it to both children as a prop.
This is called "lifting state up" — the most common React pattern for
sibling communication.

### 3. POST request from fetch

```javascript
fetch(`${API_URL}/notes`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ user_id: 1, title, body }),
});
```

Same as vanilla JS and Postman — method, Content-Type header, JSON body.

### 4. DevTools to watch

| Tab | What to look for |
|---|---|
| Network | POST /notes on submit — check Payload tab for the JSON body sent |
| Network | GET /notes?user_id=1 fires right after — that is the auto-refresh |
| Components | NoteForm state clears after submit (title and body back to empty) |
