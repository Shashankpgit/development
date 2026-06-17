# Phase 1 — Java Ecosystem

## Goal

Before writing a single Spring Boot line, understand the tools and vocabulary.
Every Java developer needs to know these things cold — they come up in every
project, every job interview, every Stack Overflow answer.

---

## Step 1.1 — Install the tools

```bash
# Java 21 (LTS — long-term support, most stable)
sudo apt install openjdk-21-jdk

# Maven (build tool)
sudo apt install maven

# Verify
java -version   # openjdk 21...
mvn -version    # Apache Maven 3.9...
```

**Why Java 21?**
Java releases a new version every 6 months, but only some versions are LTS
(Long-Term Support) — meaning they receive security patches for years.
Java 8, 11, 17, and 21 are LTS versions. Java 21 is the current LTS.
Always use LTS in production.

---

## Step 1.2 — Understand Maven and pom.xml

Read: `docs/java/guide/01-maven-and-pom.md`

Key things to understand:
- `pom.xml` is `requirements.txt` + the build system combined
- Maven has a standard lifecycle: `compile → test → package → install`
- `mvn spring-boot:run` starts the app (like `uvicorn main:app`)
- Dependencies come from Maven Central (like PyPI)
- The `groupId:artifactId:version` triplet identifies every library

Playground:
Create a plain Maven project and run `mvn compile`. No Spring yet.

---

## Step 1.3 — Java project structure

Read: `docs/java/guide/02-java-project-structure.md`

```
src/
├── main/
│   ├── java/          ← your application code
│   └── resources/     ← config files, SQL, templates
└── test/
    └── java/          ← test code (JUnit)
```

This is Maven's standard directory layout. Every Java project in the world
follows this. Spring Boot, Quarkus, Micronaut — all use it.

The Python equivalent:
```
src/main/java/     ≈   app/
src/main/resources/≈   .env, config files
src/test/java/     ≈   tests/
```

---

## Step 1.3b — Annotations

Java annotations are metadata attached to classes, methods, or fields using `@`.
They don't change logic — they give instructions to the compiler or a framework.

Three types:
- **Built-in** (`@Override`, `@Deprecated`) — compiler reads them
- **Compile-time** (Lombok's `@Data`) — generate code before compilation
- **Runtime** (Spring's `@Service`, JPA's `@Entity`) — framework reads them
  at startup using Java Reflection

Python equivalent: decorators (`@app.get("/")` ≈ `@GetMapping("/")`).

You don't need to memorise all annotations now. Learn them as you encounter
them — each Phase introduces only the annotations relevant to that phase.

## Step 1.4 — POJO, Bean, Entity, DTO

Read: `docs/java/guide/03-pojo-bean-entity-dto.md`

These four words confuse every beginner. They are all just Java classes, but
each word carries a specific meaning about how the class is used:

| Word | What it means |
|---|---|
| POJO | Any plain Java class with fields, getters, setters. No framework dependency. |
| Bean | A POJO managed by the Spring container (Spring creates and injects it). |
| Entity | A POJO mapped to a database table (`@Entity` annotation). |
| DTO | A POJO used to carry data between layers (what the API sends/receives). |

Example — all four for a Note:
```java
// POJO (plain class, no annotations)
public class Note {
    private String title;
    private String content;
    // getters, setters
}

// Entity (POJO + database mapping)
@Entity
@Table(name = "notes")
public class Note {
    @Id
    private Long id;
    private String title;
    // ...
}

// DTO (what the API receives from the client)
public class NoteRequest {
    private String title;
    private String content;
    // no id — client doesn't send the id
}

// Bean (Spring manages this object's lifecycle)
@Service
public class NoteService {     // Spring creates one instance of this
    // ...
}
```

---

## Step 1.5 — Records (modern Java)

Java 16 introduced `record` — a compact way to write immutable data classes.
Instead of:
```java
public class NoteResponse {
    private final Long id;
    private final String title;

    public NoteResponse(Long id, String title) {
        this.id = id;
        this.title = title;
    }

    public Long getId() { return id; }
    public String getTitle() { return title; }
}
```

You write:
```java
public record NoteResponse(Long id, String title) {}
```

Same thing — 1 line. We will use records for DTOs throughout this project.

---

## Phase 1 deliverable

A plain Maven project (`vault-java/`) with:
- Correct directory structure
- A `pom.xml` with no Spring dependencies yet
- A `Main.java` with a `main()` method that prints something
- Runs with `mvn compile && mvn exec:java`

Once this works, move to Phase 2.

---

## Files in this phase

| File | Purpose |
|---|---|
| `docs/java/guide/01-maven-and-pom.md` | Maven deep dive |
| `docs/java/guide/02-java-project-structure.md` | Project layout |
| `docs/java/guide/03-pojo-bean-entity-dto.md` | The four vocabulary words |
| `vault-java/pom.xml` | Created during this phase |
| `vault-java/src/main/java/com/vault/Main.java` | Created during this phase |
