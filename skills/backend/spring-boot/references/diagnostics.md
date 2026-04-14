# Spring Boot Diagnostics Reference

## Debugging Auto-Configuration

### The --debug Flag

Run with `--debug` or set `debug=true` in `application.properties`. Spring Boot prints a full conditions evaluation report showing why each auto-configuration was applied or skipped:

```
============================
CONDITIONS EVALUATION REPORT
============================

Positive matches:
   DataSourceAutoConfiguration matched:
      - @ConditionalOnClass found required classes 'javax.sql.DataSource'
      - @ConditionalOnMissingBean did not find any bean of type 'DataSource'

Negative matches:
   MongoAutoConfiguration:
      - @ConditionalOnClass did not find required class 'com.mongodb.MongoClient'
```

### /actuator/conditions Endpoint

Runtime equivalent of `--debug`. Returns the conditions evaluation as JSON:

```bash
curl http://localhost:8080/actuator/conditions | jq .
```

Must be exposed:
```yaml
management:
  endpoints:
    web:
      exposure:
        include: conditions
```

### /actuator/beans Endpoint

Lists every bean in the ApplicationContext with its scope, type, and resource:

```bash
curl http://localhost:8080/actuator/beans | jq '.contexts[].beans | keys[]' | sort
```

### /actuator/env Endpoint

Shows all resolved properties and their sources (which file/env var they came from):

```bash
curl http://localhost:8080/actuator/env/spring.datasource.url
```

---

## Common Errors and Fixes

### Bean Not Found / NoSuchBeanDefinitionException

**Error**: `No qualifying bean of type 'com.example.MyService' available`

**Causes and fixes**:

1. **Class not in component scan path**: Ensure the class is in a package under `@SpringBootApplication`'s package.
   ```java
   // If @SpringBootApplication is in com.example.app,
   // com.example.other.MyService will NOT be found
   // Fix: move class, or add @ComponentScan(basePackages = {"com.example"})
   ```

2. **Missing stereotype annotation**: Ensure class has `@Component`, `@Service`, `@Repository`, or `@Controller`.

3. **Conditional not met**: An auto-configuration's `@ConditionalOnClass` or `@ConditionalOnProperty` is not satisfied. Check `--debug` output.

4. **Profile mismatch**: Bean annotated with `@Profile("prod")` but running with `dev` profile.

5. **Multiple candidates without qualifier**: When multiple beans of the same type exist, use `@Primary` or `@Qualifier`.
   ```java
   @Autowired
   @Qualifier("postgresDataSource")
   private DataSource dataSource;
   ```

### Circular Dependency

**Error**: `The dependencies of some of the beans in the application context form a cycle`

**Causes and fixes**:

1. **Redesign** (preferred): Break the cycle by extracting shared logic into a third bean.

2. **Setter injection** (workaround):
   ```java
   @Service
   public class ServiceA {
       private ServiceB serviceB;

       @Autowired
       public void setServiceB(ServiceB serviceB) {
           this.serviceB = serviceB;
       }
   }
   ```

3. **Lazy injection** (workaround):
   ```java
   @Service
   public class ServiceA {
       public ServiceA(@Lazy ServiceB serviceB) {
           this.serviceB = serviceB;
       }
   }
   ```

4. **Allow circular references** (last resort, not recommended):
   ```properties
   spring.main.allow-circular-references=true
   ```

### Auto-Configuration Not Firing

**Symptom**: Expected auto-configured bean is missing.

**Diagnostic steps**:

1. Run with `--debug` and check the CONDITIONS EVALUATION REPORT for the auto-configuration class name.

2. Common reasons for negative matches:
   - `@ConditionalOnClass` -- required dependency not in classpath. Add the starter/dependency.
   - `@ConditionalOnMissingBean` -- you defined a custom bean of that type, so auto-configuration backed off. This is intentional.
   - `@ConditionalOnProperty` -- required property not set or wrong value.

3. Check if auto-configuration is explicitly excluded:
   ```java
   @SpringBootApplication(exclude = {DataSourceAutoConfiguration.class})
   ```

4. For third-party libraries, verify their `AutoConfiguration.imports` file exists and lists the class.

### UnsatisfiedDependencyException

**Error**: `Unsatisfied dependency expressed through constructor parameter 0`

This is typically a transitive form of NoSuchBeanDefinitionException. Read the full stack trace -- the root cause is at the bottom and identifies which specific bean type could not be resolved.

