# Minimal API Architecture Internals

## RequestDelegateFactory (RDF)

When you call `MapGet("/path", myHandler)`, ASP.NET Core uses `RequestDelegateFactory` to analyze the handler's parameter list and emit a `RequestDelegate` -- a `Func<HttpContext, Task>` -- at startup.

For each parameter, the factory decides the binding source (route, query, body, services, etc.) and generates the appropriate binding code.

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

### Binding Source Resolution

The factory uses these rules in order:

1. If the parameter name matches a route template token -> route value
2. If the type is a registered DI service -> service injection
3. If the type is a special framework type (`HttpContext`, `CancellationToken`, `ClaimsPrincipal`) -> framework injection
4. If the type is `IFormFile` or `IFormFileCollection` -> form binding
5. If the type is `Stream` or `PipeReader` -> body (raw)
6. If the type is a simple type (int, string, enum, etc.) -> query string
7. If the type is a complex type (class, record) -> body JSON

### Response Handling

The factory also generates response code based on the handler's return type:

- `string` -> writes as `text/plain` with 200
- `T` (any type) -> JSON-serializes with 200
- `IResult` -> calls `IResult.ExecuteAsync(HttpContext)`
- `Task<T>` / `ValueTask<T>` -> awaits, then applies the above rules

---

## Request Delegate Generator (RDG) -- .NET 8+

In .NET 8, the **Request Delegate Generator** replaced runtime reflection with a Roslyn source generator that emits the delegate code at **compile time** using C# 12 interceptors.

### How RDG Works

1. At compile time, the RDG source generator scans `MapGet`, `MapPost`, etc. calls
2. For each endpoint, it generates a static method that creates the `RequestDelegate`
3. The generated method uses C# 12 interceptors to replace the runtime RDF call
4. The generated code performs parameter binding, service resolution, and response writing

### Enabling RDG

```xml
<!-- Explicit opt-in -->
<PropertyGroup>
    <EnableRequestDelegateGenerator>true</EnableRequestDelegateGenerator>
</PropertyGroup>

<!-- Automatic with Native AOT -->
<PropertyGroup>
    <PublishAot>true</PublishAot>
    <!-- RDG is enabled implicitly -->
</PropertyGroup>
```

### Benefits

- **Native AOT compatibility:** No runtime code generation or reflection
- **Faster startup:** No reflection-based analysis at startup
- **Compile-time warnings:** Binding issues caught during build
- **Inspectable:** Generated source can be viewed

### Inspecting Generated Code

```xml
<PropertyGroup>
    <EmitCompilerGeneratedFiles>true</EmitCompilerGeneratedFiles>
</PropertyGroup>
```

Generated files appear in `obj/Debug/net10.0/generated/Microsoft.AspNetCore.Http.RequestDelegateGenerator/`.

### RDG Limitations

- Handlers must be accessible to the source generator (no dynamic assembly loading)
- Some complex binding scenarios may not be supported
- Libraries using runtime reflection for binding are incompatible with AOT

---

## Pipeline Comparison: Minimal APIs vs Controllers

### Minimal API Pipeline

```
HTTP Request
    -> Kestrel
    -> Middleware pipeline (UseExceptionHandler, UseRouting, etc.)
    -> EndpointMiddleware
    -> Endpoint Filters (IEndpointFilter) -- .NET 7+
    -> RequestDelegate (your handler)
    -> Response
```

### Controller Pipeline

```
HTTP Request
    -> Kestrel
    -> Middleware pipeline (UseExceptionHandler, UseRouting, etc.)
    -> EndpointMiddleware
    -> MVC Middleware (ControllerActionInvoker)
    -> Authorization Filters
    -> Resource Filters
    -> Model Binding
    -> Action Filters
    -> Action Method
    -> Result Filters
    -> Response
```

### Key Differences

| Aspect | Minimal APIs | Controllers |
|---|---|---|
| Factory | `RequestDelegateFactory` / RDG | `IControllerFactory` |
| Binding | Simple inference + `TryParse`/`BindAsync` | Full `IModelBinder` pipeline |
| Filters | `IEndpointFilter` only | Auth, Resource, Action, Exception, Result |
| Model state | No `ModelState` | Full `ModelState` |
| Result | `IResult` / `TypedResults` | `IActionResult` |
| AOT | Supported (with RDG) | Not supported |
| Overhead | Lower (fewer layers) | Higher (more framework services) |

---

## Endpoint Metadata System

Minimal APIs use the endpoint metadata system extensively. Metadata is attached to endpoints and consumed by middleware.

```csharp
// These extension methods add metadata to the endpoint
app.MapGet("/data", GetData)
    .WithName("GetData")                    // IEndpointNameMetadata
    .WithTags("Data")                       // ITagsMetadata
    .WithSummary("Gets data")              // IEndpointSummaryMetadata
    .WithDescription("Detailed desc")       // IEndpointDescriptionMetadata
    .RequireAuthorization("Admin")          // IAuthorizeData
    .RequireCors("MyPolicy")               // ICorsMetadata
    .Produces<DataResponse>(200)           // IProducesResponseTypeMetadata
    .ProducesProblem(404)                  // IProducesResponseTypeMetadata
    .CacheOutput("Short")                  // OutputCacheAttribute
    .WithRequestTimeout("Fast");           // RequestTimeoutAttribute
```

