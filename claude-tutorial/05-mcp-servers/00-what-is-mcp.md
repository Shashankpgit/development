# Claude Mastery — 13: MCP Servers — Extending Claude's Reach

> **Last updated:** June 17, 2026
> **Covers:** What MCP is, why it exists, the protocol architecture, what MCP unlocks

**20-minute read. MCP is how you connect Claude to your real tools — GitHub, Slack, databases, design tools.**

---

## The Problem MCP Solves

Without MCP, Claude can:
- Read and write files on your machine
- Run shell commands
- Fetch public URLs

Claude CANNOT (without MCP):
- Create a GitHub issue or PR via the API
- Post a Slack message
- Query your database directly
- Read from Google Drive or Confluence
- Work with Figma designs directly
- Access your Jira board
- Connect to private internal APIs

MCP (Model Context Protocol) is the bridge. It lets you connect ANY external system to Claude in a standardized way.

---

## What MCP Is

**Model Context Protocol** is an open standard that defines how AI assistants communicate with external tools and data sources.

Think of it like USB for AI tools. USB standardized how devices connect to computers — any USB device works with any USB port. MCP standardizes how tools connect to AI assistants — any MCP server works with any MCP client (Claude Code, Claude Desktop, Cursor, etc.).

```
                    MCP Protocol (standard interface)
                         │
Claude Code ────────────►│◄──── GitHub MCP Server
                         │      (talks to GitHub API)
                    standardized
                    JSON protocol
```

---

## MCP Architecture

```
You (talking to Claude)
     │
     ▼
Claude Code (MCP client)
     │
     │ MCP Protocol (JSON over stdio or HTTP)
     │
     ├──► GitHub MCP Server ──► GitHub API
     ├──► Slack MCP Server  ──► Slack API
     ├──► Postgres MCP Server → Your Database
     └──► Custom MCP Server  ──► Your Internal API
```

Each MCP server:
1. Runs as a separate process on your machine
2. Communicates with Claude Code via a standardized protocol
3. Exposes **tools** (functions Claude can call) and optionally **resources** (data Claude can read)

---

## What MCP Gives Claude

### Tools
Functions Claude can invoke: "create GitHub issue", "post Slack message", "run SQL query"

### Resources
Data Claude can read: "read this Confluence page", "get the content of this Google Doc"

### Prompts (optional)
Pre-built prompt templates the MCP server provides

---

## The Categories of MCP Servers

### Development Tools
- **GitHub** — create issues, PRs, read code, manage repos
- **GitLab** — same for GitLab
- **Linear** — project management, tickets, sprints
- **Jira** — project tracking, ticket management

### Communication
- **Slack** — read channels, post messages, search
- **Gmail** — read/send email, manage drafts
- **Google Calendar** — read/create events

### Data & Databases
- **PostgreSQL** — run queries, explore schema
- **MySQL** — same for MySQL
- **SQLite** — local database operations
- **Supabase** — Supabase database and storage

### Productivity
- **Google Drive** — read/write Google Docs, Sheets, files
- **Notion** — read/write Notion pages and databases
- **Confluence** — read Confluence pages

### Design
- **Figma** — read design files, extract specs, components
- **Excalidraw** — create and edit diagrams

### Infrastructure
- **Kubernetes** — kubectl-equivalent via MCP
- **AWS** — interact with AWS services
- **Terraform** — read/apply infrastructure

---

## Real Impact Examples

### Without GitHub MCP
```
You: "Create a GitHub issue for the auth bug we discussed"
Claude: "I can't create GitHub issues. Copy this text and paste it 
        into GitHub: [title] [body]"
You: manually opens GitHub, creates issue, pastes content
```

### With GitHub MCP
```
You: "Create a GitHub issue for the auth bug we just discussed"
Claude: [calls GitHub MCP tool create_issue with context from conversation]
        "Created issue #248: 'JWT validation allows empty password' 
         in sanketika/vault-app with labels: bug, security, p1"
```

One sentence. Done.

---

### Without Slack MCP
```
You: "Notify the team about the deployment"
Claude: "Here's a message you can send: ..."
You: opens Slack, finds channel, pastes message
```

### With Slack MCP
```
You: "Post the deployment summary to #deployments"
Claude: [calls Slack MCP tool]
        "Posted to #deployments"
```

---

## MCP Security Model

MCP servers run on YOUR machine and access only what you configure. Claude doesn't have hidden network access — it calls your local MCP server, which then uses your credentials to call the external API.

```
Claude → GitHub MCP Server (local process) → GitHub API (using YOUR token)
```

Key security properties:
- Your credentials stay on your machine
- You control which MCP servers are installed
- Each MCP server only does what its code implements
- You can see every MCP tool call Claude makes (they appear in the terminal)

---

## How to Know What's Available

```
> /tools
```

Shows all tools currently available to Claude, including MCP tools:

```
Built-in tools:
  Read, Write, Edit, Bash, WebSearch, WebFetch, Agent...

MCP tools (from connected servers):
  github: create_issue, create_pr, list_prs, search_code...
  slack: post_message, list_channels, search_messages...
  postgres: query, list_tables, describe_table...
```

---

## Common Misunderstanding: "MCP requires programming to use"

**The misunderstanding:** "MCP sounds complex — I need to write code to use it."

**The reality:** Using an MCP server requires zero code. You install it (usually `npm install -g @modelcontextprotocol/server-github`) and configure it in Claude Code's settings (a few JSON lines). After that, it just works.

WRITING an MCP server requires programming. USING one does not.

The next file covers installing and configuring MCP servers step by step.

→ Continue to: `01-installing-and-using.md`
