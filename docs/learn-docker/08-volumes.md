# 08 — Volumes & Data Persistence

Containers are ephemeral by design. Delete a container and everything inside it — including all the data your app wrote to disk — is gone. This is intentional: it makes containers clean and reproducible.

But real applications need to persist data: database files, uploaded files, application logs. Volumes solve this.

---

## Why Containers Are Ephemeral

Every container gets a **writable layer** on top of the read-only image layers. All writes go into this writable layer. When you delete the container with `docker rm`, the writable layer is deleted too.

```
Container A running:
┌────────────────────────────────────┐
│  Writable layer (deleted on rm)   │  ← WHERE DATA GOES BY DEFAULT
├────────────────────────────────────┤
│  Image layers (read-only, shared) │
└────────────────────────────────────┘
```

For stateless apps (web servers serving static requests), this is fine. For databases, this is catastrophic.

---

## The Three Storage Types

Docker has three mechanisms for persisting or sharing data:

| | Named Volumes | Bind Mounts | tmpfs Mounts |
|---|---|---|---|
| **Managed by** | Docker | You (host filesystem) | Memory (never on disk) |
| **Where data lives** | Docker's data directory | Anywhere on the host | RAM only |
| **Survives container removal** | ✅ Yes | ✅ Yes (it's on your host) | ❌ No |
| **Works on all platforms** | ✅ Yes | ⚠️ Path differences (Mac/Windows) | ✅ Yes |
| **Best for** | DB data, anything Docker should manage | Local dev (live code), config files | Secrets, temp files |
| **Portable (works in CI)** | ✅ | ❌ (depends on host paths) | ✅ |

---

## Named Volumes

### What they are

Named volumes are storage areas managed entirely by Docker. Docker decides where to store the data on the host (usually `/var/lib/docker/volumes/` on Linux). You don't care about the path — you just use the name.

### Creating and using named volumes

```bash
# Create explicitly
docker volume create mydata

# Use in docker run
docker run -v mydata:/app/data myimage

# Docker creates the volume automatically if it doesn't exist
docker run -v postgres_data:/var/lib/postgresql/data postgres:16
```

Syntax: `-v volume_name:container_path`

### Named volumes in docker-compose

```yaml
services:
  db:
    image: postgres:16
    volumes:
      - postgres_data:/var/lib/postgresql/data   # named volume mount

volumes:
  postgres_data:    # declare the volume at the top level
```

The top-level `volumes:` block declares volumes that compose should manage. When you run `docker compose up`, Docker creates this volume if it doesn't exist.

### Volume commands

```bash
# List all volumes
docker volume ls

# Inspect a volume (see where data actually lives)
docker volume inspect postgres_data

# Remove a volume (only works if no container is using it)
docker volume rm postgres_data

# Remove all unused volumes
docker volume prune

# Remove with confirmation skipped
docker volume prune -f
```

`docker volume inspect` output shows `Mountpoint` — the actual path on the host where data is stored:

```json
{
    "Name": "postgres_data",
    "Driver": "local",
    "Mountpoint": "/var/lib/docker/volumes/postgres_data/_data",
    ...
}
```

### Why PostgreSQL needs a volume

PostgreSQL stores all database files in `/var/lib/postgresql/data`. If you run postgres without a volume:

```bash
docker run postgres:16   # ❌ — all data in writable layer, lost when container is removed
```

```bash
docker run -v postgres_data:/var/lib/postgresql/data postgres:16   # ✅ — data persists
```

When you run `docker compose down`, containers are removed but volumes are not. Your data is safe. To also delete the volume (wipe the database), you must explicitly run `docker compose down -v`.

---

## Bind Mounts

### What they are

Bind mounts map a specific directory on your **host machine** directly into the container. Changes made inside the container are immediately reflected on the host, and vice versa.

```bash
docker run -v /host/absolute/path:/container/path myimage
# or with $(pwd) for current directory:
docker run -v $(pwd)/src:/app/src myimage
```

### Why bind mounts are great for development

With a bind mount, you don't have to rebuild the image to see code changes:

```yaml
# docker-compose.override.yml — only used in development
services:
  api:
    volumes:
      - ./backend:/app   # mount source code from host into container
```

Now when you save a file in your editor, the container immediately sees the change. If your app does hot-reloading (uvicorn --reload, nodemon, etc.), it picks up the change immediately.

**Without bind mount:** edit code → rebuild image → restart container → test
**With bind mount:** edit code → test (container sees it immediately)

### Bind mounts vs named volumes for development

```yaml
# Development: use bind mount for code
volumes:
  - ./backend:/app          # host code → container (for live reload)
  - postgres_data:/var/lib/postgresql/data  # named volume for db data

# Production: don't bind mount code — it should be in the image
# (no code bind mount in production docker-compose.yml)
```

### Gotchas with bind mounts

**File ownership (Linux):**
Files created inside the container are owned by the container's user (often root). On the host, those files are owned by root, and your user can't edit or delete them.

```bash
# Fix: run the container with your user ID
docker run -u $(id -u):$(id -g) -v $(pwd):/app myimage
```

Or in compose:
```yaml
services:
  api:
    user: "${UID}:${GID}"   # set in your .env file: UID=1000, GID=1000
```

**Performance on Mac and Windows:**
Bind mounts involving heavy I/O (like a `node_modules` directory with thousands of small files) are slow on Mac/Windows because every file access crosses the VM boundary. Solutions:
- Don't bind-mount `node_modules` — use a named volume for that:
  ```yaml
  volumes:
    - ./app:/app              # source code (bind mount)
    - /app/node_modules       # anonymous volume — container manages node_modules
  ```
  The `/app/node_modules` with no `volume_name:` creates an anonymous volume that "hides" the host's node_modules from being used.

**Absolute paths only:**
Bind mounts require absolute paths on the host. `$(pwd)` is the common workaround.

---

## tmpfs Mounts

Stores data in RAM only — never touches disk. Useful for:
- Secrets (passwords, tokens) that should never be written to disk
- Highly sensitive temporary data
- High-speed ephemeral scratch space

```bash
docker run --tmpfs /app/tmp myimage

# With options (size limit, permissions)
docker run --tmpfs /app/tmp:rw,size=100m,mode=755 myimage
```

In docker-compose:
```yaml
services:
  api:
    tmpfs:
      - /app/tmp
      - /tmp
```

Data in tmpfs is lost when the container stops. It also doesn't survive container restarts.

---

## Anonymous Volumes

When you specify a volume path in a Dockerfile's `VOLUME` instruction, or use `-v /container/path` without a name, Docker creates an **anonymous volume** — a named volume with a random UUID name.

```bash
docker run -v /app/data myimage     # anonymous volume
# Docker creates a volume like "a1b2c3d4e5f6..."
```

Anonymous volumes are rarely useful in practice — you can't find or reuse them by name. Prefer named volumes or bind mounts.

---

## Backup and Restore

### Backup a named volume

```bash
# Spin up a temporary container, mount both the volume and a host dir,
# tar the volume contents to the host dir
docker run --rm \
  -v postgres_data:/source:ro \
  -v $(pwd)/backups:/backup \
  alpine \
  tar czf /backup/postgres_backup.tar.gz -C /source .
```

### Restore a named volume

```bash
# Create the volume if it doesn't exist
docker volume create postgres_data

# Restore
docker run --rm \
  -v postgres_data:/target \
  -v $(pwd)/backups:/backup \
  alpine \
  tar xzf /backup/postgres_backup.tar.gz -C /target
```

---

## docker compose down vs down -v

This is the most dangerous gotcha with volumes:

```bash
docker compose down       # stops and removes containers and network — volumes SURVIVE
docker compose down -v    # same + DELETES ALL VOLUMES — all database data is GONE
```

Never run `down -v` unless you intentionally want to wipe the database. The `-v` flag is the nuclear option.

---

## Choosing the Right Storage

Use this decision tree:

```
Do you need the data to persist after the container is removed?
├── No  → Just use the container's writable layer (no action needed)
└── Yes → Choose based on use case:
          ├── Is it database data or any data Docker should manage?
          │   └── Named volume
          ├── Is it source code for live development?
          │   └── Bind mount
          ├── Is it config files that live on the host?
          │   └── Bind mount
          └── Is it temporary secret data that must never touch disk?
              └── tmpfs
```

---

## Production Checklist for Volumes

- [ ] All databases use named volumes (never the container's writable layer)
- [ ] Named volumes are declared in `docker-compose.yml`'s `volumes:` section
- [ ] Backup strategy exists for named volumes (automated, tested)
- [ ] Development bind mounts are in `docker-compose.override.yml`, not in production compose
- [ ] `docker compose down -v` is not in any automated script

---

## Summary

- Containers are ephemeral — writable layer is deleted when container is removed
- **Named volumes:** Docker-managed persistent storage. Best for databases and app data.
- **Bind mounts:** map host directory into container. Best for development (live code reload).
- **tmpfs:** memory-only, never on disk. Best for secrets and temp files.
- Always use named volumes for database containers
- `docker compose down` preserves volumes; `docker compose down -v` deletes them

**Next:** [09 — Networking](09-networking.md)

---

## Reference Links

- [Docker volumes documentation](https://docs.docker.com/storage/volumes/)
- [Bind mounts documentation](https://docs.docker.com/storage/bind-mounts/)
- [tmpfs mounts](https://docs.docker.com/storage/tmpfs/)
- [Volume driver plugins](https://docs.docker.com/engine/extend/plugins_volume/) — cloud storage integration
