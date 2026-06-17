# Claude Mastery — 05: Permissions, Settings, and Hooks

> **Last updated:** June 17, 2026
> **Covers:** Permission modes, settings.json, allowed/blocked tools, hooks system

**20-minute read. Configure Claude Code to trust the right things and block the dangerous ones.**

---

## The Settings File

Claude Code's settings live in:
```
~/.claude/settings.json       ← global settings (all projects)
.claude/settings.json         ← project-local settings (in your repo)
.claude/settings.local.json   ← local overrides (git-ignored, for your machine only)
```

Priority: local > project > global. Project settings override global; local overrides both.

**Never commit `.claude/settings.local.json`** — it's for machine-specific settings like which tools you've personally approved.

---

## The Permission System

Claude Code asks for permission before taking actions. You can pre-configure which actions are allowed or blocked.

### Permission Levels

```json
// .claude/settings.json
{
  "permissions": {
    "allow": [
      "Bash(npm test)",           // allow this specific command
      "Bash(npm run *)",          // allow npm run + anything
      "Bash(git *)",              // allow all git commands
      "Bash(kubectl get *)",      // allow kubectl get commands
      "Read(*)",                  // allow reading any file
      "Edit(src/**)",             // allow editing files in src/
      "Write(src/**)"             // allow writing files in src/
    ],
    "deny": [
      "Bash(rm -rf *)",           // never allow rm -rf
      "Bash(kubectl delete *)",   // never delete k8s resources without asking
      "Bash(git push --force *)", // never force push
      "Edit(.env*)",              // never edit .env files
      "Write(.env*)"              // never write .env files
    ]
  }
}
```

### Permission Rule Syntax

```
Tool(pattern)

Tools:
  Bash          - shell commands
  Read          - reading files
  Write         - writing files
  Edit          - editing files
  WebSearch     - web searches
  WebFetch      - fetching URLs
  Agent         - spawning subagents

Patterns:
  *             - matches anything
  npm test      - exact command match
  npm run *     - starts with "npm run "
  kubectl * -n production  - kubectl commands targeting production namespace
  src/**        - files under src/
  *.yaml        - any yaml file
```

### Interactive Permission Prompts

When Claude wants to do something not pre-configured:

```
╭──────────────────────────────────────────────────────────────╮
│  Claude wants to run:                                         │
│                                                               │
│  kubectl delete pod vault-api-7d4b9c -n production           │
│                                                               │
│  [y] Yes once  [a] Always allow  [n] No  [d] Always deny    │
╰──────────────────────────────────────────────────────────────╯
```

Choosing `[a] Always allow` or `[d] Always deny` saves the rule to your `.claude/settings.local.json` permanently.

---

## Recommended Settings for a DevOps Engineer

```json
// .claude/settings.json  (commit this to your repo)
{
  "permissions": {
    "allow": [
      "Bash(git status)",
      "Bash(git log *)",
      "Bash(git diff *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(npm *)",
      "Bash(yarn *)",
      "Bash(docker ps)",
      "Bash(docker logs *)",
      "Bash(docker inspect *)",
      "Bash(kubectl get *)",
      "Bash(kubectl describe *)",
      "Bash(kubectl logs *)",
      "Bash(kubectl rollout status *)",
      "Bash(helm list *)",
      "Bash(helm status *)",
      "Bash(helm history *)",
      "Bash(helm diff *)",
      "Bash(terraform plan *)",
      "Bash(terraform validate)",
      "Bash(aws * --dry-run)",
      "Read(*)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(kubectl delete *)",
      "Bash(kubectl exec *)",
      "Bash(helm uninstall *)",
      "Bash(terraform destroy *)",
      "Bash(git push --force *)",
      "Bash(aws * delete *)",
      "Bash(aws * terminate *)",
      "Edit(.env*)",
      "Edit(*.pem)",
      "Edit(*.key)"
    ]
  }
}
```

This setup:
- Auto-allows all read operations (git log, kubectl get, docker ps)
- Auto-allows non-destructive writes (npm, git add, git commit)
- Always asks for destructive operations (kubectl delete, rm -rf, terraform destroy)
- Never touches credentials files (.env, .pem, .key)

---

## The Hooks System

Hooks are shell commands that run automatically in response to Claude Code events. This is an advanced but powerful feature.

```json
// .claude/settings.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Running command: $CLAUDE_TOOL_INPUT' >> ~/.claude-audit.log"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Edited: $CLAUDE_TOOL_INPUT_FILE_PATH' >> ~/.claude-edits.log"
          }
        ]
      }
    ]
  }
}
```

