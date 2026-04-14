# Azure Service Bus — Managed Research Document

**Research date**: 2026-04-13  
**Sources**: Microsoft Learn official documentation, Azure SDK GitHub repositories  
**Purpose**: Writer agent reference for building Azure Service Bus technology skill files

---

## 1. Overview

Azure Service Bus is a fully managed enterprise message broker (PaaS) supporting message queues and publish-subscribe topics. It decouples applications and services, providing:

- Load-balancing across competing workers
- Reliable routing and transfer of data across service boundaries
- Transactional work coordination with high reliability
- Durable message storage with triple-redundant persistence across availability zones

**Protocol**: Primary wire protocol is AMQP 1.0 (ISO/IEC standard). HTTP/REST is also supported.  
**JMS Support**: Premium tier supports JMS 2.0 (Standard supports JMS 1.1 subset).  

**IMPORTANT SDK Retirement Notice**: On 30 September 2026, the legacy SDK libraries (`WindowsAzure.ServiceBus`, `Microsoft.Azure.ServiceBus`, `com.microsoft.azure.servicebus`) and the SBMP protocol will be retired. Migrate to the latest `Azure.Messaging.ServiceBus` (.NET), `azure-servicebus` (Python), `@azure/service-bus` (JS), or `azure-messaging-servicebus` (Java) SDKs using AMQP.

---

## 2. Architecture

### 2.1 Namespace

A namespace is the scoping container for all messaging components (queues, topics, subscriptions). It maps to a capacity slice of a large all-active cluster spanning Azure availability zones.

- Serves as an "application container" analogous to a server in traditional broker terminology
- Provides a single DNS name: `<namespace>.servicebus.windows.net`
- Supports one or more queues and topics
- Premium namespaces can be zone-redundant across three physically separated facilities

### 2.2 Queues

Queues provide point-to-point, First-In-First-Out (FIFO) message delivery to one or more competing consumers.

Key characteristics:
- Messages are ordered and timestamped on arrival
- Each message is consumed by exactly one receiver
- Pull-based delivery (long-poll, not busy-polling)
- Triple-redundant durable storage
- **Message size**: Up to 256 KB (Standard), up to 100 MB (Premium with large message support enabled)
- **Max queue size**: 1–80 GB configurable
- **Max delivery count**: Default 10, configurable; exceeded = dead-lettered
- **Lock duration**: Default 60 seconds, configurable up to 5 minutes (PeekLock mode)
- **TTL (Time-to-Live)**: Configurable per message or at entity level

DLQ path: `<queue>/$deadletterqueue`

### 2.3 Topics and Subscriptions

Topics enable publish/subscribe (fan-out) messaging: one-to-many distribution.

Key characteristics:
- Publishers send to the topic; subscribers receive from named subscriptions
- Up to **2,000 subscriptions per topic**
- Each subscription acts as a virtual queue — receives a copy of every matching message
- Subscriptions support filter rules to select a subset of messages
- Subscriptions are durable by default; can be configured with `AutoDeleteOnIdle`
- Premium: Volatile (non-durable) subscriptions supported via JMS 2.0 API

DLQ path for topic subscription: `<topic>/Subscriptions/<subscription>/$deadletterqueue`

### 2.4 AMQP 1.0 Protocol

- Open ISO/IEC standard — interoperable with ActiveMQ, RabbitMQ, and other AMQP brokers
- Maintains persistent connections to Service Bus (most efficient protocol)
- Supports batching and prefetching natively
- Required for large message support (100 MB) in Premium tier
- HTTP is request/response only; does not support prefetch or batching
- SBMP protocol (legacy .NET only) retires September 30, 2026

### 2.5 Partitioned Entities (Premium)

Partitioning increases throughput and availability by spreading messages across multiple storage nodes.

- **Standard/Basic**: Partitioning enabled at entity creation; Service Bus creates 16 partitions
- **Premium**: Partitioning enabled at **namespace** creation; number of partitions specified at creation time; all entities in the namespace are partitioned
- When partitioning is enabled, messaging units (MUs) are equally distributed across partitions
- Multiple partitions with lower MUs outperform a single partition with higher MUs
- Pairing a partitioned namespace with a nonpartitioned namespace for geo-DR is not supported

### 2.6 Premium Tier — Dedicated Resources

Premium tier provides resource isolation at CPU and memory level per customer.

**Messaging Units (MU)**:
- Dedicated compute resources allocated per namespace
- Options: 1, 2, 4, 8, or 16 MUs
- Can be scaled up/down dynamically (auto-scale supported)
- Benchmark: ~4 MB/second ingress + egress per MU
- Scale up recommendation: CPU > 70%; Scale down: CPU < 20%
- Billing is hourly

**Premium-only features**:
- Large messages up to 100 MB (AMQP only; HTTP/SBMP max 1 MB even on Premium)
- VNET integration (service endpoints, private endpoints, IP firewall via portal)
- Customer-managed key (CMK) encryption
- Geo-Disaster Recovery and Geo-Replication
- Runtime Audit Logs
- JMS 2.0 support
- Zone redundancy

### 2.7 Geo-Disaster Recovery

Available for Premium tier only. Replicates **metadata only** (entities, configuration, properties) — NOT messages.

**Key concepts**:
- **Alias**: Stable FQDN connection string used by applications; stays the same after failover
- **Primary namespace**: Active, receives messages
- **Secondary namespace**: Passive, receives replicated metadata only
- **Failover**: Customer-initiated (manual); Azure never auto-triggers failover
- Failover is near-instantaneous once initiated
- Only fail-forward semantics are supported (cannot fail back to original primary)
- **Safe Failover**: Waits for pending replications to complete before switching

**What is NOT replicated**:
- Messages in queues/subscriptions/DLQs
- VNET configurations and private endpoint connections
- RBAC assignments (must be recreated manually in secondary)
- Encryption/identity settings
- AutoScale settings and local auth settings
- Event Grid subscriptions

