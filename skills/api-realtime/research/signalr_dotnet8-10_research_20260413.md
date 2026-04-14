# ASP.NET Core SignalR Research: .NET 8–10
**Research date:** 2026-04-13  
**Versions covered:** .NET 8, .NET 9, .NET 10 (preview)  
**Sources:** Microsoft Learn, GitHub dotnet/aspnetcore, ABP Community, community articles

---

## 1. Architecture Overview

### 1.1 Hub Model

SignalR uses *hubs* as the central abstraction for real-time communication. A hub is a high-level pipeline that allows clients and servers to call methods on each other. The server defines methods callable by clients and vice versa. SignalR handles all cross-machine dispatching automatically.

**Two-layer architecture:**

1. **Connection Layer** — managed by `HttpConnectionDispatcher`. Handles incoming HTTP requests, transport protocol selection, and low-level connection lifecycle. Selects transport based on HTTP request characteristics, configured allowed transports (`HttpConnectionDispatcherOptions`), and negotiated client capabilities.

2. **Hub Layer** — the programming model. Routes method calls to hub instances, manages group/user mappings, and dispatches responses.

**Hub registration (Program.cs):**
```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSignalR();

var app = builder.Build();
app.MapHub<ChatHub>("/chathub");
app.Run();
```

**Key characteristic — hubs are transient:**
- Do NOT store state in hub class properties. Each hub method call executes on a new hub instance.
- Do NOT instantiate a hub directly via DI. Use `IHubContext<T>` to send messages from outside a hub.
- Always `await` async calls that depend on the hub staying alive.

### 1.2 Transport Negotiation

SignalR negotiates the best available transport in this priority order:

1. **WebSockets** — full-duplex, lowest overhead, preferred
2. **Server-Sent Events (SSE)** — server-to-client only, HTTP/1.1 streaming
3. **Long Polling** — simulates real-time through repeated HTTP requests, maximum compatibility

The `/negotiate` endpoint is hit first. The client sends a negotiation request, the server responds with available transports and a connection token. The client then connects using the best mutually-supported transport.

**Skip negotiation (WebSockets only, significant performance gain):**
```csharp
// .NET client
var connection = new HubConnectionBuilder()
    .WithUrl("https://example.com/chathub", options =>
    {
        options.SkipNegotiation = true;
        options.Transports = HttpTransportType.WebSockets;
    })
    .Build();
```

**Restrict transports server-side:**
```csharp
app.MapHub<ChatHub>("/chathub", options =>
{
    options.Transports =
        HttpTransportType.WebSockets |
        HttpTransportType.LongPolling;
});
```

### 1.3 Hub Protocols: JSON vs MessagePack

SignalR ships with two built-in hub protocols:

| Protocol | Format | Package | Notes |
|----------|--------|---------|-------|
| JSON | Text | Built-in | Default, human-readable |
| MessagePack | Binary | `Microsoft.AspNetCore.SignalR.Protocols.MessagePack` | ~30-40% smaller payloads, faster parse |

**MessagePack setup:**
```csharp
// Server
builder.Services.AddSignalR()
    .AddMessagePackProtocol();

// JavaScript client
import { MessagePackHubProtocol } from "@microsoft/signalr-protocol-msgpack";

const connection = new signalR.HubConnectionBuilder()
    .withUrl("/chathub")
    .withHubProtocol(new MessagePackHubProtocol())
    .build();
```

**JSON customization:**
```csharp
builder.Services.AddSignalR()
    .AddJsonProtocol(options => {
        options.PayloadSerializerOptions.PropertyNamingPolicy = null; // PascalCase
    });
```

Older browsers must support XHR level 2 to use MessagePack.

### 1.4 Connection Lifecycle

1. Client calls `/negotiate` — server returns connection token + available transports
2. Client connects via best transport (WebSocket upgrade or HTTP request)
3. Initial handshake — protocol negotiation (JSON/MessagePack), handshake timeout 15s default
4. `OnConnectedAsync` fires on hub
5. Bidirectional communication active
6. On disconnect: `OnDisconnectedAsync` fires with optional exception parameter
7. Groups are automatically cleaned up on disconnect

**Lifecycle methods:**
```csharp
public class ChatHub : Hub
{
    public override async Task OnConnectedAsync()
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, "general");
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        // exception is null for intentional disconnects
        // exception contains error info for network failures
        await base.OnDisconnectedAsync(exception);
    }
}
```

Note: `RemoveFromGroupAsync` does NOT need to be called in `OnDisconnectedAsync` — groups are cleaned up automatically.

---

## 2. Hub Features

### 2.1 Hub Methods and Client Targeting

The `Clients` property provides targeting options:

| Target | Description |
|--------|-------------|
| `Clients.All` | All connected clients |
| `Clients.Caller` | Only the calling client |
| `Clients.Others` | All clients except caller |
| `Clients.Client(id)` | Specific connection ID |
| `Clients.Clients(ids)` | Multiple specific connection IDs |
| `Clients.Group(name)` | All connections in a group |
| `Clients.Groups(names)` | Multiple groups |
| `Clients.GroupExcept(name, ids)` | Group minus specific connections |
| `Clients.OthersInGroup(name)` | Group minus caller |
| `Clients.User(userId)` | All connections for a user |
| `Clients.Users(userIds)` | Multiple users |
| `Clients.AllExcept(ids)` | All minus specific connections |

```csharp
public class ChatHub : Hub
{
    public async Task SendMessage(string user, string message)
        => await Clients.All.SendAsync("ReceiveMessage", user, message);

    public async Task SendMessageToCaller(string user, string message)
        => await Clients.Caller.SendAsync("ReceiveMessage", user, message);

    public async Task SendMessageToGroup(string user, string message)
        => await Clients.Group("SignalR Users").SendAsync("ReceiveMessage", user, message);
}
```

**`[HubMethodName]` attribute — rename exposed method:**
```csharp
[HubMethodName("SendMessageToUser")]
public async Task DirectMessage(string user, string message)
    => await Clients.User(user).SendAsync("ReceiveMessage", user, message);
```

