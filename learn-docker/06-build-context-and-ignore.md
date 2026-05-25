# 06 — Build Context & .dockerignore

Before Docker builds a single layer, it does something most beginners don't realize: it sends an entire directory to the Docker daemon. Understanding this transfer — the **build context** — explains why builds can be slow even on the first instruction, and how to fix it.

---

## What Is the Build Context?

When you run:

```bash
docker build -t myapp:1.0 .
```

The `.` at the end is not just "the current directory". It is the **build context** — the entire directory that Docker compresses and uploads to the Docker daemon.

The daemon receives this context as a tar archive. Only then does it start executing your Dockerfile instructions. `COPY` can only copy files that exist inside this context.

```
You run: docker build -t myapp:1.0 .

Step 1: Docker CLI compresses everything in "." into a tar
Step 2: Sends the tar to the Docker daemon (could be remote!)
Step 3: Daemon unpacks it
Step 4: Daemon executes Dockerfile instructions
         COPY reads files FROM the unpacked context
```

**The key point:** The entire context is sent on every build, even if nothing changed. If your context is 500MB because you have a `.venv/` folder, every single build uploads 500MB before doing any work.

---

## Why Context Size Matters

```bash
$ docker build -t myapp .
Sending build context to Docker daemon  1.73GB
```

That message — "Sending build context" — is Docker telling you how big the context is. 1.73GB for a build context is a disaster. It means:
- Every `docker build` waits minutes before the first instruction runs
- On CI/CD, you pay for the network transfer time every pipeline run
- On remote Docker daemon (Docker contexts), this is even worse

Common culprits:

| Directory / File | Why it's huge | Should it be in context? |
|---|---|---|
| `node_modules/` | Thousands of packages, hundreds of MB | No — reinstalled in container |
| `.venv/` | Python virtualenv, hundreds of MB | No — reinstalled in container |
| `.git/` | Full git history | No — never needed in image |
| `dist/` or `build/` | Build artifacts | Usually no — built inside container |
| `.DS_Store`, `Thumbs.db` | OS junk files | No |
| `*.log` | Log files | No |
| `*.env` | Secrets | No — never in image |
| Docker images themselves | `.tar`, `.img` files | No |
| Test fixtures with large files | Test data | Usually no |

---

## .dockerignore

`.dockerignore` is a file you create in the root of your build context. Docker reads it before sending the context and **excludes** any matching files.

Create it at the same level as your Dockerfile:

```
myproject/
├── Dockerfile
├── .dockerignore      ← here
├── requirements.txt
├── app/
├── .env
└── .venv/
```

---

## .dockerignore Syntax

The syntax is identical to `.gitignore`. Quick reference:

```
# This is a comment

# Match a specific file
.env

# Match a directory (and everything inside it)
.venv/
node_modules/
.git/

# Match by extension
*.log
*.pyc
*.pyo

# Match anywhere in the tree (** = any path depth)
**/__pycache__/
**/*.pyc

# Match in a specific subdirectory
tests/fixtures/large-files/

# Negation — include this even if a broader rule would exclude it
!important.log
```

---

## A Solid .dockerignore Template for Python

```
# Version control
.git/
.gitignore

# Python artifacts
__pycache__/
*.py[cod]
*$py.class
*.pyc
*.pyo
*.pyd
.Python

# Virtual environments — CRITICAL
.venv/
venv/
env/
.env/

# Secrets — NEVER in image
.env
.env.*
*.key
*.pem
secrets/

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db
desktop.ini

# Build artifacts
dist/
build/
*.egg-info/

# Docker files themselves (not needed in context)
docker-compose*.yml
Dockerfile*
.dockerignore

# Documentation (usually not needed in the image)
docs/
*.md
```

---

## A Solid .dockerignore for Node.js / JavaScript

```
.git/
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm
.yarn

.env
.env.*

dist/
build/
.next/
.nuxt/

coverage/
.nyc_output/
.jest-cache/

.DS_Store
Thumbs.db

.vscode/
.idea/

docker-compose*.yml
Dockerfile*
.dockerignore

*.md
docs/
```

