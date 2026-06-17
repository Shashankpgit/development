# Claude Mastery — 00: The Claude Ecosystem

> **Last updated:** June 17, 2026
> **Covers:** Claude models (Claude 4.x family), Claude Code CLI, claude.ai, API

**20-minute read. Understand what you're working with before touching any tool.**

---

## The Problem This Guide Solves

Most people use Claude like this:

```
You → "Write me a function that sorts a list"
Claude → [code]
You → copy-paste into editor
You → "Now add error handling"
Claude → [more code]
```

This is fine. But it's like using a Formula 1 car to drive to the grocery store.

Claude is a **reasoning engine** that can:
- Hold your entire codebase in memory and reason across all of it
- Run shell commands, read files, write code, and verify it works
- Spawn multiple specialized agents to work in parallel
- Connect to GitHub, Slack, databases, and design tools
- Remember your preferences and project context across sessions

This guide teaches you all of that.

---

## The Three Ways to Use Claude

### 1. claude.ai — The Web Interface

```
URL: claude.ai
Best for: Exploration, writing, analysis, one-off questions
NOT ideal for: Software engineering work on your actual codebase
```

Claude.ai is a chat interface. It's powerful for:
- Researching new technologies
- Explaining concepts
- Drafting documents and communications
- Brainstorming architecture
- Asking questions without a specific codebase

Limitation: It cannot read your actual files, run commands in your project, or take actions on your computer. You paste code to it; it can't see your project directly.

### 2. Claude Code — The CLI Tool

```
Install: npm install -g @anthropic/claude-code
Command: claude
Best for: ALL software engineering work
```

Claude Code runs in your terminal, inside your project directory. It can:
- **Read your actual files** (not paste, real files)
- **Run shell commands** (npm test, docker build, kubectl apply)
- **Write and edit code** directly in your filesystem
- **Search your codebase** (grep, find, ast-grep)
- **Manage git** (commit, branch, PR creation)
- **Spawn agents** to do work in parallel

This is the primary tool this guide teaches.

### 3. The Claude API

```
URL: console.anthropic.com
Best for: Building applications that use Claude
```

The API lets you build Claude into your own applications — chatbots, code tools, data pipelines. Covered in section 07.

---

## The Claude Model Family (as of mid-2026)

Claude isn't one model — it's a family. Each has different speed/intelligence tradeoffs:

```
Claude Fable 5          ← newest, highest capability
Claude Opus 4.8         ← most intelligent (best for complex reasoning)
Claude Sonnet 4.6       ← balanced intelligence + speed  ← YOU ARE USING THIS
Claude Haiku 4.5        ← fastest, cheapest (good for simple tasks)
```

Claude Code uses Sonnet 4.6 by default. Switch to Opus for the hardest reasoning tasks with `/fast` (toggles Opus mode in Claude Code).

**How to think about which model to use:**
- Haiku: quick questions, simple code generation, fast iterations
- Sonnet: daily driver — coding, debugging, documentation, most tasks
- Opus: architecture decisions, complex multi-file refactors, security audits
- Fable 5: cutting-edge tasks, where maximum reasoning matters

---

## Claude Code vs claude.ai — Which To Use When

| Situation | Use | Why |
|-----------|-----|-----|
| You're in a project directory | Claude Code CLI | It can actually read your files |
| You want to explain a concept | claude.ai | No setup needed, good for learning |
| You want to write a document | Either | claude.ai has better formatting UI |
| Debugging a bug | Claude Code CLI | It runs your tests, reads logs |
| Asking "how does X work?" | claude.ai | Pure Q&A, no tools needed |
| Building a CI/CD pipeline | Claude Code CLI | It reads your existing configs |
| Brainstorming architecture | claude.ai | Good for whiteboard-style thinking |
| Deploying to Kubernetes | Claude Code CLI | It runs kubectl, reads your manifests |
| Writing a PRD or RFC | claude.ai | Better for long-form writing |
| Code review on a PR | Claude Code CLI | It sees the diff and full context |

Rule of thumb: **if the task involves files on your machine, use Claude Code CLI.**

---

## How Claude Code Works Under the Hood

Understanding this prevents confusion later.

