# Spring Boot 4.0 Research

**Status**: GA — released November 20, 2025. Current patch: 4.0.5 (as of April 2026). Spring Boot 4.1 milestone track is active (4.1.0-M4 released March 26, 2026).

---

## System Requirements

| Requirement | Version |
|---|---|
| Java (minimum) | 17 |
| Java (recommended) | 25 (latest LTS) |
| Java (maximum tested) | 26 |
| Spring Framework | 7.0.6+ |
| Maven | 3.6.3+ |
| Gradle | 8.14+ or 9.x |
| Tomcat (embedded) | 11.0.x (Servlet 6.1) |
| Jetty (embedded) | 12.1.x (Servlet 6.1) |
| GraalVM (native) | 25 |
| Native Build Tools | 0.11.5 |

**BREAKING**: Undertow has been removed. It does not yet support the Servlet 6.1 baseline required by Spring Boot 4.0. Migrate to Tomcat (default) or Jetty.

---

## 1. Java 21+ and the New Baseline

Spring Boot 4.0's hard floor is **Java 17**, but Java 21 is the practical minimum to access the headline features. Java 25 (September 2025 LTS) is the recommended target.

### Virtual Threads as First-Class Citizens

Virtual threads (Project Loom) were opt-in in Boot 3.x via a single property. Boot 4.0 integrates them more deeply, with virtual thread support wired into the embedded server, task executors, and scheduled task infrastructure without manual configuration on Java 21+.

**Before (Boot 3.x opt-in):**
```properties
spring.threads.virtual.enabled=true
```

**After (Boot 4.0 on Java 21+):**
Virtual thread execution is the default for embedded Tomcat and `@Async` tasks when running on Java 21+. The property still exists to disable it if needed, but enabling is no longer required.

### Structured Concurrency

Java 21 structured concurrency APIs (incubating → preview → stable progression) are now usable without feature flags on Java 25. Spring does not yet provide abstractions over `StructuredTaskScope` but the runtime is fully compatible.

### Pattern Matching and Records in Components

```java
// Record-based Spring component (Boot 4.0 + Java 21+)
@Service
public record OrderService(OrderRepository repo, PaymentClient payments) {
    public OrderResult process(Object event) {
        return switch (event) {
            case OrderCreated(var id, var items) -> createOrder(id, items);
            case OrderCancelled(var id)          -> cancelOrder(id);
            default -> OrderResult.ignored();
        };
    }
}
```

Constructor injection via records is fully supported. `@ConfigurationProperties` on records is stable.

---

## 2. Spring Framework 7.0

Spring Boot 4.0 requires Spring Framework 7.0. Key changes:

### Jakarta EE 11 Baseline

- Servlet 6.1, JPA 3.2, Bean Validation 3.1
- All `javax.*` packages are gone — only `jakarta.*` exists
- Tomcat 11, Jetty 12 required

### Null Safety: JSpecify Migration

Spring Framework 7.0 migrated from JSR 305 (`@NonNull`, `@Nullable` from `org.springframework.lang`) to JSpecify annotations. This improves Kotlin integration and static analysis tooling.

```java
// Before (Spring 6.x)
import org.springframework.lang.NonNull;
import org.springframework.lang.Nullable;

// After (Spring Framework 7.0 / Boot 4.0)
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;
import org.jspecify.annotations.NullMarked;

// Package-level: mark entire package as non-null by default
@NullMarked
package com.example.myservice;
```

### Built-in Resilience Annotations

Spring Framework 7.0 absorbed Spring Retry patterns directly into `spring-core`. No more `spring-retry` dependency for basic use cases.

```java
@Configuration
@EnableResilientMethods
public class ResilienceConfig {}

@Service
public class PaymentClient {

    @Retryable(maxAttempts = 3, backoff = @Backoff(delay = 500, multiplier = 2))
    @ConcurrencyLimit(5)
    public PaymentResult charge(String orderId, Money amount) {
        return externalGateway.call(orderId, amount);
    }

    @Recover
    public PaymentResult fallback(RuntimeException ex, String orderId, Money amount) {
        return PaymentResult.deferred(orderId);
    }
}
```

Constraints: must be public methods, no same-class invocation (proxy limitation), fallback signature must match.

### API Versioning (First-Class)

No more `/api/v1/` URL prefixes or custom filters for versioning:

```java
// Spring MVC — version via header
@RestController
@RequestMapping("/orders")
public class OrderController {

    @GetMapping(version = "1")
    public List<OrderV1> listV1() { ... }

    @GetMapping(version = "2")
    public List<OrderV2> listV2() { ... }
}
```

