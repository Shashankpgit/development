# Phase 06 — Spring Boot
## "What does auto-configuration really mean?"

> Spring Framework solved JEE's problems.
> But configuring Spring itself became a new problem.
> Spring Boot's answer: "Stop configuring. Start running."

---

## The Problem Spring Boot Was Solving (2014)

By 2012, Spring Framework was the standard for Java backends.  
But setting up a new Spring project required:

```xml
<!-- applicationContext.xml — had to write ALL of this -->
<beans>
    <!-- DataSource (database connection pool) -->
    <bean id="dataSource" class="org.apache.commons.dbcp.BasicDataSource">
        <property name="driverClassName" value="org.postgresql.Driver"/>
        <property name="url" value="jdbc:postgresql://localhost:5432/vault"/>
        <property name="username" value="vault"/>
        <property name="password" value="secret"/>
        <property name="maxActive" value="10"/>
    </bean>

    <!-- EntityManagerFactory (Hibernate setup) -->
    <bean id="entityManagerFactory"
          class="org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean">
        <property name="dataSource" ref="dataSource"/>
        <property name="packagesToScan" value="com.vaultapp"/>
        <property name="jpaVendorAdapter">
            <bean class="org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter"/>
        </property>
        <property name="jpaProperties">
            <props>
                <prop key="hibernate.dialect">
                    org.hibernate.dialect.PostgreSQLDialect
                </prop>
            </props>
        </property>
    </bean>

    <!-- Transaction Manager -->
    <bean id="transactionManager"
          class="org.springframework.orm.jpa.JpaTransactionManager">
        <property name="entityManagerFactory" ref="entityManagerFactory"/>
    </bean>

    <!-- Enable @Transactional -->
    <tx:annotation-driven transaction-manager="transactionManager"/>

    <!-- Component Scanning -->
    <context:component-scan base-package="com.vaultapp"/>

    <!-- Spring MVC -->
    <mvc:annotation-driven/>

    <!-- Jackson (JSON serialization) -->
    <bean class="org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter">
        <property name="messageConverters">
            <list>
                <bean class="org.springframework.http.converter.json.MappingJackson2HttpMessageConverter"/>
            </list>
        </property>
    </bean>
</beans>
```

That's just the framework wiring — before writing a single line of business code.

**Spring Boot's observation**: *"Almost every project needs a DataSource, a TransactionManager,  
Jackson for JSON, and component scanning. Why does every project configure these from scratch?"*

---

## The Core Ideas of Spring Boot

### 1. Auto-Configuration

Spring Boot looks at what's on your classpath and auto-configures sensible defaults.

```
You add to pom.xml:                    Spring Boot automatically configures:
──────────────────                     ────────────────────────────────────
spring-boot-starter-web           →    DispatcherServlet + Jackson + Tomcat
spring-boot-starter-data-jpa      →    EntityManagerFactory + TransactionManager
postgresql (driver jar)           →    PostgreSQL JDBC connection
spring-boot-starter-security      →    Security filter chain with defaults
```

It detects: "I see a PostgreSQL driver on the classpath AND a `spring.datasource.url` in config.  
I'll create a `DataSource` bean using HikariCP."

You don't ask for this. Spring Boot does it if the conditions are met.

### 2. Convention Over Configuration

Spring Boot has opinionated defaults. Accept them and write less code.  
Override only what you need to change.

```yaml
# application.yml — 6 lines instead of 60 lines of XML
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/vault
    username: vault
    password: secret
  jpa:
    hibernate:
      ddl-auto: validate   # just these 6 lines → full JPA stack auto-configured
```

### 3. Embedded Server — No WAR, No App Server

Old way: build a WAR file → deploy to a running Tomcat/JBoss server.  
Spring Boot: **Tomcat is embedded inside your JAR**.

```
java -jar vault-api-1.0.jar
     │
     ├── Starts embedded Tomcat on port 8080
     ├── Loads your application context
     └── Ready to handle requests

No separate server to manage. One file to deploy.
```

