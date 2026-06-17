# GitHub Actions — Part 02: Using Actions, Marketplace, and Caching

**20-minute read. Actions are reusable building blocks. Know the essential ones and how to use them correctly.**

---

## The `uses:` Keyword

Instead of writing shell commands for everything, you use pre-built actions:

```yaml
steps:
  - uses: actions/checkout@v4         # checkout your repo
  - uses: actions/setup-node@v4       # install Node.js
  - uses: docker/login-action@v3      # login to container registry
```

Three sources for actions:
1. **GitHub Marketplace**: `owner/repo@version` → `actions/checkout@v4`
2. **Same repository**: `./path/to/action-dir` → `./my-actions/deploy`
3. **Docker Hub**: `docker://image:tag` → `docker://alpine:3.19`

---

## Essential Actions Every DevOps Engineer Uses

### actions/checkout — Always First

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0          # default: 1 (shallow clone — only latest commit)
                            # 0 = full history (needed for git log, versioning)
    ref: ${{ github.sha }}  # specific commit/branch/tag (default: current ref)
    token: ${{ secrets.PAT_TOKEN }}   # use PAT if you need to push back

# For monorepos — checkout a specific path:
- uses: actions/checkout@v4
  with:
    path: ./app             # checkout into a subdirectory
    sparse-checkout: |      # only checkout these paths (faster)
      src/
      package.json
      Dockerfile
```

### actions/setup-node — Node.js

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    node-version-file: '.nvmrc'     # read version from .nvmrc or .node-version
    cache: 'npm'                     # cache npm/yarn/pnpm node_modules automatically
    registry-url: 'https://registry.npmjs.org'   # for npm publish

- run: npm ci                        # after setup, use npm ci (not npm install)
```

### actions/setup-python — Python

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: '3.12'
    python-version-file: '.python-version'
    cache: 'pip'            # automatically caches pip packages

- run: pip install -r requirements.txt
```

### actions/setup-java — Java

```yaml
- uses: actions/setup-java@v4
  with:
    java-version: '21'
    distribution: 'temurin'    # Eclipse Temurin (formerly AdoptOpenJDK)
    cache: 'maven'             # or 'gradle'
```

### actions/setup-go — Go

```yaml
- uses: actions/setup-go@v5
  with:
    go-version: '1.22'
    cache: true               # caches Go module download cache
```

---

## Docker Actions

### docker/login-action — Authenticate to Registries

```yaml
# Docker Hub
- uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}  # use access token, not password

# GitHub Container Registry (GHCR) — uses built-in GITHUB_TOKEN
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}   # automatically provided, no setup needed

# AWS ECR — no static credentials needed with OIDC (covered in file 03)
- uses: docker/login-action@v3
  with:
    registry: 123456789.dkr.ecr.ap-south-1.amazonaws.com
    username: AWS
    password: ${{ steps.ecr-login.outputs.docker_password }}
```

### docker/build-push-action — Build and Push

```yaml
- uses: docker/setup-buildx-action@v3   # required before build-push-action

- uses: docker/build-push-action@v5
  with:
    context: .                          # build context (where Dockerfile is)
    file: ./Dockerfile                  # explicit path if not in root
    push: true                          # push to registry (false = build only)
    tags: |
      ghcr.io/sanketika/vault-app:latest
      ghcr.io/sanketika/vault-app:${{ github.sha }}
    build-args: |
      NODE_ENV=production
      BUILD_DATE=${{ github.run_id }}
    cache-from: type=gha              # use GitHub Actions cache for Docker layers
    cache-to: type=gha,mode=max       # save layers to cache after build
    platforms: linux/amd64,linux/arm64  # multi-arch build
```

### docker/metadata-action — Auto-Generate Tags

```yaml
- uses: docker/metadata-action@v5
  id: meta
  with:
    images: ghcr.io/sanketika/vault-app
    tags: |
      type=sha                     # sha-a3f7d2c
      type=ref,event=branch        # main
      type=ref,event=pr            # pr-42
      type=semver,pattern={{version}}  # 1.2.3 (from git tag v1.2.3)
      type=semver,pattern={{major}}.{{minor}}  # 1.2
      type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}

- uses: docker/build-push-action@v5
  with:
    tags: ${{ steps.meta.outputs.tags }}
    labels: ${{ steps.meta.outputs.labels }}
```

---

## Caching — Make Workflows Fast

Without caching, `npm install` runs every workflow run, downloading the same packages repeatedly. Caching fixes this.

### actions/cache — Manual Cache

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.npm                           # npm cache directory
      node_modules                     # installed packages
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    # key: unique string — if it matches a saved cache, restore it
    # hashFiles: generates a hash of package-lock.json content
    # If package-lock.json changes → different hash → cache miss → fresh install

    restore-keys: |
      ${{ runner.os }}-node-          # fallback: use last node cache if key misses
      ${{ runner.os }}-               # broader fallback

- run: npm ci   # uses the cached node_modules if cache hit
```

### Cache Strategies for Different Ecosystems

```yaml
# pip (Python)
- uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}

# Maven (Java)
- uses: actions/cache@v4
  with:
    path: ~/.m2/repository
    key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}

# Gradle (Java)
- uses: actions/cache@v4
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
    key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*') }}

# Go modules
- uses: actions/cache@v4
  with:
    path: ~/go/pkg/mod
    key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}

# Docker layers (via build-push-action cache-from/cache-to)
# No separate cache action needed — handled by docker/build-push-action
```

