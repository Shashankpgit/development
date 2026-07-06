# Git & GitHub — 18: The Complete GitHub Features Map

> **Last updated:** June 25, 2026
> **Covers:** Every major feature GitHub offers — what it is, what it does, when you use it

**20-minute read. After this file you'll know WHAT GitHub can do. The next files go deep on each area.**

---

## GitHub Is Not Just a Git Host

Most developers use GitHub for one thing: storing code. But GitHub is a complete software development platform. Here's everything it includes:

```
GitHub Feature Landscape
─────────────────────────────────────────────────────────────
CODE                     COLLABORATION             AUTOMATION
  Repositories             Issues                    Actions (CI/CD)
  Branches & PRs           Discussions               Actions (Automation)
  Code Review              Wiki                      Scheduled Jobs
  Codespaces (cloud IDE)   Projects (Kanban)         Dependabot
  GitHub.dev (web editor)  Milestones                
                                                    SECURITY
DISTRIBUTION             PUBLISHING                  Code Scanning (SAST)
  Releases                 GitHub Pages              Secret Scanning
  Packages (registry)      GitHub Marketplace        Dependabot Alerts
  Gists                                              Security Advisories
                         ORGANIZATION
                           Teams & Roles             INSIGHTS
                           CODEOWNERS                Pulse (activity)
                           Branch Protection         Contributors graph
                           Audit Log                 Traffic analytics
```

---

## The Code Layer

### Repositories
The fundamental unit. Everything lives in a repository. Key types:
- **Public** — visible to anyone
- **Private** — visible only to you and collaborators
- **Internal** (Org) — visible to all org members
- **Template** — other repos can be created from this one (standardizes project structure)
- **Archived** — read-only, historical reference

### Pull Requests (PRs)
Not a Git feature — a GitHub feature. PRs are a request to merge one branch into another. They enable:
- Code review before merging
- Discussion on proposed changes
- Automated checks before merging (CI must pass)
- Draft PRs (show work in progress, not ready for review)
- Required reviewers
- Auto-merge when conditions met

### Code Review
GitHub adds a layer on top of Git diffs:
- Line-level comments
- Suggested changes (reviewer writes the fix inline)
- Review states: Approve / Request Changes / Comment
- Required approvals before merge
- Dismiss stale reviews when new commits are pushed

### Codespaces
A full VS Code IDE in the browser, running in a container. You open a repo → get a pre-configured development environment in 30 seconds. No local setup required.

### GitHub.dev
Press `.` on any GitHub repo → opens a web-based code editor instantly. Good for reading and small edits — no terminal, no running code. Use Codespaces for full development.

---

## The Collaboration Layer

### Issues
A tracking system built into every repo. Use for:
- Bug reports
- Feature requests
- Tasks
- Questions

Each issue has: title, description, labels, assignees, milestones, linked PRs, and a comment thread.

**Issue Templates**: Define structured forms for users to fill when creating issues. Ensures reporters include the info you need.

### Discussions
A forum-style feature (separate from Issues). Good for:
- Questions and Answers
- Ideas and feedback
- General announcements
- Polls

Unlike issues, discussions can be marked as answered and have categories.

### Projects (v2)
GitHub's project management board. Connects issues and PRs into:
- Kanban views (To Do / In Progress / Done)
- Table views (spreadsheet-like)
- Roadmap views (timeline/Gantt)
- Custom fields (priority, estimate, status)

Projects are independent of repos — one project can span multiple repos across an org.

### Milestones
Group issues and PRs by deadline or version. Example: milestone "v2.0 Release" contains all issues that must be done before v2.0 ships. Shows progress as a percentage.

### Wiki
A built-in documentation site for a repo. Uses Markdown. Good for: setup guides, architecture docs, onboarding. (Many teams use docs/ folder instead — easier to version control and review.)

---

## The Distribution Layer

### Releases
A formal snapshot of your code at a specific tag. A release includes:
- Version tag (v1.2.3)
- Release notes (what changed)
- Binary attachments (compiled executables, zip files)
- Auto-generated CHANGELOG from commit history

GitHub Releases are how you distribute software. Users go to the Releases page to download v1.2.3 of your tool.

### GitHub Packages
A registry for artifacts alongside your code. Supports:
- npm packages
- Docker images
- Maven/Gradle (Java)
- RubyGems
- NuGet (.NET)

Your GitHub Actions pipeline can push a Docker image to `ghcr.io/your-org/app:v1.2.3`. Other teams pull from that registry.

