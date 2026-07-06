# Git & GitHub — 21: GitHub Pages — Free Static Hosting

> **Last updated:** June 25, 2026
> **Covers:** What GitHub Pages is, how to deploy, custom domains, real use cases

**20-minute read. Host documentation, portfolios, and landing pages directly from your repo.**

---

## What Is GitHub Pages?

GitHub Pages turns a repo (or part of it) into a live website — free.

```
Your repo's code / docs
         │
         ▼
GitHub Pages (hosting)
         │
         ▼
https://your-username.github.io/your-repo
         (or your custom domain)
```

No server, no deployment pipeline needed (for basic use). GitHub renders the files and serves them.

**What it serves:** Static files only — HTML, CSS, JavaScript, images. No server-side code (no Node.js, no Python, no databases). It's a static host.

**Free for:** Public repos (always). Private repos (GitHub Pro and Team plans).

---

## Three Ways to Source GitHub Pages

### Option 1: From a Branch (Simplest)

Point GitHub Pages at a specific branch. GitHub serves whatever's there.

```
Settings → Pages → Source → Branch: gh-pages → Save
```

Your site lives at: `https://username.github.io/repo-name`

```bash
# Create and push the gh-pages branch
git switch --orphan gh-pages      # orphan = no history from main
echo "<h1>Hello World</h1>" > index.html
git add . && git commit -m "Initial pages"
git push origin gh-pages

# → Your site is live immediately
```

### Option 2: From a Folder on Main

Keep your docs inside your main branch in a `docs/` folder.

```
Settings → Pages → Source → Branch: main, Folder: /docs
```

Your markdown files in `docs/` become your site.

### Option 3: From GitHub Actions (Full Control)

A workflow builds your site and deploys it. The most powerful option.

```
Settings → Pages → Source → GitHub Actions
```

You control exactly how the site is built — any static site generator (Hugo, MkDocs, Docusaurus, Next.js export, etc.).

---

## Use Case 1: Project Documentation

The most common use case. Document your project, host it at your domain.

```
Popular static site generators for docs:

MkDocs          → mkdocs.org (Python, simple, good for API docs)
Docusaurus      → docusaurus.io (React, good for open-source projects)
Hugo            → gohugo.io (Go, extremely fast build)
Jekyll          → jekyllrb.com (Ruby, GitHub's original choice)
VitePress       → vitepress.dev (Vue, great for devtools)
```

**MkDocs + GitHub Pages workflow:**

```yaml
# .github/workflows/docs.yml
name: Deploy Documentation

on:
  push:
    branches: [main]
    paths:
    - 'docs/**'          # only rebuild when docs change
    - 'mkdocs.yml'

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: write    # needed to push to gh-pages branch
    steps:
    
    - uses: actions/checkout@v4
    
    - uses: actions/setup-python@v5
      with:
        python-version: '3.x'
    
    - name: Install MkDocs
      run: pip install mkdocs-material
    
    - name: Deploy to GitHub Pages
      run: mkdocs gh-deploy --force
      # This builds and pushes to gh-pages branch automatically
```

```yaml
# mkdocs.yml
site_name: Vault App Documentation
theme:
  name: material
  palette:
    primary: indigo

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - API Reference: api/
  - Deployment Guide: deployment.md
```

Result: push to main → docs automatically rebuilt and deployed → live at `your-org.github.io/vault-app`.

---

## Use Case 2: Personal Portfolio

A portfolio site hosted for free at `your-username.github.io`.

**Special repo name:** Create a repo named `<username>.github.io` — this becomes your root GitHub Pages site (no subdirectory in URL).

```bash
# Create repo named: shashank.github.io
# Push your portfolio HTML/CSS/JS to main branch
# Settings → Pages → Branch: main → /root

# Live at: https://shashank.github.io (not /repo-name)
```

---

## Use Case 3: Component Library / Storybook

React/Vue component libraries often publish their Storybook to GitHub Pages so the team can view components without running code locally.

```yaml
# .github/workflows/storybook.yml
name: Deploy Storybook

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: 20
    - run: npm ci
    - run: npm run build-storybook -- -o ./storybook-static
    - name: Deploy to GitHub Pages
      uses: peaceiris/actions-gh-pages@v4
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./storybook-static
```

Team members go to `your-org.github.io/vault-frontend` to see all components.

---

## Custom Domain Setup

You can use your own domain instead of the `github.io` URL.

```
Steps:
1. Add your domain in Settings → Pages → Custom domain
   (e.g., docs.vault.example.com)

2. Add DNS records at your domain registrar:
   CNAME: docs.vault.example.com → your-org.github.io
   (or A records if using the apex domain)

3. GitHub automatically provisions a Let's Encrypt cert
   (Yes — GitHub Pages handles TLS automatically with cert-manager-like setup)

4. Check "Enforce HTTPS"
```

Result: `docs.vault.example.com` serves your GitHub Pages site with valid HTTPS.

---

## GitHub Pages vs Alternatives

| | GitHub Pages | Netlify | Vercel | S3+CloudFront |
|--|-------------|---------|--------|---------------|
| Cost | Free | Free tier | Free tier | Pay per use |
| Custom domain | ✓ | ✓ | ✓ | ✓ |
| HTTPS | ✓ automatic | ✓ | ✓ | Manual |
| Build step | Via Actions | Built-in | Built-in | Via Actions |
| Server-side functions | ✗ | ✓ | ✓ | ✗ |
| Deployment speed | Good | Faster | Fastest | Good |
| Analytics | ✗ | ✓ | ✓ | Via CloudWatch |

Use GitHub Pages when your site is already in GitHub and you want zero additional setup. Use Netlify/Vercel for more features (preview deployments per PR, server functions, better build systems).

---

## Common Misunderstanding: "GitHub Pages can run my Node.js API"

**The misunderstanding:** "I'll host my backend on GitHub Pages to save money."

**The reality:** GitHub Pages is static only. It serves HTML, CSS, JavaScript files. It cannot:
- Run a Node.js/Python/Go server
- Connect to a database
- Handle server-side authentication
- Process file uploads

For a backend API, you need: a VPS (DigitalOcean, Hetzner), a container platform (Railway, Render, Fly.io), or a cloud provider (AWS, GCP, Azure).

GitHub Pages is perfect for: documentation, portfolios, landing pages, marketing sites, component libraries, single-page apps that call an API hosted elsewhere.

→ Continue to: `22-github-security-features.md`