Middleware can inspect this metadata via `HttpContext.GetEndpoint()?.Metadata`:

```csharp
app.Use(async (context, next) =>
{
    var endpoint = context.GetEndpoint();
    var tags = endpoint?.Metadata.GetOrderedMetadata<ITagsMetadata>();
    var requiresAuth = endpoint?.Metadata.GetMetadata<IAuthorizeData>() != null;
    await next();
});
```

---

## Endpoint Filter Pipeline (.NET 7+)

### Filter Interface

```csharp
public interface IEndpointFilter
{
    ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next);
}
```

`EndpointFilterInvocationContext` exposes:
- `HttpContext` -- the current HTTP context
- `Arguments` -- the handler's arguments in declaration order
- `GetArgument<T>(int index)` -- type-safe argument access

### Filter Execution Model

Multiple filters execute in **FIFO order before** the handler and **FILO order after**:

```
Filter 1 before -> Filter 2 before -> Filter 3 before
    -> [handler] ->
Filter 3 after -> Filter 2 after -> Filter 1 after
```

### Filter Factory

`AddEndpointFilterFactory` runs at app startup for compile-time inspection:

```csharp
app.MapPut("/todos/{id}", UpdateTodo)
    .AddEndpointFilterFactory((factoryCtx, next) =>
    {
        var parameters = factoryCtx.MethodInfo.GetParameters();
        var todoIndex = Array.FindIndex(parameters, p => p.ParameterType == typeof(Todo));

        if (todoIndex < 0)
            return invocationCtx => next(invocationCtx);

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

### Group Filter Ordering

Filters on outer groups run before inner groups, regardless of registration order:

```csharp
var outer = app.MapGroup("/outer");
var inner = outer.MapGroup("/inner");

// Inner registered first, but outer executes first
inner.AddEndpointFilter(/* inner filter */);
outer.AddEndpointFilter(/* outer filter */);

// Execution: outer -> inner -> handler -> inner -> outer
```

---

## Version Evolution

### .NET 6 -- Foundation

- `WebApplication.CreateBuilder()`, `MapGet/Post/Put/Delete`
- Automatic parameter binding, `IResult`, `Results` static class
- `WithName`, `RequireAuthorization`, `AllowAnonymous`, `Produces<T>()`, `WithTags()`
- **Missing:** No `MapGroup`, no endpoint filters, no `TypedResults`, no `[FromForm]`, no `[AsParameters]`

### .NET 7 -- Major Feature Release

- **`MapGroup()`** -- route groups with shared prefix, auth, metadata
- **`IEndpointFilter`** -- endpoint filter pipeline
- **`TypedResults`** -- public concrete result types for OpenAPI and testing
- **`Results<T1, T2>`** -- union types for multiple return types
- **`[AsParameters]`** -- parameter grouping
- **`IFormFile`** support, array binding from query/headers
- **`WithSummary()`, `WithDescription()`**

### .NET 8 -- AOT and Form Binding

- **Request Delegate Generator (RDG)** -- compile-time delegate generation
- **Native AOT support** via `dotnet new webapiaot`
- **`CreateSlimBuilder`** and `CreateEmptyBuilder`
- **`[FromForm]`** with complex type and collection support
- **`[FromKeyedServices]`** -- keyed DI in handlers
- **Antiforgery middleware** integration
- **JSON source generation** for AOT

### .NET 9 -- Built-in OpenAPI

- **`AddOpenApi()` / `MapOpenApi()`** -- first-class OpenAPI without Swashbuckle
- **Build-time OpenAPI generation**
- **`TypedResults.InternalServerError()`**
- **`ProducesProblem()` / `ProducesValidationProblem()` on route groups**
- **Improved Roslyn analyzers** for routes and OpenAPI

### .NET 10 -- Validation, SSE, OpenAPI 3.1

- **`AddValidation()`** -- built-in DataAnnotations validation
- **`TypedResults.ServerSentEvents()`** -- SSE support
- **OpenAPI 3.1 default** with YAML output
- **XML doc comments in OpenAPI** via source generator
- **Empty string -> null** for nullable form values
- **`DisableValidation()`** per-endpoint opt-out

---

## CreateSlimBuilder vs CreateBuilder vs CreateEmptyBuilder

| Feature | `CreateBuilder` | `CreateSlimBuilder` | `CreateEmptyBuilder` |
|---|---|---|---|
| Hosting startup assemblies | Yes | No | No |
| All logging providers | Yes | Console only | None |
| `UseStaticWebAssets` | Yes | No | No |
| IIS integration | Yes | No | No |
| HTTPS / HTTP/3 | Yes | No | No |
| Regex/alpha constraints | Yes | No | No |
| Configuration sources | All defaults | All defaults | None |
| DI container | Full | Full | Empty |
| Use case | Standard apps | AOT / microservices | Maximum control |

```csharp
var builder = WebApplication.CreateSlimBuilder(args);

// Re-add features if needed:
builder.WebHost.UseKestrelHttpsConfiguration();  // HTTPS
builder.WebHost.UseQuic();                       // HTTP/3
```
