# Spring Boot 3.x — Research Reference

> Covers Spring Boot 3.0 through 3.5. Features are version-tagged throughout.
> Java 17 is the minimum baseline for all 3.x releases; Java 21 unlocks virtual threads.

---

## Support Timeline

| Version | Released     | OSS Support Ends | Commercial Support Ends |
|---------|-------------|------------------|------------------------|
| 3.0     | Nov 24 2022 | Dec 31 2023      | Dec 31 2024            |
| 3.1     | May 31 2023 | Jun 30 2024      | Jun 30 2025            |
| 3.2     | Nov 30 2023 | Dec 31 2024      | Dec 31 2025            |
| 3.3     | May 31 2024 | Jun 30 2025      | Jun 30 2026            |
| 3.4     | Nov 30 2024 | Dec 31 2025      | Dec 31 2026            |
| 3.5     | May 31 2025 | Jun 30 2026      | Jun 30 2032            |

**Current situation (April 2026):** 3.0–3.4 OSS support has ended. Only **3.5** remains in OSS support (until Jun 30 2026). Spring Boot **4.0** released Nov 30 2025 is the active major version. The only 3.x line still receiving commercial support beyond 2026 is 3.5 (until Jun 2032) and 2.7 (until Jun 2029).

---

## 1. Jakarta EE Migration — javax.* → jakarta.*

**Introduced:** Spring Boot 3.0 (Spring Framework 6.0)

Spring Boot 3.0 requires Jakarta EE 9+ APIs. Every package that was under `javax.*` in EE 8 moved to `jakarta.*` in EE 9. This is a hard, non-negotiable change — there is no compatibility bridge in Spring Boot 3.x.

### Affected Packages

| Old (javax) | New (jakarta) |
|-------------|--------------|
| `javax.servlet` | `jakarta.servlet` |
| `javax.persistence` | `jakarta.persistence` |
| `javax.validation` | `jakarta.validation` |
| `javax.annotation` | `jakarta.annotation` |
| `javax.transaction` | `jakarta.transaction` |
| `javax.xml.bind` | `jakarta.xml.bind` |
| `javax.xml.ws` | `jakarta.xml.ws` |
| `javax.websocket` | `jakarta.websocket` |
| `javax.inject` | `jakarta.inject` |
| `javax.mail` | `jakarta.mail` |
| `javax.json` | `jakarta.json` |
| `javax.security.*` | `jakarta.security.*` |
| `javax.ejb` | `jakarta.ejb` |
| `javax.jms` | `jakarta.jms` |
| `javax.batch` | `jakarta.batch` |
| `javax.activation` | `jakarta.activation` |
| `javax.el` | `jakarta.el` |
| `javax.ws` (JAX-RS) | `jakarta.ws` |

### Before/After Example

```java
// Spring Boot 2.x
import javax.servlet.http.HttpServletRequest;
import javax.persistence.Entity;
import javax.validation.constraints.NotNull;

// Spring Boot 3.x
import jakarta.servlet.http.HttpServletRequest;
import jakarta.persistence.Entity;
import jakarta.validation.constraints.NotNull;
```

### OpenRewrite Migration Recipes

The automated migration toolchain uses OpenRewrite. The umbrella recipe handles the full migration:

**Top-level recipe ID:**
```
org.openrewrite.java.migrate.jakarta.JavaxMigrationToJakarta
```

**Spring Boot 3.0 full migration recipe** (includes Jakarta + Java 17 + Spring Framework 6 + Spring Security 6):
```
org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_0
```

Sub-recipes composed into `UpgradeSpringBoot_3_0`:

| Recipe ID | Purpose |
|-----------|---------|
| `org.openrewrite.java.spring.boot2.UpgradeSpringBoot_2_7` | Prerequisite — get to 2.7 first |
| `org.openrewrite.java.migrate.UpgradeToJava17` | Upgrades language level |
| `org.openrewrite.java.spring.framework.UpgradeSpringFramework_6_0` | Framework 6.0 compat |
| `org.openrewrite.java.spring.security6.UpgradeSpringSecurity_6_0` | Security 6.0 migration |
| `org.openrewrite.java.spring.boot3.SpringBootProperties_3_0` | Renames changed properties |
| `org.openrewrite.java.spring.boot3.RemoveConstructorBindingAnnotation` | Removes now-implicit annotation |
| `org.openrewrite.java.spring.boot3.RemoveEnableBatchProcessing` | Batch 5 compat |
| `org.openrewrite.java.spring.batch.SpringBatch4To5Migration` | Spring Batch 4 → 5 |
| `org.openrewrite.java.spring.kafka.UpgradeSpringKafka_3_0` | Kafka 3.0 deps |
| `org.openrewrite.hibernate.MigrateToHibernate61` | Hibernate 6.1 migration |
| `org.openrewrite.java.springdoc.UpgradeSpringDoc_2` | SpringDoc OpenAPI 2.x |
| `org.openrewrite.java.migrate.jakarta.JavaxMigrationToJakarta` | All javax → jakarta |
| `org.openrewrite.java.migrate.jakarta.JacksonJavaxToJakarta` | Jackson Jakarta compat |
| `org.openrewrite.java.migrate.jakarta.EhcacheJavaxToJakarta` | Ehcache Jakarta compat |
| `org.openrewrite.java.migrate.jakarta.JavaxServletToJakartaServlet` | Servlet namespace |

