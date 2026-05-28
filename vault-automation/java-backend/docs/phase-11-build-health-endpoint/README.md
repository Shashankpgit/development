# Phase 11 — Build: Health Endpoint
## "First controller, first DTO, first real test"

> Goal: build /health that returns {"status":"ok","database":"connected"}
> Concepts in action: @RestController, Record DTO, ResponseEntity, @ControllerAdvice

---

## What Gets Built

```
com/vaultapp/health/
  HealthController.java     ← @RestController
  HealthResponse.java       ← Record DTO
```

```
com/vaultapp/shared/
  GlobalExceptionHandler.java   ← handles all exceptions from all controllers
  ErrorResponse.java            ← Record DTO for errors
```

---

## Files to Write

### HealthResponse.java
```java
package com.vaultapp.health;

public record HealthResponse(String status, String database) {}
```

### HealthController.java
```java
package com.vaultapp.health;

@RestController
public class HealthController {
    
    private final DatabaseHealthChecker dbHealthChecker;
    
    public HealthController(DatabaseHealthChecker dbHealthChecker) {
        this.dbHealthChecker = dbHealthChecker;
    }
    
    @GetMapping("/health")
    public ResponseEntity<HealthResponse> health() {
        boolean dbOk = dbHealthChecker.isHealthy();
        HealthResponse response = new HealthResponse(
            "ok",
            dbOk ? "connected" : "unreachable"
        );
        HttpStatus status = dbOk ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE;
        return ResponseEntity.status(status).body(response);
    }
}
```

### DatabaseHealthChecker.java
```java
package com.vaultapp.health;

@Component
public class DatabaseHealthChecker {
    
    private final DataSource dataSource;   // HikariCP DataSource, auto-configured
    
    public DatabaseHealthChecker(DataSource dataSource) {
        this.dataSource = dataSource;
    }
    
    public boolean isHealthy() {
        try (Connection conn = dataSource.getConnection()) {
            return conn.isValid(1);   // 1 second timeout
        } catch (SQLException e) {
            return false;
        }
    }
}
```

---

## Questions This Phase Answers

1. Why does `@GetMapping("/health")` work without registering anything?  
   → `@RestController` + `@ComponentScan` + Spring MVC auto-configuration

2. Why does returning a Record automatically become JSON?  
   → Jackson `HttpMessageConverter` serialises any Java object to JSON

3. Why does `ResponseEntity.status(503).body(response)` return 503?  
   → `ResponseEntity` gives you explicit HTTP status control

4. Why is `DataSource` injected rather than created?  
   → It's an auto-configured bean — Spring Boot + HikariCP + `application.yml`

---

## Deliverable

```bash
# Database running:
curl localhost:8000/health
# {"status":"ok","database":"connected"}

# Database down:
curl localhost:8000/health
# HTTP 503 {"status":"ok","database":"unreachable"}
```
