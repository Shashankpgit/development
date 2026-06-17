# Java Backend — Learning Plan Overview

## What we are building

The exact same backend that `vault/backend/` has in Python FastAPI, rebuilt in Java
using Spring Boot. Same endpoints, same database schema, same JWT validation from
Keycloak. At the end you will have two backends that do identical things — one in
Python, one in Java.

## Your starting point

You know:
- Core Java (classes, interfaces, loops, collections, generics)
- Python FastAPI (how REST APIs work, what routes/models/db sessions mean)
- That `pom.xml` is like `requirements.txt`
- That packages = folders with classes

You don't know yet:
- POJO, Bean, Entity, DTO — what these words mean in Java
- Maven (how to actually use pom.xml)
- Spring / Spring Boot — what it is and why everyone uses it
- JDBC, JPA, Hibernate — the data layer stack
- Spring Security — how auth works in Java

All of these are covered phase by phase below.

---

## The Java → Python comparison map

Every concept you already know in FastAPI has a direct Java equivalent.
Keep this as your mental anchor throughout the learning.

| FastAPI / Python | Spring Boot / Java |
|---|---|
| `main.py` with `app = FastAPI()` | `VaultApplication.java` with `@SpringBootApplication` |
| `requirements.txt` | `pom.xml` (Maven) |
| `@app.get("/notes")` | `@GetMapping("/notes")` |
| Pydantic `BaseModel` (schema) | DTO class (Data Transfer Object) |
| SQLAlchemy `Model` (ORM class) | `@Entity` class (JPA entity) |
| `SessionLocal` / `get_db()` | `Repository` interface (Spring Data JPA) |
| `db.query(Note).filter(...)` | `noteRepository.findByUserId(...)` |
| `dependencies.py` → `get_current_user()` | `JwtAuthFilter.java` (Spring Security filter) |
| Alembic migrations | Flyway migrations |
| `.env` file | `application.properties` |
| Uvicorn (ASGI server) | Embedded Tomcat (inside the JAR) |
| `app/routers/` | `controller/` package |
| `app/repositories/` | `repository/` package |
| `app/models/` | `entity/` package |
| `app/schemas/` (Pydantic) | `dto/` package |

---

## The five phases

### Phase 1 — Java Ecosystem (before any Spring)
**Goal:** understand the tools and vocabulary before writing a single endpoint.

Topics:
- Maven and pom.xml — dependencies, build lifecycle, running the app
- Java project structure — what goes where and why
- POJO, Bean, Entity, DTO — four words that confuse every beginner
- Records (Java 16+) — the modern alternative to verbose POJOs

Deliverable: a plain Maven project with a `main()` that you can run.

---

### Phase 2 — Spring Boot Fundamentals
**Goal:** understand what Spring Boot actually does and write your first REST endpoint.

Topics:
- What Spring is (IoC container, Dependency Injection) — the core idea
- What Spring Boot adds (auto-configuration, embedded server, starter POMs)
- `@SpringBootApplication` — what this annotation does
- `@RestController`, `@GetMapping`, `@PostMapping` — writing endpoints
- `@Service`, `@Repository` — the layer annotations
- `application.properties` — configuring the app
- Spring Boot DevTools — hot reload during development

Deliverable: Spring Boot app with 2–3 dummy endpoints tested in Postman.

---

### Phase 3 — Data Layer (JDBC → JPA → Spring Data)
**Goal:** understand the full data stack from foundation to what you'll actually use.

This phase teaches three things in order — not because you'll use all three, but
because each one explains WHY the next one exists.

**3A — JDBC (the foundation)**
Raw SQL over a Java connection. Verbose, manual, but it's what everything else
builds on. Writing one JDBC query makes you appreciate why JPA exists.

**3B — JPA and Hibernate (the ORM)**
JPA is the Java ORM specification. Hibernate is the implementation.
Write `@Entity` classes, let the framework generate SQL.
Same concept as SQLAlchemy in Python.

