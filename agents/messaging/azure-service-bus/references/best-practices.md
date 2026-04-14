# Azure Service Bus Best Practices Reference

## Tier Selection

- **Basic:** Dev/test only. No topics, sessions, transactions, duplicate detection.
- **Standard:** Low-medium throughput. Pay-per-operation. Shared infrastructure with throttling risk.
- **Premium:** Production workloads. Predictable latency/throughput. Dedicated MUs. Required for VNET, large messages, geo-DR.

## Connection Management

**Singleton pattern:** `ServiceBusClient`, `ServiceBusSender`, `ServiceBusReceiver`, `ServiceBusProcessor` should be singletons for application lifetime.

```csharp
// Register as singleton in DI
services.AddSingleton(sp => new ServiceBusClient(
    "<namespace>.servicebus.windows.net",
    new DefaultAzureCredential()));
```

Never recreate clients per message. Exception: `ServiceBusSessionReceiver` has session lifetime.

## Receive Modes

**PeekLock (default, recommended):** Two-phase: lock -> process -> complete/abandon/dead-letter/defer. At-least-once. Required for transactions.

**ReceiveAndDelete:** Single-phase. At-most-once. Higher throughput. Use only when occasional loss is acceptable.

## Prefetch Tuning

```csharp
var options = new ServiceBusProcessorOptions { PrefetchCount = 600 };
// Formula: 20 * max_processing_rate * receiver_count
```

- Default: 0 (no prefetch). Start with 20x processing rate.
- Prefetch locks messages server-side. Size smaller than processable within lock timeout.
- For multiple competing receivers: `PrefetchCount = 0` to prevent starvation.
- Only available for AMQP protocol.

## Session Design

- Set session IDs to natural business keys (order ID, customer ID)
- Keep sessions short-lived; long sessions reduce parallelism
- Use `SetSessionStateAsync` for checkpointing
- Design for idempotent handling (redelivery within sessions possible)

```csharp
var processorOptions = new ServiceBusSessionProcessorOptions
{
    MaxConcurrentSessions = 10,
    MaxConcurrentCallsPerSession = 1
};
```

## Security

**Authentication:** Prefer Azure AD (`DefaultAzureCredential`) over connection strings/SAS. RBAC roles: Data Owner, Data Sender, Data Receiver.

**Network:** Premium tier supports VNET service endpoints, private endpoints, IP firewall.

**Encryption:** Azure SSE (AES-256) at rest by default. Customer-managed keys on Premium.

## SDK Patterns

### .NET
```csharp
await using var client = new ServiceBusClient(ns, new DefaultAzureCredential());
await using var sender = client.CreateSender("myqueue");
await sender.SendMessageAsync(new ServiceBusMessage("Hello"));

await using var processor = client.CreateProcessor("myqueue", new ServiceBusProcessorOptions
{
    AutoCompleteMessages = false, MaxConcurrentCalls = 5, PrefetchCount = 50
});
processor.ProcessMessageAsync += async args => {
    await args.CompleteMessageAsync(args.Message);
};
await processor.StartProcessingAsync();
```

### Python
```python
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.identity import DefaultAzureCredential

with ServiceBusClient(ns, DefaultAzureCredential()) as client:
    with client.get_queue_sender("myqueue") as sender:
        sender.send_messages(ServiceBusMessage("Hello"))
    with client.get_queue_receiver("myqueue", max_wait_time=5) as receiver:
        for msg in receiver:
            receiver.complete_message(msg)
```

## Azure CLI Management

```bash
# Create namespace (Premium)
az servicebus namespace create --resource-group MyRG --name myNS --sku Premium --capacity 1

# Create queue
az servicebus queue create --resource-group MyRG --namespace-name myNS --name myQueue \
  --lock-duration PT1M --max-delivery-count 10 --enable-dead-lettering-on-message-expiration true

# Create topic and subscription with filter
az servicebus topic create --resource-group MyRG --namespace-name myNS --name myTopic
az servicebus topic subscription create --resource-group MyRG --namespace-name myNS \
  --topic-name myTopic --name mySub
az servicebus topic subscription rule create --resource-group MyRG --namespace-name myNS \
  --topic-name myTopic --subscription-name mySub --name colorFilter \
  --filter-sql-expression "color = 'blue'"

# Get connection string
az servicebus namespace authorization-rule keys list --resource-group MyRG \
  --namespace-name myNS --name RootManageSharedAccessKey --query primaryConnectionString -o tsv

# Check DLQ count
az servicebus topic subscription show --resource-group MyRG --namespace-name myNS \
  --topic-name myTopic --name mySub --query "countDetails.deadLetterMessageCount"
```

## Bicep Deployment

```bicep
resource ns 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: namespaceName
  location: location
  sku: { name: 'Premium', tier: 'Premium', capacity: 1 }
  properties: { zoneRedundant: true }
}

resource queue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: ns
  name: 'myQueue'
  properties: {
    lockDuration: 'PT1M'
    maxDeliveryCount: 10
    deadLetteringOnMessageExpiration: true
    defaultMessageTimeToLive: 'P7D'
  }
}
```
