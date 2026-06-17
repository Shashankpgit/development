# Phase 5 — Security (JWT + Keycloak)

## Goal

Validate the same Keycloak JWT tokens the Python backend validates.
The same token that authenticates against the Python backend will authenticate
against the Java backend — same Keycloak realm, same `sub` claim extraction.

---

## How the Python backend handles auth

```python
# vault/backend/app/dependencies.py
def get_current_user(credentials = Depends(bearer_scheme), db = Depends(get_db)):
    payload = _decode_jwt_payload(credentials.credentials)  # decode without verifying sig
    sub = payload.get("sub")                                 # Kong already verified the sig
    user = user_repository.get_by_sub(db, sub)
    if not user:
        user = user_repository.create(db, sub=sub)
    return user
```

Kong (the API gateway) verifies the JWT signature before forwarding to the
Python backend. So the Python backend just decodes the payload without
re-verifying.

**For the Java backend:** same approach. The JWT signature verification happens
at the Kong/ingress layer. The Java backend decodes the payload, extracts `sub`,
and looks up or creates the user.

---

## Step 5.1 — Spring Security filter chain

Read: `docs/java/guide/13-spring-security-jwt.md`

Spring Security processes every HTTP request through a **filter chain** — a
series of filters that run before the request reaches your controller.

```
HTTP Request
    ↓
[Filter 1: CorsFilter]
    ↓
[Filter 2: JwtAuthFilter]   ← we write this
    ↓
[Filter 3: Authorization check]
    ↓
[Your Controller]
```

Our `JwtAuthFilter`:
1. Reads the `Authorization: Bearer <token>` header
2. Decodes the JWT payload (base64, same as Python's `_decode_jwt_payload`)
3. Extracts the `sub` claim
4. Sets the Spring Security authentication context
5. Calls `filterChain.doFilter()` to pass the request to the next filter

```java
@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final UserService userService;

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring(7);
        String sub = extractSub(token);

        if (sub != null) {
            User user = userService.getOrCreateBySubject(sub);
            UsernamePasswordAuthenticationToken auth =
                new UsernamePasswordAuthenticationToken(user, null, List.of());
            SecurityContextHolder.getContext().setAuthentication(auth);
        }

        filterChain.doFilter(request, response);
    }

    private String extractSub(String token) {
        try {
            String[] parts = token.split("\\.");
            String payload = new String(Base64.getUrlDecoder().decode(parts[1]));
            // parse JSON and extract "sub"
            return new ObjectMapper().readTree(payload).get("sub").asText();
        } catch (Exception e) {
            return null;
        }
    }
}
```

---

## Step 5.2 — SecurityConfig

Configure which endpoints require auth and which don't:

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())           // REST APIs don't use CSRF
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))  // no sessions
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/health").permitAll()       // public
                .anyRequest().authenticated()                  // everything else needs JWT
            )
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
```

`SessionCreationPolicy.STATELESS` — Spring does not create HTTP sessions.
Every request must carry the JWT. This matches how REST APIs work (stateless).

---

## Step 5.3 — Reading the current user in controllers

In the Python backend:
```python
def get_notes(current_user: User = Depends(get_current_user)):
    ...
```

In the Java backend, the authenticated user is in the Spring Security context:
```java
@GetMapping
public List<NoteResponse> getNotes() {
    User currentUser = (User) SecurityContextHolder
        .getContext()
        .getAuthentication()
        .getPrincipal();
    return noteService.getNotesForUser(currentUser);
}
```

Or cleaner with `@AuthenticationPrincipal`:
```java
@GetMapping
public List<NoteResponse> getNotes(@AuthenticationPrincipal User currentUser) {
    return noteService.getNotesForUser(currentUser);
}
```

---

## Step 5.4 — Test with the real Keycloak token

Get a token from Keycloak (same way you test the Python backend):
```bash
# Get token from Keycloak
curl -X POST https://vaultpraja.duckdns.org/realms/vault/protocol/openid-connect/token \
  -d "client_id=vault-frontend&grant_type=password&username=test&password=test"
```

Use the `access_token` in Postman against the Java backend.
The `sub` claim is extracted, the user is looked up or created — same behaviour
as the Python backend.

---

## Phase 5 deliverable

The Java backend is fully secured:
- `GET /health` — public, no token needed
- All `/api/*` endpoints — require a valid Keycloak JWT
- The `sub` claim identifies the user
- A user record is created on first login (same as Python backend)
- The same Postman collection with Bearer token passes for both backends

---

## After Phase 5 — what's next

The Java backend has full feature parity with Python. Optional next steps:

| Topic | Why |
|---|---|
| Unit tests (JUnit 5 + Mockito) | Test service layer in isolation |
| Integration tests (Spring Boot Test) | Test full request cycle |
| Docker image for vault-java | Package the JAR the same way as vault-api |
| GitHub Actions CI | Build and push image on commit |
| Deploy to GKE | Run alongside the Python backend |
