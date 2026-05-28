# Phase 05 — Spring Framework Core
## "What is IoC/DI? How did Spring replace JEE complexity?"

> This is the most important conceptual phase in the entire series.
> IoC and Dependency Injection are not Spring-specific ideas —
> but Spring made them the central architecture of a Java application.
> Everything else in Spring Boot (JPA, Security, Web) is just DI applied to a problem domain.

---

## Part 1 — Inversion of Control (IoC)

### The Control Problem

In traditional code, **your code controls** when objects are created and how they're connected:

```java
// Traditional — YOU control everything
public class NoteService {
    
    private NoteRepository repository;
    
    public NoteService() {
        // YOU create the dependency
        this.repository = new NoteRepository();   // tightly coupled
    }
    
    public List<Note> getNotes(long userId) {
        return repository.findByUserId(userId);
    }
}
```

Problems:
- `NoteService` is **tightly coupled** to `NoteRepository`
- You can't swap the repository (e.g., for a mock in tests) without changing `NoteService`
- You can't reuse a single `NoteRepository` instance — each `NoteService` creates its own

### Inversion of Control — the Container takes control

**IoC** means: instead of your code creating its own dependencies, you hand that responsibility  
to a **container** (the Spring IoC container).

```
Traditional:
  Your code → creates → its own dependencies

IoC:
  Container → creates → all objects → injects dependencies → hands objects to your code
```

You declare *what you need*. The container decides *how to provide it*.

This inversion is why it's called "Inversion of Control" — control of object creation  
is inverted from your code to the framework.

---

## Part 2 — Dependency Injection (DI)

DI is the mechanism through which IoC works. The container **injects** (passes in) dependencies.

### Three Ways Spring Can Inject

#### 1. Constructor Injection (Recommended — Spring 4.3+)
```java
@Service
public class NoteService {
    
    private final NoteRepository noteRepository;  // final = immutable, set once
    
    // Spring sees one constructor — automatically injects NoteRepository
    public NoteService(NoteRepository noteRepository) {
        this.noteRepository = noteRepository;
    }
}
```
- ✅ Dependencies are mandatory (null-safe)
- ✅ `final` field = immutable (thread-safe)
- ✅ Easy to test: `new NoteService(mockRepository)`
- ✅ No annotation needed if there's only one constructor

#### 2. Field Injection (Common but not recommended)
```java
@Service
public class NoteService {
    
    @Autowired                           // Spring injects directly into the field
    private NoteRepository noteRepository;
}
```
- ❌ Field is not `final` — can be changed
- ❌ Hard to test without Spring's test context
- ❌ Hides dependencies (not visible in constructor)
- Widely used in older Spring codebases — you'll see it

#### 3. Setter Injection (Rarely used today)
```java
@Service
public class NoteService {
    private NoteRepository noteRepository;
    
    @Autowired
    public void setNoteRepository(NoteRepository noteRepository) {
        this.noteRepository = noteRepository;
    }
}
```
Used when the dependency is optional or can change after construction.

**We will use constructor injection throughout this project.**

---

## Part 3 — The Spring IoC Container

The container is the core of Spring. It's responsible for:
1. Discovering all "beans" (Spring-managed objects)
2. Creating them in the right order
3. Injecting their dependencies
4. Managing their lifecycle

### What is a Bean?

A **Spring Bean** is any object that is managed by the Spring IoC container.  
Not every Java object is a bean — only the ones Spring knows about.

```java
// This is a Spring Bean
@Service
public class NoteService { ... }

// This is NOT a Spring Bean (unless you create it with @Bean)
public class Note {
    private String title;   // just a regular Java object / entity
}
```

### ApplicationContext — the Container

```java
// The container — in Spring Boot this is created automatically
ApplicationContext context = SpringApplication.run(VaultApiApplication.class, args);

// You can ask the container for a bean (Spring Boot does this for you in practice)
NoteService noteService = context.getBean(NoteService.class);
```

In Spring Boot, you never call `context.getBean()` yourself.  
Spring automatically injects beans wherever you declare a constructor parameter with the right type.

---

## Part 4 — Bean Annotations

How does Spring know which classes to manage? Through annotations.

### Stereotype Annotations (what role does this class play?)

```java
@Component      // Generic — "Spring, manage this class"
@Service        // "This is a service/business logic layer" (semantically @Component)
@Repository     // "This is a data access layer" (adds exception translation)
@Controller     // "This handles HTTP requests" (@Component + MVC role)
@RestController // @Controller + @ResponseBody (returns JSON, not views)
```

