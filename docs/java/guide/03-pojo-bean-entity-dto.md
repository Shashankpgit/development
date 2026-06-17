# POJO, Bean, Entity, DTO

## Why these words are confusing

All four are Java classes. The word used depends on the role the class plays —
not its syntax. The same class can be a POJO AND an Entity at the same time.
Knowing which word to use tells you and your teammates exactly how the class
is being used.

---

## POJO — Plain Old Java Object

A POJO is any Java class with:
- Private fields
- Public getters and setters
- A no-argument constructor (optional but common)
- No dependency on any framework

```java
public class Note {
    private Long id;
    private String title;
    private String content;

    // no-arg constructor
    public Note() {}

    // getters
    public Long getId() { return id; }
    public String getTitle() { return title; }
    public String getContent() { return content; }

    // setters
    public void setId(Long id) { this.id = id; }
    public void setTitle(String title) { this.title = title; }
    public void setContent(String content) { this.content = content; }
}
```

Python equivalent: a plain Python class with `__init__` and attributes.

```python
class Note:
    def __init__(self):
        self.id = None
        self.title = None
        self.content = None
```

The word "Plain Old" was coined to contrast with heavyweight EJB (Enterprise
JavaBeans) classes from the early 2000s that required extending framework
classes. POJOs are framework-free.

---

## Bean — a POJO managed by Spring

A Bean is a POJO that Spring creates, manages, and injects. You don't call
`new NoteService()` — Spring does it for you.

```java
@Service                          // ← this annotation makes it a Bean
public class NoteService {
    private final NoteRepository noteRepository;

    public NoteService(NoteRepository noteRepository) {
        this.noteRepository = noteRepository;
    }
}
```

Spring manages:
- **Creation** — Spring calls `new NoteService(noteRepository)` once at startup
- **Injection** — Spring passes the `NoteRepository` bean into the constructor
- **Lifecycle** — Spring destroys the bean when the app shuts down

Annotations that make a class a Bean:

| Annotation | Used for | Layer |
|---|---|---|
| `@Component` | Generic bean | Any |
| `@Service` | Business logic | Service layer |
| `@Repository` | Database access | Repository layer |
| `@Controller` / `@RestController` | HTTP endpoints | Controller layer |
| `@Configuration` | Config classes | Config layer |

Python FastAPI equivalent: FastAPI's dependency injection system.
```python
# FastAPI creates and injects get_db automatically
def get_notes(db: Session = Depends(get_db)):
    ...
```
Spring does this at the object level — entire service objects are injected,
not just function parameters.

---

## Entity — a POJO mapped to a database table

An Entity is a POJO annotated with `@Entity` that tells JPA (Hibernate) to
map it to a database table. It IS a POJO — just with JPA annotations added.

```java
@Entity                          // ← JPA: map this class to a table
@Table(name = "notes")           // ← JPA: the table is called "notes"
public class Note {

    @Id                          // ← JPA: this field is the primary key
    @GeneratedValue(strategy = GenerationType.IDENTITY)  // ← auto-increment
    private Long id;

    @Column(nullable = false)    // ← JPA: NOT NULL constraint
    private String title;

    private String content;      // ← no annotation = nullable column named "content"

    @ManyToOne                   // ← JPA: foreign key relationship
    @JoinColumn(name = "user_id")
    private User user;

    // getters, setters, constructors
}
```

Python SQLAlchemy equivalent:
```python
class Note(Base):
    __tablename__ = "notes"
    id      = Column(Integer, primary_key=True, autoincrement=True)
    title   = Column(String, nullable=False)
    content = Column(Text)
    user_id = Column(Integer, ForeignKey("users.id"))
```

Key JPA annotations:

| JPA annotation | SQLAlchemy equivalent | Meaning |
|---|---|---|
| `@Entity` | `class Note(Base)` | Map to a table |
| `@Table(name="notes")` | `__tablename__ = "notes"` | Table name |
| `@Id` | `primary_key=True` | Primary key |
| `@GeneratedValue` | `autoincrement=True` | Auto-generated value |
| `@Column(nullable=false)` | `nullable=False` | NOT NULL constraint |
| `@Column(name="created_at")` | `Column("created_at", ...)` | Custom column name |
| `@ManyToOne` | `ForeignKey(...)` | Many-to-one relationship |
| `@OneToMany` | `relationship(...)` | One-to-many relationship |

---

## DTO — Data Transfer Object

A DTO is a POJO that carries data between layers. It has NO framework
annotations — it's pure data.

**Why DTOs exist:**
Your `Note` entity has ALL the database fields including `user` (the full user
object), `createdAt`, etc. You don't want to expose all of that to the API
consumer. You also don't want the consumer to send an `id` when creating a note
(the DB generates it).

DTOs are the answer:

```java
// What the client sends when creating a note
// (no id, no user, no createdAt — client doesn't send those)
public record NoteRequest(
    String title,
    String content
) {}

// What the API returns
// (no user object — just userId, no internal DB fields)
public record NoteResponse(
    Long id,
    String title,
    String content,
    LocalDateTime createdAt
) {}
```

Python Pydantic equivalent:
```python
class NoteCreate(BaseModel):    # ≈ NoteRequest (what client sends)
    title: str
    content: str | None = None

class NoteResponse(BaseModel):  # ≈ NoteResponse (what API returns)
    id: int
    title: str
    content: str | None
    created_at: datetime
```

The flow:

```
Client → NoteRequest (DTO) → NoteService → Note (Entity) → database
database → Note (Entity) → NoteService → NoteResponse (DTO) → Client
```

The entity never leaves the service layer. The DTO never touches the database.

---

## Records — the modern way to write DTOs

Java 16 introduced `record` — a compact, immutable class. Perfect for DTOs.

```java
// Old way (verbose POJO DTO)
public class NoteResponse {
    private final Long id;
    private final String title;
    private final String content;
    private final LocalDateTime createdAt;

    public NoteResponse(Long id, String title, String content, LocalDateTime createdAt) {
        this.id = id;
        this.title = title;
        this.content = content;
        this.createdAt = createdAt;
    }

    public Long getId() { return id; }
    public String getTitle() { return title; }
    // ... more getters
}

// New way (record — same thing in 1 line)
public record NoteResponse(Long id, String title, String content, LocalDateTime createdAt) {}
```

Records automatically get:
- A constructor with all fields
- Getters (called `id()`, `title()` — no `get` prefix)
- `equals()`, `hashCode()`, `toString()`
- Immutability (fields are final)

We will use records for all DTOs in this project.

---

## Summary

```
POJO   = any plain Java class (no framework dependency)
Bean   = POJO that Spring manages and injects
Entity = POJO that JPA maps to a database table
DTO    = POJO that carries data between API and service layers

A class can be:
  - Just a POJO              (utility class, helper)
  - A POJO and a Bean        (NoteService — Spring manages it)
  - A POJO and an Entity     (Note — JPA maps it)
  - A POJO and a DTO         (NoteRequest, NoteResponse)
  - A POJO, Bean, and Entity (NoteService — Spring + JPA both apply)
```
