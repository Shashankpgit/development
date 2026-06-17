# Maven and pom.xml

## What Maven is

Maven is two things in one:
1. **Dependency manager** — downloads libraries from the internet (like pip)
2. **Build tool** — compiles, tests, and packages your code into a JAR

In Python you have:
- `pip` for dependencies
- `requirements.txt` to declare them
- `setup.py` or Makefile for build tasks

In Java, Maven does all three with one tool and one file: `pom.xml`.

---

## pom.xml structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>

    <!-- ── Project identity ──────────────────────────────────── -->
    <groupId>com.vault</groupId>        <!-- your organisation/package namespace -->
    <artifactId>vault-java</artifactId> <!-- your project name -->
    <version>0.0.1-SNAPSHOT</version>   <!-- version (SNAPSHOT = in development) -->
    <packaging>jar</packaging>          <!-- output: a JAR file -->

    <!-- ── Spring Boot parent (inherits defaults) ────────────── -->
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.3.0</version>
    </parent>

    <!-- ── Java version ──────────────────────────────────────── -->
    <properties>
        <java.version>21</java.version>
    </properties>

    <!-- ── Dependencies (like requirements.txt) ──────────────── -->
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <!-- no version needed — inherited from parent -->
        </dependency>
    </dependencies>

    <!-- ── Build plugins ─────────────────────────────────────── -->
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

---

## groupId, artifactId, version

Every library in the Java world is identified by three coordinates:

```
groupId    : com.vault          (your organisation — like a Python package namespace)
artifactId : vault-java         (your project name — like the PyPI package name)
version    : 0.0.1-SNAPSHOT     (current version)
```

When you add a dependency, you use the same three coordinates:
```xml
<dependency>
    <groupId>org.postgresql</groupId>     <!-- who made it -->
    <artifactId>postgresql</artifactId>   <!-- what it is -->
    <version>42.7.3</version>             <!-- which version -->
</dependency>
```

Find any library at: https://mvnrepository.com (the PyPI equivalent for Java).

---

## The parent POM

```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.0</version>
</parent>
```

The parent POM is Spring Boot's master configuration file. By declaring it as
parent, your project inherits:
- Compatible versions for hundreds of libraries (no version conflicts)
- Default compiler settings (Java version, encoding)
- Default build plugin configuration

This is why you don't specify versions for Spring libraries — the parent
already defines the compatible version for each one.

---

## Starter dependencies

Spring Boot provides `starter` dependencies that bundle related libraries:

| Starter | What it includes |
|---|---|
| `spring-boot-starter-web` | Spring MVC + embedded Tomcat + Jackson (JSON) |
| `spring-boot-starter-data-jpa` | JPA + Hibernate + Spring Data |
| `spring-boot-starter-security` | Spring Security |
| `spring-boot-starter-validation` | Bean Validation (JSR-380) |
| `spring-boot-starter-test` | JUnit 5 + Mockito + AssertJ |

Python analogy: instead of pip-installing `fastapi`, `uvicorn`, `starlette`
separately, imagine one `pip install fastapi-bundle` that installs all three
with compatible versions. That is what starters do.

---

## Dependency scope

```xml
<dependency>
    <groupId>com.h2database</groupId>
    <artifactId>h2</artifactId>
    <scope>runtime</scope>    <!-- only needed at runtime, not compile time -->
</dependency>

<dependency>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <scope>provided</scope>   <!-- compile time only, not included in JAR -->
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>       <!-- only for tests, not in production JAR -->
</dependency>
```

No scope (default) = included everywhere (compile + runtime + test).

---

## Maven commands

| Command | Python equivalent | What it does |
|---|---|---|
| `mvn compile` | `python -c "import ast; ast.parse()"` | Compile Java source code |
| `mvn test` | `pytest` | Run unit tests |
| `mvn package` | `pip install -e .` | Build the JAR file |
| `mvn spring-boot:run` | `uvicorn main:app --reload` | Start the application |
| `mvn clean` | — | Delete the `target/` directory |
| `mvn clean package` | — | Clean + build (most common) |
| `mvn dependency:tree` | `pip show <package>` | Show all dependencies |

---

## Where Maven stores downloaded libraries

Maven downloads libraries to `~/.m2/repository/` — the local cache.
Second time you build, libraries come from cache (fast). Same as pip's cache.

---

## The target/ directory

When you run `mvn package`, Maven creates a `target/` directory:
```
target/
├── vault-java-0.0.1-SNAPSHOT.jar   ← your runnable JAR
├── classes/                         ← compiled .class files
└── test-classes/                    ← compiled test .class files
```

Add `target/` to `.gitignore` — it's generated, not source code.

---

## Running the JAR directly

```bash
# Build
mvn clean package

# Run
java -jar target/vault-java-0.0.1-SNAPSHOT.jar
```

The JAR contains everything: your code, all dependencies, and the embedded
Tomcat server. One file, runs anywhere Java 21 is installed.

Python equivalent: `pyinstaller` or Docker image — but in Java this is the
standard way to deploy, no extra tools needed.
