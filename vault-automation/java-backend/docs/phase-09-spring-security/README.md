# Phase 09 — Spring Security
## "The filter chain, JWT decoding, and SecurityContext"

> Spring Security is the most configuration-heavy part of Spring Boot.
> But since Kong handles JWT signature verification for us,
> our implementation is actually simple: decode JWT → get sub → store user.
> This phase separates what Spring Security IS from what we NEED it to do.

---

## Part 1 — What Spring Security Is

Spring Security is a framework that handles:
1. **Authentication** — who are you? (verify identity)
2. **Authorization** — what are you allowed to do? (check permissions)
3. **Protection** — CSRF, session fixation, clickjacking, etc.

By default, when you add `spring-boot-starter-security`, Spring:
- Requires login for ALL endpoints
- Generates a random password (printed in logs)
- Shows a default login form

In production, you configure who can do what and how authentication works.

---

## Part 2 — The Security Filter Chain

Every HTTP request passes through a chain of security filters BEFORE reaching your controller.

```
HTTP Request
     │
     ▼
SecurityContextPersistenceFilter   ← load existing SecurityContext
     │
     ▼
UsernamePasswordAuthenticationFilter  ← handle login forms (we don't use this)
     │
     ▼
BasicAuthenticationFilter          ← handle Basic auth (we don't use this)
     │
     ▼
[OUR CUSTOM FILTER]                ← JwtAuthenticationFilter (we write this)
     │
     ▼
ExceptionTranslationFilter         ← turn security exceptions into HTTP responses
     │
     ▼
FilterSecurityInterceptor          ← check if user has permission for this URL
     │
     ▼
DispatcherServlet → @RestController
```

The filter chain is a list of `javax.servlet.Filter` objects.  
Each filter can:
- Let the request pass to the next filter
- Short-circuit the chain (return a response without reaching the controller)
- Modify the request or response

---

## Part 3 — SecurityContext and SecurityContextHolder

The **SecurityContext** is a thread-local storage for "who is currently logged in".

```
Thread 1 (handling request from Alice):
  SecurityContextHolder → SecurityContext → Authentication{user: Alice, roles: [USER]}

Thread 2 (handling request from Bob):
  SecurityContextHolder → SecurityContext → Authentication{user: Bob, roles: [ADMIN]}
```

Each thread has its own `SecurityContext`. They don't share.

```java
// Store authenticated user (done in our JWT filter)
Authentication auth = new UsernamePasswordAuthenticationToken(
    user,       // principal (the User object)
    null,       // credentials (not needed after authentication)
    List.of()   // granted authorities (roles — we don't use roles)
);
SecurityContextHolder.getContext().setAuthentication(auth);

// Retrieve current user (done in controllers or services)
Authentication auth = SecurityContextHolder.getContext().getAuthentication();
User currentUser = (User) auth.getPrincipal();
```

After the request is complete, the `SecurityContextPersistenceFilter` clears the context.

---

## Part 4 — Our JWT Authentication Flow

Since Kong validates the JWT signature before requests reach us, our job is simpler:

```
HTTP Request with Authorization: Bearer <jwt>
     │
     ▼
JwtAuthenticationFilter (we write this)
     │
     ├── Read Authorization header
     ├── Check it starts with "Bearer "
     ├── Extract the JWT string
     ├── Decode the payload (base64 — no signature verification needed)
     ├── Extract "sub" claim
     ├── Find or create User in DB (by sub)
     ├── Store User in SecurityContextHolder
     │
     ▼
Controller method — User is available via SecurityContextHolder
```

No signature verification here. Kong already did that.

---

## Part 5 — Writing the JWT Filter

