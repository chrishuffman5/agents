# Spring Boot Architecture Deep Reference

## IoC Container Internals

### BeanFactory vs ApplicationContext

`BeanFactory` is the foundational container providing basic bean instantiation and dependency wiring. `ApplicationContext` extends it with enterprise features: event publication (`ApplicationEventPublisher`), i18n (`MessageSource`), resource loading (`ResourceLoader`), AOP integration, and automatic `BeanPostProcessor` registration.

In practice, you always work with `ApplicationContext`. Spring Boot creates:
- `AnnotationConfigServletWebServerApplicationContext` for MVC
- `AnnotationConfigReactiveWebServerApplicationContext` for WebFlux

### Bean Definition Sources

**Annotation-based** (dominant approach):

```java
@Configuration
public class AppConfig {
    @Bean
    public MyService myService(MyRepository repo) {
        return new MyServiceImpl(repo);
    }

    @Bean
    @Primary
    public DataSource primaryDataSource() { ... }
}
```

**Key distinction**: `@Configuration` classes use CGLIB proxies so inter-`@Bean` method calls return the same singleton. `@Component` classes do not -- a method call is a plain Java call.

```java
@Configuration
public class Config {
    @Bean
    public A beanA() { return new A(beanB()); } // beanB() returns the singleton

    @Bean
    public B beanB() { return new B(); }
}
```

### Component Scanning

`@SpringBootApplication` includes `@ComponentScan` defaulting to the package of the annotated class and all sub-packages.

```java
@ComponentScan(
    basePackages = "com.example",
    includeFilters = @ComponentScan.Filter(type = FilterType.ANNOTATION, classes = MyMarker.class),
    excludeFilters = @ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, classes = LegacyBean.class)
)
```

### Bean Lifecycle (Full Order)

```
1.  Bean class instantiated (constructor called)
2.  Dependencies injected (constructor/setter/field)
3.  BeanNameAware.setBeanName()
4.  BeanFactoryAware.setBeanFactory()
5.  ApplicationContextAware.setApplicationContext()
6.  BeanPostProcessor.postProcessBeforeInitialization()  <- AOP proxies created here
7.  @PostConstruct method
8.  InitializingBean.afterPropertiesSet()
9.  @Bean(initMethod = "...")
10. BeanPostProcessor.postProcessAfterInitialization()
11. Bean is ready for use
    ...
12. @PreDestroy method
13. DisposableBean.destroy()
14. @Bean(destroyMethod = "...")
```

```java
@Component
public class CacheService {
    @PostConstruct
    public void warmUp() {
        // Called after injection -- safe to use dependencies here
    }

    @PreDestroy
    public void flush() {
        // Called before container shutdown
    }
}
```

### Bean Scopes

| Scope | Description | Use Case |
|---|---|---|
| `singleton` | One per ApplicationContext (default) | Stateless services |
| `prototype` | New instance per `getBean()` call | Stateful objects |
| `request` | One per HTTP request | Per-request state |
| `session` | One per HTTP session | User session data |
| `application` | One per ServletContext | App-wide shared state |
| `websocket` | One per WebSocket session | WebSocket handlers |

**Prototype-in-singleton pitfall**:

```java
@Service
public class TaskService {
    private final ObjectProvider<TaskProcessor> processorProvider;

    public void process() {
        TaskProcessor processor = processorProvider.getObject(); // new instance each time
    }
}
```

### Dependency Injection Styles

```java
// Constructor injection -- PREFERRED (immutable, testable, fails fast)
@Service
public class PaymentService {
    private final PaymentGateway gateway;
    private final AuditLog audit;

    public PaymentService(PaymentGateway gateway, AuditLog audit) {
        this.gateway = gateway;
        this.audit = audit;
    }
}

// Setter injection -- optional dependencies
@Component
public class ReportService {
    private NotificationService notifier;

    @Autowired(required = false)
    public void setNotifier(NotificationService notifier) {
        this.notifier = notifier;
    }
}
```

Disambiguation when multiple beans match:

