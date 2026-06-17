# Claude Mastery — 17: Claude for Frontend Developers

> **Last updated:** June 17, 2026
> **Covers:** React, debugging UI bugs, accessibility, CSS, Figma-to-code, performance

**20-minute read. Frontend is where Claude's visual reasoning meets code generation.**

---

## Why Frontend Is Different

Frontend development has a challenge that backend doesn't: the output is visual. Claude can't SEE your UI — it reads code and infers what it renders.

To get good results:
1. **Describe the visual result you want, not just the component name.** "A card with a shadow, rounded corners, title on top, description below" > "a Card component"
2. **Screenshot + describe** is more powerful than describe alone. Paste a screenshot in claude.ai, then implement in Claude Code.
3. **Share design context** — which CSS framework, which component library, your color tokens.

---

## Your Claude Code Setup for Frontend

### CLAUDE.md example
```markdown
# vault-frontend — CLAUDE.md

## Stack
- React 19, TypeScript
- Vite (bundler)
- Tailwind CSS v4
- shadcn/ui (component library)
- React Query v5 (server state)
- Zustand (client state)
- React Router v7

## Design System
Colors: primary=#6366F1, background=#FAFAFA, text=#1E293B
Spacing scale: 4px base (Tailwind: p-1=4px, p-2=8px, p-4=16px)
Typography: Inter font family

## Component Patterns
- Components live in src/components/
- Page components live in src/pages/
- Shared hooks in src/hooks/
- API calls via React Query in src/api/

## Commands
npm run dev        → dev server at localhost:3000
npm run build      → production build
npm run type-check → TypeScript check without build
npm test           → Vitest unit tests

## Conventions
- All components are functional (no class components)
- Props interfaces named: ComponentNameProps
- Use shadcn/ui primitives before writing custom components
- Tailwind for all styling — no custom CSS files
```

---

## Day-to-Day Frontend Workflows

### Building Components

```
> "Build a PasswordCard component. It shows a password entry with:
   - Title and username on top row
   - Hidden password (show/hide toggle)
   - Copy button that shows a checkmark for 2 seconds after click
   - Three-dot menu with Edit, Delete options
   - Click the title to open a detail view
   Use our existing Tailwind classes and shadcn/ui components."

Claude:
1. Reads existing component files for patterns
2. Reads CLAUDE.md for color/spacing conventions
3. Builds the component with all described behavior
4. Includes TypeScript interfaces
5. Shows you the component structure before asking if you want it written
```

### Debugging Visual Bugs

```
> "The login form submits when I press Enter in the email field 
   but doesn't when I press Enter in the password field. Why?"

Claude:
1. Reads the LoginForm component
2. Identifies: password input is missing type="password" — it's type="text"
   (Pressing Enter in text inputs submits the form, 
    but type="password" wasn't triggering the form's onSubmit correctly)
3. Finds the actual issue: the Button has type="button" not type="submit"
4. Fixes both issues
```

```
> "The dropdown menu flickers when I hover near the edge of the 
   screen. Screenshots attached."

Claude:
1. Reads the dropdown component
2. Identifies: Framer Motion animation conflicting with position recalculation
3. Reads CLAUDE.md: shadcn/ui is the component library
4. Suggests: use shadcn DropdownMenu which handles positioning via Radix UI
5. Migrates the custom dropdown to the shadcn version
```

### TypeScript Errors

```
> "I'm getting: Type 'string | undefined' is not assignable to type 'string'"

Paste the error and the relevant file. Claude:
1. Reads the file
2. Identifies where the possibly-undefined value enters
3. Fixes with proper null coalescing or type guard
4. Explains: "The API response type has password as optional (string | undefined) 
   but the VaultCard props require a string. Add a fallback or make the prop optional."
```

---

## Figma to Code

If you have the Figma MCP server configured:

```
> "Implement the dashboard design from Figma. 
   File URL: figma.com/file/xxx"

Claude:
1. [Figma MCP] Reads the design file
2. Extracts: layout, spacing, colors, typography, component structure
3. Maps Figma properties to your Tailwind/design system
4. Builds the React components matching the design
5. Notes any design-to-code decisions it made
```

