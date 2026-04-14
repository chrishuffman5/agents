# SignalR Best Practices

## Authentication

### JWT Bearer Token

Browser clients pass JWT via query string (WebSocket/SSE cannot set headers):

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var token = context.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) && context.Request.Path.StartsWithSegments("/hubs"))
                    context.Token = token;
                return Task.CompletedTask;
            }
        };
    });
```

JavaScript client:
```typescript
const connection = new signalR.HubConnectionBuilder()
    .withUrl("/hubs/chat", { accessTokenFactory: () => getToken() })
    .build();
```

**Warning:** Query string tokens appear in logs. Restrict extraction to hub paths only.

### Cookie Authentication

Cookies flow automatically for same-origin. No additional SignalR config needed.

### Hub Authorization

```csharp
[Authorize] public class ChatHub : Hub { }
[Authorize("AdminOnly")] public class AdminHub : Hub { }
```

Method-level: `[Authorize("Administrators")]` on individual hub methods.

### Custom User ID Provider

```csharp
public class EmailUserIdProvider : IUserIdProvider
{
    public string GetUserId(HubConnectionContext connection)
        => connection.User?.FindFirst(ClaimTypes.Email)?.Value!;
}
builder.Services.AddSingleton<IUserIdProvider, EmailUserIdProvider>();
```

### Token Expiry on Long-Lived Connections

WebSocket connections remain authenticated after JWT expires. Options:
- `CloseOnAuthenticationExpiration: true` (closes connection on expiry)
- Implement per-message validation in hub filter
- Client-side: watch for close event and reconnect with fresh token

## Azure SignalR Service

Managed service that handles connection management and scaling:

```csharp
builder.Services.AddSignalR().AddAzureSignalR("Endpoint=https://...;AccessKey=...;Version=1.0;");
```

### Benefits
- Scales to 1M+ concurrent connections
- No sticky sessions needed
- Serverless mode for event-driven architectures
- Built-in metrics and diagnostics

### Connection Modes
- **Default**: server maintains persistent connection to Azure SignalR Service
- **Serverless**: Azure SignalR Service receives REST API calls; no persistent server connection

### Pricing Considerations
- Standard tier: per-unit pricing, each unit supports up to 1,000 concurrent connections
- Premium tier: higher limits, private endpoints

## Redis Backplane

For self-hosted scaling without Azure SignalR Service:

```csharp
builder.Services.AddSignalR().AddStackExchangeRedis("redis-connection-string", options =>
{
    options.Configuration.ChannelPrefix = RedisChannel.Literal("ChatApp");
});
```

### Redis Backplane Characteristics
- All messages published to Redis Pub/Sub
- All server instances subscribe and forward to local connections
- Adds latency (Redis round-trip)
- No message persistence -- lost if Redis is down

## Reconnection

### JavaScript Client

```typescript
const connection = new signalR.HubConnectionBuilder()
    .withUrl("/chathub")
    .withAutomaticReconnect([0, 2000, 10000, 30000])
    .build();

connection.onreconnecting((error) => {
    console.warn("Reconnecting...", error);
});

connection.onreconnected((connectionId) => {
    console.log("Reconnected:", connectionId);
    // Re-join groups, refresh state
});

connection.onclose((error) => {
    console.error("Connection closed permanently:", error);
    // Implement manual reconnect with backoff
});
```

### .NET Client

```csharp
connection.Reconnecting += error => { /* update UI */ return Task.CompletedTask; };
connection.Reconnected += connectionId => { /* re-join groups */ return Task.CompletedTask; };
connection.Closed += async (error) => {
    await Task.Delay(new Random().Next(0, 5) * 1000);
    await connection.StartAsync();
};
```

### Server-Side Group Re-Join

Groups do not persist across reconnects. Persist membership and re-join:
```csharp
public override async Task OnConnectedAsync()
{
    var userId = Context.UserIdentifier;
    var groups = await _groupStore.GetGroupsForUser(userId);
    foreach (var group in groups)
        await Groups.AddToGroupAsync(Context.ConnectionId, group);
    await base.OnConnectedAsync();
}
```

## Performance

### MessagePack Protocol

30-40% smaller payloads, faster serialization. Use for high-throughput scenarios.

### Limit Message Size

```csharp
builder.Services.AddSignalR(options =>
{
    options.MaximumReceiveMessageSize = 32 * 1024; // 32KB default
});
```

### Connection Throttling

```csharp
app.MapHub<ChatHub>("/chathub", options =>
{
    options.MaximumParallelInvocationsPerClient = 1; // serialize per-client calls
});
```

### Keep-Alive and Timeout

```csharp
builder.Services.AddSignalR(options =>
{
    options.KeepAliveInterval = TimeSpan.FromSeconds(15);
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(30);
});
```

### Skip Negotiation

Eliminates the `/negotiate` round-trip. Only works with WebSocket transport.

## Security

### CORS Configuration

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("SignalR", policy =>
    {
        policy.WithOrigins("https://app.example.com")
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});
app.UseCors("SignalR");
```

### Rate Limiting

Implement via Hub Filter:
```csharp
public class RateLimitFilter : IHubFilter
{
    public async ValueTask<object?> InvokeMethodAsync(
        HubInvocationContext ctx, Func<HubInvocationContext, ValueTask<object?>> next)
    {
        if (IsRateLimited(ctx.Context.ConnectionId))
            throw new HubException("Rate limit exceeded");
        return await next(ctx);
    }
}
```

### Input Validation

Validate all hub method parameters. Do not trust client input. Use model validation or manual checks in hub methods.

## .NET Version Specifics

### .NET 8
- Keyed services in hub methods (`[FromKeyedServices]`)
- Improved reconnection diagnostics

### .NET 9
- `CloseOnAuthenticationExpiration` option
- Improved Native AOT support (but strongly typed hubs incompatible)
- Trim-safe hub method resolution

### .NET 10 (Preview)
- Performance improvements in hub protocol parsing
- Enhanced Azure SignalR Service integration
