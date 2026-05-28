# Phase 04 — Java Web: Servlets & the JEE Era
## "How did Java handle HTTP before frameworks? Why did EJB fail?"

> This phase explains the original Java web model (Servlets) and the enterprise era (JEE/EJB).
> You will NOT use any of this directly in Spring Boot.
> But Spring MVC (which you WILL use) is built on Servlets under the hood,
> and Spring's entire reason for existing is to replace the EJB model.

---

## Part 1 — Servlets: Java's Original HTTP Handler (1996)

### What is a Servlet?

When a browser makes an HTTP request, something on the server receives it and generates a response.  
In Java, that something is a **Servlet**.

```
Browser → HTTP Request
              ↓
         Web Server (Tomcat, Jetty)
              ↓
         Servlet Container
              ↓
         Your Servlet (Java class)
              ↓
         HTTP Response → Browser
```

A Servlet is just a Java class that extends `HttpServlet`:

```java
import jakarta.servlet.http.*;
import jakarta.servlet.*;
import java.io.*;

public class NotesServlet extends HttpServlet {

    // Called when browser sends GET /notes
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        // Read query parameters
        String userId = request.getParameter("userId");

        // Fetch data (using JDBC/Hibernate)
        List<Note> notes = noteService.getNotesForUser(Long.parseLong(userId));

        // Write response (manually!)
        response.setContentType("application/json");
        response.setStatus(HttpServletResponse.SC_OK);
        PrintWriter out = response.getWriter();
        out.println("[{\"id\":1,\"title\":\"My Note\"}]");   // manual JSON string
        out.flush();
    }

    // Called when browser sends POST /notes
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        // read request body, parse it, save to DB, write response...
    }
}
```

And you had to register it in `web.xml`:
```xml
<!-- web.xml — Servlet configuration file -->
<servlet>
    <servlet-name>NotesServlet</servlet-name>
    <servlet-class>com.vaultapp.NotesServlet</servlet-class>
</servlet>
<servlet-mapping>
    <servlet-name>NotesServlet</servlet-name>
    <url-pattern>/notes</url-pattern>
</servlet-mapping>
```

### The Servlet Lifecycle

The container manages the Servlet's life:

```
Container starts → init() called (once)
                       │
              Per request:
                ┌─────────────────────────────────┐
                │  1. Container calls service()   │
                │  2. service() calls doGet/doPost │
                │  3. Response is written          │
                └─────────────────────────────────┘
Container shuts down → destroy() called (once)
```

One important thing: **a single Servlet instance handles all requests**.  
This means your Servlet must be **thread-safe** — multiple threads call `doGet()` concurrently.  
You must not store request-specific state in instance variables.

### The Problem with Raw Servlets

Look at the doGet code above. Notice what's missing compared to FastAPI:
- No automatic JSON parsing/serialization (you write raw strings)
- No URL path parameters (`/notes/42` → you extract `42` yourself)
- No routing (one Servlet per URL pattern, registered in XML)
- No automatic request body deserialization
- No middleware concept

Building a REST API with raw Servlets = writing an enormous amount of plumbing code.

This is why frameworks like **Spring MVC** and **Struts** emerged — they sat on top of Servlets  
and provided all the things Servlets were missing.

### Spring MVC runs on top of Servlets

Even today, Spring MVC's entire routing goes through one special Servlet:

```
HTTP Request
     ↓
DispatcherServlet (Spring's "Front Controller" Servlet)
     ↓  routes to
@RestController method (your code)
     ↓  serialises response to JSON (Jackson)
HTTP Response
```

Spring Boot auto-configures this. You never see `DispatcherServlet` or `web.xml`.  
But they exist — Spring just hides them.

---

## Part 2 — JEE/J2EE: Enterprise Java (1999-2006)

### What JEE Was Trying to Solve

By the late 1990s, enterprises were building large, distributed systems in Java.  
They needed:
- Transaction management across multiple databases
- Remote procedure calls between servers
- Connection pooling
- Security
- Message queuing

Sun Microsystems created **J2EE (Java 2 Platform, Enterprise Edition)** to standardise all of this.  
Later renamed to **JEE**, then **Jakarta EE**.

