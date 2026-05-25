# 14 — Debugging & Troubleshooting

Containers hide their internals by design. A process runs in isolation, you can't just open a file manager or click around. This file gives you a systematic toolkit to investigate anything that goes wrong.

---

## The Debugging Toolkit

| Tool | What it's for |
|---|---|
| `docker logs` | See what the process printed to stdout/stderr |
| `docker exec -it` | Get a shell inside a running container |
| `docker inspect` | Full metadata about any container or image |
| `docker stats` | Live CPU/memory/network/disk usage |
| `docker cp` | Copy files between host and container |
| `docker events` | Stream of Docker daemon events |
| `docker run --rm -it image sh` | Interactive shell in a fresh container |

---

## docker logs

The first thing to check when something is broken.

```bash
docker logs mycontainer
docker logs mycontainer -f          # -f (follow): stream in real time
docker logs mycontainer --tail 100  # last 100 lines only
docker logs mycontainer --since 5m  # last 5 minutes
docker logs mycontainer --since 2024-01-15T10:00:00  # since timestamp
```

**What logs contains:** Everything the main process wrote to stdout and stderr.

**Why your logs might not appear:** Python buffers stdout by default. Set `PYTHONUNBUFFERED=1` in your Dockerfile ENV to force immediate flushing. Node.js writes to stdout immediately. Go writes immediately.

**With docker compose:**
```bash
docker compose logs             # all services
docker compose logs api         # just the api service
docker compose logs -f          # follow all services
docker compose logs -f api db   # follow specific services
```

---

## docker exec — Getting Inside a Running Container

```bash
docker exec -it mycontainer bash   # bash if available
docker exec -it mycontainer sh     # sh (works on alpine/minimal images)
```

`-it` = interactive + pseudo-tty = you get a real shell prompt.

**Inside the container you can:**
```bash
# Check what files are in the working directory
ls /app

# Check what processes are running
ps aux

# Check what's listening on ports
netstat -tlnp
# or (on minimal images without netstat):
ss -tlnp
cat /proc/net/tcp   # raw fallback

# Check environment variables
env
env | grep DATABASE

# Check DNS resolution
nslookup db
nslookup google.com

# Test HTTP connectivity
curl http://db:5432   # even if db isn't HTTP, you'll get an error that tells you if it's reachable
wget -qO- http://api:8000/health

# Check file content
cat /app/.env    # if your .env is in the container (it shouldn't be — but for debugging)
```

**Running one-off commands without entering a shell:**
```bash
docker exec mycontainer cat /app/config.json
docker exec mycontainer python3 -c "import psycopg2; print('ok')"
docker exec mycontainer env | sort
```

**Running as a different user:**
```bash
docker exec -u root mycontainer bash   # force root even if container runs as non-root
```

---

## docker inspect

Returns every piece of metadata Docker knows about a container or image as JSON.

```bash
docker inspect mycontainer
docker inspect postgres:16     # inspect an image
```

Useful fields to extract with `--format`:

```bash
# Container's IP address
docker inspect mycontainer --format '{{.NetworkSettings.IPAddress}}'

# Which networks it's on and their IPs
docker inspect mycontainer --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool

# All environment variables
docker inspect mycontainer --format '{{.Config.Env}}'

# Mount points
docker inspect mycontainer --format '{{json .Mounts}}' | python3 -m json.tool

# Container state (running, exit code)
docker inspect mycontainer --format '{{.State.Status}} exit={{.State.ExitCode}}'

# Health status
docker inspect mycontainer --format '{{.State.Health.Status}}'
```

---

## docker stats

Live resource usage — updated every second.

```bash
docker stats                   # all running containers
docker stats mycontainer       # one container
docker stats --no-stream       # single snapshot (for scripts)
```

Output columns:
- `CPU %` — percentage of host CPU used
- `MEM USAGE / LIMIT` — memory used vs limit
- `MEM %` — memory percentage
- `NET I/O` — total network bytes in/out
- `BLOCK I/O` — total disk bytes in/out
- `PIDS` — number of processes/threads

**Common issue:** Container using 100% CPU → runaway process. Container at memory limit → likely OOMKilled (see exit code 137).

---

## docker cp — Copy Files Between Host and Container

```bash
# Container → host
docker cp mycontainer:/app/logs/error.log ./error.log
docker cp mycontainer:/etc/nginx/nginx.conf ./nginx.conf

# Host → container (useful for injecting config without rebuilding)
docker cp ./updated-config.json mycontainer:/app/config.json
```

Works on both running and stopped containers. Useful for extracting logs, examining output files, or injecting quick fixes for debugging.

---

## Interactive Debugging with a Fresh Container

Sometimes your app container fails to start and you can't `exec` into it (no container to exec into). Start a fresh container from the same image with an interactive shell:

```bash
# Override the CMD with bash
docker run --rm -it myapp:1.0 bash

# Explore the filesystem
ls /app
cat /app/requirements.txt
python3 -c "import app.main"   # try importing your module manually

# Run the app manually to see the actual error
uvicorn app.main:app
```

**Overriding entrypoint when ENTRYPOINT is set:**
```bash
docker run --rm -it --entrypoint bash myapp:1.0
# or with sh:
docker run --rm -it --entrypoint sh myapp:1.0
```

---

## Container Exit Codes — What They Mean

When a container exits unexpectedly, the exit code tells you why.

```bash
docker ps -a       # see exit codes in the STATUS column
# STATUS: Exited (1) 2 minutes ago
#                ↑
#                exit code
```

