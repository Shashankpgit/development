# Claude Mastery — 10: Agents — What They Are and Why They Matter

> **Last updated:** June 17, 2026
> **Covers:** Agent mental model, why subagents exist, the Agent tool, when to use agents

**20-minute read. Agents are Claude's way of parallelizing complex work — understand the model before using them.**

---

## The Problem Agents Solve

You ask Claude: "Audit the entire codebase for security vulnerabilities."

In a single context window:
```
Claude reads file 1... (3,000 tokens)
Claude reads file 2... (2,000 tokens)
Claude reads file 3... (4,000 tokens)
... 200 files later ...
Context: FULL — Claude starts forgetting earlier findings
Result: incomplete audit, some files never analyzed
```

With subagents:
```
Main Claude spawns 10 agents in parallel:
  Agent 1: audit src/api/     (fresh 200k context)
  Agent 2: audit src/auth/    (fresh 200k context)
  Agent 3: audit src/models/  (fresh 200k context)
  ...
Each agent runs in isolation, analyzes its area deeply
Main Claude collects all findings and synthesizes
Result: complete, deep audit of the entire codebase
```

Agents solve two problems:
1. **Scale** — tasks bigger than one context window
2. **Speed** — parallel work (10 agents working simultaneously = ~10x faster)

---

## What Is an Agent?

An agent is a separate Claude instance that:
- Has its own fresh context (no shared memory with the main Claude)
- Has access to the same tools (Read, Write, Bash, etc.)
- Runs a specific, bounded task
- Returns its result to the main Claude

Think of agents like worker processes. The main Claude is the orchestrator that spawns workers, collects their results, and synthesizes.

```
Main Claude (orchestrator)
     │
     ├── Agent 1: "Find all authentication endpoints" → returns list
     ├── Agent 2: "Find all database queries"        → returns list  
     ├── Agent 3: "Check Dockerfile security"        → returns findings
     │
     ▼
Main Claude: "Here are the security issues across all three areas..."
```

---

## The Agent Tool

Inside Claude Code, the main Claude uses the `Agent` tool to spawn a subagent:

```
You: "Audit the codebase for security issues"

Main Claude thinks: "This is a big codebase. I'll spawn agents 
to handle different areas in parallel."

Agent tool call:
  description: "Audit src/api/ for auth and injection vulnerabilities"
  prompt: "Analyze all files in src/api/ for: SQL injection,
           missing authentication, exposed sensitive data in logs.
           Report each issue with file:line and severity."
  
Agent 1 runs in isolation, reads all API files, returns findings.

Another Agent tool call (simultaneously):
  description: "Audit src/models/ for SQL injection"
  prompt: "Check all database model files for raw SQL 
           that could be injected. List any unsanitized inputs."

Agent 2 runs in isolation simultaneously with Agent 1.

Main Claude synthesizes both results.
```

You don't manually invoke the Agent tool — the main Claude decides when to spawn agents based on the task complexity and what you asked for.

---

## When Claude Uses Agents Automatically

Claude spawns agents when the task suggests it:
- "Analyze the ENTIRE codebase..."
- "Check ALL microservices..."
- "Find ALL occurrences of..."
- "For each of these 20 files..."
- "Run this analysis in parallel..."

Signals in your prompt that trigger agent use:
- Words like "all", "entire", "every", "parallel", "simultaneously"
- Lists of items that each need the same treatment
- Tasks obviously too large for one context

---

## When to Explicitly Request Agents

You can guide Claude toward using agents:

```
> "Audit each of our 5 microservices for security issues. Do them in parallel."

> "I need you to analyze these 30 log files. Check them simultaneously 
   and report which ones contain errors."

> "Review all pull requests opened in the last week. Use separate agents 
   for each one."
```

You can also control how many agents:
```
> "Use 3 agents in parallel to review different sections of this codebase"
```

---

## Agent vs Main Claude — What's Different

| | Main Claude | Subagent |
|--|-------------|----------|
| Memory | Full session context, CLAUDE.md, memories | Fresh — only what's in its prompt |
| Tools | All tools | All tools |
| Context | Knows everything discussed | Only knows what main Claude told it |
| Lifespan | Entire session | Single task, then done |
| Result | Ongoing conversation | Returns text to main Claude |