The key components:
- **EJB (Enterprise JavaBeans)** — for business logic, transactions, remoting
- **JNDI (Java Naming and Directory Interface)** — service discovery
- **JMS (Java Message Service)** — messaging
- **JTA (Java Transaction API)** — distributed transactions
- **Servlets/JSP** — the web layer

### Application Servers

JEE apps did not run in a simple web server. They ran in **Application Servers**:

```
JEE Application Server (JBoss, WebLogic, WebSphere, GlassFish)
  ├── EJB Container
  │     ├── Manages EJBs (your business logic components)
  │     ├── Handles transactions
  │     └── Handles remoting (calling EJBs on other servers)
  ├── Servlet Container (Tomcat embedded inside)
  │     └── Your web layer (Servlets/JSP)
  ├── JMS Provider
  │     └── Message queues
  └── JNDI Registry
        └── Service lookup
```

You packaged your application as a **WAR** (Web Archive) or **EAR** (Enterprise Archive)  
and deployed it into the running application server.

```
war/
  ├── WEB-INF/
  │     ├── web.xml          ← Servlet configuration
  │     ├── ejb-jar.xml      ← EJB configuration
  │     └── classes/
  │           └── your compiled .class files
  └── index.jsp
```

---

## The EJB Nightmare (EJB 2.x)

EJB (Enterprise JavaBeans) 2.x is probably the most infamous API in Java history.  
It was complex, slow, and painful. Here's why:

### A simple "note service" required 4 files

