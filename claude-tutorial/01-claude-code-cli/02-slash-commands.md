# Claude Mastery — 04: Claude Code — Slash Commands

> **Last updated:** June 17, 2026
> **Covers:** Every built-in slash command in Claude Code, when to use each

**20-minute read. Slash commands are shortcuts that trigger specific behaviors. Know them all.**

---

## What Slash Commands Are

In Claude Code, typing `/` in the prompt opens a command menu. Slash commands are built-in shortcuts that:
- Trigger specific Claude behaviors
- Control the session
- Invoke skills (reusable prompt templates)
- Access meta-information

Typing `/` shows all available commands. Tab-completes them.

---

## Session Management Commands

### `/help`
```
> /help
```
Shows all available slash commands with brief descriptions. Always your first stop if confused.

### `/clear`
```
> /clear
```
Clears the conversation history. Claude starts fresh with no memory of what was discussed. Useful when:
- You switch to a completely different task
- The context has too much noise from an unrelated conversation
- You want a clean slate to try a different approach

**Important:** `/clear` does NOT reset CLAUDE.md instructions or your settings. Only the conversation history is cleared.

### `/compact`
```
> /compact
```
Manually triggers context compaction — Claude summarizes old conversation turns into a shorter summary to free up context space. Claude Code does this automatically when needed, but you can trigger it manually when:
- You're doing a very long session and want to "clean up" the context
- You notice Claude is forgetting earlier details (context overflow)
- You want to preserve the key findings while clearing the noise

### `/new`
```
> /new
```
Starts a completely new session (separate from `/clear`). The old session is saved and can be resumed with `--continue` or `--resume`.

### `/quit` / `/exit`
```
> /quit
> /exit
```
Ends the Claude Code session cleanly. Same as Ctrl+D.

---

## Information Commands

### `/status`
```
> /status
```
Shows current session information:
- Model in use
- Tokens used so far
- API calls made
- Session ID
- Permission mode

Use this to monitor token usage during a long session.

### `/cost`
```
> /cost
```
Shows the estimated cost of the current session so far. Useful for budget awareness, especially when using Opus for long sessions.

### `/doctor`
```
> /doctor
```
Diagnoses common setup issues:
- Is authentication working?
- Is the API reachable?
- Are tools functioning?
- Any configuration problems?

Run this first when Claude Code isn't working correctly.

---

## Context and Memory Commands

### `/memory`
```
> /memory
```
Shows the current auto-memory content — what Claude remembers about you and your project from previous sessions. Covers user preferences, project details, feedback, and references.

See section `02-project-setup/01-memory-system.md` for full coverage of memory.

### `/init`
```
> /init
```
**One of the most important commands.** Analyzes your current project and generates a `CLAUDE.md` file — the project context file that persists across all sessions.

Run this once per project. Claude reads your codebase and writes a CLAUDE.md describing:
- What the project does
- Tech stack and versions
- Directory structure
- Common commands (build, test, deploy)
- Important conventions

After `/init`, every future session starts with Claude already understanding your project.

---

## Workflow Commands

### `/review`
```
> /review
```
Triggers a code review of the current changes (staged git changes or recent modifications). Claude reviews for:
- Bugs and logical errors
- Security vulnerabilities
- Code quality
- Best practice violations
- Test coverage

### `/commit`
```
> /commit
```
Creates a git commit for staged changes with an AI-generated commit message. Claude:
1. Reads the staged diff (`git diff --cached`)
2. Understands what changed
3. Writes a conventional commit message (feat/fix/chore/docs/refactor)
4. Shows you the message for approval
5. Creates the commit

### `/pr`
```
> /pr
```
Creates a pull request for the current branch. Claude:
1. Reads all commits since the branch diverged from main
2. Reads all file changes
3. Generates a PR title and description with context
4. Runs `gh pr create` (requires GitHub CLI)

### `/deploy`
```
> /deploy [environment]
```
If your project has deployment scripts configured, triggers a deployment. The specifics depend on your CLAUDE.md setup.

---

## Model Commands