```
Your message
     │
     ▼
Claude (language model)
     │
     │ Decides which tools to use
     ▼
┌─────────────────────────────────────────┐
│  Available Tools:                        │
│  Read        → reads a file              │
│  Write       → writes a file             │
│  Edit        → edits part of a file      │
│  Bash        → runs a shell command      │
│  Agent       → spawns a subagent         │
│  WebSearch   → searches the web          │
│  WebFetch    → fetches a URL             │
│  TodoCreate  → creates a task            │
└─────────────────────────────────────────┘
     │
     │ Tool results come back to Claude
     │ Claude reasons and decides next step
     ▼
Response to you
```

Claude is an **agent loop**: it uses tools, gets results, reasons, uses more tools, until the task is done. You don't have to manage this loop — Claude does it automatically.

This is why Claude can say "I'll run your tests and fix any failures" and actually do it — it runs the tests (Bash tool), reads the output, identifies failures, edits files (Edit tool), re-runs tests, and repeats until passing.

---

## What "Context Window" Means for Engineers

The context window is the amount of text Claude can hold in memory at one time. Think of it as working memory.

Current limits (approximate):
- Claude Sonnet 4.6: ~200,000 tokens (~150,000 words — about 200 average code files)
- Claude Opus 4.8: ~200,000 tokens

What counts toward the context:
- Your entire conversation history
- Every file Claude has read
- Every command output Claude has seen
- Every response Claude has generated

When it fills up: Claude Code automatically **compacts** the conversation — summarizes old turns to free up space, keeping the most important context. You see a notification when this happens. Work continues uninterrupted.

For software engineering: 200,000 tokens is enormous. You can have Claude read your entire small-to-medium codebase. For very large repos, it reads selectively (it searches first, then reads only relevant files).

---

## The Claude Code Permission Model

Claude Code has different levels of autonomy. You choose how much.

```
Level 1 — Ask for everything (default)
  Before every tool use: "Can I run npm test?" "Can I edit this file?"
  Safest. Slowest. Good when learning or on unfamiliar codebases.

Level 2 — Auto-approve safe operations
  Automatically: read files, search, grep
  Ask for: write, bash commands, network requests
  Best for daily use.

Level 3 — Fully autonomous (YOLO mode)
  Claude does everything without asking
  Good for: well-understood tasks, batch operations, CI/CD
  Risky for: unfamiliar codebases, anything with production access
```

How to control this: covered in `01-claude-code-cli/03-permissions-and-settings.md`.

---

## Real-World Scenario: What "Level 3" Claude Looks Like

Here's a real task from a DevOps engineer:

```
You: "Our staging deployment is failing. The pods are in CrashLoopBackOff. 
      Fix it and deploy the fix."

Claude (autonomously):
  1. Runs: kubectl get pods -n staging
  2. Runs: kubectl logs vault-api-7d4b9c -n staging
  3. Reads: the Dockerfile, the deployment.yaml
  4. Sees: missing env var DATABASE_URL in the deployment
  5. Reads: values.staging.yaml
  6. Edits: values.staging.yaml to add the missing env var
  7. Runs: helm upgrade vault-app --values values.staging.yaml
  8. Runs: kubectl rollout status deployment/vault-api -n staging
  9. Confirms: pods are Running
  10. Reports: "Fixed — the DATABASE_URL env var was missing from staging 
       values. Added it and redeployed. All pods are now Running."
```

You gave one instruction. Claude did 10 steps. That's the value of Claude Code.

---

## Common Misunderstanding: "Claude Code is just GitHub Copilot"

**The misunderstanding:** "Claude Code is an autocomplete tool that suggests the next line of code."

**The reality:** GitHub Copilot completes code as you type. Claude Code is fundamentally different:

| | GitHub Copilot | Claude Code |
|--|---------------|-------------|
| Trigger | As you type | You ask it |
| Scope | Current file | Entire project |
| Actions | Suggests text | Reads, writes, runs commands |
| Memory | None | Remembers across the session |
| Multi-file | No | Yes |
| Runs tests | No | Yes |
| Manages git | No | Yes |
| Deploys | No | Yes (with proper setup) |

Claude Code is closer to "a junior engineer working on your machine" than an autocomplete tool.

→ Continue to: `01-claude-ai-ui-mastery.md`