```java
@Autowired
@Qualifier("postgresDataSource")
private DataSource dataSource;
```

---

## Auto-Configuration Mechanics

### The Auto-Configuration Registry

**Boot 3.x**: Reads from `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` (one class per line). The old `spring.factories` approach was dropped entirely.

### Auto-Configuration Classes

Each auto-configuration class is a `@Configuration` decorated with conditional annotations:

```java
@AutoConfiguration(after = DataSourceAutoConfiguration.class)
@ConditionalOnClass(DataSource.class)
@ConditionalOnMissingBean(DataSource.class)
@EnableConfigurationProperties(DataSourceProperties.class)
public class DataSourceAutoConfiguration {
    @Bean
    @ConditionalOnProperty(name = "spring.datasource.url")
    public DataSource dataSource(DataSourceProperties props) {
        return DataSourceBuilder.create()
            .url(props.getUrl())
            .username(props.getUsername())
            .password(props.getPassword())
            .build();
    }
}
```

### Conditional Annotations (Complete)

| Annotation | Condition |
|---|---|
| `@ConditionalOnClass(Foo.class)` | Foo is on the classpath |
| `@ConditionalOnMissingClass("com.Foo")` | Foo is NOT on the classpath |
| `@ConditionalOnBean(Foo.class)` | A Foo bean is already registered |
| `@ConditionalOnMissingBean(Foo.class)` | No Foo bean registered yet |
| `@ConditionalOnProperty(name="x", havingValue="true")` | Property x=true |
| `@ConditionalOnProperty(name="x", matchIfMissing=true)` | x is missing or true |
| `@ConditionalOnWebApplication` | Running in a web context |
| `@ConditionalOnNotWebApplication` | Not a web context |
| `@ConditionalOnResource(resources="classpath:foo.xml")` | Resource exists |
| `@ConditionalOnExpression("${x} && ${y}")` | SpEL evaluates true |

### Auto-Configuration Ordering

```java
@AutoConfiguration(after = DataSourceAutoConfiguration.class)
@AutoConfigureBefore(WebMvcAutoConfiguration.class)
public class MyAutoConfiguration { ... }
```

### Debugging Auto-Configuration

Run with `--debug` or `spring.autoconfigure.report.enabled=true`. The conditions evaluation report shows why each auto-configuration was applied or skipped:

```
============================
CONDITIONS EVALUATION REPORT
============================

Positive matches:
   DataSourceAutoConfiguration matched:
      - @ConditionalOnClass found required classes 'javax.sql.DataSource'

Negative matches:
   MongoAutoConfiguration:
      - @ConditionalOnClass did not find required class 'com.mongodb.MongoClient'
```

Runtime access: `/actuator/conditions` endpoint.

### Excluding Auto-Configuration

```java
@SpringBootApplication(exclude = {DataSourceAutoConfiguration.class})
public class MyApp { ... }
```

Or in properties:
```properties
spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration
```

---

## DispatcherServlet Request Lifecycle

### The Front Controller

Every HTTP request passes through `DispatcherServlet`, which delegates to specialized components:

| Component | Interface | Role |
|---|---|---|
| Handler mapping | `HandlerMapping` | Maps URL to handler (controller method) |
| Handler adapter | `HandlerAdapter` | Invokes the handler |
| Exception resolver | `HandlerExceptionResolver` | Translates exceptions to responses |
| View resolver | `ViewResolver` | Resolves logical view names |
| Message converters | `HttpMessageConverter` | Serialize/deserialize bodies |

### Complete Request Processing Flow