**Sync rate**: ~50–100 entities per minute

**Vs. Geo-Replication**: Geo-Replication (newer feature) replicates BOTH metadata AND data (messages, message states, property changes). Geo-Replication is recommended for most disaster recovery scenarios.

### 2.8 Tier Comparison

| Feature | Basic | Standard | Premium |
|---|---|---|---|
| Queues | Yes | Yes | Yes |
| Topics/Subscriptions | No | Yes | Yes |
| Message size | 256 KB | 256 KB | Up to 100 MB |
| Sessions | No | Yes | Yes |
| Duplicate detection | No | Yes | Yes |
| Transactions | No | Yes | Yes |
| Geo-DR / Geo-Replication | No | No | Yes |
| VNET / Private Endpoints | No | No | Yes |
| Dedicated resources | No | No | Yes (MUs) |
| JMS 2.0 | No | No | Yes |
| Auto-scale | No | No | Yes |
| Pricing model | Pay-per-message | Pay-per-message | Fixed per MU/hour |
| Throughput | Low | Variable (shared) | High, predictable |

---

## 3. Features

### 3.1 Message Properties

**System properties** (set by broker or SDK):
- `MessageId` — Unique ID for duplicate detection
- `SessionId` — Groups messages into a session for FIFO ordering
- `CorrelationId` — Correlates replies to requests (request/reply pattern)
- `To` / `ReplyTo` / `ReplyToSessionId` — Routing metadata
- `Label` / `Subject` — Application-defined label
- `ContentType` — MIME type descriptor
- `TimeToLive` — Message expiry duration
- `ScheduledEnqueueTimeUtc` — Scheduled delivery time
- `DeliveryCount` — Number of delivery attempts
- `EnqueuedTimeUtc` — When message arrived in the broker
- `ExpiresAtUtc` — Computed expiry time
- `LockToken` — Identifier for the message lock (PeekLock mode)
- `SequenceNumber` — Broker-assigned unique sequence number
- `DeadLetterReason` / `DeadLetterErrorDescription` — Populated on dead-lettered messages

**User properties**: Arbitrary key-value pairs (string, int, long, bool, double, DateTime, GUID, byte[]) set by the application. Used by SQL and correlation filters.

### 3.2 Dead-Letter Queue (DLQ)

A secondary subqueue automatically associated with every queue and topic subscription. Cannot be deleted or managed independently.

**System-set dead-letter reasons**:

| Reason | Cause |
|---|---|
| `MaxDeliveryCountExceeded` | Delivery count exceeds max (default 10) |
| `TTLExpiredException` | Message TTL expired (when dead-lettering on expiration enabled) |
| `HeaderSizeExceeded` | Stream size quota exceeded |
| `Session ID is null` | Message missing SessionId sent to session-enabled entity |
| `MaxTransferHopCountExceeded` | Message forwarded through more than 4 hops |

**Application-level dead-lettering** (in .NET):
```csharp
await receiver.DeadLetterMessageAsync(message,
    deadLetterReason: "ValidationFailed",
    deadLetterErrorDescription: "Missing required field: OrderId");
```

**Resubmitting DLQ messages**: Use Service Bus Explorer (available in Azure Portal), custom code, or tools like ServicePulse (NServiceBus/MassTransit).

**DLQ path examples**:
```
myqueue/$deadletterqueue
mytopic/Subscriptions/mysubscription/$deadletterqueue
```

**DLQ does not respect TTL** — messages stay until explicitly consumed.

### 3.3 Scheduled Messages

Submit a message for delayed processing with `ScheduledEnqueueTimeUtc`:

```csharp
// .NET: Schedule a message for future delivery
var message = new ServiceBusMessage("payload");
message.ScheduledEnqueueTime = DateTimeOffset.UtcNow.AddHours(2);
long sequenceNumber = await sender.ScheduleMessageAsync(message, message.ScheduledEnqueueTime);

// Cancel a scheduled message
await sender.CancelScheduledMessageAsync(sequenceNumber);
```

- Available on Standard and Premium tiers
- Counted in duplicate detection window

### 3.4 Message Deferral

Allows a receiver to set aside a message without abandoning it, for retrieval later by sequence number.

- Deferred messages remain in the main queue (not in DLQ subqueue)
- Cannot be received through normal receive operations
- Must be received by sequence number
- Deferred messages do NOT expire/move to DLQ when TTL lapses (by design)

```csharp
// Defer a message
long seqNum = message.SequenceNumber;
await receiver.DeferMessageAsync(message);

// Receive the deferred message later
ServiceBusReceivedMessage deferred = await receiver.ReceiveDeferredMessageAsync(seqNum);
```

### 3.5 Duplicate Detection

When enabled, the broker tracks `MessageId` values for a configurable time window (1 minute to 7 days, default 10 minutes) and silently discards duplicates.

- Not available on Basic tier
- Sender can resend the same `MessageId` safely after transient failures
- Scheduled messages are included in duplicate detection
- Configurable window: `DuplicateDetectionHistoryTimeWindow`

```csharp
// Enable duplicate detection when creating a queue
var options = new CreateQueueOptions("myqueue")
{
    RequiresDuplicateDetection = true,
    DuplicateDetectionHistoryTimeWindow = TimeSpan.FromMinutes(10)
};
```

### 3.6 Auto-Forwarding

Chain a queue or subscription to another queue or topic in the same namespace.

- Service Bus automatically moves messages from source to destination
- Messages exceeding 4 hops are dead-lettered (`MaxTransferHopCountExceeded`)
- Useful for aggregation patterns (fan-in from multiple subscriptions to one queue)
- Destination must be in the same namespace

```csharp
// Enable auto-forwarding when creating a subscription
var options = new CreateSubscriptionOptions("mytopic", "mysub")
{
    ForwardTo = "destinationqueue"
};
```

### 3.7 Message Sessions (FIFO + State)

