# Claude Mastery — 14: Installing and Using MCP Servers

> **Last updated:** June 17, 2026
> **Covers:** Installing MCP servers, configuration, popular servers, practical examples

**20-minute read. Connect Claude to GitHub, Slack, databases, and more.**

---

## How to Install an MCP Server

MCP servers are configured in Claude Code's settings. The configuration tells Claude Code how to START the MCP server process.

```json
// ~/.claude/settings.json  (global — available to all projects)
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_your_token_here"
      }
    }
  }
}
```

Or project-level:
```json
// .claude/settings.json  (project-specific)
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://user:pass@localhost:5432/vault_dev"
      }
    }
  }
}
```

After adding configuration: restart Claude Code. The MCP server starts automatically.

---

## GitHub MCP Server

**What it gives Claude:** Create/read issues and PRs, search code, manage repos, review code.

### Install

```json
// ~/.claude/settings.json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxxxxxxxxx"
      }
    }
  }
}
```

**Create a GitHub PAT:**
```
GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
Scopes: repo, issues, pull_requests
```

### What You Can Now Do

```
> "Create a GitHub issue for the connection pool bug we discussed"
[Claude creates the issue with title, body, labels from conversation context]

> "What PRs are open and waiting for my review?"
[Claude queries GitHub and lists them]

> "Review PR #42 and leave a comment with your findings"
[Claude reads the PR diff, posts a review comment]

> "Create a PR from the current branch to main with the changes we just made"
[Claude creates the PR with an AI-generated description]

> "Search for all usages of the deprecated auth function across all repos in our org"
[Claude searches GitHub code search]

> "Close issue #156 and reference the commit that fixed it"
[Claude closes the issue with a comment]
```

---

## Slack MCP Server

**What it gives Claude:** Post messages, read channels, search messages.

### Install

```json
{
  "mcpServers": {
    "slack": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "xoxb-your-bot-token",
        "SLACK_TEAM_ID": "T0123456789"
      }
    }
  }
}
```

**Get a Slack bot token:**
```
api.slack.com → Your Apps → Create New App → OAuth & Permissions
Bot Token Scopes: channels:read, chat:write, chat:write.public, search:read
Install app to workspace → copy Bot User OAuth Token
```

### What You Can Now Do

```
> "Post a deployment summary to #deployments"
[Claude posts the message]

> "What was discussed in #incidents in the last 24 hours?"
[Claude reads recent messages and summarizes]

> "Notify the backend team in #backend-team that the API is deployed"
[Claude posts the message]

> "Search Slack for any messages about the Redis connection issue"
[Claude searches and returns relevant messages]
```

---

## PostgreSQL MCP Server

**What it gives Claude:** Query your database, explore schema, understand data.

### Install (for local dev database)

```json
// .claude/settings.json (project-level, not global)
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres",
               "postgresql://developer:devpass@localhost:5432/vault_dev"]
    }
  }
}
```

**SECURITY: Only connect to development databases. Never put production connection strings in settings files.**

### What You Can Now Do

```
> "What tables exist in this database?"
[Claude runs \dt and lists them with descriptions]

> "Show me the schema for the users table"
[Claude runs \d users and shows the schema]

> "How many users registered in the last 7 days?"
[Claude runs a COUNT query with date filter]

> "Are there any users with no password hash set? That's a security issue."
[Claude queries and reports]

> "What's the slowest query running right now?"
[Claude queries pg_stat_activity]

> "Generate a migration to add an email_verified boolean column to users"
[Claude examines the table and writes the migration]
```

---

## Google Drive MCP Server

**What it gives Claude:** Read Google Docs, Sheets, and other Drive files.

### Install (requires OAuth setup)

```json
{
  "mcpServers": {
    "gdrive": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-gdrive"]
    }
  }
}
```

First run will open a browser for Google OAuth authentication.

### What You Can Now Do

```
> "Read our architecture doc from Google Drive and summarize the data flow"
> "Find the API documentation in Drive and check if it matches our current endpoints"
> "Read the on-call runbook from Drive"
> "Update the deployment log in our shared Google Sheet"
```

---

## Figma MCP Server

**What it gives Claude:** Read Figma designs, extract component specs, understand design system.

### Install

```json
{
  "mcpServers": {
    "figma": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-figma"],
      "env": {
        "FIGMA_ACCESS_TOKEN": "figd_your_token"
      }
    }
  }
}
```

**Get a Figma token:** Figma → Account Settings → Personal access tokens

### What You Can Now Do

```
> "Look at the login screen design in Figma and write the React component for it"
[Claude reads the Figma file, extracts layout/colors/typography, writes the component]

> "Compare our current Button component with the Figma design system and list discrepancies"
[Claude reads both and lists differences]

> "Extract all color values from the design system and create a Tailwind config"
[Claude reads the design tokens and generates the config]

> "The designer updated the card component in Figma — 
   what changed and what code do I need to update?"
[Claude reads the new design and compares with the component code]
```

---

## Verifying MCP Servers Are Working

```bash
# In Claude Code session
> /doctor
# Should show: MCP servers connected: github, slack, postgres

# Check what MCP tools are available
> What tools do you have access to from MCP servers?
[Claude lists all available tools from each server]
```

---

## MCP Server Discovery

Find available MCP servers:
- **Official servers:** https://github.com/modelcontextprotocol/servers
- **Community servers:** Search "MCP server" on GitHub, npm
- **Anthropic's directory:** (check claude.ai docs for current link)

---

## Real-World Scenario: Full DevOps Workflow with MCP

With GitHub + Slack + Postgres MCP servers configured:

```
You: "We have a bug in production — users can't log in. 
     Diagnose it, fix it, deploy the fix, and notify the team."

Claude:
1. [Postgres MCP] Queries recent auth errors from the database
2. Reads the auth code based on what the DB shows
3. Identifies the bug (JWT secret rotation changed but old tokens still presented)
4. Writes the fix (add grace period for old tokens)
5. Runs tests to verify
6. [GitHub MCP] Creates a PR with the fix
7. Gets you to approve
8. Runs: helm upgrade to deploy
9. Verifies health check passes
10. [Slack MCP] Posts to #incidents: "Auth bug resolved — JWT grace period added. 
    PR #249 deployed at 14:32. All users can now log in."
11. [GitHub MCP] Closes the GitHub issue #247 referencing the fix
```

One instruction. Claude diagnosed, fixed, deployed, notified, and closed the ticket. That's what MCP makes possible.

---

## Common Misunderstanding: "MCP servers are unsafe"

**The misunderstanding:** "Giving Claude access to Slack and GitHub is a security risk — it could do anything."

**The reality:** Claude only uses MCP tools when you ask it to (or when the task clearly calls for it). You see every MCP tool use in the terminal. You can deny any tool use at the permission prompt.

More importantly: Claude uses your credentials with the permissions YOU granted. If your GitHub token only has read access, Claude can only read. If your Slack bot can only post to specific channels, Claude can only post there.

The risk model is: your MCP server has the permissions you gave it. Claude inherits exactly those permissions — no more.

→ Continue to: `../06-real-world-by-role/00-devops-engineer.md`
