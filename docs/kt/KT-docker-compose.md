# KT — docker-compose Deep Dive

---

## Why docker-compose exists — the problem it solves

After building your Docker image, you can run a single container with `docker run`. That works for one container. But your application is not one container — it is at least two:

1. The FastAPI backend
2. PostgreSQL database

Running them separately with raw `docker run` commands means you have to:
- Start them in the right order (db before app)
- Manually create a shared network so they can talk to each other
- Manually pass environment variables to each container
- Manually mount volumes for PostgreSQL data
- Remember the exact commands every time

That is a lot to get wrong. docker-compose solves this by letting you describe your entire multi-container application in one YAML file and start everything with a single command: `docker-compose up`.

---

## What docker-compose actually is

docker-compose is a tool that reads a `docker-compose.yml` file and translates it into the equivalent `docker run` commands, networking, and volumes — automatically.

When you run `docker-compose up`:
1. Creates a private network for all services to share
2. Starts each service in dependency order
3. Passes environment variables
4. Mounts volumes
5. Maps ports

When you run `docker-compose down`:
1. Stops all containers
2. Removes them
3. Removes the network (but NOT volumes — your data is safe)

---

## The docker-compose.yml structure

```yaml
version: "3.9"          ← compose file format version

services:               ← each container is a "service"
  api:                  ← service name (you choose this)
    ...
  db:                   ← another service
    ...

volumes:                ← named volumes (persistent storage)
  postgres_data:

networks:               ← usually optional, compose creates one automatically
```

---

## All Important Fields — What They Do

### version

```yaml
version: "3.9"
```

Specifies which version of the docker-compose file format you are using. Different versions support different features. `3.9` is current and supports everything we need.

**Edge case:** Version 2.x and 3.x have different `depends_on` behavior. In version 3, `depends_on` only waits for the container to *start*, not for the service inside to be *ready*. More on this below.

---

### services

The `services` block is the core of the file. Each key under `services` is a container you want to run. The key name becomes:
- The service name (used in CLI: `docker-compose logs api`)
- The hostname other containers use to reach it over the network

```yaml
services:
  api:       ← other containers reach this at http://api:8000
  db:        ← other containers reach this at postgresql://db:5432
```

---

### image

```yaml
services:
  db:
    image: postgres:16
```

Use a pre-built image from Docker Hub. No build needed. For PostgreSQL, we always use the official image.

---

### build

```yaml
services:
  api:
    build:
      context: ./backend    ← directory containing the Dockerfile
      dockerfile: Dockerfile ← filename (optional if it's named "Dockerfile")
```

Instead of pulling an image, build one from a Dockerfile. `context` is the directory Docker sends as the build context — same concept as when you run `docker build` manually.

**`image` vs `build` — the key difference:**

| | `image` | `build` |
|---|---|---|
| Source | Pull from registry | Build from Dockerfile |
| Use for | Third-party software (PostgreSQL, Redis) | Your own application code |
| Rebuilt on `docker-compose up --build` | No | Yes |

---

### ports

```yaml
services:
  api:
    ports:
      - "8000:8000"    ← "host_port:container_port"
```

Maps a port on your host machine to a port inside the container.

- Left side (`8000`): port on your laptop — what you type in the browser
- Right side (`8000`): port inside the container — what uvicorn listens on

**Important:** This is how you access the container from outside Docker. Without `ports`, the service is only reachable from other containers on the same network.

**Why PostgreSQL doesn't need ports exposed:**
The `db` service only needs to be reachable by the `api` container, not by your browser. You can omit `ports` for it entirely in production. In development, you might expose `5432` so you can connect with a database GUI from your laptop.

---

### environment

```yaml
services:
  db:
    environment:
      POSTGRES_USER: vault_user
      POSTGRES_PASSWORD: vault_pass
      POSTGRES_DB: vault
```

Sets environment variables inside the container. Two ways to write it:

```yaml
# Map style (key: value)
environment:
  MY_VAR: hello

# List style (VAR=value)
environment:
  - MY_VAR=hello
```

Both work identically. Map style is cleaner.

**Security note:** Hardcoding values here is fine for local development. In production, never hardcode secrets — use `env_file` instead.

---

### env_file

```yaml
services:
  api:
    env_file:
      - ./backend/.env
```

Reads a `.env` file from the host and passes all variables in it to the container. This is how secrets are injected without hardcoding them in `docker-compose.yml`.