### BeanCurrentlyInCreationException

**Error**: `Bean with name 'X' has been injected into other beans [Y] in its raw form as part of a circular reference`

This happens when Spring detects a circular dependency during singleton creation. See Circular Dependency section above.

---

## N+1 Query Detection

### Symptoms

- API response times increase linearly with result set size
- Database query count is `1 + N` where N is the number of results
- Hibernate logs show repeated `SELECT` statements with different IDs

### Enabling SQL Logging for Detection

```yaml
spring:
  jpa:
    show-sql: true
    properties:
      hibernate:
        format_sql: true

logging:
  level:
    org.hibernate.SQL: DEBUG
    org.hibernate.orm.jdbc.bind: TRACE  # Boot 3.x (Hibernate 6)
```

### Counting Queries in Tests

```java
@SpringBootTest
class PerformanceTest {

    @Autowired
    private EntityManager em;

    @Test
    void listOrders_shouldNotCauseNPlus1() {
        // Use Hibernate statistics
        SessionFactory sf = em.unwrap(Session.class).getSessionFactory();
        sf.getStatistics().setStatisticsEnabled(true);
        sf.getStatistics().clear();

        orderService.findAllWithItems();

        long queryCount = sf.getStatistics().getQueryExecutionCount();
        assertThat(queryCount).isLessThanOrEqualTo(2); // 1 for orders + 1 for items
    }
}
```

Enable statistics:
```yaml
spring.jpa.properties.hibernate.generate_statistics: true
```

### Fixes

1. **@EntityGraph** (declarative):
   ```java
   @EntityGraph(attributePaths = {"items", "customer"})
   List<Order> findByStatus(String status);
   ```

2. **JOIN FETCH in @Query**:
   ```java
   @Query("SELECT o FROM Order o JOIN FETCH o.items WHERE o.status = :status")
   List<Order> findByStatusWithItems(@Param("status") String status);
   ```

3. **Batch fetching** (global):
   ```yaml
   spring.jpa.properties.hibernate.default_batch_fetch_size: 20
   ```

4. **DTO projections** (avoid entity graph entirely):
   ```java
   @Query("SELECT new com.example.OrderSummaryDto(o.id, o.status) FROM Order o")
   List<OrderSummaryDto> findAllSummaries();
   ```

---

## Security Filter Chain Debugging

### Enable Security Debug Logging

```yaml
logging:
  level:
    org.springframework.security: DEBUG
    org.springframework.security.web.FilterChainProxy: TRACE
```

This logs every filter invocation and the security decision for each request.

### @EnableWebSecurity(debug = true)

**Development only** -- prints the complete filter chain for every request:

```java
@Configuration
@EnableWebSecurity(debug = true) // NEVER in production
public class SecurityConfig { ... }
```

Output:
```
Security filter chain: [
  DisableEncodeUrlFilter
  WebAsyncManagerIntegrationFilter
  SecurityContextHolderFilter
  HeaderWriterFilter
  CsrfFilter
  LogoutFilter
  BearerTokenAuthenticationFilter
  RequestCacheAwareFilter
  SecurityContextHolderAwareRequestFilter
  AnonymousAuthenticationFilter
  ExceptionTranslationFilter
  AuthorizationFilter
]
```

### Common Security Issues

**403 Forbidden on POST/PUT/DELETE**:
- CSRF is enabled by default. For stateless APIs, disable it: `csrf(csrf -> csrf.disable())`.
- For session-based apps, include the CSRF token in forms.

**401 Unauthorized with valid JWT**:
- Check `issuer-uri` matches the token's `iss` claim.
- Check `jwk-set-uri` is accessible from the server.
- Verify token has not expired (`exp` claim).
- Check audience (`aud`) claim if configured.

**CORS errors**:
- Spring Security's CORS filter must execute before auth. Configure via `HttpSecurity.cors()`.
- `Access-Control-Allow-Origin` must match exactly (no trailing slash).
- Pre-flight `OPTIONS` requests must be permitted.

**antMatchers vs requestMatchers**:
- Boot 3.x uses `requestMatchers()`. The old `antMatchers()` was removed.
- `requestMatchers("/api/**")` uses path pattern matching.

---

## Startup Failure Analysis

### ApplicationContextException: Unable to start

**Common causes**:

