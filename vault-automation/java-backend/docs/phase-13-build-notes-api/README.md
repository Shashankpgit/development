# Phase 13 — Build: Notes API
## "Full CRUD with entity, service, controller, DTOs, validation"

> Goal: GET/POST/PUT/DELETE /api/notes — functionally identical to the Python API.
> Concepts applied: @Entity relationships, @Valid, ResponseEntity, @ControllerAdvice.

---

## What Gets Built

```
db/migration/
  V2__create_notes_table.sql

com/vaultapp/notes/
  Note.java                  ← @Entity
  NoteRepository.java        ← JpaRepository
  NoteService.java           ← @Service
  NoteController.java        ← @RestController
  NoteCreateRequest.java     ← DTO (record)
  NoteUpdateRequest.java     ← DTO (record)
  NoteResponse.java          ← DTO (record)
  NoteNotFoundException.java ← custom exception
```

---

## Migration: V2__create_notes_table.sql

```sql
CREATE TABLE notes (
    id         BIGSERIAL    PRIMARY KEY,
    title      VARCHAR(255) NOT NULL,
    body       TEXT,
    user_id    BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notes_user_id ON notes(user_id);
```

---

## Note Entity

```java
@Entity
@Table(name = "notes")
public class Note {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false, length = 255)
    private String title;
    
    @Column(columnDefinition = "TEXT")
    private String body;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
    
    protected Note() {}
    
    public Note(String title, String body, User user) {
        this.title = title;
        this.body = body;
        this.user = user;
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }
    
    // Getters + update method
    public void update(String title, String body) {
        if (title != null) this.title = title;
        if (body != null) this.body = body;
        this.updatedAt = LocalDateTime.now();
    }
}
```

---

## DTOs

```java
// Request DTOs
public record NoteCreateRequest(
    @NotBlank String title,
    String body
) {}

public record NoteUpdateRequest(
    @Size(min = 1, max = 255) String title,  // nullable — partial update
    String body
) {}

// Response DTO
public record NoteResponse(
    Long id,
    String title,
    String body,
    LocalDateTime createdAt,
    LocalDateTime updatedAt
) {}
```

---

## NoteRepository

```java
public interface NoteRepository extends JpaRepository<Note, Long> {
    List<Note> findByUserIdOrderByCreatedAtDesc(Long userId);
    Optional<Note> findByIdAndUserId(Long id, Long userId);  // ownership check
    void deleteByIdAndUserId(Long id, Long userId);
}
```

---

## NoteService

```java
@Service
@Transactional(readOnly = true)    // default for all methods — override for writes
public class NoteService {
    
    private final NoteRepository noteRepository;
    private final UserRepository userRepository;
    
    public NoteService(NoteRepository noteRepository, UserRepository userRepository) {
        this.noteRepository = noteRepository;
        this.userRepository = userRepository;
    }
    
    public List<NoteResponse> getNotesForUser(Long userId) {
        return noteRepository.findByUserIdOrderByCreatedAtDesc(userId)
            .stream()
            .map(this::toResponse)
            .collect(Collectors.toList());
    }
    
    @Transactional    // override: this is a write
    public NoteResponse createNote(Long userId, NoteCreateRequest request) {
        User user = userRepository.getReferenceById(userId);
        Note note = new Note(request.title(), request.body(), user);
        return toResponse(noteRepository.save(note));
    }
    
    @Transactional
    public NoteResponse updateNote(Long id, Long userId, NoteUpdateRequest request) {
        Note note = noteRepository.findByIdAndUserId(id, userId)
            .orElseThrow(() -> new NoteNotFoundException(id));
        note.update(request.title(), request.body());
        return toResponse(note);   // no explicit save — dirty checking handles UPDATE
    }
    
    @Transactional
    public void deleteNote(Long id, Long userId) {
        if (!noteRepository.existsByIdAndUserId(id, userId)) {
            throw new NoteNotFoundException(id);
        }
        noteRepository.deleteByIdAndUserId(id, userId);
    }
    
    private NoteResponse toResponse(Note note) {
        return new NoteResponse(
            note.getId(), note.getTitle(), note.getBody(),
            note.getCreatedAt(), note.getUpdatedAt()
        );
    }
}
```

---

## NoteController

```java
@RestController
@RequestMapping("/api/notes")
public class NoteController {
    
    private final NoteService noteService;
    
    public NoteController(NoteService noteService) {
        this.noteService = noteService;
    }
    
    @GetMapping
    public List<NoteResponse> list(@CurrentUser User user) {
        return noteService.getNotesForUser(user.getId());
    }
    
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public NoteResponse create(
            @RequestBody @Valid NoteCreateRequest request,
            @CurrentUser User user) {
        return noteService.createNote(user.getId(), request);
    }
    
    @PutMapping("/{id}")
    public NoteResponse update(
            @PathVariable Long id,
            @RequestBody @Valid NoteUpdateRequest request,
            @CurrentUser User user) {
        return noteService.updateNote(id, user.getId(), request);
    }
    
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id, @CurrentUser User user) {
        noteService.deleteNote(id, user.getId());
    }
}
```

---

## GlobalExceptionHandler additions

```java
@ExceptionHandler(NoteNotFoundException.class)
public ResponseEntity<ErrorResponse> noteNotFound(NoteNotFoundException ex) {
    return ResponseEntity.status(404)
        .body(new ErrorResponse("not_found", ex.getMessage()));
}
```

---

## Deliverable

```bash
TOKEN="paste-your-jwt-here"

curl -H "Authorization: Bearer $TOKEN" localhost:8000/api/notes
# []

curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"title":"First note","body":"Hello Java!"}' \
     localhost:8000/api/notes
# {"id":1,"title":"First note","body":"Hello Java!","createdAt":"...","updatedAt":"..."}

curl -H "Authorization: Bearer $TOKEN" localhost:8000/api/notes
# [{"id":1,"title":"First note",...}]
```
