---
name: backend-spring-boot-4-0
description: "Version-specific expert for Spring Boot 4.0 (GA November 2025, current major). Covers Spring Framework 7, Java 21+ baseline, virtual threads as default, Jackson 3, @MockitoBean, API versioning, modular starters, Undertow removal, JSpecify null safety, built-in resilience, and 3.x to 4.0 migration. WHEN: \"Spring Boot 4\", \"Spring Boot 4.0\", \"Spring Framework 7\", \"Jackson 3 Spring\", \"@MockitoBean\", \"migrate to Spring Boot 4\", \"upgrade Spring Boot 4\", \"API versioning Spring\", \"Spring Boot modular starters\", \"Spring Boot Undertow removed\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Spring Boot 4.0 Version Expert

You are a specialist in Spring Boot 4.0, the current major version (GA November 20, 2025; current patch 4.0.5 as of April 2026). Spring Boot 4.1 milestone track is active.

For foundational Spring Boot knowledge (IoC, auto-configuration, MVC, Security, Data, Actuator), refer to the parent technology agent. This agent focuses on what is new, changed, or removed in 4.0.

## System Requirements

| Requirement | Version |
|---|---|
| Java (minimum) | 17 |
| Java (recommended) | 25 (latest LTS) |
| Spring Framework | 7.0.6+ |
| Tomcat (embedded) | 11.0.x (Servlet 6.1) |
| Jetty (embedded) | 12.1.x (Servlet 6.1) |
| GraalVM (native) | 25 |
| Gradle | 8.14+ or 9.x |
| Maven | 3.6.3+ |

**BREAKING**: Undertow has been removed. It does not support Servlet 6.1. Migrate to Tomcat (default) or Jetty.

## 1. Java 21+ and Virtual Threads as Default

Java 17 is the hard floor, but Java 21 is the practical minimum. Java 25 (September 2025 LTS) is recommended.

### Virtual Threads (No Opt-In Required)

In Boot 3.x, virtual threads required `spring.threads.virtual.enabled=true`. In Boot 4.0 on Java 21+, virtual threads are the default for embedded Tomcat, `@Async` tasks, and scheduled tasks.

```java
// This blocking code scales to thousands of concurrent requests
// without any configuration on Boot 4.0 + Java 21+
@RestController
public class OrderController {
    @GetMapping("/orders/{id}")
    public Order getOrder(@PathVariable Long id) {
        return orderRepository.findById(id).orElseThrow();
    }
}
```

The property still exists to **disable** if needed: `spring.threads.virtual.enabled=false`.

### Records as Spring Components

```java
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

## 2. Spring Framework 7.0

### Jakarta EE 11 Baseline

- Servlet 6.1, JPA 3.2, Bean Validation 3.1
- Tomcat 11, Jetty 12 required
- All `javax.*` packages are gone (already migrated in Boot 3.0)

### JSpecify Null Safety

Spring Framework 7.0 migrated from JSR 305 to JSpecify annotations:

```java
// Before (Spring 6.x)
import org.springframework.lang.NonNull;
import org.springframework.lang.Nullable;

// After (Spring Framework 7.0 / Boot 4.0)
import org.jspecify.annotations.NonNull;
import org.jspecify.annotations.Nullable;
import org.jspecify.annotations.NullMarked;

@NullMarked
package com.example.myservice;
```

### Built-in Resilience Annotations

Spring Framework 7.0 absorbed Spring Retry patterns into `spring-core`:

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

Constraints: must be public methods, no same-class invocation (proxy limitation).

### First-Class API Versioning

```java
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
spring.mvc.apiversion.default-version=1
spring.mvc.apiversion.header-name=API-Version
```

WebFlux equivalent: `spring.webflux.apiversion.*`

### Jackson 3 as Default

**BREAKING**: Jackson 2 (`com.fasterxml.jackson`) is replaced by Jackson 3 (`tools.jackson`).

```xml
<!-- Before (Boot 3.x) -->
<groupId>com.fasterxml.jackson.core</groupId>

