---
name: backend-spring-boot-3x
description: "Version-specific expert for Spring Boot 3.x (3.0 through 3.5). Covers Jakarta EE migration, GraalVM native image, Micrometer Observation API, HTTP interface clients, ProblemDetail, virtual threads, RestClient, JdbcClient, CDS, structured logging, and the SecurityFilterChain model. WHEN: \"Spring Boot 3\", \"Spring Boot 3.0\", \"Spring Boot 3.1\", \"Spring Boot 3.2\", \"Spring Boot 3.3\", \"Spring Boot 3.4\", \"Spring Boot 3.5\", \"Jakarta migration\", \"javax to jakarta\", \"Spring Boot native image\", \"RestClient\", \"JdbcClient\", \"virtual threads Spring\", \"@HttpExchange\", \"@ServiceConnection\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Spring Boot 3.x Version Expert

You are a specialist in Spring Boot 3.x (3.0 through 3.5), covering the current LTS-track release line. As of April 2026, only **3.5** remains in OSS support (ends June 2026). Spring Boot 4.0 is the current major version.

For foundational Spring Boot knowledge (IoC, auto-configuration, MVC, Security, Data, Actuator), refer to the parent technology agent. This agent focuses on what is new or changed in the 3.x line.

## Support Timeline

| Version | Released | OSS Support Ends | Status (Apr 2026) |
|---|---|---|---|
| 3.0 | Nov 2022 | Dec 2023 | EOL |
| 3.1 | May 2023 | Jun 2024 | EOL |
| 3.2 | Nov 2023 | Dec 2024 | EOL |
| 3.3 | May 2024 | Jun 2025 | Commercial only |
| 3.4 | Nov 2024 | Dec 2025 | Commercial only |
| 3.5 | May 2025 | Jun 2026 | OSS supported |

**Recommendation**: If starting a new project, use Spring Boot 4.0. Upgrade existing 3.x projects to 3.5 first, then to 4.0.

## 1. Jakarta EE Migration (3.0)

**This is the most impactful change in the 3.x line.** Every `javax.*` package from Java EE moved to `jakarta.*`. There is no compatibility bridge.

### Affected Packages

| Old (javax) | New (jakarta) |
|---|---|
| `javax.servlet` | `jakarta.servlet` |
| `javax.persistence` | `jakarta.persistence` |
| `javax.validation` | `jakarta.validation` |
| `javax.annotation` | `jakarta.annotation` |
| `javax.transaction` | `jakarta.transaction` |
| `javax.websocket` | `jakarta.websocket` |
| `javax.mail` | `jakarta.mail` |
| `javax.inject` | `jakarta.inject` |
| `javax.jms` | `jakarta.jms` |

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

### OpenRewrite Automated Migration

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
            <artifactId>rewrite-spring</artifactId>
            <version>5.x</version>
        </dependency>
    </dependencies>
</plugin>
```

```bash
./mvnw rewrite:dryRun   # preview
./mvnw rewrite:run      # apply
```

The composite recipe handles: Jakarta namespace, Java 17 upgrade, Spring Framework 6, Spring Security 6, Hibernate 6.1, Spring Batch 4 to 5, property renames, and more.

## 2. Java 17+ Baseline (3.0)

Java 17 is the minimum for all 3.x releases. Java 21 unlocks virtual threads (3.2+).

### Records as DTOs and Configuration

```java
// Record DTO -- works with @RequestBody, @ResponseBody, Spring Data projections
public record CreateUserRequest(
    @NotBlank String username,
    @Email String email
) {}

@PostMapping("/users")
public ResponseEntity<UserDto> create(@RequestBody @Valid CreateUserRequest request) { ... }

// Record-based @ConfigurationProperties
@ConfigurationProperties("app.mail")
public record MailProperties(String host, int port, boolean ssl) {}
```

### Sealed Classes for Domain Modeling

```java
public sealed interface PaymentResult
    permits PaymentResult.Success, PaymentResult.Failed, PaymentResult.Pending {

    record Success(String transactionId, BigDecimal amount) implements PaymentResult {}
    record Failed(String reason, int errorCode) implements PaymentResult {}
    record Pending(String referenceId) implements PaymentResult {}
}

