# Hands-On MCP — 2: Build a Daily Task Tracker in Google Sheets

> **Last updated:** July 17, 2026
> **Covers:** A real end-to-end project using the Google Drive connector — design, create, read, use, and the boundary you hit
> **35-minute read / build-along.**

This is the payoff. We use the connector you already have to create a real, usable Google Sheet that tracks your daily working tasks — with no code and no leaving Claude. Then we run straight into the connector's limit, and I'll show you every honest option for getting past it (one of which is the reason the "build your own MCP" chapter exists).

---

## Step 0 — Decide What "Done" Looks Like

Before touching any tool, define the artifact. A daily task tracker needs columns that answer: *what, for what, how urgent, where it stands, how long it took.*

| Column | Purpose |
|--------|---------|
| Date | The working day the task belongs to |
| Task | What you're doing |
| Project | Which effort it rolls up to (DevOps, Infra, Learning…) |
| Priority | P1 / P2 / P3 |
| Status | Todo / In Progress / Blocked / Done |
| Est (hrs) | Your up-front estimate |
| Actual (hrs) | What it really took (fill in after) |
| Notes | Blockers, links, context |

That's the target. Now — *can the Drive connector produce it?* (Remember the habit from file 1: check the tools first.)

---

## Step 1 — Reality Check Against the Tool List

The Drive connector's tools are: `create_file`, `read_file_content`, `download_file_content`, `search_files`, `list_recent_files`, `copy_file`, `get_file_metadata`, `get_file_permissions`.

For *creating a spreadsheet with content*, the one that matters is **`create_file`**. Here's the key part of its contract (paraphrased from the tool's own description):

> These Google types can be created with **no content**: `application/vnd.google-apps.document`, `...spreadsheet`, `...presentation`.
> When you upload content, **supported content is converted to the Google type** by default.

Read that second line twice — it's the whole trick.

---

## Step 2 — The Trick: CSV In, Google Sheet Out

The connector has **no** "write a cell" tool. So how do we get a *populated* spreadsheet? We don't write cells — we **upload a CSV and let Google convert it into a Sheet.**

- CSV (`text/csv`) is "supported content."
- By default the connector converts uploaded content to the matching Google first-party type.
- `text/csv` → `application/vnd.google-apps.spreadsheet`.
- Every comma becomes a column boundary, every newline a row. Google fills the cells for us.

So the plan is: hand `create_file` a CSV string as `textContent`, set `contentMimeType` to `text/csv`, and out comes a real Google Sheet with our columns and rows already in place.

### The actual tool call

This is what Claude runs on your behalf (you approve it at the permission prompt):

```
mcp__claude_ai_Google_Drive__create_file(
  title           = "Daily Task Tracker — Template",
  contentMimeType = "text/csv",
  textContent     = "Date,Task,Project,Priority,Status,Est (hrs),Actual (hrs),Notes\n
                     2026-07-17,Set up MCP hands-on guide,Learning/Claude,P1,In Progress,2,,Reading + doing the Sheets project\n
                     2026-07-17,Review open PRs,DevOps,P2,Todo,1,,\n
                     2026-07-17,Fix flaky deploy pipeline,Infra,P1,Blocked,3,,Waiting on cluster access\n
                     2026-07-17,Standup + planning,Team,P3,Done,0.5,0.5,"
)
```

In practice you never type that. You say:

```
> Create a Google Sheet called "Daily Task Tracker — Template" with columns
  Date, Task, Project, Priority, Status, Est (hrs), Actual (hrs), Notes,
  and seed it with a few example rows for today.
```

Claude assembles the CSV, chooses `create_file`, and shows you the call to approve.

### If you want a header-only template

Drop the example rows — just the first CSV line. You get an empty tracker with headers ready to go:

```
> ...same as above, but no example rows — just the header row.
```

---

## Step 3 — The Live Result

<!-- LIVE-ARTIFACT: filled in once the Drive connector is re-authorised and the sheet is created -->

*(This section records the real sheet created during the session — its file ID and link go here once Drive is re-authorised via `/mcp`.)*

To verify it landed, you don't guess — you ask Claude to search for it:

```
> Search my Drive for a file titled "Daily Task Tracker" and show me its link.
```

Claude runs `search_files` with a query like `title contains 'Daily Task Tracker'` and returns the file's ID and URL. Open it — you'll see your columns as a real spreadsheet, editable in the Google Sheets UI like any other.

---

## Step 4 — Using It Day to Day (what works today)

With the connector you have, these workflows work **right now**:

**Read it back / summarise:**
```
> Read my Daily Task Tracker and tell me what's still Todo or Blocked.
```
(`search_files` → `read_file_content`. The connector reads a Sheet's content as text.)

**Start next week from a copy:**
```
> Copy "Daily Task Tracker — Template" to a new file called
  "Task Tracker — Week of 2026-07-20".
```
(`copy_file`. Great for a fresh sheet each week without rebuilding the columns.)

**Generate a fresh day's rows to paste:**
```
> Based on my calendar today, draft today's task rows in the tracker's
  column format so I can paste them in.
```
(Claude produces CSV/tab-separated rows; you paste into Sheets. Note the *paste* — that's you, not the connector. Hold that thought.)

---

## Step 5 — The Wall (and why it's the point)

Here's the honest limit. Try this:

```
> Add a new row to my existing Daily Task Tracker: today, "Write incident postmortem", Infra, P1, Todo.
```

**This cannot be done with the Drive connector.** Look back at the tool list — there is no `update_file`, no `append_row`, no `write_cell`. `create_file` makes a *new* file; it can't edit an existing one. So "append today's task to the tracker I already have" — the single most natural thing you'd want from a *daily* tracker — is outside this connector's contract.

This is not a failure of phrasing or a bug. It's the boundary of what this particular connector exposes. And recognising it is exactly the skill file 1 drilled: **check the tools; the tool list is the contract.**

### Your options when you hit a boundary like this

There are three honest ways forward, in increasing order of power (and effort):

1. **Do the edit in the app.** Have Claude draft the row (Step 4); you paste it into the Google Sheets UI. Zero setup, but you're back to manual for the write.
2. **Attach a connector that *has* the tool.** A dedicated Google Sheets MCP server (as opposed to the general Drive connector) exposes cell-level tools like `append_values` / `update_values`. If one is available in your connectors directory, attaching it (file 1's `claude mcp add` flow) removes the wall immediately — still no code from you.
3. **Build your own MCP server.** Write a small server that wraps the Google Sheets API and exposes exactly the tool you want — `append_task_row(sheet_id, row)`. Then "add today's task to my tracker" becomes a single approved tool call. *This is the moment building-your-own pays off* — you're not reinventing Drive, you're adding the one capability the off-the-shelf connector lacks.

That progression — **app → better connector → your own server** — is the real-world decision tree for *every* MCP task. You don't build first. You build when the tool you need doesn't exist yet.

---

## What You Just Learned

- A connector's power is its tool list, and you plan around that list, not around what the app *could* theoretically do.
- You created a real, usable artifact in Google Drive with zero code, using the CSV→Sheet conversion trick baked into `create_file`.
- Reading, searching, and copying work today; **appending to an existing Sheet does not** — and you now know precisely why, and what your three options are.
- The wall you hit is the exact, concrete motivation for the next chapter: **building a small MCP server that adds the one missing tool.**

→ Next (later, once you've lived with this): **building your own MCP server** — starting from the `append_task_row` tool this project made you wish for.
