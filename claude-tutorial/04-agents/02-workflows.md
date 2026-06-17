# Claude Mastery — 12: Workflows — Orchestrating Many Agents

> **Last updated:** June 17, 2026
> **Covers:** What Workflows are, script syntax, pipeline vs parallel, practical workflow examples

**20-minute read. Workflows let you encode complex multi-agent processes as deterministic scripts.**

---

## Workflows vs Agents

```
Agents: Claude spawns them based on its judgment
        You can guide with "use multiple agents" or "do this in parallel"
        The orchestration is handled by Claude's reasoning

Workflows: YOU define the orchestration in a script
           Claude runs it deterministically
           Fan-out, loops, conditionals — all under your control
```

Agents are flexible and good for most tasks. Workflows are for when you need **exact, repeatable, large-scale orchestration** — like running 50 parallel analyses or a 4-phase CI pipeline.

---

## What Triggers Workflows

Workflows run when you explicitly ask for them. The keywords:
- "use a workflow"
- "run a workflow"  
- "fan out agents"
- "orchestrate this with subagents"
- "ultracode" keyword in your prompt
- Invoking a named saved workflow

You also see workflows in action when Claude Code processes very large requests automatically.

---

## Workflow Script Anatomy

```javascript
// Every workflow starts with meta
export const meta = {
  name: 'security-audit',
  description: 'Comprehensive security audit of the codebase',
  phases: [
    { title: 'Discover', detail: 'Map all security-sensitive code' },
    { title: 'Analyze',  detail: 'Deep analysis per area' },
    { title: 'Report',   detail: 'Synthesize all findings' },
  ],
}

// Script body runs in async context
// Built-in functions: agent(), parallel(), pipeline(), phase(), log()

phase('Discover')
const areas = await agent('List all security-sensitive directories and files', {
  schema: { type: 'object', properties: { areas: { type: 'array', items: { type: 'string' } } } }
})

phase('Analyze')
const findings = await parallel(areas.areas.map(area => () =>
  agent(`Audit ${area} for security vulnerabilities`, {
    label: `audit:${area}`,
    schema: { type: 'object', properties: { issues: { type: 'array' } } }
  })
))

phase('Report')
const report = await agent(`Synthesize these security findings: ${JSON.stringify(findings)}`)
return report
```

---

## Core Workflow Functions

### `agent(prompt, opts?)` — Spawn One Agent

```javascript
// Basic
const result = await agent('Find all TODO comments in the codebase')
// Returns: the agent's response text as a string

// With structured output (schema enforces JSON shape)
const findings = await agent('List all API endpoints', {
  schema: {
    type: 'object',
    properties: {
      endpoints: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            path: { type: 'string' },
            method: { type: 'string' },
            authenticated: { type: 'boolean' }
          }
        }
      }
    }
  }
})
// findings.endpoints is a typed array — no parsing needed

// With model override (use Opus for hard reasoning)
const analysis = await agent('Analyze this security issue deeply', {
  model: 'claude-opus-4-8'
})

// With agent type
const map = await agent('Map all files in src/', {
  agentType: 'Explore'
})
```

### `parallel(thunks)` — Run Multiple Agents Simultaneously

```javascript
// Run 3 audits at the same time
const results = await parallel([
  () => agent('Audit src/api/ for injection vulnerabilities'),
  () => agent('Audit src/auth/ for authentication issues'),
  () => agent('Audit src/models/ for SQL injection'),
])
// results[0] = api findings, results[1] = auth findings, results[2] = model findings
// All three ran AT THE SAME TIME
```

### `pipeline(items, ...stages)` — Process Items Through Stages

```javascript
const services = ['vault-api', 'vault-frontend', 'vault-worker']

const results = await pipeline(
  services,
  
  // Stage 1: analyze each service
  service => agent(`Analyze ${service} for performance issues`, {
    label: `analyze:${service}`
  }),
  
  // Stage 2: for each analysis, generate fix recommendations
  (analysis, service) => agent(`Given this analysis of ${service}: ${analysis}
    Generate specific fix recommendations with priority order`, {
    label: `recommend:${service}`
  })
)
// vault-api can be in stage 2 while vault-worker is still in stage 1
// Wall-clock time = slowest single service chain, not sum of all
```

Key difference: `pipeline()` has NO barrier between stages. Item A moves to stage 2 as soon as stage 1 finishes for A — it doesn't wait for B and C to finish stage 1 first. This is faster than `parallel()` for multi-stage work.

### `phase(title)` — Group Progress Display

```javascript
phase('Discovery')    // subsequent agents show under "Discovery" group in UI
// ... discovery agents ...

phase('Analysis')     // subsequent agents show under "Analysis" group
// ... analysis agents ...
```

### `log(message)` — Progress Messages

```javascript
log(`Processing ${items.length} files...`)
log(`Found ${findings.length} issues in API layer`)
```

---

## Practical Workflow: Codebase Migration