| Exit Code | Meaning |
|---|---|
| `0` | Exited cleanly (the process completed normally) |
| `1` | General error — check logs |
| `2` | Shell misuse (incorrect command usage) |
| `125` | Docker command itself failed |
| `126` | Command found but not executable (permission issue) |
| `127` | Command not found (wrong path, typo, not installed) |
| `130` | Terminated by Ctrl+C (SIGINT) |
| `137` | Killed with SIGKILL — usually OOMKilled (out of memory) |
| `143` | Terminated by SIGTERM (graceful shutdown) |

Exit code 137 specifically:
```bash
docker inspect mycontainer --format '{{.State.OOMKilled}}'
# → true  (container was killed because it exceeded its memory limit)
```

If a container exits with 127:
```bash
# The command in CMD/ENTRYPOINT wasn't found
# Check: is the binary installed? Is the PATH correct?
docker run --rm -it myimage sh
which uvicorn    # is it in PATH?
ls /app/.venv/bin/uvicorn   # where did pip install it?
```

---

## docker events

Stream real-time events from the Docker daemon:

```bash
docker events                          # all events
docker events --filter type=container # only container events
docker events --filter event=die      # only when containers die
docker events --since 5m              # events from last 5 minutes
```

Sample output:
```
2024-01-15T10:23:01 container start abc123 (image=myapp:1.0, name=vault_api_1)
2024-01-15T10:23:05 container die abc123 (exitCode=1, image=myapp:1.0)
```

Useful for watching what happens at startup — do containers start, crash, restart?

---

## Debugging Common Errors

### "port already in use"

```
Error: bind: address already in use
Error starting userland proxy: listen tcp4 0.0.0.0:8000: bind: address already in use
```

Something on your host is already using port 8000:

```bash
# Find what's using it (Linux/Mac)
lsof -i :8000
# or:
ss -tlnp | grep 8000

# Kill it (Linux)
fuser -k 8000/tcp

# Or change the host port in your compose file:
ports:
  - "8001:8000"   # map to 8001 instead
```

---

### "no such container"

```
Error: No such container: mycontainer
```

```bash
docker ps -a | grep mycontainer   # is it stopped? What's the exact name?
docker ps -a                       # see all containers
```

The container may have been removed, or the name is slightly different (compose prefixes with project name).

---

### Container exits immediately

```bash
docker ps -a   # see exit code in STATUS
docker logs mycontainer   # see what it printed before dying
```

**Common causes:**
- `CMD` command not found (exit 127)
- Application crashed on startup (exit 1)
- Missing environment variable causing exception
- Wrong working directory — file not found

Debug:
```bash
docker run --rm -it --entrypoint sh myapp:1.0
# inside: manually run the CMD command and read the error
uvicorn app.main:app
# → exact Python error message
```

---

### "connection refused" to another container

```
psycopg2.OperationalError: could not connect to server: Connection refused
    Is the server running on host "localhost" (127.0.0.1) and accepting
    TCP/IP connections on port 5432?
```

**Root cause:** Using `localhost` when connecting to another container. The app is in its own network namespace; `localhost:5432` is the app container's loopback — not the db container.

**Fix:** Use the service name: `DATABASE_URL=postgresql://user:pass@db:5432/mydb`

Verify:
```bash
docker exec -it api_container sh
nslookup db        # does "db" resolve?
```

---

### "permission denied" on volume mounts

```
PermissionError: [Errno 13] Permission denied: '/app/logs/app.log'
```

Files in the container are owned by root (from the Dockerfile), but the app runs as a non-root user.

Fix in Dockerfile:
```dockerfile
RUN adduser --disabled-password --no-create-home appuser \
    && chown -R appuser:appuser /app

USER appuser
```

Or for mounted directories, ensure the mounted path is writable:
```dockerfile
RUN mkdir -p /app/logs && chown -R appuser:appuser /app/logs
```

---

### Image not found on push

```
denied: requested access to the resource is denied
```

```bash
# Not logged in?
docker login

# Wrong tag format? Should be:
docker tag myapp:1.0 yourusername/myapp:1.0
docker push yourusername/myapp:1.0
# Not:
docker push myapp:1.0   # ← not tagged with your username
```

---

### "no space left on device"

Docker's images, containers, and volumes accumulate:

```bash
# Check Docker's disk usage
docker system df

# Clean up
docker system prune -a        # remove all unused images
docker volume prune           # remove unused volumes
docker container prune        # remove stopped containers
```

---

## Debugging in docker compose

```bash
# Start one service and see its logs immediately (attached mode)
docker compose up api

# Start all services, stream logs
docker compose up

# Restart one service after a code change
docker compose restart api

# Rebuild and restart one service
docker compose up --build api

# Open a shell in a service container
docker compose exec api bash

# Run a one-off command in a service (starts new container)
docker compose run --rm api python manage.py migrate
```

---

## Summary

- `docker logs -f` → first stop for any broken container
- `docker exec -it container sh` → get a shell in a running container
- `docker run --rm -it image sh` → debug a container that won't start
- `docker inspect container` → full metadata, IPs, mounts, env vars
- Exit code 137 = OOMKilled (out of memory); exit code 127 = command not found
- "connection refused" to another container → you're using `localhost`, use the service name
- `docker system prune -a` when you're out of disk space

**Next:** [15 — Security Best Practices](15-security-best-practices.md)

---

## Reference Links

- [docker inspect reference](https://docs.docker.com/reference/cli/docker/inspect/)
- [docker logs reference](https://docs.docker.com/reference/cli/docker/container/logs/)
- [Container exit codes](https://docs.docker.com/engine/reference/run/#exit-status)
