# Java Backend — Personal Vault API
## Master Teaching Plan

> **Philosophy**: You don't just learn Spring Boot. You learn WHY Spring Boot exists,  
> by seeing what problems it replaced. Every tool is a reaction to a previous pain.  
> Understanding the evolution makes the current tool make deep sense.

---

## The Journey

```
1990s         2000s              2003         2014         Today
  │              │                  │            │             │
JDBC          Servlets          Spring       Spring         You are
(raw SQL)     JEE / EJB         Framework    Boot           here
(pain)        (xml hell)        (sanity)     (magic)
```

We walk this path so that when Spring Boot does something automatically,  
you know exactly what problem it is silently solving for you.

---

## Phases at a Glance

### Learning Phases (understand before you build)

| # | Phase | Core Question |
|---|---|---|
| 01 | [Java Foundations](phase-01-java-foundations/README.md) | How is Java fundamentally different from Python? |
| 02 | [JDBC — Raw Database Access](phase-02-jdbc-raw-database-access/README.md) | What was Java DB access before ORMs? What pain did it cause? |
| 03 | [Hibernate ORM](phase-03-hibernate-orm/README.md) | How did Hibernate solve JDBC's problems? What is JPA? |
| 04 | [Java Web — Servlet & JEE Era](phase-04-java-web-servlet-jee/README.md) | How did Java handle HTTP before frameworks? Why did EJB fail? |
| 05 | [Spring Framework Core](phase-05-spring-framework-core/README.md) | What is IoC/DI? How did Spring replace JEE complexity? |
| 06 | [Spring Boot](phase-06-spring-boot/README.md) | What does "auto-configuration" really mean? |
| 07 | [Spring Data JPA](phase-07-spring-data-jpa/README.md) | How does Spring Data build on Hibernate? What is the repository pattern? |
| 08 | [Spring Web & REST](phase-08-spring-web-rest/README.md) | Controllers, DTOs, validation, exception handling |
| 09 | [Spring Security](phase-09-spring-security/README.md) | The filter chain, JWT decoding, SecurityContext |

### Build Phases (apply what you learned)

| # | Phase | What Gets Built |
|---|---|---|
| 10 | [Project Setup](phase-10-build-project-setup/README.md) | Spring Initializr, project structure, run first time |
| 11 | [Health Endpoint](phase-11-build-health-endpoint/README.md) | `/health` — first controller, first DTO, first run |
| 12 | [Database Layer](phase-12-build-database-layer/README.md) | PostgreSQL + Flyway migrations + User entity + repository |
| 13 | [Notes API](phase-13-build-notes-api/README.md) | Full CRUD — entity, service, controller, validation |
| 14 | [Auth Layer](phase-14-build-auth-layer/README.md) | JWT filter, SecurityContext, `@CurrentUser` |
| 15 | [Passwords API](phase-15-build-passwords-api/README.md) | AES-256 encryption, password entries CRUD |
| 16 | [Docker & CI/CD](phase-16-build-docker-cicd/README.md) | Multi-stage Dockerfile, GitHub Actions → GHCR |

---

## How to Read Each Phase

Every phase file has the same structure:

```
## The Problem           ← what was broken before this existed
## The Concept           ← the idea, explained clearly
## How It Works          ← mechanics, with diagrams and code examples
## Python Parallel       ← "this is like X in FastAPI"
## Why This Matters      ← what Spring Boot does with this later
## Key Terms             ← a glossary for this phase
```

---

## Tools Required (before Phase 10)

Install these before the build phases start:

```bash
# JDK 21 (LTS)
java -version    # must say 21

# Maven 3.9+
mvn -version

# Or just use IntelliJ IDEA — it ships with both
```

---

## Mindset

> In Python you write 10 lines to get a working API endpoint.  
> In Java you write 50.  
> After learning Spring Boot, you'll understand that those 50 lines give you  
> things that Python's 10 lines don't — and you'll know exactly which trade-off  
> is worth it for which situation.