Sessions provide guaranteed FIFO ordering within a group of related messages while allowing parallel processing across groups.

- Requires `RequiresSession = true` on the queue or topic subscription
- Sender sets `SessionId` property on each message
- Receivers acquire exclusive session locks
- Session state: opaque binary blob stored by broker (up to 256 KB on Standard, 100 MB on Premium)
- `SetSessionStateAsync` / `GetSessionStateAsync` for checkpoint/resume patterns

```csharp
// Sender: tag messages with SessionId
var message = new ServiceBusMessage("order event")
{
    SessionId = "order-12345"
};

// Receiver: accept a specific session
ServiceBusSessionReceiver sessionReceiver = await client.AcceptSessionAsync("myqueue", "order-12345");

// Or accept the next available session
ServiceBusSessionReceiver sessionReceiver = await client.AcceptNextSessionAsync("myqueue");

// Read and update session state
byte[] state = (await sessionReceiver.GetSessionStateAsync())?.ToArray();
await sessionReceiver.SetSessionStateAsync(BinaryData.FromBytes(newState));
```

### 3.8 Transactions

Service Bus supports atomic transactions scoped to a single messaging entity.

Operations within a transaction scope:
1. Receive a message from a queue
2. Post results to one or more queues/topics
3. Move the input message (complete/dead-letter/defer)

All succeed or all fail atomically. Dead-lettering and auto-forwarding are also transactional internally.

```csharp
// .NET transaction example
using var txScope = new TransactionScope(TransactionScopeAsyncFlowOption.Enabled);
await receiver.CompleteMessageAsync(receivedMessage);
await sender.SendMessageAsync(new ServiceBusMessage("result"));
txScope.Complete();
```

**Note**: Transactions are not supported with Receive-and-Delete mode.

### 3.9 Batching

Send multiple messages in a single round-trip:

```csharp
// .NET: Create and send a batch
using ServiceBusMessageBatch batch = await sender.CreateMessageBatchAsync();
for (int i = 0; i < 100; i++)
{
    if (!batch.TryAddMessage(new ServiceBusMessage($"Message {i}")))
        throw new Exception("Message too large for batch");
}
await sender.SendMessagesAsync(batch);
```

- Batch size is limited by message size constraints
- Large message batching is NOT supported on Premium tier for 100 MB messages

### 3.10 Large Messages (Premium Only)

- Supports messages up to 100 MB (AMQP protocol only)
- HTTP/SBMP limited to 1 MB even on Premium
- Enable per-queue or per-topic via `MaxMessageSizeInKilobytes` property
- Decreases throughput and increases latency compared to small messages
- Batching is not supported with large messages

---

## 4. Messaging Patterns

### 4.1 Competing Consumers

Multiple consumer instances read from the same queue. Each message delivered to exactly one consumer (exclusive ownership via PeekLock).

- Enables horizontal scaling of message processing
- Workers process at their own rate
- Transactional processing: if consumer fails before completing, message returns to queue
- Service Bus supports up to 1,000 concurrent connections per messaging entity

### 4.2 Topic Filters

Three filter types for subscription rules:

**Boolean Filters**:
```csharp
// TrueRuleFilter: select all messages
await adminClient.CreateRuleAsync("mytopic", "mysub",
    new CreateRuleOptions("AllMessages", new TrueRuleFilter()));

// FalseRuleFilter: select no messages
await adminClient.CreateRuleAsync("mytopic", "mysub",
    new CreateRuleOptions("NoMessages", new FalseRuleFilter()));
```

**Correlation Filters** (most efficient — use when possible):
```csharp
// Match on multiple properties (logical AND)
var filter = new CorrelationRuleFilter
{
    Label = "Important",
    ReplyTo = "johndoe@contoso.com"
};
filter.ApplicationProperties["color"] = "Red";

// Equivalent SQL: sys.ReplyTo = 'johndoe@contoso.com' AND sys.Label = 'Important' AND color = 'Red'
```

**SQL Filters** (flexible but lower throughput — each evaluation costs 1 credit):
```csharp
// SQL filter examples
var filter = new SqlRuleFilter("color = 'blue' AND quantity > 10");
var filter2 = new SqlRuleFilter("sys.label LIKE '%urgent%'");
var filter3 = new SqlRuleFilter("StoreId NOT IN ('Store1','Store2','Store3')");
var filter4 = new SqlRuleFilter("color IS NOT NULL");

// SQL filter with action (modify message metadata)
var action = new SqlRuleAction("SET sys.label = 'Processed'; SET priority = 1");
```

**Performance note**: SQL filters significantly reduce throughput at namespace level. Prefer correlation filters wherever possible.

### 4.3 Session-Based Processing (Sequential Convoy)

Processing related messages in strict FIFO order while allowing parallelism across sessions.

Use case: Processing events for specific orders, users, or workflows in sequence.

```csharp
// Processor with session support
var processorOptions = new ServiceBusSessionProcessorOptions
{
    MaxConcurrentSessions = 10,           // parallel sessions
    MaxConcurrentCallsPerSession = 1      // sequential within session
};

await using var processor = client.CreateSessionProcessor("myqueue", processorOptions);
processor.ProcessMessageAsync += async args =>
{
    // Messages within this session arrive in order
    Console.WriteLine($"Session: {args.Message.SessionId}, Body: {args.Message.Body}");
    await args.CompleteMessageAsync(args.Message);
};
await processor.StartProcessingAsync();
```

### 4.4 Request/Reply Pattern

```csharp
// Sender: include ReplyTo and CorrelationId
var request = new ServiceBusMessage("request-payload")
{
    ReplyTo = "reply-queue",
    CorrelationId = Guid.NewGuid().ToString(),
    SessionId = sessionId  // if reply queue is session-enabled
};
await requestSender.SendMessageAsync(request);

// Responder: echo CorrelationId back
var reply = new ServiceBusMessage("response-payload")
{
    CorrelationId = incomingMessage.CorrelationId,
    SessionId = incomingMessage.ReplyToSessionId
};
await replySender.SendMessageAsync(reply);
```

