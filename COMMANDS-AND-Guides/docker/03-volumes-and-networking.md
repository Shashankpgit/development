# Docker — Part 03: Volumes, Storage, and Networking

---

## Storage: The Problem With Container Filesystems

When a container is deleted, everything written to its filesystem is gone. This is intentional — containers are ephemeral. But your database data, uploaded files, and logs need to survive.

**Three storage options:**

```
┌──────────────────────────────────────────────────────────────┐
│                      Docker Host                              │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Container                                           │    │
│  │                                                     │    │
│  │  /app/data ──── Volume mount ──────────────────────────► Docker volume │
│  │                 (managed by Docker)                 │    │ /var/lib/docker/volumes/
│  │  /app/config ── Bind mount ──────────────────────────────► /home/shashank/config/ │
│  │                 (specific host path)                │    │ (any host path)
│  │  /tmp/cache ─── tmpfs mount ────────────────────────────► RAM only │
│  │                 (memory, not disk)                  │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

---

## Volumes — Docker-Managed Storage (Recommended)

Volumes are stored in Docker's own directory (`/var/lib/docker/volumes/`) and managed entirely by Docker. They are the preferred way to persist data.

### Create and use volumes:

```bash
# Create a named volume
docker volume create postgres_data

# List volumes
docker volume ls

# Inspect a volume (see where it's stored on disk)
docker volume inspect postgres_data

# Use a volume in docker run
docker run -d \
  --name my-postgres \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:15

# Delete a volume (only when no container uses it)
docker volume rm postgres_data

# Delete all unused volumes
docker volume prune
```

### Why volumes over bind mounts for databases:

- Docker manages the path — you don't need to know `/var/lib/docker/volumes/...`
- Volumes work on any OS (Mac, Windows, Linux) without path differences
- Docker can optimize I/O for volumes
- Easier to backup: `docker run --rm -v postgres_data:/source -v $(pwd):/backup alpine tar -czf /backup/backup.tar.gz /source`

---

## Bind Mounts — Mount a Specific Host Path

Bind mounts map a specific directory on the host to a path inside the container. Changes on either side are immediately visible on both sides.

```bash
# Mount current directory into container (for development)
docker run -d \
  -v $(pwd):/app \
  -p 3000:3000 \
  node:18-alpine \
  node /app/src/index.js

# Mount a specific config file
docker run -d \
  -v /etc/nginx/custom.conf:/etc/nginx/conf.d/custom.conf:ro \
  nginx
# :ro = read-only (container cannot modify this file)
```

**Best use for bind mounts:** Development — mount your source code so changes are immediately reflected without rebuilding the image.

---

## Docker Networking

### The three default network types:

```bash
docker network ls
# NETWORK ID     NAME      DRIVER    SCOPE
# abc123         bridge    bridge    local     ← default for containers
# def456         host      host      local     ← shares host network
# ghi789         none      null      local     ← no network
```

### Bridge Network (Default)

When you run `docker run nginx`, the container gets connected to the default `bridge` network. It gets an IP like `172.17.0.2`. Containers on the same bridge can communicate by IP, but NOT by name.

**Problem with the default bridge:** Containers can't find each other by name.

**Solution: Create a custom bridge network:**

```bash
# Create a custom network
docker network create myapp-network

# Run containers on the custom network
docker run -d --name postgres --network myapp-network postgres:15
docker run -d --name api --network myapp-network myapi:v1.0

# NOW: the api container can reach postgres by NAME
# Inside the api container: psql -h postgres -U admin
# (Docker does DNS resolution by container name on custom networks)
```

### Connect/disconnect running containers:

```bash
docker network connect myapp-network existing-container
docker network disconnect myapp-network existing-container
```

### Host Network (Linux only)

```bash
docker run --network host nginx
```

The container shares the host's network stack directly. Port 80 in the container IS port 80 on the host — no port mapping needed. Fastest performance, but no network isolation.

### Inspect networks:

```bash
docker network inspect myapp-network
# Shows all connected containers and their IPs
```

---

## Port Mapping Explained

```bash
docker run -p 8080:80 nginx
#              │    │
#              │    └── container port (nginx listens here)
#              └── host port (what your browser connects to)
```

Multiple port mappings:
```bash
docker run -d \
  -p 80:80 \
  -p 443:443 \
  nginx
```

Bind to specific host IP (don't expose on all interfaces):
```bash
docker run -p 127.0.0.1:3000:3000 myapp    # only accessible from localhost
docker run -p 0.0.0.0:3000:3000 myapp      # accessible from anywhere (default)
```

---

## Real-World Scenario: App + Database With Proper Networking

```bash
# 1. Create a network
docker network create vault-network

# 2. Run database (not exposed to host — only accessible inside the network)
docker run -d \
  --name vault-db \
  --network vault-network \
  -e POSTGRES_DB=vault \
  -e POSTGRES_USER=vaultuser \
  -e POSTGRES_PASSWORD=secret123 \
  -v vault_db_data:/var/lib/postgresql/data \
  postgres:15

# 3. Run app (exposed to host on port 3000)
docker run -d \
  --name vault-api \
  --network vault-network \
  -p 3000:3000 \
  -e DATABASE_URL=postgresql://vaultuser:secret123@vault-db:5432/vault \
  vault-app:v1.0

# The app container reaches the DB via the hostname "vault-db"
# The DB is NOT exposed to the host machine (no -p flag)
# This is the correct security posture
```

---

## Common Misunderstanding: "Volumes save data automatically"

**The misunderstanding:** "If I run a container, Docker automatically saves important data."

**The reality:** Without a volume or bind mount, ALL data written inside a container lives in the container's "writable layer" — a temporary layer that exists only as long as the container does. `docker rm containerName` deletes that data permanently.

You must EXPLICITLY add a volume for any data you want to keep:

```bash
# Data is LOST when container is removed:
docker run postgres:15
docker rm my-postgres        # all database data is gone!

# Data PERSISTS because of the volume:
docker run -v pg_data:/var/lib/postgresql/data postgres:15
docker rm my-postgres        # container gone, but volume (and data) remains
docker run -v pg_data:/var/lib/postgresql/data postgres:15   # data is back!
```

→ Continue to: `04-docker-compose.md`