---

## The COPY Restriction

Files excluded from the context are not available to `COPY`. If you `.dockerignore` a file and then try to COPY it, the build fails with:

```
COPY failed: file not found in build context or excluded by .dockerignore: stat .env: file not found
```

This is a feature, not a bug. It prevents you from accidentally copying secrets into images.

If you're getting this error, check:
1. Is the file in the right directory (relative to build context root)?
2. Is the file excluded by `.dockerignore`?

---

## Specifying a Different Build Context

The `.` in `docker build -t myapp .` doesn't have to be the current directory:

```bash
# Use a different directory as context
docker build -t myapp ./myapp-directory

# Use git repo as context (Docker fetches it)
docker build -t myapp https://github.com/user/repo.git

# Use a specific Dockerfile with a different context
docker build -t myapp -f ../shared/Dockerfile ./myapp-directory
```

**`-f` flag:** Specify a Dockerfile that is not named `Dockerfile` or not in the build context root:

```bash
docker build -t myapp:prod -f Dockerfile.production .
```

---

## Checking Your Context Size

There is no built-in command to check context size before building. The easiest way:

```bash
# Build and look at the "Sending build context" line
docker build -t myapp . 2>&1 | head -1
# → Sending build context to Docker daemon  42.7MB
```

If it's large, add more entries to `.dockerignore` until it's small.

Another approach — simulate what `.dockerignore` would exclude:

```bash
# List files that would be sent (not excluded)
git ls-files --others --cached --exclude-standard | head -50
```

---

## Layer Inspection: docker image history

After building, you can see how large each layer is:

```bash
docker image history myapp:1.0
```

Output:
```
IMAGE         CREATED        CREATED BY                                      SIZE
3f4a2b1e9c   2 minutes ago  CMD ["uvicorn", "app.main:app" ...              0B
d1e2f3a4b5   2 minutes ago  COPY . .                                        2.1MB
8a7b6c5d4e   5 minutes ago  RUN pip install --no-cache-dir ...              94MB
2c3d4e5f6a   5 minutes ago  COPY requirements.txt .                        1.2kB
...
```

This tells you which layers are large and whether optimization is needed.

---

## Gotchas

### 1. .dockerignore must be in the build context root
It must be at the same level as the Dockerfile you're pointing to (or at the context root). A `.dockerignore` in a subdirectory does nothing.

### 2. Secrets in .dockerignore are still reachable if COPY runs before the ignore
If you run `COPY . .` and your `.dockerignore` doesn't exclude `.env`, the secret is baked into the layer. Even if you later `RUN rm .env`, the secret still exists in the earlier layer and is readable via `docker image history`. The only fix is to rebuild without ever having copied the secret. Prevention is the only cure.

### 3. Context vs Dockerfile location
The Dockerfile does not have to be inside the build context. `docker build -f /some/other/Dockerfile /my/context` is valid. The Dockerfile is sent separately, not as part of the context.

### 4. Large contexts slow down CI even when cached
Unlike layer caching (which is node-local), context upload happens on every build regardless of what changed. A 2GB context wastes time even if nothing in the image changed. Always keep context lean.

### 5. .dockerignore affects all COPY instructions
If you exclude a file in `.dockerignore`, you can't COPY it anywhere in the Dockerfile. Plan your ignore rules so you're not excluding files you actually need.

---

## Summary

- The build context is the directory sent to the Docker daemon before building starts.
- Every build sends the full context — keep it lean with `.dockerignore`.
- `.dockerignore` syntax is the same as `.gitignore`.
- Always exclude: `.venv/`, `node_modules/`, `.git/`, `.env`, `__pycache__/`
- Secrets excluded from context cannot accidentally be baked into layers.
- Use `docker build -f` to specify a different Dockerfile name.

**Next:** [07 — Layer Cache Optimization](07-layer-cache-optimization.md)

---

## Reference Links

- [.dockerignore reference](https://docs.docker.com/reference/dockerfile/#dockerignore-file)
- [Build context documentation](https://docs.docker.com/build/building/context/)