The JAR contains everything: your code + Spring + Tomcat + all dependencies.  
This is called a "fat JAR" or "uber JAR".

```
vault-api-1.0.jar
  ├── com/vaultapp/...          ← your code
  ├── org/springframework/...    ← Spring Framework classes
  ├── org/apache/tomcat/...      ← embedded Tomcat
  ├── com/fasterxml/jackson/...  ← Jackson
  └── org/postgresql/...         ← PostgreSQL driver
```

Deploy by copying one file. Run with `java -jar`. Zero server installation.  
This is exactly why Docker works so cleanly with Spring Boot.

---

## @SpringBootApplication — Three Annotations in One

```java
@SpringBootApplication
public class VaultApiApplication {
    public static void main(String[] args) {
        SpringApplication.run(VaultApiApplication.class, args);
    }
}
```

`@SpringBootApplication` is shorthand for:
```java
@Configuration           // This class can define @Bean methods
@EnableAutoConfiguration // "Enable Spring Boot's auto-configuration magic"
@ComponentScan           // Scan this package for @Component, @Service, etc.
```

`SpringApplication.run(...)`:
1. Creates the `ApplicationContext` (the IoC container)
2. Runs auto-configuration (creates DataSource, EntityManagerFactory, etc.)
3. Starts embedded Tomcat
4. Deploys DispatcherServlet
5. Prints the startup banner and logs

The `main()` method is the standard Java entry point. Spring Boot didn't invent this —  
but earlier Spring apps were deployed as WARs (no `main()` method; the app server called init).

---

## Spring Boot Starters — Curated Dependency Sets

Instead of hunting for compatible library versions yourself, Spring Boot provides "starters" —  
pre-packaged sets of dependencies known to work together.

```xml
<!-- pom.xml — ONE starter brings many libraries -->

<!-- Web: brings Spring MVC + Jackson + embedded Tomcat -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>

<!-- JPA: brings Spring Data JPA + Hibernate + HikariCP -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>

<!-- Security: brings Spring Security -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>

<!-- Test: brings JUnit + Mockito + Spring Test support -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
```

Note: **no version numbers** on starters. The `spring-boot-starter-parent` POM  
(which you inherit in your `pom.xml`) manages all versions for compatibility.

---

## application.yml — The Configuration File

Spring Boot reads `src/main/resources/application.yml` (or `.properties`).

```yaml
# application.yml

server:
  port: 8000           # default is 8080 — we use 8000 to match Python API

spring:
  application:
    name: vault-api

  datasource:
    url: jdbc:postgresql://localhost:5432/vault
    username: ${DB_USERNAME}       # from environment variable
    password: ${DB_PASSWORD}       # from environment variable
    hikari:
      maximum-pool-size: 10        # HikariCP settings
      minimum-idle: 2

  jpa:
    hibernate:
      ddl-auto: validate          # validate schema but don't auto-create
    show-sql: false               # true = print SQL to logs (useful for debugging)
    properties:
      hibernate:
        format_sql: true

  flyway:
    enabled: true                 # run migrations on startup

app:
  encryption-key: ${VAULT_ENCRYPTION_KEY}   # custom config for our app

logging:
  level:
    com.vaultapp: DEBUG            # debug logs for our package
    org.hibernate.SQL: WARN        # suppress Hibernate SQL logs in prod
```

Environment variables override `application.yml` values.  
Docker/Kubernetes injects them. `.env` files work in development.

### Profiles — different config for different environments

```yaml
# application.yml — shared config
server:
  port: 8000

---
# application-dev.yml — local development overrides
spring:
  config:
    activate:
      on-profile: dev
  jpa:
    show-sql: true     # show SQL in dev
    hibernate:
      ddl-auto: update  # auto-update schema in dev

---
# application-prod.yml — production overrides
spring:
  config:
    activate:
      on-profile: prod
  jpa:
    show-sql: false
    hibernate:
      ddl-auto: validate  # never auto-change schema in prod
```