### Gists
Mini-repositories for sharing code snippets. Not full repos — just a single file or a few files. Good for sharing one-off scripts, config examples, code snippets.

---

## The Automation Layer

### GitHub Actions
Workflows triggered by events. A workflow is a YAML file in `.github/workflows/`. Triggers include: push, PR, issue creation, schedule (cron), manual, and more.

What Actions can do: see file `23-github-actions-all-use-cases.md` — it covers 20+ distinct use cases.

### Dependabot
Automatic dependency updates. Dependabot scans your `package.json`, `requirements.txt`, `Gemfile`, etc. and opens PRs to update outdated/vulnerable dependencies. Runs on a schedule you configure.

---

## The Security Layer

### Code Scanning (SAST)
Static analysis of your code for security vulnerabilities. Runs as a GitHub Action (using CodeQL or third-party scanners). Reports vulnerabilities as alerts in the Security tab.

### Secret Scanning
Scans every commit for accidentally committed secrets (API keys, tokens, passwords). Integrated with 150+ service providers — if you accidentally push an AWS key, GitHub notifies both you AND AWS to invalidate the key.

### Dependabot Alerts
When a vulnerability is published in a package you depend on, GitHub automatically creates an alert. You see it in the Security tab. Dependabot can auto-create a fix PR.

### Security Advisories
Create a private security advisory to work on a fix before public disclosure. Coordinate with reporters, draft the fix in a private fork, then disclose when ready.

### Branch Protection Rules
Require specific conditions before a branch can be merged to:
- PR must be approved by N reviewers
- CI must pass
- No direct pushes (force push blocked)
- Signed commits required
- Status checks must pass

---

## The Publishing Layer

### GitHub Pages
Host a static website directly from a repository. Free for public repos. Uses:
- `gh-pages` branch
- `docs/` folder in main
- GitHub Actions output directory

Common uses: project documentation, personal portfolio, landing pages.

### GitHub Marketplace
Find and install GitHub Apps and Actions from other developers. Apps integrate with GitHub's API to add features (code quality tools, project management integrations, notification services).

---

## The Organization Layer

### Organizations
A shared account for teams and companies. Under an org:
- Multiple repositories
- Teams of members with roles
- Centralized billing
- Org-wide policies

### Teams
Groups of org members. You grant a team access to repos (read, write, admin). Teams can be nested (frontend → web → mobile).

### CODEOWNERS
A file that defines who must review PRs touching specific files/directories. When someone opens a PR that changes `src/api/`, GitHub auto-requests review from the CODEOWNERS for that path.

### Audit Log
Every action by every member of an organization is logged: who pushed to what branch, who deleted a repo, who changed branch protection rules. Exportable for compliance.

---

## The Insights Layer

### Pulse
Weekly summary of a repo's activity: PRs opened/merged, issues opened/closed, active contributors.

### Contributors Graph
Visual history of commits per contributor over time.

### Traffic Analytics
For public repos: page views, unique visitors, top referring sites, popular content. Shows which docs pages people are visiting.

### Dependency Graph
Visual map of all your repo's dependencies — what packages you depend on, and who depends on you.

---

## GitHub vs Git — The Distinction

```
GIT                           GITHUB
──────────────────────────    ──────────────────────────────────
Local version control         Cloud hosting for git repos
Branches, commits, merges     Pull Requests (workflow on top of branches)
git log                       Issues, Projects, Discussions (project mgmt)
git tag                       Releases (distribution layer on top of tags)
Pre-commit hooks (local)      Actions (server-side automation)
.gitignore                    CODEOWNERS, Branch protection (governance)
Running on your machine       Teams, Orgs, Permissions (access control)
```

Everything in the left column works without GitHub. Everything in the right column is GitHub-specific and adds collaborative, automation, and governance layers on top.

---

## Common Misunderstanding: "I only need code hosting"

**The misunderstanding:** "I just push my code to GitHub. That's all I need it for."

**The reality:** Most developers use 5-10% of GitHub's feature set. The features they skip are the ones that would save them the most time:

- No Issues → bugs tracked in Slack messages that get buried
- No Projects → no visibility into what the team is working on
- No Branch Protection → junior devs push directly to main accidentally
- No Dependabot → vulnerabilities accumulate unnoticed for months
- No Actions → deployments are manual, error-prone, and undocumented
- No Releases → users can't find which version to download

You don't need ALL of these on day one. But knowing they exist means you reach for them when the pain point arrives.

→ Continue to: `19-github-issues-and-projects.md`