---

## Artifacts — Share Files Between Jobs or Download After Run

Artifacts persist files from a job. Uses:
- Share a built binary between jobs (build → test → deploy)
- Download test results or logs after a run fails
- Publish coverage reports

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run build           # produces ./dist/

      - uses: actions/upload-artifact@v4
        with:
          name: build-output         # artifact name
          path: ./dist/              # what to upload
          retention-days: 7          # how long to keep (default: 90 days)

  deploy:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build-output         # must match upload name
          path: ./dist/              # where to put it on this runner

      - run: ./deploy.sh ./dist/
```

### Upload Test Reports

```yaml
- name: Run tests
  run: npm test -- --reporter=junit --reporter-option output=./test-results.xml
  continue-on-error: true          # upload even if tests fail

- uses: actions/upload-artifact@v4
  if: always()                     # always upload, even on failure
  with:
    name: test-results
    path: ./test-results.xml
```

---

## Finding and Evaluating Marketplace Actions

### Pinning Action Versions — Critical for Security

```yaml
# WRONG: unpinned — could change or get compromised
- uses: actions/checkout@main
- uses: actions/checkout@latest

# GOOD: pinned to major version (safe for most cases)
- uses: actions/checkout@v4

# BEST: pinned to exact commit SHA (immutable — supply chain attack safe)
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

Why SHA pinning matters: A compromised `actions/checkout@v4` could exfiltrate all your secrets. With a commit SHA, even if the action's tag is moved or deleted, you always run the exact code you reviewed.

For your own internal actions or highly-trusted ones: `@v4` is acceptable. For any action accessing secrets or doing deploys: pin to SHA.

```bash
# How to find a SHA for a specific version:
# 1. Go to the action's releases on GitHub
# 2. Click on the version tag
# 3. Copy the commit SHA from the URL or the commit history
```

---

## Self-Hosted Runners

When GitHub's hosted runners aren't enough:
- Need access to internal network resources (RDS in private VPC)
- Need specific hardware (GPU, large RAM)
- Need to run builds behind a corporate firewall
- Cost control (large teams with many CI minutes)

### Set Up a Self-Hosted Runner

```bash
# On GitHub: Settings → Actions → Runners → New self-hosted runner
# Follow the instructions — essentially:

# 1. Create a directory
mkdir actions-runner && cd actions-runner

# 2. Download the runner package (GitHub gives you exact URL + version)
curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz

# 3. Extract
tar xzf ./actions-runner-linux-x64.tar.gz

# 4. Configure (GitHub gives you the token)
./config.sh --url https://github.com/sanketika/vault-app --token YOUR_TOKEN

# 5. Run (or install as service)
./run.sh                         # foreground
sudo ./svc.sh install            # install as systemd service
sudo ./svc.sh start
```

### Using a Self-Hosted Runner in Workflows

```yaml
jobs:
  build-internal:
    runs-on: self-hosted           # any self-hosted runner

  deploy-prod:
    runs-on: [self-hosted, production, linux]  # runner with ALL these labels
    # Label your runners during setup to select specific ones
```

### Runner Labels for Multiple Environments

```bash
# During config, set labels:
./config.sh \
  --url https://github.com/sanketika/vault-app \
  --token YOUR_TOKEN \
  --labels production,linux,x64,deploy-capable
```

```yaml
# In workflow:
deploy-to-prod:
  runs-on: [self-hosted, production, deploy-capable]
# Only runners with ALL THREE labels pick up this job
```

---

## Real-World Scenario: Speeding Up a Slow Pipeline

Before optimization (6-minute pipeline):
```yaml
jobs:
  all:
    steps:
      - uses: actions/checkout@v4
      - run: npm install              # 90 seconds every run
      - run: npm run build            # 60 seconds
      - run: npm test                 # 120 seconds
      - run: docker build .           # 180 seconds (rebuilds all layers)
```

After optimization (90-second pipeline):
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'               # ← 90s → 5s: cache hit
      - run: npm ci
      - run: npm test

  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v5
        with:
          cache-from: type=gha       # ← 180s → 20s: only rebuild changed layers
          cache-to: type=gha,mode=max
          push: true
          tags: ghcr.io/sanketika/vault-app:${{ github.sha }}
```

---

## Common Misunderstanding: "actions/cache speeds up everything automatically"

**The misunderstanding:** "I added `actions/cache` and my builds are faster now."

**The reality:** Cache only helps on a cache HIT. On the first run (or when `package-lock.json` changes), the cache misses and the full install runs. Then the result is saved for next time.

More importantly: `cache: 'npm'` in `actions/setup-node` is equivalent to using `actions/cache` for `~/.npm`. But `npm ci` STILL downloads packages from the npm cache on disk — it's faster than downloading from internet, but not instant. For true speed, also cache `node_modules` directly:

```yaml
- uses: actions/cache@v4
  id: cache-modules
  with:
    path: node_modules
    key: ${{ runner.os }}-modules-${{ hashFiles('package-lock.json') }}

- name: Install (only if cache miss)
  if: steps.cache-modules.outputs.cache-hit != 'true'
  run: npm ci
```

Now `npm ci` is skipped entirely on a cache hit — the `node_modules` folder is restored directly.

→ Continue to: `03-secrets-and-environments.md`
