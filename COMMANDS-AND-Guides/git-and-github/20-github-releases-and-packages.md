# Git & GitHub — 20: Releases and GitHub Packages

> **Last updated:** June 25, 2026
> **Covers:** Tags → Releases, release notes, GitHub Packages as a registry (Docker, npm, Maven)

**20-minute read. How your code becomes a distributed artifact.**

---

## The Distribution Problem

You've built something. How do users GET it?

- Compiled app? → Users need to download a specific version's binary
- npm library? → Users run `npm install your-package`
- Docker image? → Someone does `docker pull your-image:v1.2.3`
- Java library? → Maven/Gradle pulls from a registry

GitHub provides the infrastructure for all of these: **GitHub Releases** for versioned snapshots, **GitHub Packages** for artifact registries.

---

## Git Tags vs GitHub Releases

These are different things:

```
Git Tag:           A pointer to a specific commit in your local/remote git history
                   Created with: git tag v1.2.3
                   
GitHub Release:    A GitHub-layer feature built ON TOP of a tag
                   Adds: release notes, file attachments, changelog, download page
                   Created via GitHub UI or gh CLI
```

A tag says "this commit is version 1.2.3."
A release says "here's everything a user needs to know about version 1.2.3, plus the files to download."

---

## Creating a Release

### Manual (via GitHub UI)

```
GitHub → Your repo → Releases → Draft a new release

1. Choose a tag: v1.2.3 (create new if it doesn't exist)
2. Target: main branch
3. Release title: "v1.2.3 — Email Verification"
4. Description (release notes):
   ## What's New
   - Email verification now required for new accounts
   - Password strength meter on registration
   
   ## Bug Fixes
   - Fixed race condition in concurrent registration
   - Fixed JWT iat validation
   
   ## Breaking Changes
   None

5. Attach files: (optional) compiled binaries, zip archives
6. Mark as latest release: ✓
7. Publish release
```

### Via gh CLI (Better for Automation)

```bash
# Create a release from the latest tag
gh release create v1.2.3 \
  --title "v1.2.3 — Email Verification" \
  --notes "## What's New
  - Email verification required
  - Password strength meter" \
  --latest

# Create a release and attach binary files
gh release create v1.2.3 \
  --title "v1.2.3" \
  --generate-notes \          # auto-generate notes from commit messages
  ./dist/vault-api-linux-amd64 \
  ./dist/vault-api-darwin-arm64

# Create a pre-release (beta)
gh release create v2.0.0-beta.1 \
  --title "v2.0.0 Beta 1" \
  --prerelease \
  --notes "Beta release — do not use in production"

# List releases
gh release list

# View a release
gh release view v1.2.3
```

---

## Automated Releases with GitHub Actions

The real-world pattern: a GitHub Action creates the release when you push a version tag.

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
    - 'v*.*.*'          # triggers when you push v1.2.3

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write   # needed to create releases
    steps:
    
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # full history for changelog generation
    
    - name: Build
      run: npm ci && npm run build
    
    - name: Generate changelog
      id: changelog
      uses: orhun/git-cliff-action@v3
      with:
        config: cliff.toml
        args: --current
    
    - name: Create GitHub Release
      uses: softprops/action-gh-release@v2
      with:
        tag_name: ${{ github.ref_name }}
        name: ${{ github.ref_name }}
        body: ${{ steps.changelog.outputs.content }}
        files: |
          dist/vault-api-linux-amd64
          dist/vault-api-darwin-arm64
```

**The workflow:**
```bash
# Developer on their machine:
git tag v1.2.3
git push origin v1.2.3

# GitHub Actions:
# 1. Triggers automatically
# 2. Builds the project
# 3. Generates changelog from commit messages
# 4. Creates GitHub Release with release notes + binary attachments
# All automated — no manual steps
```

---

## Semantic Versioning (What v1.2.3 Means)

```
v  1   .   2   .   3
   │       │       │
   │       │       └── PATCH: bug fixes, no new features
   │       └────────── MINOR: new features, backwards compatible
   └────────────────── MAJOR: breaking changes

v1.0.0  → Initial stable release
v1.1.0  → Added email verification (new feature)
v1.1.1  → Fixed crash in email verification (bug fix)
v2.0.0  → Changed auth from sessions to JWT (breaking change)

