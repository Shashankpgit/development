# Java Project Structure

## The standard Maven layout

Every Java project (Spring Boot, Quarkus, plain Java) uses this exact structure:

```
vault-java/
├── pom.xml                                ← project definition
└── src/
    ├── main/
    │   ├── java/                          ← your application code
    │   │   └── com/vault/                 ← package hierarchy (mirrors groupId)
    │   │       ├── VaultApplication.java  ← main entry point
    │   │       ├── controller/
    │   │       ├── service/
    │   │       ├── repository/
    │   │       ├── entity/
    │   │       ├── dto/
    │   │       ├── security/
    │   │       └── config/
    │   └── resources/                     ← non-Java files
    │       ├── application.properties     ← app configuration
    │       └── db/migration/              ← Flyway SQL files
    └── test/
        └── java/
            └── com/vault/                 ← mirrors main structure
                └── service/
                    └── NoteServiceTest.java
```

---

## How packages map to directories

In Java, a **package** is a namespace that maps directly to a directory path.

```java
// File: src/main/java/com/vault/controller/NoteController.java
package com.vault.controller;   // must match the directory path

public class NoteController {
    // ...
}
```

```
src/main/java/
└── com/
    └── vault/
        └── controller/
            └── NoteController.java
```

Python equivalent:
```
app/
└── routers/
    └── notes.py        # "package" in Python is just a directory with __init__.py
```

The difference: in Java the package declaration inside the file MUST match
the directory path. If they don't match, the compiler errors.

---

## The `com.vault` package convention

Package names follow a reverse domain convention:
```
com.vault.controller   →   your company domain reversed + project + layer
org.springframework    →   springframework.org reversed
```

For a personal project `com.vault` is fine. For a company it would be
`com.companyname.projectname`.

This convention guarantees globally unique package names — same reason for
Java's global uniqueness requirement.

---

## What goes in each layer

### `controller/` — HTTP entry points
Handles HTTP requests. Calls the service layer. Returns responses.
Never contains business logic or database calls.

```java
// Good — thin controller
@GetMapping("/{id}")
public NoteResponse getNote(@PathVariable Long id,
                            @AuthenticationPrincipal User user) {
    return noteService.getNote(id, user);  // delegates to service
}

// Bad — fat controller (don't do this)
@GetMapping("/{id}")
public NoteResponse getNote(@PathVariable Long id) {
    Note note = noteRepository.findById(id).orElseThrow();  // DB call in controller
    if (!note.getUser().getId().equals(userId)) {            // business logic in controller
        throw new AccessDeniedException("...");
    }
    return new NoteResponse(note.getId(), note.getTitle());
}
```

### `service/` — business logic
The brain of the application. Validates business rules, orchestrates repository
calls, handles transactions.

```java
@Service
public class NoteService {
    private final NoteRepository noteRepository;

    public NoteResponse getNote(Long id, User user) {
        Note note = noteRepository.findByIdAndUserId(id, user.getId())
            .orElseThrow(() -> new NoteNotFoundException(id));
        return toResponse(note);
    }
}
```

### `repository/` — database access
Only speaks to the database. No business logic. Pure CRUD.

```java
public interface NoteRepository extends JpaRepository<Note, Long> {
    List<Note> findByUserId(Long userId);
    Optional<Note> findByIdAndUserId(Long id, Long userId);
}
```

### `entity/` — database models
Classes mapped to database tables. These are what Hibernate persists.

### `dto/` — request and response shapes
What the API receives (Request) and returns (Response). Different from entities
because they only contain what the API consumer should see/send.

### `security/` — auth filters and config
JWT filter, Spring Security configuration.

### `config/` — application configuration classes
CORS config, encryption bean definitions, etc.

### `exception/` — custom exceptions and global handler
`NoteNotFoundException`, `GlobalExceptionHandler`.

---

## Python FastAPI comparison

```
FastAPI (vault/backend/app/)        Spring Boot (vault-java/src/main/java/com/vault/)
────────────────────────────────    ─────────────────────────────────────────────────
routers/notes.py                    controller/NoteController.java
(no service layer in Python app)    service/NoteService.java
repositories/note_repository.py     repository/NoteRepository.java
models/note.py (SQLAlchemy)         entity/Note.java (JPA)
schemas/ (Pydantic models)          dto/ (NoteRequest, NoteResponse records)
dependencies.py (get_current_user)  security/JwtAuthFilter.java
main.py                             VaultApplication.java
.env                                src/main/resources/application.properties
```

---

## The entry point

```java
// src/main/java/com/vault/VaultApplication.java
package com.vault;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class VaultApplication {
    public static void main(String[] args) {
        SpringApplication.run(VaultApplication.class, args);
    }
}
```

`@SpringBootApplication` = three annotations in one:
- `@Configuration` — this class can define Spring beans
- `@EnableAutoConfiguration` — auto-configure based on classpath
- `@ComponentScan` — scan this package and all sub-packages for Spring components

`SpringApplication.run()` starts the embedded Tomcat, loads all components,
and starts listening on the configured port.

Python equivalent:
```python
# main.py
app = FastAPI()
# uvicorn main:app --reload    ← starts the server externally
```

In Spring Boot the server starts from inside `main()`. No external process needed.

---

## The `resources/` directory

```
src/main/resources/
├── application.properties       ← main config (like .env)
├── application-dev.properties   ← dev-specific overrides
├── application-prod.properties  ← prod-specific overrides
└── db/migration/
    ├── V1__create_users.sql
    └── V2__create_notes.sql
```

`application.properties` is automatically loaded by Spring Boot at startup.
You can switch profiles (`dev`, `prod`) with:
```bash
java -jar vault.jar --spring.profiles.active=prod
```
