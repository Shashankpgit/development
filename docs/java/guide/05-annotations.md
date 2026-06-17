# Annotations

## What annotations are

Annotations are metadata attached to a class, method, or field using `@`.
They don't change what the code does — they give instructions to the compiler
or a framework about how to treat that code.

Python equivalent: decorators.

```python
# Python decorator
@app.get("/notes")
def get_notes():
    ...
```

```java
// Java annotation
@GetMapping("/notes")
public List<Note> getNotes() {
    ...
}
```

Same concept — the `@` tells the framework "do something special with this".

---

## Three types of annotations

### 1. Built-in Java annotations (compiler reads them)

```java
@Override
public String toString() {    // compiler checks: does parent have toString()?
    return "Note";            // if not, compiler errors — catches typos
}

@Deprecated
public void oldMethod() {}    // compiler warns anyone who calls this

@SuppressWarnings("unused")
private String temp;          // tells compiler: stop warning about this
```

### 2. Compile-time annotations (processed before your code runs)

Lombok uses these. They generate code at compile time — before `javac` runs:

```java
@Data                   // generates getters, setters, equals, hashCode, toString
@NoArgsConstructor      // generates no-arg constructor
@AllArgsConstructor     // generates all-args constructor
public class Note {
    private Long id;
    private String title;
}
```

The generated methods exist in `target/classes/` but not in your source file.
Zero runtime overhead — it is pure code generation.

### 3. Runtime annotations (framework reads them while the app is running)

Spring and JPA use these. The framework scans your classes at startup using
Java Reflection and acts on what it finds:

```java
@Service                    // Spring reads this at startup
public class NoteService {  // Spring creates and manages one instance
}

@Entity                     // Hibernate reads this at startup
public class Note {         // Hibernate maps this class to the notes table
}
```

---

## How runtime annotations work (Reflection)

Reflection lets a program inspect itself at runtime — read class names, method
names, annotations, field types, etc.

When Spring Boot starts it scans every class in your package and checks for
annotations:

```java
// Simplified — what Spring does internally at startup
for (Class<?> clazz : allClassesInPackage) {
    if (clazz.isAnnotationPresent(Service.class)) {
        Object instance = clazz.getDeclaredConstructor().newInstance();
        beanContainer.register(clazz, instance);
    }
}
```

You never write this — Spring does it. But this is why adding `@Service` to a
class makes Spring manage it automatically.

---

## Annotations with parameters

Annotations can take values:

```java
@GetMapping("/notes/{id}")                              // string parameter
@Column(nullable = false)                               // named boolean parameter
@GeneratedValue(strategy = GenerationType.IDENTITY)     // enum parameter
@Column(name = "created_at", nullable = false)          // multiple parameters
```

---

## Annotations you will see in this project

| Annotation | Type | Layer | What it does |
|---|---|---|---|
| `@Override` | Java built-in | Anywhere | Compiler check |
| `@SpringBootApplication` | Spring runtime | Main class | Starts the whole framework |
| `@RestController` | Spring runtime | Controller | Handles HTTP, returns JSON |
| `@GetMapping` | Spring runtime | Controller method | Handles GET requests |
| `@PostMapping` | Spring runtime | Controller method | Handles POST requests |
| `@PutMapping` | Spring runtime | Controller method | Handles PUT requests |
| `@DeleteMapping` | Spring runtime | Controller method | Handles DELETE requests |
| `@RequestBody` | Spring runtime | Method parameter | Deserialise JSON body |
| `@PathVariable` | Spring runtime | Method parameter | Extract path segment |
| `@RequestParam` | Spring runtime | Method parameter | Extract query parameter |
| `@Service` | Spring runtime | Service class | Spring manages this bean |
| `@Repository` | Spring runtime | Repository class | Spring manages this bean |
| `@Autowired` | Spring runtime | Field/constructor | Inject dependency |
| `@Entity` | JPA runtime | Entity class | Map to a database table |
| `@Table` | JPA runtime | Entity class | Set the table name |
| `@Id` | JPA runtime | Entity field | Mark as primary key |
| `@GeneratedValue` | JPA runtime | Entity field | Auto-generate value |
| `@Column` | JPA runtime | Entity field | Column constraints |
| `@ManyToOne` | JPA runtime | Entity field | Many-to-one relationship |
| `@NotNull` | Validation | DTO field | Field cannot be null |
| `@NotBlank` | Validation | DTO field | String cannot be blank |
| `@Data` | Lombok compile-time | Any class | Generate getters/setters |
| `@NoArgsConstructor` | Lombok compile-time | Any class | Generate no-arg constructor |
| `@AllArgsConstructor` | Lombok compile-time | Any class | Generate all-args constructor |

---

## Important rule

You do not need to memorise all annotations upfront. Each phase introduces
only the annotations relevant to that phase. By the time you finish Phase 5
you will have used all of them naturally and they will be familiar.
