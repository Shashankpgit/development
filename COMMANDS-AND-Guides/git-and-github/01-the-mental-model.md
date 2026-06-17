# Part 01 — The Git Mental Model (The Most Important Thing to Understand)

Before learning any commands, you must understand how Git thinks. Without this mental model, you will memorize commands but never understand *why* they work the way they do. With it, everything else clicks.

---

## The Three Areas

Every file in a Git project can live in one of three places. Understanding these three places is the key to understanding all of Git.

```
┌─────────────────────────────────────────────────────────────────┐
│                      Your Project Folder                        │
│                                                                 │
│   ┌──────────────┐   git add   ┌──────────────┐  git commit   │
│   │   Working    │ ──────────► │   Staging    │ ─────────────► │
│   │  Directory   │             │    Area      │                │
│   │              │ ◄────────── │  (Index)     │                │
│   │ (your files) │  git restore│              │                │
│   └──────────────┘             └──────────────┘                │
│                                                                 │
│                                        ┌───────────────────┐   │
│                                        │    Repository     │   │
│                                        │   (.git folder)   │   │
│                                        │                   │   │
│                                        │  commit history   │   │
│                                        └───────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 1. The Working Directory

This is your actual folder — the files you see when you open your project. When you edit a file with VS Code or any editor, you are changing the **working directory**.

Git knows about these files but does not automatically track changes to them. Editing a file does not mean Git has saved anything.

### 2. The Staging Area (also called the Index)

This is a holding area — a preview of your next commit. When you run `git add filename`, you are telling Git: "I want this change to be part of my next save point."

Think of it like packing a box before shipping. You pick specific items from your room (working directory) and put them in the box (staging area). Only when the box is sealed (`git commit`) does it become a permanent package.

Why does the staging area exist? Because you might change 10 files but only want to save 3 of them in your next commit. The staging area lets you be precise about what you're saving.

### 3. The Repository (the .git folder)

This is where the permanent history lives. When you run `git commit`, Git takes everything in the staging area and creates a permanent snapshot in the `.git` folder.

You almost never directly interact with the `.git` folder. Git manages it for you. But it's important to know it's just a regular folder — if you delete it, you lose your entire history.

---

## What is a Commit?

A commit is a **snapshot of your entire project at a specific moment in time.**

This is different from how most people think of version control. Git does not store *diffs* (what changed). It stores the complete state of every file. (Under the hood, it is clever about not duplicating unchanged files, but conceptually: a commit = a full snapshot.)

Each commit has:
- A **unique ID** (called a SHA or hash) — looks like `7f0af4a3b2...`
- A **message** — written by you, describing why you made this change
- A **timestamp** — when the commit was created
- **Author information** — who made it (from `git config`)
- A **pointer to the previous commit** — creating a chain

```
commit A ──► commit B ──► commit C ──► commit D  (latest)
```

This chain is the history of your project. You can go back to any commit and see the exact state of every file at that point.

---

## What is a Branch?

Here is the most important insight about branches that most people never learn:

**A branch is not a copy of your code. A branch is just a label (pointer) that points to a commit.**

```
commit A ──► commit B ──► commit C
                                 ▲
                               main  ← this is just a label
```

When you create a new branch, Git creates a new label pointing to the same commit:

```
commit A ──► commit B ──► commit C
                                 ▲
                               main
                               feature-login  ← new label, same commit
```

When you make a new commit on `feature-login`, the label moves forward — but `main` stays where it was:

```
commit A ──► commit B ──► commit C ──► commit D
                                 ▲              ▲
                               main      feature-login
```

This is why branches are cheap and fast in Git. Creating a branch is just creating a new label. No file copying happens.

---

## What is HEAD?

`HEAD` is a special label that always points to the commit you are currently "on" — your current position in history.

Usually, `HEAD` points to a branch, and the branch points to a commit:

```
HEAD
  │
  ▼
main
  │
  ▼
commit C
```

When you switch branches, `HEAD` moves to point to that branch. When you make a commit, the branch label moves forward to the new commit, and HEAD follows.

```
HEAD
  │
  ▼
feature-login
  │
  ▼
commit D
```

---

## What is "Detached HEAD"?

Sometimes you might see the message: `You are in 'detached HEAD' state`.

This happens when `HEAD` points directly to a commit instead of pointing to a branch. Think of it like: you've traveled back in time to an old commit, but you're not standing on any branch. If you make commits here, they float in history with no branch to hold them — they can be lost.

You'll learn how to handle this in the Undoing Changes guide.

---

## The Lifecycle of a File in Git

A file in your project can be in these states:

```
Untracked ──► git add ──► Staged ──► git commit ──► Committed (Unmodified)
                                                           │
                                             you edit it  │
                                                           ▼
                                                       Modified
                                                           │
                                              git add  │
                                                           ▼
                                                        Staged (again)
```

- **Untracked**: Git sees the file exists but is not tracking it (new file you haven't added yet)
- **Staged**: The file's current state is queued for the next commit
- **Committed / Unmodified**: The file matches exactly what was in the last commit
- **Modified**: The file has been changed since the last commit, but not yet staged

---

## Why This Model Matters (A Real Example)

Imagine you're fixing two bugs: bug-A in `login.js` and bug-B in `database.js`.

Without understanding the staging area, you'd commit both fixes together — which makes your history messy and harder to review.

With the staging area, you can do:

```bash
# Fix bug-A in login.js
# Fix bug-B in database.js

git add login.js           # Stage only the login fix
git commit -m "fix: resolve login timeout issue"

git add database.js        # Stage only the database fix
git commit -m "fix: correct SQL query in user lookup"
```

Now you have two clean, separate commits. If bug-A's fix causes a problem, you can undo only that commit without touching the database fix.

---

## Common Misunderstanding: "A branch is a copy of my code"

**The misunderstanding:** "When I create a new branch, Git makes a full copy of all my files so I can work separately."

**The reality:** A branch is just a lightweight pointer (label) to a commit. Creating a branch is almost instant and uses virtually no disk space, regardless of how large your project is. The actual files in your working directory are controlled by which branch is currently checked out — Git swaps files in and out as needed when you switch branches.

This is why:
- Creating 20 branches in Git costs almost nothing
- Switching between branches is fast even on a large project
- You should create branches freely and often — they're cheap

---

## Next Step

Now you understand how Git stores information. The next file covers the commands to actually start using a repository.

→ Continue to: `02-starting-a-repository.md`
