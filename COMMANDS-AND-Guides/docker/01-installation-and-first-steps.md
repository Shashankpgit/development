# Docker — Part 01: Installation, First Steps, and Essential Commands

---

## Installing Docker on Ubuntu

```bash
# Remove old versions if any
sudo apt remove docker docker-engine docker.io containerd runc

# Install prerequisites
sudo apt update
sudo apt install ca-certificates curl gnupg

# Add Docker's GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify installation
docker --version
# Docker version 24.0.5, build ...
```

### Run Docker without sudo (important!):

```bash
# Add your user to the docker group
sudo usermod -aG docker $USER

# Log out and back in (or run:)
newgrp docker

# Test (should work without sudo)
docker run hello-world
```

---

## Your First Container — `docker run`

The single most important Docker command:

```bash
docker run hello-world
```

What happens behind the scenes:
1. Docker checks if the `hello-world` image is in local cache → not found
2. Docker pulls `hello-world` from Docker Hub
3. Docker creates a container from that image
4. Docker starts the container (runs the hello-world program)
5. Program prints a message and exits
6. Container stops (because the process exited)

```bash
# Run nginx web server
docker run nginx

# Run in detached mode (background) — you get your prompt back
docker run -d nginx

# Run with a name (easier to reference than random ID)
docker run -d --name my-nginx nginx

# Run and map port: host-port:container-port
docker run -d -p 8080:80 --name my-nginx nginx
# Now: http://localhost:8080 → nginx inside container on port 80

# Run an interactive terminal
docker run -it ubuntu bash
# -i = interactive (keep stdin open)
# -t = allocate a pseudo-terminal (TTY)
# You're now INSIDE the ubuntu container! Try: ls, cat /etc/os-release, exit
```

---

## Managing Containers

### List containers:

```bash
docker ps              # running containers only
docker ps -a           # ALL containers (running + stopped)
docker ps -q           # just container IDs (for scripting)
```

Output of `docker ps`:
```
CONTAINER ID   IMAGE     COMMAND                  CREATED        STATUS        PORTS                  NAMES
a3b2c1d4e5f6   nginx     "/docker-entrypoint.…"   2 hours ago    Up 2 hours    0.0.0.0:8080->80/tcp   my-nginx
```

### Start, stop, restart:

```bash
docker stop my-nginx         # graceful stop (SIGTERM, then SIGKILL after 10s)
docker start my-nginx        # start a stopped container
docker restart my-nginx      # stop + start
docker kill my-nginx         # immediate forced stop (SIGKILL)
docker pause my-nginx        # freeze all processes (no CPU, stays in memory)
docker unpause my-nginx      # resume
```

### Delete containers:

```bash
docker rm my-nginx           # delete a STOPPED container
docker rm -f my-nginx        # force delete even if running
docker container prune       # delete ALL stopped containers
```

### Inspect a container:

```bash
docker inspect my-nginx      # full JSON details (IP, mounts, config, etc.)
docker stats                 # live CPU/memory/network usage (like top for containers)
docker stats my-nginx        # stats for one container
docker top my-nginx          # processes running inside container (like ps)
```

---

## Container Logs

```bash
docker logs my-nginx                  # all logs since start
docker logs -f my-nginx               # follow (like tail -f)
docker logs --tail 50 my-nginx        # last 50 lines
docker logs --since 1h my-nginx       # logs from last 1 hour
docker logs --since "2026-06-15T09:00:00" my-nginx
docker logs -f --tail 100 my-nginx    # follow + start from last 100 lines
```

---

## Execute Commands Inside Running Containers

```bash
# Open an interactive bash shell inside a running container
docker exec -it my-nginx bash

# Run a one-off command
docker exec my-nginx cat /etc/nginx/nginx.conf
docker exec my-nginx ls /usr/share/nginx/html/
docker exec my-nginx nginx -t          # test nginx config

# Run as root even if container runs as non-root
docker exec -u root my-nginx bash
```

`docker exec` is one of the most important debug tools. When a container is behaving unexpectedly, `docker exec -it containerName bash` puts you inside its environment to investigate.

---

## Managing Images

```bash
docker images                          # list local images
docker images -a                       # include intermediate layers
docker image ls                        # same as docker images

docker pull nginx                      # download latest nginx
docker pull nginx:1.24                 # specific version
docker pull node:18-alpine             # specific tag

docker rmi nginx                       # delete an image (fails if container uses it)
docker rmi -f nginx                    # force delete
docker image prune                     # delete all dangling (untagged) images
docker image prune -a                  # delete ALL unused images (not used by any container)
```

### Image naming convention:

```
registry/repository:tag
│         │           │
│         │           └── version label (default: "latest")
│         └── image name
└── where it's stored (default: docker.io = Docker Hub)

Examples:
nginx                           = docker.io/library/nginx:latest
nginx:1.24                      = docker.io/library/nginx:1.24
node:18-alpine                  = docker.io/library/node:18-alpine
shashank/vault-app:v1.0         = docker.io/shashank/vault-app:v1.0
ghcr.io/org/app:sha-abc123      = GitHub Container Registry
123456.dkr.ecr.ap-south-1.amazonaws.com/app:v2  = AWS ECR
```

---

## Copying Files Between Host and Container

```bash
# Copy FROM host TO container
docker cp ./config.json my-nginx:/etc/nginx/config.json

# Copy FROM container TO host
docker cp my-nginx:/var/log/nginx/access.log ./access.log

# Copy entire directory
docker cp ./html/ my-nginx:/usr/share/nginx/html/
```

---

## System Cleanup

Docker accumulates disk usage quickly. Run this regularly:

```bash
docker system df                      # see how much disk Docker is using
docker system prune                   # remove stopped containers + unused networks + dangling images
docker system prune -a                # also remove all unused images
docker system prune -a --volumes      # also remove unused volumes (CAREFUL — data loss!)
```

---

## Real-World Scenario: Run a PostgreSQL Database Locally

```bash
# Run postgres with environment variables for configuration
docker run -d \
  --name local-postgres \
  -e POSTGRES_DB=myapp \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=secretpassword \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:15

# Connect to it from your laptop (using psql):
psql -h localhost -p 5432 -U admin -d myapp

# Connect from inside the container:
docker exec -it local-postgres psql -U admin -d myapp

# See the logs:
docker logs -f local-postgres
```

The `-v postgres_data:/var/lib/postgresql/data` creates a **volume** so your database data survives when the container stops. (Volumes covered in depth in Part 04.)

---

## Common Misunderstanding: "docker stop deletes the container"

**The misunderstanding:** "Once I stop a container, it's gone."

**The reality:** `docker stop` only stops the running process inside the container. The container still exists in a stopped state — all its filesystem changes, logs, and configuration are preserved. You can see it with `docker ps -a` and restart it with `docker start`.

To actually delete a container: `docker rm containerName`

The lifecycle:
- `docker stop` → container exists but is not running (stopped state)
- `docker start` → container runs again from where it stopped (process restarts)
- `docker rm` → container is permanently deleted

This is important because: if you `docker run` the same image again without `docker rm` the old one, you'll have multiple stopped containers building up and consuming disk space. Use `docker ps -a` to see them.

→ Continue to: `02-dockerfile-and-building-images.md`
