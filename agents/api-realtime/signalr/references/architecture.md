# SignalR Architecture Deep Dive

## Hub Model

### Two-Layer Architecture

1. **Connection Layer** (`HttpConnectionDispatcher`): handles HTTP requests, transport selection, connection lifecycle
2. **Hub Layer**: routes method calls, manages groups/users, dispatches responses

### Hub Registration

```csharp
builder.Services.AddSignalR();
app.MapHub<ChatHub>("/chathub");
```

### Hub Methods and Client Targeting

```csharp
public class ChatHub : Hub
{
    public async Task SendMessage(string user, string message)
        => await Clients.All.SendAsync("ReceiveMessage", user, message);

    public async Task SendToGroup(string group, string message)
        => await Clients.Group(group).SendAsync("ReceiveMessage", Context.UserIdentifier, message);
}
```

Targets: `All`, `Caller`, `Others`, `Client(id)`, `Clients(ids)`, `Group(name)`, `Groups(names)`, `GroupExcept(name, ids)`, `OthersInGroup(name)`, `User(userId)`, `Users(userIds)`, `AllExcept(ids)`.

### Strongly Typed Hubs

```csharp
public interface IChatClient
{
    Task ReceiveMessage(string user, string message);
}

public class ChatHub : Hub<IChatClient>
{
    public async Task SendMessage(string user, string message)
        => await Clients.All.ReceiveMessage(user, message);
}
```

**Limitation:** Not compatible with Native AOT (.NET 9+). `Async` suffix is NOT stripped from method names.

### Client Results (InvokeAsync)

Server requests a result from a client:
```csharp
var message = await Clients.Client(connectionId).InvokeAsync<string>("GetMessage", CancellationToken.None);
```

## Transport Negotiation

### Transport Priority

1. **WebSockets** -- full-duplex, lowest overhead
2. **Server-Sent Events (SSE)** -- server-to-client, HTTP streaming
3. **Long Polling** -- repeated HTTP requests, maximum compatibility

### Negotiation Flow

1. Client hits `/negotiate` endpoint
2. Server returns available transports + connection token
3. Client connects via best mutually-supported transport

### Skip Negotiation

```csharp
var connection = new HubConnectionBuilder()
    .WithUrl("https://example.com/chathub", options =>
    {
        options.SkipNegotiation = true;
        options.Transports = HttpTransportType.WebSockets;
    }).Build();
```

Significant performance gain -- eliminates extra round-trip. Only works with WebSockets.

### Restrict Transports

```csharp
app.MapHub<ChatHub>("/chathub", options =>
{
    options.Transports = HttpTransportType.WebSockets | HttpTransportType.LongPolling;
});
```

## Connection Lifecycle

1. `/negotiate` -- transport and token negotiation
2. Connect via selected transport
3. Protocol handshake (JSON/MessagePack), 15s timeout
4. `OnConnectedAsync` fires
5. Bidirectional communication
6. `OnDisconnectedAsync` fires (exception param for unexpected disconnects)
7. Groups auto-cleanup

```csharp
public override async Task OnConnectedAsync()
{
    await Groups.AddToGroupAsync(Context.ConnectionId, "general");
    await base.OnConnectedAsync();
}

public override async Task OnDisconnectedAsync(Exception? exception)
{
    // No need to remove from groups -- auto-cleanup
    await base.OnDisconnectedAsync(exception);
}
```

## Streaming

### Server-to-Client (IAsyncEnumerable)

```csharp
public async IAsyncEnumerable<int> Counter(int count, int delay,
    [EnumeratorCancellation] CancellationToken ct)
{
    for (var i = 0; i < count; i++)
    {
        ct.ThrowIfCancellationRequested();
        yield return i;
        await Task.Delay(delay, ct);
    }
}
```

### Client-to-Server

```csharp
public async Task UploadStream(IAsyncEnumerable<string> stream)
{
    await foreach (var item in stream) { Console.WriteLine(item); }
}
```

### JavaScript Client Streaming

```javascript
// Server-to-client
connection.stream("Counter", 10, 500).subscribe({
    next: (item) => console.log(item),
    complete: () => console.log("Done"),
    error: (err) => console.error(err)
});

// Client-to-server
const subject = new signalR.Subject();
connection.send("UploadStream", subject);
subject.next("item1");
subject.complete();
```

## Hub Protocols

### JSON (Default)

```csharp
builder.Services.AddSignalR()
    .AddJsonProtocol(options => {
        options.PayloadSerializerOptions.PropertyNamingPolicy = null;
    });
```

### MessagePack

```csharp
builder.Services.AddSignalR().AddMessagePackProtocol();
```

Client: `new signalR.HubConnectionBuilder().withHubProtocol(new MessagePackHubProtocol()).build();`

~30-40% smaller payloads, faster parsing.

## Hub Filters

```csharp
public class LoggingFilter : IHubFilter
{
    public async ValueTask<object?> InvokeMethodAsync(
        HubInvocationContext ctx, Func<HubInvocationContext, ValueTask<object?>> next)
    {
        _logger.LogInformation("Calling {Method}", ctx.HubMethodName);
        return await next(ctx);
    }
}

builder.Services.AddSignalR(options => { options.AddFilter<LoggingFilter>(); });
```

## Group Management

Groups are named collections of connections. Server-side only.

```csharp
await Groups.AddToGroupAsync(Context.ConnectionId, "room1");
await Groups.RemoveFromGroupAsync(Context.ConnectionId, "room1");
await Clients.Group("room1").SendAsync("Event", data);
```

**Key facts:**
- Groups do NOT persist across reconnects
- Groups auto-cleanup on disconnect
- Persist membership externally (Redis, DB) and re-join in `OnConnectedAsync`

## Error Handling

Default: generic error message sent to client. To send details, throw `HubException`:
```csharp
throw new HubException("This error will be sent to the client!");
```

Enable detailed errors in development only:
```csharp
builder.Services.AddSignalR(options => { options.EnableDetailedErrors = true; });
```

## Dependency Injection

Constructor injection and method-level injection (implicit in .NET 7+):
```csharp
public class ChatHub : Hub
{
    public Task Send(string msg, IUserService userService)
    {
        var name = userService.GetCurrentName();
        return Clients.All.SendAsync("ReceiveMessage", name, msg);
    }
}
```

Keyed services supported in .NET 8+.
