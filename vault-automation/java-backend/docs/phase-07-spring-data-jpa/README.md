# Phase 07 — Spring Data JPA
## "How does Spring Data build on Hibernate? What is the Repository pattern?"

> Spring Data JPA is the final step in the evolution:
> JDBC (write everything) → Hibernate (write mappings, no SQL for CRUD)
> → Spring Data JPA (write almost nothing).

---

## The Evolution Recap

```
JDBC
  You write:  SQL + ResultSet mapping + connection management + transaction code
  Result:     Correct but 40 lines per operation

Hibernate
  You write:  @Entity mappings + SessionFactory config + Session management
  Result:     Auto-generates CRUD SQL, but you still manage sessions

Spring Data JPA
  You write:  @Entity mappings + one interface declaration
  Result:     Spring generates the implementation, sessions, transactions
```

---

## Part 1 — The Repository Pattern

Before Spring Data, there was a design pattern called the **Repository**.

The idea: separate the "how to talk to the database" from "what the business logic does".

```
Business Logic (NoteService)
        │
        │  "I need notes for user 42"
        ▼
  Repository Interface
  (NoteRepository)
        │
        │  "OK, let me fetch them"
        ▼
   Implementation
   (JDBC / Hibernate / etc.)
        │
        ▼
   Database
```

The service doesn't know or care HOW data is fetched. It just calls the repository.  
This makes it easy to swap implementations (e.g., for testing).

```java
// The interface — defines WHAT the repository can do
public interface NoteRepository {
    List<Note> findByUserId(Long userId);
    Optional<Note> findById(Long id);
    Note save(Note note);
    void deleteById(Long id);
}

// One implementation (JDBC)
public class NoteJdbcRepository implements NoteRepository { ... }

// Another implementation (Hibernate)
public class NoteHibernateRepository implements NoteRepository { ... }

// A mock for testing
public class NoteMockRepository implements NoteRepository { ... }
```

With constructor injection, `NoteService` depends on the **interface**, not an implementation:
```java
@Service
public class NoteService {
    private final NoteRepository noteRepository;  // interface — Spring injects the impl
    
    public NoteService(NoteRepository noteRepository) {
        this.noteRepository = noteRepository;
    }
}
```

---

## Part 2 — Spring Data JPA: Repositories Without Implementation

Spring Data JPA takes the repository pattern and says:  
*"What if you only had to declare the interface, and Spring would write the implementation?"*

```java
// You write ONLY this — no implementation class
public interface NoteRepository extends JpaRepository<Note, Long> {
    List<Note> findByUserId(Long userId);     // Spring generates this query
    Optional<Note> findByIdAndUserId(Long id, Long userId);
}
```

Spring Data JPA:
1. Sees `NoteRepository extends JpaRepository<Note, Long>`
2. Creates an implementation class at startup
3. The implementation uses Hibernate under the hood
4. Registers it as a Spring bean so it can be injected

At runtime, when you inject `NoteRepository`, you get Spring's generated implementation —  
a class you never see and never need to write.

---

## Part 3 — JpaRepository: Free Methods

`JpaRepository<Entity, ID>` gives you these methods for free:

```java
// From CrudRepository (parent of JpaRepository):
noteRepository.save(note);               // INSERT or UPDATE (upsert)
noteRepository.findById(id);             // SELECT by PK → Optional<Note>
noteRepository.findAll();                // SELECT * (use carefully — loads everything)
noteRepository.deleteById(id);           // DELETE by PK
noteRepository.count();                  // SELECT COUNT(*)
noteRepository.existsById(id);           // SELECT 1 WHERE id = ?

// From JpaRepository (adds batch ops + sorting):
noteRepository.findAll(Sort.by("createdAt").descending());
noteRepository.findAll(PageRequest.of(0, 10));  // first 10 results (pagination)
noteRepository.saveAll(List.of(note1, note2));  // bulk save
noteRepository.flush();                  // force pending changes to DB
```

None of this required a single line of implementation code from you.

---

## Part 4 — Query Derivation: Method Name → SQL

Spring Data JPA reads your method names and **generates JPQL queries automatically**.

```java
public interface NoteRepository extends JpaRepository<Note, Long> {
    
    // Spring generates: SELECT n FROM Note n WHERE n.userId = :userId
    List<Note> findByUserId(Long userId);
    
    // Spring generates: SELECT n FROM Note n WHERE n.userId = :userId AND n.id = :id
    Optional<Note> findByIdAndUserId(Long id, Long userId);
    
    // Spring generates: SELECT COUNT(n) FROM Note n WHERE n.userId = :userId
    long countByUserId(Long userId);
    
    // Spring generates: DELETE FROM Note n WHERE n.userId = :userId
    void deleteByUserId(Long userId);
    
    // Spring generates: SELECT n FROM Note n WHERE n.title LIKE :title%
    List<Note> findByTitleStartingWith(String prefix);
    
    // Spring generates: ... ORDER BY createdAt DESC
    List<Note> findByUserIdOrderByCreatedAtDesc(Long userId);
}
```