```java
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    
    private final UserRepository userRepository;
    
    public JwtAuthenticationFilter(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
    
    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        
        // 1. Read the Authorization header
        String header = request.getHeader("Authorization");
        
        // 2. If no header or wrong format, skip auth (will be rejected by security rules)
        if (header == null || !header.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);   // pass to next filter
            return;
        }
        
        // 3. Extract the JWT
        String token = header.substring(7);   // "Bearer " is 7 characters
        
        // 4. Decode the payload (base64url decode the middle part)
        try {
            String sub = extractSubFromJwt(token);
            
            // 5. Find or create user
            User user = userRepository.findBySub(sub)
                .orElseGet(() -> userRepository.save(new User(sub)));
            
            // 6. Store in SecurityContext
            UsernamePasswordAuthenticationToken authentication =
                new UsernamePasswordAuthenticationToken(
                    user,            // principal
                    null,            // credentials
                    List.of()        // no roles
                );
            SecurityContextHolder.getContext().setAuthentication(authentication);
            
        } catch (Exception e) {
            // JWT decode failed — don't set authentication
            // The request will hit the controller unauthenticated
            // SecurityConfig will reject it with 401
        }
        
        // 7. Continue to the next filter (and eventually the controller)
        filterChain.doFilter(request, response);
    }
    
    private String extractSubFromJwt(String token) {
        // JWT = header.payload.signature (all base64url encoded)
        String[] parts = token.split("\\.");
        if (parts.length != 3) {
            throw new IllegalArgumentException("Invalid JWT format");
        }
        
        // Decode the payload (middle part)
        String payloadJson = new String(
            Base64.getUrlDecoder().decode(padBase64(parts[1]))
        );
        
        // Parse JSON and extract "sub"
        // Using Jackson's ObjectMapper:
        ObjectMapper mapper = new ObjectMapper();
        JsonNode payload = mapper.readTree(payloadJson);
        String sub = payload.get("sub").asText();
        
        if (sub == null || sub.isBlank()) {
            throw new IllegalArgumentException("JWT missing 'sub' claim");
        }
        return sub;
    }
    
    private String padBase64(String base64url) {
        // base64url doesn't include padding ('=') — add it back
        int padding = 4 - (base64url.length() % 4);
        if (padding != 4) {
            return base64url + "=".repeat(padding);
        }
        return base64url;
    }
}
```

`OncePerRequestFilter` is a Spring-provided base class that guarantees the filter  
runs exactly once per request (important for async dispatch scenarios).

---