### 4.5 Transfer Dead-Lettering

When auto-forwarding fails (destination disabled, deleted, or size exceeded), messages are moved to a Transfer Dead-Letter Queue (TDLQ) on the source queue, not the destination DLQ.

TDLQ path: `<source-queue>/$deadletterqueue` with `DeadLetterReason = MaxTransferHopCountExceeded`

---

## 5. SDKs

### 5.1 .NET — Azure.Messaging.ServiceBus

**Package**: `Azure.Messaging.ServiceBus` (NuGet)  
**Minimum platforms**: .NET Core 2.0, .NET Framework 4.6.1

```csharp
using Azure.Messaging.ServiceBus;
using Azure.Identity;

// Create client (singleton — reuse for lifetime of app)
var client = new ServiceBusClient(
    "<namespace>.servicebus.windows.net",
    new DefaultAzureCredential());

// --- SEND ---
await using var sender = client.CreateSender("myqueue");

// Send a single message
await sender.SendMessageAsync(new ServiceBusMessage("Hello, Service Bus!"));

// Send a batch
using var batch = await sender.CreateMessageBatchAsync();
batch.TryAddMessage(new ServiceBusMessage("Message 1"));
batch.TryAddMessage(new ServiceBusMessage("Message 2"));
await sender.SendMessagesAsync(batch);

// --- RECEIVE (Processor — recommended) ---
await using var processor = client.CreateProcessor("myqueue", new ServiceBusProcessorOptions
{
    AutoCompleteMessages = false,
    MaxConcurrentCalls = 5,
    PrefetchCount = 50
});

processor.ProcessMessageAsync += async args =>
{
    Console.WriteLine($"Received: {args.Message.Body}");
    await args.CompleteMessageAsync(args.Message);
};

processor.ProcessErrorAsync += args =>
{
    Console.WriteLine($"Error: {args.Exception}");
    return Task.CompletedTask;
};

await processor.StartProcessingAsync();

// --- RECEIVE (Manual) ---
await using var receiver = client.CreateReceiver("myqueue", new ServiceBusReceiverOptions
{
    ReceiveMode = ServiceBusReceiveMode.PeekLock,
    PrefetchCount = 20
});

ServiceBusReceivedMessage msg = await receiver.ReceiveMessageAsync(maxWaitTime: TimeSpan.FromSeconds(30));
if (msg != null)
{
    // Process...
    await receiver.CompleteMessageAsync(msg);
    // Or: await receiver.AbandonMessageAsync(msg);
    // Or: await receiver.DeadLetterMessageAsync(msg, "reason", "description");
    // Or: await receiver.DeferMessageAsync(msg);
}

// --- TOPICS ---
await using var topicSender = client.CreateSender("mytopic");
await topicSender.SendMessageAsync(new ServiceBusMessage("event"));

await using var subReceiver = client.CreateReceiver("mytopic", "mysubscription");

// --- ADMINISTRATION ---
var adminClient = new ServiceBusAdministrationClient(
    "<namespace>.servicebus.windows.net",
    new DefaultAzureCredential());

await adminClient.CreateQueueAsync(new CreateQueueOptions("myqueue")
{
    LockDuration = TimeSpan.FromSeconds(60),
    MaxDeliveryCount = 10,
    RequiresDuplicateDetection = true,
    DuplicateDetectionHistoryTimeWindow = TimeSpan.FromMinutes(10),
    RequiresSession = false,
    DefaultMessageTimeToLive = TimeSpan.FromDays(7),
    DeadLetteringOnMessageExpiration = true
});
```

### 5.2 Python — azure-servicebus

**Package**: `azure-servicebus` (PyPI)  
**Minimum**: Python 3.8+

```python
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.identity import DefaultAzureCredential

NAMESPACE = "<namespace>.servicebus.windows.net"
QUEUE_NAME = "myqueue"

credential = DefaultAzureCredential()

# Send
with ServiceBusClient(NAMESPACE, credential) as client:
    with client.get_queue_sender(QUEUE_NAME) as sender:
        # Single message
        sender.send_messages(ServiceBusMessage("Hello from Python"))

        # Batch
        with sender.create_message_batch() as batch:
            batch.add_message(ServiceBusMessage("Message 1"))
            batch.add_message(ServiceBusMessage("Message 2"))
        sender.send_messages(batch)

# Receive (sync)
with ServiceBusClient(NAMESPACE, credential) as client:
    with client.get_queue_receiver(QUEUE_NAME, max_wait_time=5) as receiver:
        for msg in receiver:
            print(f"Received: {msg}")
            receiver.complete_message(msg)

# Topics
with ServiceBusClient(NAMESPACE, credential) as client:
    with client.get_topic_sender("mytopic") as sender:
        sender.send_messages(ServiceBusMessage("topic event"))
    with client.get_subscription_receiver("mytopic", "mysub") as receiver:
        for msg in receiver:
            receiver.complete_message(msg)

# Async variant
from azure.servicebus.aio import ServiceBusClient as AsyncServiceBusClient

async def receive_async():
    async with AsyncServiceBusClient(NAMESPACE, credential) as client:
        async with client.get_queue_receiver(QUEUE_NAME) as receiver:
            async for msg in receiver:
                print(f"Received: {msg}")
                await receiver.complete_message(msg)
```

**Thread safety note**: Python client requires locks when using threads and concurrent async operations.

### 5.3 JavaScript/TypeScript — @azure/service-bus

**Package**: `@azure/service-bus` (npm)

