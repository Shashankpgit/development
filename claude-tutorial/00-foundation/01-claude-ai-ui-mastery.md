# Claude Mastery — 01: claude.ai UI Mastery

> **Last updated:** June 17, 2026
> **Covers:** claude.ai web interface, Projects, Artifacts, styles, keyboard shortcuts

**20-minute read. Most people use 20% of what claude.ai offers. Learn the other 80%.**

---

## The claude.ai Interface Layout

```
┌──────────────────────────────────────────────────────────────┐
│  ≡  Projects      NEW CHAT                     [Model ▼]     │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Sidebar:                    Main area:                      │
│  ┌─────────────────┐         Conversation                    │
│  │ ★ Starred       │                                         │
│  │ ─────────────   │                                         │
│  │ Projects        │                                         │
│  │  └ vault-app    │                                         │
│  │  └ learning     │                                         │
│  │ ─────────────   │                                         │
│  │ Recent chats    │                                         │
│  │  └ Docker help  │                                         │
│  │  └ K8s debug    │                                         │
│  └─────────────────┘         [    Your message here    ] [↵] │
└──────────────────────────────────────────────────────────────┘
```

---

## Projects — The Feature Most People Ignore

Projects are persistent conversation containers. They give Claude:
1. **Shared context** — every conversation in a project shares the same "project instructions"
2. **Persistent files** — upload files that stay available across all conversations in the project
3. **Chat history** — all conversations stay grouped

### Creating a Project

```
Left sidebar → Projects → New Project
```

Give it a name, then click "Edit project instructions."

### Project Instructions — Your Permanent System Prompt

This is the most powerful feature in claude.ai. Write instructions once; they apply to every conversation in this project forever.

**Example: Project Instructions for a DevOps project**

```
You are helping me manage the Vault password manager application.

## Tech Stack
- Backend: Node.js 20, Express, PostgreSQL 15
- Infrastructure: AWS EKS (Kubernetes), Terraform for infra
- Deployment: Helm charts in ./helm/, GitHub Actions CI/CD
- Monitoring: Prometheus + Grafana + Loki

## Conventions
- Environment variables are in .env files and K8s Secrets
- All k8s work is in the `production` namespace unless I say otherwise
- We use kebab-case for resource names
- Helm release name: vault-app

## My Role
I am the lead DevOps engineer. I handle infrastructure and deployments.
The dev team handles application code.

## Preferences
- Show me commands I can run, not just theory
- When suggesting Kubernetes changes, show the YAML
- Always explain WHY before HOW
- Flag any security concerns immediately
```

Now every conversation in this project starts with Claude already knowing all of this. You never have to re-explain your stack.

### Files in Projects

You can upload files that persist across all conversations:
- Architecture diagrams
- Schema files
- Environment documentation
- Team conventions document

```
Project → + Add content → Upload files
```

Supported: text files, code, PDF, images. Up to the model's context limit.

**DevOps use case:** Upload your `values.production.yaml`, the `docker-compose.yml`, and a architecture diagram. Claude now has your complete infrastructure context in every conversation.

---

## Selecting Models

```
New conversation → Model dropdown (top right)
```

Available models:
- **Claude Haiku 4.5** — fastest, cheapest. Good for: quick questions, simple tasks
- **Claude Sonnet 4.6** — default. Good for: most coding and engineering tasks
- **Claude Opus 4.8** — most capable. Good for: complex architecture, security audits, hard debugging

Switch mid-conversation: click the model name at the top → select a different one.

**When to switch to Opus:**
- Debugging a hard, multi-system problem where Sonnet keeps going in circles
- Designing a system architecture and you want deep reasoning about tradeoffs
- Security review where nuance matters

---

## Artifacts — Code and Documents in Their Own Pane

When you ask Claude to write code, create documents, or produce structured output, it can create an **Artifact** — a side panel that shows the rendered/formatted result separately from the conversation.

```
┌─────────────────────────────────────┬────────────────────┐
│  Conversation                       │  Artifact          │
│                                     │  ┌────────────┐   │
│  Here's the React component:        │  │ <Preview>  │   │
│                                     │  │            │   │
│  It renders a sidebar with...       │  │ [rendered  │   │
│                                     │  │  component]│   │
│                                     │  └────────────┘   │
│                                     │  [Copy] [Download] │
└─────────────────────────────────────┴────────────────────┘
```

Artifact types Claude creates:
- **Code** — syntax highlighted, copyable
- **Markdown** — rendered as formatted text
- **HTML** — rendered as a live preview in the browser
- **React components** — rendered as interactive previews
- **SVG** — rendered as vector graphics

**Triggering artifacts:** Just ask for something substantial. Claude decides when to use an artifact vs inline code. You can force it with "Create this as an artifact."

