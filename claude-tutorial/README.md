# Claude Mastery — Zero to Expert

> **Guide last updated:** June 17, 2026
> **Claude knowledge covers:** Claude Code CLI, claude.ai, Claude 4.x family (Sonnet 4.6, Opus 4.8, Haiku 4.5), MCP protocol, Skills, Agents, Memory system
> **Note:** Claude Code is actively developed. Some features evolve quickly — always check `claude --version` and the official docs for the newest additions.

---

## What This Guide Is

This is not a chatbot tutorial. It teaches you how to use Claude as a **professional software engineering tool** — the way engineers at fast-moving teams use it daily. After this guide you will:

- Use Claude Code CLI to automate real engineering work (not just Q&A)
- Configure projects so Claude understands your codebase without explanation every session
- Build multi-agent systems that parallelize complex tasks
- Extend Claude with MCP servers to connect it to your real tools
- Know which features to reach for in specific situations (DevOps, frontend, code review, design)

---

## The Learning Path — Follow This Order

Do not skip. Each section builds on the previous.

### Phase 1: Foundation (Days 1–2)
**Goal:** Understand what you're working with. No code yet.

| # | File | Time | What you'll learn |
|---|------|------|------------------|
| 1 | [00-foundation/00-the-claude-ecosystem.md](00-foundation/00-the-claude-ecosystem.md) | 20 min | Claude models, tools, and where each fits |
| 2 | [00-foundation/01-claude-ai-ui-mastery.md](00-foundation/01-claude-ai-ui-mastery.md) | 20 min | Claude.ai UI — features most people miss |

### Phase 2: Claude Code CLI (Days 3–5)
**Goal:** Use the terminal tool fluently.

| # | File | Time | What you'll learn |
|---|------|------|------------------|
| 3 | [01-claude-code-cli/00-installation-and-setup.md](01-claude-code-cli/00-installation-and-setup.md) | 20 min | Install, auth, first session |
| 4 | [01-claude-code-cli/01-modes-and-flags.md](01-claude-code-cli/01-modes-and-flags.md) | 20 min | All CLI flags, interactive vs non-interactive |
| 5 | [01-claude-code-cli/02-slash-commands.md](01-claude-code-cli/02-slash-commands.md) | 20 min | Every built-in slash command |
| 6 | [01-claude-code-cli/03-permissions-and-settings.md](01-claude-code-cli/03-permissions-and-settings.md) | 20 min | Settings, permission modes, hooks |

### Phase 3: Project Intelligence (Days 6–7)
**Goal:** Claude understands YOUR project, not just generic code.

| # | File | Time | What you'll learn |
|---|------|------|------------------|
| 7 | [02-project-setup/00-claude-md.md](02-project-setup/00-claude-md.md) | 20 min | CLAUDE.md — the most important file in your repo |
| 8 | [02-project-setup/01-memory-system.md](02-project-setup/01-memory-system.md) | 20 min | Persistent memory across sessions |

### Phase 4: Skills (Days 8–9)
**Goal:** Use and create slash-command shortcuts.

| # | File | Time | What you'll learn |
|---|------|------|------------------|
| 9 | [03-skills/00-what-are-skills.md](03-skills/00-what-are-skills.md) | 20 min | Skills vs slash commands vs prompts |
| 10 | [03-skills/01-built-in-skills.md](03-skills/01-built-in-skills.md) | 20 min | Every built-in skill and when to use it |
| 11 | [03-skills/02-custom-skills.md](03-skills/02-custom-skills.md) | 20 min | Building your own skills |

### Phase 5: Agents & Multi-Agent (Days 10–12)
**Goal:** Delegate complex tasks to specialized subagents.

| # | File | Time | What you'll learn |
|---|------|------|------------------|
| 12 | [04-agents/00-what-are-agents.md](04-agents/00-what-are-agents.md) | 20 min | Agent model, why they exist, mental model |
| 13 | [04-agents/01-agent-types.md](04-agents/01-agent-types.md) | 20 min | All agent types and their capabilities |
| 14 | [04-agents/02-workflows.md](04-agents/02-workflows.md) | 20 min | Workflow tool — orchestrating many agents |

