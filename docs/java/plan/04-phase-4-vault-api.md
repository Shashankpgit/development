# Phase 4 — Building the Vault API

## Goal

Rebuild every endpoint from `vault/backend/` in Spring Boot with PostgreSQL.
By the end, the Java backend is feature-complete and all Postman tests pass.

---

## The FastAPI backend we are rebuilding

```
vault/backend/app/
├── routers/
│   ├── health.py      GET  /health
│   ├── users.py       GET  /api/users/me
│   ├── notes.py       CRUD /api/notes
│   └── passwords.py   CRUD /api/passwords
├── models/
│   ├── user.py        User SQLAlchemy model
│   ├── note.py        Note SQLAlchemy model
│   └── password.py    Password SQLAlchemy model
├── repositories/
│   ├── user_repository.py
│   ├── note_repository.py
│   └── password_repository.py
├── schemas/            (Pydantic — request/response shapes)
└── dependencies.py     (get_current_user from JWT)
```

---

## Spring Boot equivalent structure

```
vault-java/src/main/java/com/vault/
├── VaultApplication.java
├── controller/
│   ├── HealthController.java
│   ├── UserController.java
│   ├── NoteController.java
│   └── PasswordController.java
├── service/
│   ├── UserService.java
│   ├── NoteService.java
│   └── PasswordService.java
├── repository/
│   ├── UserRepository.java
│   ├── NoteRepository.java
│   └── PasswordRepository.java
├── entity/
│   ├── User.java
│   ├── Note.java
│   └── Password.java
├── dto/
│   ├── NoteRequest.java
│   ├── NoteResponse.java
│   ├── PasswordRequest.java
│   └── PasswordResponse.java
├── security/
│   └── JwtAuthFilter.java        (Phase 5)
├── config/
│   └── SecurityConfig.java       (Phase 5)
└── exception/
    └── GlobalExceptionHandler.java
```

---

## Step 4.1 — Switch to PostgreSQL

Switch from H2 to PostgreSQL (same database the Python backend uses).

```xml
<!-- pom.xml — replace H2 with PostgreSQL driver -->
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <scope>runtime</scope>
</dependency>
```

```properties
# application.properties
spring.datasource.url=jdbc:postgresql://localhost:5432/vaultdb
spring.datasource.username=vault_user
spring.datasource.password=vault_pass
spring.jpa.hibernate.ddl-auto=validate
```

`ddl-auto=validate` — Hibernate validates that entities match the existing
schema but does not create or modify tables. Flyway handles schema changes.

---

## Step 4.2 — Entities

Three entities matching the Python SQLAlchemy models exactly.

**User entity** — same as `vault/backend/app/models/user.py`:
```java
@Entity
@Table(name = "users")
@Data @NoArgsConstructor @AllArgsConstructor
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String sub;          // Keycloak subject claim
}
```

**Note entity** — same as `vault/backend/app/models/note.py`:
```java
@Entity
@Table(name = "notes")
@Data @NoArgsConstructor @AllArgsConstructor
public class Note {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    private String content;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "created_at", updatable = false)
    @CreationTimestamp
    private LocalDateTime createdAt;
}
```

**Password entity** — same as `vault/backend/app/models/password.py`:
```java
@Entity
@Table(name = "passwords")
@Data @NoArgsConstructor @AllArgsConstructor
public class Password {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String label;

    @Column(nullable = false)
    private String encryptedValue;   // AES encrypted, same as Python

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
}
```

---

## Step 4.3 — DTOs (request and response shapes)

DTOs are what the API sends and receives. They are separate from entities
because:
- The entity has all DB fields (user_id, created_at, internal IDs)
- The request DTO has only what the client sends (title, content)
- The response DTO has only what the client should see (no internal fields)

Using Java records for DTOs (clean, immutable):

```java
// What the client sends to create a note
public record NoteRequest(
    @NotBlank String title,
    String content
) {}

// What the API returns
public record NoteResponse(
    Long id,
    String title,
    String content,
    LocalDateTime createdAt
) {}
```

Python Pydantic equivalent:
```python
class NoteCreate(BaseModel):
    title: str
    content: str | None

class NoteResponse(BaseModel):
    id: int
    title: str
    content: str | None
    created_at: datetime
```

---

## Step 4.4 — Exception handling

Read: `docs/java/guide/11-exception-handling.md`

In FastAPI you raise `HTTPException`. In Spring Boot you throw exceptions and
a `@ControllerAdvice` class handles them globally:

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(NoteNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public Map<String, String> handleNotFound(NoteNotFoundException ex) {
        return Map.of("detail", ex.getMessage());
    }

    @ExceptionHandler(AccessDeniedException.class)
    @ResponseStatus(HttpStatus.FORBIDDEN)
    public Map<String, String> handleForbidden(AccessDeniedException ex) {
        return Map.of("detail", "Access denied");
    }
}
```

The response format matches FastAPI's `{"detail": "..."}` so Postman tests
work the same way.

---

## Step 4.5 — Validation

Read: `docs/java/guide/12-validation.md`

Add `@Valid` to controller parameters and annotations to DTOs:

```java
public record NoteRequest(
    @NotBlank(message = "title cannot be blank") String title,
    @Size(max = 10000) String content
) {}

@PostMapping
public NoteResponse create(@Valid @RequestBody NoteRequest request) {
    ...
}
```

FastAPI equivalent:
```python
class NoteRequest(BaseModel):
    title: str = Field(min_length=1)
    content: str | None = Field(max_length=10000)
```

---

## Step 4.6 — All endpoints

Rebuild every endpoint from the FastAPI backend:

**Health:**
```
GET  /health                    → {"status":"ok"}
```

**Users:**
```
GET  /api/users/me              → current user info (from JWT sub)
```

**Notes:**
```
POST   /api/notes               → create note
GET    /api/notes               → list user's notes
GET    /api/notes/{id}          → get one note
PUT    /api/notes/{id}          → update note
DELETE /api/notes/{id}          → delete note
```

**Passwords:**
```
POST   /api/passwords           → create password (encrypted)
GET    /api/passwords           → list user's passwords
GET    /api/passwords/{id}      → get one (decrypted)
PUT    /api/passwords/{id}      → update
DELETE /api/passwords/{id}      → delete
```

---

## Phase 4 deliverable

All endpoints working with PostgreSQL. The same Postman collection used for
the Python backend passes against the Java backend (without auth for now —
that's Phase 5).

---

## Files in this phase

| File | Purpose |
|---|---|
| `docs/java/guide/11-exception-handling.md` | Global error handling |
| `docs/java/guide/12-validation.md` | Request validation |
| All entity, repository, service, controller, dto files | The full API |
| `vault-java/src/main/resources/db/migration/` | Flyway SQL migrations |
