# Git & GitHub — 19: Issues, Projects, and Team Coordination

> **Last updated:** June 25, 2026
> **Covers:** GitHub Issues, Labels, Milestones, Issue Templates, Projects v2, the real-world team workflow

**20-minute read. How GitHub replaces your Jira, Trello, or sticky notes.**

---

## Why Issues Exist

Every software project has three types of work:
1. Something is broken (bug)
2. Something doesn't exist yet (feature request)
3. Something needs to change (improvement/tech debt)

Email, Slack, and verbal conversations are terrible at tracking these because they get buried, forgotten, and can't be linked to the code change that fixes them.

GitHub Issues keeps these in the same place as your code. An issue links directly to the PR that fixes it, which links to the exact commit. You get a complete audit trail: "what was wrong → who fixed it → what changed."

---

## Creating an Issue

```
GitHub repo → Issues → New Issue

Fields:
  Title:       Short description of the problem
  Description: Full context (what happened, what was expected, steps to reproduce)
  Labels:      bug / enhancement / documentation / help wanted / etc.
  Assignees:   Who is responsible for fixing this
  Milestone:   Which version/sprint this belongs to
  Projects:    Which project board this should appear on
```

### Issue Description Best Practices

```markdown
## What happened?
POST /api/auth returns 500 when the email field is empty.
Currently returns: HTTP 500 Internal Server Error
Expected: HTTP 400 Bad Request with "email is required"

## Steps to reproduce
1. Send POST /api/auth with body: {}
2. See 500 error in response

## Environment
- Node.js 20.x
- Express 5
- Production and staging both affected

## Relevant logs
TypeError: Cannot read properties of undefined (reading 'toLowerCase')
  at validateEmail (src/middleware/auth.js:34)
```

The issue is self-contained. A developer reading it 6 months later understands the full context without asking anyone.

---

## Linking Issues to PRs

When your PR fixes an issue, close it automatically with keywords in the PR description:

```
Closes #42
Fixes #42
Resolves #42
```

When the PR merges → issue #42 automatically closes. The issue shows "Closed in PR #57."

This creates the full chain: `Issue #42 (bug report)` → `PR #57 (fix)` → `Commit abc1234`.

---

## Labels — Organizing Issues

Labels are colored tags. GitHub creates default labels:

| Default Label | Meaning |
|---------------|---------|
| `bug` | Something isn't working |
| `enhancement` | New feature or request |
| `documentation` | Improvements or additions to docs |
| `good first issue` | Good for newcomers |
| `help wanted` | Extra attention is needed |
| `question` | Further information is requested |
| `wontfix` | This will not be worked on |

### Custom Label System (Real-World)

```
Type labels:
  bug             red
  feature         blue  
  tech-debt       orange
  security        dark red

Priority labels:
  p0-critical     red (production down)
  p1-high         orange (major feature blocked)
  p2-medium       yellow (normal priority)
  p3-low          green (nice to have)

Status labels:
  needs-triage    gray (not yet reviewed)
  in-progress     purple
  blocked         dark red
  ready-for-qa    teal

Team labels:
  team-backend    indigo
  team-frontend   pink
  team-devops     brown
```

Filter issues by label:
```
# Issues your team owns that are high priority and unassigned
Labels: p1-high + team-backend + (no assignee)
```

---

## Issue Templates — Structured Forms

Without templates, people write incomplete issue reports. With templates, they fill in a structured form.

```
.github/
  ISSUE_TEMPLATE/
    bug_report.yml
    feature_request.yml
    security_vulnerability.yml
```

```yaml
# .github/ISSUE_TEMPLATE/bug_report.yml
name: Bug Report
description: Something isn't working
labels: ["bug", "needs-triage"]
assignees: []
body:
  - type: markdown
    attributes:
      value: "## Before Submitting — Search existing issues to avoid duplicates"

  - type: input
    id: summary
    attributes:
      label: What happened?
      placeholder: "POST /api/auth returns 500 when email is empty"
    validations:
      required: true

  - type: textarea
    id: reproduce
    attributes:
      label: Steps to reproduce
      placeholder: "1. Send request...\n2. See error..."
    validations:
      required: true

  - type: input
    id: expected
    attributes:
      label: Expected behavior
      placeholder: "Should return 400 Bad Request"

  - type: dropdown
    id: severity
    attributes:
      label: Severity
      options:
        - P0 - Production Down
        - P1 - Major Feature Broken
        - P2 - Normal Priority
        - P3 - Minor / Cosmetic
    validations:
      required: true

  - type: textarea
    id: logs
    attributes:
      label: Relevant logs or screenshots
      render: shell
```

Now when someone opens a new issue, they see a form — not a blank text box.

---