They're all essentially `@Component` with extra meaning.  
Spring's component scanning finds them all and creates beans.

### @Configuration and @Bean

Sometimes you need to create a bean from a class you don't own (a library class):

```java
@Configuration              // This class contains bean definitions
public class AppConfig {
    
    @Bean                   // This method creates a bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();   // you don't own BCryptPasswordEncoder
    }
    
    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());   // customise Jackson
        return mapper;
    }
}
```

Spring calls `passwordEncoder()` once and stores the returned object in the container.  
Whenever any class needs a `PasswordEncoder`, Spring injects this object.

---

## Part 5 — Component Scanning

Spring doesn't automatically look at every Java class in the universe.  
It scans a specific package (and its sub-packages).

```java
@SpringBootApplication  // This annotation includes @ComponentScan
public class VaultApiApplication {
    public static void main(String[] args) {
        SpringApplication.run(VaultApiApplication.class, args);
    }
}
```

`@ComponentScan` scans the package where `VaultApiApplication` lives and all sub-packages.  
Convention: put `VaultApiApplication.java` at the root package.

```
com.vaultapp
├── VaultApiApplication.java       ← scanning starts here
├── notes/
│     ├── NoteController.java      ← @RestController found ✓
│     ├── NoteService.java         ← @Service found ✓
│     └── NoteRepository.java      ← @Repository found ✓
├── users/
│     ├── UserController.java      ← @RestController found ✓
│     └── UserService.java         ← @Service found ✓
└── config/
      └── SecurityConfig.java      ← @Configuration found ✓
```

---

## Part 6 — AOP: Aspect-Oriented Programming

AOP is how Spring handles **cross-cutting concerns** — things that need to happen  
across many methods without cluttering the business logic.

Classic examples:
- Logging "entering method X, leaving method X with result Y"
- `@Transactional` — start a transaction before the method, commit/rollback after
- Security checks — verify the user has permission before the method runs
- Caching — return cached result if available, skip method execution

Without AOP:
```java
public List<Note> getNotes(long userId) {
    logger.debug("entering getNotes, userId={}", userId);  // logging
    Transaction tx = beginTransaction();                    // transaction
    try {
        List<Note> result = noteRepository.findByUserId(userId);
        tx.commit();
        logger.debug("getNotes returning {} results", result.size());
        return result;
    } catch (Exception e) {
        tx.rollback();
        throw e;
    }
}
```

With AOP (`@Transactional` + logging aspect):
```java
@Transactional     // Spring wraps this method with transaction management
@Loggable          // a custom aspect that logs entry/exit
public List<Note> getNotes(long userId) {
    return noteRepository.findByUserId(userId);  // pure business logic
}
```

### How `@Transactional` Works (AOP in action)

This is important to understand because you'll use `@Transactional` constantly.

When Spring sees a `@Transactional` method, it creates a **proxy**:

```
You call: noteService.getNotes(userId)

Spring intercepts (via proxy):
  1. Open a database connection from the pool
  2. Begin a transaction (setAutoCommit(false))
  3. ── call YOUR method ──
       noteRepository.findByUserId(userId)
  4a. If method returned normally: commit transaction
  4b. If method threw RuntimeException: rollback transaction
  5. Close connection (return to pool)
```

Your method runs inside a transaction without any transaction code in it.  
Spring uses **dynamic proxies** (or CGLIB byte-code generation) to wrap your classes.

```
NoteService (your actual class)
     ↑
NoteService$Proxy (Spring-generated wrapper that adds transaction management)
     ↑
Classes that inject NoteService actually get the proxy
```

This is why `@Transactional` only works when called **from outside** the class.  
`this.someMethod()` bypasses the proxy — no transaction.

---

## Part 7 — Spring MVC

Spring MVC is Spring's answer to raw Servlets. It uses the **Front Controller** pattern.

```
HTTP Request: GET /api/notes?userId=42
     ↓
DispatcherServlet (the single "front controller" Servlet)
     ↓  asks
HandlerMapping  → "Which @Controller handles /api/notes?"
                → "NoteController.list()"
     ↓  calls
NoteController.list()
     ↓  returns
List<Note>
     ↓  serialised by
HttpMessageConverter (Jackson converts List<Note> to JSON)
     ↓
HTTP Response: 200 OK, body: [{"id":1,"title":"..."}]
```

### The Controller

