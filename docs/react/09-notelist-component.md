# NoteList + NoteCard Components

## Stage 1 — What we are building

Two components:
- `NoteCard.jsx` — displays a single note (title + body)
- `NoteList.jsx` — fetches all notes for user_id=1 on load, renders a NoteCard for each

### Files
- `vault/frontend/src/components/NoteCard.jsx` ← new
- `vault/frontend/src/components/NoteList.jsx` ← new
- `vault/frontend/src/App.jsx` ← updated

### Vanilla JS equivalent (for comparison)
```javascript
const response = await fetch("/notes?user_id=1");
const notes = await response.json();
list.innerHTML = notes.map(note => `
  <li><strong>${note.title}</strong><p>${note.body}</p></li>
`).join("");
```

### React version
```jsx
// NoteList auto-fetches on load using useEffect
useEffect(() => {
  fetch(`${API_URL}/notes?user_id=1`)
    .then(res => res.json())
    .then(data => setNotes(data));
}, []);

// Renders a NoteCard for each note
notes.map(note => <NoteCard key={note.id} note={note} />)
```

---

## Stage 2 — KT: New concepts in this component

### 1. Component decomposition

NoteList is split into two components on purpose:
- `NoteList` — owns the data fetching and state
- `NoteCard` — only knows how to display one note, receives it as a prop

This mirrors the FastAPI pattern:
- Router = NoteList (orchestrates)
- Schema = NoteCard (defines the shape of one item)

### 2. useEffect auto-fetches on load

Unlike HealthCheck (which fetches on button click), NoteList fetches
automatically when the component first appears on screen:

```jsx
useEffect(() => {
  fetch(...)
}, []);   // ← empty array = run once on mount
```

No button needed. The data loads as soon as the page opens.

### 3. Passing the full note object as a prop

Instead of passing individual fields:
```jsx
<NoteCard title={note.title} body={note.body} />   // ← works but repetitive
```

We pass the whole object:
```jsx
<NoteCard note={note} />   // ← cleaner
```

Inside NoteCard: `{ note }` destructures the prop, then `note.title`, `note.body`.

### 4. DevTools to watch

| Tab | What to look for |
|---|---|
| Network | `notes?user_id=1` request fires automatically on page load — no button click needed |
| Components | Click `NoteList` → watch `notes` state go from `[]` to the array of notes |
| Components | Click `NoteCard` → see the `note` prop with all its fields |