### 2.2 Strongly Typed Hubs

Using `Hub<T>` provides compile-time checking of client method calls, eliminating string-based method names.

**Define the client interface:**
```csharp
public interface IChatClient
{
    Task ReceiveMessage(string user, string message);
    Task UserConnected(string userId);
}
```

**Implement the strongly-typed hub:**
```csharp
public class StronglyTypedChatHub : Hub<IChatClient>
{
    public async Task SendMessage(string user, string message)
        => await Clients.All.ReceiveMessage(user, message);

    public async Task SendToGroup(string groupName, string user, string message)
        => await Clients.Group(groupName).ReceiveMessage(user, message);
}
```

**Limitations:**
- Using `Hub<T>` disables `SendAsync` (string-based)
- The `Async` suffix is NOT stripped from method names automatically. If the interface defines `ReceiveMessageAsync`, the client must use `.on('ReceiveMessageAsync')`, not `.on('ReceiveMessage')`
- Strongly typed hubs are NOT compatible with Native AOT (.NET 9+)

### 2.3 Client Results (Server-to-Client Invocations with Return Values)

The server can request a result from a specific client using `InvokeAsync`:

```csharp
public class ChatHub : Hub
{
    public async Task<string> WaitForMessage(string connectionId)
    {
        var message = await Clients.Client(connectionId).InvokeAsync<string>(
            "GetMessage", CancellationToken.None);
        return message;
    }
}
```

**Client-side handler (.NET):**
```csharp
hubConnection.On("GetMessage", async () =>
{
    Console.WriteLine("Enter message:");
    var message = await Console.In.ReadLineAsync();
    return message;
});
```

**Client-side handler (TypeScript):**
```typescript
hubConnection.on("GetMessage", async () => {
    return new Promise<string>((resolve) => {
        setTimeout(() => resolve("message"), 100);
    });
});
```

**Strongly-typed hub with return value:**
```csharp
public interface IClient
{
    Task<string> GetMessage();
}

public class ChatHub : Hub<IClient>
{
    public async Task<string> WaitForMessage(string connectionId)
    {
        string message = await Clients.Client(connectionId).GetMessage();
        return message;
    }
}
```

### 2.4 Dependency Injection in Hubs

Hub constructors and hub methods both support DI:

```csharp
// Constructor injection
public class ChatHub : Hub
{
    private readonly ILogger<ChatHub> _logger;
    
    public ChatHub(ILogger<ChatHub> logger)
    {
        _logger = logger;
    }
}

// Method-level injection (implicit by default in .NET 7+)
public class ChatHub : Hub
{
    public Task SendMessage(string user, string message, IDatabaseService dbService)
    {
        var userName = dbService.GetUserName(user);
        return Clients.All.SendAsync("ReceiveMessage", userName, message);
    }
}

// Keyed services (.NET 8+)
public class MyHub : Hub
{
    public void SmallCacheMethod([FromKeyedServices("small")] ICache cache)
    {
        Console.WriteLine(cache.Get("signalr"));
    }
}
```

**Disable implicit DI resolution:**
```csharp
builder.Services.AddSignalR(options =>
{
    options.DisableImplicitFromServicesParameters = true;
});
// Now use [FromServices] explicitly
```

### 2.5 IHubContext — Sending Messages from Outside Hubs

Use `IHubContext<T>` to push messages from background services, controllers, middleware, etc.:

```csharp
public class NotificationService : BackgroundService
{
    private readonly IHubContext<ChatHub> _hubContext;

    public NotificationService(IHubContext<ChatHub> hubContext)
    {
        _hubContext = hubContext;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await _hubContext.Clients.All.SendAsync("Notification", "Heartbeat", stoppingToken);
            await Task.Delay(5000, stoppingToken);
        }
    }
}
```

For strongly-typed hubs, use `IHubContext<THub, TClient>`.

### 2.6 Group Management

Groups are named collections of connections. Groups persist only while connections are active — they do not survive reconnects.

```csharp
public class ChatHub : Hub
{
    public async Task JoinRoom(string roomName)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, roomName);
        await Clients.Group(roomName).SendAsync("UserJoined", Context.UserIdentifier);
    }

    public async Task LeaveRoom(string roomName)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, roomName);
        await Clients.Group(roomName).SendAsync("UserLeft", Context.UserIdentifier);
    }
}
```

**Group management patterns:**
- Groups do NOT persist across connection IDs. When a client reconnects, its new connection ID must be re-added to groups.
- Consider maintaining group membership in a persistent store (Redis, database) and re-joining groups in `OnConnectedAsync`.
- Groups are local to the server instance unless using Azure SignalR Service or Redis backplane.

### 2.7 Error Handling

**Default behavior:** Hub exceptions return a generic error to the client to avoid leaking sensitive information:
```
Microsoft.AspNetCore.SignalR.HubException: An unexpected error occurred invoking 'SendMessage' on the server.
```

**To send error details to the client, throw `HubException`:**
```csharp
public Task ThrowException()
    => throw new HubException("This error will be sent to the client!");
```

**Enable detailed errors (development only):**
```csharp
builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = true; // Never enable in production!
});
```

**Client-side error handling (JavaScript):**
```javascript
try {
    await connection.invoke("SendMessage", user, message);
} catch (err) {
    console.error(err);
}
```

Connections are NOT closed when a hub throws an exception. Only `HubException.Message` is sent to the client — stack trace and other properties are not available.

### 2.8 Hub Filters (IHubFilter)

Hub filters allow pre/post logic around hub method invocations, similar to middleware. Available since .NET 5.

