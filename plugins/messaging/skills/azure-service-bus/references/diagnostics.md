# Azure Service Bus Diagnostics Reference

## Throttling

### Symptoms
- `ThrottledRequests` metric > 0
- SDK throws `ServiceBusException` with `Reason = ServiceBusy`
- Increased latency and intermittent failures

### Diagnosis
```
Azure Monitor > Metrics > ThrottledRequests (split by MessagingErrorSubCode)
```

### Resolution
| Cause | Resolution |
|---|---|
| Standard tier at capacity | Upgrade to Premium with dedicated MUs |
| Premium CPU > 70% | Scale up MUs (1 -> 2 -> 4 -> 8 -> 16) |
| Too many concurrent operations | Reduce client concurrency; use batching |
| Entity size limit reached | Increase entity max size; archive old messages |

## DLQ Investigation

### Check DLQ Count
```bash
az servicebus queue show --resource-group MyRG --namespace-name myNS --name myQueue \
  --query "countDetails.deadLetterMessageCount"
```

### Read DLQ Messages
```csharp
var dlqReceiver = client.CreateReceiver("myqueue",
    new ServiceBusReceiverOptions { SubQueue = SubQueue.DeadLetter });
var messages = await dlqReceiver.ReceiveMessagesAsync(maxMessages: 10);
foreach (var msg in messages) {
    Console.WriteLine($"Reason: {msg.DeadLetterReason}");
    Console.WriteLine($"Description: {msg.DeadLetterErrorDescription}");
    Console.WriteLine($"Body: {msg.Body}");
}
```

### Common DLQ Reasons
| Reason | Cause | Resolution |
|---|---|---|
| `MaxDeliveryCountExceeded` | Consumer failed 10+ times | Fix processing bug; increase max delivery count |
| `TTLExpiredException` | Message expired before consumption | Add consumers; reduce TTL; investigate slow consumers |
| `HeaderSizeExceeded` | Message metadata too large | Reduce header/property size |
| `Session ID is null` | Missing SessionId on session-enabled entity | Set SessionId on all messages to session entities |

### Redrive DLQ Messages

Use Azure Portal Service Bus Explorer or SDK to read DLQ messages and resend to original entity.

## Session Issues

### Session Lock Lost
- SDK throws `SessionLockLostException`
- Cause: Processing exceeds lock duration; network interruption
- Resolution: Extend session lock; reduce per-message processing time; increase lock duration

### No Available Sessions
- `AcceptNextSessionAsync` times out
- Cause: All sessions locked by other receivers; no messages with SessionId
- Resolution: Check active session locks; verify messages have SessionId set

### Session State Too Large
- Standard tier: max 256 KB
- Premium tier: max 100 MB
- Resolution: Store minimal checkpoint data; use external storage for large state

## Lock Expiration

### Symptoms
- `MessageLockLostException` when calling `CompleteMessageAsync`
- Messages redelivered despite successful processing

### Resolution
1. Increase lock duration (up to 5 minutes)
2. Reduce processing time per message
3. Call `RenewMessageLockAsync` for long-running processing
4. Reduce prefetch count (locks acquired at prefetch time)

```csharp
// Renew lock during long processing
var lockRenewalTask = Task.Run(async () => {
    while (!cts.Token.IsCancellationRequested) {
        await Task.Delay(TimeSpan.FromSeconds(30), cts.Token);
        await receiver.RenewMessageLockAsync(message);
    }
});
```

## Connectivity Issues

### Connection Failures
| Symptom | Cause | Resolution |
|---|---|---|
| `ServiceBusException: Unauthorized` | Invalid credentials or expired SAS | Refresh credentials; use Azure AD |
| `SocketException` | Network or firewall blocking | Check VNET rules; verify AMQP port 5671 |
| `TimeoutException` | Server overloaded or network latency | Retry with backoff; check throttling |

### AMQP Connection Limits
- Premium: 1,000 concurrent connections per MU
- Standard: 1,000 concurrent connections per namespace
- Resolution: Use connection pooling; reduce connection count; singleton clients

## Azure Monitor Metrics

### Critical Alerts

| Metric | Alert Threshold | Notes |
|---|---|---|
| `DeadletteredMessages` | > 0 or threshold | Processing failures |
| `ThrottledRequests` | > 0 sustained | Capacity issue |
| `NamespaceCpuUsage` | > 70% | Scale up MUs (Premium) |
| `ActiveMessages` | Growing trend | Consumer falling behind |
| `ServerErrors` | > 0 sustained | Platform issue |
| `ScheduledMessages` | Unexpected count | Scheduled message buildup |

### Log Analytics Tables
- `AZMSOperationalLogs` -- Management operations
- `AZMSRuntimeAuditLogs` -- Data plane operations (Premium only)
- `AZMSDiagnosticErrorLogs` -- Client errors, throttling
- `AZMSVNetConnectionEvents` -- VNET/IP filter logs

### Useful KQL Queries

```kql
// Throttled requests in last hour
AZMSDiagnosticErrorLogs
| where TimeGenerated > ago(1h)
| where OperationName contains "Throttle"
| summarize count() by bin(TimeGenerated, 5m), EntityName

// DLQ message reasons
AZMSRuntimeAuditLogs
| where TimeGenerated > ago(24h)
| where ActivityName == "DeadLetter"
| summarize count() by EntityName, Properties.deadLetterReason
```

## Cost Analysis

### Premium Tier Sizing
- Start with 1 MU
- Monitor `NamespaceCpuUsage` and `NamespaceMemoryUsage`
- Scale when CPU > 70% sustained
- Each MU: ~4 MB/s throughput
- Consider partitioned namespace for high throughput

### Standard Tier Cost Drivers
- Operations (send/receive/peek): $0.05 per million
- Relay hours, hybrid connections
- Optimize: batch operations, long polling, reduce unnecessary peeks

### Common Cost Mistakes
1. Premium MUs left running with no workload -- stop or scale down
2. Too many subscriptions (each receives a copy) -- consolidate with filters
3. Large messages on Premium -- charged per 64 KB chunk
4. Orphaned namespaces with no active usage