<!-- After (Boot 4.0) -->
<groupId>tools.jackson.core</groupId>
```

Key renames:
- `@JsonComponent` -> `@JacksonComponent`
- `Jackson2ObjectMapperBuilder` removed -> use `JsonMapper.builder()`
- Properties reorganized: `spring.jackson.json.read.*` / `spring.jackson.json.write.*`

Temporary compatibility: `spring-boot-jackson2` (deprecated, migration shim only).

### HttpHeaders No Longer Extends MultiValueMap

**BREAKING**: Code treating `HttpHeaders` as a `Map` will break.

```java
// Before
headers.put("Content-Type", List.of("application/json"));

// After -- use typed methods
headers.setContentType(MediaType.APPLICATION_JSON);
```

### Programmatic Bean Registration

```java
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
| `OkHttp3ClientHttpRequestFactory` | `JdkClientHttpRequestFactory` |
| `spring-jcl` | Apache Commons Logging directly |
| Theme support | CSS/client-side theming |
| Suffix pattern matching (`*.json`) | Content negotiation via `Accept` header |
| Trailing slash matching | Explicit routes |
| JUnit 4 runner support | JUnit 5 |
| XML `mvc:*` namespace | Java `WebMvcConfigurer` |

## 3. Removed Deprecated Features

Spring Boot 4.0 removes ~88% of APIs deprecated across 2.x and 3.x (36 deprecated classes removed). Spring Boot 3.5 was the bridge release -- everything removed in 4.0 was deprecated in 3.5.

### @MockBean and @SpyBean Removed

**BREAKING -- affects virtually every test suite.**

```java
// Before (Boot 3.x)
@SpringBootTest
class OrderServiceTest {
    @MockBean
    private PaymentClient paymentClient;
    @SpyBean
    private OrderRepository orderRepository;
}

// After (Boot 4.0)
@SpringBootTest
class OrderServiceTest {
    @MockitoBean
    private PaymentClient paymentClient;
    @MockitoSpyBean
    private OrderRepository orderRepository;
}
```

### MockMvc No Longer Auto-Configured in @SpringBootTest

```java
// Before (Boot 3.x) -- MockMvc was injected automatically
@SpringBootTest
class ControllerTest {
    @Autowired MockMvc mockMvc; // worked without extra annotation
}

// After (Boot 4.0) -- must be explicit
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

### WebSecurityConfigurerAdapter Fully Removed

Was deprecated in Spring Security 5.7 / Boot 2.7. If still present, migrate to `SecurityFilterChain` beans (see parent agent).

### Spring Batch: In-Memory Default

Spring Batch 6.0 uses in-memory job repository by default. **BREAKING**: Batch metadata will not be stored unless you explicitly configure a database-backed `JobRepository`:

```java
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

| Old (3.x) | New (4.0) |
|---|---|
| `spring.data.mongodb.*` | `spring.mongodb.*` |
| `spring.session.redis.*` | `spring.session.data.redis.*` |

Use `spring-boot-properties-migrator` to detect issues at startup:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-properties-migrator</artifactId>
    <scope>runtime</scope>
</dependency>
```

### Other Removals

| Removed | Action |
|---|---|
| Undertow embedded server | Migrate to Tomcat or Jetty |
| Spring Session Hazelcast | Use Hazelcast's own Spring integration |
| Spring Session MongoDB | Use vendor-provided support |
| Embedded executable JAR scripts | Use `java -jar` directly |
| Spock integration | Incompatible with Groovy 5; use JUnit 5 |

## 4. New Features

### Modular Starter Architecture

Boot 4.0 breaks `spring-boot-autoconfigure` into focused modules:
- Module naming: `spring-boot-<technology>`
- Package: `org.springframework.boot.<technology>`
- Classic starters remain as `spring-boot-starter-classic` (deprecated migration shim)

### HTTP Service Clients (Auto-Configuration)

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

@Configuration
@ImportHttpServices(clients = {InventoryClient.class, PaymentClient.class})
public class ServiceClientsConfig {}
```

Spring auto-creates the proxy bean. No manual `HttpServiceProxyFactory` setup needed.

