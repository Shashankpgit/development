# Phase 08 — Spring Web & REST
## "Controllers, DTOs, validation, and exception handling"

> You've seen the database layer (JPA) and the framework wiring (Spring Boot).
> This phase covers the HTTP layer — how requests come in, get validated,
> get processed, and how responses and errors go out.

---

## Part 1 — @RestController in Detail

```java
@RestController                   // = @Controller + @ResponseBody
@RequestMapping("/api/notes")     // base path for all methods in this class
public class NoteController {
    
    private final NoteService noteService;
    
    // Constructor injection — no @Autowired needed (single constructor)
    public NoteController(NoteService noteService) {
        this.noteService = noteService;
    }
}
```

### @Controller vs @RestController

```java
@Controller                    // returns a view name (for HTML pages, Thymeleaf templates)
public class WebController {
    @GetMapping("/home")
    public String home(Model model) {
        model.addAttribute("user", "Alice");
        return "home";            // looks for home.html template
    }
}

@RestController                // returns data (JSON/XML), not view names
public class ApiController {
    @GetMapping("/notes")
    public List<Note> notes() {
        return noteService.getAll();   // Jackson converts List<Note> → JSON automatically
    }
}
```

`@ResponseBody` (included in `@RestController`) tells Spring:  
*"Serialize the return value to the response body using a `HttpMessageConverter`."*  
Jackson is the default `HttpMessageConverter` for JSON.

---

## Part 2 — Mapping HTTP Methods

```java
@RestController
@RequestMapping("/api/notes")
public class NoteController {
    
    @GetMapping                     // GET /api/notes
    public List<NoteResponse> list() { ... }
    
    @GetMapping("/{id}")            // GET /api/notes/42
    public NoteResponse getById(@PathVariable Long id) { ... }
    
    @PostMapping                    // POST /api/notes
    @ResponseStatus(HttpStatus.CREATED)   // returns 201 instead of 200
    public NoteResponse create(@RequestBody NoteCreateRequest request) { ... }
    
    @PutMapping("/{id}")            // PUT /api/notes/42
    public NoteResponse update(
            @PathVariable Long id,
            @RequestBody NoteUpdateRequest request) { ... }
    
    @DeleteMapping("/{id}")         // DELETE /api/notes/42
    @ResponseStatus(HttpStatus.NO_CONTENT)  // returns 204
    public void delete(@PathVariable Long id) { ... }
}
```

### Method Parameter Annotations

```java
@GetMapping("/search")
public List<NoteResponse> search(
        @RequestParam String keyword,              // GET /search?keyword=hello
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "10") int size,
        @RequestHeader("X-Request-ID") String requestId,  // from HTTP header
        @CookieValue(required = false) String sessionId   // from cookie
) { ... }

@PostMapping
public NoteResponse create(
        @RequestBody @Valid NoteCreateRequest request   // JSON body → object + validate
) { ... }

@GetMapping("/{id}")
public NoteResponse get(
        @PathVariable Long id                          // /notes/42 → id=42
) { ... }
```

---

## Part 3 — DTOs (Data Transfer Objects)

### Why DTOs Exist

Your `@Entity` class represents the database table. It should NOT be your API response.

Problems with returning entities directly:
1. **Security**: entity might have fields you don't want to expose (`password`, `sub`)
2. **Coupling**: changing DB schema changes API response (breaking clients)
3. **Circular references**: `Note` has `User`, `User` has `List<Note>` → Jackson infinite loop
4. **Bidirectional control**: you might want different shapes for create vs update vs response

```
HTTP Layer           Service Layer        Database Layer
──────────────       ─────────────        ──────────────
NoteCreateRequest →  Note (entity)   →    notes table
NoteUpdateRequest →                  
                                     ←    notes table
NoteResponse      ←  Note (entity)
```

### Request DTO — what the client sends
```java
// Using Java Record (Java 16+) — immutable, auto-generates constructor + getters
public record NoteCreateRequest(
    @NotBlank(message = "Title is required")
    @Size(max = 255, message = "Title must be 255 characters or less")
    String title,
    
    String body   // nullable — optional field
) {}
```

### Response DTO — what the server returns
```java
public record NoteResponse(
    Long id,
    String title,
    String body,
    LocalDateTime createdAt,
    LocalDateTime updatedAt
) {}
```

### Mapping between Entity and DTO