```java
@RestController                    // @Controller + @ResponseBody
@RequestMapping("/api/notes")      // all methods in this class are under /api/notes
public class NoteController {
    
    private final NoteService noteService;
    
    public NoteController(NoteService noteService) {  // constructor injection
        this.noteService = noteService;
    }
    
    @GetMapping                    // handles GET /api/notes
    public List<Note> listNotes(@RequestParam Long userId) {
        return noteService.getNotes(userId);
        // Spring automatically serialises List<Note> to JSON
    }
    
    @GetMapping("/{id}")           // handles GET /api/notes/42
    public Note getNote(@PathVariable Long id) {
        return noteService.getNote(id);
    }
    
    @PostMapping                   // handles POST /api/notes
    public ResponseEntity<Note> createNote(@RequestBody NoteRequest request) {
        // @RequestBody: Jackson deserialises JSON body → NoteRequest object
        Note created = noteService.createNote(request);
        return ResponseEntity.status(201).body(created);
    }
}
```

Compare to FastAPI (Python):
```python
router = APIRouter(prefix="/api/notes")

@router.get("")
def list_notes(user_id: int, db = Depends(get_db)):
    return note_service.get_notes(db, user_id)

@router.get("/{note_id}")
def get_note(note_id: int):
    return note_service.get_note(note_id)

@router.post("")
def create_note(note: NoteCreate):
    return note_service.create_note(note)
```

Different syntax, same concepts:
- Python `@router.get("")` ↔ Java `@GetMapping`
- Python `Depends(get_db)` ↔ Java `@Autowired` (DI)
- Python `BaseModel` (Pydantic) ↔ Java POJO class or Record
- Python returns dict ↔ Java returns object (Jackson serialises to JSON)

---

## Part 8 — The @Value and @ConfigurationProperties

Spring reads `application.yml` and makes values available.

```yaml
# application.yml
app:
  encryption-key: ${ENCRYPTION_KEY}    # from environment variable
  max-notes-per-user: 100
```

```java
// Inject a single value
@Service
public class EncryptionService {
    
    @Value("${app.encryption-key}")    // injects value at startup
    private String encryptionKey;
    
    @Value("${app.max-notes-per-user:50}")  // :50 is the default if not set
    private int maxNotesPerUser;
}
```

```java
// Or bind an entire config section to a class (better for groups)
@ConfigurationProperties(prefix = "app")
@Component
public class AppConfig {
    private String encryptionKey;
    private int maxNotesPerUser;
    // getters and setters
}
```

This replaces Python's `os.getenv("ENCRYPTION_KEY")`.

---

## Summary: What Spring Framework Gave Us

| Problem | Spring's Solution |
|---|---|
| EJB XML boilerplate | Annotations: `@Service`, `@Repository`, `@Transactional` |
| JNDI lookup | Constructor injection — declare what you need, Spring provides it |
| Must extend EJB classes | POJOs — your classes extend nothing |
| Application server required | Works in any Servlet container (Tomcat, Jetty) |
| Hard to test | Constructor injection → easy `new Service(mockRepo)` in tests |
| Transaction management code everywhere | `@Transactional` — Spring wraps your method |
| One Servlet per URL | `@Controller` + `@RequestMapping` — one class handles many URLs |

Spring Framework solved all the problems of JEE.  
But configuring Spring itself had new problems — XML `applicationContext.xml` files got large.  
Spring Boot (Phase 06) solves Spring's own configuration problem.

---

## Key Terms

| Term | Meaning |
|---|---|
| IoC | Inversion of Control — container manages object creation, not your code |
| DI | Dependency Injection — container passes dependencies to objects |
| Spring Bean | Any object managed by the Spring IoC container |
| ApplicationContext | The Spring IoC container |
| @Component | Marks a class as a Spring bean |
| @Service / @Repository | Specialised @Component annotations with semantic meaning |
| @Autowired | Tells Spring to inject a dependency here (not needed with constructor injection) |
| @Configuration + @Bean | Define beans that Spring can't discover by scanning |
| @ComponentScan | Tells Spring which packages to scan for annotations |
| AOP | Aspect-Oriented Programming — wrapping methods with cross-cutting behaviour |
| Proxy | Spring-generated wrapper class that adds AOP behaviour |
| @Transactional | Wraps a method in a DB transaction (via AOP proxy) |
| DispatcherServlet | Spring MVC's front controller — routes all requests |
| @RestController | Marks a class as handling HTTP requests, returning JSON |
| @RequestMapping | Maps a URL pattern to a controller class or method |
| @Value | Injects a value from application.yml/environment |