### `/model`
```
> /model claude-opus-4-8
```
Switches the model for the current session. Takes effect immediately.

```
> /model            # without args: shows current model
> /model claude-haiku-4-5-20251001
> /model claude-sonnet-4-6
> /model claude-opus-4-8
```

### `/fast`
```
> /fast
```
Toggles "Fast mode" — uses Claude Opus 4.8 with speed optimizations. Does NOT downgrade the model. Toggle again to turn off.

### `/verbose`
```
> /verbose
```
Toggles verbose output — shows more detail about Claude's reasoning and tool usage. Toggle again to turn off.

---

## Planning Commands

### `/plan`
```
> /plan
```
Enters **plan mode** — Claude analyzes the task, creates a plan, and shows it to you for approval BEFORE doing anything. Use this for:
- Complex multi-file changes
- Risky operations
- When you want to review the approach before execution

```
> /plan
[Plan mode activated]

> Refactor the authentication module to use JWT instead of sessions

Claude creates a plan:
1. Identify all files using session auth
2. Add JWT dependency
3. Create JWT utility module
4. Update login endpoint
5. Update auth middleware
6. Update all protected routes
7. Update tests

[Approve? y/n]
```

---

## Utility Commands

### `/bug`
```
> /bug "Description of unexpected Claude behavior"
```
Reports a bug to Anthropic about Claude Code's behavior. Opens a pre-filled issue or submits feedback.

### `/schedule`
```
> /schedule "Check if the deployment is healthy in 10 minutes"
```
Schedules a wakeup — Claude will check back on a task after a specified delay. Used in loop mode for monitoring tasks.

### `/login` / `/logout`
```
> /login     # re-authenticate
> /logout    # remove stored credentials
```

---

## Skills — Slash Commands That Are Prompt Templates

Beyond the built-in commands, Claude Code supports **skills** — custom slash commands defined in `.claude/commands/` files. When you type `/` you see both built-in commands AND custom skills.

Full coverage: `03-skills/` section.

```
> /             # shows all: built-ins + custom skills
> /review       # built-in
> /deploy-staging  # custom skill you defined
> /write-tests   # custom skill you defined
```

---

## The Keyboard Shortcuts In-Session

| Shortcut | Action |
|----------|--------|
| `Ctrl+C` | Cancel current generation |
| `Ctrl+D` | Exit session |
| `↑/↓` | Navigate command history |
| `Tab` | Autocomplete slash commands |
| `Ctrl+L` | Clear terminal (not conversation) |

---

## Real-World Scenario: A Complete Git Workflow with Slash Commands

```bash
cd vault-app
claude
```

```
> Look at the failing tests in the auth module and fix them

[Claude reads test files, identifies failures, edits code]

> /review

[Claude reviews the changes it just made]

Review findings:
  ✓ Logic is correct
  ✓ Error handling added
  ⚠️ One edge case: empty password string isn't validated

Fix the empty password edge case, then we'll commit.

[Claude fixes it]

> /commit

Proposed commit message:
  fix(auth): handle empty password in JWT validation

  - Added empty string check before JWT generation
  - Prevents auth bypass with empty password submission
  - Added test case for edge case

[y/n]: y
Committed: a3f7d2c

> /pr

Creating PR...
Title: fix(auth): handle empty password in JWT validation
Body: [detailed description Claude wrote]
URL: https://github.com/sanketika/vault-app/pull/47
```

Three slash commands replaced: writing a commit message, writing a PR description, and manually pushing. Clean, fast, consistent.

---

## Common Misunderstanding: "/clear removes CLAUDE.md instructions"

**The misunderstanding:** "If I run `/clear`, I lose all my project context and Claude won't know about my project anymore."

**The reality:** `/clear` only clears the conversation history (the chat messages). It does NOT remove:
- Your CLAUDE.md file (still on disk, re-read at the start of the next message)
- Your memory files (persisted independently)
- Your settings
- Any files you edited

Think of `/clear` as "new conversation, same project." Claude reads CLAUDE.md at the beginning of every session and after `/clear`, so your project context immediately comes back.

→ Continue to: `03-permissions-and-settings.md`