The `.env` file is NOT copied into the image (it's in `.dockerignore`). It's read by docker-compose at startup and injected at runtime.

**`environment` vs `env_file` — when to use which:**

| | `environment` | `env_file` |
|---|---|---|
| Where values come from | Inline in yaml | External file |
| Good for | Non-secret config, third-party image defaults | Your app secrets |
| Risk if committed to git | Medium (values visible) | Low (file is gitignored) |

---

### volumes (under a service)

```yaml
services:
  db:
    volumes:
      - postgres_data:/var/lib/postgresql/data
```

Mounts a volume into the container at a path. `postgres_data` is the volume name (declared at the top-level `volumes:` block). `/var/lib/postgresql/data` is where PostgreSQL stores its database files inside the container.

Without this, all your database data vanishes when the container is removed.

**Two types of volume mounts:**

```yaml
volumes:
  # Named volume — managed by Docker, persists between container restarts
  - postgres_data:/var/lib/postgresql/data

  # Bind mount — maps a directory on your host directly into the container
  - ./backend:/app
```

Bind mounts are useful in development — changes to your code on the host are immediately visible inside the container without rebuilding. Named volumes are for data you want Docker to manage.

---

### depends_on

```yaml
services:
  api:
    depends_on:
      - db
```

Tells docker-compose to start `db` before starting `api`.

**The critical gotcha — depends_on does NOT wait for readiness:**

`depends_on` only waits for the `db` *container* to start, not for PostgreSQL *inside* the container to be ready to accept connections. PostgreSQL takes a few seconds to initialize. If `api` starts too quickly, it tries to connect to PostgreSQL before it is ready and crashes.

The real fix is a healthcheck on the `db` service and `depends_on` with `condition: service_healthy`:

```yaml
services:
  db:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vault_user -d vault"]
      interval: 5s
      timeout: 5s
      retries: 5

  api:
    depends_on:
      db:
        condition: service_healthy   ← wait until db passes its healthcheck
```

This is the correct way. Without it, your app crashes on first start and you have to run `docker-compose up` a second time.

---

### healthcheck (under a service)

```yaml
services:
  db:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vault_user -d vault"]
      interval: 5s      ← run check every 5 seconds
      timeout: 5s       ← fail if no response within 5 seconds
      retries: 5        ← mark unhealthy after 5 consecutive failures
      start_period: 10s ← grace period before checks start
```

Docker runs the `test` command inside the container periodically. If it exits with code 0, the container is healthy. If it fails `retries` times, it is marked unhealthy.

`pg_isready` is a PostgreSQL tool that checks if the server is ready to accept connections. It exits 0 if ready, non-zero if not.

---

### restart

```yaml
services:
  api:
    restart: unless-stopped
```

What to do if the container exits:

| Value | Behaviour |
|---|---|
| `no` | Never restart (default) |
| `always` | Always restart, even after `docker-compose down` |
| `on-failure` | Restart only if it exited with a non-zero code |
| `unless-stopped` | Restart always unless you explicitly stop it |

`unless-stopped` is the right choice for production. `no` is fine during development.

---

### networks (top-level and per-service)

```yaml
networks:
  vault_network:

services:
  api:
    networks:
      - vault_network
  db:
    networks:
      - vault_network
```

docker-compose automatically creates a default network and puts all services on it — you do not need to define this explicitly unless you want custom network names or multiple isolated networks.

**Why this matters:** Containers on the same network can reach each other by service name. Containers on different networks cannot. This is how you isolate services in complex architectures.

---

## The Full Picture — How It All Connects

```
Your laptop
│
├── docker-compose up
│     │
│     ├── Creates network: vault_default
│     │
│     ├── Starts db container
│     │     ├── image: postgres:16
│     │     ├── environment: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
│     │     ├── volume: postgres_data → /var/lib/postgresql/data
│     │     └── healthcheck: pg_isready
│     │
│     └── Waits for db healthy → starts api container
│           ├── build: ./backend/Dockerfile
│           ├── env_file: ./backend/.env
│           ├── ports: 8000:8000
│           └── DATABASE_URL=postgresql://vault_user:vault_pass@db:5432/vault
│                                                                ↑
│                                             "db" resolves to the db container's IP
│                                             via Docker's internal DNS
│
└── http://localhost:8000  →  punched through by ports: 8000:8000  →  api container
```

---

## Edge Cases and Gotchas

### 1. The `db` hostname only works inside Docker
`DATABASE_URL=postgresql://...@db:5432/vault` works inside Docker because containers share the same network and Docker resolves `db` to the db container's IP. On your laptop outside Docker, `db` means nothing — use `localhost` there.

This is why you need two values: one for local dev (`.env` with `localhost`), one for Docker (pass via `environment:` with `db`).

### 2. `docker-compose down` vs `docker-compose down -v`
- `docker-compose down` — stops and removes containers, removes network. **Volumes survive.**
- `docker-compose down -v` — same as above plus **deletes volumes**. All database data is gone.

Never run `down -v` unless you want to wipe the database.

### 3. Changes to code don't auto-rebuild
`docker-compose up` does not rebuild images automatically. You need:
```bash
docker-compose up --build   ← rebuilds images before starting
```

### 4. `.env` file location
docker-compose automatically reads a `.env` file in the **same directory as `docker-compose.yml`**. Variables in that file are available for substitution inside `docker-compose.yml` itself using `${VAR}` syntax. This is separate from the `env_file:` field, which passes variables *into* a container.

### 5. Port conflicts
If port 8000 is already in use on your machine (e.g., your local uvicorn is running), `docker-compose up` fails with "address already in use". Stop the local server first.