**Key implication:** Agents don't share context with each other or with the main Claude automatically. The main Claude must explicitly pass context in the agent prompt if the agent needs it.

---

## Foreground vs Background Agents

### Foreground (default)
Main Claude waits for the agent to complete before continuing. Use when you need the result before next steps.

```
You: "Which files in src/ have the most complex logic?"

[Claude spawns an agent]
[Main Claude waits]
[Agent returns analysis]
[Main Claude responds based on findings]
```

### Background
Agent runs while main Claude continues other work. Use for long-running tasks.

```
You: "Start a full dependency security audit in the background 
      while we work on the feature"

[Claude spawns background agent for security audit]
[Main Claude: "I've started the security audit in background. Let's work on the feature."]
[You work on the feature with main Claude]
[Security audit agent completes]
[Main Claude: "Background security audit is done. Found 3 HIGH issues."]
```

---

## Agent Types — Specialized Agents

Beyond generic agents, Claude Code has specialized agent types with custom capabilities:

| Agent Type | Purpose | Best for |
|------------|---------|----------|
| `Explore` | Fast, read-only code search | Finding files, locating symbols, answering "where is X?" |
| `Plan` | Architecture and design | Planning implementation strategy before coding |
| `code-reviewer` | Independent code review | Getting a second opinion with a fresh perspective |
| `claude-code-guide` | Claude Code questions | Questions about Claude Code features themselves |
| `general-purpose` | Catch-all | Complex multi-step tasks that don't fit others |

Full detail on each type: `01-agent-types.md`

---

## Real-World Scenario: Security Audit with Agents

```
You: "Perform a comprehensive security audit of the vault-app. 
      Be thorough — check the API, the database layer, the 
      authentication, the Dockerfile, and the K8s manifests."

Main Claude orchestrates:
  
  Agent 1 (Explore): "Map the codebase structure and identify 
  all security-sensitive areas"
  → Returns: file map with auth, API, database layers identified
  
  Agent 2 (code-reviewer): "Audit src/api/ for injection 
  vulnerabilities and missing auth"
  → Returns: 3 HIGH findings, 2 MEDIUM findings
  
  Agent 3 (code-reviewer): "Audit src/models/ for SQL injection"
  → Returns: 1 CRITICAL finding (raw SQL without escaping)
  
  Agent 4: "Audit Dockerfile and K8s manifests for 
  misconfigurations"
  → Returns: running as root, no resource limits, privileged container
  
  [All 4 agents run in parallel]
  [Main Claude synthesizes]

Main Claude: "Security Audit Results:

CRITICAL (fix before deploy):
  - src/models/user.js line 45: SQL injection via unsanitized email parameter

HIGH:
  - src/api/auth.js line 12: Missing rate limiting on login endpoint
  - ...

Container Security:
  - Dockerfile: running as root user — add USER directive
  - ..."
```

What took a human security engineer half a day took Claude 3 minutes. And every file was checked, not just a sample.

---

## Common Misunderstanding: "More agents = always better"

**The misunderstanding:** "I should always use as many agents as possible for speed."

**The reality:** Agents have overhead and tradeoffs:

1. **Each agent has fresh context** — if the task requires seeing the FULL picture to make decisions, splitting it across agents can produce inconsistent results (Agent 1 doesn't know what Agent 2 found).

2. **Synthesis takes time** — the main Claude has to read and combine all agent outputs, which itself costs tokens and time.

3. **Some tasks are sequential by nature** — "Fix the bug in step 1, then run the tests in step 2" can't be parallelized.

**When agents HELP:**
- Independent, parallel tasks (audit these 10 files separately)
- Tasks exceeding context limits (entire codebase analysis)
- Tasks where you want DIFFERENT perspectives (two independent code reviewers)

**When agents DON'T HELP:**
- Small tasks (spawning an agent to answer one question is overkill)
- Sequential tasks (each step depends on the previous)
- Tasks requiring global context (agent doesn't know what other agents found)

→ Continue to: `01-agent-types.md`
