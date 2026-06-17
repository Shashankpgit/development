# Records

## What records are

Records are a compact way to write immutable data classes introduced in Java 16.
They are used for DTOs — classes that carry data between layers.

Before records you needed ~30 lines to write a simple two-field data class.
Records do the same in one line.

---

## Syntax

```java
public record NoteRequest(String title, String content) {}
```

That single line automatically gives you:
- A constructor: `new NoteRequest("My note", "content")`
- Getters: `request.title()` and `request.content()` (no `get` prefix)
- `equals()` — two records with same values are equal
- `hashCode()` — consistent with equals
- `toString()` — `NoteRequest[title=My note, content=content]`

---

## Old way vs record

```java
// Old way — 30+ lines
public class NoteRequest {
    private final String title;
    private final String content;

    public NoteRequest(String title, String content) {
        this.title = title;
        this.content = content;
    }

    public String getTitle() { return title; }
    public String getContent() { return content; }

    @Override public boolean equals(Object o) { ... }
    @Override public int hashCode() { ... }
    @Override public String toString() { ... }
}

// Record — 1 line, identical result
public record NoteRequest(String title, String content) {}
```

---

## Getters have no `get` prefix

```java
NoteRequest request = new NoteRequest("My note", "some content");

// Regular POJO getter
note.getTitle()       // with "get"

// Record getter
request.title()       // no "get"
request.content()     // no "get"
```

---

## Records are immutable

Fields are `final` — you cannot change them after creation:

```java
NoteRequest request = new NoteRequest("My note", "content");
request.title = "changed";    // ❌ compile error
```

This is intentional. DTOs carry data in one direction and should not be
modified after creation. Immutability prevents bugs.

---

## Records with validation

You can add Bean Validation annotations to record fields:

```java
public record NoteRequest(
    @NotBlank String title,
    @Size(max = 10000) String content
) {}
```

The annotations don't change what a record is — they just add validation rules
that Spring checks when the record arrives as a request body.

---

## When to use records vs regular classes

| Use record when | Use regular class when |
|---|---|
| The class is a DTO (carries data) | The class has behaviour (methods with logic) |
| Fields should not change after creation | Fields need to be updated |
| You need equals/hashCode automatically | You need custom equals/hashCode logic |
| Simple data container | Entity (`@Entity` cannot be a record — JPA requires mutable classes) |

**Important:** `@Entity` classes cannot be records. JPA requires a no-arg
constructor and mutable fields (setters). Always use regular classes for entities.

---

## Python equivalent

```python
# Python dataclass (closest equivalent)
from dataclasses import dataclass

@dataclass(frozen=True)      # frozen=True makes it immutable like a record
class NoteRequest:
    title: str
    content: str
```

Or even closer — a Pydantic model:
```python
class NoteRequest(BaseModel):
    title: str
    content: str
```

---

## Records used in this project

```java
// Request DTOs (what the client sends)
public record NoteRequest(String title, String content) {}
public record PasswordRequest(String label, String value) {}

// Response DTOs (what the API returns)
public record NoteResponse(Long id, String title, String content, LocalDateTime createdAt) {}
public record PasswordResponse(Long id, String label) {}
```
