# Phase 3 — Data Layer

## Goal

Understand the full Java data stack from the ground up.
Learn JDBC (foundation) → JPA/Hibernate (ORM) → Spring Data JPA (what we use).
Each one explains why the next one exists.

---

## Why learn JDBC if we won't use it?

Same reason you need to understand HTTP even though FastAPI hides it from you.
When Spring Data JPA fails with a cryptic error, knowing what's happening at
the JDBC layer tells you exactly where the problem is.

One hour of JDBC gives you the mental model that makes JPA and Spring Data
instantly understandable.

---

## Step 3.1 — JDBC (the foundation)

Read: `docs/java/guide/07-jdbc.md`

JDBC = Java Database Connectivity. It is the raw Java API for talking to any
relational database. Every ORM (Hibernate, Spring Data, etc.) uses JDBC under
the hood.

```java
// JDBC — raw SQL, manual everything
Connection conn = DriverManager.getConnection(url, user, password);
PreparedStatement stmt = conn.prepareStatement("SELECT * FROM notes WHERE id = ?");
stmt.setLong(1, noteId);
ResultSet rs = stmt.executeQuery();

while (rs.next()) {
    Long id = rs.getLong("id");
    String title = rs.getString("title");
    // manually build your object
}
rs.close();
stmt.close();
conn.close();
```

Problems with JDBC:
- Massive boilerplate (open connection, prepare statement, iterate result set, close)
- Manual mapping from rows → objects
- SQL scattered across the codebase
- Error-prone (forget to close a connection → memory leak)

**Playground:** write one JDBC query against H2 (in-memory DB). Just once.
After you see how painful it is, you'll understand why JPA exists.

---

## Step 3.2 — JPA and Hibernate

Read: `docs/java/guide/08-jpa-and-hibernate.md`

**JPA** = Jakarta Persistence API. A specification (a set of interfaces and
annotations) that defines how Java objects map to database tables.

**Hibernate** = the most popular implementation of JPA. It's what actually
runs — JPA is the contract, Hibernate does the work.

Python equivalent: JPA ≈ the SQLAlchemy spec, Hibernate ≈ SQLAlchemy's engine.

```java
// JPA Entity — maps the class to the "notes" table
@Entity
@Table(name = "notes")
public class Note {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    private String content;

    @ManyToOne
    @JoinColumn(name = "user_id")
    private User user;

    // getters, setters (or use Lombok)
}
```

Python SQLAlchemy equivalent:
```python
class Note(Base):
    __tablename__ = "notes"
    id      = Column(Integer, primary_key=True)
    title   = Column(String, nullable=False)
    content = Column(Text)
    user_id = Column(Integer, ForeignKey("users.id"))
```

JPA annotations:

| JPA | SQLAlchemy | What it does |
|---|---|---|
| `@Entity` | `Base` subclass | Maps class to table |
| `@Table(name="notes")` | `__tablename__` | Sets table name |
| `@Id` | `primary_key=True` | Primary key |
| `@GeneratedValue` | `autoincrement=True` | Auto-increment |
| `@Column(nullable=false)` | `nullable=False` | Column constraint |
| `@ManyToOne` | `relationship()` | Foreign key relation |

---

## Step 3.3 — Lombok (reduce boilerplate)

Before Spring Data, learn Lombok — it eliminates getters/setters/constructors:

```java
// Without Lombok — 30+ lines of boilerplate
public class Note {
    private Long id;
    private String title;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    // constructor...
}

// With Lombok — 5 lines
@Data                    // generates all getters, setters, equals, hashCode, toString
@NoArgsConstructor       // generates no-arg constructor (required by JPA)
@AllArgsConstructor      // generates all-args constructor
@Entity
public class Note {
    @Id @GeneratedValue
    private Long id;
    private String title;
}
```

Lombok processes annotations at compile time — zero runtime overhead.

---

## Step 3.4 — Spring Data JPA (what we actually use)