String describe(PaymentResult result) {
    return switch (result) {
        case PaymentResult.Success s  -> "Paid: " + s.transactionId();
        case PaymentResult.Failed f   -> "Failed: " + f.reason();
        case PaymentResult.Pending p  -> "Pending: " + p.referenceId();
    };
}
```

## 3. GraalVM Native Image (3.0)

Spring Boot 3.0 provides first-class GraalVM native image support via AOT processing. The AOT engine runs at build time, generating static bean definitions and GraalVM hint files.

### Build Commands

```bash
# Docker (no local GraalVM needed)
./mvnw -Pnative spring-boot:build-image

# Local native compile
./mvnw -Pnative native:compile
```

### Custom Runtime Hints

```java
public class MyRuntimeHints implements RuntimeHintsRegistrar {
    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        hints.reflection().registerMethod(
            ReflectionUtils.findMethod(MyClass.class, "process", String.class),
            ExecutableMode.INVOKE);
        hints.resources().registerPattern("templates/*.html");
    }
}

@SpringBootApplication
@ImportRuntimeHints(MyRuntimeHints.class)
public class MyApplication { ... }
```

For serialized classes: `@RegisterReflectionForBinding(UserDto.class)`.

**Key limitations**: Closed-world assumption, no `@Profile` switching, `@MockBean`/`@SpyBean` unsupported, reflection requires explicit hints. See parent agent `references/best-practices.md` for the full limitations table.

## 4. Observability -- Micrometer Observation API (3.0)

Replaces Spring Cloud Sleuth with a unified API tying metrics, tracing, and logging together.

### Configuration

```yaml
management:
  tracing:
    sampling:
      probability: 1.0  # default is 0.1
  opentelemetry:
    tracing:
      export:
        otlp:
          endpoint: http://localhost:4318/v1/traces
```

### Log Correlation

Spring Boot automatically injects `traceId` and `spanId` into MDC:

```yaml
logging:
  pattern:
    correlation: "[${spring.application.name:},%X{traceId:-},%X{spanId:-}] "
```

### Custom Observations

```java
@Service
public class UserService {
    private final ObservationRegistry observationRegistry;

    public User createUser(String email) {
        return Observation.createNotStarted("user.create", observationRegistry)
            .lowCardinalityKeyValue("operation", "create")
            .highCardinalityKeyValue("email", email)
            .observe(() -> doCreateUser(email));
    }
}
```

### @Observed Annotation (requires spring-boot-starter-aop)

```java
@Service
public class PaymentService {
    @Observed(name = "payment.process", contextualName = "processing-payment")
    public PaymentResult processPayment(PaymentRequest request) {
        return doProcess(request);
    }
}
```

## 5. HTTP Interface Clients -- @HttpExchange (3.0)

Declarative HTTP interfaces replacing verbose WebClient/RestTemplate boilerplate:

```java
@HttpExchange(url = "/users", contentType = MediaType.APPLICATION_JSON_VALUE)
public interface UserClient {

    @GetExchange("/{id}")
    User getById(@PathVariable Long id);

    @PostExchange
    ResponseEntity<Void> create(@RequestBody CreateUserRequest request);

    @DeleteExchange("/{id}")
    void delete(@PathVariable Long id);
}
```

### Proxy Factory Setup (3.2+ with RestClient)

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

Available annotations: `@GetExchange`, `@PostExchange`, `@PutExchange`, `@PatchExchange`, `@DeleteExchange`.

## 6. ProblemDetail -- RFC 7807/9457 (3.0)

```yaml
spring:
  mvc:
    problemdetails:
      enabled: true
```

```java
@ControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {
    @ExceptionHandler(RecordNotFoundException.class)
    public ProblemDetail handleNotFound(RecordNotFoundException ex) {
        ProblemDetail body = ProblemDetail.forStatusAndDetail(
            HttpStatus.NOT_FOUND, ex.getMessage());
        body.setTitle("Record Not Found");
        body.setProperty("errorCode", "REC_404");
        return body;
    }
}
```

All Spring MVC exceptions implement `ErrorResponse` and serialize as `application/problem+json` automatically when enabled.

## 7. Security Changes (3.0)

`WebSecurityConfigurerAdapter` removed. Lambda DSL is the only approach:

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
                .anyRequest().authenticated())
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
        return http.build();
    }
}
```

Key API changes from 2.x:
- `antMatchers()` -> `requestMatchers()`
- `authorizeRequests()` -> `authorizeHttpRequests()`
- Chained `.and()` removed -- use lambda DSL
- `spring-boot-starter-oauth2-authorization-server` added in 3.1

