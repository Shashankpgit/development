# Phase 02 — JDBC: Raw Database Access
## "What was Java DB access before ORMs? What pain did it cause?"

> JDBC is NOT something you'll use directly in Spring Boot.  
> But understanding it is why you'll appreciate what Spring Data JPA does for free.  
> Every ORM, every Spring repository, every `save()` call is hiding JDBC underneath.

---

## The Problem JDBC Was Solving (1997)

Before JDBC, every database had its own proprietary Java API.  
Oracle had one. MySQL had one. PostgreSQL had one.  
Change your database → rewrite your entire data layer.

**JDBC (Java Database Connectivity)** introduced a standard API:
- One set of Java interfaces (`Connection`, `Statement`, `ResultSet`)
- Database vendors write "drivers" that implement those interfaces
- Your code uses the standard API — the driver handles vendor specifics

```
Your Java code (uses JDBC API)
         │
         ▼
   JDBC Driver Manager
         │
    ┌────┼────┐
    ▼    ▼    ▼
PostgreSQL  MySQL  Oracle
  Driver    Driver  Driver
    │         │       │
    ▼         ▼       ▼
 Postgres    MySQL  Oracle DB
   DB          DB
```

This was a major improvement. But JDBC itself is still very low-level.

---

## How JDBC Works — The Full Flow

Let's say you want to fetch all notes for a user. Here is JDBC code in full:

```java
import java.sql.*;

public class NoteJdbcExample {

    // Step 1: Database connection details (hardcoded for illustration)
    private static final String DB_URL      = "jdbc:postgresql://localhost:5432/vault";
    private static final String DB_USER     = "vault";
    private static final String DB_PASSWORD = "secret";

    public List<Note> getNotesForUser(long userId) {
        List<Note> notes = new ArrayList<>();

        // Step 2: Get a Connection — opens a TCP socket to the DB
        Connection connection = null;
        PreparedStatement statement = null;
        ResultSet resultSet = null;

        try {
            connection = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);

            // Step 3: Prepare the SQL
            String sql = "SELECT id, title, body, created_at FROM notes WHERE user_id = ?";
            statement = connection.prepareStatement(sql);

            // Step 4: Bind parameters (? placeholder)
            statement.setLong(1, userId);   // 1 = first ? placeholder

            // Step 5: Execute the query
            resultSet = statement.executeQuery();

            // Step 6: Read the ResultSet row by row
            while (resultSet.next()) {
                Note note = new Note();
                note.setId(resultSet.getLong("id"));
                note.setTitle(resultSet.getString("title"));
                note.setBody(resultSet.getString("body"));
                note.setCreatedAt(resultSet.getTimestamp("created_at").toLocalDateTime());
                notes.add(note);
            }

        } catch (SQLException e) {
            // Step 7: Handle database errors
            throw new RuntimeException("Failed to fetch notes: " + e.getMessage(), e);

        } finally {
            // Step 8: ALWAYS close resources — even if an exception occurred
            // Order matters: close in reverse order of opening
            try { if (resultSet  != null) resultSet.close();  } catch (SQLException ignored) {}
            try { if (statement  != null) statement.close();  } catch (SQLException ignored) {}
            try { if (connection != null) connection.close();  } catch (SQLException ignored) {}
        }

        return notes;
    }
}
```

Count the lines: about 40 lines to fetch a list of rows from one table.  
With Spring Data JPA, this entire thing becomes one interface method:
```java
List<Note> findByUserId(Long userId);
```

---

## The JDBC Pain Points (this is why ORMs exist)

### Pain 1: Every query is a wall of boilerplate

**For every single database operation**, you need:
1. Open connection
2. Create statement
3. Bind parameters
4. Execute
5. Map ResultSet rows to Java objects
6. Close ResultSet
7. Close Statement
8. Close Connection (in `finally` so it always runs)

An application with 20 endpoints could have thousands of lines of this.

### Pain 2: SQL strings scattered throughout Java code

```java
// These SQL strings are scattered across many Java files
String sql1 = "SELECT * FROM notes WHERE user_id = ?";
String sql2 = "INSERT INTO notes (title, body, user_id) VALUES (?, ?, ?)";
String sql3 = "UPDATE notes SET title = ?, body = ? WHERE id = ? AND user_id = ?";
```
No refactoring. No IDE help. A typo in a SQL string is a runtime crash.  
Rename a column in the database → find every SQL string in every Java file.

### Pain 3: Manual object mapping (ResultSet → Java object)

```java
Note note = new Note();
note.setId(resultSet.getLong("id"));
note.setTitle(resultSet.getString("title"));
note.setBody(resultSet.getString("body"));
note.setCreatedAt(resultSet.getTimestamp("created_at").toLocalDateTime());
```
Write this for every query, for every field, for every entity.  
Add a new field to your table → update every query that maps that entity.

### Pain 4: Connection management was a disaster

Opening a database connection is expensive (TCP handshake, auth, etc.).  
Raw JDBC opens a new connection for every operation.

```
Request 1 → new Connection → query → close Connection   (100ms overhead)
Request 2 → new Connection → query → close Connection   (100ms overhead)
```

The solution: **Connection Pooling**. Reuse connections instead of creating new ones.

```
Application starts → open pool of 10 connections → keep them ready
Request 1 → borrow connection from pool → query → return to pool
Request 2 → borrow connection from pool → query → return to pool
```