Pre-release:
v2.0.0-alpha.1  → Very early, unstable
v2.0.0-beta.1   → Feature complete, testing
v2.0.0-rc.1     → Release candidate, final testing
v2.0.0          → Stable release
```

Browsers, npm, Maven, Go modules all understand semver and use it for dependency resolution.

---

## GitHub Packages — Your Private Registry

GitHub Packages is a place to store and distribute artifacts from your code.

Think of it like Docker Hub or npm Registry, but:
- **Private** by default (only org members can pull)
- **Authenticated** with your GitHub credentials
- **Integrated** with your repos (each package shows what repo it came from)
- **Free storage** for public packages (paid for private)

### What You Can Store

| Package Type | Registry URL | Use Case |
|-------------|-------------|---------|
| Docker images | `ghcr.io` | Kubernetes deployments |
| npm packages | `npm.pkg.github.com` | Internal JS libraries |
| Maven/Gradle | `maven.pkg.github.com` | Internal Java libraries |
| RubyGems | `rubygems.pkg.github.com` | Ruby libraries |
| NuGet | `nuget.pkg.github.com` | .NET libraries |

---

## GitHub Container Registry (ghcr.io)

The most common use case for DevOps: storing Docker images.

### Push a Docker Image

```bash
# Login with your GitHub token
echo $GITHUB_TOKEN | docker login ghcr.io -u your-username --password-stdin

# Build and tag your image
docker build -t ghcr.io/your-org/vault-api:v1.2.3 .
docker build -t ghcr.io/your-org/vault-api:latest .

# Push
docker push ghcr.io/your-org/vault-api:v1.2.3
docker push ghcr.io/your-org/vault-api:latest
```

### Pull an Image

```bash
# Anyone with access to your org can pull
docker pull ghcr.io/your-org/vault-api:v1.2.3
```

### In Kubernetes (Helm values)

```yaml
# helm/vault-api/values.yaml
image:
  repository: ghcr.io/your-org/vault-api
  tag: "v1.2.3"
  pullPolicy: IfNotPresent

imagePullSecrets:
- name: ghcr-credentials    # Kubernetes Secret with GitHub token
```

### Automated Build and Push (GitHub Actions)

```yaml
# .github/workflows/docker-build.yml
name: Build and Push Docker Image

on:
  push:
    branches: [main]
    tags: ['v*.*.*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}    # your-org/vault-api

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write    # needed to push to GitHub Packages
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}   # automatic, no setup needed
    
    - name: Extract metadata (tags, labels)
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=semver,pattern={{version}}         # v1.2.3 → 1.2.3
          type=semver,pattern={{major}}.{{minor}} # v1.2.3 → 1.2
          type=sha,prefix=sha-                    # sha-abc1234
          type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}
    
    - name: Build and push
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha           # GitHub Actions cache
        cache-to: type=gha,mode=max
```

This workflow:
- On push to main: builds and pushes with `latest` + `sha-abc1234` tags
- On push of `v1.2.3` tag: builds and pushes with `1.2.3`, `1.2`, and `latest` tags
- Uses GitHub Actions cache to speed up subsequent builds
- Uses `GITHUB_TOKEN` (automatic, no secrets to set up)

---

## npm Packages (GitHub Packages)

For internal JavaScript/TypeScript libraries that you share across projects:

```bash
# .npmrc in your project
@your-org:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
```

```json
// package.json — must be scoped to your org
{
  "name": "@your-org/vault-sdk",
  "version": "1.2.3",
  "publishConfig": {
    "registry": "https://npm.pkg.github.com"
  }
}
```

```bash
# Publish
npm publish

# Install in another project
npm install @your-org/vault-sdk
```

---

## The Full Release Flow (Combined)

In a real project, a release triggers a chain reaction:

```
Developer:
  git tag v1.2.3
  git push origin v1.2.3

GitHub Actions (triggered by tag):

  Job 1: Test
    npm test → all tests pass

  Job 2: Build Docker image (depends on Job 1)
    docker build → push to ghcr.io/your-org/vault-api:1.2.3
    docker push → image available
  
  Job 3: Create GitHub Release (depends on Job 1)
    generate changelog from commits
    create GitHub Release with notes
    attach any build artifacts
  
  Job 4: Deploy to production (depends on Job 2)
    helm upgrade --set image.tag=1.2.3
    notify Slack: "v1.2.3 deployed to production"

Result:
  - GitHub Release page shows v1.2.3 with changelog
  - Docker image available at ghcr.io/your-org/vault-api:1.2.3
  - Production cluster running v1.2.3
  - Team notified
  
All triggered by: git push origin v1.2.3
```

---

## Common Misunderstanding: "I should manage my own Docker registry"

**The misunderstanding:** "We need to self-host a Docker registry (Harbor, ECR) for our images."

**The reality:** For most teams, GitHub Container Registry (ghcr.io) is sufficient:
- Free for public images
- Reasonable pricing for private
- No infrastructure to maintain
- Integrated with GitHub authentication
- Works with Kubernetes imagePullSecrets

Use a dedicated registry (ECR, GAR, Harbor) when:
- You need regional distribution (images pulled in multiple regions, latency matters)
- Compliance requires data residency in a specific cloud
- You need advanced features like image signing, vulnerability scanning built into the registry

For 90% of teams: ghcr.io is fine.

→ Continue to: `21-github-pages.md`
