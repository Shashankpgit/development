# Phase 03 — Hibernate ORM
## "How did Hibernate solve JDBC's problems? What is JPA?"

> Hibernate was created in 2001 by Gavin King because he was fed up writing JDBC boilerplate.
> It became so popular that Sun Microsystems standardised its ideas as JPA.
> Understanding Hibernate = understanding what Spring Data JPA does invisibly.

---

## The Problem Hibernate Was Solving

Looking at JDBC from Phase 02, the core pain was **Object-Relational Impedance Mismatch**:

```
Java world (Objects)              Database world (Tables)
─────────────────────             ───────────────────────
Note object                       notes table
  ├── id: Long                      id: BIGINT
  ├── title: String                 title: VARCHAR
  ├── body: String                  body: TEXT
  ├── user: User (object ref)       user_id: BIGINT (FK)    ← mismatch!
  └── createdAt: LocalDateTime      created_at: TIMESTAMP
```

Java thinks in **objects with references**.  
Databases think in **rows with foreign keys**.  
JDBC forced you to manually bridge this gap for every query.

Hibernate's answer: **let me map objects to tables, and I'll write the SQL for you.**

---

## Core Hibernate Concepts

### 1. Entity — A Java class that maps to a table

Before Hibernate, this mapping was in XML files (`hibernate.cfg.xml`).  
Modern Hibernate uses annotations — and this is what you'll use in Spring Boot.

```java
import jakarta.persistence.*;  // JPA annotations (standardised from Hibernate)
import java.time.LocalDateTime;

@Entity                        // "this class maps to a database table"
@Table(name = "notes")         // "the table is called 'notes'"
public class Note {

    @Id                                    // "this field is the primary key"
    @GeneratedValue(strategy = GenerationType.IDENTITY)  // "let DB auto-increment"
    private Long id;

    @Column(nullable = false)              // "NOT NULL constraint"
    private String title;

    @Column(columnDefinition = "TEXT")     // "use TEXT column type"
    private String body;

    @ManyToOne(fetch = FetchType.LAZY)     // "many notes → one user"
    @JoinColumn(name = "user_id", nullable = false)  // "FK column name"
    private User user;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    // Constructors, getters, setters (or use Lombok / Records later)
}
```

Compare to SQLAlchemy (Python):
```python
class Note(Base):
    __tablename__ = "notes"
    id         = Column(Integer, primary_key=True)
    title      = Column(String, nullable=False)
    body       = Column(Text)
    user_id    = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)
    user       = relationship("User")
```
Same concept, different syntax.

---

### 2. SessionFactory and Session

`SessionFactory` = one per application, expensive to create, builds the entire mapping.  
`Session` = one per request/transaction, the "unit of work".

```
Application Startup:
  SessionFactory created (reads all @Entity classes, validates mappings)

Per Request:
  Session opened  ← unit of work begins
     │
     ├── load entity:  session.get(Note.class, id)
     ├── save entity:  session.save(note)
     ├── update entity: session.update(note)
     └── delete entity: session.delete(note)
     │
  Transaction committed / rolled back
  Session closed
```

In Spring Boot, you never manage `Session` directly.  
Spring creates and closes Sessions for you, tied to `@Transactional`.

---

### 3. How Hibernate Generates SQL

This is the key: you work with **Java objects**, Hibernate generates **SQL**.

```java
// You write:
session.save(note);

// Hibernate generates and executes:
// INSERT INTO notes (title, body, user_id, created_at)
// VALUES ('My Title', 'My Body', 42, '2024-01-01 12:00:00')
```

```java
// You write:
Note note = session.get(Note.class, 1L);

// Hibernate generates:
// SELECT id, title, body, user_id, created_at
// FROM notes WHERE id = 1
```

```java
// You modify the object (inside a transaction):
note.setTitle("Updated Title");
// (no explicit save call needed)

// Hibernate detects the change and generates:
// UPDATE notes SET title = 'Updated Title' WHERE id = 1
```

That last example — **automatic dirty checking** — is unique to Hibernate.  
It tracks every object loaded in a session and automatically generates UPDATE statements  
for objects that changed. No explicit `save()` call needed.

