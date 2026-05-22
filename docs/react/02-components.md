# Components

## What is a component?

A component is a **JavaScript function that returns UI**.

That's the entire definition. A function. Takes some input data. Returns what to show on screen.

```jsx
function NoteCard({ title, body }) {
  return (
    <div className="note-card">
      <strong>{title}</strong>
      <p>{body}</p>
    </div>
  );
}
```

---

## How a page is built from components

Instead of one big HTML file, a React page is a tree of components:

```
<App />
├── <Header />
├── <NoteForm />
└── <NoteList />
    ├── <NoteCard />
    ├── <NoteCard />
    └── <NoteCard />
```

Each component owns one piece of the UI. Small, focused, reusable.

---

## Props — passing data into a component

Props are the inputs to a component. Same idea as function arguments.

```jsx
// Defining the component — title and body are props
function NoteCard({ title, body }) {
  return <div><strong>{title}</strong><p>{body}</p></div>;
}

// Using the component — passing values as props
<NoteCard title="Shopping list" body="Milk, eggs, bread" />
<NoteCard title="Meeting notes" body="Discussed Q3 roadmap" />
```

Props flow **downward** — from parent component to child component.
A child never modifies its own props. It only reads them.

---

## Comparison with vanilla JS

| Vanilla JS | React |
|---|---|
| One big `index.html` + `app.js` | Many small component files |
| Build HTML strings manually | Return JSX from a function |
| Manually find and update DOM elements | React updates DOM automatically |
| Reuse via copy-paste | Reuse via component with different props |

---

## What is JSX?

JSX is HTML-like syntax written inside JavaScript files.

```jsx
// This looks like HTML but it's inside a .jsx file
function Header() {
  return <h1>Personal Vault</h1>;
}
```

JSX is **not** a browser feature. It gets compiled down to plain JavaScript before the browser sees it. This is why React needs a build step — the browser cannot run JSX directly.

Under the hood, JSX compiles to:
```javascript
React.createElement("h1", null, "Personal Vault")
```

You write JSX because it's readable. The build tool converts it.

---

## Key rules of JSX

1. **Use `className` instead of `class`** — `class` is a reserved word in JS
   ```jsx
   <div className="note-card">  ✓
   <div class="note-card">      ✗
   ```

2. **Every component must return one root element**
   ```jsx
   // ✓ one root div wrapping everything
   return <div><h1>Title</h1><p>Body</p></div>;

   // ✗ two root elements — invalid
   return <h1>Title</h1><p>Body</p>;
   ```

3. **JavaScript expressions go inside `{}`**
   ```jsx
   return <p>{note.title}</p>;          // variable
   return <p>{2 + 2}</p>;               // expression
   return <p>{isAdmin ? "Admin" : "User"}</p>;  // ternary
   ```
