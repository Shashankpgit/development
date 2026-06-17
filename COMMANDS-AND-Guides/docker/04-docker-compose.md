# Docker — Part 04: Docker Compose — Multi-Container Applications

Running multiple `docker run` commands manually doesn't scale. Docker Compose lets you define your entire application stack in a single YAML file and manage it with simple commands.

---

## What Docker Compose Solves

Without Compose, running a 3-service app requires:
```bash
docker network create myapp
docker volume create db_data
docker run -d --name db --network myapp -v db_data:/var/lib/postgresql/data -e POSTGRES_PASSWORD=secret postgres:15
docker run -d --name redis --network myapp redis:7
docker run -d --name api --network myapp -p 3000:3000 -e DATABASE_URL=postgresql://postgres:secret@db:5432/myapp -e REDIS_URL=redis://redis:6379 myapi:v1.0
```

With Compose: `docker compose up -d`

---

## Anatomy of a `docker-compose.yml`

```yaml
# docker-compose.yml

version: '3.8'          # compose file format version

services:               # define each container
  
  db:                   # service name (also becomes DNS hostname on the network)
    image: postgres:15
    restart: unless-stopped
    environment:
      POSTGRES_DB: vault
      POSTGRES_USER: vaultuser
      POSTGRES_PASSWORD: secretpassword
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vaultuser -d vault"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    networks:
      - backend

  api:
    build:              # build from local Dockerfile
      context: .        # build context (where the Dockerfile is)
      dockerfile: Dockerfile
    image: vault-api:latest    # also tag the built image
    restart: unless-stopped
    ports:
      - "3000:3000"     # host:container
    environment:
      NODE_ENV: production
      DATABASE_URL: postgresql://vaultuser:secretpassword@db:5432/vault
      REDIS_URL: redis://redis:6379
    depends_on:
      db:
        condition: service_healthy    # wait for db healthcheck to pass
      redis:
        condition: service_started
    networks:
      - backend
    volumes:
      - ./uploads:/app/uploads    # bind mount for user uploads

  nginx:
    image: nginx:1.24-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      - api
    networks:
      - backend

volumes:                # named volumes declaration
  db_data:

networks:               # custom networks
  backend:
    driver: bridge
```

---

## Essential Docker Compose Commands

```bash
# Start all services (build if needed, detached mode)
docker compose up -d

# Start and force rebuild images
docker compose up -d --build

# Stop all services (containers stop but are not removed)
docker compose stop

# Stop AND remove containers, networks (volumes preserved)
docker compose down

# Stop AND remove containers, networks, AND volumes (DATA LOSS!)
docker compose down -v

# See running services
docker compose ps

# View logs (all services)
docker compose logs -f

# View logs for a specific service
docker compose logs -f api
docker compose logs -f --tail 100 db

# Scale a service (run multiple instances)
docker compose up -d --scale api=3

# Execute command in a service
docker compose exec api bash
docker compose exec db psql -U vaultuser -d vault

# Restart a single service
docker compose restart api

# Pull latest images for all services
docker compose pull

# Check configuration is valid
docker compose config

# Build images without starting
docker compose build

# Stop and remove a specific service
docker compose rm -f api
```

---

## Environment Variables in Compose

### Using a `.env` file:

Create a `.env` file in the same directory as `docker-compose.yml`:

```bash
# .env
POSTGRES_PASSWORD=supersecretpassword
POSTGRES_USER=vaultuser
POSTGRES_DB=vault
API_PORT=3000
IMAGE_TAG=v1.5.0
```

Reference in `docker-compose.yml`:

```yaml
services:
  db:
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: ${POSTGRES_USER}
  
  api:
    image: vault-api:${IMAGE_TAG}
    ports:
      - "${API_PORT}:3000"
```

Now you can have different `.env.development`, `.env.staging`, `.env.production` files.

### Multiple env files:

```bash
docker compose --env-file .env.production up -d
```

---

## Override Files for Different Environments

```yaml
# docker-compose.yml (base — shared across all environments)
services:
  api:
    build: .
    environment:
      NODE_ENV: production

# docker-compose.override.yml (auto-loaded in development)
services:
  api:
    environment:
      NODE_ENV: development
    volumes:
      - .:/app          # mount source code for live reload
    ports:
      - "3000:3000"

# docker-compose.prod.yml (explicitly loaded for production)
services:
  api:
    image: registry.example.com/vault-api:${VERSION}
    deploy:
      replicas: 3
```

```bash
# Development (auto-loads override file):
docker compose up -d

# Production (explicitly specify files):
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## Depends_on and Health Checks

`depends_on` ensures services start in the right order — but by default it only waits for the container to START, not for the service inside to be READY.

```yaml
# WRONG — api might start before postgres is ready to accept connections
depends_on:
  - db

# CORRECT — api waits until db healthcheck passes
depends_on:
  db:
    condition: service_healthy
```

Always pair `depends_on` with `healthcheck` on the dependency.

---

## Real-World Scenario: Full Stack Dev Environment

```yaml
# docker-compose.yml for local development
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: vault_dev
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: devpassword
    ports:
      - "5432:5432"    # expose to host so your IDE can connect
    volumes:
      - postgres_dev:/var/lib/postgresql/data
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql   # auto-run on first start

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  mailhog:            # fake SMTP server — catches all emails locally
    image: mailhog/mailhog
    ports:
      - "1025:1025"   # SMTP
      - "8025:8025"   # Web UI to view caught emails

  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgresql://dev:devpassword@postgres:5432/vault_dev
      REDIS_URL: redis://redis:6379
      SMTP_HOST: mailhog
      SMTP_PORT: 1025
    volumes:
      - .:/app                      # hot reload: code changes immediately
      - /app/node_modules           # but keep container's node_modules
    command: npm run dev            # override CMD for development (e.g., nodemon)
    depends_on:
      - postgres
      - redis

volumes:
  postgres_dev:
```

```bash
docker compose up -d
# Your entire dev environment in one command
# postgres, redis, mailhog, and your app — all running, connected, ready
```

---

## Common Misunderstanding: "`depends_on` means my app won't start until the database is ready"

**The misunderstanding:** "I added `depends_on: db` so my app will wait until PostgreSQL finishes starting."

**The reality:** Without `condition: service_healthy`, `depends_on` only waits for the container to START (Docker daemon created it), not for the service inside to be READY to accept connections. PostgreSQL takes ~2 seconds to initialize after the container starts — your app might try to connect before that.

**The proper fix:**

```yaml
db:
  image: postgres:15
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres"]
    interval: 5s
    retries: 5

api:
  depends_on:
    db:
      condition: service_healthy   # wait for pg_isready to pass
```

Alternatively: add retry logic to your application's database connection code (a best practice regardless).

→ Continue to: `05-registry-and-real-world-scenarios.md`