## Part 6 — Security Configuration

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    
    private final JwtAuthenticationFilter jwtFilter;
    
    public SecurityConfig(JwtAuthenticationFilter jwtFilter) {
        this.jwtFilter = jwtFilter;
    }
    
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            // Disable CSRF — REST APIs use tokens, not session cookies
            .csrf(csrf -> csrf.disable())
            
            // Stateless — no HTTP session (JWT is our state)
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            
            // Which endpoints need auth?
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/health", "/actuator/**").permitAll()  // public
                .anyRequest().authenticated()                            // everything else needs auth
            )
            
            // How to respond to unauthenticated requests?
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint((request, response, exception) -> {
                    response.setStatus(401);
                    response.setContentType("application/json");
                    response.getWriter().write("{\"code\":\"unauthorized\",\"message\":\"Authentication required\"}");
                })
            )
            
            // Add our JWT filter BEFORE the standard authentication filters
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        
        return http.build();
    }
}
```

### Why disable CSRF?

CSRF (Cross-Site Request Forgery) attacks require the browser to send session cookies.  
REST APIs using JWT tokens in headers are not vulnerable to CSRF because:
- CSRF exploits cookies (which the browser auto-sends to the right domain)
- JWT in `Authorization: Bearer` header must be explicitly set by JavaScript
- A malicious site's JavaScript can't read your JWT from localStorage (same-origin policy)

Spring Security enables CSRF by default because it's safe-by-default for browser apps.  
For REST APIs: always disable CSRF.

### Why `STATELESS` session?

Spring Security can store authentication in HTTP sessions (default).  
REST APIs are stateless — authentication is in every request's JWT.  
`STATELESS` tells Spring: don't create a session, don't read from session.

---

## Part 7 — @CurrentUser: Getting the Current User in Controllers

Instead of calling `SecurityContextHolder.getContext().getAuthentication()` in every method,  
we can create a `@CurrentUser` annotation that Spring resolves automatically.

```java
// The annotation
@Target(ElementType.PARAMETER)
@Retention(RetentionPolicy.RUNTIME)
public @interface CurrentUser {}
```

```java
// The resolver — Spring calls this to resolve @CurrentUser parameters
@Component
public class CurrentUserArgumentResolver implements HandlerMethodArgumentResolver {
    
    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return parameter.hasParameterAnnotation(CurrentUser.class)
            && parameter.getParameterType().equals(User.class);
    }
    
    @Override
    public Object resolveArgument(MethodParameter parameter,
                                  ModelAndViewContainer mavContainer,
                                  NativeWebRequest webRequest,
                                  WebDataBinderFactory binderFactory) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof User)) {
            throw new UnauthorizedException("Not authenticated");
        }
        return (User) auth.getPrincipal();
    }
}
```

```java
// Register the resolver
@Configuration
public class WebConfig implements WebMvcConfigurer {
    
    private final CurrentUserArgumentResolver resolver;
    
    public WebConfig(CurrentUserArgumentResolver resolver) {
        this.resolver = resolver;
    }
    
    @Override
    public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
        resolvers.add(resolver);
    }
}
```

```java
// Now controllers can use it cleanly
@RestController
@RequestMapping("/api/notes")
public class NoteController {
    
    @GetMapping
    public List<NoteResponse> list(@CurrentUser User user) {
        return noteService.getNotesForUser(user.getId());
    }
    
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public NoteResponse create(
            @RequestBody @Valid NoteCreateRequest request,
            @CurrentUser User user) {
        return noteService.createNote(user.getId(), request);
    }
    
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id, @CurrentUser User user) {
        noteService.deleteNote(id, user.getId());
    }
}
```

Compare to Python FastAPI:
```python
# Python
@router.get("")
def list_notes(db = Depends(get_db), current_user: User = Depends(get_current_user)):
    return note_service.list_for_user(db, current_user.id)
```

```java
// Java
@GetMapping
public List<NoteResponse> list(@CurrentUser User user) {
    return noteService.getNotesForUser(user.getId());
}
```

The Java version is actually cleaner — the user is resolved transparently.

---

## Part 8 — Authentication vs Authorization (Brief)

We're only implementing authentication (who you are).  
If you needed authorization (what you can do), Spring Security handles that too.

```java
// Role-based authorization (we don't implement this but good to know)
.authorizeHttpRequests(auth -> auth
    .requestMatchers("/admin/**").hasRole("ADMIN")
    .requestMatchers("/api/**").hasAnyRole("USER", "ADMIN")
    .anyRequest().authenticated()
)
```

```java
// Method-level security
@PreAuthorize("hasRole('ADMIN')")
public void deleteUser(Long id) { ... }

@PostAuthorize("returnObject.userId == authentication.principal.id")
public Note getNote(Long id) { ... }
```

For our Vault API: every authenticated user has the same role.  
Row-level security (users can only see their own notes) is enforced in the query:
```java
noteRepository.findByIdAndUserId(noteId, currentUser.getId())
    .orElseThrow(() -> new NoteNotFoundException(noteId));
// If the note exists but belongs to another user → 404 (not even 403)
// This reveals no information about other users' data
```

---

## Part 9 — The Complete Request Lifecycle

End-to-end, for `GET /api/notes` with `Authorization: Bearer <jwt>`:

```
1. Browser sends: GET /api/notes  Authorization: Bearer eyJ...
2. DispatcherServlet receives the request
3. SecurityContextPersistenceFilter: no existing context
4. JwtAuthenticationFilter.doFilterInternal():
     a. header = "Bearer eyJ..."
     b. token = "eyJ..."
     c. sub = decode jwt → "user-uuid-123"
     d. user = userRepository.findBySub("user-uuid-123")
     e. SecurityContextHolder.set(new Authentication(user))
5. FilterSecurityInterceptor: /api/notes requires authentication
     → SecurityContext has authentication → PASS
6. DispatcherServlet routes to NoteController.list()
7. Spring resolves @CurrentUser → SecurityContextHolder.getContext().getAuthentication().getPrincipal()
8. NoteController.list(user) is called
9. noteService.getNotesForUser(user.getId()) → runs @Transactional query
10. NoteService returns List<NoteResponse>
11. Jackson serialises to JSON
12. HTTP 200 OK with JSON body
```

---

## Key Terms

| Term | Meaning |
|---|---|
| Security Filter Chain | The ordered list of filters every request passes through |
| `SecurityContext` | Thread-local storage for the current user's authentication |
| `SecurityContextHolder` | Provides access to the `SecurityContext` |
| `Authentication` | Holds the principal (user), credentials, and authorities |
| Principal | The currently authenticated user (our `User` entity) |
| `OncePerRequestFilter` | Spring base class guaranteeing filter runs exactly once per request |
| `JwtAuthenticationFilter` | Our custom filter that decodes JWT and sets SecurityContext |
| `STATELESS` | Session policy: no HTTP session, re-authenticate every request |
| CSRF | Cross-Site Request Forgery — not a concern for JWT REST APIs |
| `@CurrentUser` | Our custom annotation to inject the current user into controller methods |
| `HandlerMethodArgumentResolver` | Spring mechanism to resolve custom method parameter annotations |
| Authentication | Who are you? (verifying identity) |
| Authorization | What are you allowed to do? (checking permissions) |