```typescript
import { ServiceBusClient, ServiceBusMessage } from "@azure/service-bus";
import { DefaultAzureCredential } from "@azure/identity";

const namespace = "<namespace>.servicebus.windows.net";
const credential = new DefaultAzureCredential();
const client = new ServiceBusClient(namespace, credential);

// Send
const sender = client.createSender("myqueue");
await sender.sendMessages({ body: "Hello from TypeScript" } as ServiceBusMessage);
await sender.sendMessages([
    { body: "Batch message 1" },
    { body: "Batch message 2" }
]);
await sender.close();

// Receive with processor (recommended)
const processor = client.createReceiver("myqueue");
processor.subscribe({
    processMessage: async (msg) => {
        console.log(`Received: ${msg.body}`);
        await processor.completeMessage(msg);
    },
    processError: async (err) => {
        console.error(err.error);
    }
});

// Receive messages manually
const receiver = client.createReceiver("myqueue");
const messages = await receiver.receiveMessages(10, { maxWaitTimeInMs: 5000 });
for (const msg of messages) {
    console.log(msg.body);
    await receiver.completeMessage(msg);
}

// Sessions
const sessionReceiver = await client.acceptNextSession("myqueue");
const sessionMessages = await sessionReceiver.receiveMessages(5);

// Topics
const topicSender = client.createSender("mytopic");
await topicSender.sendMessages({ body: "topic event" });
const subReceiver = client.createReceiver("mytopic", "mysubscription");

await client.close();
```

### 5.4 Java — azure-messaging-servicebus

**Package**: `com.azure:azure-messaging-servicebus` (Maven)

```java
import com.azure.messaging.servicebus.*;
import com.azure.identity.DefaultAzureCredentialBuilder;

String namespace = "<namespace>.servicebus.windows.net";
String queueName = "myqueue";

// Build client
ServiceBusClientBuilder builder = new ServiceBusClientBuilder()
    .fullyQualifiedNamespace(namespace)
    .credential(new DefaultAzureCredentialBuilder().build());

// Send
ServiceBusSenderClient sender = builder.sender().queueName(queueName).buildClient();
sender.sendMessage(new ServiceBusMessage("Hello from Java"));

ServiceBusMessageBatch batch = sender.createMessageBatch();
batch.tryAddMessage(new ServiceBusMessage("Batch 1"));
batch.tryAddMessage(new ServiceBusMessage("Batch 2"));
sender.sendMessages(batch);
sender.close();

// Receive with processor
ServiceBusProcessorClient processor = builder
    .processor()
    .queueName(queueName)
    .processMessage(ctx -> {
        System.out.println("Received: " + ctx.getMessage().getBody());
        ctx.complete();
    })
    .processError(ctx -> System.err.println("Error: " + ctx.getException()))
    .buildProcessorClient();

processor.start();
// ... processor.stop();

// Sessions (JMS 2.0 on Premium)
ServiceBusSessionReceiverClient sessionClient = builder
    .sessionReceiver()
    .queueName(queueName)
    .buildClient();
ServiceBusReceiverClient sessionReceiver = sessionClient.acceptNextSession();
```

---

## 6. Management

### 6.1 Azure CLI (az servicebus)

```bash
# Create resource group and namespace
az group create --name MyRG --location eastus

az servicebus namespace create \
  --resource-group MyRG \
  --name myNamespace \
  --location eastus \
  --sku Premium \
  --capacity 1

# Create a queue
az servicebus queue create \
  --resource-group MyRG \
  --namespace-name myNamespace \
  --name myQueue \
  --lock-duration PT1M \
  --max-delivery-count 10 \
  --enable-dead-lettering-on-message-expiration true \
  --default-message-time-to-live P7D

# Create a topic
az servicebus topic create \
  --resource-group MyRG \
  --namespace-name myNamespace \
  --name myTopic

# Create a subscription
az servicebus topic subscription create \
  --resource-group MyRG \
  --namespace-name myNamespace \
  --topic-name myTopic \
  --name mySubscription

# Create a SQL filter rule on a subscription
az servicebus topic subscription rule create \
  --resource-group MyRG \
  --namespace-name myNamespace \
  --topic-name myTopic \
  --subscription-name mySubscription \
  --name colorFilter \
  --filter-sql-expression "color = 'blue'"

# Create a correlation filter rule
az servicebus topic subscription rule create \
  --resource-group MyRG \
  --namespace-name myNamespace \
  --topic-name myTopic \
  --subscription-name S1 \
  --name correlationFilter \
  --action-sql-expression "SET label = 'processed'" \
  --filter-correlation-id "order-*"

# Get connection string
az servicebus namespace authorization-rule keys list \
  --resource-group MyRG \
  --namespace-name myNamespace \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString \
  --output tsv

# Show DLQ message count for a subscription
az servicebus topic subscription show \
  --resource-group MyRG \
  --namespace-name myNamespace \
  --topic-name myTopic \
  --name mySubscription \
  --query "countDetails.deadLetterMessageCount"

# List queues
az servicebus queue list \
  --resource-group MyRG \
  --namespace-name myNamespace \
  --output table

# Delete a queue
az servicebus queue delete \
  --resource-group MyRG \
  --namespace-name myNamespace \
  --name myQueue

# Initiate geo-DR pairing (CLI)
az servicebus georecovery-alias create \
  --resource-group MyRG \
  --namespace-name myPrimaryNamespace \
  --alias myAlias \
  --partner-namespace /subscriptions/<sub-id>/resourceGroups/MyRG/providers/Microsoft.ServiceBus/namespaces/mySecondaryNamespace

# Trigger failover
az servicebus georecovery-alias fail-over \
  --resource-group MyRG \
  --namespace-name mySecondaryNamespace \
  --alias myAlias
```

### 6.2 Bicep Template