Read: `docs/java/guide/09-spring-data-jpa.md`

Spring Data JPA sits on top of JPA/Hibernate. You define an interface — Spring
generates the implementation automatically at startup.

```java
// You write this interface (no implementation needed)
public interface NoteRepository extends JpaRepository<Note, Long> {

    // Spring generates: SELECT * FROM notes WHERE user_id = ?
    List<Note> findByUserId(Long userId);

    // Spring generates: SELECT * FROM notes WHERE user_id = ? AND id = ?
    Optional<Note> findByIdAndUserId(Long id, Long userId);

    // Spring generates: DELETE FROM notes WHERE user_id = ?
    void deleteByUserId(Long userId);
}
```

Python equivalent:
```python
# FastAPI — you write the query manually
def get_notes_by_user(db: Session, user_id: int):
    return db.query(Note).filter(Note.user_id == user_id).all()
```

Spring Data generates the SQL from the method name. The naming convention:
- `findBy` → SELECT WHERE
- `deleteBy` → DELETE WHERE
- `countBy` → SELECT COUNT WHERE
- `And` / `Or` → combine conditions

For complex queries use `@Query`:
```java
@Query("SELECT n FROM Note n WHERE n.user.id = :userId ORDER BY n.createdAt DESC")
List<Note> findRecentByUser(@Param("userId") Long userId);
```

---

## Step 3.5 — H2 for development

H2 is an in-memory database — starts with the app, gone when the app stops.
Perfect for learning because no Docker setup needed.

```xml
<!-- pom.xml -->
<dependency>
    <groupId>com.h2database</groupId>
    <artifactId>h2</artifactId>
    <scope>runtime</scope>
</dependency>
```

```properties
# application.properties
spring.datasource.url=jdbc:h2:mem:vaultdb
spring.jpa.hibernate.ddl-auto=create-drop
spring.h2.console.enabled=true
```

`ddl-auto=create-drop` — Hibernate creates tables when the app starts and
drops them when it stops. For dev only — never use in production.

Visit `http://localhost:8080/h2-console` to browse the in-memory database.

---

## Step 3.6 — Flyway migrations (production)

Read: `docs/java/guide/10-flyway-migrations.md`

When switching to PostgreSQL, we stop using `ddl-auto` and use Flyway instead.
Flyway ≈ Alembic in Python.

```
src/main/resources/db/migration/
├── V1__create_users_table.sql
├── V2__create_notes_table.sql
└── V3__create_passwords_table.sql
```

Flyway runs these in order at startup. Once run, they are never re-run.
Add a new migration to add a column — never modify an existing migration.

---

## Phase 3 deliverable

`NoteController` with full CRUD connected to H2 via Spring Data JPA:

```
POST   /api/notes          → create a note
GET    /api/notes          → list all notes
GET    /api/notes/{id}     → get one note
PUT    /api/notes/{id}     → update a note
DELETE /api/notes/{id}     → delete a note
```

All tested in Postman. H2 console shows the data persisting within a session.

---

## Files in this phase

| File | Purpose |
|---|---|
| `docs/java/guide/07-jdbc.md` | JDBC foundation |
| `docs/java/guide/08-jpa-and-hibernate.md` | JPA + Hibernate deep dive |
| `docs/java/guide/09-spring-data-jpa.md` | Spring Data JPA |
| `docs/java/guide/10-flyway-migrations.md` | DB migrations |
| `vault-java/src/main/java/com/vault/entity/Note.java` | Note entity |
| `vault-java/src/main/java/com/vault/repository/NoteRepository.java` | Note repository |
| `vault-java/src/main/java/com/vault/service/NoteService.java` | Note service |
| `vault-java/src/main/java/com/vault/controller/NoteController.java` | Note endpoints |
| `vault-java/src/main/java/com/vault/dto/NoteRequest.java` | Request DTO |
| `vault-java/src/main/java/com/vault/dto/NoteResponse.java` | Response DTO |
