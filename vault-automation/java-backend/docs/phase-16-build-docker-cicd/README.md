# Phase 16 — Build: Docker & CI/CD
## "Multi-stage Dockerfile + GitHub Actions → GHCR"

> Goal: package the Java API as a Docker image pushed to GHCR.
> Same pipeline pattern as the Python API.

---

## Dockerfile — Multi-Stage Build

```dockerfile
# java-backend/Dockerfile

# ─── Stage 1: Build ──────────────────────────────────────────────────────────
# Use full JDK + Maven to compile and package
FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /app

# Copy pom.xml first — download dependencies as a separate Docker layer
# If pom.xml hasn't changed, Docker reuses this cached layer (fast rebuilds)
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Now copy source and build
COPY src ./src
RUN mvn package -DskipTests -q

# ─── Stage 2: Runtime ────────────────────────────────────────────────────────
# Only JRE (not JDK) — smaller image, no compiler, no Maven
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Copy only the fat JAR from the build stage
COPY --from=builder /app/target/vault-api-*.jar app.jar

# Expose port 8000
EXPOSE 8000

# Health check for Docker/Kubernetes
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://localhost:8000/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Why multi-stage?

```
Single-stage build image:     Multi-stage build image:
  JDK 21: ~300MB               JRE 21 Alpine: ~80MB
  Maven: ~100MB                Your app.jar: ~80MB
  Source code: ~1MB            ──────────────────
  app.jar: ~80MB               Total: ~160MB
  ──────────────────
  Total: ~480MB

~3x smaller in production.
Build tools (Maven, JDK) are not needed at runtime — why ship them?
```

### .dockerignore

```
target/         ← compiled output (stage 1 creates this inside Docker)
.git/
*.md
```

---

## GitHub Actions Workflow

```yaml
# .github/workflows/java-api.yml
name: Build and Push Java API

on:
  push:
    branches: [main]
    paths:
      - 'java-backend/**'         # only trigger when java-backend changes

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    
    permissions:
      contents: read
      packages: write             # required to push to GHCR
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}   # auto-provided, no secret needed
      
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: java-backend/
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/vault-java-api:latest
            ghcr.io/${{ github.repository_owner }}/vault-java-api:${{ github.sha }}
```

---

## Java Vault API in docker-compose

```yaml
# vault/docker-compose.yml — add java-api service
java-api:
  image: ghcr.io/shashankpgit/vault-java-api:latest
  environment:
    SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/vault
    SPRING_DATASOURCE_USERNAME: vault
    SPRING_DATASOURCE_PASSWORD: ${POSTGRES_APP_PASSWORD}
    APP_ENCRYPTION_KEY: ${VAULT_ENCRYPTION_KEY}
  ports:
    - "8001:8000"    # Python API on 8000, Java API on 8001 (both can run simultaneously)
  depends_on:
    postgres:
      condition: service_healthy
```

---

## JVM Tuning for Containers

By default, the JVM allocates based on total system RAM — not container limits.  
Add flags to tell JVM to respect container memory limits:

```dockerfile
ENTRYPOINT ["java",
  "-XX:+UseContainerSupport",          # respect cgroup memory limits
  "-XX:MaxRAMPercentage=75.0",         # use 75% of container's allocated RAM
  "-jar", "app.jar"]
```

For a 512Mi container: JVM uses ~384Mi max heap.  
Without these flags: JVM might try to allocate 25% of node's 16GB RAM → 4GB → OOMKilled.

---

## Deliverable

```bash
# Build locally
cd java-backend/
docker build -t vault-java-api:local .
docker run -p 8001:8000 \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://host.docker.internal:5432/vault \
  -e SPRING_DATASOURCE_USERNAME=vault \
  -e SPRING_DATASOURCE_PASSWORD=secret \
  -e APP_ENCRYPTION_KEY=<base64-key> \
  vault-java-api:local

# Verify
curl localhost:8001/health
# {"status":"ok","database":"connected"}
```

After pushing to GHCR, the Kubernetes vault-api chart can point to either image.