```java
@Service
public class NoteService {
    
    public NoteResponse createNote(Long userId, NoteCreateRequest request) {
        Note note = new Note();
        note.setTitle(request.title());     // .title() = getter on record
        note.setBody(request.body());
        note.setUser(userRepository.getReferenceById(userId));
        
        Note saved = noteRepository.save(note);
        return toResponse(saved);           // convert entity → DTO
    }
    
    // Mapping method — entity → response DTO
    private NoteResponse toResponse(Note note) {
        return new NoteResponse(
            note.getId(),
            note.getTitle(),
            note.getBody(),
            note.getCreatedAt(),
            note.getUpdatedAt()
        );
    }
}
```

Python equivalent: Pydantic models for request/response + SQLAlchemy model for DB.  
Same separation, different syntax.

---

## Part 4 — Bean Validation (@Valid)

Spring Boot includes **Bean Validation** (Jakarta Bean Validation / Hibernate Validator).  
Add `@Valid` to a `@RequestBody` parameter → Spring validates before calling the method.  
Invalid request → automatic `400 Bad Request` with error details.

```java
// Validation annotations on the DTO:
public record NoteCreateRequest(

    @NotNull(message = "Title cannot be null")
    @NotBlank(message = "Title cannot be empty")
    @Size(min = 1, max = 255, message = "Title must be between 1 and 255 characters")
    String title,

    @Size(max = 10000, message = "Body is too long")
    String body
) {}
```

```java
// @Valid triggers validation before the method body runs
@PostMapping
public ResponseEntity<NoteResponse> create(@RequestBody @Valid NoteCreateRequest request) {
    // if validation fails, Spring returns 400 before this line runs
    NoteResponse response = noteService.createNote(userId, request);
    return ResponseEntity.status(201).body(response);
}
```

### Common validation annotations

| Annotation | What it validates |
|---|---|
| `@NotNull` | Value is not null |
| `@NotBlank` | String is not null, not empty, not just whitespace |
| `@NotEmpty` | Collection/String is not null and not empty |
| `@Size(min, max)` | String/Collection length within bounds |
| `@Min(value)` | Number >= value |
| `@Max(value)` | Number <= value |
| `@Email` | Valid email format |
| `@Pattern(regexp)` | Matches regex |
| `@Positive` | Number > 0 |
| `@PositiveOrZero` | Number >= 0 |
| `@Future` | Date/time is in the future |
| `@Past` | Date/time is in the past |

---

## Part 5 — ResponseEntity

`ResponseEntity<T>` gives you full control over the HTTP response.

```java
// Simple return — Spring uses 200 OK automatically
@GetMapping("/{id}")
public NoteResponse get(@PathVariable Long id) {
    return noteService.findById(id);   // 200 OK
}

// ResponseEntity — explicit control
@PostMapping
public ResponseEntity<NoteResponse> create(@RequestBody @Valid NoteCreateRequest req) {
    NoteResponse note = noteService.create(req);
    return ResponseEntity
        .status(HttpStatus.CREATED)          // 201
        .header("Location", "/api/notes/" + note.id())  // custom header
        .body(note);
}

// No body — 204 No Content
@DeleteMapping("/{id}")
public ResponseEntity<Void> delete(@PathVariable Long id) {
    noteService.delete(id);
    return ResponseEntity.noContent().build();   // 204
}

// Conditional response
@GetMapping("/{id}")
public ResponseEntity<NoteResponse> get(@PathVariable Long id) {
    return noteService.findById(id)
        .map(note -> ResponseEntity.ok(note))        // 200 if found
        .orElse(ResponseEntity.notFound().build());   // 404 if not found
}
```

---

## Part 6 — Global Exception Handling (@ControllerAdvice)

Every application needs consistent error responses.  
Without a global handler, exceptions become 500 errors with Java stack traces in the response.

### The Problem

```java
@GetMapping("/{id}")
public NoteResponse get(@PathVariable Long id) {
    return noteRepository.findById(id)
        .orElseThrow(() -> new RuntimeException("Note not found"));
    // Without a handler: HTTP 500, body contains stack trace — terrible!
}
```

### @ControllerAdvice — handles exceptions from ALL controllers

