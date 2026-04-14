# SignalR Diagnostics

## Connection Failures

### "Failed to start the connection: Error"

**Steps:**
1. Check server is running and hub is mapped (`app.MapHub<ChatHub>("/chathub")`)
2. Verify URL matches between client and server (path, scheme)
3. Check CORS configuration if cross-origin
4. Check if authentication middleware runs before hub mapping
5. Verify TLS certificate if using HTTPS

### "WebSocket connection to 'wss://...' failed"

**Steps:**
1. Check if WebSocket transport is allowed server-side
2. Verify reverse proxy/load balancer supports WebSocket upgrade
3. Check for corporate proxy blocking WebSocket
4. Try SSE or Long Polling as fallback

**Nginx WebSocket config:**
```nginx
location /chathub {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
}
```

### Negotiate Returns 404

**Fix:** Ensure `app.MapHub<ChatHub>("/chathub")` is called. Check that the path matches the client URL.

### Negotiate Returns 401

**Fix:** Authentication middleware must run before hub mapping. Verify token is valid. For WebSocket/SSE, ensure `OnMessageReceived` extracts token from query string.

## Transport Issues

### Falling Back to Long Polling

**Symptom:** Connection works but latency is high. Network tab shows repeated HTTP requests.

**Causes:**
1. WebSocket blocked by proxy/firewall
2. Server does not have WebSocket middleware
3. `SkipNegotiation` set but WebSocket unavailable

**Diagnosis:** Check negotiate response for `availableTransports`. If WebSocket is listed but not used, check network path.

### SSE Not Working

**Cause:** SSE is server-to-client only. Client-to-server messages use separate HTTP POST requests. If POST requests fail, the connection degrades to Long Polling.

## Authentication Problems

### Hub Method Returns "Unauthorized"

**Steps:**
1. Verify `[Authorize]` attribute is on the hub or method
2. Check that authentication middleware is configured and runs before authorization
3. For WebSocket: verify `OnMessageReceived` extracts token from query string
4. Check token expiry -- tokens may have expired after initial connection

### Token Not Reaching Server

**Steps:**
1. Verify `accessTokenFactory` is set in JavaScript client
2. Check that the factory returns a string (not a Promise that resolves to undefined)
3. Verify the token is being sent as `access_token` query parameter
4. Check server-side `OnMessageReceived` is extracting from correct path

### "User identifier is null"

**Fix:** SignalR uses `ClaimTypes.NameIdentifier` by default. Ensure the JWT contains this claim, or implement `IUserIdProvider` to use a different claim.

## Scaling Issues

### Messages Not Reaching All Clients (Multi-Server)

**Cause:** Without a backplane, each server only knows about its own connections.

**Fix:** Add Redis backplane or Azure SignalR Service:
```csharp
builder.Services.AddSignalR().AddStackExchangeRedis("redis-connection-string");
```

### Redis Backplane Latency

**Symptom:** Messages arrive slowly compared to single-server deployment.

**Diagnosis:** Measure Redis round-trip time. Check Redis CPU/memory. Consider Azure SignalR Service for lower latency.

### Azure SignalR Service Connection Limit

**Symptom:** Connections rejected after reaching unit capacity.

**Fix:** Scale up units in Azure portal. Each Standard unit supports ~1,000 concurrent connections.

## Streaming Errors

### "Stream was not completed" / Hung Stream

**Cause:** Server-side `ChannelWriter` not completed in `finally` block. If an exception occurs before `writer.Complete()`, the stream hangs.

**Fix:**
```csharp
private async Task WriteItemsAsync(ChannelWriter<int> writer, ...)
{
    try { /* write items */ }
    catch (Exception ex) { localException = ex; }
    finally { writer.Complete(localException); }
}
```

### Client-to-Server Stream Not Receiving

**Steps:**
1. Verify client is calling `subject.next()` with data
2. Check that `subject.complete()` is called when done
3. Verify the hub method parameter type matches (`IAsyncEnumerable<T>` or `ChannelReader<T>`)

## Group Management Issues

### Client Not Receiving Group Messages After Reconnect

**Cause:** Groups are cleaned up on disconnect. New connection ID is not in any group.

**Fix:** Persist group membership externally. Re-join in `OnConnectedAsync`:
```csharp
public override async Task OnConnectedAsync()
{
    var groups = await _store.GetGroups(Context.UserIdentifier);
    foreach (var g in groups) await Groups.AddToGroupAsync(Context.ConnectionId, g);
}
```

### Group Messages Sent But Not Received

**Steps:**
1. Verify client is in the group (check via logging in `AddToGroupAsync`)
2. Verify event name matches between server `SendAsync` and client `.on()`
3. Check if using backplane -- group membership must propagate across servers

## Hub Method Errors

### "An unexpected error occurred invoking 'MethodName'"

This is the default sanitized error message. To see details:
1. Enable `DetailedErrors` in development: `options.EnableDetailedErrors = true`
2. Check server logs for the actual exception
3. Throw `HubException` to send custom error messages to client

### Method Not Found

**Steps:**
1. Check method name casing -- C# methods are matched case-insensitively from JavaScript
2. Verify method is `public` and defined on the hub class
3. Check parameter count and types match client call

## Logging

Enable detailed SignalR logging:

```csharp
builder.Logging.AddFilter("Microsoft.AspNetCore.SignalR", LogLevel.Debug);
builder.Logging.AddFilter("Microsoft.AspNetCore.Http.Connections", LogLevel.Debug);
```

JavaScript client:
```typescript
.configureLogging(signalR.LogLevel.Debug)
```

## Common Error Patterns

| Error | Cause | Fix |
|---|---|---|
| Connection timeout during handshake | Server not responding within 15s | Check server startup, increase HandshakeTimeout |
| "Invocation canceled" | Client disconnected during method call | Handle `OperationCanceledException` in hub |
| "Connection closed with an error" | Unhandled exception in hub | Add try/catch in hub methods |
| Max message size exceeded | Client sent message > 32KB default | Increase `MaximumReceiveMessageSize` or reduce payload |
| "The connection was stopped before the invocation result was received" | Connection closed before response | Implement retry on client side |