**Implementing a filter:**
```csharp
public class LoggingHubFilter : IHubFilter
{
    private readonly ILogger<LoggingHubFilter> _logger;
    
    public LoggingHubFilter(ILogger<LoggingHubFilter> logger)
    {
        _logger = logger;
    }

    public async ValueTask<object?> InvokeMethodAsync(
        HubInvocationContext invocationContext, 
        Func<HubInvocationContext, ValueTask<object?>> next)
    {
        _logger.LogInformation("Calling hub method '{Method}'", 
            invocationContext.HubMethodName);
        try
        {
            return await next(invocationContext);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception in hub method '{Method}'", 
                invocationContext.HubMethodName);
            throw;
        }
    }

    // Optional: wrap OnConnectedAsync
    public Task OnConnectedAsync(HubLifetimeContext context, 
        Func<HubLifetimeContext, Task> next)
        => next(context);

    // Optional: wrap OnDisconnectedAsync
    public Task OnDisconnectedAsync(HubLifetimeContext context, Exception? exception, 
        Func<HubLifetimeContext, Exception?, Task> next)
        => next(context, exception);
}
```

**Registration:**
```csharp
// Global filter
builder.Services.AddSignalR(options =>
{
    options.AddFilter<LoggingHubFilter>();
});

// Per-hub filter
builder.Services.AddSignalR()
    .AddHubOptions<ChatHub>(options =>
    {
        options.AddFilter<ChatSpecificFilter>();
    });

// Register as singleton for performance (avoids re-instantiation)
builder.Services.AddSingleton<LoggingHubFilter>();
```

**Filter ordering:** Global filters run before per-hub filters. Authorize attributes run before hub filters.

**HubInvocationContext properties:**
- `Context` — `HubCallerContext` (connection info)
- `Hub` — the hub instance
- `HubMethodName` — string method name
- `HubMethodArguments` — `IReadOnlyList<string>`
- `ServiceProvider` — scoped DI provider
- `HubMethod` — `MethodInfo`

**To skip a hub method:** Throw `HubException` instead of calling `next`.

---

## 3. Streaming

### 3.1 Server-to-Client Streaming

A hub method becomes a streaming method by returning `IAsyncEnumerable<T>` or `ChannelReader<T>`.

