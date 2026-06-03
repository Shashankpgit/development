# 04 — Essential CLI Commands

These are the commands you will use every single day. Learn them properly once — not just the syntax but what each flag does and why it exists.

---

## The Two Surfaces

Docker CLI commands split into two groups:

- **`docker <noun> <verb>`** — the newer, structured form: `docker container run`, `docker image ls`
- **`docker <shortcut>`** — the legacy shortcuts: `docker run`, `docker images`

Both work. The shortcut form is what you will see in documentation and tutorials. This guide uses shortcuts for brevity.

---

## docker run

The most important command. Pulls an image (if not local), creates a container from it, and starts it.

```bash
docker run nginx
```

That's it in its simplest form. It pulls `nginx:latest` if not present, starts a container, and attaches your terminal to it. Press Ctrl+C to stop.

### Key flags

```bash
docker run -d nginx
```
`-d` (detach) — run in background. Returns the container ID. Your terminal is free.

```bash
docker run -p 8080:80 nginx
```
`-p host_port:container_port` — publish a port. Maps port 8080 on your machine to port 80 inside the container. Access via `http://localhost:8080`.

```bash
docker run -e MY_VAR=hello nginx
```
`-e VAR=value` — set an environment variable inside the container.

```bash
docker run -v myvolume:/data nginx
```
`-v name:path` — mount a named volume at a path inside the container.

```bash
docker run -v $(pwd)/code:/app nginx
```
`-v /host/path:/container/path` — bind mount: map a host directory into the container. Changes on the host are immediately visible in the container.

```bash
docker run --name mycontainer nginx
```
`--name` — give the container a human-readable name instead of a random one like `angry_einstein`.

```bash
docker run --rm nginx
```
`--rm` — automatically delete the container when it stops. Great for one-off commands where you do not want to clean up manually.

```bash
docker run -it ubuntu bash
```
`-it` — two flags combined:
- `-i` (interactive) — keep stdin open even if not attached
- `-t` (tty) — allocate a pseudo-terminal

Together, `-it` gives you an interactive shell inside the container. Without `-it`, `bash` would start and immediately exit because there is no terminal.

### Combining flags — a real example

```bash
docker run -d -p 5432:5432 --name my-postgres \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
```

This: runs detached, exposes port 5432, names it, passes three env vars, mounts a named volume, uses the postgres:16 image.

### Override CMD

```bash
docker run ubuntu echo "hello from ubuntu"
```

Anything after the image name overrides the `CMD` defined in the Dockerfile. Here we run `echo` instead of whatever ubuntu's default command is.

---

## docker ps

List running containers.

```bash
docker ps
```

Shows: container ID, image, command, created time, status, ports, name.

```bash
docker ps -a
```
`-a` (all) — show stopped containers too. Essential for debugging containers that exited unexpectedly.

```bash
docker ps -q
```
`-q` (quiet) — print only container IDs. Useful for piping into other commands.

```bash
# Stop all running containers
docker stop $(docker ps -q)

# Remove all containers
docker rm $(docker ps -aq)
```

---

## docker stop and docker kill

```bash
docker stop mycontainer
```

Sends `SIGTERM` to the container's PID 1. Gives it 10 seconds to shut down gracefully. If it hasn't stopped after 10 seconds, sends `SIGKILL`.

```bash
docker kill mycontainer
```

Sends `SIGKILL` immediately. No grace period. The process is killed instantly.

**When to use which:**
- Use `docker stop` almost always — it allows graceful shutdown
- Use `docker kill` when a container is frozen and not responding to SIGTERM

```bash
docker stop --time 30 mycontainer   # give it 30 seconds instead of 10
```

---

## docker rm

Remove a stopped container.

```bash
docker rm mycontainer
```

Container must be stopped first. To force-remove a running container:

```bash
docker rm -f mycontainer    # -f (force) stops and removes in one step
```

Remove all stopped containers at once:

```bash
docker container prune
```

---

## docker images

List images stored locally.

```bash
docker images
```

Shows: repository, tag, image ID, created time, size.

```bash
docker images -a    # show intermediate layers too
docker images -q    # just image IDs
```

---

## docker pull

Download an image from a registry. `docker run` does this implicitly if the image is not local, but explicit pulls are useful to pre-fetch or check for updates.

```bash
docker pull nginx
docker pull nginx:alpine
docker pull postgres:16
```

---

## docker rmi

Remove one or more images.

```bash
docker rmi nginx
docker rmi nginx:alpine postgres:16
```

You cannot remove an image that has running or stopped containers using it. Remove containers first.

```bash
docker rmi -f nginx     # force remove (even if containers exist)
```

Remove all unused images:

```bash
docker image prune          # removes dangling images (untagged)
docker image prune -a       # removes all images not used by a container
```

---

## docker exec

Run a command inside a **running** container.

```bash
docker exec mycontainer ls /app
```

The most common use — get a shell inside a running container:

```bash
docker exec -it mycontainer bash    # if bash is available
docker exec -it mycontainer sh      # for alpine/minimal images
```

Other useful exec commands:

```bash
# See all environment variables the container has
docker exec mycontainer env

# Check a process list inside the container
docker exec mycontainer ps aux

# Run as a specific user
docker exec -u root mycontainer bash
```

