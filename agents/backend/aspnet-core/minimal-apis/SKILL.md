---
name: backend-aspnet-core-minimal-apis
description: "Deep-dive expert for ASP.NET Core Minimal APIs across .NET 6-10. Covers architecture (RequestDelegateFactory, RDG), route handlers, route groups, parameter binding, endpoint filters, validation, TypedResults, OpenAPI integration, organizing at scale, and when controllers win. WHEN: \"Minimal API\", \"MapGet\", \"MapPost\", \"MapGroup\", \"route group\", \"endpoint filter\", \"IEndpointFilter\", \"TypedResults\", \"Results<T1,T2>\", \"parameter binding\", \"[AsParameters]\", \"[FromForm]\", \"[FromKeyedServices]\", \"organize minimal APIs\", \"Carter\", \"vertical slice\", \"controllers vs minimal\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# ASP.NET Core Minimal APIs Expert

You are a specialist in ASP.NET Core Minimal APIs across .NET 6 through .NET 10. Minimal APIs are a first-class hosting model built directly on `WebApplication`, bypassing the MVC middleware stack. They use the same endpoint routing infrastructure as MVC but map directly to `RequestDelegate` instances.

For foundational ASP.NET Core knowledge (middleware pipeline, DI, Kestrel, hosting), refer to the parent technology agent. For version-specific features, refer to the version agents.

## How to Approach Tasks

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md` for RequestDelegateFactory, RDG, compile-time generation
   - **Route design** -- Use route groups, parameter binding, and handler organization sections below
   - **Validation** -- Determine version (.NET 10 has built-in; .NET 6-9 requires FluentValidation or MiniValidation)
   - **Controllers vs Minimal** -- Use the decision framework below
   - **OpenAPI** -- Determine version (.NET 9+ built-in; .NET 6-8 Swashbuckle)

2. **Identify version** -- Feature availability varies significantly across .NET versions.

3. **Load context** -- Read `references/architecture.md` for internals questions.

4. **Recommend** -- Provide concrete C# examples. Always note which .NET version is required.

## Core Architecture

Minimal APIs bypass `IControllerFactory`, action filters, and the MVC model binding pipeline. Instead, they use `RequestDelegateFactory` (RDF) to analyze handler parameters and generate a `RequestDelegate` at startup.

```
HTTP Request -> Kestrel -> Middleware pipeline -> EndpointMiddleware
    -> RequestDelegate (your handler) -> Response
```

In .NET 8+, the **Request Delegate Generator (RDG)** replaces runtime reflection with a Roslyn source generator that emits delegate code at **compile time**, enabling Native AOT.

## Route Handlers

```csharp
var app = builder.Build();

app.MapGet("/items", () => new[] { "item1", "item2" });
app.MapPost("/items", (Item item) => Results.Created($"/items/{item.Id}", item));
app.MapPut("/items/{id}", (int id, Item item) => Results.NoContent());
app.MapDelete("/items/{id}", (int id) => Results.NoContent());
app.MapMethods("/options", new[] { "OPTIONS", "HEAD" }, () => Results.Ok());
app.MapFallback(() => Results.NotFound());
```

**Handler types:** inline lambdas, lambda variables, local functions, instance methods, static methods, async handlers.

```csharp
// Named endpoint for link generation
app.MapGet("/users/{id}", (int id) => Results.Ok(new User(id)))
   .WithName("GetUser");

app.MapPost("/users", (User user, LinkGenerator linker) =>
{
    var location = linker.GetPathByName("GetUser", new { id = user.Id });
    return Results.Created(location, user);
});
```

## Route Groups (.NET 7+)

Organize endpoints sharing a prefix, auth policy, filters, or metadata:

```csharp
var api = app.MapGroup("/api").RequireAuthorization();
var v1 = api.MapGroup("/v1");
var todos = v1.MapGroup("/todos").WithTags("Todos");

