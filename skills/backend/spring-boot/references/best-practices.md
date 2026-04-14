# Spring Boot Best Practices Reference

## Configuration Patterns

### @ConfigurationProperties (Type-Safe Binding)

Always prefer `@ConfigurationProperties` over `@Value` for anything beyond a single property:

```java
@ConfigurationProperties(prefix = "app.order")
@Validated
public class OrderProperties {

    @NotNull
    private String currencyCode = "USD";

    @Min(1) @Max(1000)
    private int maxItemsPerOrder = 100;

    private Duration processingTimeout = Duration.ofMinutes(5);

    private Retry retry = new Retry();

    @Data
    public static class Retry {
        private int maxAttempts = 3;
        private Duration backoff = Duration.ofSeconds(2);
    }
}
```

Record-based (immutable, Boot 3.x+):

```java
@ConfigurationProperties(prefix = "app.mail")
public record MailProperties(String host, int port, boolean ssl) {}
```

```yaml
app:
  order:
    currency-code: EUR            # kebab-case binds to camelCase
    max-items-per-order: 50
    processing-timeout: 10m
    retry:
      max-attempts: 5
      backoff: 3s
```

Register with `@ConfigurationPropertiesScan` or `@EnableConfigurationProperties(OrderProperties.class)`.

### Profiles

**File organization**: Use profile-specific files (`application-dev.yml`, `application-prod.yml`) with a shared base `application.yml`.

```yaml
# application.yml -- shared base
spring:
  application:
    name: order-service

---
# application-dev.yml
spring:
  datasource:
    url: jdbc:h2:mem:orders
  jpa:
    hibernate:
      ddl-auto: create-drop

---
# application-prod.yml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:5432/orders
```

Activation:
```bash
SPRING_PROFILES_ACTIVE=prod java -jar app.jar
java -Dspring.profiles.active=prod -jar app.jar
```

Profile-specific beans:
```java
@Configuration
@Profile("prod")
public class ProductionConfig {
    @Bean
    public DataSource productionDataSource() { ... }
}

@Configuration
@Profile("!prod")
public class LocalConfig { ... }
```

### Property Priority (High to Low)

1. Command-line arguments (`--server.port=9090`)
2. JNDI attributes
3. System properties (`-Dserver.port=9090`)
4. OS environment variables (`SERVER_PORT=9090`)
5. Profile-specific files outside JAR
6. Profile-specific files inside JAR
7. `application.yml` outside JAR
8. `application.yml` inside JAR
9. `@PropertySource` annotations
10. Default properties

### Relaxed Binding

All these bind to the same property:

| Form | Example |
|---|---|
| Kebab-case (recommended) | `max-items-per-order` |
| camelCase | `maxItemsPerOrder` |
| Underscore | `max_items_per_order` |
| UPPER_SNAKE_CASE (env vars) | `MAX_ITEMS_PER_ORDER` |

### Externalized Configuration for Microservices

Spring Cloud Config Server for centralized configuration:

```yaml
spring:
  config:
    import: configserver:http://config-server:8888
  cloud:
    config:
      name: order-service
      profile: prod
      label: main
```

Use `@RefreshScope` + `/actuator/refresh` for runtime config updates without restart.

---

## Testing Strategies

### Test Slices vs Full Context

| Annotation | Context Loaded | Use Case | Speed |
|---|---|---|---|
| `@SpringBootTest` | Full ApplicationContext | Integration tests | Slow |
| `@WebMvcTest` | MVC layer only | Controller unit tests | Fast |
| `@WebFluxTest` | WebFlux layer only | Reactive controller tests | Fast |
| `@DataJpaTest` | JPA layer only | Repository tests | Medium |
| `@DataMongoTest` | MongoDB layer only | Mongo repository tests | Medium |
| `@JsonTest` | Jackson/Gson only | Serialization tests | Fast |
| `@RestClientTest` | RestClient/WebClient | HTTP client tests | Fast |

**Always prefer the narrowest test slice.** Full `@SpringBootTest` is expensive and should be reserved for end-to-end integration tests.

### Controller Tests with @WebMvcTest

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean  // Boot 3.4+; use @MockBean on 3.0-3.3
    private OrderService orderService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void getOrder_existingId_returns200() throws Exception {
        given(orderService.findById(1L)).willReturn(Optional.of(new Order(1L, "PENDING")));

        mockMvc.perform(get("/api/orders/1")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1L))
            .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void createOrder_invalidRequest_returns400() throws Exception {
        CreateOrderRequest request = new CreateOrderRequest(null, -1);

        mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isBadRequest());
    }
}
```

### Repository Tests with @DataJpaTest

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = Replace.NONE) // Use real DB with Testcontainers
class OrderRepositoryTest {

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void findByStatus_returnsMatchingOrders() {
        entityManager.persist(new Order("PENDING"));
        entityManager.persist(new Order("COMPLETED"));
        entityManager.flush();

        List<Order> pending = orderRepository.findByStatus("PENDING");
        assertThat(pending).hasSize(1);
    }
}
```

