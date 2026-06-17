# Claude Mastery — 20: Context Management — Long Sessions and Compaction

> **Last updated:** June 17, 2026
> **Covers:** How context windows work, managing long sessions, compaction, best practices

**20-minute read. Understanding context lets you work efficiently without losing important information.**

---

## What Is a Context Window?

Every conversation with Claude has a **context window** — a maximum amount of text (tokens) that Claude can hold in its "working memory" at one time.

```
Context window = everything Claude can "see" right now:
  - The conversation history (your messages + Claude's responses)
  - File contents that have been read
  - Command outputs
  - Tool call results
```

When the context fills up, something has to give. Claude Code handles this automatically through **compaction**.

---

## Token Basics

A **token** is roughly ¾ of a word. Quick estimates:
- 1 line of code ≈ 10-20 tokens
- 1 KB of code ≈ 300-400 tokens
- Average JS file (200 lines) ≈ 2,000-4,000 tokens
- Large class (500 lines) ≈ 5,000-10,000 tokens

Claude Sonnet 4.6 context window: **200,000 tokens** (~150,000 words)

That sounds large. In practice, a long debugging session reading many files fills it faster than you'd expect.

---

## What Happens When Context Gets Full: Compaction

When your conversation approaches the context limit, Claude Code **compacts** it.

Compaction:
1. Summarizes the earlier conversation into a compressed form
2. Removes the raw message history that was summarized
3. Keeps the summary + recent messages
4. You see a notification: "Conversation compacted"

**What survives compaction:**
- Key decisions made
- Code changes implemented
- Important context (file paths, what errors were found)
- Recent messages (verbatim)

**What's lost:**
- Exact wording of early messages
- Intermediate reasoning
- Specific code snippets from early in the session (but the changes are in your files)

---

## Signs Your Context Is Getting Large

```
# Check current session status
> /status
```

Shows: model, context usage, cost, tokens spent this session.

```
# When Claude starts saying things like:
"I don't have the earlier part of our conversation available"
"Could you remind me what we decided about X?"
"I need to re-read the file to get the current state"

These signal: context was compacted, those details are gone.
```

---

## Commands for Managing Context

### `/compact` — Manually Compact the Context

```
> /compact
```

Forces compaction now, freeing up space before the automatic limit. Use this when:
- You've finished one task and starting a new one
- You've been reading lots of large files
- You want to ensure a clean context for a new problem

### `/clear` — Start Completely Fresh

```
> /clear
```

Wipes the entire conversation. Use this when:
- Moving to a completely unrelated task
- The current context has too much noise
- You want to restart a conversation that went off track

### `/new` — New Conversation Window

```
> /new
```

Opens a new Claude Code session. The current session continues in the old window.

### `/compact` vs `/clear`

| | `/compact` | `/clear` |
|--|-----------|---------|
| What's kept | Compressed summary | Nothing |
| When to use | Same task, need space | New task entirely |
| Recoverable? | Yes, summary preserved | No |

---

## Best Practices for Long Sessions

### 1. Let CLAUDE.md Hold Permanent Context

Instead of explaining your project at the start of every session, put it in CLAUDE.md. Claude reads it automatically. Your context window stays free for the actual work.

```
# Don't do this every session:
> "I'm working on a Node.js API with PostgreSQL. We use Jest for tests.
   Our error handling uses an AppError class..."

# Do this instead:
Write it in CLAUDE.md once. Claude reads it on session start.
```

### 2. Break Large Tasks Into Sessions

A session that solves one problem is more reliable than a session that solves ten.

```
Good session scope:
  Session 1: Design and implement the email verification feature
  Session 2: Write tests for the email verification feature
  Session 3: Integrate email verification into the registration flow

Too much for one session:
  Session 1: Implement email verification + payments + social auth + admin dashboard
```

### 3. Files Are Persistent — Context Is Not

When Claude implements something, it's in your files. Files don't disappear with context.

The context window is for the conversation and reasoning. Your actual work is safe in files.

```
If you're worried Claude will "forget" important decisions:
  → Write them to a file: "Write a summary of our auth design decisions to DECISIONS.md"
  → That file persists across sessions and can be read later
```

### 4. Use `/compact` at Transition Points

After finishing a sub-task, compact before starting the next:

```
> [finished implementing auth]
> /compact   ← compress that work, free up space
> "Now let's work on the email service"
```

### 5. Re-Anchor After Compaction

After compaction, Claude's recent context is a summary. For the next task, give it fresh context:

```
> "We're now adding pagination to the vault list API. 
   Read src/routes/vaults.js to understand the current state before we start."
```

This costs a few tokens to re-read, but ensures Claude's understanding is accurate.

---

## Working with Very Large Files

Large files eat context fast. Strategies:

### Tell Claude Which Part to Focus On

```
# Instead of: let Claude read the entire 2000-line service file
> "In src/services/vaultService.js, look at the create() 
   and update() functions (around lines 45-120). I need to add 
   transaction support to both."
```

### Summarize Large Files First

```
> "Summarize the structure of src/services/vaultService.js — 
   function names, what each does, what it returns. 
   Don't read the full implementation."
```

Then read specific functions when needed.

### Use Explore Agents for Large Codebases

```
> "Use an Explore agent to find all functions that call the database 
   without transaction support. Just return the function names and files."
```

Explore agents run in their own context — their work doesn't fill your main session context.

---

## Understanding the `--continue` Flag

```bash
# Resume the most recent session
claude --continue

# Resume a specific session
claude --continue --session-id <id>
```

When you close Claude Code and reopen it, `--continue` picks up where you left off. The conversation history (including any summaries from compaction) is reloaded.

```
# Typical workflow
claude                    # start new session
# ... work ...
# accidentally close terminal
claude --continue         # resume exactly where you left off
```

---

## Context in Multi-Agent Work

When Claude spawns agents, each agent gets its OWN context window. This is powerful:

```
Your session: 50k tokens used (half full)
  └── Agent 1: 0 tokens used (fresh context)
  └── Agent 2: 0 tokens used (fresh context)
  └── Agent 3: 0 tokens used (fresh context)
```

Each agent runs independently. The main session context only grows when the agents return their results. This is why agents are useful for large tasks — they don't consume your context window while they work.

---

## Cost and Context

Context size directly affects cost (you pay per token). Practical tips:

```
> /cost    ← see what you've spent this session
> /status  ← see token usage breakdown
```

What uses the most tokens:
1. Reading large files multiple times (Claude re-reads on each reference)
2. Long back-and-forth about the same problem
3. Including file contents in error messages

What doesn't cost much:
- Short questions and answers
- Simple code edits (diff is small)
- Bash commands with small output

---

## Common Misunderstanding: "Claude forgot what we discussed"

**The misunderstanding:** "Claude forgot our design decisions from earlier in the session."

**The reality:** There are three different things that could have happened:

1. **Context was compacted** — the early conversation was summarized. Key decisions should survive, but exact wording is gone. Ask Claude to recall: "What did we decide about the auth strategy?" It will tell you what it knows from the summary.

2. **You started a new session** without `/continue` — the new session has no history. Check if the previous session is still available with `claude --continue`.

3. **The information was never saved** — if it was discussed but never written to CLAUDE.md or a file, it only existed in the conversation. Going forward: important decisions → write them to a file.

The fix for all three: write important decisions to CLAUDE.md or a dedicated decisions file. Files survive forever. Context does not.

→ Continue to: `02-claude-api.md`
