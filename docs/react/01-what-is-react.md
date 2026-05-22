# What is React and Why Does It Exist?

## The problem with vanilla JS

In vanilla JS, every time data changes you manually update the DOM:

```javascript
// After deleting a note — manually rebuild the entire list
list.innerHTML = notes.map(note => `<li>...</li>`).join("");
```

This works for small apps. But as the app grows:
- 50+ components on a page
- Data coming from multiple API calls
- One piece of data affects multiple parts of the UI

Manually tracking "what needs to update when X changes" becomes unmanageable.

---

## What React solves

> When your data changes, the UI updates automatically.
> You describe WHAT the page should look like — React figures out HOW to update it.

You stop writing DOM instructions. You write a description of the UI.

---

## Imperative vs Declarative

This is the core mental shift.

**Vanilla JS — Imperative** (you give step-by-step instructions):
```
1. Find the list element
2. Clear it
3. Loop over notes
4. Build HTML strings
5. Inject into the DOM
```

**React — Declarative** (you describe the result):
```
"Show one NoteCard for each note in this array."
React handles all the DOM steps automatically.
```

Same outcome. Very different way of thinking.

---

## Real world analogy

**Imperative:** You give a chef step-by-step cooking instructions.
**Declarative:** You show the chef a photo of the finished dish.

React is the photo approach — you describe the end state, not the steps.