todos.MapGet("/", GetAllTodos);
todos.MapGet("/{id:int}", GetTodo);
todos.MapPost("/", CreateTodo);
```

**Shared policies across groups:**
```csharp
var publicGroup = app.MapGroup("/public/todos").WithTags("Public");
var privateGroup = app.MapGroup("/private/todos")
    .RequireAuthorization("AdminPolicy").WithTags("Private");

publicGroup.MapTodosApi();
privateGroup.MapTodosApi();

public static RouteGroupBuilder MapTodosApi(this RouteGroupBuilder group)
{
    group.MapGet("/", GetAllTodos);
    group.MapPost("/", CreateTodo);
    return group;
}
```

**ProducesProblem on groups (.NET 9+):**
```csharp
var todos = app.MapGroup("/todos")
    .ProducesProblem()
    .ProducesValidationProblem();
```

**Filter ordering:** Outer group filters run before inner group filters, regardless of registration order.

## Parameter Binding

### Automatic Inference

| Parameter Type | Inferred Source |
|---|---|
| Appears in route template | Route value |
| Simple type not in route | Query string |
| Complex type (class/record) | Body (JSON) |
| Registered DI service | Dependency injection |
| `HttpContext`, `HttpRequest`, `HttpResponse` | Framework special |
| `CancellationToken` | Framework special |
| `ClaimsPrincipal` | Framework special |
| `IFormFile`, `IFormFileCollection` | Form |
| `Stream`, `PipeReader` | Body (raw) |

```csharp
app.MapGet("/{id}", (int id,        // route
                     int page,       // query string
                     IMyService svc) // DI
    => { });

app.MapPost("/", (Person person) => { }); // body JSON
```

### Explicit Binding

```csharp
app.MapGet("/{id}", (
    [FromRoute] int id,
    [FromQuery(Name = "p")] int page,
    [FromHeader(Name = "X-Api-Version")] string apiVersion,
    [FromServices] IMyService service,
    [FromBody] SearchCriteria criteria) => { });
```

### Form Binding (.NET 8+)

```csharp
app.MapPost("/todos", ([FromForm] string name, [FromForm] bool done) => { });
app.MapPost("/upload", ([FromForm] IFormFile file) => { });
app.MapPost("/contact", ([FromForm] ContactForm form) => Results.Ok(form));
```

Antiforgery validation is automatic with `[FromForm]`. Opt out with `[IgnoreAntiforgeryToken]`.

### [AsParameters] (.NET 7+)

Groups multiple parameters into a single struct/class:

```csharp
app.MapGet("/todos/{id}", ([AsParameters] GetTodoRequest req) =>
    req.Db.Todos.FindAsync(req.Id));

struct GetTodoRequest
{
    public int Id { get; set; }          // route
    public TodoDb Db { get; set; }       // DI
    public ILogger<Program> Logger { get; set; } // DI
}
```

Flat parameter destructuring -- not recursive model binding.

### Custom Binding

```csharp
// TryParse -- for route/query string
public record Point(double X, double Y)
{
    public static bool TryParse(string? value, out Point point)
    {
        var parts = value?.Split(',');
        if (parts?.Length == 2 && double.TryParse(parts[0], out var x)
            && double.TryParse(parts[1], out var y))
        {
            point = new Point(x, y);
            return true;
        }
        point = default!;
        return false;
    }
}

// BindAsync -- for async binding
public class Pagination
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;

    public static ValueTask<Pagination?> BindAsync(HttpContext ctx, ParameterInfo parameter)
    {
        int.TryParse(ctx.Request.Query["page"], out var page);
        int.TryParse(ctx.Request.Query["pageSize"], out var pageSize);
        return ValueTask.FromResult<Pagination?>(new Pagination
        {
            Page = page > 0 ? page : 1,
            PageSize = pageSize is > 0 and <= 100 ? pageSize : 20
        });
    }
}
```

## Endpoint Filters (.NET 7+)

Pipeline within each endpoint, running before and after the handler with access to arguments:

```csharp
app.MapGet("/colors/{color}", (string color) => $"Color: {color}")
    .AddEndpointFilter(async (ctx, next) =>
    {
        var color = ctx.GetArgument<string>(0);
        if (color == "Red") return Results.Problem("Red not allowed!");
        return await next(ctx);
    });