**3C — Spring Data JPA (what you will actually use)**
A layer on top of JPA. You define an interface with method names like
`findByUserId(Long userId)` and Spring generates the implementation automatically.
No SQL written at all for simple queries.

Deliverable: A `Note` entity connected to H2 (in-memory DB) with full CRUD via
Spring Data JPA. Tested in Postman.

---

### Phase 4 — Building the Vault API
**Goal:** rebuild every endpoint from `vault/backend/` in Spring Boot.

Structure to build:
```
src/main/java/com/vault/
├── VaultApplication.java
├── controller/      NoteController, PasswordController, UserController, HealthController
├── service/         NoteService, PasswordService, UserService
├── repository/      NoteRepository, PasswordRepository, UserRepository
├── entity/          Note, Password, User
├── dto/             NoteRequest, NoteResponse, PasswordRequest, PasswordResponse
└── exception/       GlobalExceptionHandler
```

Switch from H2 to PostgreSQL (same DB the Python backend uses).

Deliverable: All vault endpoints working with PostgreSQL, tested with the Postman
collection.

---

### Phase 5 — Security (JWT + Keycloak)
**Goal:** validate Keycloak JWT tokens exactly as the Python backend does.

Topics:
- Spring Security filter chain — how requests flow through security
- Writing a `JwtAuthFilter` — decode the JWT, extract `sub`, set the security context
- Protecting routes — which endpoints require auth, which don't
- Connecting to the same Keycloak realm the Python backend uses

Deliverable: The same JWT that authenticates against the Python backend also
authenticates against the Java backend. One Keycloak, two backends.

---

## Directory structure we will create

```
vault-java/                         ← new directory at repo root
├── pom.xml                         ← Maven project file
└── src/
    └── main/
        ├── java/
        │   └── com/vault/
        │       ├── VaultApplication.java
        │       ├── controller/
        │       ├── service/
        │       ├── repository/
        │       ├── entity/
        │       ├── dto/
        │       ├── security/
        │       └── config/
        └── resources/
            ├── application.properties
            └── db/migration/       ← Flyway SQL files
```

---

## Guide files (docs/java/guide/)

A guide file exists for every concept we learn. Read the guide file, then
implement. Each guide has:
- What it is and why it exists
- The Python/FastAPI equivalent
- A minimal working example
- What to watch out for

```
guide/
├── 01-maven-and-pom.md
├── 02-java-project-structure.md
├── 03-pojo-bean-entity-dto.md
├── 04-spring-boot-intro.md
├── 05-dependency-injection.md
├── 06-rest-controllers.md
├── 07-jdbc.md
├── 08-jpa-and-hibernate.md
├── 09-spring-data-jpa.md
├── 10-flyway-migrations.md
├── 11-exception-handling.md
├── 12-validation.md
└── 13-spring-security-jwt.md
```

---

## Tools you need installed

| Tool | Purpose | Install |
|---|---|---|
| Java 21 (LTS) | Runtime + compiler | `sudo apt install openjdk-21-jdk` |
| Maven 3.9+ | Build tool | `sudo apt install maven` |
| IntelliJ IDEA Community | IDE (best for Java) | jetbrains.com/idea/download |
| Postman | API testing | Already have it |
| Docker | Run PostgreSQL locally | Already have it |

Verify after install:
```bash
java -version    # should show 21
mvn -version     # should show 3.9+
```

---

## How we learn — the pattern for every phase

```
1. Read the guide file          ← understand the concept
2. Build a playground class     ← apply it in isolation (no pressure)
3. Test it                      ← confirm it works
4. Integrate into vault-java/   ← apply to the real project
5. Test with Postman            ← confirm end-to-end
```

We never skip to step 4. The playground classes exist so you can experiment
without worrying about breaking the real project.

---

## What we start with

**Phase 1, Step 1:** install Java 21 and Maven, then read
`docs/java/guide/01-maven-and-pom.md`.