```javascript
export const meta = {
  name: 'migrate-console-to-logger',
  description: 'Replace all console.log with Winston logger',
  phases: [
    { title: 'Find', detail: 'Locate all console.log usages' },
    { title: 'Migrate', detail: 'Replace per file' },
    { title: 'Verify', detail: 'Confirm all replaced' },
  ],
}

phase('Find')
const scanResult = await agent('Find all files containing console.log', {
  agentType: 'Explore',
  schema: {
    type: 'object',
    properties: {
      files: { type: 'array', items: { type: 'string' } }
    }
  }
})

log(`Found console.log in ${scanResult.files.length} files`)

phase('Migrate')
const migrations = await parallel(
  scanResult.files.map(file => () =>
    agent(`In ${file}: replace all console.log calls with our Winston logger.
    Import: const logger = require('./src/utils/logger');
    Map: console.log → logger.info, console.error → logger.error, 
    console.warn → logger.warn.
    Preserve the log message content.`, {
      label: `migrate:${file}`,
      isolation: 'worktree'  // each agent gets isolated copy of repo
    })
  )
)

phase('Verify')
const verification = await agent('Search for any remaining console.log in the codebase', {
  agentType: 'Explore'
})

return {
  migrated: scanResult.files.length,
  remaining: verification
}
```

---

## Practical Workflow: Multi-Service Deployment

```javascript
export const meta = {
  name: 'deploy-all-services',
  description: 'Deploy all changed services to staging',
  phases: [
    { title: 'Detect',  detail: 'Find changed services' },
    { title: 'Deploy',  detail: 'Deploy each service in parallel' },
    { title: 'Verify',  detail: 'Health check all services' },
  ],
}

const services = args || ['vault-api', 'vault-worker', 'vault-frontend']

phase('Detect')
const changedServices = await agent(`
  Check which of these services have uncommitted or recent changes: ${services.join(', ')}
  Run: git diff --name-only HEAD~1 HEAD
  Return only the service names that have changes.
`, {
  schema: {
    type: 'object',
    properties: { changed: { type: 'array', items: { type: 'string' } } }
  }
})

log(`Deploying ${changedServices.changed.length} changed services`)

phase('Deploy')
const deployResults = await parallel(
  changedServices.changed.map(service => () =>
    agent(`Deploy ${service} to staging namespace:
    1. Get current SHA: git rev-parse --short HEAD
    2. Run: helm upgrade ${service} ./helm/${service}/ -n staging --set image.tag=<SHA> --atomic --timeout 5m
    3. Report success/failure with details`, {
      label: `deploy:${service}`
    })
  )
)

phase('Verify')
const healthChecks = await parallel(
  changedServices.changed.map(service => () =>
    agent(`Verify ${service} is healthy in staging:
    1. kubectl get pods -n staging -l app=${service}
    2. curl -sf https://staging.vault.internal/${service}/health
    Report: HEALTHY or DEGRADED with details`, {
      label: `health:${service}`
    })
  )
)

return { deployed: deployResults, health: healthChecks }
```

---

## Running a Workflow

### From Your Prompt
```
> "Use a workflow to audit all 12 microservices for security vulnerabilities in parallel"
[Claude writes and runs a workflow automatically]
```

### Invoking a Named Saved Workflow
```
> /security-audit           (if you've saved it as a skill)
> Run the "deploy-all-services" workflow with args: ["vault-api", "vault-worker"]
```

### Watching Progress
While a workflow runs, you see a live progress tree:
```
▸ security-audit
  ✓ Phase: Discover (4.2s)
  ✓ Phase: Analyze
    ✓ audit:src/api (12.3s) — 3 issues found
    ✓ audit:src/auth (9.1s) — 1 CRITICAL issue
    ⠋ audit:src/models (running...) — 5.2s
  ● Phase: Report (waiting)
```

Use `/workflows` to see all running and recent workflows.

---

## When to Use Workflows vs Regular Agents

| Situation | Use |
|-----------|-----|
| Small, one-off parallel task | Ask Claude to use agents ("do these in parallel") |
| Complex task you'll repeat | Workflow (deterministic, repeatable) |
| Task needs exact control flow | Workflow (loops, conditionals) |
| 50+ parallel operations | Workflow (parallel() handles queuing) |
| One-time analysis | Regular agent or ask Claude |
| CI/CD automation | Workflow (runs headlessly) |

---

## Common Misunderstanding: "Workflows are always better than asking Claude"

**The misunderstanding:** "I should always write a workflow for complex tasks."

**The reality:** Workflows have a setup cost — you're writing JavaScript. For most tasks, just asking Claude well is faster:

```
"Audit each of these 5 services for security issues, run them in parallel, 
then give me a consolidated report"
```

This works without a workflow. Claude will spawn agents appropriately.

Write a workflow when:
- You'll run the EXACT same process repeatedly (CI/CD, weekly audits)
- The orchestration has complex logic (conditional branching, loops)
- You need exact control over what happens (compliance, risk management)
- The task involves 20+ agents that need careful ordering

For anything else, describe what you want and let Claude figure out the parallelization.

→ Continue to: `../05-mcp-servers/00-what-is-mcp.md`
