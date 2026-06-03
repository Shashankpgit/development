# 09 — Networking

Container networking is where most Docker beginners hit their first wall. The root cause is almost always the same: using `localhost` when you should be using a container name. This file builds the mental model that makes networking click.

---

## The Core Insight: Each Container Has Its Own Network Stack

When a container starts, Docker gives it its own **network namespace** — a completely isolated network stack with its own:
- Network interfaces (including `lo` — the loopback)
- IP address
- Routing table
- `localhost` (`127.0.0.1`)

This means **`localhost` inside Container A is NOT the same as `localhost` on your host machine** and NOT the same as `localhost` inside Container B.

```
Host machine (your laptop)
│  localhost = 127.0.0.1 → host loopback
│
├── Container A (your app)
│   │  localhost = 127.0.0.1 → Container A's own loopback
│   │  PostgreSQL is NOT running here
│
└── Container B (PostgreSQL)
    │  localhost = 127.0.0.1 → Container B's own loopback
    │  PostgreSQL IS running here, but only reachable via Container B's localhost
```

**The mistake:** App in Container A uses `DATABASE_URL=postgresql://localhost:5432/mydb`. Container A looks for PostgreSQL on its own loopback. Nothing is running there. Connection fails.

**The fix:** Use the service name (when using docker-compose) or the container name.

---

## Docker's Network Drivers

Docker supports several network types (called "drivers"). You choose a driver when creating a network.

### bridge (default)

The default network driver for containers on a single host. Docker creates a virtual bridge interface (`docker0`) on the host. Containers attach to this bridge and can communicate with each other through it.

```bash
docker network create --driver bridge mynet
# or simply:
docker network create mynet   # bridge is the default
```

On the host, you'll see:
```bash
ip addr show docker0     # the virtual bridge interface Docker creates
```

Containers on the same bridge network can reach each other. Containers on different bridge networks cannot (unless you explicitly connect them).

**Default bridge vs user-defined bridge:**

Docker has a built-in default bridge network (`bridge`). When you run a container without specifying a network, it joins this default bridge. But there's a critical difference:

| | Default bridge | User-defined bridge |
|---|---|---|
| Container discovery by name | ❌ No DNS | ✅ Automatic DNS |
| Isolation | All containers share it | Only containers you add |
| Recommended | No | Yes |

On the default bridge, containers can only reach each other by IP address. On a user-defined bridge, Docker provides DNS resolution — containers can reach each other by container name.

```bash
# Containers on the same user-defined bridge can use service names
docker network create myapp_net
docker run --network myapp_net --name db postgres:16
docker run --network myapp_net --name api myapp   # api can reach db as "db"
```

### host

Container shares the host's network namespace entirely. No isolation. Container uses the host's IP and ports directly.

```bash
docker run --network host nginx
# nginx listens on host port 80 directly — no -p mapping needed
```

**When to use:** High-performance scenarios where network overhead matters, or for network monitoring tools that need direct host access. **Not for production app containers** — no isolation.

**Linux only.** On Mac/Windows, `--network host` maps to the Docker Desktop VM's network, not your actual host.

### none

Container has no networking at all — only a loopback interface.

```bash
docker run --network none myimage
```

**When to use:** Batch processing, data transformation, or any workload that should have zero network access (for security).

### overlay

Enables containers running on different Docker hosts to communicate. Used with Docker Swarm for multi-host deployments.

```bash
docker network create --driver overlay myswarm_net
```

Out of scope for single-machine development — documented for completeness.

### macvlan

Assigns a MAC address to a container, making it appear as a physical device on the network. Used for legacy applications that need to appear to be on the LAN directly. Rarely needed.

---

## Docker Compose and Automatic Networking

When you run `docker compose up`, docker-compose automatically:
1. Creates a **user-defined bridge network** named `<project>_default` (where `<project>` is the directory name)
2. Attaches every service to this network
3. Enables DNS resolution — every service is reachable by its service name

```yaml
services:
  api:          # reachable as "api" from other containers
    build: .
    
  db:           # reachable as "db" from other containers
    image: postgres:16
```

Inside the `api` container, you can connect to PostgreSQL at `db:5432` — Docker's internal DNS resolves `db` to the db container's IP automatically.

```
DATABASE_URL=postgresql://vault_user:vault_pass@db:5432/vault
                                                 ↑
                                                 "db" → Docker DNS → db container IP
```

---

## Port Publishing: Reaching Containers from Outside

Containers on a bridge network are isolated from the host. To make a container accessible from your browser or from outside Docker, you must **publish** a port.

```bash
docker run -p 8080:80 nginx
#          -p host:container
```

This creates a port mapping: traffic arriving at port 8080 on your host is forwarded to port 80 inside the container.

```
Browser → localhost:8080 → [host port 8080] → Docker proxy → [container port 80] → nginx
```

In docker-compose:
```yaml
services:
  api:
    ports:
      - "8000:8000"     # host:container
      - "127.0.0.1:8000:8000"  # bind to localhost only (more secure)
```

**When NOT to publish ports:**