### Phase 6: MCP Servers (Days 13–14)
**Goal:** Connect Claude to your real tools (GitHub, Slack, databases, design tools).

| # | File | Time | What you'll learn |
|---|------|------|------------------|
| 15 | [05-mcp-servers/00-what-is-mcp.md](05-mcp-servers/00-what-is-mcp.md) | 20 min | Model Context Protocol — what it is and why |
| 16 | [05-mcp-servers/01-installing-and-using.md](05-mcp-servers/01-installing-and-using.md) | 20 min | Install, configure, and use MCP servers |

### Phase 7: Real-World by Role (Days 15–19)
**Goal:** Master the patterns specific to YOUR work.

| # | File | Time | What you'll learn |
|---|------|------|------------------|
| 17 | [06-real-world-by-role/00-devops-engineer.md](06-real-world-by-role/00-devops-engineer.md) | 20 min | Infrastructure, CI/CD, Kubernetes with Claude |
| 18 | [06-real-world-by-role/01-backend-developer.md](06-real-world-by-role/01-backend-developer.md) | 20 min | APIs, databases, testing |
| 19 | [06-real-world-by-role/02-frontend-developer.md](06-real-world-by-role/02-frontend-developer.md) | 20 min | React, debugging UI, accessibility |
| 20 | [06-real-world-by-role/03-git-and-code-review.md](06-real-world-by-role/03-git-and-code-review.md) | 20 min | PRs, reviews, commits, history |

### Phase 8: Advanced Mastery (Days 20–22)
**Goal:** Use Claude at expert level.

| # | File | Time | What you'll learn |
|---|------|------|------------------|
| 21 | [07-advanced-mastery/00-prompt-engineering.md](07-advanced-mastery/00-prompt-engineering.md) | 20 min | Getting better results, fewer iterations |
| 22 | [07-advanced-mastery/01-context-management.md](07-advanced-mastery/01-context-management.md) | 20 min | Managing long sessions, compaction |
| 23 | [07-advanced-mastery/02-claude-api.md](07-advanced-mastery/02-claude-api.md) | 20 min | Using the API directly in your apps |

---

## The Three Levels of Claude Usage

Most people stay at Level 1 forever. This guide gets you to Level 3.

```
Level 1 — Chat Replacement
  Open claude.ai → type a question → copy the answer
  "Claude is like a better Google"
  Time savings: ~30 minutes/day

Level 2 — Coding Assistant  
  Use Claude Code CLI in your editor
  Ask it to write functions, explain code, fix bugs
  Time savings: ~2 hours/day

Level 3 — Engineering Partner   ← where this guide takes you
  Claude has persistent context about your project
  It runs multi-step tasks autonomously
  It spawns agents to work in parallel
  It connects to your real tools via MCP
  Time savings: ~4-6 hours/day
```

---

## Key Terms (Glossary)

| Term | What it means |
|------|--------------|
| **Claude Code** | The CLI tool you install (`npm install -g @anthropic/claude-code`) |
| **claude.ai** | The web interface at claude.ai |
| **Session** | One conversation with Claude Code (ends when you close the terminal) |
| **CLAUDE.md** | A file in your project root that gives Claude permanent project context |
| **Skill** | A named, reusable prompt invoked with a `/slash-command` |
| **Agent** | A separate Claude instance that does a specific subtask |
| **Subagent** | An agent spawned by Claude to parallelize work |
| **MCP Server** | A program that gives Claude access to external tools (GitHub, Slack, etc.) |
| **Tool** | A specific capability Claude has (Read, Write, Bash, Agent, etc.) |
| **Context window** | The amount of text Claude can hold in memory at once |
| **Compaction** | Automatic summarization when the context window fills up |
| **Permission mode** | How much Claude can do automatically vs asking for approval |
