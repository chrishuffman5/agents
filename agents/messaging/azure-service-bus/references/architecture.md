# Azure Service Bus Architecture Reference

## Namespace

Scoping container for all messaging components. Maps to capacity slice of all-active cluster. DNS name: `<namespace>.servicebus.windows.net`. Premium namespaces are zone-redundant across three facilities.

## Queues

Point-to-point FIFO delivery to one or more competing consumers. Triple-redundant durable storage. Max message size: 256 KB (Standard), 100 MB (Premium, AMQP only). Max queue size: 1-80 GB. Max delivery count: default 10. Lock duration: default 60s, max 5 min. DLQ path: `<queue>/$deadletterqueue`.

## Topics and Subscriptions

One-to-many distribution. Up to 2,000 subscriptions per topic. Each subscription is a virtual queue receiving matching messages. Subscriptions are durable by default. DLQ path: `<topic>/Subscriptions/<sub>/$deadletterqueue`.

### Filter Types

**Correlation filters (most efficient):**
```csharp
var filter = new CorrelationRuleFilter { Label = "Important" };
filter.ApplicationProperties["color"] = "Red";
```

**SQL filters (flexible, each evaluation costs 1 credit):**
```csharp
var filter = new SqlRuleFilter("color = 'blue' AND quantity > 10");
```

**SQL actions (modify message metadata):**
```csharp
var action = new SqlRuleAction("SET sys.label = 'Processed'");
```

## Sessions

Guaranteed FIFO per session group. `RequiresSession = true` on entity. Sender sets `SessionId`. Receiver acquires exclusive lock. Session state: up to 256 KB (Standard), 100 MB (Premium).

```csharp
// Accept next available session
var sessionReceiver = await client.AcceptNextSessionAsync("myqueue");
// Accept specific session
var sessionReceiver = await client.AcceptSessionAsync("myqueue", "order-12345");
// Read/update session state
var state = await sessionReceiver.GetSessionStateAsync();
await sessionReceiver.SetSessionStateAsync(BinaryData.FromBytes(newState));
```

## Dead-Letter Queue

Built-in subqueue per entity. Cannot be deleted. Messages arrive when: MaxDeliveryCount exceeded, TTL expired, session ID null on session-enabled entity, max transfer hops exceeded.

```csharp
// Application-level dead-lettering
await receiver.DeadLetterMessageAsync(message,
    deadLetterReason: "ValidationFailed",
    deadLetterErrorDescription: "Missing OrderId");
```

DLQ does not respect TTL -- messages stay until explicitly consumed.

## Duplicate Detection

Tracks `MessageId` values for configurable window (1 min to 7 days, default 10 min). Duplicates silently discarded. Not available on Basic tier.

## Transactions

Atomic operations scoped to single messaging entity:
```csharp
using var txScope = new TransactionScope(TransactionScopeAsyncFlowOption.Enabled);
await receiver.CompleteMessageAsync(receivedMessage);
await sender.SendMessageAsync(new ServiceBusMessage("result"));
txScope.Complete();
```

Not supported with ReceiveAndDelete mode.

## Scheduled Messages

```csharp
var message = new ServiceBusMessage("payload");
message.ScheduledEnqueueTime = DateTimeOffset.UtcNow.AddHours(2);
long seqNum = await sender.ScheduleMessageAsync(message, message.ScheduledEnqueueTime);
await sender.CancelScheduledMessageAsync(seqNum);
```

## Message Deferral

Set aside a message for later retrieval by sequence number:
```csharp
await receiver.DeferMessageAsync(message);
var deferred = await receiver.ReceiveDeferredMessageAsync(seqNum);
```

Deferred messages do NOT expire via TTL.

## Auto-Forwarding

Chain entities within same namespace. Messages exceeding 4 hops are dead-lettered.

## Premium Tier

| Feature | Basic | Standard | Premium |
|---|---|---|---|
| Topics/Subscriptions | No | Yes | Yes |
| Sessions | No | Yes | Yes |
| Message size | 256 KB | 256 KB | Up to 100 MB |
| Duplicate detection | No | Yes | Yes |
| VNET / Private Endpoints | No | No | Yes |
| Geo-DR / Geo-Replication | No | No | Yes |
| Dedicated resources | No | No | Yes (MUs) |
| Pricing | Per-message | Per-message | Per MU/hour |

**Messaging Units:** 1, 2, 4, 8, or 16 MUs. ~4 MB/s per MU. Scale up at CPU > 70%, down at < 20%.

## Geo-Disaster Recovery (Premium)

Replicates metadata only (not messages). Alias provides stable FQDN. Failover is manual. Sync rate: ~50-100 entities/minute.

**Geo-Replication** (newer): Replicates both metadata AND data. Recommended for most DR scenarios.

## Partitioned Entities

Standard/Basic: 16 partitions per entity. Premium: partitioning set at namespace level. Multiple partitions with lower MUs outperform single partition with higher MUs.

## AMQP 1.0

Primary wire protocol (ISO/IEC standard). Persistent connections. Supports batching and prefetching. Required for large messages (100 MB) on Premium. HTTP is request/response only.

**SDK Retirement (September 30, 2026):** Migrate from `WindowsAzure.ServiceBus`, `Microsoft.Azure.ServiceBus`, `com.microsoft.azure.servicebus` to latest SDKs (`Azure.Messaging.ServiceBus`, etc.).