### Testcontainers Integration

**Traditional approach** with `@DynamicPropertySource`:

```java
@SpringBootTest
@Testcontainers
class IntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
}
```

**@ServiceConnection** (Boot 3.1+, preferred):

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

    // No @DynamicPropertySource needed -- auto-configured
}
```

Supported containers: PostgreSQL, MySQL, MariaDB, MongoDB, Redis, Kafka, RabbitMQ, Cassandra, Elasticsearch, Neo4j, ActiveMQ, Artemis, LDAP, Couchbase, and R2DBC variants.

**Reusable test configuration**:

```java
@TestConfiguration(proxyBeanMethods = false)
public class TestContainersConfig {
    @Bean
    @ServiceConnection
    PostgreSQLContainer<?> postgresContainer() {
        return new PostgreSQLContainer<>("postgres:16-alpine");
    }
}
```

### Security in Tests

```java
@Test
@WithMockUser(roles = "ADMIN")
void adminEndpoint_withAdminRole_returns200() throws Exception {
    mockMvc.perform(delete("/api/orders/1"))
        .andExpect(status().isNoContent());
}

// Custom JWT decoder for tests
@TestConfiguration
static class TestSecurityConfig {
    @Bean
    @Primary
    public JwtDecoder jwtDecoder() {
        return token -> Jwt.withTokenValue(token)
            .header("alg", "none")
            .claim("sub", "test-user")
            .claim("roles", List.of("USER"))
            .issuedAt(Instant.now())
            .expiresAt(Instant.now().plusSeconds(3600))
            .build();
    }
}
```

---

## Security Hardening

### Secure Defaults Checklist

1. **CSRF**: Enabled by default for session-based apps. Disable only for stateless APIs with `csrf(csrf -> csrf.disable())`.
2. **CORS**: Explicitly configure allowed origins. Never use `allowedOrigins("*")` with `allowCredentials(true)`.
3. **Password encoding**: Always use `BCryptPasswordEncoder`. Never store plaintext.
4. **JWT validation**: Always set `issuer-uri` and validate `aud` claim.
5. **Actuator security**: Never expose all actuator endpoints without auth. Run on a separate port (`management.server.port=9090`) behind a firewall.
6. **SQL injection**: Use parameterized queries (`@Param` in `@Query`, JdbcClient named params). Never concatenate user input into SQL.
7. **Headers**: Spring Security sets `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Cache-Control: no-cache` by default.

### Multiple Security Filter Chains

```java
@Bean @Order(1)
public SecurityFilterChain apiChain(HttpSecurity http) throws Exception {
    http.securityMatcher("/api/**")
        .sessionManagement(s -> s.sessionCreationPolicy(STATELESS))
        .oauth2ResourceServer(o -> o.jwt(Customizer.withDefaults()));
    return http.build();
}

@Bean @Order(2)
public SecurityFilterChain webChain(HttpSecurity http) throws Exception {
    http.authorizeHttpRequests(a -> a.anyRequest().authenticated())
        .formLogin(Customizer.withDefaults());
    return http.build();
}
```

### Password Encoding

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12); // strength 4-31, default 10
}
```

---

## Performance Tuning

### Connection Pool (HikariCP)

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10        # default: 10
      minimum-idle: 5               # match max for fixed pool
      connection-timeout: 30000     # ms to wait for connection
      idle-timeout: 600000          # ms before idle connection removed
      max-lifetime: 1800000         # ms total connection lifetime
      leak-detection-threshold: 60000
```

**Sizing rule**: `pool size = (2 * CPU cores) + effective spindle count`. For cloud databases: start at 10, load test, adjust.

### Tomcat Thread Pool

```yaml
server:
  tomcat:
    threads:
      max: 200                # default; increase for I/O-heavy workloads
      min-spare: 10
    max-connections: 8192
    accept-count: 100
