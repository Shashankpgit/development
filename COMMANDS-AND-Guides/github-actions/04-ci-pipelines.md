# GitHub Actions — Part 04: Building Real CI Pipelines

**20-minute read. Complete CI pipelines you can copy and adapt. Tests, linting, Docker builds, multi-language, matrix.**

---

## What a Good CI Pipeline Does

```
Every PR:
  1. Code quality gates (lint, format check)
  2. Tests (unit → integration)
  3. Security scan (dependencies, container image)
  4. Build verification (does it compile/build successfully?)

On merge to main:
  5. Build Docker image
  6. Push to registry
  7. Update deployment manifest / trigger CD
```

---

## Complete Node.js CI Pipeline

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true     # cancel previous run on same branch if new push comes in

jobs:

  lint:
    name: Lint & Format Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: ESLint
        run: npm run lint

      - name: Prettier format check
        run: npm run format:check

  test-unit:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Run unit tests
        run: npm run test:unit -- --coverage

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: unit-coverage
          path: ./coverage/

  test-integration:
    name: Integration Tests
    runs-on: ubuntu-latest
    services:                         # spin up Docker containers alongside the job
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: testuser
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: vault_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Run integration tests
        env:
          DATABASE_URL: postgresql://testuser:testpass@localhost:5432/vault_test
          REDIS_URL: redis://localhost:6379
        run: npm run test:integration

  build-docker:
    name: Build Docker Image
    runs-on: ubuntu-latest
    needs: [lint, test-unit, test-integration]    # all three must pass
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        if: github.event_name != 'pull_request'   # don't push on PRs
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/metadata-action@v5
        id: meta
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha
            type=ref,event=branch
            type=semver,pattern={{version}}

      - uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## Services — Database in CI

The `services:` block starts Docker containers that run alongside your job:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_PASSWORD: password
          POSTGRES_DB: testdb
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432        # map container port to runner port

    steps:
      - uses: actions/checkout@v4
      - run: |
          # wait is not needed — health check ensures postgres is ready
          psql postgresql://postgres:password@localhost:5432/testdb -c "SELECT 1"
```

The `options: --health-*` flags make GitHub wait for the service to be healthy before starting your steps. Without this, your tests might start before the database is ready.

---

## Matrix Builds — Test Multiple Versions

```yaml
jobs:
  test:
    name: Test Node ${{ matrix.node }} on ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
        node: [18, 20, 22]

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm ci && npm test
```

This creates 6 parallel jobs:
- ubuntu + node18
- ubuntu + node20
- ubuntu + node22
- macos + node18
- macos + node20
- macos + node22

### Dynamic Matrix from Script

```yaml
jobs:
  generate-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
      - id: set-matrix
        run: |
          # Generate matrix from directory listing (e.g., for monorepo services)
          SERVICES=$(ls services/ | jq -R -s -c 'split("\n")[:-1]')
          echo "matrix={\"service\":$SERVICES}" >> $GITHUB_OUTPUT

  build:
    needs: generate-matrix
    strategy:
      matrix: ${{ fromJSON(needs.generate-matrix.outputs.matrix) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build ./services/${{ matrix.service }}
```

---

## Python CI Pipeline

```yaml
name: Python CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ['3.10', '3.11', '3.12']

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
          cache: 'pip'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install -r requirements-dev.txt

      - name: Lint with flake8
        run: flake8 src/ tests/

      - name: Type check with mypy
        run: mypy src/

      - name: Run pytest
        run: pytest tests/ -v --tb=short --junitxml=test-results.xml

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-${{ matrix.python-version }}
          path: test-results.xml
```

---

## Go CI Pipeline

```yaml
name: Go CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
          cache: true

      - name: Vet
        run: go vet ./...

      - name: Test
        run: go test -v -race -coverprofile=coverage.out ./...

      - name: Build
        run: go build -v ./...

      - name: golangci-lint
        uses: golangci/golangci-lint-action@v4
        with:
          version: latest
```

---

## Security Scanning in CI

### Dependency Vulnerability Scan

```yaml
- name: Audit npm dependencies
  run: npm audit --audit-level=high
  # fails if there are high or critical vulnerabilities
  # use --audit-level=moderate for stricter checks

# Python:
- run: pip install safety && safety check

# Go:
- uses: golang/govulncheck-action@v1
```

### Container Image Scanning with Trivy

```yaml
- name: Scan Docker image for vulnerabilities
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
    format: 'table'
    exit-code: '1'             # fail the build on HIGH/CRITICAL findings
    severity: 'HIGH,CRITICAL'
    ignore-unfixed: true       # ignore vulns without a fix available
```

### Secret Scanning with Gitleaks

```yaml
- uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  # Scans git history for accidentally committed secrets
```

---

## PR Comments with Test Results

```yaml
- name: Run tests with coverage
  id: tests
  run: |
    npm test -- --coverage --coverageReporters=text-summary 2>&1 | tee test-output.txt
    echo "exit_code=${PIPESTATUS[0]}" >> $GITHUB_OUTPUT

- name: Comment coverage on PR
  uses: actions/github-script@v7
  if: github.event_name == 'pull_request'
  with:
    script: |
      const fs = require('fs');
      const output = fs.readFileSync('test-output.txt', 'utf8');
      const lines = output.split('\n').slice(-15).join('\n');  // last 15 lines (summary)
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `## Test Results\n\`\`\`\n${lines}\n\`\`\``
      });
