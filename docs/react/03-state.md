# State

## What is state?

State is **data that belongs to a component and can change over time**.

When state changes, React automatically re-renders the component — the UI
updates to reflect the new data. You never touch the DOM manually.

---

## useState — the hook for state

```jsx
import { useState } from "react";

function Counter() {
  const [count, setCount] = useState(0);  // initial value is 0

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>+1</button>
    </div>
  );
}
```

`useState(0)` returns two things:
- `count` — the current value
- `setCount` — a function to update it

When you call `setCount(count + 1)`, React:
1. Updates the value
2. Re-renders the component
3. The `<p>` now shows the new count

You never write `document.getElementById(...).textContent = count`.
React does that step for you.

---

## Vanilla JS vs React state

**Vanilla JS:**
```javascript
let count = 0;

document.getElementById("btn").addEventListener("click", () => {
  count++;
  document.getElementById("counter").textContent = count;  // manual DOM update
});
```

**React:**
```jsx
const [count, setCount] = useState(0);

// Just call setCount — React handles the DOM
<button onClick={() => setCount(count + 1)}>+1</button>
```

React removes the manual DOM step entirely.

---

## State for our vault app

In our NoteList component, the notes array is state:

```jsx
function NoteList() {
  const [notes, setNotes] = useState([]);  // starts empty

  // When notes changes, React automatically re-renders the list
  return (
    <ul>
      {notes.map(note => <NoteCard key={note.id} title={note.title} />)}
    </ul>
  );
}
```

When we fetch notes from the API and call `setNotes(data)`, the list
re-renders automatically. No `innerHTML`, no manual DOM work.

---

## Props vs State — the key difference

| | Props | State |
|---|---|---|
| Who owns it | Parent passes it in | The component itself |
| Can it change | No — read only | Yes — via setter function |
| What it's for | Input data | Data that changes over time |