### Method name keywords

| Keyword | Generated SQL fragment |
|---|---|
| `findBy` | `SELECT ... WHERE` |
| `And` | `AND` |
| `Or` | `OR` |
| `Not` | `NOT` |
| `GreaterThan` | `> ?` |
| `LessThan` | `< ?` |
| `Between` | `BETWEEN ? AND ?` |
| `Like` | `LIKE ?` |
| `StartingWith` | `LIKE ?%` |
| `EndingWith` | `LIKE %?` |
| `Containing` | `LIKE %?%` |
| `IsNull` | `IS NULL` |
| `OrderBy...Asc` | `ORDER BY ... ASC` |
| `OrderBy...Desc` | `ORDER BY ... DESC` |

---

## Part 5 — @Query: When Method Names Aren't Enough

For complex queries, use `@Query` with JPQL or native SQL:

```java
public interface NoteRepository extends JpaRepository<Note, Long> {
    
    // JPQL — queries entity classes, not table names
    @Query("SELECT n FROM Note n WHERE n.user.id = :userId AND n.title LIKE %:keyword%")
    List<Note> searchNotes(@Param("userId") Long userId, @Param("keyword") String keyword);
    
    // Native SQL — when you need DB-specific features
    @Query(value = "SELECT * FROM notes WHERE user_id = ? ORDER BY created_at DESC LIMIT ?",
           nativeQuery = true)
    List<Note> findRecentNotes(Long userId, int limit);
    
    // Modifying query — must annotate
    @Modifying
    @Transactional
    @Query("UPDATE Note n SET n.title = :title WHERE n.id = :id AND n.user.id = :userId")
    int updateTitle(@Param("id") Long id, @Param("userId") Long userId, @Param("title") String title);
}
```

JPQL vs SQL:
```
JPQL:  SELECT n FROM Note n WHERE n.user.id = :userId
SQL:   SELECT * FROM notes WHERE user_id = ?

JPQL uses class names (Note), field names (user.id), named params (:userId)
SQL uses table names (notes), column names (user_id), positional params (?)
```

---

## Part 6 — @Entity Mapping in Depth

### Basic Entity
```java
@Entity
@Table(name = "notes")
public class Note {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)  // SERIAL / BIGSERIAL in PostgreSQL
    private Long id;
    
    @Column(name = "title", nullable = false, length = 255)
    private String title;
    
    @Column(columnDefinition = "TEXT")  // TEXT type, not VARCHAR
    private String body;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
    
    @PrePersist                          // called before INSERT
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }
    
    @PreUpdate                           // called before UPDATE
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
    
    // getters and setters
}
```

### Relationship Mapping
```java
@Entity
@Table(name = "notes")
public class Note {
    
    // ...
    
    @ManyToOne(fetch = FetchType.LAZY)          // many notes → one user
    @JoinColumn(name = "user_id", nullable = false)  // FK column in notes table
    private User user;
}

@Entity
@Table(name = "users")
public class User {
    
    // ...
    
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    // "user" = the field name in Note that owns this relationship
    // cascade ALL = save/delete User cascades to its Notes
    // orphanRemoval = delete Note when removed from user.notes list
    private List<Note> notes = new ArrayList<>();
}
```

### GenerationType Strategies

```java
@GeneratedValue(strategy = GenerationType.IDENTITY)
// PostgreSQL SERIAL/BIGSERIAL — DB auto-increments
// Most commonly used — simple, efficient

@GeneratedValue(strategy = GenerationType.SEQUENCE)
// Uses a DB sequence — better for batching, supports allocationSize
// Hibernate's preferred strategy for PostgreSQL

@GeneratedValue(strategy = GenerationType.UUID)  // Java 17+
// Generates a UUID — good for distributed systems
// No coordination between servers needed
```

---

## Part 7 — Transactions in Spring Data JPA

`@Transactional` is handled by Spring AOP (Phase 05).