```bicep
param namespaceName string
param location string = resourceGroup().location
param skuName string = 'Premium'
param capacity int = 1

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: namespaceName
  location: location
  sku: {
    name: skuName
    tier: skuName
    capacity: capacity
  }
  properties: {
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
    zoneRedundant: true
  }
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'myQueue'
  properties: {
    lockDuration: 'PT1M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P7D'
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 10
    enableBatchedOperations: true
    enablePartitioning: false
  }
}

resource serviceBusTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'myTopic'
  properties: {
    defaultMessageTimeToLive: 'P7D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    enableBatchedOperations: true
    enablePartitioning: false
  }
}

resource topicSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: serviceBusTopic
  name: 'mySubscription'
  properties: {
    lockDuration: 'PT1M'
    maxDeliveryCount: 10
    deadLetteringOnMessageExpiration: true
    deadLetteringOnFilterEvaluationExceptions: false
    requiresSession: false
    defaultMessageTimeToLive: 'P7D'
  }
}

// Deploy
// az deployment group create --resource-group MyRG --template-file main.bicep
```

### 6.3 Azure Portal

- Create and manage namespaces, queues, topics, subscriptions, rules
- View message counts (active, DLQ, scheduled, deferred)
- Send/receive/peek test messages via Service Bus Explorer (built-in)
- Configure IP firewall (Premium only via portal; other tiers require ARM/CLI/PowerShell)
- Set up Geo-Disaster Recovery pairing
- View real-time metrics and configure alerts

### 6.4 Service Bus Explorer (Tool)

Standalone open-source tool by Paolo Salvatori, available at: https://github.com/paolosalvatori/ServiceBusExplorer

- Browse entities (queues, topics, subscriptions)
- Send, receive, peek messages
- Inspect DLQ contents
- Move/resubmit DLQ messages
- View message properties and body
- Also available as built-in feature within the Azure Portal

### 6.5 Azure Monitor Metrics

Key metrics for `Microsoft.ServiceBus/Namespaces`:

| Metric | Description | Tier |
|---|---|---|
| `IncomingMessages` | Messages sent to Service Bus | All |
| `OutgoingMessages` | Messages received from Service Bus | All |
| `ActiveMessages` | Messages in active state (ready for delivery) | All |
| `DeadletteredMessages` | Messages in DLQ | All |
| `ScheduledMessages` | Scheduled (future delivery) messages | All |
| `Messages` | Total messages (all states) | All |
| `ThrottledRequests` | Requests throttled (with `MessagingErrorSubCode` dimension) | All |
| `ServerErrors` | Server-side errors | All |
| `UserErrors` | Client-side errors | All |
| `SuccessfulRequests` | Successful requests | All |
| `IncomingRequests` | Total requests | All |
| `ActiveConnections` | Active connections | All |
| `NamespaceCpuUsage` | CPU usage % | Premium |
| `NamespaceMemoryUsage` | Memory usage % | Premium |
| `ServerSendLatency` | Send operation latency (ms) | All |
| `ReplicationLagCount` | Geo-replication lag (message count) | Premium |
| `ReplicationLagDuration` | Geo-replication lag (seconds) | Premium |
| `Size` | Entity size in bytes | All |

**Alert thresholds (Premium)**:
- Alert on `NamespaceCpuUsage > 70%` → Consider scaling up MUs
- Alert on `ThrottledRequests > 0` sustained → Investigate capacity
- Alert on `DeadletteredMessages > threshold` → Processing failures

**Log Analytics tables**:
- `AZMSOperationalLogs` — Management operations (create, update, delete entities)
- `AZMSRuntimeAuditLogs` — Data plane operations (send, receive; Premium only)
- `AZMSDiagnosticErrorLogs` — Client errors, throttling, quota exceeded
- `AZMSVNetConnectionEvents` — VNet/IP filter connection logs
- `AzureDiagnostics` — Legacy unified table (all categories)

---

## 7. Best Practices

### 7.1 Tier Selection

- **Basic**: Dev/test only; no topics, sessions, transactions, or duplicate detection
- **Standard**: Low-medium throughput; variable latency acceptable; pay-per-operation; shared infrastructure with throttling risk
- **Premium**: Production workloads; predictable latency/throughput; dedicated MUs; required for VNET, large messages, Geo-DR

### 7.2 Connection Management

- **Singleton pattern**: `ServiceBusClient`, `ServiceBusSender`, `ServiceBusReceiver`, `ServiceBusProcessor` should be singletons for the application lifetime
- Never recreate clients per message — connection setup is expensive
- Register as singletons in DI containers:
  ```csharp
  services.AddSingleton(sp => new ServiceBusClient(connectionString));
  ```
- Exception: `ServiceBusSessionReceiver` has session lifetime; dispose after session completes

### 7.3 Receive Mode Selection

**PeekLock** (default, recommended):
- Two-phase: lock message → process → complete/abandon/dead-letter/defer
- At-least-once delivery semantics
- Required for transactions, deferral, and dead-lettering
- Messages redelivered if lock expires or consumer crashes
- Combine with duplicate detection for exactly-once semantics

**ReceiveAndDelete**:
- Single-phase: mark consumed and return in one operation
- At-most-once delivery — messages lost if consumer crashes before processing
- Higher throughput
- No transaction support
- Use only when occasional message loss is acceptable

### 7.4 Prefetch Configuration

Prefetch fills a local client cache to reduce round-trips:

```csharp
var options = new ServiceBusProcessorOptions
{
    PrefetchCount = 20 * maxProcessingRatePerReceiver * numberOfReceivers
    // Example: 20 * 10 msg/s * 3 receivers = 600
};
```

**Guidelines**:
- Default `PrefetchCount = 0` (no prefetch)
- With 60-second lock: `PrefetchCount = 20 × max_processing_rate × receiver_count`
- For low-latency with single client: `PrefetchCount = 20 × processing_rate`
- For low-latency with multiple clients: `PrefetchCount = 0` (prevent starvation)
- Prefetch locks messages server-side; set smaller than messages processable within lock timeout
- Only available for AMQP protocol; HTTP does not support prefetch

### 7.5 Partition Strategy

- Use partitioned namespaces on Premium for high throughput
- Multiple partitions with lower MUs outperform a single partition with higher MUs
- For extreme scale, shard entities across multiple namespaces
- Consider cross-region sharding for global workloads

### 7.6 Session Design