```

With virtual threads (Boot 3.2+ on Java 21): set `spring.threads.virtual.enabled=true` and these limits become less relevant since virtual threads don't exhaust a fixed pool.

### JPA Performance

1. **N+1 queries**: Use `@EntityGraph` or `JOIN FETCH`:
   ```java
   @EntityGraph(attributePaths = {"items", "customer"})
   Optional<Order> findById(Long id);
   ```

2. **Batch fetching**:
   ```yaml
   spring.jpa.properties.hibernate.default_batch_fetch_size: 20
   ```

3. **Projections** to avoid loading full entities:
   ```java
   List<OrderSummaryDto> findByStatus(String status);
   ```

4. **Read-only transactions** for queries:
   ```java
   @Transactional(readOnly = true)
   public List<Order> findAll() { ... }
   ```

5. **Second-level cache**:
   ```yaml
   spring.jpa.properties.hibernate.cache.use_second_level_cache: true
   spring.jpa.properties.hibernate.cache.region.factory_class: org.hibernate.cache.jcache.JCacheRegionFactory
   ```

### Response Compression

```yaml
server:
  compression:
    enabled: true
    mime-types: application/json,application/xml,text/html
    min-response-size: 1024
```

### HTTP/2

```yaml
server:
  http2:
    enabled: true
```

---

## GraalVM Native Image

### AOT Processing (Spring Boot 3.0+)

Spring Boot's AOT engine runs at build time, generating:
1. Static bean definitions (replacing reflection-based discovery)
2. Pre-generated proxies
3. GraalVM hint files in `META-INF/native-image/`

### Build Configuration

**Maven** (via `spring-boot-starter-parent` native profile):
```xml
<plugin>
    <groupId>org.graalvm.buildtools</groupId>
    <artifactId>native-maven-plugin</artifactId>
</plugin>
```

```bash
# Docker (no local GraalVM needed)
./mvnw -Pnative spring-boot:build-image

# Local native compile (requires GraalVM)
./mvnw -Pnative native:compile
```

**Gradle**:
```gradle
plugins {
    id 'org.graalvm.buildtools.native'
}
```

### Custom Runtime Hints

When AOT cannot infer hints automatically:

```java
public class MyRuntimeHints implements RuntimeHintsRegistrar {
    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        hints.reflection().registerMethod(
            ReflectionUtils.findMethod(MyClass.class, "process", String.class),
            ExecutableMode.INVOKE);
        hints.resources().registerPattern("templates/email/*.html");
        hints.proxies().registerJdkProxy(MyInterface.class);
    }
}

@SpringBootApplication
@ImportRuntimeHints(MyRuntimeHints.class)
public class MyApplication { ... }
```

For serialized classes:
```java
@RestController
@RegisterReflectionForBinding(UserDto.class)
public class UserController { ... }
```

### Known Limitations

| Limitation | Detail |
|---|---|
| Closed-world assumption | All code and deps must be known at build time |
| No `@Profile` switching | Profile selection happens at runtime |
| `@ConditionalOnProperty` limited | Cannot evaluate runtime conditions |
| No `@MockBean`/`@SpyBean` | Use `@DisabledInNativeImage` on those tests |
| Reflection requires hints | Any reflective access must be declared |
| Slower builds | AOT adds significant build time |

### JVM vs Native Comparison

| Aspect | Native Image | JVM |
|---|---|---|
| Startup time | Milliseconds | Seconds |
| Peak throughput | Lower (no JIT) | Higher |
| Memory footprint | Lower (~75% less) | Higher |
| Build time | Longer | Shorter |
| Classpath | Fixed at build | Flexible |
| Debugging | Limited | Full |

### Class Data Sharing (CDS, Boot 3.3+)

CDS offers a middle ground: ~40-50% startup reduction without native image limitations.

```bash
# Training run
java -XX:ArchiveClassesAtExit=./application.jsa \
     -Dspring.context.exit=onRefresh -jar target/myapp.jar

# Production run
java -XX:SharedArchiveFile=application.jsa -jar target/myapp.jar
```

---

## Actuator Best Practices

### Exposure and Security

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, metrics, prometheus, loggers
  endpoint:
    health:
      show-details: when-authorized
      show-components: always
  server:
    port: 9090    # Separate port -- firewall it
```

### Health Groups (Kubernetes Probes)

```yaml
management:
  endpoint:
    health:
      group:
        readiness:
          include: db, redis, diskSpace
        liveness:
          include: ping
```

Map to Kubernetes probes:
- Liveness: `/actuator/health/liveness`
- Readiness: `/actuator/health/readiness`

### Custom Health Indicators

```java
@Component
public class ExternalApiHealthIndicator extends AbstractHealthIndicator {
    @Override
    protected void doHealthCheck(Health.Builder builder) throws Exception {
        try {
            externalApi.ping();
            builder.up().withDetail("api", "reachable");
        } catch (Exception ex) {
            builder.down().withException(ex);
        }
    }
}
```

### Prometheus Integration

```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

Prometheus scrapes `/actuator/prometheus`. Grafana dashboards: Spring Boot dashboard ID 4701 or 12900.
