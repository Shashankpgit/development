# 02 — Installation & Setup

Install Docker on your machine and verify it works correctly. Skip to the section for your OS.

---

## How Docker Is Structured (Before You Install)

Understanding what you are installing matters before you run commands.

**Docker Engine** — the background daemon (`dockerd`) that actually builds images and runs containers. Runs only on Linux natively. On Mac and Windows, it runs inside a lightweight Linux VM.

**Docker CLI** — the `docker` command you type. It does nothing by itself — it talks to the Engine via a REST API over a Unix socket (`/var/run/docker.sock`).

**Docker Desktop** — a Mac/Windows application that bundles the Linux VM, the Engine, the CLI, and a GUI. It is the recommended install path on non-Linux machines.

```
You type:        docker run nginx
       ↓
Docker CLI      (sends command via REST API)
       ↓
Docker Engine   (runs on Linux kernel / Linux VM)
       ↓
Container       (nginx process, namespace-isolated)
```

---

## Linux (Ubuntu / Debian)

Do not install Docker from the default apt repository (`apt install docker.io`) — that version is often outdated. Use the official Docker CE (Community Edition) repository.

### Step 1 — Remove any old versions

```bash
sudo apt remove docker docker-engine docker.io containerd runc
```

### Step 2 — Set up the repository

```bash
# Install prerequisites
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Step 3 — Install Docker CE

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Step 4 — Start and enable the daemon

```bash
sudo systemctl start docker
sudo systemctl enable docker   # starts Docker automatically on boot
```

### Step 5 — Run without sudo (important)

By default, the Docker socket is owned by root. Every `docker` command requires `sudo`. Add yourself to the `docker` group to fix this:

```bash
sudo usermod -aG docker $USER
```

**Log out and log back in** (or run `newgrp docker`) for this to take effect. This is the most common "why does this not work?" issue after a fresh install.

---

## macOS

### Option A — Docker Desktop (Recommended)

1. Download from [https://docs.docker.com/desktop/install/mac-install/](https://docs.docker.com/desktop/install/mac-install/)
2. Choose Intel or Apple Silicon (M1/M2/M3) — check via Apple menu → About This Mac
3. Open the `.dmg`, drag Docker to Applications
4. Launch Docker from Applications
5. Accept the license, wait for the whale icon in the menu bar to stop animating

Docker Desktop on Mac runs a lightweight Linux VM (using Apple Hypervisor Framework). This is transparent — you use `docker` commands normally.

### Option B — Colima (Lightweight Alternative)

Colima is a community tool that runs Docker without the full Docker Desktop app. Useful on older Macs or if Docker Desktop's resource usage is too high.

```bash
brew install colima docker docker-compose
colima start
```

---

## Windows

### Option A — Docker Desktop with WSL2 (Recommended)

WSL2 (Windows Subsystem for Linux 2) is a real Linux kernel running inside Windows. Docker Desktop integrates with it.

1. Enable WSL2: open PowerShell as Administrator and run `wsl --install`
2. Restart Windows
3. Download Docker Desktop from [https://docs.docker.com/desktop/install/windows-install/](https://docs.docker.com/desktop/install/windows-install/)
4. During install, ensure "Use WSL2 instead of Hyper-V" is checked
5. Launch Docker Desktop, accept the license

After install, you can run `docker` from PowerShell, Command Prompt, or from inside your WSL2 terminal.

---

## Verifying the Installation

Run these commands. All should succeed.

```bash
# Check the CLI version
docker version

# Check the daemon is running
docker info

# Run the hello-world container
docker run hello-world
```

**What `docker run hello-world` does:**
1. Looks for an image named `hello-world` locally — not found
2. Pulls it from Docker Hub automatically
3. Starts a container from it
4. The container prints a message and exits

If you see "Hello from Docker!" — your installation works.

---

## Common Installation Issues

### "permission denied while trying to connect to the Docker daemon socket"

You haven't added yourself to the `docker` group, or haven't re-logged-in after doing so.

```bash
# Add to group (if not done yet)
sudo usermod -aG docker $USER

# Activate without logging out
newgrp docker

# Verify group membership
groups
```

### "Cannot connect to the Docker daemon at unix:///var/run/docker.sock"

The Docker daemon is not running.

```bash
# Linux
sudo systemctl start docker
sudo systemctl status docker   # check for errors

# Mac — open Docker Desktop application
# Windows — open Docker Desktop application
```

### Docker is running but very slow (Mac/Windows)

Docker Desktop allocates 2 CPUs and 2GB RAM by default on Mac/Windows. For larger projects, increase it: Docker Desktop → Settings → Resources → increase CPU and Memory.

---

## Docker Desktop vs Docker Engine — When to Use Which

| | Docker Desktop | Docker Engine (Linux only) |
|---|---|---|
| Platform | Mac, Windows, Linux | Linux only |
| Includes GUI | Yes | No |
| Resource overhead | Higher (runs a VM) | Minimal |
| Cost | Free for personal use; paid for companies >250 employees | Always free |
| Best for | Development on Mac/Windows | Linux servers, CI/CD |

For production Linux servers, always install Docker Engine directly. Docker Desktop is a development tool.

---

## Installing Docker Compose (if not already installed)

Docker Compose V2 (`docker compose`) is installed automatically with the Docker CE plugin bundle above and with Docker Desktop.

If you're on a system without it:

```bash
# Check if it's already there
docker compose version

# If missing on Linux, install the plugin
sudo apt install docker-compose-plugin
```

**V1 vs V2:**
- V1: `docker-compose` (hyphen, separate binary, written in Python) — deprecated
- V2: `docker compose` (space, plugin, written in Go) — current standard

This guide uses V2 (`docker compose` with a space).

---

## Summary

- Linux: install Docker CE from the official repository, add yourself to the docker group
- Mac/Windows: install Docker Desktop (runs a Linux VM internally)
- Verify with `docker run hello-world`
- Use `docker compose` (V2) not `docker-compose` (V1)

**Next:** [03 — Core Concepts](03-core-concepts.md)

---

## Reference Links

- [Install Docker on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) — official guide
- [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
- [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
- [Post-install steps for Linux](https://docs.docker.com/engine/install/linux-postinstall/) — sudo-less usage, autostart
