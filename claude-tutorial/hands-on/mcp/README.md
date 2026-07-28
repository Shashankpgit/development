# Hands-On MCP — Using It in Real Projects

> **Last updated:** July 17, 2026
> **Prerequisite reading:** `../../05-mcp-servers/00-what-is-mcp.md` and `01-installing-and-using.md`
> Those two files explain the *theory* (what MCP is, the protocol, categories of servers).
> **This folder is the practice** — you use MCP on a real task and feel where it helps and where it doesn't.

---

## What This Folder Teaches

The `05-mcp-servers` files answered "what is MCP?". This folder answers a different question:

> "I have MCP connectors already attached to Claude. How do I actually *use* them to get real work done — and where are the edges?"

We learn by shipping one small real project: **a daily task tracker in Google Sheets**, driven entirely from Claude via the Google Drive connector you already have.

You will finish this folder able to:

1. Tell the difference between the **two kinds of MCP server** — and know which kind each of your connectors is.
2. Inspect exactly **what tools a connector gives Claude** (and why that list is the whole story).
3. Drive a real connector to **create, read, and search** files in your Google Drive.
4. Recognise a connector's **limits** and know your options when you hit one — including the moment where "build your own MCP" becomes the right answer.

---

## The Order (do not skip)

| # | File | What you'll learn | Time |
|---|------|-------------------|------|
| 1 | [00-using-existing-connectors.md](00-using-existing-connectors.md) | Remote vs local servers, how connectors attach & authenticate, how to see their tools, the security model | 25 min |
| 2 | [01-google-sheets-task-tracker.md](01-google-sheets-task-tracker.md) | The worked project: build a real task-tracker Sheet, use it, and hit the wall that motivates a custom server | 35 min |

**Then, and only then:** building your own MCP server (separate folder — coming after you've felt why you'd want one).

---

## Why This Order Matters (the WHY)

You asked to *use existing connectors before building your own*. That instinct is correct, and here's the reasoning:

- **Using MCP is free of code.** You learn the entire mental model — tools, permissions, the natural-language → tool-call loop — without writing a line. That model is *identical* whether the server is someone else's or yours.
- **Building MCP only makes sense once you've hit a wall.** If you build a server before you understand what off-the-shelf ones already do, you'll rebuild something that exists, or build the wrong thing. In file 2 you'll hit a genuine wall (you can *create* a Sheet but not *append a row* to it with this connector). That wall is the honest, concrete reason to build your own — and now you'll build the *right* thing.

So: use first, feel the edge, then build. That's the path.