---

### 4. The Persistence Context — Hibernate's First-Level Cache

Every `Session` maintains a "persistence context" — a map of loaded entities.

```
Session (one per request/transaction)
  └── Persistence Context (first-level cache)
        ├── Note{id=1} → reference to the Note object you loaded
        ├── Note{id=2} → reference to another Note you loaded
        └── User{id=5} → reference to the User you loaded
```

```java
Note note1 = session.get(Note.class, 1L);  // SELECT from DB
Note note2 = session.get(Note.class, 1L);  // Returns CACHED object, NO second SELECT
// note1 == note2 → same object reference
```

This means within a single transaction, loading the same entity twice is free.  
But it also means you must understand **when the session ends** to avoid stale data.

---

### 5. Lazy vs Eager Loading — A Critical Concept

When you load a `Note`, should Hibernate also load the associated `User`?

```java
@ManyToOne(fetch = FetchType.EAGER)  // Always load User when loading Note
private User user;
// SELECT * FROM notes WHERE id = ?
// SELECT * FROM users WHERE id = ?   ← extra query, always

@ManyToOne(fetch = FetchType.LAZY)   // Load User only if you access it
private User user;
// SELECT * FROM notes WHERE id = ?   ← just this
// note.getUser().getName()           ← THIS triggers: SELECT * FROM users WHERE id = ?
```

**LAZY is almost always correct**. Load only what you need.  
EAGER causes unnecessary data to load — even when you don't use it.

### The LazyInitializationException

This is the most common Hibernate mistake for beginners:

```java
Session session = sessionFactory.openSession();
Note note = session.get(Note.class, 1L);
session.close();                    // session is closed

note.getUser().getName();           // LazyInitializationException!
// Session is closed — Hibernate can't load the User anymore
```

Spring Boot solves this by keeping the session open for the duration of a web request  
(Open Session in View pattern — though this has its own debate).  
Later, you'll learn to load what you need with JPQL JOIN FETCH.

---

## 6. The N+1 Query Problem

This is one of the most important performance concepts in any ORM.

**Scenario**: Load 10 notes and display each note's author name.

```java
// Naive approach
List<Note> notes = session.createQuery("FROM Note", Note.class).list();
// SQL: SELECT * FROM notes   (1 query)

for (Note note : notes) {
    String authorName = note.getUser().getName();  // lazy-load for each note
    // SQL: SELECT * FROM users WHERE id = ?       (N queries, one per note)
}
// Total: 1 + N queries
```

With 100 notes = 101 queries. With 1000 notes = 1001 queries.  
The database makes 1001 round trips instead of 1.

**The fix: JOIN FETCH**
```java
// JPQL (Hibernate Query Language — HQL) — queries objects, not tables
List<Note> notes = session.createQuery(
    "SELECT n FROM Note n JOIN FETCH n.user",   // load User in the SAME query
    Note.class
).list();
// SQL: SELECT n.*, u.* FROM notes n JOIN users u ON n.user_id = u.id
// (1 query, not N+1)
```

Spring Data JPA gives you `@EntityGraph` and `@Query` for this. You'll use it.

---

## 7. HQL / JPQL — Object-Oriented Queries

Hibernate has its own query language. Instead of querying **tables and columns**,  
you query **classes and fields**.

```sql
-- SQL (table-centric)
SELECT n.id, n.title, n.body FROM notes n WHERE n.user_id = 42;
```

```java
// HQL/JPQL (object-centric)
List<Note> notes = session.createQuery(
    "FROM Note n WHERE n.user.id = :userId",
    Note.class
)
.setParameter("userId", 42L)
.list();
```

- `Note` = the Java class name (capital N)
- `n.user.id` = navigate the relationship (`user` field on `Note`, then `id` on `User`)
- `:userId` = named parameter (prevents SQL injection)

JPA standardised this as JPQL (Java Persistence Query Language).  
Spring Data JPA lets you use `@Query("JPQL here")` in repositories.

---

## 8. JPA — The Standard That Came From Hibernate

Hibernate was so successful that Sun Microsystems (now Oracle) said:  
*"We should standardise this so any ORM can be swapped."*

