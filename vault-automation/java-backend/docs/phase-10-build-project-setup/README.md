# Phase 10 — Build: Project Setup
## "Create the project, understand every generated file, run it"

> First build phase. Pure setup — no business logic yet.
> Goal: understand every file Spring Initializr generates and WHY it's there.

---

## What We Create

```
java-backend/
  pom.xml                                  ← Maven build descriptor
  src/
    main/
      java/
        com/vaultapp/
          VaultApiApplication.java         ← the entry point
          config/
            SecurityConfig.java
            WebConfig.java
          shared/
            GlobalExceptionHandler.java
      resources/
        application.yml                    ← all configuration
        db/migration/                      ← Flyway SQL files (empty for now)
    test/
      java/
        com/vaultapp/
          VaultApiApplicationTests.java    ← basic context load test
  .gitignore
  Dockerfile                               ← (Phase 16)
```

---

## Key Decisions Made Here

### Package structure: feature-first

We'll use **feature-first** packages, not layer-first:

```
Feature-first (our choice):        Layer-first (common but harder to navigate):
com.vaultapp.notes/                com.vaultapp.controller/
  NoteController.java                NoteController.java
  NoteService.java                   UserController.java
  NoteRepository.java              com.vaultapp.service/
  Note.java (entity)                 NoteService.java
  NoteResponse.java (dto)            UserService.java
  NoteCreateRequest.java           com.vaultapp.repository/
                                     NoteRepository.java
com.vaultapp.users/                com.vaultapp.entity/
  UserController.java                Note.java
  UserService.java                   User.java
  UserRepository.java
  User.java
```

Feature-first: everything for a feature is in one place.  
Finding all note-related code? → `com.vaultapp.notes/`

### Port: 8000

The Python API runs on 8000. The Java API will also run on 8000.  
In docker-compose, they won't run simultaneously — but they'll be swappable.

```yaml
server:
  port: 8000
```

### JDK 21

Latest LTS. Records, virtual threads (previewed), improved garbage collection.

---

## What You Do in This Phase

1. Go to [start.spring.io](https://start.spring.io) and generate a project with:
   - Project: Maven
   - Language: Java
   - Spring Boot: 3.3.x
   - Group: `com.vaultapp`
   - Artifact: `vault-api`
   - Java: 21
   - Dependencies:
     - Spring Web
     - Spring Data JPA
     - Spring Security
     - PostgreSQL Driver
     - Flyway Migration
     - Spring Boot Actuator
     - Validation

2. Unzip into `java-backend/`

3. Walk through every generated file — understand before running

4. Update `application.yml` with database config

5. Run `mvn spring-boot:run` — app starts on port 8000

6. Verify: `curl localhost:8000/actuator/health` returns `{"status":"UP"}`

---

## What "Application Starts" Means

Spring Boot startup log (what you should see):

```
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::                (v3.3.0)

[main] o.s.b.SpringApplication         : Starting VaultApiApplication using Java 21
[main] o.s.b.SpringApplication         : No active profile set, falling back to 1 default profile
[main] o.s.data.jpa.JpaBaseConfig      : Bootstrapping Spring Data JPA repositories ...
[main] o.s.d.j.r.query.QueryLookupStrategy : Creating Spring Data query method for ...
[main] o.h.e.t.j.p.i.JtaPlatformInitiator: Using JtaPlatform implementation: [NoJtaPlatform]
[main] j.LocalContainerEntityManagerFactoryBean: Initialized JPA EntityManagerFactory
[main] o.s.b.w.e.tomcat.TomcatWebServer: Tomcat started on port 8000 (http)
[main] com.vaultapp.VaultApiApplication: Started VaultApiApplication in 3.422 seconds
```

Key lines to understand:
- `Bootstrapping Spring Data JPA repositories` → found your `@Repository` interfaces
- `Initialized JPA EntityManagerFactory` → Hibernate configured
- `Tomcat started on port 8000` → embedded Tomcat listening
- `Started in 3.4 seconds` → Java startup time (vs Python's ~0.5s — the trade-off)

---

## Deliverable

```bash
curl localhost:8000/actuator/health
# {"status":"UP"}

curl localhost:8000/actuator/info
# {"app":{"name":"vault-api"}}
```

Application starts, actuator works. Ready for the first real endpoint.