Hook events:
- `PreToolUse` — runs BEFORE Claude uses a tool. If your hook exits non-zero, Claude is blocked.
- `PostToolUse` — runs AFTER Claude uses a tool. For logging, notifications.
- `Stop` — runs when Claude finishes a task.
- `Notification` — runs when Claude sends you a notification.

### Practical Hook: Prevent Editing Production Files

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "if [[ \"$CLAUDE_TOOL_INPUT_FILE_PATH\" == *\"production\"* ]]; then echo 'BLOCKED: Production file edit requires manual review'; exit 2; fi"
          }
        ]
      }
    ]
  }
}
```

If Claude tries to edit any file with "production" in the path, the hook blocks it.

### Practical Hook: Audit Log

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"$(date '+%Y-%m-%d %H:%M:%S') BASH: $CLAUDE_TOOL_INPUT\" >> ~/.claude/audit.log"
          }
        ]
      }
    ]
  }
}
```

Every command Claude runs is logged with a timestamp to `~/.claude/audit.log`.

---

## Global vs Project Settings — What Goes Where

```
~/.claude/settings.json  ← YOUR personal defaults for all projects
  - Default model preference
  - Global permission defaults
  - Personal hooks (audit logging)
  - Telemetry preferences

.claude/settings.json    ← THIS PROJECT's rules (commit to git)
  - Project-specific allowed/blocked commands
  - Project-specific hooks
  - Team-shared settings

.claude/settings.local.json  ← YOUR machine, THIS project (never commit)
  - Commands you've approved interactively
  - Your personal overrides for this project
```

---

## Other Useful Settings

```json
// ~/.claude/settings.json
{
  "model": "claude-sonnet-4-6",        // default model for all sessions
  "theme": "dark",                      // UI theme
  "autoCompact": true,                  // auto-compact long conversations
  "autoSave": true,                     // auto-save sessions
  "telemetry": {
    "enabled": false                    // opt out of telemetry
  },
  "env": {
    "ANTHROPIC_API_KEY": "sk-ant-..."  // API key (alternative to env var)
  }
}
```

---

## The `.claude/` Directory Structure

```
your-project/
├── .claude/
│   ├── settings.json         ← project settings (commit to git)
│   ├── settings.local.json   ← your local overrides (gitignore this)
│   └── commands/             ← custom skills (slash commands)
│       ├── deploy-staging.md
│       ├── write-tests.md
│       └── review-security.md
├── CLAUDE.md                 ← project context (commit to git)
└── src/
```

---

## Real-World Scenario: Secure DevOps Setup

A DevOps engineer sets up Claude Code for their infrastructure team:

```json
// .claude/settings.json (committed to vault-infra repo)
{
  "permissions": {
    "allow": [
      "Bash(terraform plan *)",
      "Bash(terraform validate)",
      "Bash(kubectl get *)",
      "Bash(kubectl describe *)",
      "Bash(kubectl logs *)",
      "Bash(helm diff *)",
      "Bash(helm status *)",
      "Bash(helm history *)",
      "Bash(aws * --dry-run)",
      "Read(*)"
    ],
    "deny": [
      "Bash(terraform apply *)",
      "Bash(terraform destroy *)",
      "Bash(kubectl delete *)",
      "Bash(kubectl exec *)",
      "Bash(helm upgrade *)",
      "Bash(helm install *)",
      "Bash(helm uninstall *)",
      "Bash(aws ec2 terminate*)",
      "Bash(aws rds delete*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "echo \"$(date) | $USER | $CLAUDE_TOOL_INPUT\" >> /var/log/claude-infra-audit.log"
        }]
      }
    ]
  }
}
```

Result:
- Claude can freely INSPECT infrastructure (plan, validate, get, describe, logs)
- Claude must ASK before CHANGING infrastructure (apply, upgrade, delete)
- Every command is logged with timestamp and username for compliance

---

## Common Misunderstanding: "Allow rules override deny rules"

**The misunderstanding:** "If I have `allow: ['Bash(kubectl *)']` and `deny: ['Bash(kubectl delete *)']`, the delete is still blocked."

**The reality:** Deny rules take precedence over allow rules. More specific deny rules block even if a broad allow rule covers the pattern. In the example above:
- `kubectl get pods` → matches allow `kubectl *` → ALLOWED
- `kubectl delete pod xyz` → matches deny `kubectl delete *` → BLOCKED

This is the safe default — if you explicitly deny something, it stays denied even if you broadly allow the parent pattern.

When in doubt, test with `--verbose` to see which rules Claude is applying.

→ Continue to: `../02-project-setup/00-claude-md.md`
