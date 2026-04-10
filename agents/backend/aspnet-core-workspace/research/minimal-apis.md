# ASP.NET Core Minimal APIs — Deep Dive Reference

**Target audience:** Senior .NET developers evaluating Minimal APIs for production  
**Versions covered:** .NET 6 through .NET 10  
**Last updated:** April 2026

---

## Table of Contents

1. [Architecture and Internals](#1-architecture-and-internals)
2. [Route Handlers and HTTP Methods](#2-route-handlers-and-http-methods)
3. [Route Groups](#3-route-groups)
4. [Parameter Binding](#4-parameter-binding)
5. [Endpoint Filters](#5-endpoint-filters)
6. [Validation](#6-validation)
7. [TypedResults and IResult](#7-typedresults-and-iresult)
8. [OpenAPI Integration](#8-openapi-integration)
9. [Organizing Minimal APIs at Scale](#9-organizing-minimal-apis-at-scale)
10. [When Controllers Win](#10-when-controllers-win)
11. [Version Evolution (.NET 6 through .NET 10)](#11-version-evolution)

---

## 1. Architecture and Internals

### How Minimal APIs Work

Minimal APIs were introduced in .NET 6 as a first-class hosting model built directly on top of `WebApplication`. They bypass the MVC middleware stack entirely — no `IControllerFactory`, no action filters, no model binding pipeline. Instead, they use the same **endpoint routing** infrastructure that MVC uses, but map directly to `RequestDelegate` instances.

The core pipeline:

```
HTTP Request
    → Kestrel
    → Middleware pipeline (UseRouting, etc.)
    → EndpointMiddleware
    → RequestDelegate  ← your lambda/method runs here
    → Response
```

### RequestDelegate and RequestDelegateFactory

Internally, when you call `MapGet("/path", myHandler)`, ASP.NET Core uses `RequestDelegateFactory` (RDF) to analyze your handler's parameter list via reflection and emit a `RequestDelegate` — a `Func<HttpContext, Task>` — at startup. For each parameter, the factory decides the binding source (route, query, body, services, etc.) and generates the appropriate binding code.

```csharp
// What you write:
app.MapGet("/users/{id}", (int id, IUserService svc) => svc.GetUser(id));

// What the framework generates at runtime (simplified):
RequestDelegate del = async (HttpContext ctx) =>
{
    var id = int.Parse((string)ctx.Request.RouteValues["id"]!);
    var svc = ctx.RequestServices.GetRequiredService<IUserService>();
    var result = handler(id, svc);
    await ctx.Response.WriteAsJsonAsync(result);
};
```

### Request Delegate Generator (RDG) — .NET 8+

In .NET 8, the **Request Delegate Generator** (RDG) replaced runtime reflection with a Roslyn source generator that emits the delegate code at **compile time** using C# 12 interceptors. Benefits:

- Native AOT compatibility (no runtime code generation)
- Faster startup (no reflection at startup)
- Compile-time warnings for binding issues

Enable manually:

```xml
<PropertyGroup>
  <EnableRequestDelegateGenerator>true</EnableRequestDelegateGenerator>
</PropertyGroup>
```

Enabled automatically when `PublishAot` is set.

### Minimal APIs vs. Controllers: Key Differences

| Aspect | Minimal APIs | Controller-based APIs |
|--------|-------------|----------------------|
| Boilerplate | Minimal — no class needed | Requires `ControllerBase` subclass |
| DI binding | Automatic from registered services | `[FromServices]` or constructor injection |
| Middleware | Same pipeline | Same pipeline |
| Filters | `IEndpointFilter` | Action filters, result filters, exception filters |
| Model binding | Limited to explicit binding sources | Full `IModelBinder` extensibility |
| OpenAPI | Attribute + extension method based | Attributes + ApiExplorer |
| AOT support | Full (with RDG) | Not supported |
| Performance | Slightly faster (less overhead) | Slightly more overhead |
| Test ergonomics | `WebApplicationFactory` + `TypedResults` | `WebApplicationFactory` + `ControllerContext` |

**Microsoft's current guidance:** Minimal APIs are recommended for new projects.

---

## 2. Route Handlers and HTTP Methods

### Basic Map Methods

`WebApplication` exposes `Map{Verb}` methods for all standard HTTP methods:

```csharp
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/items", () => new[] { "item1", "item2" });
app.MapPost("/items", (Item item) => Results.Created($"/items/{item.Id}", item));
app.MapPut("/items/{id}", (int id, Item item) => Results.NoContent());
app.MapDelete("/items/{id}", (int id) => Results.NoContent());
app.MapPatch("/items/{id}", (int id, JsonPatchDocument<Item> patch) => Results.Ok());

// Multiple verbs on one route
app.MapMethods("/options-or-head", new[] { "OPTIONS", "HEAD" }, () => Results.Ok());

// Catch-all
app.MapFallback(() => Results.NotFound());
```

### Handler Types

Route handlers can be any of the following:

```csharp
// 1. Inline lambda
app.MapGet("/inline", () => "Hello from inline lambda");

// 2. Lambda variable
var handler = () => "Hello from lambda variable";
app.MapGet("/var", handler);

// 3. Local function
string LocalFunction() => "Hello from local function";
app.MapGet("/local", LocalFunction);

// 4. Instance method
var service = new GreetingService();
app.MapGet("/instance", service.Greet);

// 5. Static method
app.MapGet("/static", GreetingService.StaticGreet);

// 6. Async handlers
app.MapGet("/async", async (CancellationToken ct) =>
{
    await Task.Delay(100, ct);
    return Results.Ok("done");
});
```

### Route Parameters and Constraints

```csharp
// Basic route parameter
app.MapGet("/users/{userId}/books/{bookId}",
    (int userId, int bookId) => $"User {userId}, Book {bookId}");

// Type constraints in route template
app.MapGet("/todos/{id:int}", (int id) => $"Todo {id}");
app.MapGet("/todos/{text}", (string text) => $"Search: {text}");
app.MapGet("/posts/{slug:regex(^[a-z0-9_-]+$)}", (string slug) => $"Post {slug}");

// Catch-all / wildcard
app.MapGet("/files/{*path}", (string path) => $"File: {path}");
```

### Named Endpoints and Link Generation

```csharp
app.MapGet("/users/{id}", (int id) => Results.Ok(new User(id)))
   .WithName("GetUser");

app.MapPost("/users", (User user, LinkGenerator linker) =>
{
    var location = linker.GetPathByName("GetUser", new { id = user.Id });
    return Results.Created(location, user);
});
```

### Endpoints Defined Outside Program.cs

```csharp
// Program.cs
using MyApp;

var app = WebApplication.Create();
TodoEndpoints.Map(app);
app.Run();

// TodoEndpoints.cs
namespace MyApp;

public static class TodoEndpoints
{
    public static void Map(WebApplication app)
    {
        app.MapGet("/todos", GetAll);
        app.MapGet("/todos/{id}", GetById);
        app.MapPost("/todos", Create);
        app.MapPut("/todos/{id}", Update);
        app.MapDelete("/todos/{id}", Delete);
    }

    static async Task<IResult> GetAll(TodoDb db)
        => Results.Ok(await db.Todos.ToListAsync());

    static async Task<IResult> GetById(int id, TodoDb db)
        => await db.Todos.FindAsync(id) is Todo todo
            ? Results.Ok(todo)
            : Results.NotFound();

    // ... other handlers
}
```

---

## 3. Route Groups

Introduced in **.NET 7**, `MapGroup()` allows organizing endpoints that share a common prefix, authorization policy, filters, or metadata.

### Basic Group

```csharp
// Without groups (repetitive)
app.MapGet("/api/v1/todos", GetTodos);
app.MapGet("/api/v1/todos/{id}", GetTodo);
app.MapPost("/api/v1/todos", CreateTodo);

// With MapGroup
var todos = app.MapGroup("/api/v1/todos");
todos.MapGet("/", GetTodos);
todos.MapGet("/{id}", GetTodo);
todos.MapPost("/", CreateTodo);
```

### Shared Policies and Metadata

```csharp
var publicGroup = app.MapGroup("/public/todos")
    .WithTags("Public Todos")
    .WithOpenApi();

var privateGroup = app.MapGroup("/private/todos")
    .WithTags("Private Todos")
    .RequireAuthorization("AdminPolicy")
    .WithOpenApi();

// Both groups share the same endpoint implementations
publicGroup.MapTodosApi();
privateGroup.MapTodosApi();

// Extension method registers the endpoints
public static RouteGroupBuilder MapTodosApi(this RouteGroupBuilder group)
{
    group.MapGet("/", GetAllTodos);
    group.MapGet("/{id}", GetTodo);
    group.MapPost("/", CreateTodo);
    group.MapPut("/{id}", UpdateTodo);
    group.MapDelete("/{id}", DeleteTodo);
    return group;
}
```

### Nested Groups

```csharp
var api = app.MapGroup("/api");
var v1 = api.MapGroup("/v1");
var todos = v1.MapGroup("/todos");

todos.MapGet("/", GetAllTodos);
todos.MapGet("/{id:int}", GetTodo);

// Route parameters from outer groups are captured
var org = app.MapGroup("{org}");
var user = org.MapGroup("{user}");
user.MapGet("", (string org, string user) => $"{org}/{user}");
```

### Groups with ProducesProblem (.NET 9)

```csharp
var todos = app.MapGroup("/todos")
    .ProducesProblem()           // Declares all endpoints can return ProblemDetails
    .ProducesValidationProblem(); // Declares all endpoints can return ValidationProblemDetails

todos.MapGet("/", () => new Todo(1, "Sample", false));
todos.MapPost("/", (Todo todo) => Results.Ok(todo));
```

### Filter Ordering with Nested Groups

Filters on outer groups run before filters on inner groups, regardless of registration order:

```csharp
var outer = app.MapGroup("/outer");
var inner = outer.MapGroup("/inner");

// Register inner filter FIRST
inner.AddEndpointFilter((ctx, next) =>
{
    app.Logger.LogInformation("/inner group filter");
    return next(ctx);
});

// Register outer filter SECOND
outer.AddEndpointFilter((ctx, next) =>
{
    app.Logger.LogInformation("/outer group filter");
    return next(ctx);
});

inner.MapGet("/", () => "Hi!");
```

A request to `/outer/inner/` logs:

```
/outer group filter
/inner group filter
MapGet filter (if any on the endpoint itself)
```

---

## 4. Parameter Binding

### Binding Source Priority

The framework automatically infers binding sources in this order:

| Parameter Type | Inferred Source |
|----------------|-----------------|
| Appears in route template | Route value |
| Simple type (int, string, etc.) not in route | Query string |
| Complex type (class/record) | Body (JSON) |
| Registered DI service | Dependency Injection |
| `HttpContext`, `HttpRequest`, `HttpResponse` | Framework special |
| `CancellationToken` | Framework special |
| `ClaimsPrincipal` | Framework special |
| `IFormFile`, `IFormFileCollection` | Form |
| `Stream`, `PipeReader` | Body (raw) |

```csharp
// Automatic inference example
app.MapGet("/{id}", (int id,          // route (in template)
                     int page,         // query string (not in template)
                     Service svc) =>   // DI (registered service)
{
    // ...
});

app.MapPost("/", (Person person) => { }); // body JSON (complex type)
```

### Explicit Attribute-Based Binding

```csharp
using Microsoft.AspNetCore.Mvc;

app.MapGet("/{id}", (
    [FromRoute] int id,
    [FromQuery(Name = "p")] int page,
    [FromHeader(Name = "X-Api-Version")] string apiVersion,
    [FromServices] IMyService service,
    [FromBody] SearchCriteria criteria) => { });
```

### Form Binding (.NET 8+)

```csharp
// Simple form fields
app.MapPost("/todos", async ([FromForm] string name,
    [FromForm] bool isComplete,
    IFormFile? attachment,
    IAntiforgery antiforgery,
    HttpContext ctx) =>
{
    await antiforgery.ValidateRequestAsync(ctx);
    // process...
    return Results.Ok();
});

// Complex form object with [AsParameters]
app.MapPost("/todos", async ([AsParameters] NewTodoRequest request, TodoDb db) =>
{
    var todo = new Todo { Name = request.Name, IsComplete = request.IsComplete };
    if (request.Attachment is not null)
    {
        using var stream = File.OpenWrite(Path.GetTempFileName());
        await request.Attachment.CopyToAsync(stream);
    }
    db.Todos.Add(todo);
    await db.SaveChangesAsync();
    return Results.Ok();
});

public record struct NewTodoRequest(
    [FromForm] string Name,
    [FromForm] bool IsComplete,
    IFormFile? Attachment);
```

**Note:** Form binding with `[FromForm]` automatically validates antiforgery tokens. Call `app.UseAntiforgery()` and register `builder.Services.AddAntiforgery()`.

### [AsParameters] for Grouping Handler Parameters

Introduced in **.NET 7**. Groups multiple parameters into a single struct/class:

```csharp
// Before [AsParameters]
app.MapGet("/todos/{id}", async (int id, TodoDb db, ILogger<Program> logger) =>
    await db.Todos.FindAsync(id) is Todo todo
        ? Results.Ok(todo)
        : Results.NotFound());

// After [AsParameters]
app.MapGet("/ap/todos/{id}", async ([AsParameters] GetTodoRequest req) =>
    await req.Db.Todos.FindAsync(req.Id) is Todo todo
        ? Results.Ok(todo)
        : Results.NotFound());

struct GetTodoRequest
{
    public int Id { get; set; }          // bound from route
    public TodoDb Db { get; set; }       // bound from DI
    public ILogger<Program> Logger { get; set; } // bound from DI
}
```

`[AsParameters]` is flat parameter destructuring, **not** recursive model binding. Each property is bound independently using the same rules as top-level parameters.

### Custom Binding via TryParse

Any type with a static `TryParse(string, out T)` method can be bound from route or query string:

```csharp
public record Point(double X, double Y)
{
    public static bool TryParse(string? value, out Point point)
    {
        var parts = value?.Split(',');
        if (parts?.Length == 2
            && double.TryParse(parts[0], out var x)
            && double.TryParse(parts[1], out var y))
        {
            point = new Point(x, y);
            return true;
        }
        point = default!;
        return false;
    }
}

// GET /distance?from=0,0&to=3,4
app.MapGet("/distance", (Point from, Point to) =>
    Math.Sqrt(Math.Pow(to.X - from.X, 2) + Math.Pow(to.Y - from.Y, 2)));
```

### Custom Binding via BindAsync

For async binding (e.g., reading from body or external sources):

```csharp
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

app.MapGet("/items", (Pagination pagination, ItemDb db) =>
    db.Items.Skip((pagination.Page - 1) * pagination.PageSize)
            .Take(pagination.PageSize)
            .ToList());
```

### Special Bound Types

```csharp
// HttpContext — full request/response access
app.MapGet("/ctx", (HttpContext ctx) => ctx.Connection.RemoteIpAddress?.ToString());

// HttpRequest / HttpResponse
app.MapGet("/req", (HttpRequest req, HttpResponse res) =>
    res.WriteAsync($"Host: {req.Host}"));

// CancellationToken — from the request lifecycle
app.MapGet("/slow", async (CancellationToken ct) =>
{
    await Task.Delay(5000, ct);
    return Results.Ok("done");
});

// ClaimsPrincipal — current authenticated user
app.MapGet("/me", (ClaimsPrincipal user) => user.Identity?.Name)
   .RequireAuthorization();

// Keyed DI (.NET 8+)
app.MapGet("/cache", ([FromKeyedServices("redis")] ICache cache) =>
    cache.Get("key"));
```

### Array and Collection Binding

```csharp
// Bind multiple query values to array
// GET /tags?q=1&q=2&q=3
app.MapGet("/tags", (int[] q) => string.Join(", ", q));

// Bind from header
app.MapGet("/items", ([FromHeader(Name = "X-Item-Id")] int[] ids) =>
    ids.Select(id => $"Item {id}"));

// StringValues
app.MapGet("/names", (StringValues names) => names.Count);
```

### Optional Parameters

```csharp
// Nullable type
app.MapGet("/products", (int? page) => $"Page: {page ?? 1}");

// Default value
app.MapGet("/products2", (int page = 1, int size = 20) => $"Page {page}, Size {size}");
```

---

## 5. Endpoint Filters

Introduced in **.NET 7**, endpoint filters provide a pipeline within each endpoint — running before and after the handler with access to handler arguments.

### The Filter Interface

```csharp
public interface IEndpointFilter
{
    ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next);
}
```

`EndpointFilterInvocationContext` exposes:
- `HttpContext` — the current HTTP context
- `Arguments` — the handler's arguments in declaration order
- `GetArgument<T>(int index)` — type-safe argument access

### Basic Filter with Lambda

```csharp
app.MapGet("/colors/{color}", (string color) => $"Color: {color}")
    .AddEndpointFilter(async (ctx, next) =>
    {
        var color = ctx.GetArgument<string>(0);

        if (color == "Red")
            return Results.Problem("Red is not allowed!");

        return await next(ctx); // short-circuit if we don't call next
    });
```

### Class-Based Filter

```csharp
public class ValidationFilter<T> : IEndpointFilter where T : class
{
    private readonly IValidator<T> _validator;

    public ValidationFilter(IValidator<T> validator)
    {
        _validator = validator;
    }

    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext ctx,
        EndpointFilterDelegate next)
    {
        // Find the T argument
        var model = ctx.Arguments.OfType<T>().FirstOrDefault();
        if (model is null)
            return await next(ctx);

        var result = await _validator.ValidateAsync(model);
        if (!result.IsValid)
        {
            return Results.ValidationProblem(result.ToDictionary());
        }

        return await next(ctx);
    }
}

// Usage
app.MapPost("/todos", CreateTodo)
   .AddEndpointFilter<ValidationFilter<CreateTodoRequest>>();
```

### Filter Ordering (FIFO/FILO)

Multiple filters on the same endpoint execute in **FIFO order for code before `next`** and **FILO order for code after `next`** — like standard middleware:

```csharp
app.MapGet("/", () => { /* handler */ })
    .AddEndpointFilter(async (ctx, next) =>
    {
        Console.WriteLine("Filter 1 before");
        var result = await next(ctx);
        Console.WriteLine("Filter 1 after");  // runs LAST
        return result;
    })
    .AddEndpointFilter(async (ctx, next) =>
    {
        Console.WriteLine("Filter 2 before");
        var result = await next(ctx);
        Console.WriteLine("Filter 2 after");  // runs SECOND
        return result;
    })
    .AddEndpointFilter(async (ctx, next) =>
    {
        Console.WriteLine("Filter 3 before");
        var result = await next(ctx);
        Console.WriteLine("Filter 3 after");  // runs FIRST
        return result;
    });
```

Output:
```
Filter 1 before
Filter 2 before
Filter 3 before
[handler]
Filter 3 after
Filter 2 after
Filter 1 after
```

### Filter Factory (for Compile-Time Inspection)

`AddEndpointFilterFactory` runs at app startup — use it to inspect handler metadata once and build an optimized filter:

```csharp
app.MapPut("/todos/{id}", UpdateTodo)
    .AddEndpointFilterFactory((factoryCtx, next) =>
    {
        // Inspect the handler's parameters at startup
        var parameters = factoryCtx.MethodInfo.GetParameters();
        var todoIndex = Array.FindIndex(parameters, p => p.ParameterType == typeof(Todo));

        if (todoIndex < 0)
            return invocationCtx => next(invocationCtx); // pass-through

        // Build optimized filter that knows exactly which argument to validate
        return async invocationCtx =>
        {
            var todo = invocationCtx.GetArgument<Todo>(todoIndex);
            if (string.IsNullOrEmpty(todo.Name))
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["Name"] = ["Name is required"]
                });

            return await next(invocationCtx);
        };
    });
```

### Applying Filters to Controller Actions

```csharp
// Same endpoint filter can apply to both Minimal API and controller action endpoints
app.MapControllers()
    .AddEndpointFilter(async (ctx, next) =>
    {
        ctx.HttpContext.Items["requestId"] = Guid.NewGuid();
        return await next(ctx);
    });
```

---

## 6. Validation

Minimal APIs don't have built-in model validation like MVC. The ecosystem offers several approaches.

### .NET 10 Built-in Validation

**.NET 10** introduced first-class validation support via `AddValidation()`:

```csharp
// Program.cs
builder.Services.AddValidation();

// Works with System.ComponentModel.DataAnnotations
app.MapPost("/products", (Product product) => TypedResults.Ok(product));

public record Product(
    [Required] string Name,
    [Range(1, 1000)] int Quantity,
    [EmailAddress] string? ContactEmail);

// Returns 400 ValidationProblem automatically on failure
```

Disable for specific endpoints:

```csharp
app.MapPost("/raw", (RawData data) => TypedResults.Ok(data))
   .DisableValidation();
```

### FluentValidation via Endpoint Filter (.NET 6–9)

```csharp
// NuGet: FluentValidation.AspNetCore

// Validator definition
public class CreateTodoValidator : AbstractValidator<CreateTodoRequest>
{
    public CreateTodoValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.DueDate).GreaterThan(DateOnly.FromDateTime(DateTime.Today));
    }
}

// Reusable validation filter
public class FluentValidationFilter<T> : IEndpointFilter where T : class
{
    private readonly IValidator<T> _validator;

    public FluentValidationFilter(IValidator<T> validator)
        => _validator = validator;

    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext ctx,
        EndpointFilterDelegate next)
    {
        var model = ctx.Arguments.OfType<T>().FirstOrDefault();
        if (model is null) return await next(ctx);

        var result = await _validator.ValidateAsync(model, ctx.HttpContext.RequestAborted);
        if (!result.IsValid)
        {
            return Results.ValidationProblem(
                result.ToDictionary(),
                title: "Validation failed",
                statusCode: 422);
        }

        return await next(ctx);
    }
}

// Registration
builder.Services.AddValidatorsFromAssemblyContaining<Program>();

// Usage
app.MapPost("/todos", CreateTodo)
   .AddEndpointFilter<FluentValidationFilter<CreateTodoRequest>>();
```

### MiniValidation

MiniValidation (NuGet: `MiniValidation`) is a lightweight library that evaluates `DataAnnotations` with support for recursive validation:

```csharp
// NuGet: MiniValidation
using MiniValidation;

app.MapPost("/products", (Product product) =>
{
    if (!MiniValidator.TryValidate(product, out var errors))
        return Results.ValidationProblem(errors);

    // ... create product
    return Results.Created($"/products/{product.Id}", product);
});

public class Product
{
    public int Id { get; set; }

    [Required, MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [Range(0.01, 10000)]
    public decimal Price { get; set; }

    [Required]
    public Category Category { get; set; } = new();
}

public class Category
{
    [Required, MaxLength(50)]
    public string Name { get; set; } = string.Empty;
}
```

### Problem Details Integration

```csharp
// Register IProblemDetails service
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = context =>
    {
        if (context.ProblemDetails.Status == 400)
        {
            context.ProblemDetails.Title = "Validation failed";
            context.ProblemDetails.Extensions["traceId"] =
                Activity.Current?.Id ?? context.HttpContext.TraceIdentifier;
        }
    };
});

// Return validation problems
app.MapPost("/orders", (Order order) =>
{
    var errors = new Dictionary<string, string[]>();

    if (string.IsNullOrEmpty(order.CustomerId))
        errors["customerId"] = ["CustomerId is required"];

    if (order.Quantity <= 0)
        errors["quantity"] = ["Quantity must be greater than zero"];

    if (errors.Count > 0)
        return Results.ValidationProblem(errors);

    return Results.Created($"/orders/{order.Id}", order);
});
```

---

## 7. TypedResults and IResult

### Return Type Options

Minimal API handlers can return:

1. `string` — written as `text/plain` with 200
2. `T` (any type) — JSON-serialized with 200
3. `IResult` — calls `IResult.ExecuteAsync(HttpContext)`

### Results vs TypedResults

Both `Results` and `TypedResults` provide the same factory methods, but with different return types:

| Aspect | `Results` | `TypedResults` |
|--------|-----------|----------------|
| Return type | `IResult` | Concrete type (`Ok<T>`, `NotFound`, etc.) |
| OpenAPI metadata | Must call `.Produces<T>()` | Automatically inferred |
| Unit testing | Requires cast | Direct type assertion |
| Multiple return types | Compiles implicitly | Requires `Results<T1, T2>` union |

```csharp
// Results approach — manual OpenAPI annotation needed
app.MapGet("/todos/{id}", async (int id, TodoDb db) =>
    await db.Todos.FindAsync(id) is Todo todo
        ? Results.Ok(todo)
        : Results.NotFound())
    .Produces<Todo>()
    .Produces(404);

// TypedResults approach — OpenAPI metadata automatic
app.MapGet("/todos/{id}", async Task<Results<Ok<Todo>, NotFound>> (int id, TodoDb db) =>
    await db.Todos.FindAsync(id) is Todo todo
        ? TypedResults.Ok(todo)
        : TypedResults.NotFound());
```

### Results Union Types

When a handler can return multiple `IResult` types and you want static type information:

```csharp
app.MapGet("/orders/{id}",
    async Task<Results<Ok<Order>, NotFound, ForbidHttpResult>> (
        int id, ClaimsPrincipal user, OrderDb db) =>
{
    var order = await db.Orders.FindAsync(id);
    if (order is null) return TypedResults.NotFound();
    if (order.UserId != user.FindFirst("sub")?.Value) return TypedResults.Forbid();
    return TypedResults.Ok(order);
});
```

### Common Result Factories

```csharp
// Success responses
TypedResults.Ok(value)                        // 200 + JSON body
TypedResults.Created("/path", value)          // 201 + Location header
TypedResults.CreatedAtRoute("routeName", routeValues, value) // 201
TypedResults.Accepted("/path", value)         // 202
TypedResults.NoContent()                      // 204
TypedResults.ResetContent()                   // 205

// Client error responses
TypedResults.BadRequest(detail)               // 400
TypedResults.Unauthorized()                   // 401
TypedResults.Forbid()                         // 403
TypedResults.NotFound()                       // 404
TypedResults.Conflict(detail)                 // 409
TypedResults.UnprocessableEntity(detail)      // 422

// Problem responses
TypedResults.Problem(detail, title, statusCode)    // RFC 7807 ProblemDetails
TypedResults.ValidationProblem(errors)             // RFC 7807 + errors dict

// Server error responses
TypedResults.InternalServerError(detail)      // 500 (.NET 9+)

// Content responses
TypedResults.Text("plain text")               // text/plain
TypedResults.Json(obj, options)               // application/json
TypedResults.File("path.pdf", "application/pdf")
TypedResults.Stream(stream, contentType)
TypedResults.Redirect("/new-url")
TypedResults.RedirectToRoute("routeName", routeValues)

// Server-Sent Events (.NET 9+)
TypedResults.ServerSentEvents(asyncEnumerable, eventType: "update")

// Status code
TypedResults.StatusCode(429)
```

### Unit Testing with TypedResults

The primary advantage of `TypedResults` is testability:

```csharp
[Fact]
public async Task GetTodo_Returns200_WhenFound()
{
    await using var db = new MockDb().CreateDbContext();
    db.Todos.Add(new Todo { Id = 1, Name = "Write tests" });
    await db.SaveChangesAsync();

    var result = await TodoEndpoints.GetTodo(1, db);

    // Direct type assertion — no casting needed
    Assert.IsType<Results<Ok<Todo>, NotFound>>(result);
    var okResult = (Ok<Todo>)result.Result;
    Assert.Equal("Write tests", okResult.Value?.Name);
}

[Fact]
public async Task GetTodo_Returns404_WhenMissing()
{
    await using var db = new MockDb().CreateDbContext();

    var result = await TodoEndpoints.GetTodo(999, db);

    Assert.IsType<Results<Ok<Todo>, NotFound>>(result);
    Assert.IsType<NotFound>(result.Result);
}
```

---

## 8. OpenAPI Integration

### .NET 6–8: Swashbuckle + WithOpenApi()

In .NET 6–8, OpenAPI relied on Swashbuckle (or NSwag) with `Microsoft.AspNetCore.OpenApi` providing the `WithOpenApi()` extension method:

```csharp
// Program.cs — .NET 6/7/8
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "My API", Version = "v1" });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.MapPost("/todos/{id}", async (int id, Todo todo, TodoDb db) =>
{
    // ...
    return Results.Created($"/todos/{id}", todo);
})
.WithOpenApi(op =>
{
    op.Parameters[0].Description = "The todo ID";
    op.Summary = "Create a todo item";
    op.Description = "Creates a new todo and persists it to the database";
    return op;
})
.WithTags("Todos")
.WithName("CreateTodo")
.Produces<Todo>(201)
.ProducesProblem(400)
.ProducesProblem(500);
```

### .NET 9+: Built-in OpenAPI (Microsoft.AspNetCore.OpenApi)

.NET 9 introduced **first-class OpenAPI document generation** without Swashbuckle:

```csharp
// NuGet: Microsoft.AspNetCore.OpenApi
builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi(); // serves at /openapi/v1.json
}

app.Run();
```

**Default endpoint:** `https://localhost:{port}/openapi/v1.json`

Interactive UI (Scalar or Swagger UI) must be added separately:

```csharp
// NuGet: Scalar.AspNetCore
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(); // UI at /scalar/v1
}
```

### OpenAPI Document Customization (.NET 9+)

```csharp
builder.Services.AddOpenApi("v1", options =>
{
    options.OpenApiVersion = OpenApiSpecVersion.OpenApi3_1; // default in .NET 10
    options.AddDocumentTransformer((document, context, ct) =>
    {
        document.Info.Title = "My API";
        document.Info.Version = "1.0.0";
        document.Info.Contact = new OpenApiContact
        {
            Name = "Support",
            Email = "support@example.com"
        };
        return Task.CompletedTask;
    });
});
```

### Multiple OpenAPI Documents

```csharp
builder.Services.AddOpenApi("public");
builder.Services.AddOpenApi("internal");

// Assign endpoints to documents
app.MapGet("/public/data", GetData)
   .WithGroupName("public");

app.MapGet("/internal/admin", GetAdminData)
   .WithGroupName("internal")
   .RequireAuthorization("Admin");
```

### Build-Time OpenAPI Generation (.NET 9+)

```bash
dotnet add package Microsoft.Extensions.ApiDescription.Server
dotnet build
# Outputs: obj/{ProjectName}.json
```

```xml
<PropertyGroup>
  <OpenApiDocumentsDirectory>./openapi</OpenApiDocumentsDirectory>
  <OpenApiGenerateDocumentsOptions>--document-name v1 --file-name api</OpenApiGenerateDocumentsOptions>
</PropertyGroup>
```

### Describing Endpoints

```csharp
app.MapGet("/todos/{id}", GetTodo)
   .WithSummary("Get a todo by ID")
   .WithDescription("Returns a single todo item. Returns 404 if not found.")
   .WithTags("Todos")
   .WithName("GetTodoById");

// Or with attributes on named methods
app.MapGet("/todos/{id}", GetTodo);

[EndpointSummary("Get a todo by ID")]
[EndpointDescription("Returns a single todo item. Returns 404 if not found.")]
static async Task<Results<Ok<Todo>, NotFound>> GetTodo(int id, TodoDb db)
    => await db.Todos.FindAsync(id) is Todo todo
        ? TypedResults.Ok(todo)
        : TypedResults.NotFound();
```

### XML Documentation Comments (.NET 10)

```xml
<!-- .csproj -->
<PropertyGroup>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
</PropertyGroup>
```

```csharp
app.MapGet("/greet", Hello);

/// <summary>Returns a greeting for the given name.</summary>
/// <param name="name">The person's name.</param>
/// <returns>A personalized greeting string.</returns>
static string Hello(string name) => $"Hello, {name}!";
```

### Response Type Metadata

```csharp
// With Results (manual annotation)
app.MapGet("/orders/{id}", GetOrder)
   .Produces<Order>(200)
   .Produces<ProblemDetails>(404)
   .Produces<ProblemDetails>(500);

// With TypedResults (automatic — preferred)
app.MapGet("/orders/{id}",
    async Task<Results<Ok<Order>, NotFound, InternalServerError>> (int id, OrderDb db) =>
    {
        // OpenAPI metadata inferred from return type signature
    });
```

### YAML Format (.NET 10)

```csharp
app.MapOpenApi("/openapi/{documentName}.yaml");
```

---

## 9. Organizing Minimal APIs at Scale

### Extension Method Pattern (Recommended First Step)

Group related endpoints into static extension methods on `IEndpointRouteBuilder` or `RouteGroupBuilder`:

```csharp
// TodoModule.cs
public static class TodoModule
{
    public static IEndpointRouteBuilder MapTodos(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/todos")
            .WithTags("Todos")
            .RequireAuthorization()
            .WithOpenApi();

        group.MapGet("/", GetAll);
        group.MapGet("/{id:int}", GetById);
        group.MapPost("/", Create);
        group.MapPut("/{id:int}", Update);
        group.MapDelete("/{id:int}", Delete);

        return app;
    }

    static async Task<Ok<List<Todo>>> GetAll(TodoDb db)
        => TypedResults.Ok(await db.Todos.ToListAsync());

    static async Task<Results<Ok<Todo>, NotFound>> GetById(int id, TodoDb db)
        => await db.Todos.FindAsync(id) is Todo todo
            ? TypedResults.Ok(todo)
            : TypedResults.NotFound();

    static async Task<Created<Todo>> Create(Todo todo, TodoDb db)
    {
        db.Todos.Add(todo);
        await db.SaveChangesAsync();
        return TypedResults.Created($"/todos/{todo.Id}", todo);
    }

    // Update and Delete...
}

// Program.cs
app.MapTodos();
app.MapOrders();
app.MapUsers();
```

### Vertical Slice Architecture

Organize by feature, not by layer:

```
Features/
  Todos/
    GetTodo.cs
    CreateTodo.cs
    UpdateTodo.cs
    DeleteTodo.cs
    TodoModule.cs
  Orders/
    GetOrder.cs
    CreateOrder.cs
    OrderModule.cs
```

Each feature handler is a self-contained class:

```csharp
// Features/Todos/CreateTodo.cs
public static class CreateTodo
{
    public record Request(string Name, DateOnly? DueDate);
    public record Response(int Id, string Name, DateOnly? DueDate);

    public static void Map(RouteGroupBuilder group)
    {
        group.MapPost("/", Handle)
             .WithSummary("Create a new todo")
             .AddEndpointFilter<FluentValidationFilter<Request>>();
    }

    static async Task<Created<Response>> Handle(
        Request request,
        TodoDb db,
        CancellationToken ct)
    {
        var todo = new Todo { Name = request.Name, DueDate = request.DueDate };
        db.Todos.Add(todo);
        await db.SaveChangesAsync(ct);
        return TypedResults.Created(
            $"/todos/{todo.Id}",
            new Response(todo.Id, todo.Name, todo.DueDate));
    }
}

// TodoModule.cs
public static class TodoModule
{
    public static IEndpointRouteBuilder MapTodos(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/todos").WithTags("Todos");
        CreateTodo.Map(group);
        GetTodo.Map(group);
        // ...
        return app;
    }
}
```

### Carter Library

Carter (NuGet: `Carter`) provides a structured module pattern reminiscent of NancyFX:

```csharp
// NuGet: Carter
// Program.cs
builder.Services.AddCarter();

var app = builder.Build();
app.MapCarter(); // discovers and registers all ICarterModule implementations
app.Run();

// TodoModule.cs
public class TodoModule : ICarterModule
{
    public void AddRoutes(IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/todos").WithTags("Todos");

        group.MapGet("/", GetAll);
        group.MapGet("/{id}", GetById);
        group.MapPost("/", Create);
    }

    private static async Task<IResult> GetAll(TodoDb db)
        => Results.Ok(await db.Todos.ToListAsync());

    private static async Task<IResult> GetById(int id, TodoDb db)
        => await db.Todos.FindAsync(id) is Todo todo
            ? Results.Ok(todo)
            : Results.NotFound();

    private static async Task<IResult> Create(Todo todo, TodoDb db)
    {
        db.Todos.Add(todo);
        await db.SaveChangesAsync();
        return Results.Created($"/todos/{todo.Id}", todo);
    }
}
```

Carter also provides:
- Auto-discovery of modules via assembly scanning
- `ICarterModule` interface for clear structure
- Request/response validation integration

### IEndpointRouteBuilder Interface Pattern

For library/framework code that must work with both Minimal APIs and can accept any route builder:

```csharp
public interface IApiModule
{
    static abstract void Map(IEndpointRouteBuilder app);
}

public class TodosModule : IApiModule
{
    public static void Map(IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/todos");
        group.MapGet("/", GetAll);
        // ...
    }
}

// Registration via reflection or source generator
// Program.cs
typeof(Program).Assembly
    .GetTypes()
    .Where(t => t.IsAssignableTo(typeof(IApiModule)) && !t.IsInterface)
    .ToList()
    .ForEach(module =>
    {
        var method = module.GetMethod("Map",
            BindingFlags.Static | BindingFlags.Public);
        method?.Invoke(null, [app]);
    });
```

---

## 10. When Controllers Win

Despite Microsoft recommending Minimal APIs for new projects, controllers still have genuine advantages in specific scenarios.

### Genuine Controller Advantages

| Scenario | Why Controllers Win |
|----------|---------------------|
| **Complex model binding** | `IModelBinderProvider` and `IModelBinder` provide recursive, extensible binding that `BindAsync`/`TryParse` can't match |
| **OData** | `Microsoft.AspNetCore.OData` only works with `ControllerBase`. No Minimal API equivalent. |
| **JsonPatch** | `Microsoft.AspNetCore.JsonPatch` integrates with MVC's `[HttpPatch]` + `ApplyTo()`. Minimal APIs require manual implementation. |
| **Action filters** | `IActionFilter`, `IResultFilter`, `IExceptionFilter` with full MVC pipeline access. Endpoint filters are a subset. |
| **Application parts** | Plugin/extensibility scenarios using `ApplicationPartManager` |
| **IModelValidator** | DataAnnotations server-side validation is deeply integrated in MVC |
| **API Versioning** | `Asp.Versioning.Mvc` has mature controller support; Minimal API versioning is less mature |
| **Large teams with MVC background** | Lower learning curve, established patterns |
| **Code generation tools** | Many scaffolders target controllers |

### API Versioning Note

`Asp.Versioning.Http` (the Minimal API versioning package) works but has limitations. As of .NET 10, versioning via URL segments, query strings, and headers is supported, but route groups make it manageable:

```csharp
// NuGet: Asp.Versioning.Http
builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),
        new HeaderApiVersionReader("X-Api-Version"));
});

var versionedApi = app.NewVersionedApi();

var v1 = versionedApi.MapGroup("/api/v{version:apiVersion}/todos")
    .HasApiVersion(1);

var v2 = versionedApi.MapGroup("/api/v{version:apiVersion}/todos")
    .HasApiVersion(2);

v1.MapGet("/", GetTodosV1);
v2.MapGet("/", GetTodosV2);
```

### Decision Framework

```
Starting a new project?
    → Use Minimal APIs

Need OData?
    → Controllers (no alternative)

Need JsonPatch?
    → Controllers (or build custom)

Large enterprise app, team knows MVC?
    → Either; controllers reduce learning curve

Performance is critical (e.g., high-throughput API)?
    → Minimal APIs (slightly less overhead, AOT support)

Need native AOT?
    → Minimal APIs (controllers do not support AOT)

Complex model binding with custom IModelBinder?
    → Controllers

Everything else?
    → Minimal APIs with MapGroup + extension methods
```

---

## 11. Version Evolution

### .NET 6 — Foundation

**What shipped:**
- `WebApplication.Create()` and `WebApplication.CreateBuilder()`
- `MapGet`, `MapPost`, `MapPut`, `MapDelete`, `MapMethods`
- `MapFallback`, `MapFallbackToFile`
- Automatic parameter binding (route, query, body, DI, special types)
- `IResult` interface and `Results` static class
- `WithName`, `WithMetadata`, `RequireAuthorization`, `RequireCors`, `AllowAnonymous`
- Initial `Microsoft.AspNetCore.OpenApi` package (Swashbuckle-based)
- `Produces<T>()`, `ProducesProblem()`, `WithTags()`

```csharp
// The canonical .NET 6 Minimal API
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDbContext<TodoDb>(opt => opt.UseInMemoryDatabase("todos"));
var app = builder.Build();

app.MapGet("/todos", async (TodoDb db) =>
    await db.Todos.ToListAsync());

app.MapGet("/todos/{id}", async (int id, TodoDb db) =>
    await db.Todos.FindAsync(id) is Todo todo
        ? Results.Ok(todo)
        : Results.NotFound());

app.MapPost("/todos", async (Todo todo, TodoDb db) =>
{
    db.Todos.Add(todo);
    await db.SaveChangesAsync();
    return Results.Created($"/todos/{todo.Id}", todo);
});

app.Run();
```

**Limitations in .NET 6:**
- No `MapGroup()` — prefix repetition required
- No endpoint filters — middleware or custom `RequestDelegate` wrappers needed
- `IResult` types were internal — hard to unit test
- No `TypedResults` — only `Results`
- No form binding with `[FromForm]`
- No `[AsParameters]`

---

### .NET 7 — Major Feature Release

**What shipped:**

**Endpoint Filters (`IEndpointFilter`)**
```csharp
app.MapGet("/", () => "Hello")
    .AddEndpointFilter(async (ctx, next) =>
    {
        // before
        var result = await next(ctx);
        // after
        return result;
    });
```

**Route Groups (`MapGroup`)**
```csharp
var todos = app.MapGroup("/todos").RequireAuthorization();
todos.MapGet("/", GetAll);
todos.MapPost("/", Create);
```

**TypedResults (public concrete types)**
```csharp
// Results<T1, T2> union type
app.MapGet("/todos/{id}",
    async Task<Results<Ok<Todo>, NotFound>> (int id, TodoDb db) =>
    await db.Todos.FindAsync(id) is Todo todo
        ? TypedResults.Ok(todo)
        : TypedResults.NotFound());
```

**[AsParameters]**
```csharp
app.MapGet("/todos/{id}", ([AsParameters] TodoRequest req) => ...);
struct TodoRequest { public int Id { get; set; } public TodoDb Db { get; set; } }
```

**IFormFile support**
```csharp
app.MapPost("/upload", async (IFormFile file) => { ... });
```

**Array binding from query/headers**
```csharp
app.MapGet("/filter", (int[] ids) => ...); // GET /filter?ids=1&ids=2
```

**WithOpenApi() enhancements, WithSummary(), WithDescription()**
```csharp
app.MapGet("/todos", GetTodos)
   .WithSummary("List all todos")
   .WithDescription("Returns a paginated list of all todo items.");
```

**Stream overloads for Results**
```csharp
Results.Stream(stream => ResizeImageAsync(stream), "image/jpeg")
```

---

### .NET 8 — AOT and Form Binding

**What shipped:**

**Request Delegate Generator (RDG) — compile-time delegate generation**
```xml
<EnableRequestDelegateGenerator>true</EnableRequestDelegateGenerator>
```

**Native AOT support**
```bash
dotnet new webapiaot   # new template
dotnet publish         # self-contained native binary
```

**CreateSlimBuilder and CreateEmptyBuilder**
```csharp
var builder = WebApplication.CreateSlimBuilder(args); // minimal feature set
var builder = WebApplication.CreateEmptyBuilder(new()); // absolutely empty
```

**Full form binding with [FromForm]**
```csharp
app.MapPost("/todos", ([FromForm] string name, [FromForm] bool done) => ...);
app.MapPost("/todos", ([AsParameters] NewTodoRequest req) => ...);
```

**Antiforgery middleware for Minimal APIs**
```csharp
builder.Services.AddAntiforgery();
app.UseAntiforgery();
```

**Keyed services ([FromKeyedServices])**
```csharp
app.MapGet("/", ([FromKeyedServices("myCache")] ICache cache) => cache.Get("key"));
```

**Complex and collection form binding**
```csharp
app.MapPost("/form", ([FromForm] ComplexModel model) => ...);
// Supports List<T>, Dictionary<K,V>, nested complex types
```

**JSON serialization for Native AOT**
```csharp
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.TypeInfoResolverChain.Insert(0, AppJsonSerializerContext.Default);
});

[JsonSerializable(typeof(Todo[]))]
internal partial class AppJsonSerializerContext : JsonSerializerContext { }
```

---

### .NET 9 — Built-in OpenAPI

**What shipped:**

**Built-in OpenAPI document generation (Microsoft.AspNetCore.OpenApi)**
```csharp
builder.Services.AddOpenApi();
app.MapOpenApi(); // /openapi/v1.json
```

**Build-time OpenAPI generation**
```bash
dotnet add package Microsoft.Extensions.ApiDescription.Server
dotnet build  # emits .json to output directory
```

**TypedResults.InternalServerError**
```csharp
app.MapGet("/", () => TypedResults.InternalServerError("Something went wrong!"));
```

**ProducesProblem / ProducesValidationProblem on route groups**
```csharp
var todos = app.MapGroup("/todos").ProducesProblem();
```

**Problem/ValidationProblem with IEnumerable**
```csharp
var extensions = new List<KeyValuePair<string, object?>> { new("traceId", Activity.Current?.Id) };
TypedResults.Problem("error message", extensions: extensions);
```

**AOT-compatible OpenAPI**
```bash
dotnet new webapiaot
dotnet add package Microsoft.AspNetCore.OpenApi
```

---

### .NET 10 — Validation, SSE, OpenAPI 3.1

**What shipped:**

**Built-in validation support**
```csharp
builder.Services.AddValidation();

// DataAnnotations validated automatically
app.MapPost("/products", (Product product) => TypedResults.Ok(product));

public record Product([Required] string Name, [Range(1, 100)] int Qty);
// Returns 400 ValidationProblem automatically if invalid
```

**Disable validation per endpoint**
```csharp
app.MapPost("/raw", (RawData data) => TypedResults.Ok(data))
   .DisableValidation();
```

**Empty string → null for nullable form fields**
```csharp
// Empty string in form post maps to null for nullable types
app.MapPost("/form", ([FromForm] DateOnly? dueDate) => ...);
```

**Server-Sent Events (TypedResults.ServerSentEvents)**
```csharp
app.MapGet("/heartrate", (CancellationToken ct) =>
{
    async IAsyncEnumerable<SseItem<int>> Stream(
        [EnumeratorCancellation] CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            yield return new SseItem<int>(Random.Shared.Next(60, 100), eventType: "heartRate");
            await Task.Delay(2000, token);
        }
    }
    return TypedResults.ServerSentEvents(Stream(ct));
});
```

**OpenAPI 3.1 as default**
```csharp
// Default is now OpenApi3_1
builder.Services.AddOpenApi(); // generates OAS 3.1
```

**OpenAPI in YAML format**
```csharp
app.MapOpenApi("/openapi/{documentName}.yaml");
```

**XML doc comments in OpenAPI**
```xml
<GenerateDocumentationFile>true</GenerateDocumentationFile>
```

**Validation APIs in Microsoft.Extensions.Validation**
```csharp
// Usable outside ASP.NET Core HTTP scenarios
using Microsoft.Extensions.Validation;
```

**IProblemDetailsService customization for validation errors**
```csharp
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = context =>
    {
        if (context.ProblemDetails.Status == 400)
        {
            context.ProblemDetails.Extensions["support"] = "support@example.com";
        }
    };
});
```

---

## Summary: Version-by-Version Feature Matrix

| Feature | .NET 6 | .NET 7 | .NET 8 | .NET 9 | .NET 10 |
|---------|--------|--------|--------|--------|---------|
| MapGet/Post/Put/Delete | ✓ | ✓ | ✓ | ✓ | ✓ |
| IResult / Results | ✓ | ✓ | ✓ | ✓ | ✓ |
| TypedResults (public) | — | ✓ | ✓ | ✓ | ✓ |
| Results<T1,T2> unions | — | ✓ | ✓ | ✓ | ✓ |
| MapGroup | — | ✓ | ✓ | ✓ | ✓ |
| IEndpointFilter | — | ✓ | ✓ | ✓ | ✓ |
| [AsParameters] | — | ✓ | ✓ | ✓ | ✓ |
| IFormFile binding | — | ✓ | ✓ | ✓ | ✓ |
| [FromForm] binding | — | — | ✓ | ✓ | ✓ |
| Complex form binding | — | — | ✓ | ✓ | ✓ |
| Antiforgery middleware | — | — | ✓ | ✓ | ✓ |
| Keyed DI ([FromKeyedServices]) | — | — | ✓ | ✓ | ✓ |
| Native AOT support | — | — | ✓ | ✓ | ✓ |
| Request Delegate Generator | — | — | ✓ | ✓ | ✓ |
| Built-in OpenAPI (AddOpenApi) | — | — | — | ✓ | ✓ |
| Build-time OpenAPI | — | — | — | ✓ | ✓ |
| TypedResults.InternalServerError | — | — | — | ✓ | ✓ |
| ProducesProblem on groups | — | — | — | ✓ | ✓ |
| Built-in validation (AddValidation) | — | — | — | — | ✓ |
| Server-Sent Events (SSE) | — | — | — | — | ✓ |
| OpenAPI 3.1 default | — | — | — | — | ✓ |
| OpenAPI YAML format | — | — | — | — | ✓ |
| XML doc comments in OpenAPI | — | — | — | — | ✓ |

---

## Key References

- [Minimal APIs overview](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/overview)
- [Parameter binding](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/parameter-binding)
- [Responses](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/responses)
- [Filters](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/min-api-filters)
- [OpenAPI document generation](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/aspnetcore-openapi)
- [Carter library](https://github.com/CarterCommunity/Carter)
- [MiniValidation](https://github.com/DamianEdwards/MiniValidation)