```

### Class-Based Filter

```csharp
public class ValidationFilter<T> : IEndpointFilter where T : class
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext ctx, EndpointFilterDelegate next)
    {
        var model = ctx.Arguments.OfType<T>().FirstOrDefault();
        if (model is null) return await next(ctx);

        var validator = ctx.HttpContext.RequestServices
            .GetRequiredService<IValidator<T>>();
        var result = await validator.ValidateAsync(model);
        if (!result.IsValid)
            return Results.ValidationProblem(result.ToDictionary());
        return await next(ctx);
    }
}

app.MapPost("/todos", CreateTodo)
   .AddEndpointFilter<ValidationFilter<CreateTodoRequest>>();
```

**Execution order:** FIFO before handler, FILO after handler (like middleware).

## TypedResults and IResult

### Results vs TypedResults

| Aspect | `Results` | `TypedResults` |
|---|---|---|
| Return type | `IResult` | Concrete type (`Ok<T>`, `NotFound`, etc.) |
| OpenAPI metadata | Must call `.Produces<T>()` | Automatically inferred |
| Unit testing | Requires cast | Direct type assertion |

```csharp
// TypedResults -- automatic OpenAPI metadata
app.MapGet("/todos/{id}",
    async Task<Results<Ok<Todo>, NotFound>> (int id, TodoDb db) =>
    await db.Todos.FindAsync(id) is Todo todo
        ? TypedResults.Ok(todo)
        : TypedResults.NotFound());
```

### Common Result Factories

```csharp
TypedResults.Ok(value)                              // 200
TypedResults.Created("/path", value)                // 201
TypedResults.NoContent()                            // 204
TypedResults.BadRequest(detail)                     // 400
TypedResults.NotFound()                             // 404
TypedResults.Problem(detail, title, statusCode)     // ProblemDetails
TypedResults.ValidationProblem(errors)              // Validation errors
TypedResults.InternalServerError(detail)            // 500 (.NET 9+)
TypedResults.ServerSentEvents(asyncEnumerable)      // SSE (.NET 10+)
TypedResults.File("path.pdf", "application/pdf")    // File download
TypedResults.Redirect("/new-url")                   // Redirect
```

## Validation

### .NET 10: Built-In

```csharp
builder.Services.AddValidation();

public record Product([Required] string Name, [Range(1, 1000)] int Qty);
app.MapPost("/products", (Product p) => TypedResults.Ok(p));
// 400 ValidationProblem returned automatically if invalid
```

### .NET 6-9: FluentValidation via Endpoint Filter

```csharp
public class FluentValidationFilter<T> : IEndpointFilter where T : class
{
    private readonly IValidator<T> _validator;
    public FluentValidationFilter(IValidator<T> validator) => _validator = validator;

    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext ctx, EndpointFilterDelegate next)
    {
        var model = ctx.Arguments.OfType<T>().FirstOrDefault();
        if (model is null) return await next(ctx);

        var result = await _validator.ValidateAsync(model, ctx.HttpContext.RequestAborted);
        if (!result.IsValid)
            return Results.ValidationProblem(result.ToDictionary());
        return await next(ctx);
    }
}
```

## OpenAPI Integration

### .NET 9+: Built-In

```csharp
builder.Services.AddOpenApi();
app.MapOpenApi(); // /openapi/v1.json

app.MapGet("/todos/{id}", GetTodo)
   .WithSummary("Get a todo by ID")
   .WithDescription("Returns 404 if not found.")
   .WithTags("Todos")
   .WithName("GetTodoById");
```

### .NET 6-8: Swashbuckle

```csharp
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
app.UseSwagger();
app.UseSwaggerUI();
```

## Organizing at Scale

### Extension Method Pattern (Recommended)

```csharp
// TodoModule.cs
public static class TodoModule
{
    public static IEndpointRouteBuilder MapTodos(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/todos")
            .WithTags("Todos").RequireAuthorization();

        group.MapGet("/", GetAll);
        group.MapGet("/{id:int}", GetById);
        group.MapPost("/", Create);
        return app;
    }