## 8. Virtual Threads (3.2, Java 21)

```yaml
spring:
  threads:
    virtual:
      enabled: true
```

When enabled: Tomcat, Jetty, `@Async`, and scheduled tasks all use virtual threads. Standard blocking code scales without thread pool sizing concerns:

```java
@RestController
public class UserController {
    @GetMapping("/users/{id}")
    public User getUser(@PathVariable Long id) {
        // Blocking JDBC -- scales fine on virtual threads
        return userRepository.findById(id).orElseThrow();
    }
}
```

**Impact**: Eliminates the main motivation for adopting WebFlux in I/O-bound applications.

## 9. RestClient (3.2)

Modern, fluent, synchronous HTTP client replacing `RestTemplate`:

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
            .body(new ParameterizedTypeReference<>() {});
    }

    public Post findById(Long id) {
        return restClient.get()
            .uri("/posts/{id}", id)
            .retrieve()
            .body(Post.class);
    }
}
```

## 10. JdbcClient (3.2)

Fluent JDBC API without Spring Data JPA:

```java
@Repository
public class UserRepository {
    private final JdbcClient jdbcClient;

    public UserRepository(JdbcClient jdbcClient) {
        this.jdbcClient = jdbcClient;
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

## 11. Class Data Sharing -- CDS (3.3)

~40-50% startup reduction without native image limitations:

```bash
# Training run
java -XX:ArchiveClassesAtExit=./application.jsa \
     -Dspring.context.exit=onRefresh -jar target/myapp.jar

# Production run
java -XX:SharedArchiveFile=application.jsa -jar target/myapp.jar
```

With Buildpacks: `BP_JVM_AOTCACHE_ENABLED=true ./mvnw spring-boot:build-image`

## 12. @ServiceConnection for Testcontainers (3.1, expanded 3.3)

```java
@SpringBootTest
@Testcontainers
class IntegrationTest {
    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @Container
    @ServiceConnection
    static RedisContainer redis = new RedisContainer("redis:7");

    // No manual @DynamicPropertySource needed
}
```

Supports: PostgreSQL, MySQL, MariaDB, MongoDB, Redis, Kafka, RabbitMQ, Cassandra, Elasticsearch, Neo4j, ActiveMQ, Artemis, LDAP, Couchbase, R2DBC variants.

## 13. Structured Logging (3.4)

```yaml
logging:
  structured:
    format:
      console: ecs          # Elastic Common Schema
      # console: logstash   # Logstash JSON
      # console: gelf       # Graylog Extended Log Format
```

Output:
```json
{
  "@timestamp": "2024-01-15T10:23:45.123Z",
  "log.level": "INFO",
  "message": "User created successfully",
  "service.name": "my-service",
  "trace.id": "803b448a0489f84084905d3093480352"
}
```

## 14. CRaC -- Coordinated Restore at Checkpoint (3.2)

Captures a running JVM checkpoint and restores it for near-instant startup while maintaining JIT-warmed throughput. Linux only. Spring Boot provides `SmartLifecycle` integration to properly close and reopen resources around checkpoints.

## Feature-to-Version Matrix

| Feature | Version |
|---|---|
| Jakarta EE 9 (javax -> jakarta) | 3.0 |
| Java 17 minimum | 3.0 |
| GraalVM native image (first-class) | 3.0 |
| Micrometer Observation API | 3.0 |
| @HttpExchange declarative clients | 3.0 |
| ProblemDetail / RFC 7807 | 3.0 |
| SecurityFilterChain (WebSecurityConfigurerAdapter removed) | 3.0 |
| spring-authorization-server starter | 3.1 |
| @ServiceConnection (Testcontainers) | 3.1 |
| Virtual threads (`spring.threads.virtual.enabled`) | 3.2 (Java 21) |
| RestClient | 3.2 |
| JdbcClient | 3.2 |
| CRaC support | 3.2 |
| Class Data Sharing (CDS) | 3.3 |
| @ServiceConnection expanded | 3.3 |
| Structured logging (ECS, Logstash, GELF) | 3.4 |

## Migration Path to 4.0

Spring Boot 3.5 is the bridge release. Upgrade to 3.5 first -- it deprecates everything removed in 4.0, giving compiler warnings without breaking your build. Then move to 4.0. See `4.0/SKILL.md` for full migration guidance.