1. **Port already in use**:
   ```
   Web server failed to start. Port 8080 was already in use.
   ```
   Fix: Change `server.port` or kill the process on that port.

2. **Database connection failure**:
   ```
   Failed to configure a DataSource: 'url' attribute is not specified
   ```
   Fix: Set `spring.datasource.url` or exclude `DataSourceAutoConfiguration` if no DB needed.

3. **Missing required property**:
   ```
   Binding to target ... failed: Property 'app.required-field' is missing
   ```
   Fix: Set the property in `application.yml` or provide a default.

### Banner and Startup Logging

Customize startup banner:
```
# src/main/resources/banner.txt
${spring-boot.version} :: ${spring.application.name}
```

Startup performance analysis:
```yaml
spring:
  application:
    startup:
      track: true  # Enables ApplicationStartup tracking
```

```java
// Programmatic startup tracking
SpringApplication app = new SpringApplication(MyApp.class);
app.setApplicationStartup(new BufferingApplicationStartup(2048));
app.run(args);
```

Access via `/actuator/startup` (expose it first).

---

## Actuator Diagnostic Endpoints

| Endpoint | What It Shows | When to Use |
|---|---|---|
| `/actuator/health` | Component health status | App not responding, dependency failures |
| `/actuator/conditions` | Auto-configuration decisions | Missing beans, unexpected behavior |
| `/actuator/beans` | All registered beans | Bean not found, unexpected wiring |
| `/actuator/env` | All properties with sources | Wrong property value, override confusion |
| `/actuator/configprops` | @ConfigurationProperties values | Configuration binding issues |
| `/actuator/loggers` | Logger levels | Changing log level at runtime without restart |
| `/actuator/metrics/{name}` | Specific metric | Performance investigation |
| `/actuator/threaddump` | JVM thread dump | Thread pool exhaustion, deadlocks |
| `/actuator/heapdump` | JVM heap dump | Memory leak investigation |
| `/actuator/httptrace` | Recent HTTP requests | Request pattern analysis |

### Changing Log Level at Runtime

```bash
# View current level
curl http://localhost:9090/actuator/loggers/com.example.OrderService

# Change level (POST)
curl -X POST http://localhost:9090/actuator/loggers/com.example.OrderService \
  -H "Content-Type: application/json" \
  -d '{"configuredLevel": "DEBUG"}'
```

---

## Lazy Loading and Open Session in View

### LazyInitializationException

**Error**: `could not initialize proxy - no Session`

**Cause**: Accessing a lazy-loaded JPA association outside of a transaction/session boundary.

**Fixes**:

1. **Fetch eagerly in the query** (preferred):
   ```java
   @EntityGraph(attributePaths = {"items"})
   Optional<Order> findById(Long id);
   ```

2. **Keep the transaction open through the service call**:
   ```java
   @Transactional(readOnly = true)
   public OrderDto getOrderWithItems(Long id) {
       Order order = orderRepository.findById(id).orElseThrow();
       // items are accessible here within the transaction
       return OrderDto.from(order);
   }
   ```

3. **Open Session in View** (disabled by default in Boot 3.x):
   ```yaml
   spring.jpa.open-in-view: true  # NOT recommended for APIs
   ```
   This keeps the Hibernate session open for the entire HTTP request. Not recommended -- it masks N+1 issues and couples the view layer to JPA.

---

## Transaction Debugging

### Missing @Transactional

**Symptom**: Data not being saved, or `TransactionRequiredException`.

Spring Data JPA repository methods (`save`, `delete`) are transactional by default. Custom service methods are NOT -- you must annotate them:

```java
@Service
@Transactional // applies to all public methods
public class OrderService {

    @Transactional(readOnly = true) // override for read-only
    public List<Order> findAll() { ... }

    // This method IS transactional (class-level annotation)
    public Order createOrder(CreateOrderRequest request) { ... }
}
```

### Self-Invocation Pitfall

```java
@Service
public class OrderService {
    @Transactional
    public void processOrder(Long id) {
        // This calls validate() directly -- bypasses the proxy
        // validate() will NOT run in its own transaction
        validate(id);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void validate(Long id) { ... }
}
```

Fix: Inject `self` or extract into a separate bean.

### Enabling Transaction Logging

```yaml
logging:
  level:
    org.springframework.transaction: TRACE
    org.springframework.orm.jpa: DEBUG
```
