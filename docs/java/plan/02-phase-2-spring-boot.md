# Phase 2 — Spring Boot Fundamentals

## Goal

Write your first REST endpoint in Spring Boot and understand what Spring is
actually doing behind the scenes. By the end of this phase you will have a
running Spring Boot app with dummy endpoints tested in Postman.

---

## Step 2.1 — What is Spring? What is Spring Boot?

Read: `docs/java/guide/04-spring-boot-intro.md`

**Spring** is a framework that manages your objects for you. In Python, when
you write `service = NoteService()` you create the object yourself. Spring
creates, wires, and manages objects automatically.

**Spring Boot** is Spring + sensible defaults. Before Spring Boot, configuring
Spring required hundreds of lines of XML. Spring Boot auto-configures
everything based on what JARs are on the classpath.

The one-line summary:
```
Spring     = IoC container + ecosystem of libraries
Spring Boot = Spring + auto-configuration + embedded Tomcat + starter POMs
```

**Embedded Tomcat** — the biggest difference from Python:
In Python, your app and the server are separate (Uvicorn runs FastAPI).
In Spring Boot, the web server (Tomcat) is embedded inside your JAR file.
You run `java -jar vault.jar` and the server starts automatically.

---

## Step 2.2 — Dependency Injection

Read: `docs/java/guide/05-dependency-injection.md`

This is the single most important concept in Spring. Everything else builds on it.

**The problem without DI:**
```java
public class NoteController {
    private NoteService service = new NoteService();  // controller creates service
    // Problem: controller is tightly coupled to NoteService
    // Testing is hard — you cannot swap NoteService for a mock
}
```

**With Spring DI:**
```java
@RestController
public class NoteController {
    private final NoteService service;

    public NoteController(NoteService service) {  // Spring injects this
        this.service = service;
    }
}
```

Spring sees `NoteController` needs a `NoteService`. Spring creates one
`NoteService` instance and passes it in. You never call `new NoteService()`.

Python FastAPI equivalent:
```python
# FastAPI DI
def get_notes(db: Session = Depends(get_db)):
    ...
```
Spring does the same thing but at the object level, not the function level.

---

## Step 2.2b — Servlets (what Tomcat actually runs)

Before writing your first endpoint, understand what is happening underneath.

When Spring Boot starts you will see this in the logs:
```
Tomcat started on port 8080
```

Tomcat is a **Servlet container** — its job is to receive HTTP requests and
hand them to Servlet objects. A Servlet is the raw Java way to handle HTTP:
read the request, write the response, manually.

Spring MVC has ONE Servlet called `DispatcherServlet`. Every request goes to
it. It then finds the right `@RestController` method, parses the JSON body,
injects path variables, and serialises the return value back to JSON —
automatically. You never write a raw Servlet yourself.

```
HTTP Request
    ↓
Tomcat (Servlet container — manages HTTP lifecycle)
    ↓
DispatcherServlet (Spring's one Servlet — does routing + parsing)
    ↓
Your @GetMapping method (just your business logic)
    ↓
HTTP Response (JSON serialised automatically)
```

Python equivalent:
```
Gunicorn  ≈  Tomcat             (the container)
Starlette ≈  DispatcherServlet  (the routing layer)
FastAPI   ≈  Spring Boot        (your code lives here)
```

You never wrote raw WSGI code in FastAPI. You never write raw Servlet code
in Spring Boot. This note exists so that when a Spring error mentions
`HttpServletRequest` or `DispatcherServlet` you know exactly what it is.

## Step 2.3 — First Spring Boot endpoint

Read: `docs/java/guide/06-rest-controllers.md`

Add Spring Boot to `pom.xml`:
```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.0</version>
</parent>

<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
</dependencies>
```

`spring-boot-starter-web` pulls in: Spring MVC, embedded Tomcat, Jackson
(JSON serialisation), and validation — everything needed for a REST API.

Write the endpoint:
```java
@RestController
@RequestMapping("/api")
public class HelloController {

    @GetMapping("/hello")
    public String hello() {
        return "Hello from Java!";
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }
}
```

Annotation mapping to FastAPI:
```python
# FastAPI                           # Spring Boot
@app.get("/api/hello")    ≈         @GetMapping("/api/hello")
@app.post("/api/notes")   ≈         @PostMapping("/api/notes")
@app.put("/api/notes/{id}") ≈       @PutMapping("/api/notes/{id}")
@app.delete("/api/notes/{id}") ≈    @DeleteMapping("/api/notes/{id}")
```

---

## Step 2.4 — Request body and path variables

```java
// Path variable — /api/notes/42
@GetMapping("/notes/{id}")
public String getNote(@PathVariable Long id) {
    return "Note " + id;
}

// Request body — POST /api/notes with JSON body
@PostMapping("/notes")
public String createNote(@RequestBody NoteRequest request) {
    return "Created: " + request.title();
}

// Query param — /api/notes?page=1
@GetMapping("/notes")
public String getNotes(@RequestParam(defaultValue = "0") int page) {
    return "Page " + page;
}
```

Python equivalent:
```python
# FastAPI
@app.get("/notes/{id}")
def get_note(id: int): ...

@app.post("/notes")
def create_note(request: NoteRequest): ...

@app.get("/notes")
def get_notes(page: int = 0): ...
```

---

## Step 2.5 — application.properties

`src/main/resources/application.properties` is your `.env` equivalent:

```properties
# Server
server.port=8080

# App name (shows in logs)
spring.application.name=vault-api

# Log level
logging.level.com.vault=DEBUG
```

Spring Boot reads this automatically at startup. No parsing needed.

---

## Step 2.6 — Playground: build dummy endpoints

Build these endpoints in a `PlaygroundController.java` — no database, just
hardcoded responses. Goal: get comfortable with annotations and Postman testing.

```
GET  /playground/hello              → "Hello from Java"
GET  /playground/echo/{message}     → returns the message back
POST /playground/greet              → body: {"name":"Shashank"} → "Hello Shashank"
GET  /playground/notes              → returns a hardcoded list of 2 notes
POST /playground/notes              → receives a note, returns it back
```

Test each one in Postman before moving on.

---

## Phase 2 deliverable

Spring Boot app running on port 8080 with:
- `HealthController` → `GET /health` returning `{"status":"ok"}`
- `PlaygroundController` → 5 dummy endpoints tested in Postman
- DevTools configured for hot reload

---

## Files in this phase

| File | Purpose |
|---|---|
| `docs/java/guide/04-spring-boot-intro.md` | What Spring/Spring Boot is |
| `docs/java/guide/05-dependency-injection.md` | IoC and DI deep dive |
| `docs/java/guide/06-rest-controllers.md` | Writing endpoints |
| `vault-java/src/main/java/com/vault/VaultApplication.java` | Main class |
| `vault-java/src/main/java/com/vault/controller/HealthController.java` | Health endpoint |
| `vault-java/src/main/java/com/vault/controller/PlaygroundController.java` | Dummy endpoints |
| `vault-java/src/main/resources/application.properties` | App config |
