# Claude Mastery — 03: Claude Code — Modes and Flags

> **Last updated:** June 17, 2026
> **Covers:** All CLI flags, interactive vs non-interactive mode, pipe usage, headless CI

**20-minute read. Know every way to run Claude Code — you'll use all of these.**

---

## All CLI Flags Reference

```bash
claude [options] [prompt]

# Core flags
--help, -h                    # show help
--version, -v                 # show version

# Session control
--continue, -c                # resume the most recent session
--resume <session-id>         # resume a specific session by ID
--new                         # start a fresh session (ignores --continue default)

# Output control
--print, -p                   # print response to stdout and exit (non-interactive)
--output-format <format>      # output format: text (default), json, stream-json

# Model selection
--model <model-id>            # use a specific model
                              # e.g. --model claude-opus-4-8

# Working directory
-C <path>                     # change working directory before starting

# Context
--system-prompt <text>        # add a system prompt for this session
--append-system-prompt <text> # append to the default system prompt

# Permission mode
--dangerously-skip-permissions # skip all permission prompts (YOLO mode)
                               # WARNING: Claude can do anything without asking

# Verbose / debug
--verbose                     # show more detail about what Claude is doing
--debug                       # very detailed debug output (for troubleshooting)
```

---

## Interactive Mode (Default)

```bash
claude
# Starts an interactive REPL — you type, Claude responds, you continue the conversation
```

This is the primary mode for development work. The session stays open, context accumulates, and you build on previous messages.

```
> Look at the API routes and tell me which ones are missing authentication
[Claude reads routes, responds]

> Good. Now add the auth middleware to the ones you identified
[Claude edits the files]

> Run the tests to make sure nothing broke
[Claude runs tests]

> Great. Now write a PR description for this change
[Claude writes the description, knows exactly what changed]
```

Each message builds on the context from all previous messages in the session. This is the power of interactive mode — no re-explaining.

---

## Non-Interactive (Headless) Mode

```bash
# --print: single task, prints output, exits
claude --print "What does the auth module do?"

# With a prompt argument (equivalent)
claude "What does the auth module do?" --print
```

Use this for:
- Shell scripts
- CI/CD pipelines
- Git hooks
- Automation

### Piping Input to Claude

```bash
# Pipe from stdin
echo "What's wrong with this SQL?" | claude --print

# Pipe a file's contents
cat Dockerfile | claude --print "Review this for security issues"

# Pipe command output
git diff HEAD~1 HEAD | claude --print "Summarize what changed and the risk"

# Pipe test results
npm test 2>&1 | claude --print "Which tests are failing and why?"

# Pipe log file
tail -100 /var/log/app.log | claude --print "What errors are occurring?"
```

### Practical Shell Script Examples

```bash
#!/bin/bash
# pre-commit hook: AI review before every commit

DIFF=$(git diff --cached)
if [ -z "$DIFF" ]; then
  exit 0
fi

REVIEW=$(echo "$DIFF" | claude --print "Review this code diff for bugs, security issues, and code quality. Be concise. List critical issues only.")

echo "Claude Code Review:"
echo "$REVIEW"
echo ""
read -p "Continue with commit? (y/n): " choice
[[ "$choice" == "y" ]] && exit 0 || exit 1
```

```bash
#!/bin/bash
# CI step: explain test failures in plain English

TEST_OUTPUT=$(npm test 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  EXPLANATION=$(echo "$TEST_OUTPUT" | claude --print \
    "These are CI test failures. Explain what's failing in 3 bullet points. Be specific about file names and function names.")
  
  echo "Test failures:"
  echo "$TEST_OUTPUT"
  echo ""
  echo "AI Explanation:"
  echo "$EXPLANATION"
  exit 1
fi
```

---

## JSON Output Mode

```bash
# Structured JSON output — useful when scripting
claude --print --output-format json "List all API endpoints in this codebase"

# Output:
# {
#   "type": "result",
#   "result": "...",
#   "cost_usd": 0.003,
#   "duration_ms": 1250,
#   "num_turns": 1
# }

# Stream JSON — each event as it happens
claude --print --output-format stream-json "Analyze the codebase"
```

---

## Model Selection

```bash
# Use Opus for complex tasks (slower, more intelligent)
claude --model claude-opus-4-8

# Use Haiku for quick, simple tasks (fastest, cheapest)
claude --model claude-haiku-4-5-20251001

# Inside an interactive session, use /model command:
> /model claude-opus-4-8
# Switches model for the current session
```

When to use each model in practice:

| Task | Model |
|------|-------|
| Quick question, simple task | Haiku |
| Daily coding, debugging, most tasks | Sonnet (default) |
| Complex refactor, architecture review, hard debugging | Opus |
| Security audit, compliance review | Opus |
| CI/CD automation (cost matters) | Haiku or Sonnet |

---

## Working Directory Flag

```bash
# Run Claude Code from a different directory without cd-ing
claude -C /home/sanketika7420/projects/vault-app

# Combine with --print for scripts that run in a fixed location
claude -C /var/app --print "Is the application healthy? Check logs and processes."
```

---

## The `!` Prefix — Run Shell Commands Directly

Inside an interactive Claude Code session, prefix any line with `!` to run it as a shell command directly (without involving Claude):

```
> !ls -la
total 80
drwxr-xr-x  12 user user 4096 Jun 15 10:30 .
drwxr-xr-x  45 user user 4096 Jun 14 09:00 ..
-rw-r--r--   1 user user 1234 Jun 15 10:30 CLAUDE.md
...

> !git log --oneline -5
a3f7d2c (HEAD -> main) feat: add password strength check
7b8c9d1 fix: JWT expiry calculation
...
```

This is faster than asking Claude to run it — you get the output immediately and it's visible in context for Claude to reference in the next message.

**Real use case:**
```
> !kubectl get pods -n production
NAME                     READY   STATUS             RESTARTS
vault-api-7d4b9c-xyz     0/1     CrashLoopBackOff   5

What's causing the crash? Check the logs.
[Claude sees the pod list output and checks logs]
```

---

## Verbose Mode

```bash
claude --verbose
# Shows detailed information about what Claude is doing:
# - Which files it's reading
# - What commands it's considering
# - Why it made certain decisions
# - Token usage per step
```

Use verbose mode when:
- Debugging why Claude is making unexpected choices
- Learning what Claude is doing under the hood
- Diagnosing slow or expensive sessions

---

## The `/fast` Toggle — Opus Mode Inside a Session

Inside an interactive session:

```
> /fast
Fast mode enabled. Using Claude Opus with faster output.
```

This toggles "Fast mode" which uses Claude Opus 4.8 but optimized for speed. It's NOT a downgrade to a smaller model — it's Opus with speed optimizations.

Use `/fast` when:
- You're in a complex debugging session that needs Opus-level reasoning
- You need faster responses during an intensive session

Toggle back with `/fast` again.

---

## Session IDs and Resuming Work

```bash
# List recent sessions
claude --list-sessions    # (if supported in your version)

# Inside a session, get current session ID
> /status
# Shows: Session ID: sess_abc123def456

# Resume a specific session later
claude --resume sess_abc123def456
```

Sessions are stored locally. Resuming a session restores the full conversation history.

```bash
# Most common: just continue the last session
claude --continue
# or
claude -c
```

---

## Real-World Scenario: Using Claude Code in a Makefile

```makefile
# Makefile

.PHONY: review explain fix-tests

# AI code review before pushing
review:
	@git diff HEAD | claude --print -C . \
	  "Review this diff. List any bugs, security issues, or bad patterns. Be specific."

# Explain what a test failure means
explain-failure:
	@npm test 2>&1 | claude --print -C . \
	  "These test failures need a fix. Give me the exact changes needed with file paths and line numbers."

# AI-generated commit message
commit-msg:
	@git diff --cached | claude --print -C . \
	  "Write a conventional commit message (feat/fix/chore/docs) for these changes. One line only." | git commit -F -

# Ask Claude about your infra
infra-audit:
	@cat helm/values.production.yaml kubernetes/*.yaml | claude --print \
	  "Review this Kubernetes configuration for security issues and misconfigurations."
```

```bash
make review          # review before push
make commit-msg      # auto-generate commit message
make infra-audit     # security check your k8s config
```

---

## Common Misunderstanding: "YOLO mode is dangerous, never use it"

**The misunderstanding:** "`--dangerously-skip-permissions` is reckless and you should never use it."

**The reality:** It depends entirely on the context.

**When YOLO mode is appropriate:**
- You're running Claude on a fresh dev environment (not production)
- You're doing a one-off task like "add type annotations to 50 files"
- You trust Claude's judgment for that specific task
- You're in a throw-away container or CI environment
- You have git and can see/revert every change

**When to NEVER use YOLO mode:**
- Any machine with production credentials or access
- Any task involving `rm`, `drop table`, or destructive operations
- When working in a shared environment
- When you haven't established what Claude will do

The flag exists because the permission prompts for 50 files and 200 commands per batch job are genuinely annoying. For controlled environments, it's a legitimate tool.

→ Continue to: `02-slash-commands.md`