```
HTTP Request
    |
    v
Servlet Container (Tomcat)
    |
    v
Filter Chain (Security, encoding, CORS)
    |
    v
DispatcherServlet.service()
    |
    +-> HandlerMapping -- find handler
    |       RequestMappingHandlerMapping (annotation-based)
    |       RouterFunctionMapping (functional endpoints)
    |
    +-> HandlerAdapter -- resolve & call handler
    |       Runs HandlerInterceptor.preHandle()
    |       Argument resolution (@PathVariable, @RequestBody, etc.)
    |       Invokes controller method
    |       Runs HandlerInterceptor.postHandle()
    |
    +-> (Exception) HandlerExceptionResolver chain
    |       ExceptionHandlerExceptionResolver (@ExceptionHandler)
    |       ResponseStatusExceptionResolver (@ResponseStatus)
    |       DefaultHandlerExceptionResolver (Spring MVC standard)
    |
    +-> MessageConverter -- serialize return value
    |       MappingJackson2HttpMessageConverter (JSON)
    |       StringHttpMessageConverter
    |
    +-> HandlerInterceptor.afterCompletion()
    |
HTTP Response
```

### Handler Method Arguments

| Argument | Source |
|---|---|
| `@PathVariable` | URL template `{id}` |
| `@RequestParam` | Query string / form data |
| `@RequestHeader` | HTTP headers |
| `@RequestBody` | Body via MessageConverter (`@Valid` triggers Bean Validation) |
| `@ModelAttribute` | Form data / model (MVC views) |
| `HttpServletRequest` | Raw servlet request |
| `Principal` / `@AuthenticationPrincipal` | Security context |
| `Pageable` | Query params resolved by Spring Data Web |

### Controller Example

```java
@RestController
@RequestMapping("/api/orders")
public class OrderController {
    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @GetMapping("/{id}")
    public ResponseEntity<Order> getOrder(@PathVariable Long id) {
        return orderService.findById(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Order createOrder(@RequestBody @Valid CreateOrderRequest request) {
        return orderService.create(request);
    }
}
```

### ProblemDetail (RFC 9457) Exception Handling

```java
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(BusinessRuleException.class)
    public ResponseEntity<ProblemDetail> handleBusinessRule(BusinessRuleException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_ENTITY, ex.getMessage());
        problem.setTitle("Business Rule Violation");
        problem.setProperty("code", ex.getCode());
        return ResponseEntity.unprocessableEntity().body(problem);
    }
}
```

Enable application-wide: `spring.mvc.problemdetails.enabled=true`

### HandlerInterceptors

```java
@Component
public class RequestLoggingInterceptor implements HandlerInterceptor {
    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
        return true; // false aborts request
    }

    @Override
    public void afterCompletion(HttpServletRequest req, HttpServletResponse res,
                                Object handler, Exception ex) {
        // Always called -- cleanup, logging
    }
}

@Configuration
public class WebConfig implements WebMvcConfigurer {
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new RequestLoggingInterceptor())
                .addPathPatterns("/api/**")
                .excludePathPatterns("/api/health");
    }
}
```

---

## WebFlux Reactive Stack

### MVC vs WebFlux Comparison

| Aspect | Spring MVC | Spring WebFlux |
|---|---|---|
| **Model** | Imperative, blocking | Reactive, non-blocking |
| **Server** | Tomcat, Jetty (Servlet) | Netty (default), Tomcat, Jetty (Servlet 3.1 async) |
| **Thread model** | Thread-per-request | Event loop (few threads, many connections) |
| **Backpressure** | No | Yes (Reactive Streams) |
| **Debugging** | Simple stack traces | Complex async traces |
| **Blocking** | Native | Only on `Schedulers.boundedElastic()` |

### Reactor: Mono and Flux

```java
// Mono -- 0 or 1 item
Mono<Order> orderMono = Mono.just(new Order(1L, "PENDING"));

// Flux -- 0 to N items
Flux<Order> orderFlux = Flux.fromIterable(orderList);

// Operators
Mono<OrderDto> mapped = orderMono
    .map(order -> new OrderDto(order))
    .flatMap(dto -> enrichAsync(dto))
    .filter(dto -> dto.isActive())
    .switchIfEmpty(Mono.error(new NotFoundException("Not found")))
    .subscribeOn(Schedulers.boundedElastic()); // offload blocking

// Combining
Mono<Tuple2<User, Order>> combined = Mono.zip(userMono, orderMono);
Flux<Order> merged = Flux.merge(flux1, flux2);
```

