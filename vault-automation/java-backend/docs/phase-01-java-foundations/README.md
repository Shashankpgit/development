# Phase 01 — Java Foundations
## "How is Java fundamentally different from Python?"

> This phase is 100% conceptual. No Spring. No framework. Just the language.  
> If you try to rush to Spring Boot without this, everything in Spring will feel like magic  
> you can't control. This phase makes the magic explainable.

---

## 1. The Compilation Mental Model

Python and Java have completely different execution models. This changes everything.

### Python (Interpreted)
```
your_code.py
     │
     ▼
 Python interpreter reads line by line
     │
     ▼
 Executes immediately
```
A typo in a function you never call? Python never notices — unless that line runs.  
A wrong variable type? Python finds out at runtime — when it crashes.

### Java (Compiled to bytecode → JVM)
```
YourClass.java
     │
     ▼  javac (Java compiler)
YourClass.class  (bytecode — not machine code, not source code)
     │
     ▼  JVM (Java Virtual Machine)
 Executes on any OS
```

What the compiler checks **before you ever run**:
- Variable types match their assignments
- Methods exist and accept the right argument types
- You handle every checked exception (more on this later)
- You're not calling a method on something that might be null (Java 17+ with records)

**Why this matters for you**: When you learn Spring Boot, you'll sometimes see errors at  
**compile time** ("application context failed to start" before any request) rather than  
at runtime when a request arrives. That's the Java compilation model in action.

---

## 2. Static Typing — The Biggest Mental Shift

### Python: types are optional hints
```python
def add(a, b):       # a and b could be anything
    return a + b

add(1, 2)      # works: 3
add("hello", " world")  # also works: "hello world"
add(1, "two")  # crashes at RUNTIME: TypeError
```

### Java: types are mandatory contracts
```java
public int add(int a, int b) {
    return a + b;
}

add(1, 2);          // works: 3
add("hello", " world");  // COMPILE ERROR — won't even run
add(1, "two");           // COMPILE ERROR — caught before execution
```

The compiler reads your entire program before running a single line.  
It enforces all type contracts. Wrong type = doesn't compile = can't ship broken code.

### Java's type categories

**Primitive types** (lowercase, stored by value in memory):
```java
int     age = 25;           // 32-bit integer
long    bigNum = 99999999L; // 64-bit integer (L suffix)
double  price = 19.99;      // 64-bit floating point
boolean active = true;      // true or false
char    letter = 'A';       // single character
```

**Reference types** (uppercase, stored as a pointer to an object):
```java
String  name = "Alice";     // text (NOT a primitive)
Integer boxed = 25;         // int wrapped in an object (boxing)
List<String> names = new ArrayList<>();
User    user = new User();
```

### Autoboxing — Java bridges primitives and objects
```java
int primitive = 42;
Integer boxed = primitive;   // Java automatically "boxes" int → Integer
int back = boxed;            // Java automatically "unboxes" Integer → int
```
This matters in collections: `List<int>` is **illegal**, `List<Integer>` is correct.  
Python has no such distinction — everything is an object.

---

## 3. Object-Oriented Programming (OOP)

Python has OOP. Java **enforces** OOP — everything lives inside a class.

### Classes and Objects
```python
# Python — functions can exist outside classes
def greet(name):
    return f"Hello {name}"

class User:
    def __init__(self, name):
        self.name = name
```

```java
// Java — EVERYTHING must be inside a class
public class Greeter {
    public String greet(String name) {
        return "Hello " + name;
    }
}

public class User {
    private String name;          // field (instance variable)
    
    public User(String name) {    // constructor
        this.name = name;
    }
    
    public String getName() {     // getter
        return name;
    }
    
    public void setName(String name) {  // setter
        this.name = name;
    }
}
```

### Access Modifiers — Java is explicit about visibility
```java
public class BankAccount {
    public    String owner;      // anyone can read/write
    private   double balance;    // only this class can access
    protected String notes;      // this class + subclasses + same package
    // (no modifier) = "package-private" — only classes in same package
}
```
Python has conventions (`_private`, `__mangled`). Java enforces it at compile time.

---