```java
@RestControllerAdvice   // applies to all @RestController classes
public class GlobalExceptionHandler {
    
    // Handle our custom not-found exception
    @ExceptionHandler(NoteNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNoteNotFound(NoteNotFoundException ex) {
        return ResponseEntity
            .status(HttpStatus.NOT_FOUND)    // 404
            .body(new ErrorResponse("not_found", ex.getMessage()));
    }
    
    // Handle validation failures (@Valid)
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationError(
            MethodArgumentNotValidException ex) {
        
        String message = ex.getBindingResult()
            .getFieldErrors()
            .stream()
            .map(error -> error.getField() + ": " + error.getDefaultMessage())
            .collect(Collectors.joining(", "));
        
        return ResponseEntity
            .status(HttpStatus.BAD_REQUEST)   // 400
            .body(new ErrorResponse("validation_error", message));
    }
    
    // Handle unauthorised access
    @ExceptionHandler(UnauthorizedException.class)
    public ResponseEntity<ErrorResponse> handleUnauthorized(UnauthorizedException ex) {
        return ResponseEntity
            .status(HttpStatus.UNAUTHORIZED)  // 401
            .body(new ErrorResponse("unauthorized", ex.getMessage()));
    }
    
    // Catch-all — don't leak stack traces to clients
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGeneric(Exception ex) {
        log.error("Unhandled exception", ex);  // log the full error internally
        return ResponseEntity
            .status(HttpStatus.INTERNAL_SERVER_ERROR)  // 500
            .body(new ErrorResponse("server_error", "An unexpected error occurred"));
    }
}
```

### Error Response DTO
```java
public record ErrorResponse(
    String code,      // machine-readable: "not_found", "validation_error"
    String message    // human-readable: "Note with id 42 not found"
) {}
```

### Custom Exceptions
```java
// A business exception
public class NoteNotFoundException extends RuntimeException {
    public NoteNotFoundException(Long id) {
        super("Note with id " + id + " not found");
    }
}

// Throw from service:
Note note = noteRepository.findByIdAndUserId(id, userId)
    .orElseThrow(() -> new NoteNotFoundException(id));
```

---

## Part 7 — JSON Customisation with Jackson

Spring Boot includes Jackson for JSON. You can control the output format.

### Naming conventions

Java uses camelCase. JSON APIs often use snake_case.

```java
// Option 1: @JsonProperty on individual fields
public record NoteResponse(
    Long id,
    String title,
    @JsonProperty("created_at")  LocalDateTime createdAt,
    @JsonProperty("updated_at")  LocalDateTime updatedAt
) {}

// Option 2: Global config in application.yml
// spring.jackson.property-naming-strategy: SNAKE_CASE
// Converts ALL camelCase fields to snake_case automatically
```

### Null handling
```java
// Don't include null fields in JSON output
@JsonInclude(JsonInclude.Include.NON_NULL)
public record NoteResponse(Long id, String title, String body) {}
// If body is null: {"id":1,"title":"My Note"} — body field omitted
```

### Date format
```yaml
# application.yml
spring:
  jackson:
    serialization:
      write-dates-as-timestamps: false    # "2024-01-15T10:30:00" not 1705310400
    time-zone: UTC
```

---

## Part 8 — Comparison with Python FastAPI

| Concept | Python FastAPI | Java Spring Boot |
|---|---|---|
| Route definition | `@router.get("/notes")` on function | `@GetMapping` on method in `@RestController` |
| Path variable | `def get(note_id: int)` | `@PathVariable Long id` |
| Query param | `def list(page: int = 0)` | `@RequestParam(defaultValue="0") int page` |
| Request body | `def create(note: NoteCreate)` | `@RequestBody NoteCreateRequest request` |
| Validation | Pydantic model validators | `@Valid` + Bean Validation annotations |
| Response model | `response_model=NoteResponse` | Method return type + `NoteResponse` record |
| 201 status | `status_code=201` | `@ResponseStatus(CREATED)` or `ResponseEntity.status(201)` |
| Error handling | `@app.exception_handler(...)` | `@ControllerAdvice` class |
| Dependency | `Depends(get_current_user)` | `@CurrentUser` annotation (Phase 09) |

The concepts are nearly identical. The syntax is different.

---

## Key Terms

| Term | Meaning |
|---|---|
| `@RestController` | `@Controller` + `@ResponseBody` — returns serialised data, not views |
| `@RequestMapping` | Maps URL patterns to a controller or method |
| `@PathVariable` | Binds `/notes/{id}` → method parameter |
| `@RequestParam` | Binds `?keyword=value` → method parameter |
| `@RequestBody` | Deserialises JSON request body → Java object |
| `@ResponseStatus` | Sets a default HTTP status code for the method |
| `ResponseEntity<T>` | Full control over status, headers, and body |
| DTO | Data Transfer Object — a class used only for request/response, not DB |
| Record | Java 16+ immutable data class (perfect for DTOs) |
| `@Valid` | Triggers Bean Validation on a method parameter |
| `@ControllerAdvice` | Global exception handler for all controllers |
| `@ExceptionHandler` | Handles a specific exception type in `@ControllerAdvice` |
| Jackson | The JSON library Spring Boot uses by default |
| `HttpMessageConverter` | Converts Java objects to HTTP response body (Jackson is one) |