```properties
# application.properties
spring.mvc.apiversion.default-version=1
spring.mvc.apiversion.header-name=API-Version
```

WebFlux equivalent: `spring.webflux.apiversion.*`

### HttpHeaders No Longer Extends MultiValueMap

**BREAKING.** Code that treated `HttpHeaders` as a `Map` will break.

```java
// Before
HttpHeaders headers = new HttpHeaders();
headers.put("Content-Type", List.of("application/json")); // Map method

// After
HttpHeaders headers = new HttpHeaders();
headers.setContentType(MediaType.APPLICATION_JSON); // use typed methods
```

### Jackson 3 as Default

Spring Framework 7.0 defaults to Jackson 3 (`tools.jackson` group ID). Jackson 2.x is deprecated.

```xml
<!-- Before (Boot 3.x) -->
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-databind</artifactId>
</dependency>

<!-- After (Boot 4.0) -->
<dependency>
    <groupId>tools.jackson.core</groupId>
    <artifactId>jackson-databind</artifactId>
</dependency>
```

Key annotation renames:
- `@JsonComponent` → `@JacksonComponent`
- `Jackson2ObjectMapperBuilder` removed → use `JsonMapper.builder()`
- Properties reorganized: `spring.jackson.json.read.*` / `spring.jackson.json.write.*`

Compatibility shim: `spring-boot-jackson2` (deprecated, use only for temporary migration).

### Programmatic Bean Registration

```java
// New BeanRegistrar contract for dynamic registration
public class FeatureBeans implements BeanRegistrar {
    @Override
    public void register(BeanRegistry registry, Environment env) {
        if (env.matchesProfiles("cloud")) {
            registry.registerBean(CloudMetricsCollector.class);
        }
    }
}
```

### Removed from Spring Framework 7.0

| Removed | Replacement |
|---|---|
| `ListenableFuture` | `CompletableFuture` |
| `OkHttp3ClientHttpRequestFactory` | `JdkClientHttpRequestFactory` or `ReactorClientHttpRequestFactory` |
| `spring-jcl` | Apache Commons Logging directly |
| `Theme` support | CSS/client-side theming |
| Suffix pattern matching (`*.json`) | Content negotiation via `Accept` header |
| Trailing slash matching | Explicit routes |
| JUnit 4 runner support | JUnit 5 |
| XML `mvc:*` namespace | Java `WebMvcConfigurer` |

---

## 3. Removed Deprecated Features (from 3.x)

Spring Boot 4.0 removes ~88% of APIs deprecated across the 2.x and 3.x lines (36 deprecated classes removed). Spring Boot 3.5 was the "bridge" release — everything removed in 4.0 was deprecated in 3.5.

### Testing Annotation Removals

**BREAKING — affects virtually every test suite.**

```java
// Before (Spring Boot 3.x)
@SpringBootTest
class OrderServiceTest {
    @MockBean
    private PaymentClient paymentClient;

    @SpyBean
    private OrderRepository orderRepository;
}

// After (Spring Boot 4.0)
@SpringBootTest
class OrderServiceTest {
    @MockitoBean
    private PaymentClient paymentClient;

    @MockitoSpyBean
    private OrderRepository orderRepository;
}
```

`MockitoTestExecutionListener` is also removed. Use Mockito's `MockitoExtension` directly.

### MockMVC No Longer Auto-Configured in @SpringBootTest

```java
// Before (Boot 3.x) — MockMvc was injected automatically
@SpringBootTest
class ControllerTest {
    @Autowired MockMvc mockMvc; // worked without extra annotation
}

// After (Boot 4.0) — must be explicit
@SpringBootTest
@AutoConfigureMockMvc
class ControllerTest {
    @Autowired MockMvc mockMvc;
}

// Or use the new RestTestClient
@SpringBootTest(webEnvironment = RANDOM_PORT)
@AutoConfigureRestTestClient
class ControllerTest {
    @Autowired RestTestClient restTestClient;
}
```

### WebSecurityConfigurerAdapter Removed

Was deprecated in Spring Security 5.7 / Boot 2.7, removed in Boot 4.0.

```java
// Before
@Configuration
public class SecurityConfig extends WebSecurityConfigurerAdapter {
    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http.authorizeRequests().anyRequest().authenticated();
    }
}

// After
@Configuration
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.authorizeHttpRequests(auth -> auth.anyRequest().authenticated());
        return http.build();
    }
}
```