- Set session IDs to natural business keys (order ID, customer ID, workflow instance ID)
- Keep sessions short-lived; long sessions reduce parallelism
- Use `SetSessionStateAsync` for checkpointing — store last processed sequence number
- Design for idempotent message handling within sessions (redelivery can occur)
- On Premium, session state can be up to 100 MB; on Standard up to 256 KB

### 7.7 Filter Design

- Prefer **correlation filters** over SQL filters for performance
- SQL filters: each evaluation costs 1 credit in Standard; reduces throughput significantly
- Avoid running many SQL filters on a single subscription
- Use `TrueRuleFilter` on subscriptions that should receive all messages
- Use `FalseRuleFilter` to disable a subscription without deleting it

### 7.8 Error Handling and Retry

**SDK default retry policy**: Exponential backoff with jitter.

```csharp
// Customize retry policy
var clientOptions = new ServiceBusClientOptions
{
    RetryOptions = new ServiceBusRetryOptions
    {
        Mode = ServiceBusRetryMode.Exponential,
        MaxRetries = 5,
        Delay = TimeSpan.FromMilliseconds(800),
        MaxDelay = TimeSpan.FromSeconds(60),
        TryTimeout = TimeSpan.FromSeconds(30)
    }
};
var client = new ServiceBusClient(connectionString, clientOptions);
```

- Transient exceptions are retried automatically
- Non-transient exceptions surface immediately to the application
- On throttling (error code 50009): SDK retries with 10-second backoff by default

### 7.9 Performance Optimization

1. **Use AMQP** — maintains persistent connections; supports batching and prefetch
2. **Reuse clients** — avoid per-message connection creation
3. **Use async operations** — concurrent send/receive via `Task.WhenAll`
4. **Batch sends** — `CreateMessageBatchAsync` + `SendMessagesAsync`
5. **Set appropriate prefetch** — reduces round trips; formula above
6. **Use Premium for production** — dedicated resources, predictable latency
7. **Use partitioned namespaces** — improves throughput on Premium
8. **Limit SQL filters** — favor correlation filters
9. **Set `MaxConcurrentCalls`** — tune parallelism of processor
10. **Scale MUs reactively** — monitor CPU; add MUs when CPU > 70%

### 7.10 Cost Optimization

- **Standard tier**: Pay per million operations (cheaper for low volume)
- **Premium tier**: Fixed hourly cost per MU (cheaper above ~10M operations/month)
- Use auto-scale rules on Premium to reduce MUs during off-peak hours
- Avoid unnecessary SQL filter evaluations (each costs 1 credit per message per filter)
- Set appropriate TTL — don't retain messages indefinitely
- Enable `AutoDeleteOnIdle` on unused subscriptions to prevent silent accumulation
- Monitor `Size` metric — large entity sizes increase storage cost

---

## 8. Diagnostics

### 8.1 Dead-Letter Investigation

```bash
# Check DLQ count via CLI
az servicebus queue show \
  --resource-group MyRG \
  --namespace-name myNamespace \
  --name myQueue \
  --query "countDetails.deadLetterMessageCount"

# Peek DLQ using SDK
await using var dlqReceiver = client.CreateReceiver(
    ServiceBusClient.GetDeadLetterQueueName("myqueue"),
    new ServiceBusReceiverOptions { ReceiveMode = ServiceBusReceiveMode.PeekLock });

var dlqMessages = await dlqReceiver.PeekMessagesAsync(maxMessages: 50);
foreach (var msg in dlqMessages)
{
    Console.WriteLine($"DLQ Reason: {msg.DeadLetterReason}");
    Console.WriteLine($"DLQ Description: {msg.DeadLetterErrorDescription}");
    Console.WriteLine($"Delivery Count: {msg.DeliveryCount}");
    Console.WriteLine($"Body: {msg.Body}");
}
```

**Log Analytics query for DLQ spikes**:
```kusto
AZMSDiagnosticErrorLogs
| where OperationResult == "ClientError"
| where ActivityName == "ReceiveMessage"
| summarize ErrorCount = sum(ErrorCount) by bin(TimeGenerated, 5m), EntityName
| order by TimeGenerated desc
```

### 8.2 Message Expiration

When `DeadLetteringOnMessageExpiration = true`, expired messages move to DLQ with `TTLExpiredException`.

Check entity-level TTL configuration:
```bash
az servicebus queue show \
  --resource-group MyRG \
  --namespace-name myNamespace \
  --name myQueue \
  --query "{TTL: defaultMessageTimeToLive, DeadLetterOnExpiry: deadLetteringOnMessageExpiration}"
```

### 8.3 Throttling (429 / Error 50009)

**Standard tier throttling** — credit-based:
- 1,000 credits per second per namespace
- Data operations (send, receive, peek): 1 credit per message
- Management operations: 10 credits
- SQL filter evaluations: 1 credit per filter per message

**Throttling error response**:
```
The request was terminated because the entity is being throttled. 
Error code: 50009. Please wait 2 seconds and try again.
```

**Detection**:
```kusto
// Azure Monitor - throttled requests over time
AzureMetrics
| where MetricName == "ThrottledRequests"
| where ResourceId contains "myNamespace"
| summarize ThrottledCount = sum(Total) by bin(TimeGenerated, 1m)
| order by TimeGenerated desc
```

**Resolution**:
- Standard: SDK auto-retries with exponential backoff; if persistent, migrate to Premium
- Premium: Scale up MUs when CPU > 70%; enable auto-scale

### 8.4 Connectivity Issues

Common connectivity problems and diagnostics:

**Connection refused / timeout**:
- Verify firewall allows outbound port 5671 (AMQP) and 5672, or port 443 (AMQP over WebSocket)
- Check IP filter rules on namespace
- Verify private endpoint configuration if using VNET

**Authentication failures (401)**:
- Verify SAS key or Managed Identity permissions
- Required RBAC roles:
  - `Azure Service Bus Data Sender` — send messages
  - `Azure Service Bus Data Receiver` — receive messages
  - `Azure Service Bus Data Owner` — full access