**Iterating on artifacts:** Click the artifact → "Edit" → describe the change. Claude updates it without rewriting the whole conversation.

---

## Uploading Files and Images

```
Message input → paperclip icon → Upload
```

Supported formats:
- Code files (any language)
- Text, Markdown, PDF
- Images (PNG, JPG, GIF, WebP)
- CSV, JSON, XML

**Image uploads — what Claude can do:**
- Read text in screenshots
- Analyze UI screenshots and suggest improvements
- Describe diagrams and architecture images
- Read error messages from screenshots
- Analyze log output in screenshot form

**Real use case:** Take a screenshot of your Grafana dashboard showing high latency → paste it into Claude → "What's causing this spike and what should I investigate?" Claude reads the dashboard visually and gives targeted suggestions.

---

## Voice Input

```
Message input → microphone icon → speak
```

Works well for:
- Describing a problem when typing feels slow
- Dictating while looking at a running system
- Quick questions without breaking your flow

Not ideal for: sharing code (transcription of code is messy).

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Enter` | Send message |
| `Shift + Enter` | New line in message |
| `↑` (in empty input) | Edit last message |
| `Ctrl/Cmd + K` | New conversation |
| `Ctrl/Cmd + /` | Show shortcuts |
| `Ctrl/Cmd + Shift + C` | Copy last response |
| `Esc` | Cancel generation |

---

## Conversation Controls

**Stop generation:** Hit `Esc` or click the stop button. Claude stops mid-generation.

**Edit your message:** Hover over your message → pencil icon → edit → re-send. This forks the conversation from that point — useful for trying a different approach.

**Regenerate a response:** At the bottom of Claude's response → refresh icon. Claude tries again with the same prompt.

**Copy a response:** Bottom of any response → copy icon. Copies the full markdown.

**Rate a response:** Thumbs up/down. Helps improve Claude.

---

## The `/` Command in Claude.ai

In the message input, type `/` to see a quick command menu:

```
/new         → start a new conversation
/search      → search your conversation history  
```

More slash commands are available (depends on your plan and current UI version).

---

## Styles — Controlling Response Format

In Projects: **Project Settings → Response style**

Options:
- **Normal** — balanced, default
- **Concise** — shorter responses, less explanation
- **Explanatory** — more detailed, more "why"
- **Formal** — professional tone

You can also specify in your project instructions:
```
Always respond concisely. Skip pleasantries.
Use code blocks for all commands.
When explaining, use numbered steps.
```

---

## What claude.ai Cannot Do (That Claude Code Can)

Be clear on these limitations — they're why Claude Code exists:

| Cannot | Why | Alternative |
|--------|-----|-------------|
| Read files on your computer | Browser sandbox — no filesystem access | Upload the file manually, or use Claude Code |
| Run commands | No system access | Claude Code can run shell commands |
| Access your private GitHub repos | No authentication | Use Claude Code with gh CLI, or the GitHub MCP server |
| See your running Docker containers | No Docker socket access | Claude Code on your machine can run docker commands |
| Deploy anything | No cloud credentials | Claude Code with proper setup can deploy |
| Keep context permanently without Projects | Each new chat starts fresh | Use Projects for persistence |

---

## Real-World Scenario: Using Projects for Team Knowledge

A DevOps team shares one claude.ai project for "Infrastructure Q&A":

**Project Instructions:**
```
This project is for our infrastructure team at Sanketika.

## Our Setup
- AWS ap-south-1 region, account ID: 123456789
- EKS cluster: vault-cluster (Kubernetes 1.29)
- 3 namespaces: staging, production, monitoring
- We use Helm for all deployments
- Terraform state is in S3: sanketika-terraform-state

## Conventions
- Never suggest changes without showing the exact command
- Always mention if something requires production access approval
- Tag security-sensitive operations with ⚠️

## Team Members Who Use This
- Shashank (lead DevOps) — full production access
- Akash (dev) — staging only
```

Every team member uses the same project → consistent answers, team context always loaded → no "what's our cluster name again?" questions.

---

## Common Misunderstanding: "New chat = fresh Claude"

**The misunderstanding:** "Every new chat is a blank slate — Claude doesn't remember anything."

**The reality:** By default, yes — each new conversation starts fresh. But:

1. **Projects** → Claude has your project instructions and uploaded files in every conversation
2. **Claude Code** → has a persistent memory system (section 02 of this guide) that survives across sessions

The mental model:
- `claude.ai` without a project = amnesia every chat
- `claude.ai` with a Project = remembers your project context
- `Claude Code` with CLAUDE.md = knows your codebase permanently
- `Claude Code` with Memory = remembers your preferences, decisions, and history

→ Continue to: `../01-claude-code-cli/00-installation-and-setup.md`