### Spring Batch: No Longer Requires a Database

Spring Batch 6.0 (bundled with Boot 4.0) uses in-memory job repository by default. **BREAKING**: On upgrade, Batch metadata will not be stored in your existing database unless you explicitly configure a `JobRepository` bean backed by a `DataSource`.

```java
// Boot 4.0: explicit database-backed job repository
@Configuration
public class BatchConfig {
    @Bean
    public JobRepository jobRepository(DataSource dataSource,
                                       PlatformTransactionManager txManager) throws Exception {
        return new JdbcJobRepositoryFactoryBean()
            .setDataSource(dataSource)
            .setTransactionManager(txManager)
            .getObject();
    }
}
```

### Property Renames

| Old Property (3.x) | New Property (4.0) |
|---|---|
| `spring.data.mongodb.*` | `spring.mongodb.*` (except Spring Data-specific keys) |
| `spring.session.redis.*` | `spring.session.data.redis.*` |

Use `spring-boot-properties-migrator` to detect renamed/removed properties at startup (add as a temporary runtime dependency, remove after migration):

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-properties-migrator</artifactId>
    <scope>runtime</scope>
</dependency>
```

### Removed Embedded Server and Session Backends

| Removed | Action Required |
|---|---|
| Undertow | Migrate to Tomcat or Jetty |
| Spring Session Hazelcast | Use Hazelcast's own Spring integration |
| Spring Session MongoDB | Use vendor-provided support |
| Pulsar Reactive client | Use standard Pulsar client |
| Embedded executable JAR scripts | Use `java -jar` directly |
| Spock integration | Incompatible with Groovy 5; test in JUnit 5 |

---

## 4. New Features in Spring Boot 4.0

### Modular Starter Architecture

Boot 4.0 breaks the monolithic `spring-boot-autoconfigure` into focused modules, each with its own package namespace.

- Module naming: `spring-boot-<technology>`
- Package: `org.springframework.boot.<technology>`
- Test starter: `spring-boot-starter-<technology>-test`

Classic starters remain as a migration shim (`spring-boot-starter-classic`) but are deprecated.

### HTTP Service Clients (Auto-Configuration)

Declarative HTTP clients without Feign:

```java
@HttpServiceClient(
    name = "inventory-service",
    url = "${clients.inventory.base-url}"
)
public interface InventoryClient {

    @GetMapping("/products/{id}")
    ProductDto getProduct(@PathVariable String id);

    @PostMapping("/reservations")
    ReservationDto reserve(@RequestBody ReservationRequest request);
}
```

Spring auto-creates the proxy bean. Supports `@ImportHttpServices` for registering multiple clients in one place:

```java
@Configuration
@ImportHttpServices(clients = {InventoryClient.class, PaymentClient.class})
public class ServiceClientsConfig {}
```

### OpenTelemetry Starter

New dedicated starter replacing manual OTLP wiring:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-opentelemetry</artifactId>
</dependency>
```

Provides auto-configured OTLP metric and trace export, OpenTelemetry SDK initialization, and integration with Micrometer 2.0 and the Actuator.

### API Versioning Auto-Configuration

See Spring Framework 7.0 section above. Boot's contribution is auto-configuration of the versioning infrastructure from properties — no manual `@Bean` setup required for common cases.

### JmsClient Support

```java
// New fluent JmsClient alongside existing JmsTemplate
@Service
public class NotificationService {
    private final JmsClient jmsClient;

    public NotificationService(JmsClient jmsClient) {
        this.jmsClient = jmsClient;
    }

    public void send(Notification notification) {
        jmsClient.send("notifications", notification);
    }
}
```

### Multiple TaskDecorator Beans

Boot 4.0 composes multiple `TaskDecorator` beans automatically via `CompositeTaskDecorator`. Use `@Order` to control composition order:

```java
@Bean @Order(1)
public TaskDecorator mdcDecorator() {
    return runnable -> {
        Map<String, String> context = MDC.getCopyOfContextMap();
        return () -> {
            MDC.setContextMap(context);
            runnable.run();
        };
    };
}

@Bean @Order(2)
public TaskDecorator tracingDecorator() { ... }
```

### RestTestClient

A non-reactive testing alternative to `WebTestClient`, usable with either MockMvc or a running server:

```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@AutoConfigureRestTestClient
class OrderApiTest {
    @Autowired
    RestTestClient restTestClient;

    @Test
    void getOrder() {
        restTestClient.get().uri("/orders/123")
            .exchange()
            .expectStatus().isOk()
            .expectBody(OrderDto.class)
            .value(order -> assertThat(order.id()).isEqualTo("123"));
    }
}
```