**Maven application:**

```xml
<plugin>
  <groupId>org.openrewrite.maven</groupId>
  <artifactId>rewrite-maven-plugin</artifactId>
  <version>6.36.0</version>
  <configuration>
    <activeRecipes>
      <recipe>org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_0</recipe>
    </activeRecipes>
  </configuration>
  <dependencies>
    <dependency>
      <groupId>org.openrewrite.recipe</groupId>
      <artifactId>rewrite-migrate-java</artifactId>
      <version>3.32.0</version>
    </dependency>
    <dependency>
      <groupId>org.openrewrite.recipe</groupId>
      <artifactId>rewrite-spring</artifactId>
      <version>5.x</version>
    </dependency>
  </dependencies>
</plugin>
```

**Run:**
```bash
./mvnw rewrite:run
```

**Gradle application:**
```gradle
plugins {
    id("org.openrewrite.rewrite") version("latest.release")
}

rewrite {
    activeRecipe("org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_0")
}

dependencies {
    rewrite("org.openrewrite.recipe:rewrite-migrate-java:3.32.0")
    rewrite("org.openrewrite.recipe:rewrite-spring:5.x")
}
```

**Run:**
```bash
./gradlew rewriteRun
```

---

## 2. Java 17+ Baseline and Modern Language Features

**Introduced:** Spring Boot 3.0

Java 17 is the minimum. Spring Boot 3.x is designed to work with Java 21 as well, with Java 21 enabling virtual thread support (see section 8).

### Records as DTOs

Records eliminate the boilerplate of immutable data classes. Spring MVC, WebFlux, and Spring Data all recognize records natively in 3.x.

```java
// Before (Spring Boot 2.x — verbose POJO)
public class CreateUserRequest {
    private final String username;
    private final String email;

    public CreateUserRequest(String username, String email) {
        this.username = username;
        this.email = email;
    }
    public String getUsername() { return username; }
    public String getEmail() { return email; }
    // equals, hashCode, toString...
}

// After (Spring Boot 3.x — record)
public record CreateUserRequest(String username, String email) {}

// Works directly in @RestController
@PostMapping("/users")
public ResponseEntity<UserDto> create(@RequestBody @Valid CreateUserRequest request) { ... }

// Works in @ConfigurationProperties
@ConfigurationProperties("app.mail")
public record MailProperties(String host, int port, boolean ssl) {}
```

### Sealed Classes for Domain Modeling

```java
// Model a payment result hierarchy with closed types
public sealed interface PaymentResult
    permits PaymentResult.Success, PaymentResult.Failed, PaymentResult.Pending {}

public record Success(String transactionId, BigDecimal amount) implements PaymentResult {}
public record Failed(String reason, int errorCode) implements PaymentResult {}
public record Pending(String referenceId) implements PaymentResult {}

// Pattern matching switch (Java 21, preview in 17) in service logic
String describe(PaymentResult result) {
    return switch (result) {
        case Success s  -> "Paid: " + s.transactionId();
        case Failed f   -> "Failed: " + f.reason();
        case Pending p  -> "Pending: " + p.referenceId();
    };
}
```

### Pattern Matching for instanceof

```java
// Before
if (obj instanceof String) {
    String s = (String) obj;
    return s.toUpperCase();
}

// After (Java 16+)
if (obj instanceof String s) {
    return s.toUpperCase();
}
```

### Text Blocks for Embedded SQL/JSON/Templates

```java
// Useful in Spring Data @Query, test fixtures, MockMvc expectations
String sql = """
    SELECT u.id, u.email, r.name AS role
    FROM users u
    JOIN user_roles ur ON u.id = ur.user_id
    JOIN roles r ON ur.role_id = r.id
    WHERE u.active = true
    ORDER BY u.created_at DESC
    """;

String jsonPayload = """
    {
        "username": "alice",
        "email": "alice@example.com"
    }
    """;
```

---

## 3. GraalVM Native Image

**Introduced:** Spring Boot 3.0 (first-class support; experimental in 2.x via Spring Native)

### Core Concept: Spring AOT Processing

Spring Boot 3.x includes an AOT (Ahead-of-Time) processing step that runs at **build time** to analyze the application context and generate:

1. **Java source code** — Static bean definitions replacing runtime reflection-based discovery
2. **Bytecode** — Pre-generated proxies
3. **GraalVM hint files** in `META-INF/native-image/{groupId}/{artifactId}/`:
   - `reflect-config.json`
   - `resource-config.json`
   - `proxy-config.json`
   - `serialization-config.json`
   - `jni-config.json`

**Generated AOT code example:**

