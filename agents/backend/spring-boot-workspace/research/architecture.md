# Spring Boot Core Architecture

> Cross-version fundamentals covering Spring Boot 2.x and 3.x. Where behavior diverges between versions, both are noted.

---

## Table of Contents

1. [Spring IoC Container](#1-spring-ioc-container)
2. [Auto-Configuration](#2-auto-configuration)
3. [Spring MVC](#3-spring-mvc)
4. [Spring WebFlux](#4-spring-webflux)
5. [Spring Data JPA](#5-spring-data-jpa)
6. [Spring Security](#6-spring-security)
7. [Actuator](#7-actuator)
8. [Configuration](#8-configuration)
9. [Testing](#9-testing)
10. [Embedded Servers](#10-embedded-servers)

---

## 1. Spring IoC Container

### BeanFactory vs ApplicationContext

`BeanFactory` is the foundational container — it provides basic bean instantiation and dependency wiring. `ApplicationContext` extends `BeanFactory` with enterprise features:

- **Event publication** (`ApplicationEventPublisher`)
- **Message source** for i18n (`MessageSource`)
- **Resource loading** (`ResourceLoader`)
- **AOP integration** and load-time weaving
- **Automatic BeanPostProcessor registration**

In practice, you always work with `ApplicationContext`. Spring Boot creates a `AnnotationConfigServletWebServerApplicationContext` (MVC) or `AnnotationConfigReactiveWebServerApplicationContext` (WebFlux) at startup. BeanFactory is the internal implementation detail.

```java
// Rarely done manually — Spring Boot bootstraps the context
ApplicationContext ctx = SpringApplication.run(MyApp.class, args);
MyService svc = ctx.getBean(MyService.class);
```

### Bean Definition Sources

**XML (legacy)** — rarely used in new projects.

**Annotation-based** — the dominant approach:

```java
@Configuration          // Marks class as a source of @Bean definitions
public class AppConfig {

    @Bean               // Registers return value as a Spring bean
    public MyService myService(MyRepository repo) {
        return new MyServiceImpl(repo);
    }

    @Bean
    @Primary            // Preferred candidate when multiple beans of same type exist
    public DataSource primaryDataSource() { ... }
}
```

**Key distinction**: `@Configuration` classes use CGLIB proxies so that inter-`@Bean` method calls return the same singleton instance. `@Component` classes do not — a method call is a plain Java call.

```java
@Configuration
public class Config {
    @Bean
    public A beanA() { return new A(beanB()); } // beanB() returns the singleton

    @Bean
    public B beanB() { return new B(); }
}
```

### Stereotype Annotations

These are specializations of `@Component` that trigger component scanning and carry semantic meaning:

| Annotation | Layer | Extra Behavior |
|---|---|---|
| `@Component` | Generic | None beyond registration |
| `@Service` | Business logic | No extra behavior — semantic marker |
| `@Repository` | Data access | Enables exception translation (wraps JPA/SQL exceptions into Spring `DataAccessException`) |
| `@Controller` | Web/MVC | Marks handlers for `DispatcherServlet` |
| `@RestController` | Web/REST | `@Controller` + `@ResponseBody` |

```java
@Service
public class OrderService {
    private final OrderRepository repo;

    // Constructor injection preferred — immutable, testable
    public OrderService(OrderRepository repo) {
        this.repo = repo;
    }
}

@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {}
```

### Component Scanning

`@ComponentScan` tells the container which packages to search for annotated classes. `@SpringBootApplication` includes `@ComponentScan` defaulting to the package of the annotated class and all sub-packages.

```java
@SpringBootApplication
// Equivalent to:
// @Configuration
// @EnableAutoConfiguration
// @ComponentScan(basePackages = "com.example")
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class, args);
    }
}
```

Scanning filter customization:

```java
@ComponentScan(
    basePackages = "com.example",
    includeFilters = @ComponentScan.Filter(type = FilterType.ANNOTATION, classes = MyMarker.class),
    excludeFilters = @ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, classes = LegacyBean.class)
)
```

**Debug tip**: Add `--debug` flag or `logging.level.org.springframework=DEBUG` to see which beans are registered and why auto-configuration fired or was skipped.

### Bean Lifecycle

The full lifecycle in order:

```
1.  Bean class instantiated (constructor called)
2.  Dependencies injected (constructor/setter/field)
3.  BeanNameAware.setBeanName()
4.  BeanFactoryAware.setBeanFactory()
5.  ApplicationContextAware.setApplicationContext()
6.  BeanPostProcessor.postProcessBeforeInitialization()  ← AOP proxies created here
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
        // Called after injection — safe to use dependencies here
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
| `singleton` | One instance per ApplicationContext (default) | Stateless services |
| `prototype` | New instance per `getBean()` call | Stateful objects, command objects |
| `request` | One per HTTP request | Web: per-request state |
| `session` | One per HTTP session | Web: user session data |
| `application` | One per `ServletContext` | Web: app-wide shared state |
| `websocket` | One per WebSocket session | WebSocket handlers |

```java
@Component
@Scope("prototype")
public class TaskProcessor { ... }

// Inject prototype into singleton — use ObjectProvider to get fresh instances
@Service
public class TaskService {
    private final ObjectProvider<TaskProcessor> processorProvider;

    public void process() {
        TaskProcessor processor = processorProvider.getObject(); // new instance each time
    }
}
```

**Pitfall**: Injecting a `prototype`-scoped bean directly into a `singleton` defeats the prototype scope — you get the same instance. Use `ObjectProvider<T>`, `@Lookup`, or a scoped proxy (`@Scope(proxyMode = ScopedProxyMode.TARGET_CLASS)`).

### Dependency Injection Styles

```java
// Constructor injection — PREFERRED
@Service
public class PaymentService {
    private final PaymentGateway gateway;
    private final AuditLog audit;

    public PaymentService(PaymentGateway gateway, AuditLog audit) {
        this.gateway = gateway;
        this.audit = audit;
    }
}

// Setter injection — optional dependencies
@Component
public class ReportService {
    private NotificationService notifier;

    @Autowired(required = false)
    public void setNotifier(NotificationService notifier) {
        this.notifier = notifier;
    }
}

// Field injection — avoid in production code (hinders testing)
@Autowired
private UserRepository userRepository;
```

Disambiguation when multiple beans match:

```java
@Autowired
@Qualifier("postgresDataSource")
private DataSource dataSource;

// Or via primary
@Bean
@Primary
public DataSource defaultDataSource() { ... }
```

---

## 2. Auto-Configuration

### How @SpringBootApplication Works

`@SpringBootApplication` is a composed annotation equivalent to:

```java
@Configuration
@EnableAutoConfiguration
@ComponentScan
```

`@EnableAutoConfiguration` imports `AutoConfigurationImportSelector`, which reads the list of auto-configuration classes to apply.

### The Auto-Configuration Registry

**Spring Boot 2.6 and earlier** — reads from `META-INF/spring.factories`:

```properties
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
  com.example.MyAutoConfiguration,\
  com.example.AnotherAutoConfiguration
```

**Spring Boot 2.7+ / 3.x** — reads from `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` (one class per line):

```
com.example.MyAutoConfiguration
com.example.AnotherAutoConfiguration
```

Spring Boot 3.x dropped `spring.factories` support for auto-configuration entirely. Third-party libraries targeting both must ship both files during a transition period.

### Auto-Configuration Classes

Each auto-configuration class is a `@Configuration` class decorated with conditional annotations:

```java
@AutoConfiguration                          // Marks as auto-config (Boot 3.x)
@ConditionalOnClass(DataSource.class)       // Only if DataSource on classpath
@ConditionalOnMissingBean(DataSource.class) // Only if no user-defined DataSource bean
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

### Conditional Annotations

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

Run with `--debug` or add `spring.autoconfigure.report.enabled=true`. Spring Boot prints a conditions evaluation report:

```
============================
CONDITIONS EVALUATION REPORT
============================

Positive matches:
-----------------
   DataSourceAutoConfiguration matched:
      - @ConditionalOnClass found required classes 'javax.sql.DataSource'

Negative matches:
-----------------
   MongoAutoConfiguration:
      - @ConditionalOnClass did not find required class 'com.mongodb.MongoClient'
```

The `/actuator/conditions` endpoint gives this at runtime.

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

## 3. Spring MVC

### DispatcherServlet — The Front Controller

Every HTTP request to a Spring MVC application passes through a single `DispatcherServlet`. It implements the **Front Controller** pattern, delegating to specialized components:

| Component | Interface | Role |
|---|---|---|
| Handler mapping | `HandlerMapping` | Maps request URL to a handler (controller method) |
| Handler adapter | `HandlerAdapter` | Invokes the handler (abstracts invocation strategy) |
| Exception resolver | `HandlerExceptionResolver` | Translates exceptions to responses |
| View resolver | `ViewResolver` | Resolves logical view names to `View` objects |
| Message converters | `HttpMessageConverter` | Serialize/deserialize request/response bodies |

### Request Processing Lifecycle (Detailed)

```
HTTP Request
    │
    ▼
Servlet Container (Tomcat)
    │
    ▼
Filter Chain (Spring Security filters, encoding filters, etc.)
    │
    ▼
DispatcherServlet.service()
    │
    ├─► HandlerMapping — find handler
    │       RequestMappingHandlerMapping (annotation-based)
    │       RouterFunctionMapping (functional)
    │       SimpleUrlHandlerMapping (resource handlers)
    │
    ├─► HandlerAdapter — resolve & call handler
    │       RequestMappingHandlerAdapter (for @RequestMapping methods)
    │       Runs HandlerInterceptor.preHandle()
    │       Performs argument resolution (@PathVariable, @RequestBody, etc.)
    │       Invokes controller method
    │       Runs HandlerInterceptor.postHandle()
    │
    ├─► (Exception) HandlerExceptionResolver chain
    │       ExceptionHandlerExceptionResolver (@ExceptionHandler)
    │       ResponseStatusExceptionResolver (@ResponseStatus)
    │       DefaultHandlerExceptionResolver (standard Spring MVC exceptions)
    │
    ├─► MessageConverter — serialize return value
    │       MappingJackson2HttpMessageConverter (JSON)
    │       StringHttpMessageConverter
    │       ByteArrayHttpMessageConverter
    │
    ├─► (View rendering if not REST)
    │       ViewResolver resolves view name to View
    │       View.render() writes response
    │
    └─► HandlerInterceptor.afterCompletion()

HTTP Response
```

### Controllers

```java
@RestController                         // @Controller + @ResponseBody
@RequestMapping("/api/orders")          // Base path for all methods
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

    @GetMapping
    public Page<OrderDto> listOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String status) {
        return orderService.findAll(PageRequest.of(page, size), status);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Order createOrder(@RequestBody @Valid CreateOrderRequest request) {
        return orderService.create(request);
    }

    @PutMapping("/{id}")
    public Order updateOrder(@PathVariable Long id, @RequestBody @Valid UpdateOrderRequest request) {
        return orderService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteOrder(@PathVariable Long id) {
        orderService.delete(id);
    }
}
```

### Handler Method Arguments (Resolved by HandlerAdapter)

| Argument | Source | Notes |
|---|---|---|
| `@PathVariable` | URL template `{id}` | Type conversion applied |
| `@RequestParam` | Query string / form data | Optional, defaultValue supported |
| `@RequestHeader` | HTTP headers | |
| `@RequestBody` | Request body via MessageConverter | `@Valid` triggers Bean Validation |
| `@ModelAttribute` | Form data / model | Used in MVC (Thymeleaf etc.) |
| `HttpServletRequest` | Raw servlet request | |
| `Principal` | Security context | Authenticated user |
| `@AuthenticationPrincipal` | Spring Security principal | |
| `Pageable` | Query params (page, size, sort) | Auto-resolved by Spring Data Web |

### Return Values

| Return Type | Behavior |
|---|---|
| `String` | Logical view name (MVC apps) |
| `@ResponseBody Object` | Serialized by MessageConverter |
| `ResponseEntity<T>` | Full control over status, headers, body |
| `Mono<T>` / `Flux<T>` | Reactive — works in MVC with reactive support |
| `void` | Response written directly via `HttpServletResponse` |

### Exception Handling

**Controller-local handler:**

```java
@Controller
public class OrderController {
    @ExceptionHandler(OrderNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ResponseEntity<ProblemDetail> handleNotFound(OrderNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setTitle("Order Not Found");
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(problem);
    }
}
```

**Global handler with @ControllerAdvice:**

```java
@RestControllerAdvice                   // @ControllerAdvice + @ResponseBody
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {
    // ResponseEntityExceptionHandler handles standard Spring MVC exceptions
    // (MethodArgumentNotValidException, HttpMessageNotReadableException, etc.)

    @ExceptionHandler(BusinessRuleException.class)
    public ResponseEntity<ProblemDetail> handleBusinessRule(BusinessRuleException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_ENTITY, ex.getMessage());
        problem.setTitle("Business Rule Violation");
        problem.setProperty("code", ex.getCode());  // Custom extension field
        return ResponseEntity.unprocessableEntity().body(problem);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ProblemDetail> handleValidation(ConstraintViolationException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        problem.setTitle("Validation Failed");
        problem.setProperty("violations",
            ex.getConstraintViolations().stream()
                .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                .toList());
        return ResponseEntity.badRequest().body(problem);
    }
}
```

**ProblemDetail** (RFC 9457, available from Spring 6 / Boot 3):

```json
{
  "type": "https://api.example.com/errors/order-not-found",
  "title": "Order Not Found",
  "status": 404,
  "detail": "Order with id 42 does not exist",
  "instance": "/api/orders/42"
}
```

Enabled application-wide:
```properties
spring.mvc.problemdetails.enabled=true
```

### HandlerInterceptors

```java
@Component
public class RequestLoggingInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
        // Return false to abort request processing
        return true;
    }

    @Override
    public void postHandle(HttpServletRequest req, HttpServletResponse res,
                           Object handler, ModelAndView mav) {
        // After handler, before view rendering
    }

    @Override
    public void afterCompletion(HttpServletRequest req, HttpServletResponse res,
                                Object handler, Exception ex) {
        // Always called — cleanup, logging
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

### Content Negotiation

Spring MVC selects `HttpMessageConverter` based on `Accept` and `Content-Type` headers. Default converters (auto-configured):

- `MappingJackson2HttpMessageConverter` — `application/json`
- `StringHttpMessageConverter` — `text/plain`
- `ByteArrayHttpMessageConverter` — `application/octet-stream`
- `ResourceHttpMessageConverter` — static resources

---

## 4. Spring WebFlux

### Reactive Stack Overview

WebFlux is the non-blocking, reactive alternative to Spring MVC. The two stacks are:

| | Spring MVC | Spring WebFlux |
|---|---|---|
| **Model** | Imperative, blocking | Reactive, non-blocking |
| **Server** | Tomcat, Jetty, Undertow (Servlet) | Netty (default), Tomcat, Jetty, Undertow (via Servlet 3.1 async) |
| **Thread model** | Thread-per-request (pool) | Event loop (few threads, many connections) |
| **Backpressure** | No | Yes (Reactive Streams) |
| **Latency** | Good for CPU-bound | Excellent for I/O-bound, high concurrency |
| **Complexity** | Lower | Higher (debugging async code) |
| **Blocking allowed** | Yes (native) | Only on bounded scheduler (`Schedulers.boundedElastic()`) |

### Reactor: Mono and Flux

The reactive types from Project Reactor underpin WebFlux:

```java
// Mono — 0 or 1 item
Mono<Order> orderMono = Mono.just(new Order(1L, "PENDING"));
Mono<Void> empty = Mono.empty();
Mono<Order> fromCallable = Mono.fromCallable(() -> repo.findById(1L)); // wrap blocking call

// Flux — 0 to N items
Flux<Order> orderFlux = Flux.just(order1, order2, order3);
Flux<Order> fromIterable = Flux.fromIterable(orderList);
Flux<Long> interval = Flux.interval(Duration.ofSeconds(1)); // infinite stream

// Operators
Mono<OrderDto> mapped = orderMono
    .map(order -> new OrderDto(order))              // synchronous transform
    .flatMap(dto -> enrichAsync(dto))               // async transform (returns Mono)
    .filter(dto -> dto.isActive())
    .switchIfEmpty(Mono.error(new NotFoundException("Order not found")))
    .onErrorReturn(new OrderDto())                  // error recovery
    .doOnNext(dto -> log.info("Processing: {}", dto))  // side effect
    .subscribeOn(Schedulers.boundedElastic());      // offload blocking work

Flux<OrderDto> paged = orderFlux
    .skip(20)
    .take(20)
    .flatMap(order -> enrichAsync(order), 10);      // concurrency = 10

// Combining
Mono<Tuple2<User, Order>> combined = Mono.zip(userMono, orderMono);
Flux<Order> merged = Flux.merge(flux1, flux2);      // interleaved
Flux<Order> concat = Flux.concat(flux1, flux2);     // sequential
```

**Schedulers** (thread pools):

| Scheduler | Use Case |
|---|---|
| `Schedulers.parallel()` | CPU-bound work |
| `Schedulers.boundedElastic()` | Blocking I/O (JDBC, blocking APIs) |
| `Schedulers.single()` | Single-threaded sequential work |
| `Schedulers.immediate()` | Current thread |

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
        return orderService.streamAll();  // Server-Sent Events
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<Order> createOrder(@RequestBody @Valid Mono<CreateOrderRequest> request) {
        return request.flatMap(orderService::create);
    }
}
```

### Functional Endpoints

An alternative to annotations — explicit routing using `RouterFunction`:

```java
@Configuration
public class OrderRouter {

    @Bean
    public RouterFunction<ServerResponse> orderRoutes(OrderHandler handler) {
        return RouterFunctions.route()
            .GET("/api/orders/{id}", handler::getOrder)
            .GET("/api/orders", handler::listOrders)
            .POST("/api/orders", handler::createOrder)
            .DELETE("/api/orders/{id}", handler::deleteOrder)
            .build();
    }
}

@Component
public class OrderHandler {

    public Mono<ServerResponse> getOrder(ServerRequest request) {
        Long id = Long.parseLong(request.pathVariable("id"));
        return orderService.findById(id)
            .flatMap(order -> ServerResponse.ok()
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(order))
            .switchIfEmpty(ServerResponse.notFound().build());
    }

    public Mono<ServerResponse> createOrder(ServerRequest request) {
        return request.bodyToMono(CreateOrderRequest.class)
            .flatMap(orderService::create)
            .flatMap(order -> ServerResponse.created(
                URI.create("/api/orders/" + order.getId()))
                .bodyValue(order));
    }
}
```

### WebFlux DispatcherHandler

Mirrors `DispatcherServlet` for reactive:

| Component | MVC | WebFlux |
|---|---|---|
| Front controller | `DispatcherServlet` | `DispatcherHandler` |
| Handler mapping | `HandlerMapping` | `HandlerMapping` |
| Handler adapter | `HandlerAdapter` | `HandlerAdapter` |
| Result handling | `ViewResolver` | `HandlerResultHandler` |

### MVC vs WebFlux: When to Choose

**Use Spring MVC when:**
- Team is familiar with blocking/imperative style
- Using blocking libraries (standard JDBC, JPA, Hibernate)
- Straightforward CRUD APIs with moderate traffic
- Simpler debugging and stack traces are valued

**Use Spring WebFlux when:**
- Handling many concurrent connections (thousands+)
- Building streaming APIs (SSE, WebSocket)
- Calling multiple downstream services in parallel
- Using reactive databases (R2DBC, MongoDB reactive, Cassandra)
- Microservice gateways (Spring Cloud Gateway is built on WebFlux)

**Do not mix blocking calls into WebFlux event loops.** If you must call a blocking API:

```java
return Mono.fromCallable(() -> blockingRepository.findById(id))
    .subscribeOn(Schedulers.boundedElastic()); // offload to thread pool
```

---

## 5. Spring Data JPA

### Repository Hierarchy

```
Repository<T, ID>                    ← marker interface
    └── CrudRepository<T, ID>        ← save, findById, findAll, delete, count
        └── PagingAndSortingRepository<T, ID>  ← findAll(Pageable), findAll(Sort)
            └── JpaRepository<T, ID>           ← flush, saveAndFlush, deleteInBatch, getReference
```

```java
public interface OrderRepository extends JpaRepository<Order, Long> {
    // Spring Data generates implementation at startup
}
```

### Query Derivation from Method Names

Spring Data parses method names and generates JPQL:

```java
public interface UserRepository extends JpaRepository<User, Long> {

    // SELECT u FROM User u WHERE u.email = ?1
    Optional<User> findByEmail(String email);

    // SELECT u FROM User u WHERE u.lastname = ?1 AND u.firstname = ?2
    List<User> findByLastnameAndFirstname(String lastname, String firstname);

    // SELECT u FROM User u WHERE u.age BETWEEN ?1 AND ?2
    List<User> findByAgeBetween(int min, int max);

    // SELECT u FROM User u WHERE u.lastname LIKE %?1%
    List<User> findByLastnameContaining(String substring);

    // SELECT u FROM User u WHERE u.active = true ORDER BY u.lastname ASC
    List<User> findByActiveTrueOrderByLastnameAsc();

    // COUNT query
    long countByDepartment(Department dept);

    // DELETE query
    void deleteByStatus(String status);
}
```

Supported keywords: `And`, `Or`, `Is`, `Equals`, `Between`, `LessThan`, `GreaterThan`, `After`, `Before`, `IsNull`, `NotNull`, `Like`, `NotLike`, `StartingWith`, `EndingWith`, `Containing`, `Not`, `In`, `NotIn`, `True`, `False`, `IgnoreCase`, `OrderBy`.

### @Query — Explicit JPQL and Native SQL

```java
public interface OrderRepository extends JpaRepository<Order, Long> {

    // JPQL — entity/field names, not table/column names
    @Query("SELECT o FROM Order o WHERE o.status = :status AND o.createdAt > :since")
    List<Order> findByStatusSince(@Param("status") OrderStatus status,
                                   @Param("since") Instant since);

    // Native SQL
    @Query(value = "SELECT * FROM orders WHERE total_amount > :amount",
           nativeQuery = true)
    List<Order> findHighValueOrders(@Param("amount") BigDecimal amount);

    // With pagination (native requires explicit count query)
    @Query(value = "SELECT * FROM orders WHERE customer_id = :customerId",
           countQuery = "SELECT count(*) FROM orders WHERE customer_id = :customerId",
           nativeQuery = true)
    Page<Order> findByCustomerId(@Param("customerId") Long customerId, Pageable pageable);

    // Modifying query (UPDATE/DELETE)
    @Modifying
    @Query("UPDATE Order o SET o.status = :status WHERE o.id IN :ids")
    int bulkUpdateStatus(@Param("status") OrderStatus status, @Param("ids") List<Long> ids);
}
```

### Pagination and Slicing

```java
// Pageable encapsulates page number, size, and sort
Pageable pageable = PageRequest.of(0, 20, Sort.by("createdAt").descending());

// Page<T> — full count query, knows total pages/elements
Page<Order> page = orderRepository.findAll(pageable);
page.getContent();        // List<Order> for current page
page.getTotalElements();  // total record count
page.getTotalPages();     // total page count
page.getNumber();         // current page (0-based)
page.hasNext();

// Slice<T> — no count query, only knows if there's a next page
Slice<Order> slice = orderRepository.findByStatus(status, pageable);
slice.getContent();
slice.hasNext();          // fires SELECT with LIMIT+1 to peek ahead
```

**Spring Data Web support** (auto-configured by Spring Boot MVC):

```java
@GetMapping("/orders")
public Page<Order> list(Pageable pageable) {
    // ?page=0&size=20&sort=createdAt,desc resolved automatically
    return orderRepository.findAll(pageable);
}
```

### Specifications (JPA Criteria API)

```java
// Extend JpaSpecificationExecutor to use specs
public interface OrderRepository extends JpaRepository<Order, Long>,
        JpaSpecificationExecutor<Order> {}

// Build reusable specifications
public class OrderSpecs {

    public static Specification<Order> hasStatus(OrderStatus status) {
        return (root, query, cb) -> cb.equal(root.get("status"), status);
    }

    public static Specification<Order> createdAfter(Instant date) {
        return (root, query, cb) -> cb.greaterThan(root.get("createdAt"), date);
    }

    public static Specification<Order> forCustomer(Long customerId) {
        return (root, query, cb) -> cb.equal(root.get("customerId"), customerId);
    }
}

// Compose with and/or
List<Order> results = orderRepository.findAll(
    OrderSpecs.hasStatus(PENDING)
        .and(OrderSpecs.createdAfter(yesterday))
        .and(OrderSpecs.forCustomer(customerId))
);
```

### Projections

Avoid loading full entities when only a subset of fields is needed:

```java
// Interface projection
public interface OrderSummary {
    Long getId();
    String getStatus();
    BigDecimal getTotalAmount();

    // Computed projection using SpEL
    @Value("#{target.firstName + ' ' + target.lastName}")
    String getCustomerFullName();
}

// Class (DTO) projection
public record OrderSummaryDto(Long id, String status, BigDecimal totalAmount) {}

// Repository
public interface OrderRepository extends JpaRepository<Order, Long> {
    List<OrderSummary> findByStatus(String status);              // interface projection
    List<OrderSummaryDto> findByCustomerId(Long customerId);     // DTO projection
}
```

### Auditing

```java
@Entity
@EntityListeners(AuditingEntityListener.class)  // Required on each entity
public class Order {

    @CreatedDate
    private Instant createdAt;

    @LastModifiedDate
    private Instant updatedAt;

    @CreatedBy
    private String createdBy;

    @LastModifiedBy
    private String updatedBy;
}

// Enable auditing in configuration
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

## 6. Spring Security

### Filter Chain Architecture

Spring Security integrates as a Servlet `Filter`. The architecture:

```
HTTP Request
    │
    ▼
Servlet Container Filter Chain
    │
    ├── DelegatingFilterProxy          ← bridges Servlet and Spring lifecycles
    │       │
    │       └── FilterChainProxy       ← core Spring Security filter
    │               │
    │               ├── SecurityFilterChain 1 (e.g. /api/**)
    │               │       ├── SecurityContextHolderFilter
    │               │       ├── CsrfFilter
    │               │       ├── BearerTokenAuthenticationFilter (JWT)
    │               │       ├── BasicAuthenticationFilter
    │               │       ├── AnonymousAuthenticationFilter
    │               │       ├── ExceptionTranslationFilter
    │               │       └── AuthorizationFilter
    │               │
    │               └── SecurityFilterChain 2 (e.g. /admin/**)
    │                       └── ... stricter rules
    │
    ▼
DispatcherServlet
```

### SecurityFilterChain Configuration (Boot 3.x / Spring Security 6)

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity          // Enables @PreAuthorize, @PostAuthorize
public class SecurityConfig {

    @Bean
    public SecurityFilterChain apiFilterChain(HttpSecurity http) throws Exception {
        http
            .securityMatcher("/api/**")
            .csrf(csrf -> csrf.disable())              // Stateless API — no CSRF needed
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .requestMatchers(HttpMethod.GET, "/api/orders").hasAnyRole("USER", "ADMIN")
                .anyRequest().authenticated())
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtConverter())));

        return http.build();
    }

    @Bean
    public SecurityFilterChain actuatorChain(HttpSecurity http) throws Exception {
        http
            .securityMatcher("/actuator/**")
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                .anyRequest().hasRole("ACTUATOR"))
            .httpBasic(Customizer.withDefaults());

        return http.build();
    }
}
```

### Authentication

**UserDetailsService** — load user from a data store:

```java
@Service
public class UserDetailsServiceImpl implements UserDetailsService {

    private final UserRepository userRepository;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        return userRepository.findByUsername(username)
            .map(user -> User.builder()
                .username(user.getUsername())
                .password(user.getPasswordHash())  // must be encoded
                .roles(user.getRoles().toArray(String[]::new))
                .build())
            .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));
    }
}
```

**Custom AuthenticationProvider:**

```java
@Component
public class ApiKeyAuthenticationProvider implements AuthenticationProvider {

    @Override
    public Authentication authenticate(Authentication auth) throws AuthenticationException {
        String apiKey = (String) auth.getCredentials();
        if (!isValidApiKey(apiKey)) {
            throw new BadCredentialsException("Invalid API key");
        }
        return new ApiKeyAuthentication(apiKey, List.of(new SimpleGrantedAuthority("ROLE_API")));
    }

    @Override
    public boolean supports(Class<?> authentication) {
        return ApiKeyAuthentication.class.isAssignableFrom(authentication);
    }
}
```

### OAuth2 Resource Server with JWT

```properties
# application.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.example.com
          jwk-set-uri: https://auth.example.com/.well-known/jwks.json
```

JWT validation process:
1. `BearerTokenAuthenticationFilter` extracts `Authorization: Bearer <token>` header
2. `NimbusJwtDecoder` fetches JWK from `jwk-set-uri` and validates signature
3. Claims verified: `exp`, `iss`, `aud`
4. `JwtAuthenticationConverter` maps `scope`/`roles` claims to `GrantedAuthority`
5. `JwtAuthenticationToken` stored in `SecurityContextHolder`

```java
@Bean
public JwtAuthenticationConverter jwtAuthenticationConverter() {
    JwtGrantedAuthoritiesConverter grantedAuthoritiesConverter = new JwtGrantedAuthoritiesConverter();
    grantedAuthoritiesConverter.setAuthoritiesClaimName("roles");
    grantedAuthoritiesConverter.setAuthorityPrefix("ROLE_");

    JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
    converter.setJwtGrantedAuthoritiesConverter(grantedAuthoritiesConverter);
    return converter;
}
```

### Method-Level Security

```java
@Service
public class OrderService {

    @PreAuthorize("hasRole('ADMIN') or #userId == authentication.principal.id")
    public Order getOrder(Long orderId, Long userId) { ... }

    @PreAuthorize("hasRole('ADMIN')")
    public void deleteOrder(Long orderId) { ... }

    @PostAuthorize("returnObject.customerId == authentication.principal.id")
    public Order createOrder(CreateOrderRequest request) { ... }

    @PostFilter("filterObject.customerId == authentication.principal.id")
    public List<Order> listOrders() { ... }
}
```

### CORS Configuration

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("https://app.example.com"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
    config.setAllowCredentials(true);
    config.setMaxAge(3600L);

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}

// And reference it in SecurityFilterChain:
http.cors(cors -> cors.configurationSource(corsConfigurationSource()));
```

**Important**: Spring Security's CORS filter must execute before authentication filters. Configuring CORS via `HttpSecurity.cors()` ensures this ordering.

### Password Encoding

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12); // strength 4-31, default 10
}

// When saving a user:
user.setPasswordHash(passwordEncoder.encode(rawPassword));

// When authenticating — DaoAuthenticationProvider calls this automatically:
passwordEncoder.matches(rawPassword, storedHash);
```

---

## 7. Actuator

### Overview

Spring Boot Actuator exposes operational endpoints for monitoring and management. Add the dependency:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

### Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/actuator/health` | GET | Application health (UP/DOWN + components) |
| `/actuator/info` | GET | Build info, git info, custom metadata |
| `/actuator/metrics` | GET | List available metric names |
| `/actuator/metrics/{name}` | GET | Specific metric value |
| `/actuator/env` | GET | All environment properties |
| `/actuator/env/{property}` | GET | Single property value |
| `/actuator/loggers` | GET | All logger levels |
| `/actuator/loggers/{name}` | POST | Change logger level at runtime |
| `/actuator/beans` | GET | All Spring beans |
| `/actuator/conditions` | GET | Auto-configuration conditions report |
| `/actuator/configprops` | GET | All @ConfigurationProperties values |
| `/actuator/threaddump` | GET | JVM thread dump |
| `/actuator/heapdump` | GET | JVM heap dump |
| `/actuator/prometheus` | GET | Metrics in Prometheus format |
| `/actuator/httptrace` | GET | Recent HTTP requests |

### Exposure Configuration

By default, only `/health` and `/info` are exposed over HTTP. Never expose all endpoints in production without security:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, metrics, prometheus, loggers
        # include: "*"  # ALL — add security before doing this
  endpoint:
    health:
      show-details: when-authorized   # never | always | when-authorized
      show-components: always
  server:
    port: 9090    # Separate port for actuator (firewall it)
```

### Custom Health Indicators

```java
@Component
public class DatabaseHealthIndicator extends AbstractHealthIndicator {

    private final DataSource dataSource;

    @Override
    protected void doHealthCheck(Health.Builder builder) throws Exception {
        try (Connection conn = dataSource.getConnection()) {
            PreparedStatement stmt = conn.prepareStatement("SELECT 1");
            stmt.execute();
            builder.up()
                   .withDetail("database", conn.getMetaData().getDatabaseProductName())
                   .withDetail("validationQuery", "SELECT 1");
        } catch (Exception ex) {
            builder.down().withException(ex);
        }
    }
}

// Composite health for grouping
@Component
public class ReadinessHealthIndicator implements HealthIndicator {
    @Override
    public Health health() {
        // Check if app is ready to accept traffic
        return Health.up()
            .withDetail("cacheWarmed", cacheService.isWarmed())
            .build();
    }
}
```

Health groups (Spring Boot 2.3+):

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

### Micrometer Metrics

Spring Boot auto-configures a `MeterRegistry` via Micrometer. All Spring Boot metrics flow through it:

```java
@Service
public class OrderService {

    private final MeterRegistry registry;
    private final Counter orderCounter;
    private final Timer orderTimer;

    public OrderService(MeterRegistry registry) {
        this.registry = registry;
        this.orderCounter = Counter.builder("orders.created")
            .description("Total orders created")
            .tag("environment", "production")
            .register(registry);
        this.orderTimer = Timer.builder("orders.processing.time")
            .description("Order processing duration")
            .register(registry);
    }

    public Order createOrder(CreateOrderRequest request) {
        return orderTimer.record(() -> {
            Order order = processOrder(request);
            orderCounter.increment();
            registry.gauge("orders.active", activeOrderCount());
            return order;
        });
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

```yaml
management:
  endpoints:
    web:
      exposure:
        include: prometheus
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
      environment: ${spring.profiles.active}
```

Prometheus scrapes `/actuator/prometheus`. Grafana dashboards can import Spring Boot dashboard ID 4701 or 12900.

---

## 8. Configuration

### application.properties / application.yml

```yaml
# application.yml
spring:
  application:
    name: order-service
  datasource:
    url: jdbc:postgresql://localhost:5432/orders
    username: ${DB_USER}           # resolved from env var
    password: ${DB_PASSWORD}
    hikari:
      maximum-pool-size: 10
      connection-timeout: 30000
  jpa:
    hibernate:
      ddl-auto: validate           # never, validate, update, create, create-drop
    show-sql: false
    properties:
      hibernate:
        format_sql: true
        dialect: org.hibernate.dialect.PostgreSQLDialect
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.example.com

server:
  port: 8080
  servlet:
    context-path: /
  compression:
    enabled: true
    mime-types: application/json,application/xml,text/html

logging:
  level:
    root: WARN
    com.example: INFO
    org.springframework.security: DEBUG
```

### @ConfigurationProperties — Type-Safe Binding

```java
@ConfigurationProperties(prefix = "app.order")
@Validated                          // Enables JSR-303 validation on properties
public class OrderProperties {

    @NotNull
    private String currencyCode = "USD";

    @Min(1)
    @Max(1000)
    private int maxItemsPerOrder = 100;

    private Duration processingTimeout = Duration.ofMinutes(5);

    private Retry retry = new Retry();

    @Data
    public static class Retry {
        private int maxAttempts = 3;
        private Duration backoff = Duration.ofSeconds(2);
    }

    // getters/setters (or use @Data Lombok)
}

// Register the class:
@SpringBootApplication
@ConfigurationPropertiesScan        // Scans for @ConfigurationProperties
public class MyApp { ... }

// OR explicitly:
@EnableConfigurationProperties(OrderProperties.class)
```

```yaml
app:
  order:
    currency-code: EUR            # kebab-case bound to camelCase
    max-items-per-order: 50
    processing-timeout: 10m
    retry:
      max-attempts: 5
      backoff: 3s
```

### Profiles

```yaml
# application.yml — shared base config
spring:
  application:
    name: order-service

---
# application-dev.yml
spring:
  config:
    activate:
      on-profile: dev
  datasource:
    url: jdbc:h2:mem:orders
  jpa:
    hibernate:
      ddl-auto: create-drop

---
# application-prod.yml
spring:
  config:
    activate:
      on-profile: prod
  datasource:
    url: jdbc:postgresql://${DB_HOST}:5432/orders
```

Activate profiles:

```bash
# Environment variable
SPRING_PROFILES_ACTIVE=prod java -jar app.jar

# JVM arg
java -Dspring.profiles.active=prod -jar app.jar

# In tests
@ActiveProfiles("test")
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
@Profile("!prod")    // Active when NOT prod
public class LocalConfig { ... }
```

### Property Priority (High to Low)

1. Command-line arguments (`--server.port=9090`)
2. JNDI attributes (`java:comp/env`)
3. System properties (`-Dserver.port=9090`)
4. OS environment variables (`SERVER_PORT=9090`)
5. Profile-specific files outside JAR (`application-prod.yml`)
6. Profile-specific files inside JAR
7. `application.yml` / `application.properties` outside JAR
8. `application.yml` / `application.properties` inside JAR
9. `@PropertySource` annotations
10. Default properties (`SpringApplication.setDefaultProperties`)

### Relaxed Binding

Spring Boot accepts multiple formats for property names:

| Form | Example |
|---|---|
| Standard camelCase | `maxItemsPerOrder` |
| Kebab-case (recommended) | `max-items-per-order` |
| Underscore | `max_items_per_order` |
| UPPER_SNAKE_CASE (env vars) | `MAX_ITEMS_PER_ORDER` |

All four bind to the same `maxItemsPerOrder` property.

### Spring Cloud Config (Centralized Configuration)

For microservices needing shared configuration:

```yaml
# bootstrap.yml (or spring.config.import)
spring:
  config:
    import: configserver:http://config-server:8888
  cloud:
    config:
      name: order-service
      profile: prod
      label: main         # git branch
```

Config Server serves `order-service-prod.yml` from a Git repository. Clients can refresh config without restart using `@RefreshScope` + `/actuator/refresh`.

---

## 9. Testing

### Test Slices vs Full Context

| Annotation | Context Loaded | Use Case |
|---|---|---|
| `@SpringBootTest` | Full ApplicationContext | Integration tests, end-to-end |
| `@WebMvcTest` | MVC layer only | Controller unit tests |
| `@WebFluxTest` | WebFlux layer only | Reactive controller tests |
| `@DataJpaTest` | JPA layer only | Repository tests |
| `@DataMongoTest` | MongoDB layer only | Mongo repository tests |
| `@JsonTest` | Jackson/Gson only | JSON serialization tests |
| `@RestClientTest` | RestTemplate/WebClient | HTTP client tests |

### @SpringBootTest — Integration Tests

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class OrderIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;    // blocking HTTP client for tests

    @Autowired
    private OrderRepository orderRepository;

    @MockitoBean                             // Boot 3.4+ replaces @MockBean
    private PaymentGateway paymentGateway;

    @Test
    void createOrder_returns201() {
        given(paymentGateway.charge(any())).willReturn(PaymentResult.success());

        ResponseEntity<Order> response = restTemplate.postForEntity(
            "/api/orders",
            new CreateOrderRequest("item-1", 2),
            Order.class
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody().getId()).isNotNull();
    }
}
```

### @WebMvcTest — Controller Unit Tests

```java
@WebMvcTest(OrderController.class)         // Only loads MVC layer
class OrderControllerTest {

    @Autowired
    private MockMvc mockMvc;               // Pre-configured, no server needed

    @MockitoBean
    private OrderService orderService;     // Must mock all controller dependencies

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void getOrder_existingId_returns200() throws Exception {
        Order order = new Order(1L, "PENDING");
        given(orderService.findById(1L)).willReturn(Optional.of(order));

        mockMvc.perform(get("/api/orders/1")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1L))
            .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void createOrder_invalidRequest_returns400() throws Exception {
        CreateOrderRequest request = new CreateOrderRequest(null, -1); // invalid

        mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isBadRequest());
    }
}
```

### @DataJpaTest — Repository Tests

```java
@DataJpaTest                               // H2 in-memory by default, auto-rollback
@AutoConfigureTestDatabase(replace = Replace.NONE)  // Use real DB (with Testcontainers)
class OrderRepositoryTest {

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private TestEntityManager entityManager; // JPA test utilities

    @Test
    void findByStatus_returnsMatchingOrders() {
        entityManager.persist(new Order("PENDING"));
        entityManager.persist(new Order("PENDING"));
        entityManager.persist(new Order("COMPLETED"));
        entityManager.flush();

        List<Order> pending = orderRepository.findByStatus("PENDING");

        assertThat(pending).hasSize(2);
    }
}
```

### Testcontainers Integration

```java
@SpringBootTest
@Testcontainers
class OrderRepositoryIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("testdb")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private OrderRepository orderRepository;

    @Test
    void persistsAndRetrievesOrder() {
        Order saved = orderRepository.save(new Order("PENDING", BigDecimal.TEN));
        Order found = orderRepository.findById(saved.getId()).orElseThrow();
        assertThat(found.getStatus()).isEqualTo("PENDING");
    }
}
```

Spring Boot 3.1+ has first-class Testcontainers support:

```java
// src/test/java — reusable test application
@TestConfiguration(proxyBeanMethods = false)
public class TestContainersConfig {

    @Bean
    @ServiceConnection             // Auto-wires datasource properties from container
    PostgreSQLContainer<?> postgresContainer() {
        return new PostgreSQLContainer<>("postgres:16-alpine");
    }

    @Bean
    @ServiceConnection
    RedisContainer redisContainer() {
        return new RedisContainer("redis:7-alpine");
    }
}
```

### WebTestClient — Reactive Tests

```java
@WebFluxTest(OrderController.class)
class OrderControllerTest {

    @Autowired
    private WebTestClient webTestClient;

    @MockitoBean
    private OrderService orderService;

    @Test
    void getOrder_returns200() {
        given(orderService.findById(1L)).willReturn(Mono.just(new Order(1L, "PENDING")));

        webTestClient.get().uri("/api/orders/1")
            .accept(MediaType.APPLICATION_JSON)
            .exchange()
            .expectStatus().isOk()
            .expectBody(Order.class)
            .value(order -> assertThat(order.getId()).isEqualTo(1L));
    }
}
```

### Test Configuration Patterns

```java
// Override beans for specific tests
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

// Using @WithMockUser (Spring Security Test)
@Test
@WithMockUser(roles = "ADMIN")
void adminEndpoint_withAdminRole_returns200() throws Exception {
    mockMvc.perform(delete("/api/orders/1"))
        .andExpect(status().isNoContent());
}
```

---

## 10. Embedded Servers

### Overview

Spring Boot embeds a servlet container or reactive server inside the executable JAR, eliminating WAR deployment:

```
java -jar order-service.jar
    │
    └── Starts embedded server
    └── Deploys Spring application
    └── Listens on configured port
```

### Available Servers

| Server | Stack | Default | Use Case |
|---|---|---|---|
| **Tomcat** | Servlet (blocking) | Yes (MVC) | General purpose, widely known |
| **Jetty** | Servlet (blocking + async) | No | Lower memory footprint |
| **Undertow** | Servlet + non-blocking | No | High throughput, low latency |
| **Netty** | Reactive (non-blocking) | Yes (WebFlux) | Highest concurrency, reactive |

### Switching Servers

```xml
<!-- Switch from Tomcat to Undertow -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <exclusions>
        <exclusion>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-tomcat</artifactId>
        </exclusion>
    </exclusions>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-undertow</artifactId>
</dependency>
```

### Tomcat Configuration

```yaml
server:
  port: 8080
  tomcat:
    threads:
      max: 200                    # Thread pool max (default: 200)
      min-spare: 10               # Minimum idle threads
    max-connections: 8192         # Max simultaneous connections
    accept-count: 100             # Queue length when max-connections reached
    connection-timeout: 20000     # ms before idle connection closed
  compression:
    enabled: true
    min-response-size: 1024       # Only compress responses >= 1KB
  http2:
    enabled: true
```

### Netty (WebFlux)

```yaml
server:
  port: 8080
  netty:
    connection-timeout: 20s
    idle-timeout: 60s
```

Netty uses an event loop model with `N` threads (default: `2 * CPU cores`). It handles far more concurrent connections than Tomcat because connections don't hold threads while waiting for I/O.

### Thread Model Comparison

**Tomcat (MVC):**
- 1 thread per request while request is active
- Default pool: 200 threads → 200 concurrent requests max
- Thread blocked during DB/network I/O
- Simple to reason about, easy to debug

**Netty (WebFlux):**
- 1 event loop thread handles many connections
- Thread never blocks — I/O completion is a callback/reactive signal
- `N = 2 * CPU` threads → handles thousands of concurrent connections
- Requires reactive/non-blocking throughout (no blocking calls on event loop)

### SSL/TLS Configuration

```yaml
server:
  ssl:
    key-store: classpath:keystore.p12
    key-store-password: ${KEYSTORE_PASSWORD}
    key-store-type: PKCS12
    enabled: true
  port: 8443
```

### Graceful Shutdown

```yaml
server:
  shutdown: graceful      # Wait for in-flight requests to complete
spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
```

---

## Servlet Stack vs Reactive Stack — Summary

| Concern | Servlet (MVC + Tomcat) | Reactive (WebFlux + Netty) |
|---|---|---|
| **Concurrency model** | Thread-per-request | Event loop |
| **Blocking calls** | Native | Must use `Schedulers.boundedElastic()` |
| **Database** | JDBC, JPA, Hibernate | R2DBC, reactive Mongo |
| **Debugging** | Standard stack traces | Complex async traces |
| **Testing** | MockMvc, TestRestTemplate | WebTestClient |
| **Ecosystem** | Mature, vast | Growing |
| **CPU-bound work** | Thread pool scales well | Use `Schedulers.parallel()` |
| **I/O-bound work** | Pool exhaustion risk | Ideal — no threads held |
| **When to choose** | Default, CRUD, team familiarity | High concurrency, streaming, gateway |

---

## Architecture Decision Notes for Senior Devs

### Debugging Auto-Configuration

1. Add `--debug` to JVM args — prints the full conditions evaluation report.
2. Access `/actuator/conditions` at runtime.
3. Check `@ConditionalOnMissingBean` — if your bean is being overridden, ensure it's defined before the auto-configuration fires (using `@AutoConfigureBefore/After`).
4. If a bean is not registered, verify: (a) package is within component scan base, (b) no `@ConditionalOnClass` precondition is unmet.

### Common Pitfalls

- **Circular dependencies**: Constructor injection triggers these early and loudly. Use setter injection for circular cases, or better, redesign to eliminate the cycle.
- **Prototype in singleton**: Use `ObjectProvider<T>` or `@Lookup` injection.
- **N+1 queries in JPA**: Use `@EntityGraph`, `JOIN FETCH` in `@Query`, or batch fetching (`spring.jpa.properties.hibernate.default_batch_fetch_size`).
- **Lazy loading outside transaction**: Either fetch eagerly, keep session open (Open Session in View — disabled by default in Boot 3), or use DTOs/projections.
- **Blocking in WebFlux**: Never call blocking code on the event loop. Identify with `BlockHound` in tests.
- **SecurityFilterChain ordering**: Multiple `SecurityFilterChain` beans are ordered — use `@Order` or `.securityMatcher()` to disambiguate. The most specific matcher should have lowest order value (highest priority).
- **CSRF and stateless APIs**: Disable CSRF for stateless JWT/OAuth2 APIs (`csrf.disable()`). CSRF protection is for session-based authentication.
