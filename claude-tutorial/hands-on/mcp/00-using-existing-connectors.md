# Hands-On MCP — 1: Using the Connectors You Already Have

> **Last updated:** July 17, 2026
> **Covers:** The two kinds of MCP server, how remote connectors attach & authenticate, seeing a connector's tools, the security model
> **25-minute read.**

---

## Start From What You Already Have

Run this in a terminal:

```bash
claude mcp list
```

On your machine, this prints something like:

```
claude.ai Gmail:           https://gmailmcp.googleapis.com/mcp/v1     - ✔ Connected
claude.ai Google Calendar: https://calendarmcp.googleapis.com/mcp/v1 - ✔ Connected
claude.ai Google Drive:    https://drivemcp.googleapis.com/mcp/v1    - ✔ Connected
claude.ai Spotify:         https://mcp-gateway...spotify.net/mcp     - ✔ Connected
claude.ai Figma:           https://mcp.figma.com/mcp                 - ! Needs authentication
...
```

Look closely at that output. **Every one of your servers is a URL** (`https://...`). None of them is a program on your laptop. That single detail is the most important thing in this file, and it's the thing the `05-mcp-servers` theory docs did *not* cover — so let's fix that now.

---

## The Two Kinds of MCP Server

There are exactly two ways an MCP server can run. Knowing which kind you're dealing with tells you how it's configured, where your credentials live, and how it fails.

### Kind A — Local (stdio) server

This is what `05-mcp-servers/01-installing-and-using.md` describes. A program runs **on your machine** as a child process of Claude Code. Claude talks to it over stdin/stdout ("stdio").

```json
// ~/.claude/settings.json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_..." }
    }
  }
}
```

- Claude Code **launches the process** using `command` + `args`.
- Your **credentials sit in the config** (or your shell env) on your machine.
- If your laptop is offline, the server still starts (though the API it calls may not answer).

### Kind B — Remote (HTTP/SSE) server

This is what **all of your current connectors are**. The server is **hosted by a vendor** (Google, Spotify, Figma, or Anthropic acting as a gateway). Claude Code talks to it over HTTPS. Nothing is installed locally.

```
Claude Code ──HTTPS──► https://drivemcp.googleapis.com/mcp/v1 ──► Google Drive API
                        (Google runs this; you just authenticate)
```

- **Nothing to install.** No `npx`, no process on your machine.
- You **authenticate with OAuth** — a browser window, "Allow Claude to access your Drive", done.
- Your credential is an **OAuth token held by the connector**, not a token pasted into a file.
- If the **token expires**, the connector goes into `! Needs authentication` / "requires re-authorization" and you re-approve in the browser. (You'll likely hit this — it's normal, not a bug.)

### Side-by-side

| | **Local (stdio)** | **Remote (HTTP/SSE)** |
|---|---|---|
| Where it runs | Your machine, as a child process | Vendor's servers |
| Install step | `npm`/`npx`, sometimes a binary | None |
| Config | `command`, `args`, `env` in settings | A URL + `--transport` |
| Auth | Token in config/env | OAuth in the browser |
| Credential lives | On your machine | Held by the connector (token) |
| Typical failure | "command not found", bad token | "requires re-authorization" (token expired) |
| Your connectors | (GitHub, Postgres examples) | **All of them today** |

> **The mental model that unifies both:** a client (Claude Code) asks a server "what tools do you have?", the server answers with a list, and Claude calls those tools on your behalf. *How* the server runs — local or remote — is plumbing. The tool loop is identical.

---

## How a Remote Connector Gets Attached

You have connectors already because they sync from your claude.ai account's **Connectors** settings. But you can also attach one by hand — and you *will* need this when you connect a server that isn't in the claude.ai directory (including, later, your own).

```bash
# Attach a remote MCP server by URL
claude mcp add --transport http drive https://drivemcp.googleapis.com/mcp/v1

# For servers that stream over Server-Sent Events instead:
claude mcp add --transport sse some-server https://example.com/mcp
```

Then authenticate:

```
> /mcp
```

`/mcp` opens an interactive panel listing every server and its status. Select one that says **Needs authentication**, press enter, and a browser window opens for OAuth. Approve the scopes, and the status flips to **Connected**.