```java
// Original configuration
@Configuration(proxyBeanMethods = false)
public class MyConfiguration {
    @Bean
    public MyBean myBean() {
        return new MyBean();
    }
}

// Generated by Spring AOT (in target/spring-aot/main/sources)
public class MyConfiguration__BeanDefinitions {
    public static BeanDefinition getMyConfigurationBeanDefinition() {
        RootBeanDefinition beanDefinition = new RootBeanDefinition(MyConfiguration.class);
        beanDefinition.setInstanceSupplier(MyConfiguration::new);
        return beanDefinition;
    }

    private static BeanInstanceSupplier<MyBean> getMyBeanInstanceSupplier() {
        return BeanInstanceSupplier.<MyBean>forFactoryMethod(MyConfiguration.class, "myBean")
            .withGenerator((registeredBean) -> registeredBean.getBeanFactory()
                .getBean(MyConfiguration.class).myBean());
    }

    public static BeanDefinition getMyBeanBeanDefinition() {
        RootBeanDefinition beanDefinition = new RootBeanDefinition(MyBean.class);
        beanDefinition.setInstanceSupplier(getMyBeanInstanceSupplier());
        return beanDefinition;
    }
}
```

### Build Configuration

**Maven — native-maven-plugin** (via `spring-boot-starter-parent` native profile):

```xml
<!-- In pom.xml — the native profile is declared in spring-boot-starter-parent -->
<!-- Just add the plugin; the parent activates it in the "native" profile -->
<plugin>
    <groupId>org.graalvm.buildtools</groupId>
    <artifactId>native-maven-plugin</artifactId>
</plugin>
```

Build commands:

```bash
# Option 1: Using Buildpacks (Docker, no local GraalVM install needed)
./mvnw -Pnative spring-boot:build-image

# Option 2: Direct native compilation (requires local GraalVM install)
./mvnw -Pnative native:compile

# Output: target/<artifactId>  (native executable, no JVM required)
```

**Gradle:**

```gradle
plugins {
    id 'org.graalvm.buildtools.native'
}
```

```bash
# Buildpacks
./gradlew bootBuildImage

# Direct compile
./gradlew nativeCompile
```

**AOT-generated sources locations:**

| Tool | Sources | Resources | Classes |
|------|---------|-----------|---------|
| Maven | `target/spring-aot/main/sources` | `target/spring-aot/main/resources` | `target/spring-aot/main/classes` |
| Gradle | `build/generated/aotSources` | `build/generated/aotResources` | `build/generated/aotClasses` |

### Custom Runtime Hints

When AOT cannot infer hints automatically, register them programmatically:

```java
// 1. Implement RuntimeHintsRegistrar
public class MyRuntimeHints implements RuntimeHintsRegistrar {
    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        // Reflection hint for a private method
        Method method = ReflectionUtils.findMethod(MyClass.class, "process", String.class);
        hints.reflection().registerMethod(method, ExecutableMode.INVOKE);

        // Resource hint
        hints.resources().registerPattern("templates/email/*.html");

        // JDK proxy hint
        hints.proxies().registerJdkProxy(MyInterface.class);

        // Serialization hint
        hints.reflection().registerJavaSerialization(MySerializableClass.class);
    }
}

// 2. Activate on a @Configuration class or @SpringBootApplication
@SpringBootApplication
@ImportRuntimeHints(MyRuntimeHints.class)
public class MyApplication { ... }
```

For classes that are serialized/deserialized (Jackson, RestClient, WebClient):

```java
@RestController
@RegisterReflectionForBinding(UserDto.class)
public class UserController { ... }
```

### Testing Native Hints

```java
class MyRuntimeHintsTests {
    @Test
    void shouldRegisterHints() {
        RuntimeHints hints = new RuntimeHints();
        new MyRuntimeHints().registerHints(hints, getClass().getClassLoader());
        assertThat(RuntimeHintsPredicates.resource().forResource("templates/email/welcome.html"))
            .accepts(hints);
    }
}
```

### Nested Configuration Properties

Nested non-inner configuration property classes require explicit annotation in native mode:

```java
@ConfigurationProperties("app")
public class AppProperties {
    private String name;

    @NestedConfigurationProperty  // required for native image
    private final DatabaseProperties database = new DatabaseProperties();
}
```

### Known Limitations

| Limitation | Detail |
|------------|--------|
| **Closed-world assumption** | All reachable code and dependencies must be known at build time; classpath is fixed |
| **No lazy class loading** | All shipped classes load on startup |
| **@Profile not supported** | Profile selection changes application behavior at runtime, incompatible with AOT |
| **@ConditionalOnProperty limited** | `.enabled=false` conditions cannot be reliably evaluated at build time |
| **No application context hierarchies** | Hierarchical contexts not supported in AOT/native |
| **No lambda bean definitions** | `@Bean` methods that use lambdas or instance suppliers are not supported |
| **Mockito not supported** | `@MockBean` and `@SpyBean` fail; annotate tests with `@DisabledInNativeImage` |
| **Reflection requires explicit hints** | Any reflective access must be declared via `RuntimeHintsRegistrar` or JSON config |
| **Dynamic proxies are build-time** | cglib and JDK proxies are generated during compilation, not at runtime |
| **Spring-WS not supported** | Spring Web Services does not support AOT/GraalVM native |
| **@ModelAttribute optional binding** | Cannot infer data binding reflection hints at AOT time |
| **Slower builds** | AOT compilation adds significant time to the build process |
| **Minimum GraalVM version** | Requires GraalVM/Liberica NIK version matching the target Java version |

**JVM vs Native Image comparison:**