## 4. Interfaces — Spring's Most Used Concept

Interfaces are **contracts**. They say "any class that implements me must have these methods."

```java
// Interface: defines WHAT, not HOW
public interface Saveable {
    void save();
    void delete(Long id);
}

// Class: implements the HOW
public class NoteRepository implements Saveable {
    @Override
    public void save() {
        // actual save logic here
    }
    
    @Override
    public void delete(Long id) {
        // actual delete logic here
    }
}
```

**Why you need to understand this deeply**: Spring uses interfaces everywhere.  
When you write `UserRepository extends JpaRepository<User, Long>`, you are  
defining an interface and letting Spring provide the implementation automatically.  
When Spring injects a `UserRepository` into your service, it injects the implementation object.

### Python has no formal interfaces
Python uses "duck typing" — if it has the right methods, it works.  
Java requires an explicit contract declaration.

---

## 5. Generics — Type-Safe Collections

```python
# Python — a list can hold anything
items = [1, "two", 3.0, True]   # no error
```

```java
// Java — you declare what type a list holds
List<String> names = new ArrayList<>();
names.add("Alice");
names.add("Bob");
names.add(42);      // COMPILE ERROR — list is String only

List<User> users = new ArrayList<>();
users.add(new User("Alice"));
User first = users.get(0);   // returns User, not Object — no cast needed
```

`<String>`, `<User>`, `<Integer>` are **type parameters** — generics.  
Without generics, every list would return `Object` and you'd need constant casting.  
With generics, the compiler knows what type comes out.

You'll see this constantly in Spring:
```java
List<Note> notes = noteRepository.findByUserId(userId);  // List<Note>, not raw List
Optional<User> user = userRepository.findById(id);       // Optional<User>
ResponseEntity<NoteResponse> response = ...              // ResponseEntity<NoteResponse>
```

---

## 6. Exception Handling — Checked vs Unchecked

This is one area where Java is significantly more complex than Python.

### Python
```python
try:
    result = risky_operation()
except Exception as e:
    print(f"Error: {e}")
```
One type of exception. You can catch or ignore — Python doesn't force you.

### Java: two kinds of exceptions

**Unchecked exceptions** (extend `RuntimeException`) — you CAN catch them but don't HAVE to:
```java
// NullPointerException, IllegalArgumentException, etc.
String text = null;
text.length();   // NullPointerException at runtime — Java doesn't force you to handle this
```

**Checked exceptions** — the compiler FORCES you to handle or declare them:
```java
public void readFile(String path) throws IOException {  // must declare it
    FileReader reader = new FileReader(path);  // FileNotFoundException is checked
    // ...
}

// Caller must handle it:
try {
    readFile("/path/to/file");
} catch (IOException e) {
    System.out.println("File error: " + e.getMessage());
}
```
If you don't handle a checked exception, the code **won't compile**.

**In Spring Boot**: most Spring exceptions are unchecked (`RuntimeException`), so you  
usually only deal with checked exceptions when touching JDBC, file I/O, or JSON parsing.

---

## 7. The `null` Problem and `Optional`

Java's most infamous bug source: `NullPointerException` (NPE).

```java
User user = findUser(id);   // might return null if not found
user.getName();             // NullPointerException if user is null!
```

Java 8 introduced `Optional<T>` to make "might not exist" explicit:
```java
Optional<User> maybeUser = userRepository.findById(id);

// Forces you to handle both cases:
maybeUser.ifPresent(u -> System.out.println(u.getName()));

// Or with a default:
String name = maybeUser.map(User::getName).orElse("Unknown");

// Or check first:
if (maybeUser.isPresent()) {
    User user = maybeUser.get();
}
```

In Spring Data repositories you'll see:
```java
Optional<User> findBySub(String sub);  // returns Optional, not null
```
This is much safer — the caller can't forget to check for "not found".

---

## 8. Modern Java Features (Java 8 through 21)

These are used heavily in Spring Boot. You need to recognise them.

