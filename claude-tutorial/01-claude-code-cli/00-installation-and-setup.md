# Claude Mastery — 02: Claude Code — Installation and First Session

> **Last updated:** June 17, 2026
> **Covers:** Installing Claude Code, authentication, first real session, what the interface looks like

**20-minute read. Get Claude Code installed and have your first real engineering session.**

---

## What You Need

- Node.js 18+ (check: `node --version`)
- npm or a package manager
- An Anthropic account (claude.ai)
- Optionally: VS Code, JetBrains (for IDE integration)

---

## Installation

```bash
# Install Claude Code globally
npm install -g @anthropic/claude-code

# Verify installation
claude --version
# Claude Code 1.x.x

# Alternative: use npx (no install, always latest)
npx @anthropic/claude-code
```

### IDE Extensions (Optional but Recommended)

```
VS Code:
  Extensions → search "Claude Code" → Install
  After install: Ctrl+Shift+P → "Claude Code: Open"

JetBrains (IntelliJ, PyCharm, WebStorm):
  Settings → Plugins → search "Claude Code" → Install

# After IDE extension install, Claude Code appears as a sidebar panel
# You get the full CLI experience inside your IDE
```

---

## Authentication

```bash
# Start authentication (first time only)
claude

# You'll be prompted to open a browser and log in to claude.ai
# After logging in, Claude Code is authenticated

# OR: authenticate with an API key (for CI/CD or servers)
export ANTHROPIC_API_KEY=sk-ant-...
claude  # uses the API key instead of browser auth
```

Where the auth token is stored:
```
~/.claude/  (Linux/macOS)
%APPDATA%\Claude\  (Windows)
```

---

## Starting a Session

```bash
# Navigate to your project first — ALWAYS
cd /path/to/your-project

# Start Claude Code
claude
```

**Why navigate to your project first?** Claude Code anchors itself to the current directory. From there it can:
- Read all files in the project
- Run commands relative to the project root
- Understand the project structure

```
❯ claude
╭────────────────────────────────────────────────────────────╮
│ ✻ Welcome to Claude Code!                                  │
│                                                            │
│ /path/to/vault-app                                         │
│                                                            │
│ Tips for getting started:                                  │
│  1. Ask me to do tasks, read files, or run commands        │
│  2. Use /help to see available commands                    │
│  3. Use /init to generate a CLAUDE.md for this project     │
╰────────────────────────────────────────────────────────────╯

> _
```

The `>` prompt is where you type. Claude Code is now running and has access to your project.

---

## Your First Real Session

Let's do something immediately useful — have Claude understand your project:

```
> What does this project do? Give me a tour of the codebase.
```

Claude will:
1. Read your `package.json`, `README.md`, or equivalent
2. Explore the directory structure
3. Read key files
4. Give you a coherent summary

This is the first superpower: **Claude reads your project, you don't have to explain it**.

```
> Are there any obvious issues with the Dockerfile?
```

Claude reads the Dockerfile and gives specific feedback based on YOUR actual file.

```
> Run the tests and tell me what's failing
```

Claude runs `npm test` (or whatever your test command is), reads the output, and explains the failures.

---

## The Interface — What You're Looking At

```
╭─────────────────────────────────────────────────────────────╮
│  Tool: Read                                                  │  ← Claude is reading a file
│  Path: src/api/routes.js                                     │
╰─────────────────────────────────────────────────────────────╯

╭─────────────────────────────────────────────────────────────╮
│  Tool: Bash                                                  │  ← Claude is running a command
│  Command: npm test                                           │
╰─────────────────────────────────────────────────────────────╯

Looking at the test output, I can see three failures:                ← Claude's response text

1. `auth.test.js` line 45 — JWT secret is missing from test env...
```

You see every tool use Claude makes — this is intentional. You're always in the loop.