| Aspect | Native Image | JVM |
|--------|-------------|-----|
| Bean discovery | Build-time (static) | Runtime (dynamic) |
| Classpath | Fixed at build | Flexible |
| Class loading | Eager (startup) | Lazy (on-demand) |
| Reflection | Must declare hints | Automatic |
| Proxy generation | Build-time bytecode | Runtime cglib |
| Startup time | Milliseconds | Seconds |
| Peak throughput | Lower (no JIT) | Higher |
| Memory footprint | Lower | Higher |

---

## 4. Observability — Micrometer Observation API

**Introduced:** Spring Boot 3.0

Spring Boot 3.x replaces the old Spring Cloud Sleuth approach with a unified Micrometer Observation API that ties metrics, tracing, and logging together.

### Auto-Configured Tracing Backends

| Backend | Dependency |
|---------|-----------|
| Zipkin (via Brave) | `spring-boot-starter-zipkin` |
| OTLP (OpenTelemetry) | `spring-boot-starter-opentelemetry` |
| Wavefront | `spring-boot-starter-actuator` + Wavefront exporter |

```xml
<!-- Zipkin via Brave (recommended) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-zipkin</artifactId>
</dependency>

<!-- OpenTelemetry with OTLP -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-opentelemetry</artifactId>
</dependency>
```

### Sampling Configuration

```yaml
management:
  tracing:
    sampling:
      probability: 1.0  # 100% — default is 0.1 (10%)
  opentelemetry:
    tracing:
      export:
        otlp:
          endpoint: http://localhost:4318/v1/traces
```

### Log Correlation IDs

Spring Boot automatically injects `traceId` and `spanId` into MDC, appearing in logs:

```
2024-01-15 10:23:45 [803B448A0489F84084905D3093480352-3425F23BB2432450] INFO  c.e.UserService - Creating user
```

Custom pattern matching Spring Cloud Sleuth's old format:

```yaml
logging:
  pattern:
    correlation: "[${spring.application.name:},%X{traceId:-},%X{spanId:-}] "
  include-application-name: false
```

### Custom Observations — ObservationRegistry

```java
@Component
public class UserService {
    private final ObservationRegistry observationRegistry;

    public UserService(ObservationRegistry observationRegistry) {
        this.observationRegistry = observationRegistry;
    }

    public User createUser(String email) {
        return Observation.createNotStarted("user.create", observationRegistry)
            .lowCardinalityKeyValue("operation", "create")   // goes to metrics AND traces
            .highCardinalityKeyValue("email", email)          // traces only
            .observe(() -> doCreateUser(email));
    }
}
```

### @Observed Annotation

Enable annotation-driven observation (requires AspectJ):

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-aop</artifactId>
</dependency>
```

```yaml
management:
  observations:
    annotations:
      enabled: true
```

```java
@Service
public class PaymentService {
    @Observed(name = "payment.process", contextualName = "processing-payment")
    public PaymentResult processPayment(PaymentRequest request) {
        // Automatically creates an observation span + metric counter
        return doProcess(request);
    }
}
```

### Common Tags

```yaml
management:
  observations:
    key-values:
      region: us-east-1
      stack: prod
```

### Preventing Observations

```yaml
management:
  observations:
    enable:
      spring.security: false   # disable security observations
      denied.prefix: false
```

### Context Propagation (Async / Reactive)

```yaml
spring:
  reactor:
    context-propagation: auto  # propagate trace context in reactive pipelines
```

```java
// For @Async methods
@Configuration
class ContextPropagationConfig {
    @Bean
    ContextPropagatingTaskDecorator contextPropagatingTaskDecorator() {
        return new ContextPropagatingTaskDecorator();
    }
}
```

**Note:** Trace propagation is automatic only through auto-configured HTTP clients (`RestTemplateBuilder`, `RestClient.Builder`, `WebClient.Builder`). Manually constructed clients bypass propagation.

---

## 5. HTTP Interface Clients — @HttpExchange

**Introduced:** Spring Boot 3.0 (Spring Framework 6.0)

Declarative HTTP interfaces let you define service-to-service HTTP calls as annotated interfaces, with Spring generating the proxy implementation. This replaces verbose WebClient/RestTemplate boilerplate for service clients.

### Before — WebClient Boilerplate

```java
@Bean
WebClient webClient() {
    return WebClient.builder()
        .baseUrl("https://api.example.com/")
        .build();
}

// Every call requires chaining retrieve, bodyTo, block
public User getUser(Long id) {
    return webClient.get()
        .uri("/users/{id}", id)
        .retrieve()
        .bodyToMono(User.class)
        .block();
}
```

### After — @HttpExchange Interface

```java
@HttpExchange(url = "/users", contentType = MediaType.APPLICATION_JSON_VALUE)
public interface UserClient {

    @GetExchange("/{id}")
    User getById(@PathVariable Long id);

    @GetExchange
    List<User> findAll(@RequestParam String role);

    @PostExchange
    ResponseEntity<Void> create(@RequestBody CreateUserRequest request);

    @PutExchange("/{id}")
    User update(@PathVariable Long id, @RequestBody UpdateUserRequest request);

    @DeleteExchange("/{id}")
    void delete(@PathVariable Long id);
}
```

### Proxy Factory Setup

```java
@Configuration
public class HttpClientConfig {