**Key difference from `docker run -it image bash`:**
- `docker run -it` starts a new container from an image (clean slate)
- `docker exec -it` enters an already-running container (current state)

---

## docker logs

View stdout/stderr output from a container.

```bash
docker logs mycontainer
```

```bash
docker logs -f mycontainer         # -f (follow): stream logs in real time
docker logs --tail 50 mycontainer  # last 50 lines only
docker logs --since 5m mycontainer # logs from last 5 minutes
docker logs --since 2024-01-15T10:00:00 mycontainer  # since a timestamp
```

**Important:** `docker logs` only works for containers whose logging driver is `json-file` or `journald` (the default). If you switched to a different logging driver, you need that driver's tools to access logs.

---

## docker inspect

Returns the full JSON metadata for a container or image. Everything Docker knows about it.

```bash
docker inspect mycontainer
docker inspect nginx:latest    # inspect an image
```

Useful fields to extract:

```bash
# Get the container's IP address
docker inspect mycontainer --format '{{.NetworkSettings.IPAddress}}'

# Get all environment variables
docker inspect mycontainer --format '{{.Config.Env}}'

# See what mounts are configured
docker inspect mycontainer --format '{{json .Mounts}}' | python3 -m json.tool
```

---

## docker stats

Live CPU, memory, network I/O, and disk I/O usage for running containers.

```bash
docker stats                    # all running containers
docker stats mycontainer        # specific container
docker stats --no-stream        # one snapshot, then exit (not live)
```

---

## docker cp

Copy files between host and container (works on running and stopped containers).

```bash
# host → container
docker cp ./myfile.txt mycontainer:/app/myfile.txt

# container → host
docker cp mycontainer:/app/config.json ./config.json
```

Useful for extracting logs, config files, or debugging output from a container.

---

## docker build

Build an image from a Dockerfile (covered in depth in [05-dockerfile.md](05-dockerfile.md)):

```bash
docker build -t myapp:1.0 .     # -t: tag, .: build context is current directory
docker build -f Dockerfile.prod -t myapp:prod .    # -f: specify Dockerfile name
docker build --no-cache -t myapp:1.0 .              # ignore cache, full rebuild
```

---

## docker system prune

Clean up everything unused — stopped containers, dangling images, unused networks.

```bash
docker system prune              # prompts for confirmation
docker system prune -f           # skip confirmation
docker system prune -a           # also remove unused images (not just dangling)
docker system prune --volumes    # also remove unused volumes (CAREFUL: data loss)
```

**Warning:** `--volumes` deletes volumes not attached to any container. If you have a postgres volume not currently used by a container, it will be deleted. Only run this when you genuinely want to wipe everything.

---

## docker volume

Volume management commands (covered fully in [08-volumes.md](08-volumes.md)):

```bash
docker volume ls                          # list all volumes
docker volume create myvol               # create a named volume
docker volume inspect myvol             # full metadata
docker volume rm myvol                  # delete a volume
docker volume prune                     # delete all unused volumes
```

---

## docker network

Network management commands (covered fully in [09-networking.md](09-networking.md)):

```bash
docker network ls                        # list all networks
docker network create mynet             # create a network
docker network inspect mynet           # full metadata
docker network connect mynet mycontainer      # add container to network
docker network disconnect mynet mycontainer   # remove container from network
```

---

## Cheat Sheet

| Command | What it does |
|---|---|
| `docker run -d -p 8080:80 --name web nginx` | Run nginx detached, expose port, name it |
| `docker run --rm -it ubuntu bash` | Interactive shell, auto-cleanup on exit |
| `docker ps` | List running containers |
| `docker ps -a` | List all containers including stopped |
| `docker stop web` | Graceful stop (SIGTERM) |
| `docker rm web` | Delete stopped container |
| `docker rm -f web` | Force stop and delete |
| `docker images` | List local images |
| `docker rmi nginx` | Delete image |
| `docker pull postgres:16` | Download image |
| `docker exec -it web bash` | Shell into running container |
| `docker logs -f web` | Stream container logs |
| `docker inspect web` | Full container metadata JSON |
| `docker stats` | Live resource usage |
| `docker cp web:/app/log.txt .` | Copy file from container |
| `docker build -t myapp:1.0 .` | Build image from Dockerfile |
| `docker system prune -a` | Delete all unused containers + images |

---

## Summary

- `docker run` creates and starts a container; `-d`, `-p`, `-e`, `-v`, `--name`, `-it`, `--rm` are the essential flags
- `docker ps -a` shows all containers including stopped ones
- `docker stop` sends SIGTERM (graceful); `docker kill` sends SIGKILL (immediate)
- `docker exec -it` drops you into a running container's shell
- `docker logs -f` streams live output
- `docker inspect` gives you everything Docker knows about a container or image
- `docker system prune -a` cleans up everything unused

**Next:** [05 — Dockerfile](05-dockerfile.md)

---

## Reference Links

- [docker run reference](https://docs.docker.com/reference/cli/docker/container/run/)
- [docker exec reference](https://docs.docker.com/reference/cli/docker/container/exec/)
- [Full CLI reference](https://docs.docker.com/reference/cli/docker/)