**Schedulers**:

| Scheduler | Use Case |
|---|---|
| `Schedulers.parallel()` | CPU-bound work |
| `Schedulers.boundedElastic()` | Blocking I/O (JDBC, blocking APIs) |
| `Schedulers.single()` | Single-threaded sequential work |

### Annotated WebFlux Controllers

```java
@RestController
@RequestMapping("/api/orders")
public class OrderController {
    @GetMapping("/{id}")
    public Mono<ResponseEntity<Order>> getOrder(@PathVariable Long id) {
        return orderService.findById(id)
            .map(ResponseEntity::ok)
            .defaultIfEmpty(ResponseEntity.notFound().build());
    }

    @GetMapping(produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<Order> streamOrders() {
        return orderService.streamAll();
    }
}
```

### Functional Endpoints (RouterFunction)

```java
@Configuration
public class OrderRouter {
    @Bean
    public RouterFunction<ServerResponse> orderRoutes(OrderHandler handler) {
        return RouterFunctions.route()
            .GET("/api/orders/{id}", handler::getOrder)
            .POST("/api/orders", handler::createOrder)
            .build();
    }
}

@Component
public class OrderHandler {
    public Mono<ServerResponse> getOrder(ServerRequest request) {
        Long id = Long.parseLong(request.pathVariable("id"));
        return orderService.findById(id)
            .flatMap(order -> ServerResponse.ok().bodyValue(order))
            .switchIfEmpty(ServerResponse.notFound().build());
    }
}
```

### WebFlux DispatcherHandler

Mirrors DispatcherServlet for reactive:

| MVC | WebFlux |
|---|---|
| `DispatcherServlet` | `DispatcherHandler` |
| `HandlerMapping` | `HandlerMapping` |
| `HandlerAdapter` | `HandlerAdapter` |
| `ViewResolver` | `HandlerResultHandler` |

---

## Spring Security Filter Chain

### Architecture

```
HTTP Request
    |
    v
Servlet Container Filter Chain
    |
    +-- DelegatingFilterProxy        <- bridges Servlet and Spring
    |       |
    |       +-- FilterChainProxy     <- core Spring Security filter
    |               |
    |               +-- SecurityFilterChain 1 (e.g. /api/**)
    |               |       +-- SecurityContextHolderFilter
    |               |       +-- CsrfFilter
    |               |       +-- BearerTokenAuthenticationFilter (JWT)
    |               |       +-- BasicAuthenticationFilter
    |               |       +-- AnonymousAuthenticationFilter
    |               |       +-- ExceptionTranslationFilter
    |               |       +-- AuthorizationFilter
    |               |
    |               +-- SecurityFilterChain 2 (e.g. /admin/**)
    |                       +-- ... stricter rules
    |
    v
DispatcherServlet
```

### SecurityFilterChain Configuration

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain apiFilterChain(HttpSecurity http) throws Exception {
        http
            .securityMatcher("/api/**")
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated())
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtConverter())));
        return http.build();
    }
}
```

### OAuth2 Resource Server with JWT

```properties
spring.security.oauth2.resourceserver.jwt.issuer-uri=https://auth.example.com
spring.security.oauth2.resourceserver.jwt.jwk-set-uri=https://auth.example.com/.well-known/jwks.json
```

JWT validation flow:
1. `BearerTokenAuthenticationFilter` extracts `Authorization: Bearer <token>`
2. `NimbusJwtDecoder` validates signature via JWK set
3. Claims verified: `exp`, `iss`, `aud`
4. `JwtAuthenticationConverter` maps claims to `GrantedAuthority`
5. `JwtAuthenticationToken` stored in `SecurityContextHolder`

### Method-Level Security

```java
@Service
public class OrderService {
    @PreAuthorize("hasRole('ADMIN') or #userId == authentication.principal.id")
    public Order getOrder(Long orderId, Long userId) { ... }

    @PostAuthorize("returnObject.customerId == authentication.principal.id")
    public Order createOrder(CreateOrderRequest request) { ... }
}
```

### CORS Configuration

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("https://app.example.com"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
    config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
    config.setAllowCredentials(true);

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}
```