PostgreSQL in a compose file usually doesn't need its port exposed to the host. It only needs to be reachable by the `api` container on the same internal network. Exposing `5432` to the host means any process on your laptop can reach it, which is an unnecessary security exposure.

```yaml
services:
  db:
    image: postgres:16
    # No ports: block — only accessible from inside Docker network
    # api can reach it at db:5432 but your host cannot reach localhost:5432
```

For development, you might expose it temporarily to use a DB GUI:
```yaml
  db:
    ports:
      - "5432:5432"    # exposed for local dev only — remove in production
```

---

## Custom Networks

Define your own networks for fine-grained control:

```yaml
networks:
  frontend_net:    # web-facing services
  backend_net:     # internal services only

services:
  nginx:
    networks:
      - frontend_net     # can reach frontend only
  
  api:
    networks:
      - frontend_net     # reachable from nginx
      - backend_net      # can reach database
  
  db:
    networks:
      - backend_net      # only reachable from api — nginx cannot reach db directly
```

This is a key security pattern: your database is not reachable from the internet-facing tier even if nginx is compromised.

---

## Container DNS — How Names Resolve

Docker's embedded DNS server (`127.0.0.11` inside containers) resolves container names and service names to their current IPs.

```bash
# Inside a container on a user-defined network:
nslookup db
# → Server: 127.0.0.11
# → Address: 172.18.0.3
```

This DNS resolution is automatic on user-defined networks. It is NOT available on the default `bridge` network.

If a container's IP changes (container restarted, scale up/down), DNS automatically returns the new IP. You never hardcode container IPs.

---

## Network Commands

```bash
# List networks
docker network ls

# Inspect a network (see connected containers and their IPs)
docker network inspect myapp_default

# Create a network
docker network create mynet
docker network create --driver bridge --subnet 172.20.0.0/16 mynet

# Connect a running container to a network
docker network connect mynet mycontainer

# Disconnect
docker network disconnect mynet mycontainer

# Remove a network (only if no containers are attached)
docker network rm mynet

# Remove all unused networks
docker network prune
```

---

## The localhost Confusion — Full Picture

| Where code runs | `localhost` resolves to | To reach PostgreSQL in another container |
|---|---|---|
| Your host machine (local dev) | Your machine | `localhost:5432` (if postgres runs on host) |
| Container A (your app) | Container A's own loopback | Service name, e.g. `db:5432` |
| Container A (your app) | — | NOT `localhost:5432` — that's Container A's loopback |

**How to handle dev vs Docker:**

Your local dev `.env` and Docker env need different `DATABASE_URL`:

```bash
# .env for local development (app running on host, postgres on host)
DATABASE_URL=postgresql://user:pass@localhost:5432/mydb

# .env for Docker (both app and postgres in containers)
DATABASE_URL=postgresql://user:pass@db:5432/mydb
#                                    ↑ service name
```

Common pattern: use `env_file` in compose for the docker-specific env, keep the local `.env` for running outside Docker.

---

## Debugging Network Issues

### Is the container running and reachable?

```bash
# Check that the container is running
docker ps

# Get the container's IP
docker inspect mycontainer --format '{{.NetworkSettings.IPAddress}}'
docker inspect mycontainer --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

### Can Container A reach Container B?

```bash
# Get a shell in Container A
docker exec -it container_a sh

# Try to reach container_b by service name
ping db               # should resolve and respond
curl http://api:8000  # test HTTP
```

### Is the port open inside the container?

```bash
# Inside the container
docker exec -it mycontainer sh
# Then check what's listening:
netstat -tlnp
# or:
ss -tlnp
```

### nslookup for DNS debugging

```bash
docker exec -it mycontainer sh
nslookup db            # does "db" resolve to an IP?
nslookup google.com    # does external DNS work?
```

---

## Common Networking Mistakes

### 1. Using `localhost` between containers
The #1 mistake. Use service names instead.

### 2. Exposing all ports to 0.0.0.0
`ports: - "5432:5432"` binds to `0.0.0.0` — reachable from any machine on your network. Use `127.0.0.1:5432:5432` to bind to localhost only during development.

### 3. Relying on the default bridge network
The default bridge network has no DNS. Always use user-defined networks (docker-compose creates one automatically; with raw docker, create one explicitly).

### 4. Hardcoding container IPs
Container IPs change when containers restart. Always use names.

### 5. Not checking which network the container joined
```bash
docker inspect mycontainer | grep -A 10 Networks
```

---

## Summary

- Each container has its own network namespace — its own `localhost`
- `localhost` inside a container is that container's own loopback, not the host or other containers
- Use **service names** (in compose) or **container names** to communicate between containers
- Docker compose creates a user-defined bridge network with DNS automatically
- Port publishing (`-p` or `ports:`) exposes a container to the host — only do it when needed
- Use multiple compose networks to isolate tiers (frontend, backend, database)

**Next:** [10 — Docker Compose](10-docker-compose.md)

---

## Reference Links

- [Docker networking overview](https://docs.docker.com/network/)
- [Bridge networks](https://docs.docker.com/network/drivers/bridge/)
- [Networking in docker compose](https://docs.docker.com/compose/networking/)
- [Container DNS](https://docs.docker.com/network/drivers/bridge/#dns-services)