    // Using RestClient (Spring Boot 3.2+ preferred — blocking)
    @Bean
    UserClient userClient(RestClient.Builder builder) {
        RestClient restClient = builder
            .baseUrl("https://api.example.com")
            .build();
        HttpServiceProxyFactory factory = HttpServiceProxyFactory
            .builderFor(RestClientAdapter.create(restClient))
            .build();
        return factory.createClient(UserClient.class);
    }

    // Using WebClient (reactive)
    @Bean
    UserClient userClientReactive(WebClient.Builder builder) {
        WebClient webClient = builder
            .baseUrl("https://api.example.com")
            .build();
        HttpServiceProxyFactory factory = HttpServiceProxyFactory
            .builderFor(WebClientAdapter.create(webClient))
            .build();
        return factory.createClient(UserClient.class);
    }
}
```

### Available Annotations

| Annotation | HTTP Method |
|-----------|-------------|
| `@HttpExchange` | Any (specify `method` attribute) |
| `@GetExchange` | GET |
| `@PostExchange` | POST |
| `@PutExchange` | PUT |
| `@PatchExchange` | PATCH |
| `@DeleteExchange` | DELETE |

### Method Parameter Annotations

| Annotation | Purpose |
|-----------|---------|
| `@PathVariable` | URI template variables |
| `@RequestParam` | Query parameters |
| `@RequestHeader` | Request headers |
| `@RequestBody` | Request body |
| `@RequestPart` | Multipart fields/files |

---

## 6. ProblemDetail — RFC 7807 Error Responses

**Introduced:** Spring Boot 3.0 (Spring Framework 6.0)

Spring Framework 6 implements RFC 7807 "Problem Details for HTTP APIs." All built-in Spring MVC exceptions already implement the `ErrorResponse` interface and serialize as `application/problem+json`.

### Enable Auto-Configuration

```yaml
spring:
  mvc:
    problemdetails:
      enabled: true   # enables ResponseEntityExceptionHandler auto-configuration
  webflux:
    problemdetails:
      enabled: true   # WebFlux variant
```

### ProblemDetail Structure

```json
{
    "type": "https://example.com/errors/not-found",
    "title": "Record Not Found",
    "status": 404,
    "detail": "Employee id '101' does not exist",
    "instance": "/employees/101"
}
```

### ProblemDetail API

```java
ProblemDetail pd = ProblemDetail.forStatusAndDetail(
    HttpStatus.NOT_FOUND,
    "Employee id '101' does not exist"
);
pd.setType(URI.create("https://example.com/errors/not-found"));
pd.setTitle("Record Not Found");
pd.setProperty("hostname", "api.example.com");  // custom extension fields
pd.setProperty("errorCode", "EMP_404");
```

### Custom Exception Handler

```java
@ControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(RecordNotFoundException.class)
    public ProblemDetail handleRecordNotFoundException(
            RecordNotFoundException ex, WebRequest request) {
        ProblemDetail body = ProblemDetail
            .forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        body.setType(URI.create("https://example.com/errors/not-found"));
        body.setTitle("Record Not Found");
        return body;
    }

    @ExceptionHandler(ValidationException.class)
    public ProblemDetail handleValidation(ValidationException ex) {
        ProblemDetail body = ProblemDetail
            .forStatusAndDetail(HttpStatus.UNPROCESSABLE_ENTITY, ex.getMessage());
        body.setTitle("Validation Failed");
        body.setProperty("violations", ex.getViolations());
        return body;
    }
}
```

### Wrapping Non-Standard Exceptions

```java
// Wrap any exception into an ErrorResponse-compatible form
ProblemDetail pd = ProblemDetail.forStatusAndDetail(
    HttpStatus.INTERNAL_SERVER_ERROR, "Unexpected error"
);
throw new ErrorResponseException(HttpStatus.INTERNAL_SERVER_ERROR, pd, cause);
```

### ErrorResponse Interface

All Spring MVC exceptions (e.g., `MethodArgumentNotValidException`, `HttpMessageNotReadableException`) implement `ErrorResponse`, which exposes:
- HTTP status
- Response headers
- `ProblemDetail` body

When `spring.mvc.problemdetails.enabled=true`, these are automatically serialized as `application/problem+json` without any custom handler code.

---

## 7. Security Changes

**Introduced:** Spring Boot 3.0 (Spring Security 6.0)

### WebSecurityConfigurerAdapter Removed

`WebSecurityConfigurerAdapter` was deprecated in Spring Security 5.7 and **fully removed in Spring Security 6.0** (Spring Boot 3.0). All security configuration must use the component-based `SecurityFilterChain` bean approach.

### Before — WebSecurityConfigurerAdapter (Spring Boot 2.x)

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .csrf().disable()
            .authorizeRequests()
                .antMatchers("/public/**").permitAll()
                .antMatchers("/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            .and()
            .formLogin()
            .and()
            .httpBasic();
    }

    @Override
    protected void configure(AuthenticationManagerBuilder auth) throws Exception {
        auth.inMemoryAuthentication()
            .withUser("user").password("{noop}password").roles("USER");
    }
}
```