**Important**: Configure CORS via `HttpSecurity.cors()` to ensure the CORS filter executes before authentication filters.

---

## Spring Data JPA

### Repository Hierarchy

```
Repository<T, ID>                    <- marker interface
    +-- CrudRepository<T, ID>        <- save, findById, findAll, delete, count
        +-- PagingAndSortingRepository<T, ID>  <- findAll(Pageable), findAll(Sort)
            +-- JpaRepository<T, ID>           <- flush, saveAndFlush, deleteInBatch
```

### Query Derivation

Spring Data parses method names and generates JPQL:

```java
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    List<User> findByLastnameAndFirstname(String lastname, String firstname);
    List<User> findByAgeBetween(int min, int max);
    List<User> findByActiveTrueOrderByLastnameAsc();
    long countByDepartment(Department dept);
}
```

Keywords: `And`, `Or`, `Is`, `Between`, `LessThan`, `GreaterThan`, `Like`, `Containing`, `In`, `NotIn`, `True`, `False`, `OrderBy`, `IgnoreCase`.

### Projections

```java
// Interface projection
public interface OrderSummary {
    Long getId();
    String getStatus();
    BigDecimal getTotalAmount();
}

// Record (DTO) projection
public record OrderSummaryDto(Long id, String status, BigDecimal totalAmount) {}

public interface OrderRepository extends JpaRepository<Order, Long> {
    List<OrderSummary> findByStatus(String status);
    List<OrderSummaryDto> findByCustomerId(Long customerId);
}
```

### Specifications (JPA Criteria API)

```java
public interface OrderRepository extends JpaRepository<Order, Long>,
        JpaSpecificationExecutor<Order> {}

public class OrderSpecs {
    public static Specification<Order> hasStatus(OrderStatus status) {
        return (root, query, cb) -> cb.equal(root.get("status"), status);
    }

    public static Specification<Order> createdAfter(Instant date) {
        return (root, query, cb) -> cb.greaterThan(root.get("createdAt"), date);
    }
}

// Compose
List<Order> results = orderRepository.findAll(
    OrderSpecs.hasStatus(PENDING).and(OrderSpecs.createdAfter(yesterday))
);
```

### Auditing

```java
@Entity
@EntityListeners(AuditingEntityListener.class)
public class Order {
    @CreatedDate  private Instant createdAt;
    @LastModifiedDate  private Instant updatedAt;
    @CreatedBy  private String createdBy;
    @LastModifiedBy  private String updatedBy;
}

@Configuration
@EnableJpaAuditing
public class JpaConfig {
    @Bean
    public AuditorAware<String> auditorProvider() {
        return () -> Optional.ofNullable(SecurityContextHolder.getContext())
            .map(SecurityContext::getAuthentication)
            .filter(Authentication::isAuthenticated)
            .map(Authentication::getName);
    }
}
```

---

## Embedded Servers

### Thread Model Comparison

**Tomcat (MVC)**:
- 1 thread per request while active
- Default pool: 200 threads -> 200 concurrent requests max
- Thread blocked during DB/network I/O
- Simple to reason about, easy to debug

**Netty (WebFlux)**:
- Event loop with `2 * CPU cores` threads
- Thread never blocks -- I/O completion is reactive signal
- Handles thousands of concurrent connections
- Requires non-blocking throughout

### Tomcat Tuning

```yaml
server:
  tomcat:
    threads:
      max: 200
      min-spare: 10
    max-connections: 8192
    accept-count: 100
    connection-timeout: 20000
  compression:
    enabled: true
    min-response-size: 1024
  http2:
    enabled: true
```

### SSL/TLS

```yaml
server:
  ssl:
    key-store: classpath:keystore.p12
    key-store-password: ${KEYSTORE_PASSWORD}
    key-store-type: PKCS12
  port: 8443
```

### Graceful Shutdown

```yaml
server:
  shutdown: graceful
spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
```