Activate with: `java -jar app.jar --spring.profiles.active=prod`  
Or in Docker: `SPRING_PROFILES_ACTIVE=prod`

---

## Spring Boot Actuator — Production Observability

Spring Boot Actuator adds operational endpoints for free:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
```

Auto-configured endpoints:
```
GET /actuator/health    → {"status":"UP", "db":{"status":"UP"}}
GET /actuator/info      → app name, version, build info
GET /actuator/metrics   → JVM memory, HTTP request counts, etc.
```

Our custom `/health` endpoint will wrap or extend this.  
Kubernetes liveness/readiness probes often point to `/actuator/health`.

---

## How Auto-Configuration Works (Under the Hood)

You don't need to know this to use Spring Boot, but understanding it removes the mystery.

Spring Boot ships with hundreds of `@Configuration` classes inside `spring-boot-autoconfigure.jar`.  
Each one is conditional — only activates if certain conditions are met.

```java
// Inside spring-boot-autoconfigure.jar (you don't write this, it's Spring Boot's code)
@Configuration
@ConditionalOnClass(HikariDataSource.class)      // "only if HikariCP is on classpath"
@ConditionalOnMissingBean(DataSource.class)       // "only if no DataSource bean defined yet"
@EnableConfigurationProperties(DataSourceProperties.class)
public class DataSourceAutoConfiguration {
    
    @Bean
    public DataSource dataSource(DataSourceProperties props) {
        HikariDataSource ds = new HikariDataSource();
        ds.setJdbcUrl(props.getUrl());
        ds.setUsername(props.getUsername());
        ds.setPassword(props.getPassword());
        return ds;
    }
}
```

When you add `spring-boot-starter-data-jpa` to `pom.xml`:
1. HikariCP lands on the classpath
2. `@ConditionalOnClass(HikariDataSource.class)` → true
3. You haven't defined your own DataSource bean
4. `@ConditionalOnMissingBean(DataSource.class)` → true
5. Spring Boot creates a `HikariDataSource` from your `application.yml` values
6. You get a working database connection pool without writing a single `@Bean` method

You can **override** any auto-configured bean by simply defining your own:
```java
@Configuration
public class DatabaseConfig {
    
    @Bean  // This bean now REPLACES the auto-configured one
    public DataSource dataSource() {
        // your custom DataSource setup
    }
}
```

---

## Spring Boot DevTools — Hot Reload

In development, you don't want to restart the application after every code change.

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-devtools</artifactId>
    <scope>runtime</scope>
    <optional>true</optional>
</dependency>
```

With DevTools:
- Save a Java file → application restarts in ~1 second (not 10 seconds)
- Change a static resource (HTML, CSS) → browser auto-refreshes
- Automatically excluded from production builds (`<optional>true</optional>`)

Like Flask's `debug=True` or FastAPI's `--reload` with uvicorn.

---

## Key Terms

| Term | Meaning |
|---|---|
| Auto-configuration | Spring Boot automatically creates beans based on classpath contents |
| `@SpringBootApplication` | `@Configuration` + `@EnableAutoConfiguration` + `@ComponentScan` |
| Starter | A curated set of dependencies (e.g., `spring-boot-starter-web`) |
| Fat JAR / Uber JAR | A single JAR containing your code + all dependencies + embedded server |
| Embedded Server | Tomcat/Jetty/Netty bundled inside the JAR — no separate server needed |
| `application.yml` | Spring Boot's centralised configuration file |
| Profile | Named configuration variant (dev, prod, test) activated at runtime |
| `@Conditional` | Annotation that activates a bean only when certain conditions are true |
| Actuator | Built-in operational endpoints: `/health`, `/metrics`, `/info` |
| DevTools | Development-only hot reload tool |
| HikariCP | The connection pool Spring Boot uses by default (fastest Java pool) |

---

## What's Next

Phase 07 covers Spring Data JPA — building on Hibernate (Phase 03) with Spring Boot's  
auto-configuration. After understanding raw Hibernate, you'll see exactly what Spring Data JPA  
adds: the Repository pattern and query generation from method names.