```

---

## Status Checks and Branch Protection

After creating CI workflows, configure branch protection rules:

```
Repository → Settings → Branches → main → Add protection rule

Required status checks:
  ✓ lint
  ✓ test-unit
  ✓ test-integration
  ✓ build-docker

Options:
  ✓ Require branches to be up to date before merging
  ✓ Require pull request reviews before merging
```

Now no code can merge to `main` without all CI checks passing. GitHub blocks the merge button.

---

## Real-World Scenario: CI That Only Runs Relevant Tests

Large monorepo — don't run backend tests when only frontend changed:

```yaml
jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      backend: ${{ steps.changes.outputs.backend }}
      frontend: ${{ steps.changes.outputs.frontend }}
      infra: ${{ steps.changes.outputs.infra }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2            # need previous commit to diff against

      - uses: dorny/paths-filter@v3
        id: changes
        with:
          filters: |
            backend:
              - 'backend/**'
              - 'package.json'
            frontend:
              - 'frontend/**'
            infra:
              - 'terraform/**'
              - 'k8s/**'

  test-backend:
    needs: detect-changes
    if: needs.detect-changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd backend && npm test

  test-frontend:
    needs: detect-changes
    if: needs.detect-changes.outputs.frontend == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd frontend && npm test

  validate-infra:
    needs: detect-changes
    if: needs.detect-changes.outputs.infra == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd terraform && terraform validate
```

If only frontend code changes, backend and infra jobs are skipped — much faster pipelines.

---

## Common Misunderstanding: "npm install vs npm ci in CI"

**The misunderstanding:** "I use `npm install` in CI like I do locally."

**The reality:** Always use `npm ci` in CI pipelines. The difference:

| | `npm install` | `npm ci` |
|--|--------------|---------|
| Uses `package-lock.json` | Updates it if needed | Strictly follows it (fails if mismatch) |
| Speed in CI | Slower (resolves versions) | Faster (skips resolution) |
| Reproducibility | Can vary | Guaranteed identical installs |
| Node_modules | Updates existing | Deletes and reinstalls from scratch |

`npm install` can silently update transitive dependencies. Two CI runs from the same commit might install different packages. `npm ci` guarantees the exact same packages every time — deterministic builds.

Same principle applies to other ecosystems:
- Python: `pip install -r requirements.txt` → always pin versions in requirements.txt
- Go: `go mod download` → go.sum locks all versions
- Maven: use `mvn dependency:resolve` with version pinning

→ Continue to: `05-cd-deployments.md`
