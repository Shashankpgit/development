# Phase 14 — Build: Auth Layer
## "JWT filter + SecurityConfig + @CurrentUser"

> Goal: protect all /api/** endpoints. Unauthenticated → 401. Authenticated → user resolved.
> Applies Phase 09 (Spring Security) concepts directly.

---

## What Gets Built

```
com/vaultapp/auth/
  JwtAuthenticationFilter.java     ← OncePerRequestFilter
  CurrentUser.java                  ← @interface annotation
  CurrentUserArgumentResolver.java  ← resolves @CurrentUser in controllers

com/vaultapp/config/
  SecurityConfig.java               ← SecurityFilterChain
  WebConfig.java                    ← registers argument resolver
```

---

## JwtAuthenticationFilter.java

Core logic: read JWT → decode → find/create user → set SecurityContext.

```java
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    
    private static final Logger log = LoggerFactory.getLogger(JwtAuthenticationFilter.class);
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;
    
    public JwtAuthenticationFilter(UserRepository userRepository, ObjectMapper objectMapper) {
        this.userRepository = userRepository;
        this.objectMapper = objectMapper;
    }
    
    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res,
                                    FilterChain chain) throws ServletException, IOException {
        String header = req.getHeader("Authorization");
        
        if (header == null || !header.startsWith("Bearer ")) {
            chain.doFilter(req, res);
            return;
        }
        
        try {
            String sub = extractSub(header.substring(7));
            
            User user = userRepository.findBySub(sub)
                .orElseGet(() -> userRepository.save(new User(sub)));
            
            SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(user, null, List.of())
            );
        } catch (Exception e) {
            log.warn("JWT processing failed: {}", e.getMessage());
            // Don't set auth → SecurityConfig will return 401
        }
        
        chain.doFilter(req, res);
    }
    
    private String extractSub(String token) throws Exception {
        String[] parts = token.split("\\.");
        if (parts.length != 3) throw new IllegalArgumentException("Not a JWT");
        
        int padding = 4 - (parts[1].length() % 4);
        String padded = parts[1] + (padding != 4 ? "=".repeat(padding) : "");
        
        byte[] decoded = Base64.getUrlDecoder().decode(padded);
        JsonNode payload = objectMapper.readTree(decoded);
        
        String sub = payload.path("sub").asText(null);
        if (sub == null || sub.isBlank()) throw new IllegalArgumentException("Missing sub claim");
        return sub;
    }
}
```

Note: `objectMapper` is injected — it's the same Jackson instance Spring Boot configured.

---

## SecurityConfig.java

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
        return http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/health", "/actuator/**").permitAll()
                .anyRequest().authenticated()
            )
            .exceptionHandling(ex -> ex.authenticationEntryPoint(
                (req, res, e) -> {
                    res.setStatus(401);
                    res.setContentType("application/json");
                    res.getWriter().write("{\"code\":\"unauthorized\",\"message\":\"Authentication required\"}");
                }
            ))
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }
}
```

---

## @CurrentUser + Resolver

```java
// The annotation
@Target(ElementType.PARAMETER)
@Retention(RetentionPolicy.RUNTIME)
public @interface CurrentUser {}

// The resolver
@Component
public class CurrentUserArgumentResolver implements HandlerMethodArgumentResolver {
    
    @Override
    public boolean supportsParameter(MethodParameter param) {
        return param.hasParameterAnnotation(CurrentUser.class)
            && User.class.isAssignableFrom(param.getParameterType());
    }
    
    @Override
    public Object resolveArgument(MethodParameter param, ModelAndViewContainer mav,
                                   NativeWebRequest req, WebDataBinderFactory factory) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof User user)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Not authenticated");
        }
        return user;
    }
}

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

---

## Why `@Transactional` is needed on the filter

The filter calls `userRepository.findBySub()` and potentially `userRepository.save()`.  
These are JPA operations — they need a transaction.

But the filter runs outside Spring MVC's transaction boundary.  
Solution: annotate `doFilterInternal` with `@Transactional`, or use a `UserService` method.

---

## Deliverable

```bash
# Without token:
curl localhost:8000/api/notes
# HTTP 401 {"code":"unauthorized","message":"Authentication required"}

# With valid token:
curl -H "Authorization: Bearer <jwt>" localhost:8000/api/notes
# HTTP 200 [...]

# With malformed token:
curl -H "Authorization: Bearer not-a-jwt" localhost:8000/api/notes
# HTTP 401 (JWT decode failed, logged as WARN)
```