## Milestones — Tracking Versions

A milestone groups issues by what version or sprint they belong to.

```
Milestone: v2.0.0 — Target: July 31, 2026
  Progress: 12/20 issues closed (60%)
  
  Open issues (8 remaining):
    □ Add email verification
    □ Add password strength meter
    □ Mobile layout fixes
    ...
  
  Closed issues (12 done):
    ✓ User registration API
    ✓ Login with JWT
    ✓ Forgot password flow
    ...
```

When you look at a milestone, you immediately know how far from release you are.

---

## GitHub Projects (v2) — The Kanban Board

Projects connect issues and PRs from any repo into a visual board.

### Creating a Project

```
GitHub → Your Profile (or Org) → Projects → New Project
Templates: Board / Table / Roadmap

Add issues: "Add item" → search for any issue/PR across your repos
```

### Board View (Kanban)

```
┌─────────────┬─────────────┬─────────────┬─────────────┐
│   Backlog   │  In Progress│    Review   │    Done     │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ #45 Add     │ #38 JWT     │ #35 Login   │ #30 Setup   │
│ export feat │ refresh     │ UI fixes    │ database    │
│             │             │             │             │
│ #47 Dark    │             │             │ #28 Auth    │
│ mode        │             │             │ middleware  │
│             │             │             │             │
│ #50 Mobile  │             │             │             │
│ nav fixes   │             │             │             │
└─────────────┴─────────────┴─────────────┴─────────────┘
```

### Table View (Spreadsheet)

For issues with custom fields:

```
Issue           | Status      | Priority | Sprint | Assignee    | Estimate
─────────────────────────────────────────────────────────────────────────
#38 JWT refresh | In Progress | P1-High  | S4     | @shashank   | 3 days
#45 Export feat | Backlog     | P2-Med   | S5     | unassigned  | 5 days
#47 Dark mode   | Backlog     | P3-Low   | S5     | @developer  | 2 days
```

### Roadmap View (Timeline)

Visual calendar view — drag items to set dates. Shows what's planned for which month.

### Automations in Projects

Projects can automatically move issues:
- Issue opened → add to "Backlog"
- PR merged → move linked issue to "Done"
- Issue labeled "in-progress" → move to "In Progress" column

---

## Real-World Team Workflow

Here's how Issues + Projects + PRs work together for a team:

```
Monday Sprint Planning:
  Product Manager creates issues in GitHub
  Team assigns issues, sets sprint, adds to Project board
  Issues move to "In Progress" column

During the Week:
  Developer picks issue #38 from the board
  Creates branch: git switch -c feature/jwt-refresh
  Works on code
  Pushes branch

  Opens PR with description:
    "Closes #38 — Add JWT refresh token endpoint
     
     Changes:
     - Added POST /api/auth/refresh endpoint
     - Token rotation on each refresh
     - 30-day refresh token expiry
     
     Test plan: see tests/auth/refresh.test.js"
  
  PR linked to issue #38 → issue moves to "Review" column (automation)
  
  Team member reviews PR, approves
  
  CI passes (GitHub Actions)
  
  PR merged → issue #38 automatically closes → moves to "Done"

Friday Sprint Review:
  Project board shows what was completed
  Milestone shows new % progress toward release
```

---

## Searching and Filtering Issues

```
# In GitHub UI, filter bar:
is:open is:issue label:bug assignee:@me         → your open bugs
is:open is:issue milestone:"v2.0.0" no:assignee → unassigned v2 issues
is:open is:pr review-requested:@me              → PRs waiting for your review
is:issue label:p0-critical is:open              → critical open issues
```

```bash
# With the gh CLI (from terminal)
gh issue list --label "bug" --assignee "@me"
gh issue list --milestone "v2.0.0" --state open
gh issue create --title "JWT returns 500" --body "..." --label "bug"
gh issue close 42 --comment "Fixed in PR #57"
```

---

## Common Misunderstanding: "Issues are only for bugs"

**The misunderstanding:** "We use Jira for project management. GitHub Issues are just for bug reports from users."

**The reality:** GitHub Issues is a full task tracker. The distinction many teams don't realize:

Issues can be created for ANYTHING:
- Bugs (of course)
- Features being built
- Tech debt: "Migrate auth from callbacks to async/await"
- Documentation tasks: "Write deployment runbook"
- Research spikes: "Evaluate Redis vs Memcached"
- Decisions: "Should we use GraphQL or REST?"
- Questions from external contributors

When you keep all work in Issues (not Jira + GitHub split), you get one thing that's invaluable: every PR automatically links to the work item it implements. You never ask "why was this code changed?" — you trace commit → PR → issue → original requirement.

→ Continue to: `20-github-releases-and-packages.md`