### After — SecurityFilterChain Lambda DSL (Spring Boot 3.x)

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/public/**").permitAll()
                .requestMatchers("/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .formLogin(Customizer.withDefaults())
            .httpBasic(Customizer.withDefaults());

        return http.build();
    }

    @Bean
    public UserDetailsService userDetailsService() {
        UserDetails user = User.withDefaultPasswordEncoder()
            .username("user")
            .password("password")
            .roles("USER")
            .build();
        return new InMemoryUserDetailsManager(user);
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```

**Key changes:**
- `antMatchers()` → `requestMatchers()`
- `authorizeRequests()` → `authorizeHttpRequests()`
- All configurers now use lambda DSL; chained `.and()` removed
- Authentication manager is now a separate `@Bean`

### Web Security Customizer

```java
@Bean
public WebSecurityCustomizer webSecurityCustomizer() {
    return (web) -> web.ignoring()
        .requestMatchers("/static/**", "/favicon.ico");
}
```

### Multiple SecurityFilterChain Beans (ordered)

```java
@Bean
@Order(1)
public SecurityFilterChain apiSecurityFilterChain(HttpSecurity http) throws Exception {
    http
        .securityMatcher("/api/**")
        .authorizeHttpRequests(auth -> auth.anyRequest().hasRole("API_USER"))
        .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
    return http.build();
}

@Bean
@Order(2)
public SecurityFilterChain webSecurityFilterChain(HttpSecurity http) throws Exception {
    http
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/login", "/register").permitAll()
            .anyRequest().authenticated()
        )
        .formLogin(Customizer.withDefaults());
    return http.build();
}
```

### OAuth2 Authorization Server

**New in Spring Boot 3.1:** `spring-boot-starter-oauth2-authorization-server` (replaces the old, separately-maintained `spring-security-oauth2` project).

**Dependency:**
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-oauth2-authorization-server</artifactId>
</dependency>
```

**Minimal application.yml configuration:**
```yaml
server:
  port: 9000
spring:
  security:
    oauth2:
      authorizationserver:
        client:
          my-client:
            registration:
              client-id: "my-client"
              client-secret: "{noop}secret"
              client-authentication-methods:
                - "client_secret_basic"
              authorization-grant-types:
                - "authorization_code"
                - "refresh_token"
              redirect-uris:
                - "http://127.0.0.1:8080/login/oauth2/code/my-client"
              scopes:
                - "openid"
                - "profile"
            require-authorization-consent: true
```

**Java-based configuration (full control):**
```java
@Configuration
@EnableWebSecurity
public class AuthServerConfig {

    @Bean
    @Order(1)
    public SecurityFilterChain authServerFilterChain(HttpSecurity http) throws Exception {
        OAuth2AuthorizationServerConfigurer authorizationServerConfigurer =
            OAuth2AuthorizationServerConfigurer.authorizationServer();
        http
            .securityMatcher(authorizationServerConfigurer.getEndpointsMatcher())
            .with(authorizationServerConfigurer, server ->
                server.oidc(Customizer.withDefaults())
            )
            .authorizeHttpRequests(auth -> auth.anyRequest().authenticated())
            .exceptionHandling(ex -> ex
                .defaultAuthenticationEntryPointFor(
                    new LoginUrlAuthenticationEntryPoint("/login"),
                    new MediaTypeRequestMatcher(MediaType.TEXT_HTML)
                )
            );
        return http.build();
    }

    @Bean
    public RegisteredClientRepository registeredClientRepository() {
        RegisteredClient client = RegisteredClient.withId(UUID.randomUUID().toString())
            .clientId("my-client")
            .clientSecret("{noop}secret")
            .clientAuthenticationMethod(ClientAuthenticationMethod.CLIENT_SECRET_BASIC)
            .authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE)
            .authorizationGrantType(AuthorizationGrantType.REFRESH_TOKEN)
            .redirectUri("http://127.0.0.1:8080/login/oauth2/code/my-client")
            .scope(OidcScopes.OPENID)
            .scope(OidcScopes.PROFILE)
            .clientSettings(ClientSettings.builder().requireAuthorizationConsent(true).build())
            .build();
        return new InMemoryRegisteredClientRepository(client);
    }

    @Bean
    public JWKSource<SecurityContext> jwkSource() {
        KeyPairGenerator gen = KeyPairGenerator.getInstance("RSA");
        gen.initialize(2048);
        KeyPair keyPair = gen.generateKeyPair();
        RSAKey rsaKey = new RSAKey.Builder((RSAPublicKey) keyPair.getPublic())
            .privateKey(keyPair.getPrivate())
            .keyID(UUID.randomUUID().toString())
            .build();
        return new ImmutableJWKSet<>(new JWKSet(rsaKey));
    }

    @Bean
    public JwtDecoder jwtDecoder(JWKSource<SecurityContext> jwkSource) {
        return OAuth2AuthorizationServerConfiguration.jwtDecoder(jwkSource);
    }

    @Bean
    public AuthorizationServerSettings authorizationServerSettings() {
        return AuthorizationServerSettings.builder().build();
    }
}
```

---

## 8. Spring Boot 3.2 Additions

**Released:** November 30 2023

### Virtual Threads (JDK 21)

**Requires:** Java 21

```yaml
spring:
  threads:
    virtual:
      enabled: true
```

When enabled:
- Tomcat uses virtual threads for request handling (instead of platform thread pool)
- Jetty uses virtual threads for request handling
- `@Async` methods execute on virtual threads
- Scheduled tasks run on virtual threads

This allows writing standard blocking/imperative code without thread pool sizing concerns, making I/O-bound workloads scale better without the complexity of reactive programming.

```java
// This blocking code scales fine on virtual threads
@RestController
public class UserController {
    @GetMapping("/users/{id}")
    public User getUser(@PathVariable Long id) {
        // Blocking JDBC call — fine with virtual threads
        return userRepository.findById(id).orElseThrow();
    }
}
```

### RestClient — New Synchronous HTTP Client

`RestClient` (Spring Framework 6.1) is a modern, fluent, synchronous HTTP client that complements WebClient for reactive use cases. It replaces the aging `RestTemplate` for new code.

```java
@Service
public class PostService {
    private final RestClient restClient;

    public PostService(RestClient.Builder builder) {
        this.restClient = builder
            .baseUrl("https://jsonplaceholder.typicode.com")
            .build();
    }

    public List<Post> findAll() {
        return restClient.get()
            .uri("/posts")
            .retrieve()
            .body(new ParameterizedTypeReference<List<Post>>() {});
    }

    public Post findById(Long id) {
        return restClient.get()
            .uri("/posts/{id}", id)
            .retrieve()
            .body(Post.class);
    }

    public Post create(Post post) {
        return restClient.post()
            .uri("/posts")
            .contentType(MediaType.APPLICATION_JSON)
            .body(post)
            .retrieve()
            .body(Post.class);
    }
}
```

**Using RestClient with @HttpExchange (3.2+):**
```java
@Bean
UserClient userClient(RestClient.Builder builder) {
    RestClient restClient = builder.baseUrl("https://api.example.com").build();
    return HttpServiceProxyFactory
        .builderFor(RestClientAdapter.create(restClient))
        .build()
        .createClient(UserClient.class);
}
```

### JdbcClient — Fluent JDBC API

`JdbcClient` (Spring Framework 6.1) is auto-configured in Spring Boot 3.2 when a `NamedParameterJdbcTemplate` is present. It provides a fluent API over JDBC without requiring Spring Data JPA.

```java
@Repository
public class UserRepository {
    private final JdbcClient jdbcClient;

    public UserRepository(JdbcClient jdbcClient) {
        this.jdbcClient = jdbcClient;
    }

    public List<User> findAll() {
        return jdbcClient.sql("SELECT * FROM users")
            .query(User.class)
            .list();
    }

    public Optional<User> findById(Long id) {
        return jdbcClient.sql("SELECT * FROM users WHERE id = :id")
            .param("id", id)
            .query(User.class)
            .optional();
    }

    public int save(User user) {
        return jdbcClient.sql("INSERT INTO users (name, email) VALUES (:name, :email)")
            .param("name", user.name())
            .param("email", user.email())
            .update();
    }
}
```

### CRaC — Coordinated Restore at Checkpoint

CRaC (Project CRaC) allows capturing a running JVM process checkpoint and restoring it later for near-instant startup. Unlike GraalVM native images it keeps the JIT-warmed JVM, so peak throughput is maintained.

- Requires Linux (checkpoint/restore is a Linux kernel feature)
- Spring Boot 3.2 provides framework-level `SmartLifecycle` integration to properly close resources before checkpoint and reopen them after restore
- Deployment concern (DevOps/CI-CD), not a developer coding concern
- Can yield ~100x faster startup vs cold JVM start for warmed-up applications

---

## 9. Spring Boot 3.3 Additions

**Released:** May 31 2024

### Class Data Sharing (CDS)

CDS is a JVM feature that persists parsed class metadata in a shared archive file. On restart the JVM memory-maps the archive instead of parsing classes from scratch.

Spring Boot 3.3 integrated the Spring lifecycle to align with the CDS training run phase, making setup straightforward.

**Performance:** ~40–50% reduction in startup time; ~16% reduction in memory footprint (JVM, not native).

**Setup steps:**

```bash
# 1. Build the application JAR normally
./mvnw package -DskipTests

# 2. Extract the JAR layers (Spring Boot layered JAR)
java -Djarmode=tools -jar target/myapp.jar extract

# 3. Training run — starts app, captures classes, exits on context refresh
java -Dspring.aot.enabled=true \
     -XX:ArchiveClassesAtExit=./application.jsa \
     -Dspring.context.exit=onRefresh \
     -jar target/myapp.jar

# 4. Production run — use the CDS archive
java -Dspring.aot.enabled=true \
     -XX:SharedArchiveFile=application.jsa \
     -jar target/myapp.jar
```

**With AOT processing (for best results):**

Enable AOT in the Maven plugin:
```xml
<plugin>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-maven-plugin</artifactId>
    <executions>
        <execution>
            <id>process-aot</id>
            <goals><goal>process-aot</goal></goals>
        </execution>
    </executions>
</plugin>
```

**Benchmark results (lightweight Spring Boot app):**

| Mode | Startup Time |
|------|-------------|
| Baseline (no optimization) | 1.0–1.4 s |
| CDS only | 700–800 ms (~50% faster) |
| CDS + AOT | 500–600 ms (~60% faster) |

**Buildpacks (Docker):**
```bash
# Paketo buildpack automates the training run inside the image build
BP_JVM_AOTCACHE_ENABLED=true ./mvnw spring-boot:build-image
```

**Training run note:** If the application connects to external services (databases, message brokers) at startup, configure the training run to skip those connections or use in-memory alternatives to avoid failures during the CDS archive phase.

### @ServiceConnection Improvements (3.1 introduced, 3.3 expanded)

`@ServiceConnection` (introduced in 3.1) eliminates manual `spring.datasource.url`-style properties in Testcontainers-based tests. Spring Boot 3.3 expanded the set of supported container types.

```java
@Testcontainers
@SpringBootTest
class IntegrationTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @Container
    @ServiceConnection
    static RedisContainer redis = new RedisContainer("redis:7");

    @Container
    @ServiceConnection
    static KafkaContainer kafka = new KafkaContainer(
        DockerImageName.parse("confluentinc/cp-kafka:7.5.0"));

    @Test
    void myTest() {
        // postgres, redis, kafka auto-configured — no manual properties needed
    }
}
```

Supported containers include: PostgreSQL, MySQL, MariaDB, MongoDB, Redis, Kafka, RabbitMQ, Cassandra, Elasticsearch, Neo4j, Pulsar, ActiveMQ, Artemis, LDAP, Couchbase, R2DBC variants, and more.

**Filtering by connection type:**
```java
// PostgreSQL supports both JDBC and R2DBC — create only JDBC
@ServiceConnection(type = JdbcConnectionDetails.class)
static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");
```

### Structured Logging (3.4 — preview in 3.3)

**Full support landed in Spring Boot 3.4.** Structured logging outputs JSON-formatted log entries for log aggregation pipelines (ECS, Logstash, GELF).

```yaml
# Spring Boot 3.4+
logging:
  structured:
    format:
      console: ecs          # Elastic Common Schema
      # console: logstash   # Logstash JSON
      # console: gelf       # Graylog Extended Log Format
      file: ecs             # also apply to file output
```

**ECS output example:**
```json
{
  "@timestamp": "2024-01-15T10:23:45.123Z",
  "log.level": "INFO",
  "message": "User created successfully",
  "service.name": "my-service",
  "trace.id": "803b448a0489f84084905d3093480352",
  "span.id": "3425f23bb2432450",
  "log.logger": "com.example.UserService",
  "process.pid": 12345
}
```

MDC (Mapped Diagnostic Context) values are included automatically in all structured formats.

---

## 10. EOL Timeline and Migration to Spring Boot 4.0

### Current Status (April 2026)

- **3.5** — the only 3.x line still in OSS support (ends Jun 30 2026)
- **3.3** — OSS ended Jun 30 2025; commercial extended support available until Jun 30 2026
- **3.0–3.2** — fully EOL (both OSS and commercial)
- **4.0** — current active major version (released Nov 30 2025, OSS support ends Dec 31 2026)

### Spring Boot 4.0 Breaking Changes

| Change | Detail |
|--------|--------|
| **Jackson 3** | Baseline raised from Jackson 2 to Jackson 3 |
| **JUnit 6** | Baseline raised from JUnit 5 to JUnit 6 |
| **Java 17+ still minimum** | No Java baseline change from 3.x |
| **Spring Framework 7** | Underlying framework version |
| **OTel Zipkin exporter removed** | OpenTelemetry's Zipkin exporter deprecated in 3.x, removed in 4.2 |

### Recommended Migration Path

```
Spring Boot 2.7 → 3.0 → 3.5 → 4.0
```

- **2.7 → 3.0:** Use OpenRewrite `UpgradeSpringBoot_3_0` recipe. This is the largest migration (Jakarta namespace, Security 6, Java 17 minimum).
- **3.0 → 3.5:** Incremental; use OpenRewrite `UpgradeSpringBoot_3_x` recipes per minor version. Adopt virtual threads, RestClient, JdbcClient, CDS as available.
- **3.5 → 4.0:** Jackson 2 → 3, JUnit 5 → 6 are the main code-level changes. OpenRewrite recipes are available for 4.0 as well.

---

## Quick Reference: Feature-to-Version Matrix

| Feature | Version |
|---------|---------|
| Jakarta EE 9 (javax → jakarta) | 3.0 |
| Java 17 minimum baseline | 3.0 |
| GraalVM native image (first-class) | 3.0 |
| Micrometer Observation API | 3.0 |
| @HttpExchange declarative clients | 3.0 |
| ProblemDetail / RFC 7807 | 3.0 |
| SecurityFilterChain (WebSecurityConfigurerAdapter removed) | 3.0 |
| spring-authorization-server (OAuth2 AS starter) | 3.1 |
| @ServiceConnection (Testcontainers) | 3.1 |
| Virtual threads (`spring.threads.virtual.enabled`) | 3.2 (Java 21) |
| RestClient | 3.2 |
| JdbcClient | 3.2 |
| CRaC support | 3.2 |
| Class Data Sharing (CDS) built-in support | 3.3 |
| @ServiceConnection expanded (ActiveMQ, Artemis, LDAP) | 3.3 |
| Structured logging (ECS, Logstash, GELF) | 3.4 |
| AOT Cache via Buildpacks | 3.5 / ongoing |