With raw JDBC you had to configure this yourself (using libraries like C3P0, DBCP).  
Spring Boot does this automatically with **HikariCP** — the fastest Java connection pool.

### Pain 5: No transaction management

```java
public void transferMoney(long fromId, long toId, double amount) {
    Connection conn = null;
    try {
        conn = DriverManager.getConnection(...);
        conn.setAutoCommit(false);   // disable auto-commit to start a transaction

        // debit sender
        PreparedStatement debit = conn.prepareStatement(
            "UPDATE accounts SET balance = balance - ? WHERE id = ?");
        debit.setDouble(1, amount);
        debit.setLong(2, fromId);
        debit.executeUpdate();

        // credit receiver
        PreparedStatement credit = conn.prepareStatement(
            "UPDATE accounts SET balance = balance + ? WHERE id = ?");
        credit.setDouble(1, amount);
        credit.setLong(2, toId);
        credit.executeUpdate();

        conn.commit();   // success — commit both changes

    } catch (SQLException e) {
        conn.rollback(); // failure — undo everything
        throw new RuntimeException(e);
    } finally {
        conn.close();
    }
}
```

Manual `setAutoCommit(false)`, manual `commit()`, manual `rollback()`.  
Spring's `@Transactional` annotation replaces ALL of this with a single annotation.

---

## PreparedStatement vs Statement — SQL Injection

This is important for security.

### Statement — DANGEROUS
```java
// BAD — never do this
String userId = "1 OR 1=1";  // attacker-controlled input
String sql = "SELECT * FROM notes WHERE user_id = " + userId;
// Executes: SELECT * FROM notes WHERE user_id = 1 OR 1=1
// Returns ALL notes from ALL users!
Statement stmt = conn.createStatement();
ResultSet rs = stmt.executeQuery(sql);  // SQL INJECTION
```

### PreparedStatement — SAFE
```java
// GOOD — parameterised query
String sql = "SELECT * FROM notes WHERE user_id = ?";
PreparedStatement stmt = conn.prepareStatement(sql);
stmt.setLong(1, userId);   // value is always treated as data, never as SQL
ResultSet rs = stmt.executeQuery();
```
With `PreparedStatement`, the SQL structure is fixed. The `?` is always a value, never code.  
ORMs (Hibernate, JOOQ, etc.) always use parameterised queries internally.

---

## JDBC Template — Spring's First Improvement

Before Spring Data JPA, Spring provided `JdbcTemplate` — a thin wrapper around JDBC that eliminated the boilerplate while keeping SQL explicit.

```java
// Raw JDBC — 40 lines to get a list
// JdbcTemplate — same operation
@Repository
public class NoteJdbcRepository {
    
    private final JdbcTemplate jdbc;   // Spring injects this
    
    public List<Note> findByUserId(long userId) {
        return jdbc.query(
            "SELECT id, title, body FROM notes WHERE user_id = ?",
            (rs, rowNum) -> {
                Note note = new Note();
                note.setId(rs.getLong("id"));
                note.setTitle(rs.getString("title"));
                note.setBody(rs.getString("body"));
                return note;
            },
            userId   // bound to ?
        );
    }
}
```

`JdbcTemplate` handles:
- Opening/closing connections (from the pool)
- Opening/closing statements
- The `try/catch/finally` block
- Iterating the `ResultSet`

**You** still write:
- The SQL string
- The mapping from `ResultSet` to Java object (the `RowMapper`)

This was a big improvement over raw JDBC — but the SQL and mapping are still manual.  
Hibernate eliminated both.

---

## The JDBC Mental Model (What Every ORM Hides)

Even though you'll never write raw JDBC in Spring Boot, knowing this model is essential:

```
Every database operation:
  1. Get a connection from the pool
  2. Start a transaction (if @Transactional is active)
  3. Prepare SQL statement
  4. Bind parameters
  5. Execute → get ResultSet
  6. Map ResultSet rows to Java objects  ← ORM automates this
  7. Commit/rollback the transaction     ← @Transactional automates this
  8. Return connection to pool
```

Every `noteRepository.findByUserId(userId)` in Spring Data JPA goes through all 8 of these steps.  
Spring Data JPA writes steps 3, 4, 5, 6 for you. Spring's transaction management handles 2 and 7.  
HikariCP (auto-configured by Spring Boot) handles 1 and 8.

---

## Key Terms

| Term | Meaning |
|---|---|
| JDBC | Java Database Connectivity — standard Java API for database access |
| JDBC Driver | A library provided by each DB vendor that implements the JDBC interfaces |
| Connection | A TCP socket to the database — expensive to open |
| PreparedStatement | A parameterised SQL query — safe from SQL injection |
| ResultSet | A cursor over the rows returned by a query |
| Connection Pool | A cache of open connections, reused across requests |
| HikariCP | The fastest Java connection pool — auto-configured by Spring Boot |
| JdbcTemplate | Spring's JDBC wrapper that handles boilerplate but keeps SQL explicit |

---

## What's Next

Phase 03 covers Hibernate — which took the JDBC model and said:  
*"What if the mapping from SQL rows to Java objects was automatic?  
What if you never had to write SELECT/INSERT/UPDATE/DELETE for basic operations?"*  
That's the ORM revolution.