**IAsyncEnumerable approach (preferred, C# 8+):**
```csharp
public async IAsyncEnumerable<int> Counter(
    int count,
    int delay,
    [EnumeratorCancellation] CancellationToken cancellationToken)
{
    for (var i = 0; i < count; i++)
    {
        cancellationToken.ThrowIfCancellationRequested();
        yield return i;
        await Task.Delay(delay, cancellationToken);
    }
}
```

**ChannelReader approach:**
```csharp
public ChannelReader<int> Counter(int count, int delay, CancellationToken cancellationToken)
{
    var channel = Channel.CreateUnbounded<int>();
    // Return the reader immediately; write on background thread
    _ = WriteItemsAsync(channel.Writer, count, delay, cancellationToken);
    return channel.Reader;
}

private async Task WriteItemsAsync(ChannelWriter<int> writer, int count, int delay,
    CancellationToken cancellationToken)
{
    Exception? localException = null;
    try
    {
        for (var i = 0; i < count; i++)
        {
            await writer.WriteAsync(i, cancellationToken);
            await Task.Delay(delay, cancellationToken);
        }
    }
    catch (Exception ex)
    {
        localException = ex;
    }
    finally
    {
        writer.Complete(localException);
    }
}
```

**Important:** Write to `ChannelWriter<T>` on a background thread and return `ChannelReader` immediately. Other hub invocations are blocked until `ChannelReader` is returned. Always complete the channel in a `finally` block.

### 3.2 Client-to-Server Streaming

Accept `IAsyncEnumerable<T>` or `ChannelReader<T>` as hub method parameters:

```csharp
// IAsyncEnumerable version
public async Task UploadStream(IAsyncEnumerable<string> stream)
{
    await foreach (var item in stream)
    {
        Console.WriteLine(item);
    }
}

// ChannelReader version
public async Task UploadStreamChannel(ChannelReader<string> stream)
{
    while (await stream.WaitToReadAsync())
    {
        while (stream.TryRead(out var item))
        {
            Console.WriteLine(item);
        }
    }
}
```

### 3.3 JavaScript Client Streaming

**Server-to-client:**
```javascript
// Stream method returns IStreamResult
const subscription = connection.stream("Counter", 10, 500)
    .subscribe({
        next: (item) => console.log(`Received: ${item}`),
        complete: () => console.log("Stream completed"),
        error: (err) => console.error(err)
    });

// Cancel the stream
subscription.dispose();
```

**Client-to-server:**
```javascript
const subject = new signalR.Subject();
connection.send("UploadStream", subject);

let iteration = 0;
const handle = setInterval(() => {
    iteration++;
    subject.next(iteration.toString());
    if (iteration === 10) {
        clearInterval(handle);
        subject.complete();
    }
}, 500);
```

### 3.4 .NET Client Streaming

**Server-to-client:**
```csharp
// IAsyncEnumerable<T> approach
var cts = new CancellationTokenSource();
await foreach (var count in hubConnection.StreamAsync<int>("Counter", 10, 500, cts.Token))
{
    Console.WriteLine(count);
}

// ChannelReader<T> approach
var channel = await hubConnection.StreamAsChannelAsync<int>("Counter", 10, 500);
while (await channel.WaitToReadAsync())
{
    while (channel.TryRead(out var count))
        Console.WriteLine(count);
}
```

**Client-to-server:**
```csharp
// IAsyncEnumerable
async IAsyncEnumerable<string> ClientStreamData()
{
    for (var i = 0; i < 5; i++)
    {
        yield return await FetchSomeData();
    }
}
await connection.SendAsync("UploadStream", ClientStreamData());

// ChannelWriter
var channel = Channel.CreateBounded<string>(10);
await connection.SendAsync("UploadStream", channel.Reader);
await channel.Writer.WriteAsync("item 1");
await channel.Writer.WriteAsync("item 2");
channel.Writer.Complete();
```

---

## 4. Authentication and Authorization

### 4.1 JWT Bearer Token Authentication

The recommended approach for non-browser clients. Browser clients must pass the token via query string for WebSockets and SSE due to browser API limitations.

**Server configuration:**
```csharp
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
}).AddJwtBearer(options =>
{
    options.Authority = "https://your-authority.com";
    
    // Required: read token from query string for WebSocket/SSE
    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        }
    };
});

builder.Services.AddSignalR();
```

**JavaScript client:**
```typescript
const connection = new signalR.HubConnectionBuilder()
    .withUrl("/hubs/chat", { 
        accessTokenFactory: () => this.loginToken 
    })
    .build();
```

**Note on token expiry:** If a token expires during the connection lifetime, the connection continues to work for WebSockets. LongPolling and SSE connections fail on subsequent requests if the token is not refreshed. Use `CloseOnAuthenticationExpiration: true` to close connections on expiry.

**Warning:** Query string tokens appear in server logs. Restrict this code path to SignalR hub routes only.

### 4.2 Cookie Authentication

For browser-only apps, cookie auth flows automatically to SignalR connections:
```csharp
// No additional config needed — cookies flow automatically
// Just ensure authentication middleware is set up
app.UseAuthentication();
app.UseAuthorization();
```

### 4.3 Hub Authorization

```csharp
// Require authentication for all hub methods
[Authorize]
public class ChatHub : Hub { }

// Require specific policy
[Authorize("AdminOnly")]
public class AdminHub : Hub { }

// Method-level authorization
[Authorize]
public class ChatHub : Hub
{
    public async Task Send(string message) { /* anyone authenticated */ }

    [Authorize("Administrators")]
    public void BanUser(string userName) { /* admins only */ }
}
```

**Custom authorization with HubInvocationContext:**
```csharp
public class DomainRestrictedRequirement :
    AuthorizationHandler<DomainRestrictedRequirement, HubInvocationContext>,
    IAuthorizationRequirement
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        DomainRestrictedRequirement requirement,
        HubInvocationContext resource)
    {
        if (context.User.Identity?.Name?.EndsWith("@company.com") == true &&
            IsAllowed(resource.HubMethodName, context.User.Identity.Name))
        {
            context.Succeed(requirement);
        }
        return Task.CompletedTask;
    }
}

// Register in Program.cs
services.AddAuthorization(options =>
{
    options.AddPolicy("DomainRestricted", policy =>
        policy.Requirements.Add(new DomainRestrictedRequirement()));
});
```

### 4.4 Custom User ID Provider

By default, SignalR uses `ClaimTypes.NameIdentifier` as the user ID. Override with `IUserIdProvider`:

```csharp
public class EmailBasedUserIdProvider : IUserIdProvider
{
    public string GetUserId(HubConnectionContext connection)
        => connection.User?.FindFirst(ClaimTypes.Email)?.Value!;
}

// Registration
builder.Services.AddSingleton<IUserIdProvider, EmailBasedUserIdProvider>();
```

**Windows authentication:**
```csharp
public class NameUserIdProvider : IUserIdProvider
{
    public string GetUserId(HubConnectionContext connection)
        => connection.User?.Identity?.Name; // Format: DOMAIN\Username
}
```

### 4.5 Multiple Authentication Schemes

```csharp
// Support both JWT and cookie auth on a hub
[Authorize(AuthenticationSchemes = "Bearer, Identity.Application")]
public class ChatHub : Hub { }
```

---

## 5. Client SDKs

### 5.1 JavaScript/TypeScript Client

**Package:** `@microsoft/signalr`

**Connection setup with automatic reconnect:**
```typescript
import * as signalR from "@microsoft/signalr";

const connection = new signalR.HubConnectionBuilder()
    .withUrl("/chathub", {
        accessTokenFactory: () => getToken(),
        transport: signalR.HttpTransportType.WebSockets,
        headers: { "X-Custom-Header": "value" },
        withCredentials: true
    })
    .configureLogging(signalR.LogLevel.Information)
    .withAutomaticReconnect([0, 2000, 10000, 30000]) // retry delays in ms
    .build();

// Start connection
await connection.start();

// Handle reconnection events
connection.onreconnecting((error) => {
    console.warn("Connection lost, reconnecting...", error);
    // Update UI to show disconnected state
});

connection.onreconnected((connectionId) => {
    console.log("Reconnected:", connectionId);
    // Re-join groups, refresh state
});

connection.onclose((error) => {
    console.error("Connection closed permanently", error);
    // Handle permanent disconnection
});
```

**Custom retry policy:**
```typescript
.withAutomaticReconnect({
    nextRetryDelayInMilliseconds: retryContext => {
        if (retryContext.elapsedMilliseconds < 60000) {
            // Random delay 0-10 seconds for first minute
            return Math.random() * 10000;
        }
        // Stop retrying after 1 minute
        return null;
    }
})
```

**Key API differences from .NET client:**
- Uses `connection.on("MethodName", handler)` for receiving (not `hubConnection.On`)
- Uses `connection.invoke(...)` (returns Promise) or `connection.send(...)` (fire-and-forget)
- `connection.stream("Method")` returns `IStreamResult` with `subscribe()`
- Log level set via `configureLogging(signalR.LogLevel.Debug)` or string: `"warn"`

**Server timeout and keep-alive:**
```javascript
const connection = new signalR.HubConnectionBuilder()
    .withUrl("/chathub")
    .withServerTimeout(60000)       // 60s (default 30s) — double keepAlive
    .withKeepAliveInterval(30000)   // 30s (default 15s)
    .build();
```

### 5.2 .NET Client

**Package:** `Microsoft.AspNetCore.SignalR.Client`

```csharp
var connection = new HubConnectionBuilder()
    .WithUrl("https://example.com/chathub", options =>
    {
        options.AccessTokenProvider = () => Task.FromResult(_token);
        options.Headers["X-Custom"] = "value";
        options.SkipNegotiation = true;
        options.Transports = HttpTransportType.WebSockets;
        options.UseDefaultCredentials = true; // Windows auth
    })
    .WithAutomaticReconnect()
    .WithServerTimeout(TimeSpan.FromSeconds(60))
    .WithKeepAliveInterval(TimeSpan.FromSeconds(30))
    .ConfigureLogging(logging =>
    {
        logging.AddConsole();
        logging.SetMinimumLevel(LogLevel.Debug);
        logging.AddFilter("Microsoft.AspNetCore.SignalR", LogLevel.Debug);
        logging.AddFilter("Microsoft.AspNetCore.Http.Connections", LogLevel.Debug);
    })
    .Build();

// Register handlers
connection.On<string, string>("ReceiveMessage", (user, message) =>
    Console.WriteLine($"{user}: {message}"));

await connection.StartAsync();

// Invoke hub method
await connection.InvokeAsync("SendMessage", "Alice", "Hello");

// Send without waiting for acknowledgment
await connection.SendAsync("SendMessage", "Alice", "Hello");
```

### 5.3 Java Client

**Package:** `com.microsoft.signalr:signalr`

```java
HubConnection hubConnection = HubConnectionBuilder
    .create("https://example.com/chathub")
    .withHeader("Authorization", "Bearer " + token)
    .shouldSkipNegotiate(true)
    .withAccessTokenProvider(Single.defer(() -> Single.just(getToken())))
    .withHandshakeResponseTimeout(30_000)
    .build();

hubConnection.on("ReceiveMessage", (user, message) -> {
    System.out.println(user + ": " + message);
}, String.class, String.class);

hubConnection.start().blockingAwait();

// Server-to-client streaming
hubConnection.stream(String.class, "StreamMethod", "arg1")
    .subscribe(
        item -> System.out.println(item),
        error -> System.err.println(error),
        () -> System.out.println("Complete")
    );
```

**Java client uses RxJava** for streaming (Observable pattern).

### 5.4 Python Client

There is no official Microsoft Python client. Community options:
- `signalrcore` — third-party client with basic hub support
- `pysignalr` — async Python client

These clients have limited feature support compared to the .NET/JS clients. For production Python integration, prefer REST APIs with Azure SignalR Service or use a .NET microservice as intermediary.

---

## 6. Configuration Reference

### 6.1 Server Hub Options

```csharp
builder.Services.AddSignalR(options =>
{
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(60);  // default 30s
    options.HandshakeTimeout = TimeSpan.FromSeconds(15);        // default 15s
    options.KeepAliveInterval = TimeSpan.FromSeconds(15);       // default 15s
    options.EnableDetailedErrors = false;                        // NEVER true in prod
    options.MaximumReceiveMessageSize = 32 * 1024;              // default 32KB
    options.StreamBufferCapacity = 10;                          // default 10
    options.MaximumParallelInvocationsPerClient = 1;            // default 1
    options.DisableImplicitFromServicesParameters = false;
});
```

### 6.2 Transport/Endpoint Options

```csharp
app.MapHub<ChatHub>("/chathub", options =>
{
    options.Transports = HttpTransportType.WebSockets | HttpTransportType.LongPolling;
    options.ApplicationMaxBufferSize = 64 * 1024;  // default 64KB
    options.TransportMaxBufferSize = 64 * 1024;    // default 64KB
    options.CloseOnAuthenticationExpiration = true; // .NET 8+
    options.LongPolling.PollTimeout = TimeSpan.FromSeconds(90);
    options.WebSockets.CloseTimeout = TimeSpan.FromSeconds(5);
    options.MinimumProtocolVersion = 0;
});
```

### 6.3 Keep-Alive Timing Best Practice

- Set `ClientTimeoutInterval` to at least double `KeepAliveInterval` on server
- Set `ServerTimeout` to at least double `KeepAliveInterval` on client
- Default: `KeepAliveInterval = 15s`, `ClientTimeoutInterval = 30s` — these match

---

## 7. Scaling

### 7.1 Sticky Sessions (Session Affinity)

SignalR requires that all HTTP requests for a specific connection be handled by the same server process. Sticky sessions are required in all circumstances EXCEPT:

1. Single server, single process
2. Azure SignalR Service (handles affinity internally)
3. All clients using WebSockets ONLY + `SkipNegotiation = true`

**Azure App Service:** Enable "ARR Affinity" in Configuration settings.

**Nginx sticky sessions (ip_hash):**
```nginx
http {
    upstream signalr_backend {
        server localhost:5000;
        server localhost:5002;
        ip_hash;  # simple IP-based affinity
    }

    server {
        location /hubs {
            proxy_pass http://signalr_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_cache off;
            proxy_buffering off;
            proxy_read_timeout 100s;
        }
    }
}
```

**Nginx Plus cookie-based sticky sessions:**
```nginx
upstream signalr_backend {
    server localhost:5000;
    server localhost:5002;
    sticky cookie srv_id expires=max domain=.example.com path=/ httponly;
}
```

### 7.2 Redis Backplane

Recommended for on-premises multi-server deployments. Uses Redis pub/sub to forward messages between server nodes.

**Package:** `Microsoft.AspNetCore.SignalR.StackExchangeRedis`

```csharp
builder.Services.AddSignalR()
    .AddStackExchangeRedis("redis-connection-string", options =>
    {
        options.Configuration.ChannelPrefix = RedisChannel.Literal("MyApp");
    });
```

**Key constraints:**
- Sticky sessions ARE still required (except WebSockets + SkipNegotiation)
- App must scale based on connection count (not just message volume)
- Performance degrades significantly if Redis is in a different data center
- Connection information is passed to the backplane; messages are relayed

### 7.3 Azure SignalR Service

The recommended scale-out approach for Azure-hosted applications.

**Package:** `Microsoft.Azure.SignalR`

```csharp
builder.Services.AddSignalR()
    .AddAzureSignalR("Endpoint=https://...;AccessKey=...;Version=1.0;");

// Or use AddAzureSignalR() with configuration
builder.Services.AddSignalR()
    .AddAzureSignalR(); // reads "Azure:SignalR:ConnectionString" from config
```

**Service modes:**

| Mode | Use When | Sticky Sessions |
|------|----------|-----------------|
| **Default** | You have ASP.NET Core hub servers | Not required (service handles it) |
| **Serverless** | Azure Functions, no hub server | N/A |
| **Classic** | Legacy — do not use for new apps | Avoid |

**Default mode architecture:**
- Clients connect to Azure SignalR Service (redirect on negotiate)
- Hub servers maintain a small number of server connections to the service
- Service manages all client connections
- App server scales based on message volume, not connection count

**Serverless mode (Azure Functions):**
```json
// local.settings.json
{
    "Values": {
        "AzureSignalRConnectionString": "Endpoint=https://...;AccessKey=...;Version=1.0;"
    }
}
```

**Advantages of Azure SignalR Service over Redis:**
- No sticky session requirement
- App scales based on messages sent, not total connections
- Connections don't count against app server limits
- Built-in connection monitoring and diagnostics in Azure portal

### 7.4 TCP Connection Resource Limits

Each SignalR connection is persistent and holds a TCP connection. This is distinct from standard HTTP's ephemeral connections. Common error when connection limits are exhausted:
```
An attempt was made to access a socket in a way forbidden by its access permissions...
```

**Windows client OS limitation:** IIS on Windows 10/11 limits to 10 concurrent connections. Use Kestrel or IIS Express in development.

**Third-party backplane alternatives:**
- NCache
- Orleans (SignalR.Orleans)
- Rebus.SignalR
- IntelliTect.AspNetCore.SignalR.SqlServer

---

## 8. .NET Version-Specific Features

### 8.1 .NET 8 SignalR

- **Stateful Reconnect** introduced (available from .NET 8 onward)
- `CloseOnAuthenticationExpiration` option added
- Keyed DI service support (`[FromKeyedServices]`)
- MessagePack format improvements
- Blazor Server uses SignalR internally; enhanced Blazor SignalR guidance

### 8.2 .NET 9 SignalR

#### 8.2.1 Stateful Reconnect

Reduces perceived downtime during brief network interruptions by buffering messages and replaying them on reconnect. The client reconnects using the same logical connection, and missed messages are replayed.

**Server configuration:**
```csharp
app.MapHub<MyHub>("/hubname", options =>
{
    options.AllowStatefulReconnects = true;
});

// Optional: configure buffer size globally (default 100,000 bytes)
builder.Services.AddSignalR(o => o.StatefulReconnectBufferSize = 100_000);

// Or per-hub
builder.Services.AddSignalR()
    .AddHubOptions<MyHub>(o => o.StatefulReconnectBufferSize = 50_000);
```

**JavaScript/TypeScript client:**
```typescript
const connection = new signalR.HubConnectionBuilder()
    .withUrl("/hubname")
    .withStatefulReconnect({ bufferSize: 1000 }) // optional, bytes
    .build();
```

**.NET client:**
```csharp
var builder = new HubConnectionBuilder()
    .WithUrl("<hub url>")
    .WithStatefulReconnect();

builder.Services.Configure<HubConnectionOptions>(o =>
    o.StatefulReconnectBufferSize = 100_000);

var connection = builder.Build();
```

**How it works:**
1. Client detects disconnect
2. Client attempts reconnect with same connection context
3. Server and client exchange ACK messages for buffered data
4. Messages sent during disconnection window are replayed
5. Application resumes without data loss

#### 8.2.2 Native AOT Support

SignalR server and client now support trimming and Native AOT compilation (.NET 9+).

**Limitations:**
- JSON protocol only (MessagePack not supported with AOT)
- Must use `System.Text.Json` source generator
- Strongly typed hubs (`Hub<T>`) not supported with `PublishAot`
- `IAsyncEnumerable<T>` and `ChannelReader<T>` where T is a value type not recommended

**AOT-compatible SignalR server:**
```csharp
var builder = WebApplication.CreateSlimBuilder(args); // Use Slim builder

builder.Services.AddSignalR();

// Configure source generator for JSON serialization
builder.Services.Configure<JsonHubProtocolOptions>(o =>
{
    o.PayloadSerializerOptions.TypeInfoResolverChain.Insert(0,
        AppJsonSerializerContext.Default);
});

var app = builder.Build();
app.MapHub<ChatHub>("/chathub");
app.Run();

// Define JsonSerializable for all hub message types
[JsonSerializable(typeof(string))]
[JsonSerializable(typeof(ChatMessage))]
internal partial class AppJsonSerializerContext : JsonSerializerContext { }
```

**Publish with AOT:**
```bash
dotnet publish -c Release
# Or set in project file:
# <PublishAot>true</PublishAot>
```

#### 8.2.3 Polymorphic Hub Methods

Hub methods can now accept parameters of a base class type, with derived classes serialized/deserialized polymorphically.

```csharp
[JsonPolymorphic]
[JsonDerivedType(typeof(Cat), "cat")]
[JsonDerivedType(typeof(Dog), "dog")]
public class Animal
{
    public string Name { get; set; } = "";
}

public class Cat : Animal { public bool Indoor { get; set; } }
public class Dog : Animal { public string Breed { get; set; } = ""; }

public class AnimalHub : Hub
{
    public async Task SendAnimal(Animal animal)
    {
        // animal will be the correct derived type at runtime
        await Clients.All.SendAsync("ReceiveAnimal", animal);
    }
}
```

#### 8.2.4 Activity Tracing (.NET 9)

SignalR emits `ActivitySource` events for distributed tracing:

- **Server:** `Microsoft.AspNetCore.SignalR.Server` — one activity per hub method call
- **Client (.NET):** `Microsoft.AspNetCore.SignalR.Client` — hub invocation spans

Hub method activities are NOT bundled under the long-running connection activity (each is independent). Context propagation enables true distributed tracing from client to server.

```csharp
// OpenTelemetry integration
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing =>
    {
        tracing.AddAspNetCoreInstrumentation();
        tracing.AddSource("Microsoft.AspNetCore.SignalR.Server");
        tracing.AddSource("Microsoft.AspNetCore.SignalR.Client");
    });
```

### 8.3 .NET 10 SignalR

.NET 10 is in preview as of April 2026. Confirmed improvements include:

- Performance optimizations for high-connection-count scenarios
- Enhanced integration with Minimal APIs
- Improved Server-Sent Events native support in .NET 10 HTTP stack (which may reduce SSE as a SignalR transport use case for simple scenarios)
- Further AOT/trimming improvements

Note: .NET 10 SignalR-specific features were still being finalized at research time. Check the [ASP.NET Core 10.0 What's New](https://learn.microsoft.com/en-us/aspnet/core/release-notes/aspnetcore-10.0) documentation for the full list.

---

## 9. Best Practices

### 9.1 Hub Design

**Granularity:**
- Prefer fewer, purpose-specific hubs over one monolithic hub
- Split by domain: `ChatHub`, `NotificationHub`, `DashboardHub`
- Avoid deeply nested logic in hub methods — delegate to services

**Method naming:**
- Use descriptive verb-noun names: `SendMessage`, `JoinRoom`, `BroadcastUpdate`
- Keep hub methods thin; call service layer
- The `Async` suffix is significant — clients must match the exact name including or excluding `Async`

**Do NOT:**
```csharp
// BAD: Storing state in hub properties (hub is transient)
public class BadHub : Hub
{
    private string _userName; // WRONG - new instance each call

    public Task SetName(string name)
    {
        _userName = name; // This is lost immediately
        return Task.CompletedTask;
    }
}
```

**DO:**
```csharp
// GOOD: Use Context.Items for per-connection state
public class GoodHub : Hub
{
    public Task SetName(string name)
    {
        Context.Items["UserName"] = name; // Persists for this connection
        return Task.CompletedTask;
    }
}
```

### 9.2 Group Management Patterns

```csharp
// Pattern: Re-join groups on reconnect using persistent storage
public class ChatHub : Hub
{
    private readonly IGroupMembershipStore _store;

    public ChatHub(IGroupMembershipStore store) => _store = store;

    public override async Task OnConnectedAsync()
    {
        var userId = Context.UserIdentifier;
        if (userId != null)
        {
            var groups = await _store.GetUserGroupsAsync(userId);
            foreach (var group in groups)
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, group);
            }
        }
        await base.OnConnectedAsync();
    }

    public async Task JoinRoom(string roomName)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, roomName);
        await _store.AddUserToGroupAsync(Context.UserIdentifier!, roomName);
    }
}
```

### 9.3 Performance Best Practices

1. **Use MessagePack** for high-frequency, binary-safe data — 30-40% smaller payloads
2. **Use streaming** for large data sets or real-time feeds instead of buffering entire payloads
3. **Avoid large single messages** — split into streams or pagination
4. **Skip negotiation + WebSockets only** for known controlled environments (reduces one HTTP round-trip)
5. **Prefer `IAsyncEnumerable`** over `ChannelReader` for simpler streaming code
6. **Use Azure SignalR Service** to offload connection management overhead
7. **Register hub filters as singletons** when they have no per-request state

### 9.4 Connection Lifetime Management

```csharp
// Always handle reconnection in JavaScript clients
connection.onreconnecting((error) => {
    document.getElementById("status").textContent = "Reconnecting...";
    disableUI();
});

connection.onreconnected((connectionId) => {
    document.getElementById("status").textContent = "Connected";
    enableUI();
    // Re-join groups, refresh state
    rejoinGroups();
});

// Manual reconnect pattern for connection.start() failures
async function startWithRetry() {
    try {
        await connection.start();
    } catch (err) {
        setTimeout(startWithRetry, 5000);
    }
}
// Note: withAutomaticReconnect() does NOT handle initial start failures
```

---

## 10. Diagnostics and Troubleshooting

### 10.1 Server-Side Logging

Two key logging categories:
- `Microsoft.AspNetCore.SignalR` — Hub protocols, hub activation, method invocation
- `Microsoft.AspNetCore.Http.Connections` — Transport selection, WebSockets, Long Polling, SSE

**appsettings.json:**
```json
{
    "Logging": {
        "LogLevel": {
            "Default": "Information",
            "Microsoft.AspNetCore.SignalR": "Debug",
            "Microsoft.AspNetCore.Http.Connections": "Debug"
        }
    }
}
```

**Code-based configuration:**
```csharp
builder.Logging.AddFilter("Microsoft.AspNetCore.SignalR", LogLevel.Debug);
builder.Logging.AddFilter("Microsoft.AspNetCore.Http.Connections", LogLevel.Debug);
```

**Azure App Service:** Enable "Application Logging (Filesystem)" at Verbose level in Diagnostics Logs.

### 10.2 JavaScript Client Logging

```javascript
// Standard log levels
const connection = new signalR.HubConnectionBuilder()
    .withUrl("/chathub")
    .configureLogging(signalR.LogLevel.Debug)
    .build();

// Custom logger
class MyLogger {
    log(logLevel, message) {
        console.log(`[SignalR ${logLevel}] ${message}`);
    }
}

const connection = new signalR.HubConnectionBuilder()
    .withUrl("/chathub")
    .configureLogging(new MyLogger())
    .build();
```

**WARNING:** Never post raw logs from production apps publicly — they may contain access tokens and user data.

### 10.3 Metrics (Event Counters)

Monitor with `dotnet-counters`:
```bash
dotnet-counters monitor --process-id <PID> --counters Microsoft.AspNetCore.Http.Connections
```

**Available metrics:**

| Counter | Description |
|---------|-------------|
| `connections-started` | Total connections started |
| `connections-stopped` | Total connections stopped |
| `connections-timed-out` | Total connections timed out |
| `current-connections` | Active connections right now |
| `connections-duration` | Average connection duration (ms) |

### 10.4 Common Errors and Solutions

**CORS error preventing negotiate:**
```
Access to XMLHttpRequest at 'https://api.example.com/hubs/chat/negotiate' from origin 
'https://app.example.com' has been blocked by CORS policy
```
Solution: Configure CORS before `UseRouting()`. As of .NET 2.2+, you CANNOT use `AllowAnyOrigin()` with `AllowCredentials()` — must specify explicit origins:
```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("SignalRPolicy", policy =>
        policy.WithOrigins("https://app.example.com")
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials());
});
app.UseCors("SignalRPolicy");
```

**WebSocket upgrade failing (nginx):**
Ensure these nginx headers are set:
```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_http_version 1.1;
proxy_cache off;
```

**Negotiate endpoint not found (404):**
- Verify `app.MapHub<T>("/path")` is called
- Verify HTTPS is used in production (browsers block non-secure WebSockets on HTTPS pages)
- Check route prefix configuration

**Socket exhaustion error:**
```
An attempt was made to access a socket in a way forbidden by its access permissions
```
Solutions: Reduce connection count with Azure SignalR Service; separate SignalR to dedicated servers; scale out

**Connection drops on load balancer without sticky sessions:**
Symptom: Clients disconnect frequently, often with 400 Bad Request on long-poll responses.
Solution: Enable session affinity on load balancer.

**Token in query string logged by server:**
This is expected behavior for WebSocket/SSE browser connections. Mitigation: use HTTPS (encrypts query string in transit); restrict logging of SignalR paths; rotate tokens frequently.

### 10.5 Network Trace Collection

- **Fiddler** — best for all apps, can decrypt HTTPS
- **tcpdump** — macOS/Linux: `tcpdump -i eth0 -w trace.pcap`
- **Browser DevTools** — Network tab captures HTTP but NOT WebSocket frames in most browsers
- **HAR export** — useful for HTTP negotiation issues, not WebSocket frame content

### 10.6 Azure SignalR Service Diagnostics

Azure portal provides:
- Live connection count metrics
- Message count per second
- Error rate graphs
- Connection duration histograms

**Azure Monitor integration:**
```csharp
// Enable Azure Monitor with OpenTelemetry
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddSource("Microsoft.AspNetCore.SignalR.Server")
        .AddAzureMonitorTraceExporter());
```

---

## 11. Quick Reference: Key APIs

### Server-Side
```csharp
// Hub base class
public class MyHub : Hub { }
public class MyHub : Hub<IMyClient> { } // strongly typed

// Context properties
Context.ConnectionId         // string — unique per connection
Context.UserIdentifier       // string? — from IUserIdProvider
Context.User                 // ClaimsPrincipal
Context.Items                // IDictionary<object, object?> — per-connection state
Context.ConnectionAborted    // CancellationToken
Context.GetHttpContext()     // HttpContext? — headers, query string

// Client targeting
Clients.All
Clients.Caller
Clients.Others
Clients.Client(connectionId)
Clients.Group(groupName)
Clients.User(userId)
Clients.AllExcept(connectionIds)

// Group management
await Groups.AddToGroupAsync(Context.ConnectionId, "roomName");
await Groups.RemoveFromGroupAsync(Context.ConnectionId, "roomName");

// Hub method attributes
[HubMethodName("CustomName")]
[Authorize("PolicyName")]
```

### JavaScript Client Key Methods
```javascript
connection.on("Method", handler)        // Register handler
connection.off("Method", handler)       // Remove handler
connection.invoke("Method", ...args)    // Call hub, returns Promise with result
connection.send("Method", ...args)      // Call hub, fire-and-forget
connection.stream("Method", ...args)    // Start stream
connection.start()                      // Connect
connection.stop()                       // Disconnect
connection.state                        // HubConnectionState enum
connection.connectionId                 // string | null
connection.onreconnecting(cb)
connection.onreconnected(cb)
connection.onclose(cb)
```

### .NET Client Key Methods
```csharp
connection.On<T>("Method", handler)     // Register handler
connection.InvokeAsync("Method", args) // Call hub with result
connection.SendAsync("Method", args)   // Fire-and-forget
connection.StreamAsync<T>("Method")    // IAsyncEnumerable stream
connection.StartAsync()
connection.StopAsync()
connection.State                       // HubConnectionState
connection.ConnectionId                // string?
```

---

## Sources

- [Overview of ASP.NET Core SignalR](https://learn.microsoft.com/en-us/aspnet/core/signalr/introduction?view=aspnetcore-10.0)
- [Use hubs in ASP.NET Core SignalR](https://learn.microsoft.com/en-us/aspnet/core/signalr/hubs?view=aspnetcore-10.0)
- [ASP.NET Core SignalR configuration](https://learn.microsoft.com/en-us/aspnet/core/signalr/configuration?view=aspnetcore-10.0)
- [Use streaming in ASP.NET Core SignalR](https://learn.microsoft.com/en-us/aspnet/core/signalr/streaming?view=aspnetcore-9.0)
- [Authentication and authorization in ASP.NET Core SignalR](https://learn.microsoft.com/en-us/aspnet/core/signalr/authn-and-authz?view=aspnetcore-9.0)
- [Use hub filters in ASP.NET Core SignalR](https://learn.microsoft.com/en-us/aspnet/core/signalr/hub-filters?view=aspnetcore-10.0)
- [Logging and diagnostics in ASP.NET Core SignalR](https://learn.microsoft.com/en-us/aspnet/core/signalr/diagnostics?view=aspnetcore-10.0)
- [ASP.NET Core SignalR production hosting and scaling](https://learn.microsoft.com/en-us/aspnet/core/signalr/scale?view=aspnetcore-10.0)
- [Redis backplane for ASP.NET Core SignalR scale-out](https://learn.microsoft.com/en-us/aspnet/core/signalr/redis-backplane?view=aspnetcore-10.0)
- [Service mode in Azure SignalR Service](https://learn.microsoft.com/en-us/azure/azure-signalr/concept-service-mode)
- [.NET 9.0 SignalR supports trimming and Native AOT](https://abp.io/community/articles/.net-9.0-signalr-supports-trimming-and-native-aot-4oxx0qbs)
- [ASP.NET Core SignalR New Features Summary](https://abp.io/community/articles/asp.net-core-signalr-new-features-summary-kcydtdgq)
- [What's New in SignalR with .NET 9](https://medium.com/@serkutyildirim/whats-new-in-signalr-with-net-9-982ea9cbc921)
- [HubConnectionBuilderHttpExtensions.WithStatefulReconnect](https://learn.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.signalr.client.hubconnectionbuilderhttpextensions.withstatefulreconnect?view=aspnetcore-9.0)
- [SignalR Transport Protocols Spec](https://github.com/dotnet/aspnetcore/blob/main/src/SignalR/docs/specs/TransportProtocols.md)
