# Phase 12 — Build: Database Layer
## "PostgreSQL + Flyway + User entity + repository"

> Goal: connect to PostgreSQL, run first Flyway migration, build User entity.
> This is the foundation all other features sit on.

---

## What Gets Built

```
src/main/resources/db/migration/
  V1__create_users_table.sql

com/vaultapp/users/
  User.java              ← @Entity
  UserRepository.java    ← extends JpaRepository
```

---

## Flyway Migration: V1__create_users_table.sql

```sql
CREATE TABLE users (
    id         BIGSERIAL    PRIMARY KEY,
    sub        VARCHAR(255) NOT NULL UNIQUE,  -- Keycloak's user UUID
    created_at TIMESTAMP    NOT NULL DEFAULT NOW()
);
```

On application startup, Flyway:
1. Checks `flyway_schema_history` table (creates it if first run)
2. Sees V1 has not been applied
3. Runs V1 script
4. Records V1 in history table

Next startup: V1 is already in history → skip.

---

## User Entity

```java
@Entity
@Table(name = "users")
public class User {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false, unique = true)
    private String sub;                    // Keycloak UUID ("sub" claim from JWT)
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    // No-arg constructor required by JPA
    protected User() {}
    
    // Constructor for creating new users
    public User(String sub) {
        this.sub = sub;
        this.createdAt = LocalDateTime.now();
    }
    
    // Getters (no setters for immutable fields)
    public Long getId()            { return id; }
    public String getSub()         { return sub; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
```

Why no `@PrePersist` for `createdAt`? The SQL default `DEFAULT NOW()` handles it at the DB level.  
Either approach works — DB default is slightly more reliable.

---

## UserRepository

```java
@Repository   // optional — JpaRepository impls are auto-detected, but documents intent
public interface UserRepository extends JpaRepository<User, Long> {
    
    Optional<User> findBySub(String sub);
    // Spring generates: SELECT u FROM User u WHERE u.sub = :sub
    
    boolean existsBySub(String sub);
    // Spring generates: SELECT COUNT(u) > 0 FROM User u WHERE u.sub = :sub
}
```

---

## Key Decisions

### Why `sub` and not `email` or `username`?

The `sub` claim is the Keycloak user's permanent, immutable UUID.  
Email can change. Username can change. `sub` never changes.  
It's the safest primary identifier from an external identity provider.

### Why `String sub` and not `UUID sub`?

The JWT `sub` claim is a string. Keeping it as `String` avoids conversion errors.  
PostgreSQL can store UUID in a text column without issues.

### Why `protected User() {}` for JPA?

JPA (Hibernate) requires a no-argument constructor to create instances via reflection  
when loading entities from the database.  
`protected` prevents direct instantiation from other packages while satisfying JPA.

---

## Deliverable

```bash
# On startup, logs should show:
# Flyway: Successfully applied 1 migration to schema "public"
# Hibernate: validated schema against entities

# Verify table was created:
# kubectl exec postgresql-0 -- psql -U vault -c "\dt"
# → users table exists
```