**MessageLockLostException**:
- Lock expired before message was completed
- Increase lock duration or reduce processing time
- Implement lock renewal:
  ```csharp
  // Renew lock (not needed when using ServiceBusProcessor — it auto-renews)
  await receiver.RenewMessageLockAsync(message);
  ```

**SessionLockLostException**:
- Session lock expired; session acquired by another processor
- Reduce session processing time or increase session lock timeout

### 8.5 Diagnostic Logs Configuration

Enable diagnostic logs via CLI:
```bash
az monitor diagnostic-settings create \
  --resource /subscriptions/<sub>/resourceGroups/MyRG/providers/Microsoft.ServiceBus/namespaces/myNamespace \
  --name myDiagSettings \
  --logs '[{"category":"OperationalLogs","enabled":true},{"category":"RuntimeAuditLogs","enabled":true},{"category":"DiagnosticErrorLogs","enabled":true}]' \
  --workspace /subscriptions/<sub>/resourceGroups/MyRG/providers/Microsoft.OperationalInsights/workspaces/myWorkspace
```

Log categories:
- `OperationalLogs` — Management operations (create/update/delete entities); free to export
- `RuntimeAuditLogs` — Data plane operations (send/receive); Premium only; costs to export
- `DiagnosticErrorLogs` — Client errors, throttling, quota exceeded; costs to export
- `VNetAndIPFilteringLogs` — VNet/IP connection events; free to export

### 8.6 Application Insights Integration

Service Bus SDK supports distributed tracing via OpenTelemetry/Activity API.

```csharp
// .NET: Enable Application Insights with distributed tracing
services.AddApplicationInsightsTelemetry();

// The SDK automatically propagates trace context via message properties:
// Diagnostic-Id and Correlation-Context headers
// Application Insights will show end-to-end transaction traces
// spanning message send → queue → receive → process
```

**Key Application Insights queries**:
```kusto
// Failed dependencies (Service Bus send failures)
dependencies
| where type == "Azure Service Bus"
| where success == false
| summarize count() by name, resultCode
| order by count_ desc

// Message processing latency distribution
dependencies
| where type == "Azure Service Bus"
| where name contains "Receive"
| summarize percentiles(duration, 50, 95, 99) by bin(timestamp, 5m)
```

---

## 9. Security

### 9.1 Authentication Options

1. **Managed Identity + RBAC** (recommended for production):
   ```csharp
   var client = new ServiceBusClient(
       "<namespace>.servicebus.windows.net",
       new DefaultAzureCredential());
   ```

2. **SAS (Shared Access Signature)**:
   - Connection string: `Endpoint=sb://<namespace>.servicebus.windows.net/;SharedAccessKeyName=<name>;SharedAccessKey=<key>`
   - Use for legacy integrations or when Managed Identity is unavailable
   - Scope SAS keys to specific entities, not the entire namespace

3. **Microsoft Entra ID (AAD)**:
   - RBAC roles: `Azure Service Bus Data Sender`, `Azure Service Bus Data Receiver`, `Azure Service Bus Data Owner`

### 9.2 Network Security (Premium Only)

- **Service Endpoints**: Route traffic through Azure backbone; block public internet access
- **Private Endpoints**: Full private connectivity within VNET (no public IP)
- **IP Firewall**: Allow/deny based on source IP ranges
- **Disable local auth**: Force AAD-only authentication with `disableLocalAuth: true`

### 9.3 Encryption

- All data at rest encrypted with Microsoft-managed keys (default)
- Customer-managed keys (CMK/BYOK) supported on Premium
- TLS 1.2+ enforced for all connections

---

## 10. Limits and Quotas (Quick Reference)

| Limit | Basic | Standard | Premium |
|---|---|---|---|
| Namespace throughput | Shared | Shared | Dedicated (per MU) |
| Max message size | 256 KB | 256 KB | 100 MB (AMQP) |
| Max queue size | 1–80 GB | 1–80 GB | 1–80 GB |
| Topics/subscriptions per namespace | 0 | 1,000 | 1,000 |
| Subscriptions per topic | N/A | 2,000 | 2,000 |
| Concurrent connections per entity | 1,000 | 1,000 | 1,000+ |
| Max delivery count | 1–2,000 | 1–2,000 | 1–2,000 |
| Lock duration | N/A | 5 min max | 5 min max |
| Session state size | N/A | 256 KB | 100 MB |
| Duplicate detection window | N/A | 7 days max | 7 days max |
| Standard throttle limit | N/A | 1,000 credits/sec | By MU allocation |
| Messaging units | N/A | N/A | 1, 2, 4, 8, 16 |
| Geo-DR / Geo-Replication | No | No | Yes |

---

## 11. Key Integration Points

- **Azure Functions**: Trigger on queue/topic messages; output bindings for sending
- **Azure Logic Apps**: Built-in Service Bus connector
- **Azure Event Grid**: Service Bus can emit events to Event Grid on message activity
- **Azure Stream Analytics**: Input from Service Bus
- **Power Platform**: Built-in connector
- **Dynamics 365**: Business events integration
- **NServiceBus / MassTransit**: Third-party frameworks built on top of the .NET SDK

---

*Sources consulted*:
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-messaging-overview
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-premium-messaging
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-queues-topics-subscriptions
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-performance-improvements
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-throttling
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-dead-letter-queues
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-geo-dr
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/monitor-service-bus-reference
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/topic-filters
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/message-sessions
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/advanced-features-overview
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/duplicate-detection
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/message-deferral
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-auto-forwarding
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-transactions
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-prefetch
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-quickstart-cli
- https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-resource-manager-namespace-queue-bicep
- https://learn.microsoft.com/en-us/azure/architecture/patterns/competing-consumers
- https://learn.microsoft.com/en-us/azure/architecture/patterns/sequential-convoy