```java
@Service
public class NoteService {
    
    private final NoteRepository noteRepository;
    
    // read-only transaction — more efficient (no dirty checking, can use read replicas)
    @Transactional(readOnly = true)
    public List<Note> getNotesForUser(Long userId) {
        return noteRepository.findByUserId(userId);
    }
    
    // write transaction — default (readOnly = false)
    @Transactional
    public Note createNote(Long userId, String title, String body) {
        Note note = new Note();
        note.setTitle(title);
        note.setBody(body);
        note.setUser(userRepository.getReferenceById(userId));
        return noteRepository.save(note);
    }
    
    @Transactional
    public void deleteNote(Long id, Long userId) {
        Note note = noteRepository.findByIdAndUserId(id, userId)
            .orElseThrow(() -> new RuntimeException("Note not found"));
        noteRepository.delete(note);
    }
}
```

### Transaction propagation

What happens when a `@Transactional` method calls another `@Transactional` method?

```java
@Transactional                      // starts transaction A
public void methodA() {
    save(entity1);                  // within transaction A
    methodB();                      // what happens here?
}

@Transactional(propagation = Propagation.REQUIRED)   // default
public void methodB() {
    // REQUIRED: join existing transaction A
    // No new transaction — uses A's transaction
    save(entity2);                  // within transaction A
}

@Transactional(propagation = Propagation.REQUIRES_NEW)
public void methodC() {
    // REQUIRES_NEW: suspend A, start new transaction B
    save(entity3);                  // within transaction B
    // if methodA fails after this, entity3 is still committed
}
```

The default (`REQUIRED`) is almost always what you want.

---

## Part 8 — N+1 Solution in Spring Data JPA

From Phase 03, N+1 queries are a common performance issue. Spring Data JPA solutions:

### @EntityGraph
```java
@EntityGraph(attributePaths = {"user"})    // load user in the same query
List<Note> findByUserId(Long userId);
```
Generates: `SELECT n.*, u.* FROM notes n JOIN users u ON n.user_id = u.id WHERE n.user_id = ?`

### @Query with JOIN FETCH
```java
@Query("SELECT n FROM Note n JOIN FETCH n.user WHERE n.user.id = :userId")
List<Note> findByUserIdWithUser(@Param("userId") Long userId);
```

### When do you need it?
Only when you're accessing a lazy-loaded association in your response DTOs.  
For our API, we usually only return note fields (not user fields), so N+1 is not a concern.

---

## Part 9 — Flyway: Database Migrations

### Why Not `ddl-auto: create` or `update`?

```yaml
# DO NOT use in production:
spring.jpa.hibernate.ddl-auto: create   # drops + recreates tables on startup
spring.jpa.hibernate.ddl-auto: update   # tries to ALTER tables (often wrong)
```

Problems with `create`:
- Destroys all data on every startup
- Not suitable for production

Problems with `update`:
- Cannot rename columns (creates new + orphans old)
- Cannot modify column types safely
- No rollback — can't undo a bad migration

### Flyway — Versioned SQL Migrations

```
src/main/resources/db/migration/
  V1__create_users_table.sql
  V2__create_notes_table.sql
  V3__create_password_entries_table.sql
  V4__add_updated_at_to_notes.sql
```

Each file runs exactly ONCE, in order, and is tracked in `flyway_schema_history` table.  
Flyway checks this table on startup and only runs files it hasn't run before.

```sql
-- V1__create_users_table.sql
CREATE TABLE users (
    id     BIGSERIAL PRIMARY KEY,
    sub    VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

```sql
-- V4__add_updated_at_to_notes.sql
ALTER TABLE notes ADD COLUMN updated_at TIMESTAMP;
UPDATE notes SET updated_at = created_at;
ALTER TABLE notes ALTER COLUMN updated_at SET NOT NULL;
```

This is a proper, reversible, trackable migration.

Compare with SQLAlchemy's `create_all()` in the Python FastAPI project:
```python
# Python — convenient for development, not suitable for production
Base.metadata.create_all(bind=engine)
```
For our Java project, we'll use Flyway from day one — this is the production approach.

---

## Key Terms

| Term | Meaning |
|---|---|
| Repository Pattern | Design pattern separating data access from business logic |
| JpaRepository | Spring Data interface — extend it to get free CRUD methods |
| Query Derivation | Spring generates JPQL from method names like `findByUserId` |
| @Query | Annotation to declare custom JPQL or native SQL |
| @Entity | Marks a Java class as a JPA entity (maps to a table) |
| @ManyToOne | Relationship: many entities belong to one parent |
| @OneToMany | Relationship: one entity has many children |
| FetchType.LAZY | Load related entity only when accessed (preferred) |
| FetchType.EAGER | Load related entity immediately with parent |
| @Transactional | Wraps method in a DB transaction (via Spring AOP) |
| Propagation | What happens when a transactional method calls another |
| @EntityGraph | Solves N+1 by specifying associations to load eagerly per query |
| Flyway | Database migration tool — runs versioned SQL files once each |
| ddl-auto | Hibernate setting for schema creation (validate = safe for prod) |