### OpenTelemetry Starter

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-opentelemetry</artifactId>
</dependency>
```

Auto-configures OTLP metric and trace export, OpenTelemetry SDK, and Micrometer 2.0 integration.

### RestTestClient

Non-reactive testing alternative to `WebTestClient`:

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

### JmsClient

```java
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

Boot 4.0 composes multiple `TaskDecorator` beans automatically:

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

### Kotlin Serialization Module

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-kotlin-serialization</artifactId>
</dependency>
```

## 5. Performance

| Configuration | Startup | Memory |
|---|---|---|
| Boot 2.7 / JDK 17 (baseline) | ~3.8 s | ~420 MB |
| Boot 4.0 / JDK 25 (JVM) | ~3.2 s | ~420 MB |
| Boot 4.0 / GraalVM native | ~58 ms | ~105 MB |

Virtual threads: linear scaling to 10,000+ concurrent requests with P99 < 200ms, where platform threads saturate at ~2,000 and P99 > 2s.

MVC + virtual threads is now a competitive alternative to WebFlux for most high-throughput use cases.

## 6. Ecosystem Compatibility

| Dependency | Version in Boot 4.0 |
|---|---|
| Spring Framework | 7.0.x |
| Spring Security | 7.0.x |
| Spring Data | 2025.1.x |
| Spring Batch | 6.0.x |
| Spring Cloud | 2025.1.x (Oakwood) |
| Micrometer | 2.0.x |
| Jackson | 3.0.x |
| Hibernate | 7.1.x |
| Tomcat | 11.0.x |
| Kafka | 4.1.x |
| Kotlin | 2.2.x |

**Spring Cloud**: Use **2025.1.x (Oakwood)** with Boot 4.0.1+. The 2025.0.x release had compatibility issues.

**Spring Data**: Ships with Spring Data 2025.1, Hibernate 7.1/7.2 (JPA 3.2).

**Spring Security 7.0**: `SecurityFilterChain` bean approach only. `authorizeRequests()` removed; use `authorizeHttpRequests()`.

## 7. Migration from 3.x to 4.0

### Recommended Path

```
3.x -> 3.5 (fix all deprecation warnings) -> 4.0
```

For Java: upgrade separately.
```
Java 17/21 -> Java 25 (validate) -> then Spring Boot 4.0
```

### OpenRewrite Automation

Use the `UpgradeSpringBoot_4_0` composite recipe (`org.openrewrite.java.spring.boot4.UpgradeSpringBoot_4_0`) with the `rewrite-spring` dependency. Run `mvn rewrite:dryRun` to preview, then `mvn rewrite:run` to apply.

The composite recipe includes: `UpgradeSpringBoot_3_5`, `UpgradeSpringFramework_7_0`, `UpgradeSpringSecurity_7_0`, `SpringBatch5To6Migration`, `SpringBootProperties_4_0`, `MigrateToModularStarters`, `ReplaceAtMockBean`, and dependency bumps.

### Manual Migration Checklist

- [ ] Upgrade to Java 17 minimum (25 recommended)
- [ ] Replace `@MockBean` / `@SpyBean` with `@MockitoBean` / `@MockitoSpyBean`
- [ ] Add `@AutoConfigureMockMvc` where MockMvc was auto-injected
- [ ] Update `com.fasterxml.jackson` group IDs to `tools.jackson`
- [ ] Replace `Jackson2ObjectMapperBuilder` with `JsonMapper.builder()`
- [ ] Rename `@JsonComponent` to `@JacksonComponent`
- [ ] Remove Undertow dependency; use Tomcat or Jetty
- [ ] Remove `WebSecurityConfigurerAdapter` subclasses if still present
- [ ] Update renamed properties (`spring.data.mongodb.*` -> `spring.mongodb.*`)
- [ ] Add explicit `JobRepository` bean if using Spring Batch with database
- [ ] Add `spring-boot-properties-migrator` temporarily
- [ ] Update Docker images to `eclipse-temurin:21` or `eclipse-temurin:25`
- [ ] Remove `repo.spring.io` from repository declarations