### Lambda expressions (Java 8)
```python
# Python lambda
transform = lambda x: x * 2
nums = list(map(lambda x: x * 2, [1, 2, 3]))
```
```java
// Java lambda
Function<Integer, Integer> transform = x -> x * 2;
List<Integer> nums = List.of(1, 2, 3)
    .stream()
    .map(x -> x * 2)
    .collect(Collectors.toList());
```

### Stream API (Java 8) — like Python list comprehensions
```python
# Python
active_users = [u for u in users if u.is_active()]
names = [u.name for u in active_users]
```
```java
// Java streams
List<String> names = users.stream()
    .filter(u -> u.isActive())
    .map(User::getName)
    .collect(Collectors.toList());
```

### Records (Java 16+) — like Python dataclasses
```python
# Python dataclass
@dataclass
class NoteResponse:
    id: int
    title: str
    body: str
```
```java
// Java record — immutable, auto-generates constructor, getters, equals, hashCode, toString
public record NoteResponse(Long id, String title, String body) {}
```
We'll use records heavily for DTOs (request/response objects).

### `var` keyword (Java 10+)
```java
// Instead of:
List<String> names = new ArrayList<String>();
// You can write:
var names = new ArrayList<String>();  // compiler infers the type
```
Less typing, same type safety. The type is still fixed at compile time.

---

## 9. Maven — The Build Tool

Every Java project has a `pom.xml` — Maven's equivalent of `requirements.txt + Makefile`.

```xml
<!-- pom.xml — Project Object Model -->
<project>
    <groupId>com.vaultapp</groupId>       <!-- like a namespace (your company/project) -->
    <artifactId>vault-api</artifactId>     <!-- the project name -->
    <version>0.0.1-SNAPSHOT</version>     <!-- version -->
    <packaging>jar</packaging>             <!-- output a .jar file -->

    <dependencies>
        <!-- Like: pip install fastapi -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <version>3.3.0</version>
        </dependency>

        <!-- Like: pip install psycopg2 -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>
    </dependencies>
</project>
```

### Key Maven commands
```bash
mvn clean           # delete compiled output (like removing __pycache__)
mvn compile         # compile .java → .class
mvn test            # run tests
mvn package         # compile + test + package into .jar
mvn spring-boot:run # compile + run (like uvicorn app.main:app)
mvn dependency:tree # show all dependencies (like pip show)
```

### Maven coordinates
Every dependency is identified by `groupId:artifactId:version`.  
You find these on Maven Central (mvnrepository.com) — like PyPI but for Java.

---

## 10. Packages — Java's Module System

```python
# Python — directory structure IS the module structure
app/
    routers/
        notes.py        → from app.routers import notes
```

```java
// Java — package declaration at top of every file
package com.vaultapp.notes;        // declares which package this file belongs to

// File: src/main/java/com/vaultapp/notes/NoteController.java
// The directory structure MUST match the package declaration
```

Convention: `com.yourcompany.projectname.featurename`  
For our project: `com.vaultapp.notes`, `com.vaultapp.users`, `com.vaultapp.auth`

---

## Key Terms Glossary

| Term | Meaning |
|---|---|
| JVM | Java Virtual Machine — runs bytecode on any OS |
| Bytecode | Compiled output of Java source — not machine code, not source |
| Static typing | Types known and enforced at compile time |
| Primitive | `int`, `long`, `double`, `boolean` — raw values, not objects |
| Boxing/Unboxing | Auto-converting between `int` and `Integer` |
| Interface | A contract declaring method signatures without implementation |
| Generics | Type parameters like `List<String>` — type-safe containers |
| Checked exception | Exception the compiler forces you to handle |
| RuntimeException | Unchecked — can be ignored (but still crashes at runtime if unhandled) |
| Optional<T> | A container that either holds a value or is empty — avoids null |
| Stream API | Functional-style operations on collections |
| Record | Immutable data class with auto-generated boilerplate |
| pom.xml | Maven's project descriptor and dependency list |
| groupId:artifactId | Maven's way of identifying a library (like PyPI package name) |

---

## What's Next

Phase 02 takes this language knowledge and applies it to databases the **hard way first** — raw JDBC.  
Seeing the pain of JDBC makes Hibernate's value obvious, and Hibernate's patterns make  
Spring Data JPA's magic understandable.