**When Claude asks for permission:**
```
╭──────────────────────────────────────────────────────────────╮
│  Claude wants to run:                                         │
│                                                               │
│  npm test                                                     │
│                                                               │
│  [y] Yes   [n] No   [a] Always allow   [d] Don't allow      │
╰──────────────────────────────────────────────────────────────╯
```

- `y` — allow this once
- `n` — deny (Claude tries another approach)
- `a` — always allow this type of command (saved to settings)
- `d` — never allow this (saved to settings)

---

## Running a Single Task (Non-Interactive)

You don't have to be in an interactive session for every task:

```bash
# Run a single task and exit
claude "What tests are failing and why?"

# Equivalent: --print flag outputs to stdout, no interaction
claude --print "Summarize the changes in the last 3 commits"

# Pipe input to claude
git diff HEAD~3 HEAD | claude --print "What changed and what's the risk?"

# Non-interactive with working directory
claude -C /path/to/project --print "Is the Dockerfile production-ready?"
```

This is how you use Claude Code in shell scripts and CI/CD pipelines.

---

## Continuing a Previous Session

```bash
# Continue the most recent session
claude --continue

# Or inside a session, nothing to do — sessions are continuous until you exit
```

```bash
# Start Claude with a specific task immediately
claude "Review the security of the authentication module"
# Opens interactive session AND immediately starts the task
```

---

## Exiting a Session

```bash
# Type in the Claude prompt:
/quit       # exit Claude Code
/exit       # same

# Or: Ctrl+C (interrupt)
# Or: Ctrl+D (end of input)
```

---

## Checking Session Status

```bash
# Inside a session:
/status      # shows model, API usage, session info
/cost        # shows how many tokens used and estimated cost so far
```

```
> /status
Model: claude-sonnet-4-6
Session: active
Context used: 45,230 tokens
API calls this session: 23
```

---

## IDE Integration Workflow

When using Claude Code inside VS Code:

```
Ctrl+Shift+P → "Claude Code: Open Terminal Panel"
```

Claude Code opens as a panel BELOW your editor. Now:
1. You're looking at code in the editor
2. Claude Code is in the panel below
3. Claude can see all the files you have open
4. You can say "fix the error on line 42" and Claude reads the current file

**Pro tip for VS Code:** Use `Ctrl+\`` to toggle the terminal. Keep Claude Code running in one terminal panel, your normal terminal in another.

---

## Real-World Scenario: First Day With a New Codebase

You just joined a team and got access to the `vault-app` repo. Normal approach: spend 2-3 days reading code, asking teammates questions.

With Claude Code:

```bash
cd vault-app
claude
```

```
> Give me a full technical onboarding. I want to understand:
  1. What this app does
  2. How the code is organized
  3. The main data flows
  4. The deployment architecture
  5. Any tech debt or known issues (check TODO/FIXME comments, 
     old dependencies in package.json)
```

Claude reads the entire codebase and gives you a structured onboarding doc in ~2 minutes. It will:
- Read README, package.json, Dockerfile
- Explore src/ directory structure
- Read key route/controller/service files
- Check for TODOs and FIXMEs
- Look at CI/CD configs
- Read deployment manifests

What took 3 days now takes 15 minutes.

---

## Common Misunderstanding: "claude must be run from the project root"

**The misunderstanding:** "I have to `cd` to exactly the project root before running `claude`."

**The reality:** Claude Code uses wherever you run it as the "working directory." You can run it from any subdirectory — but Claude will have access to files relative to where you started it, and Bash commands run from that directory.

Best practice: run from the project root so Claude has access to everything. Running from a subdirectory limits Claude's view and may confuse it about relative paths.

```bash
# GOOD: full project context
cd ~/projects/vault-app
claude

# WORKS BUT LIMITED: claude only has easy access to backend/ subtree
cd ~/projects/vault-app/backend
claude
```

There's no hard enforcement — it's about giving Claude the context it needs.

→ Continue to: `01-modes-and-flags.md`