### Kotlin Serialization Module

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-kotlin-serialization</artifactId>
</dependency>
```

Auto-configures a `Json` bean with `spring.kotlinx.serialization.json.*` properties and registers `HttpMessageConverter` for Kotlin serializable classes.

### Redis Static Master/Replica (Lettuce)

```properties
spring.data.redis.masterreplica.nodes=redis://primary:6379,redis://replica1:6379,redis://replica2:6379
```

### MongoDB Direct Driver Health

Health indicators no longer require Spring Data MongoDB. The raw Java driver connection is now health-checked directly, useful for applications using the Mongo driver without Spring Data.

### Milestones on Maven Central

Starting with 4.0.0-M1, all milestones and release candidates publish to Maven Central. No more `repo.spring.io` repository declaration for pre-releases.

---

## 5. Migration from 3.x to 4.0

### Recommended Migration Path

Spring Boot 3.5 is the bridge release. Migrate to 3.5 first — it deprecates everything removed in 4.0, giving you compiler warnings without breaking your build. Then move to 4.0.

```
3.x → 3.5 (fix all deprecation warnings) → 4.0
```

For Java: treat it as a separate axis.

```
Java 17/21 → Java 25 (validate) → then Spring Boot 4.0 upgrade
```

### OpenRewrite Automation

The `UpgradeSpringBoot_4_0` composite recipe handles the mechanical migration:

**Maven:**
```xml
<plugin>
    <groupId>org.openrewrite.maven</groupId>
    <artifactId>rewrite-maven-plugin</artifactId>
    <version>5.x</version>
    <configuration>
        <activeRecipes>
            <recipe>org.openrewrite.java.spring.boot4.UpgradeSpringBoot_4_0</recipe>
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
mvn rewrite:dryRun   # preview changes
mvn rewrite:run      # apply changes
mvn clean compile && mvn test
```

**What the composite recipe includes:**
- `UpgradeSpringBoot_3_5` (if not already on 3.5)
- `UpgradeSpringCloud_2025_1`
- `UpgradeSpringFramework_7_0`
- `UpgradeSpringSecurity_7_0`
- `SpringBatch5To6Migration`
- `SpringBootProperties_4_0` (property renames)
- `MigrateToModularStarters`
- Dependency version bumps

**Additional targeted recipes:**
- `org.openrewrite.java.spring.boot4.SpringBootProperties_4_0` — property renames only
- `org.openrewrite.java.spring.boot4.MigrateToModularStarters` — starter restructuring only
- `org.openrewrite.java.spring.boot4.ReplaceAtMockBean` — `@MockBean` → `@MockitoBean`

For Java upgrade:
- `org.openrewrite.java.migrate.UpgradeToJava25`

### Manual Migration Checklist

- [ ] Upgrade to Java 17 minimum (25 recommended)
- [ ] Replace all `javax.*` imports with `jakarta.*`
- [ ] Remove Undertow dependency; add Jetty if not using Tomcat
- [ ] Replace `@MockBean` / `@SpyBean` with `@MockitoBean` / `@MockitoSpyBean`
- [ ] Add `@AutoConfigureMockMvc` where MockMvc was previously auto-injected
- [ ] Remove `WebSecurityConfigurerAdapter` subclasses; use `SecurityFilterChain` beans
- [ ] Update `com.fasterxml.jackson` group IDs to `tools.jackson`
- [ ] Replace `Jackson2ObjectMapperBuilder` with `JsonMapper.builder()`
- [ ] Rename `@JsonComponent` to `@JacksonComponent`
- [ ] Update renamed properties (`spring.data.mongodb.*` → `spring.mongodb.*`, etc.)
- [ ] Add explicit `JobRepository` bean if using Spring Batch with database persistence
- [ ] Update base Docker images to `eclipse-temurin:21` or `eclipse-temurin:25`
- [ ] Update Tomcat images to `tomcat:11-jdk21`
- [ ] Remove `repo.spring.io` from repository declarations
- [ ] Add `spring-boot-properties-migrator` temporarily to catch runtime property issues

---

## 6. Performance

### Startup Time

| Configuration | Startup Time |
|---|---|
| Spring Boot 2.7 / JDK 17 (baseline) | ~3.8 s |
| Spring Boot 4.0 / JDK 25 (JVM) | ~3.2 s |
| Spring Boot 4.0 / GraalVM Native Image | ~58 ms |

Native image = ~98% startup reduction vs legacy JVM baseline.

### Memory

| Configuration | Resident Memory |
|---|---|
| Traditional JVM | ~420 MB |
| GraalVM Native Image | ~105 MB |

75% memory reduction with native image.

### Throughput (Virtual Threads)

| Concurrency Model | 10,000 Concurrent Requests |
|---|---|
| Platform threads (Boot 3.x default) | Saturated at ~2,000 req; P99 > 2s |
| Virtual threads (Boot 4.0 on Java 21+) | Linear scaling; P99 < 200ms |

Virtual threads eliminate the need to migrate to reactive (WebFlux) for most high-throughput use cases. The `spring-webmvc` + virtual threads combination is now a competitive alternative to WebFlux.

### Modular Starters Impact

The new modular starter architecture reduces classpath size and removes unnecessary auto-configuration, contributing to faster startup on JVM (not just native).

---

## 7. Ecosystem Compatibility

### Spring Cloud

| Spring Cloud Release | Spring Boot Compatibility |
|---|---|
| 2025.0.x (Northfields) | Spring Boot 4.0.0 only |
| **2025.1.x (Oakwood)** | **Spring Boot 4.0.1+ (recommended)** |

**Use Spring Cloud 2025.1.x (Oakwood) with Spring Boot 4.0.** The 2025.0.x release had compatibility issues with Boot 4.0.1 and later patch releases. Oakwood GA was released November 25, 2025.

Spring Cloud component versions in Oakwood (2025.1.x):
- spring-cloud-bus: 5.0.x
- spring-cloud-circuitbreaker: 5.0.x
- spring-cloud-commons: 5.0.x
- spring-cloud-config: 5.0.x
- spring-cloud-gateway: 5.0.x
- spring-cloud-kubernetes: 5.0.x
- spring-cloud-netflix: 5.0.x (Eureka only; Hystrix, Ribbon long removed)

**Note**: Spring Cloud GCP and Spring Cloud AWS have separate release trains with their own Boot 4.0 support timelines. Check their respective GitHub issue trackers for status.

### Spring Data

Spring Boot 4.0 ships with **Spring Data 2025.1** as part of the Bill of Materials.

Key changes:
- Hibernate ORM 7.1/7.2 (JPA 3.2)
- MongoDB driver updated (direct driver health checks no longer require Spring Data MongoDB)
- Repository base class variants removed (deprecated in 3.x)

### Spring Security

Spring Boot 4.0 ships with **Spring Security 7.0**.

Key changes:
- `WebSecurityConfigurerAdapter` fully removed (see Migration section)
- `SecurityFilterChain` bean approach is the only supported model
- `HttpSecurity.authorizeRequests()` removed; use `authorizeHttpRequests()`
- Method security annotations updated

### Spring Batch

**Spring Batch 6.0** bundled. In-memory mode is now the default (no database required for simple jobs). Explicitly configure `JobRepository` if database persistence is needed.

### Other Key Dependency Versions

| Dependency | Version in Boot 4.0 |
|---|---|
| Spring Framework | 7.0.x |
| Spring Security | 7.0.x |
| Spring Data | 2025.1.x |
| Spring Batch | 6.0.x |
| Micrometer | 2.0.x (was 1.x) |
| Jackson | 3.0.x |
| Hibernate | 7.1.x |
| Tomcat | 11.0.x |
| Kafka | 4.1.x |
| Kotlin | 2.2.x |
| Gradle (supported) | 8.14+ / 9.x |

---

## Key Sources

- [Spring Boot 4.0 Release Notes](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Release-Notes)
- [Spring Boot 4.0 Migration Guide](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Migration-Guide)
- [Spring Framework 7.0 Release Notes](https://github.com/spring-projects/spring-framework/wiki/Spring-Framework-7.0-Release-Notes)
- [Spring Framework 7.0 GA announcement](https://spring.io/blog/2025/11/13/spring-framework-7-0-general-availability/)
- [Spring Cloud Oakwood GA](https://spring.io/blog/2025/11/25/spring-cloud-2025-1-0-aka-oakwood-has-been-released/)
- [OpenRewrite Spring Boot 4.0 recipes](https://docs.openrewrite.org/recipes/java/spring/boot4)
- [Spring Boot 4.0 system requirements](https://docs.spring.io/spring-boot/system-requirements.html)
- [Moderne: Spring Boot 4 Migration Guide](https://www.moderne.ai/blog/spring-boot-4x-migration-guide)