**1. The Remote Interface** (how it's called from other JVMs)
```java
public interface NoteService extends EJBObject {
    List<Note> getNotesForUser(long userId) throws RemoteException;
    void createNote(Note note) throws RemoteException;
}
```

**2. The Home Interface** (how you create/find instances of the bean)
```java
public interface NoteServiceHome extends EJBHome {
    NoteService create() throws CreateException, RemoteException;
}
```

**3. The Implementation Class**
```java
public class NoteServiceBean implements SessionBean {
    private SessionContext ctx;

    public void setSessionContext(SessionContext ctx) {
        this.ctx = ctx;
    }
    public void ejbCreate() {}
    public void ejbRemove() {}
    public void ejbActivate() {}
    public void ejbPassivate() {}

    public List<Note> getNotesForUser(long userId) throws RemoteException {
        // actual logic — but you can't just call new Repository() !
        // you have to use JNDI to find other services
        try {
            InitialContext ctx = new InitialContext();
            NoteDAOHome daoHome = (NoteDAOHome) ctx.lookup("java:comp/env/ejb/NoteDAO");
            NoteDAO dao = daoHome.create();
            return dao.findByUserId(userId);
        } catch (NamingException | CreateException e) {
            throw new RemoteException("Failed", e);
        }
    }
}
```

**4. Deployment descriptor (XML)**
```xml
<!-- ejb-jar.xml — another XML file to wire everything together -->
<session>
    <ejb-name>NoteService</ejb-name>
    <home>com.vaultapp.NoteServiceHome</home>
    <remote>com.vaultapp.NoteService</remote>
    <ejb-class>com.vaultapp.NoteServiceBean</ejb-class>
    <session-type>Stateless</session-type>
    <transaction-type>Container</transaction-type>
</session>
```

**The result**: 4 files (2 interfaces + 1 implementation + 1 XML) for what would later be  
a single Spring `@Service` class with 10 lines.

### Why was it so bad?

1. **Impossible to test** — EJBs required an actual application server to run.  
   Unit testing meant starting a JBoss instance. Slow feedback loops.

2. **XML configuration hell** — every component, every transaction, every dependency  
   declared in verbose XML files. Change a class name → update 3 XML files.

3. **No POJO (Plain Old Java Object) support** — you had to extend/implement EJB-specific  
   interfaces. Your domain classes were tightly coupled to the framework.

4. **Lookup via JNDI** — instead of passing dependencies directly, you looked them up  
   by string name from a registry. Typos were runtime errors, not compile errors.

5. **Performance** — EJBs had enormous overhead. The container intercepted every method call.

---

## The Backlash and Rod Johnson's Solution (2002)

In 2002, Rod Johnson wrote a book: **"Expert One-on-One J2EE Design and Development"**.

His argument:
> *Most enterprise Java applications don't need 95% of what JEE provides.  
> All the complexity of EJBs was introduced to solve problems that most applications don't have.  
> We can build better enterprise applications with plain Java objects and a lightweight container.*

The code he included in that book eventually became **Spring Framework** (released 2003).

Spring's key insight:
- **Use POJOs (Plain Old Java Objects)** — your classes don't extend/implement framework classes
- **Dependency Injection** — instead of JNDI lookup, let a container inject dependencies
- **AOP (Aspect-Oriented Programming)** — handle cross-cutting concerns (transactions, logging) without polluting business code
- **Run anywhere** — no application server required, works in a simple Tomcat

The EJB equivalent in Spring (post-2003):
```java
// Spring — one class, no XML, testable in isolation
@Service
public class NoteService {
    
    private final NoteRepository noteRepository;  // injected by Spring, no JNDI
    
    public NoteService(NoteRepository noteRepository) {
        this.noteRepository = noteRepository;
    }
    
    @Transactional  // replaces all the EJB transaction XML
    public List<Note> getNotesForUser(long userId) {
        return noteRepository.findByUserId(userId);
    }
}
```

4 files became 1. Hundreds of lines became 15.

---

## Part 3 — EJB 3.0: JEE Learns From Spring (2006)

Seeing Spring's popularity, Sun released **EJB 3.0** which borrowed heavily from Spring:
- POJOs instead of mandatory interface implementation
- Annotations instead of XML (`@Stateless`, `@Transactional`)
- CDI (Contexts and Dependency Injection) — JEE's version of Spring's DI

```java
// EJB 3.0 — much cleaner than EJB 2.x
@Stateless                         // lightweight session bean
@TransactionManagement             // container-managed transactions
public class NoteService {
    
    @EJB                           // injection (like Spring @Autowired)
    private NoteDAO noteDAO;
    
    public List<Note> getNotesForUser(long userId) {
        return noteDAO.findByUserId(userId);
    }
}
```

But by 2006, Spring had won the hearts of Java developers.  
EJB 3.0 came too late. The ecosystem had moved to Spring.

---

## Where We Are Now

Today's landscape:

```
Legacy (still exists in old codebases)    Modern
─────────────────────────────────────    ─────────────────
EJB 2.x + XML + Application Server       Spring Boot + embedded Tomcat
WAR deployment                           JAR deployment ("fat JAR")
JNDI lookup                              Constructor injection
XML configuration                        application.yml + annotations
Heavyweight (500MB+ server)              Lightweight (~50MB JAR)
```

**Jakarta EE** (the modern JEE) has largely adopted Spring Boot's ideas.  
Quarkus and Micronaut (newer frameworks) are also Jakarta EE but with cloud-native focus.

In the Java industry today, **Spring Boot is the dominant choice for new projects**.

---

## Key Terms

| Term | Meaning |
|---|---|
| Servlet | Java class that handles HTTP requests (`doGet`, `doPost`) |
| Servlet Container | Runs Servlets (Tomcat, Jetty) |
| DispatcherServlet | Spring's single Servlet that routes to `@Controller` methods |
| WAR | Web Application Archive — deployed to an app server |
| EAR | Enterprise Archive — WAR + EJBs + other JEE components |
| JEE / J2EE | Java Enterprise Edition — the official enterprise Java spec |
| Jakarta EE | JEE renamed after Oracle transferred it to Eclipse Foundation |
| EJB | Enterprise JavaBeans — JEE's component model (2.x was notorious) |
| Application Server | Runs JEE apps (JBoss, WebLogic, GlassFish) |
| JNDI | Service registry — look up resources by string name |
| POJO | Plain Old Java Object — no framework interfaces required |
| CDI | Contexts and Dependency Injection — JEE's answer to Spring DI |

---

## What's Next

Phase 05 is Spring Framework Core — the solution to everything described in this phase.  
We'll go deep on Dependency Injection, the IoC container, AOP, and Spring MVC.  
This is the most important conceptual phase for understanding how Spring Boot works.