Without Figma MCP — describe the design or paste a screenshot in claude.ai:
```
> "Build this dashboard layout:
   - Left sidebar: 240px wide, dark bg, logo at top, nav links below
   - Main content: takes remaining width, light gray bg
   - Top bar: spans full width within main, white bg, search bar + avatar
   - Content area: 3-column stats cards, then a full-width table below
   
   Use Tailwind, match our design system from CLAUDE.md."
```

---

## Performance Optimization

```
> "The app feels slow when switching between pages. 
   Bundle size feels large."

Claude:
1. npm run build → reads the build output
2. Identifies large chunks
3. Checks for: non-lazy-loaded page components, large libraries loaded on first paint
4. Fixes:
   - Wraps page components in React.lazy() + Suspense
   - Code-splits heavy libraries (chart library, PDF viewer)
   - Adds Vite bundle analysis if not present
5. Shows before/after bundle sizes
```

```
> "The vault list is slow with 200+ items. Users are complaining."

Claude:
1. Reads the VaultList component
2. Identifies: rendering 200+ full DOM nodes, no virtualization
3. Recommends TanStack Virtual (already in your stack or easy to add)
4. Implements windowed list — only renders visible items
```

---

## Accessibility Audits

```
> "Audit the authentication flow for accessibility issues"

Claude:
1. Reads LoginPage, RegisterPage, ForgotPasswordPage
2. Checks for:
   - Missing aria-labels on icon-only buttons
   - Form inputs without associated labels
   - Error messages not announced to screen readers (missing role="alert")
   - Keyboard navigation issues (focus trapped in modal?)
   - Color contrast (Tailwind color vs WCAG AA 4.5:1 ratio)
3. Fixes all issues
4. Explains each change
```

---

## React Patterns and Refactoring

```
> "The UserContext is re-rendering the whole app too often. 
   Fix it without changing the API."

Claude:
1. Reads UserContext.tsx
2. Diagnoses: single context object with all user state — 
   any property change re-renders all consumers
3. Solution: split into UserDataContext and UserActionsContext
   (actions don't change reference, data changes are isolated)
4. Implements without changing the consumer API
```

```
> "Extract the pagination logic from this component into a 
   reusable hook"

Claude:
1. Reads the component
2. Extracts pagination logic to usePagination() hook
3. Makes it generic (works for any data type)
4. Replaces the inline logic with the hook
5. Shows how other components can now use it
```

---

## Component Testing

```
> "Write tests for the PasswordCard component"

Claude writes Vitest + React Testing Library tests:
- Renders without crashing
- Show/hide password toggle works
- Copy button shows checkmark after click
- Copy button reverts after 2 seconds
- Three-dot menu opens on click
- Edit option calls onEdit prop
- Delete option calls onDelete prop with the vault id
- Accessible: all interactive elements have accessible names
```

---

## Using Claude for Design Decisions

```
> "I need a way to show password strength. What are my options 
   given our stack?"

Claude: "Three approaches that fit your Tailwind + shadcn setup:

1. Progress bar (simplest):
   shadcn Progress component, colored by strength level
   (weak=red, medium=yellow, strong=green)

2. Segmented indicator (cleaner):
   4 colored divs that fill in as strength increases
   
3. Text + icon (most informative):
   Text label 'Weak/Fair/Good/Strong' + matching icon

Recommendation: segmented indicator — visually clear, 
fits well in a form without adding vertical space. 
Want me to build it?"
```

---

## Common Misunderstanding: "Claude can't do frontend without seeing the UI"

**The misunderstanding:** "Describing visual things to Claude is useless — it needs to see the UI."

**The reality:** There are two different tasks here:

1. **Building from scratch** — Claude works from your description. You describe the layout, Claude implements it. The result may need tweaks (font size, spacing) but the structure will be correct.

2. **Debugging existing UI** — If you can reproduce the bug in code (wrong behavior, TypeScript error, incorrect rendering), Claude can fix it from code alone. If the bug is "it looks slightly off," a screenshot in claude.ai + description in Claude Code is the right combo.

The workflow that works: use **claude.ai** (uploads images) to describe the visual problem, decide the fix, then use **Claude Code** to implement it. The two tools complement each other.

→ Continue to: `03-git-and-code-review.md`