**JPA (Java Persistence API)** — released 2006:
- A **specification** (a set of interfaces and annotations)
- Not an implementation — just the contracts
- Hibernate implements JPA (and adds extras beyond the spec)
- EclipseLink, OpenJPA are other JPA implementations

```
JPA (the standard)
  ├── @Entity
  ├── @Table
  ├── @Id
  ├── @OneToMany, @ManyToOne
  ├── EntityManager (JPA's Session equivalent)
  └── JPQL

Hibernate (implements JPA + adds extras)
  ├── Implements all of the above
  ├── Adds @Type, @Formula, @BatchSize (Hibernate-specific)
  └── Session (Hibernate-specific, wraps EntityManager)
```

**What you should use**: JPA annotations (`jakarta.persistence.*`).  
Not Hibernate-specific annotations — unless you need a feature JPA doesn't have.  
This way you could theoretically swap Hibernate for EclipseLink (you won't, but you could).

In Spring Boot, you always use `EntityManager` or `JpaRepository` (not Hibernate's `Session`).

---

## 9. The Old Way vs The New Way

Seeing the evolution makes you appreciate Spring Boot's auto-configuration.

### Old way (before Spring, raw Hibernate):
```xml
<!-- hibernate.cfg.xml — 40+ lines of XML configuration -->
<hibernate-configuration>
    <session-factory>
        <property name="connection.url">jdbc:postgresql://localhost/vault</property>
        <property name="connection.driver_class">org.postgresql.Driver</property>
        <property name="dialect">org.hibernate.dialect.PostgreSQLDialect</property>
        <property name="connection.username">vault</property>
        <property name="connection.password">secret</property>
        <mapping class="com.vaultapp.Note"/>
        <mapping class="com.vaultapp.User"/>
        <!-- ... -->
    </session-factory>
</hibernate-configuration>
```

```java
// Bootstrapping — just to create a SessionFactory:
Configuration configuration = new Configuration().configure("hibernate.cfg.xml");
SessionFactory sessionFactory = configuration.buildSessionFactory();

// Now use it:
Session session = sessionFactory.openSession();
Transaction tx = session.beginTransaction();
session.save(note);
tx.commit();
session.close();
```

### Spring Boot way:
```yaml
# application.yml — 4 lines
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/vault
    username: vault
    password: secret
```
```java
// Your repository:
public interface NoteRepository extends JpaRepository<Note, Long> {
    List<Note> findByUserId(Long userId);   // Spring generates the query
}

// Your service:
noteRepository.save(note);      // Spring manages session + transaction
noteRepository.findByUserId(5); // Spring generates SELECT
```

Spring Boot reads `application.yml`, auto-configures Hibernate, creates the `SessionFactory` (internally called `EntityManagerFactory`), manages sessions per request, and configures `@Transactional`. You configure nothing.

---

## Key Terms

| Term | Meaning |
|---|---|
| ORM | Object-Relational Mapping — mapping Java classes to DB tables automatically |
| Hibernate | Most popular Java ORM, open source, implements JPA |
| JPA | Java Persistence API — the standard spec Hibernate (and others) implement |
| Entity | A Java class annotated `@Entity`, representing a database table |
| EntityManager | JPA's interface for database operations (Spring hides this) |
| Session | Hibernate's equivalent of EntityManager |
| SessionFactory | One-per-application factory for creating Sessions |
| Persistence Context | The session-scoped cache of loaded entities (first-level cache) |
| Dirty Checking | Hibernate's auto-detection of changed entities within a transaction |
| Lazy Loading | Loading related entities only when accessed |
| Eager Loading | Loading related entities immediately with the parent |
| N+1 Problem | N extra queries caused by lazy-loading in a loop |
| JPQL | JPA's object-oriented query language (queries classes, not tables) |
| HQL | Hibernate Query Language — Hibernate's version of JPQL |
| JOIN FETCH | JPQL syntax to solve N+1 by loading relations in one query |

---

## What's Next

Phase 04 covers how Java handles HTTP — Servlets — and the JEE era.  
This is the story of how enterprise Java got very complex, very fast,  
and why a consultant named Rod Johnson decided to fix it with Spring.
