# useEffect and Fetching Data

## What is useEffect?

`useEffect` is how you run code that has a **side effect** — anything that
happens outside of rendering. The most common side effect: fetching data from an API.

```jsx
import { useState, useEffect } from "react";

function NoteList() {
  const [notes, setNotes] = useState([]);

  useEffect(() => {
    fetch("/notes?user_id=1")
      .then(res => res.json())
      .then(data => setNotes(data));
  }, []);  // ← the empty [] means: run this once when the component first loads

  return (
    <ul>
      {notes.map(note => <li key={note.id}>{note.title}</li>)}
    </ul>
  );
}
```

---

## When does useEffect run?

The second argument to `useEffect` is the **dependency array**.

| Dependency array | When it runs |
|---|---|
| `[]` (empty) | Once — when the component first appears on screen |
| `[userId]` | Every time `userId` changes |
| nothing (omitted) | Every render — almost never what you want |

For fetching data on page load: always use `[]`.

---

## The full data fetch pattern

This is the pattern you will use everywhere:

```jsx
function NoteList({ userId }) {
  const [notes, setNotes] = useState([]);     // 1. start with empty data
  const [loading, setLoading] = useState(true); // 2. track loading state

  useEffect(() => {
    fetch(`/notes?user_id=${userId}`)          // 3. fetch from API
      .then(res => res.json())
      .then(data => {
        setNotes(data);                         // 4. store in state
        setLoading(false);                      // 5. mark as done
      });
  }, [userId]);                                // 6. re-fetch if userId changes

  if (loading) return <p>Loading...</p>;       // 7. show loading state

  return (
    <ul>
      {notes.map(note => (
        <li key={note.id}>{note.title}</li>
      ))}
    </ul>
  );
}
```

---

## Comparison with vanilla JS

**Vanilla JS:**
```javascript
// You wire this to a button click
document.getElementById("load-btn").addEventListener("click", () => {
  fetch("/notes?user_id=1")
    .then(res => res.json())
    .then(notes => {
      list.innerHTML = notes.map(n => `<li>${n.title}</li>`).join("");
    });
});
```

**React:**
```jsx
// Runs automatically when component loads — no button needed
useEffect(() => {
  fetch("/notes?user_id=1")
    .then(res => res.json())
    .then(data => setNotes(data));  // React updates DOM automatically
}, []);
```

---

## The key of each list item

You noticed `key={note.id}` in the list. React requires a unique `key`
on each item when rendering a list. It uses this to track which items
changed, were added, or were removed — so it only updates what's necessary.

```jsx
// ✓ correct — unique id as key
notes.map(note => <li key={note.id}>{note.title}</li>)

// ✗ wrong — index as key (breaks when list order changes)
notes.map((note, index) => <li key={index}>{note.title}</li>)
```

---

## Summary — the 3 hooks you need for our vault app

| Hook | Purpose |
|---|---|
| `useState` | Store data that can change (notes list, form input values) |
| `useEffect` | Fetch data when a component loads |
| Both together | The standard pattern for any data-driven component |