    static async Task<Ok<List<Todo>>> GetAll(TodoDb db)
        => TypedResults.Ok(await db.Todos.ToListAsync());
}

// Program.cs
app.MapTodos();
app.MapOrders();
```

### Vertical Slice Architecture

```
Features/
  Todos/
    CreateTodo.cs    -- request, response, handler, validator
    GetTodo.cs
    TodoModule.cs    -- maps all todo endpoints
  Orders/
    CreateOrder.cs
    OrderModule.cs
```

```csharp
public static class CreateTodo
{
    public record Request(string Name, DateOnly? DueDate);
    public record Response(int Id, string Name);

    public static void Map(RouteGroupBuilder group)
    {
        group.MapPost("/", Handle)
             .WithSummary("Create a new todo")
             .AddEndpointFilter<FluentValidationFilter<Request>>();
    }

    static async Task<Created<Response>> Handle(Request req, TodoDb db, CancellationToken ct)
    {
        var todo = new Todo { Name = req.Name, DueDate = req.DueDate };
        db.Todos.Add(todo);
        await db.SaveChangesAsync(ct);
        return TypedResults.Created($"/todos/{todo.Id}", new Response(todo.Id, todo.Name));
    }
}
```

### Carter Library

Auto-discovery of modules via assembly scanning:

```csharp
builder.Services.AddCarter();
app.MapCarter();

public class TodoModule : ICarterModule
{
    public void AddRoutes(IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/todos").WithTags("Todos");
        group.MapGet("/", GetAll);
        group.MapPost("/", Create);
    }
}
```

## When Controllers Win

| Scenario | Why Controllers Win |
|---|---|
| **OData** | Only works with `ControllerBase` |
| **JsonPatch** | Integrates with MVC `ApplyTo()` |
| **Complex model binding** | `IModelBinderProvider` / `IModelBinder` |
| **Action filters** | Full MVC filter pipeline |
| **API Versioning** | `Asp.Versioning.Mvc` more mature |
| **Large teams with MVC background** | Lower learning curve |

### Decision Framework

```
New project?                    -> Minimal APIs
Need OData?                     -> Controllers (no alternative)
Need JsonPatch?                 -> Controllers (or build custom)
Performance-critical / AOT?     -> Minimal APIs
Large enterprise, team knows MVC? -> Either; controllers reduce learning curve
Everything else?                -> Minimal APIs with MapGroup + extension methods
```

Both coexist -- migrate incrementally:
```csharp
app.MapControllers();                        // Controller routes
app.MapGet("/v2/orders", MinimalHandler);    // Minimal API alongside
```

## Version Feature Matrix

| Feature | .NET 6 | .NET 7 | .NET 8 | .NET 9 | .NET 10 |
|---|---|---|---|---|---|
| MapGet/Post/Put/Delete | Yes | Yes | Yes | Yes | Yes |
| TypedResults / Results unions | -- | Yes | Yes | Yes | Yes |
| MapGroup | -- | Yes | Yes | Yes | Yes |
| IEndpointFilter | -- | Yes | Yes | Yes | Yes |
| [AsParameters] | -- | Yes | Yes | Yes | Yes |
| [FromForm] binding | -- | -- | Yes | Yes | Yes |
| Keyed DI ([FromKeyedServices]) | -- | -- | Yes | Yes | Yes |
| Native AOT (RDG) | -- | -- | Yes | Yes | Yes |
| Built-in OpenAPI (AddOpenApi) | -- | -- | -- | Yes | Yes |
| Built-in validation (AddValidation) | -- | -- | -- | -- | Yes |
| Server-Sent Events (SSE) | -- | -- | -- | -- | Yes |
| OpenAPI 3.1 + YAML | -- | -- | -- | -- | Yes |

## Reference Files

- `references/architecture.md` -- RequestDelegateFactory internals, RDG compile-time generation, pipeline details, evolution across .NET versions. **Load when:** internals questions, AOT debugging, understanding how binding works under the hood.
