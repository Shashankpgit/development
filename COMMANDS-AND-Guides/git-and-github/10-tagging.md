# Part 10 — Tagging: Marking Releases and Milestones

---

## What is a Tag?

A tag is a label attached to a specific commit — like a bookmark in your history. Unlike a branch (which moves forward with every new commit), **a tag never moves.** It permanently marks a specific point in time.

Tags are most commonly used to mark **release versions**:
- `v1.0.0` — first stable release
- `v2.3.1` — a patch release
- `v3.0.0-beta` — a pre-release

When you deploy your app to production, you tag that commit. Six months later if something breaks, you can instantly check out `v2.3.1` to see the exact code that was running.

---

## Two Types of Tags

### Lightweight Tags

A lightweight tag is just a name that points to a commit — nothing else. No extra information.

```bash
git tag v1.0.0
```

This tags the current commit as `v1.0.0`. That's it.

### Annotated Tags (recommended for releases)

An annotated tag is a full Git object. It stores:
- The tag name
- The tagger's name and email
- The date it was created
- A message (like a commit message)
- Can be signed with GPG

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
```

The `-a` flag means "annotated". The `-m` is the tag message.

**Use annotated tags for releases.** Lightweight tags are for personal, temporary bookmarks.

---

## `git tag` — Listing Tags

### List all tags:

```bash
git tag
```

Output:
```
v0.9.0
v1.0.0
v1.0.1
v1.1.0
v2.0.0
```

### Filter tags by pattern:

```bash
git tag -l "v1.*"
```

Output:
```
v1.0.0
v1.0.1
v1.1.0
```

---

## Creating Tags

### Tag the current commit:

```bash
# Annotated tag (recommended):
git tag -a v1.0.0 -m "Initial stable release"

# Lightweight tag:
git tag v1.0.0
```

### Tag a past commit (not the current one):

```bash
# Look up the hash you want to tag
git log --oneline
# Output:
# 7f0af4a (HEAD) feat: add deployment config
# 5b84053 feat: add payment processing  ← this is what we want to tag as v1.0.0
# 067906b feat: initial setup

# Tag a specific past commit
git tag -a v1.0.0 5b84053 -m "Version 1.0.0 - payment feature complete"
```

---

## Viewing Tag Details

### See what commit a tag points to and its metadata:

```bash
git show v1.0.0
```

For an annotated tag, output:
```
tag v1.0.0
Tagger: Shashank Patil <shashank@example.com>
Date:   Sat Jun 14 10:30:00 2026 +0530

Initial stable release

commit 5b84053f1e2d3c4b5a6f7e8d9c0b1a2f3e4d5c6b
Author: Shashank Patil <shashank@example.com>
Date:   Fri Jun 13 16:45:00 2026 +0530

    feat: add payment processing
...
```

---

## Pushing Tags to Remote

**Tags are NOT pushed automatically with `git push`.** You must push them explicitly.

```bash
# Push a specific tag
git push origin v1.0.0

# Push ALL tags at once
git push origin --tags

# Push all annotated tags only (not lightweight)
git push origin --follow-tags
```

After pushing, the tag appears on GitHub in the "Tags" section and under "Releases" (if you create a release from it on GitHub).

---

## Checking Out a Tag

```bash
git checkout v1.0.0
```

This puts you in **"detached HEAD"** state — you're at the tagged commit but not on any branch. This is fine for reading the code, but if you want to make changes based on this version, create a branch:

```bash
git switch -c hotfix-for-v1 v1.0.0
```

Now you're on a proper branch (`hotfix-for-v1`) that started at the `v1.0.0` tag.

---

## Deleting Tags

### Delete a local tag:

```bash
git tag -d v1.0.0
```

### Delete a tag on the remote:

```bash
git push origin --delete v1.0.0
# or
git push origin :refs/tags/v1.0.0
```

---

## Semantic Versioning — The Standard Tag Naming Convention

Most software uses **Semantic Versioning (semver)**: `MAJOR.MINOR.PATCH`

- `MAJOR` — breaking changes (API changed, not backwards compatible)
- `MINOR` — new features, backwards compatible
- `PATCH` — bug fixes, backwards compatible

Examples:
- `v1.0.0` → `v1.0.1` — bug fix
- `v1.0.1` → `v1.1.0` — new feature added
- `v1.1.0` → `v2.0.0` — breaking change (removed or changed existing feature)

Pre-release versions:
- `v2.0.0-alpha.1` — early testing, may change significantly
- `v2.0.0-beta.2` — feature-complete, bug fixes only
- `v2.0.0-rc.1` — release candidate, considered stable

---

## Common Misunderstanding: "git push pushes my tags too"

**The misunderstanding:** "When I `git push`, all my tags go up to GitHub automatically."

**The reality:** Tags are NOT included in a regular `git push`. This is intentional — tags are meant to be explicitly shared. If you make dozens of tags during development and they all got pushed automatically, it would clutter your remote.

To push tags, you must explicitly run:
```bash
git push origin --tags     # all tags
git push origin v1.0.0     # specific tag
```

You'll notice this especially when: you tag `v1.0.0` locally, go to GitHub, and don't see it in the Releases/Tags section. The fix is simply `git push origin --tags`.

---

## Next Step

Tags are marked. Now learn about the advanced commands that solve specific complex situations: cherry-pick, bisect, and the all-important reflog.

→ Continue to: `11-advanced-commands.md`