> **You just saw this happen live.** Earlier in this session the Drive token had expired (`requires re-authorization`). The fix was exactly this: `/mcp` → Google Drive → approve in browser. Remote connectors do this periodically — the token is short-lived by design, so a leaked token stops being useful quickly.

### Removing / inspecting

```bash
claude mcp list          # status of every server
claude mcp get drive     # details of one server
claude mcp remove drive  # detach it
```

---

## Seeing What a Connector Actually Gives Claude

This is the part people skip, and it's the part that matters most. **A connector is exactly its list of tools — nothing more.** Claude cannot do anything to Google Drive that isn't a tool the Drive connector exposes. So before using a connector, learn its tools.

### The tool naming convention

Every MCP tool Claude sees is named:

```
mcp__<server-name>__<tool-name>
```

For your Drive connector, the tools are:

```
mcp__claude_ai_Google_Drive__create_file
mcp__claude_ai_Google_Drive__read_file_content
mcp__claude_ai_Google_Drive__download_file_content
mcp__claude_ai_Google_Drive__search_files
mcp__claude_ai_Google_Drive__list_recent_files
mcp__claude_ai_Google_Drive__copy_file
mcp__claude_ai_Google_Drive__get_file_metadata
mcp__claude_ai_Google_Drive__get_file_permissions
```

Read that list like a menu. It tells you the **whole** truth about what's possible:

- You can **create** a file, **read** it, **download** it, **search** for it, **copy** it, and inspect **metadata/permissions**.
- Notice what is **absent**: there is no `update_file`, no `append_row`, no `write_cell`. **That absence is not an accident you can work around by phrasing your request better — it's a hard boundary.** (File 2 is built entirely around this fact.)

### How to ask Claude what it has

You don't have to memorise tool names. Just ask:

```
> What Google Drive tools do you have access to right now?
```

Claude will enumerate them. Do this whenever you attach a new connector — it's the fastest way to learn a connector's shape.

---

## The Usage Loop (what actually happens when you ask)

When you type a request that needs a connector, this is the sequence:

```
1. You (natural language):  "Find my architecture doc in Drive and summarise it."
2. Claude decides:          this needs mcp__..._Google_Drive__search_files, then read_file_content
3. Permission prompt:       Claude Code shows you the exact tool call and waits for approval
4. You approve (or deny)
5. Connector runs:          the remote server calls the Google Drive API with YOUR token
6. Result returns:          Claude reads the content and answers you
```

Two things to internalise:

- **You are always in the loop at step 3.** No MCP tool runs silently. You see the tool name and its arguments and can deny it. (You can pre-approve tools you trust to reduce prompts — see `/permissions`.)
- **Claude chooses the tool, you approve the intent.** You speak goals ("track my tasks"), Claude maps them to tools (`create_file` with CSV). You don't call tools by name.

---

## The Security Model for Remote Connectors

The theory doc covered local-server security (your token, your machine). Remote connectors are a little different and worth stating plainly:

- **OAuth scopes are the fence.** When you approved the Drive connector, you granted specific scopes (e.g. "see and manage files you create"). The connector — and therefore Claude — can do **only** what those scopes allow. If Claude tries something outside them, Google refuses.
- **You never handle the token.** Unlike a local server where you paste a PAT into a file, the OAuth token is held by the connector. Nothing sensitive lands in your repo or settings. (Good — it means these config files are safe to commit.)
- **Per-call approval still applies.** Scopes are the outer fence; the per-tool-call permission prompt is the inner one. Both must pass.
- **Expiry is a feature.** The "requires re-authorization" you'll see periodically exists so a stolen token is useless within hours. Annoying, deliberate, correct.

---

## Common Misunderstanding: "A connector can do anything the app can do"

**The misunderstanding:** "I connected Google Drive, so Claude can do everything I can do in Drive — rename, share, edit cells, set up automations."

**The reality:** A connector can do **exactly the tools it exposes, within the scopes you granted** — no more. The Drive connector has no "edit a cell" tool, so Claude *cannot* edit a cell, no matter how you ask. When you evaluate whether MCP can do a job, **read the tool list first.** The tool list is the contract; the app's full UI is irrelevant.

This is the single most useful habit in this whole folder: **before asking "can Claude do X with this connector?", check whether a tool for X exists.**

→ Continue to: `01-google-sheets-task-tracker.md` — where we put this to work and meet the boundary head-on.
