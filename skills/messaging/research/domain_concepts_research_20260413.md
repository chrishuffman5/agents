# Messaging & Event Streaming — Domain Concepts Research

Deep reference for cross-technology messaging theory. Covers concepts that span RabbitMQ, NATS, Azure Service Bus, AWS SQS/SNS, GCP Pub/Sub, Apache Pulsar, Apache Kafka, and Redis Streams. Technology-specific implementation details are documented in technology agent files; this file covers the conceptual layer that enables comparing, selecting, and architecting with any of them.

---

## 1. Messaging Patterns

### 1.1 Point-to-Point (Queue)

A message is sent to a named queue. Exactly one consumer receives and processes each message. The broker holds the message until a consumer acknowledges it or the message expires.

```
Producer --> [Queue] --> Consumer A
                     (not Consumer B — only one processes each message)
```

**Key properties:**
- Load distribution: multiple consumers compete for messages from the same queue
- Ordered delivery is possible but constrains parallelism
- Work is guaranteed to happen exactly once (by one consumer) when combined with acknowledgment

**Implementations:** RabbitMQ direct/default exchange, SQS standard queue, Azure Service Bus queue, NATS JetStream consumer with queue group

### 1.2 Publish/Subscribe (Topic)

A message is published to a topic. All interested subscribers receive a copy. Subscribers are decoupled from publishers — a publisher does not know who (or how many) will receive the message.

```
Publisher --> [Topic] --> Subscriber A (gets a copy)
                      --> Subscriber B (gets a copy)
                      --> Subscriber C (gets a copy)
```

**Key properties:**
- Fan-out: one message, many receivers
- Subscribers can join/leave independently without modifying the publisher
- If no subscribers exist at publish time, messages may be lost unless the broker retains them

**Implementations:** RabbitMQ fanout exchange, SNS, GCP Pub/Sub, Kafka topics (consumer groups as subscription model), Pulsar topics, NATS subjects, Redis Pub/Sub (non-persistent)

### 1.3 Request/Reply

A producer sends a request and waits for a response. The reply is directed back to the original sender via a reply-to address.

```
Requester --> [Request Queue] --> Responder
          <-- [Reply Queue]   <--
```

**Implementation pattern:**
1. Requester generates a correlation ID
2. Requester sets `reply-to` header to a temporary queue or inbox
3. Responder reads, processes, and sends response to the reply-to address with the same correlation ID
4. Requester correlates response by correlation ID

**Trade-offs:** Tightly couples timing (requester must wait). Often better implemented with async patterns (send request, receive event later). NATS has built-in request/reply primitives that avoid the need to manage reply queues manually.

### 1.4 Competing Consumers

Multiple consumer instances read from a single queue or consumer group. The broker distributes messages across consumers, enabling horizontal scaling of processing without duplication.

```
[Queue] --> Consumer A (processes msg 1, 4, 7...)
        --> Consumer B (processes msg 2, 5, 8...)
        --> Consumer C (processes msg 3, 6, 9...)
```

**Ordering implication:** Competing consumers on a single queue destroys total ordering unless the broker enforces grouping (see Section 4, Message Ordering). SQS FIFO message groups and Service Bus sessions provide ordering within a partition while still allowing competing consumers across partitions.

### 1.5 Fan-Out

A message arrives at a single point and is replicated to multiple destinations (queues, topics, or subscribers). Fan-out can happen at:

- **Exchange level** (RabbitMQ fanout exchange): messages are copied to all bound queues
- **Topic level** (SNS → multiple SQS queues, Kafka topic → multiple consumer groups)
- **Application level** (consumer reads from one queue, writes to N queues)

### 1.6 Content-Based Routing

The broker (or a routing component) inspects message headers or body to determine where to send the message. Enables selective delivery without requiring separate queues per message type.

**Implementations:**
- RabbitMQ headers exchange (route by header values, not routing key)
- RabbitMQ topic exchange (route by routing key pattern: `orders.#`, `orders.created.*`)
- Azure Service Bus topic subscriptions with SQL filter expressions
- SNS message filtering (subscription filter policy on attributes)
- Kafka Streams / ksqlDB for stream-time routing
- NATS subject hierarchy (consumers subscribe to `orders.>`, `orders.created.us-east`)

### 1.7 Message Routing Topologies

```
TOPOLOGY COMPARISON

Direct (Queue):
  P --> [Q1] --> C1

Fanout:
  P --> [Exchange/Topic] --> [Q1] --> C1
                         --> [Q2] --> C2

Topic / Pattern:
  P (key: order.created.us) --> [Exchange]
    binding: order.*.us    --> [Q-US] --> C-US
    binding: order.#       --> [Q-ALL] --> C-ALL

Scatter/Gather:
  P --> [Request Topic] --> Worker1 \
                        --> Worker2  --> [Reply Aggregator] --> Response
                        --> Worker3 /
```

---

## 2. Delivery Guarantees

### 2.1 At-Most-Once

A message is delivered zero or one times. The broker does not retry on failure. Messages may be lost.

**When to use:** Fire-and-forget telemetry, metrics, or events where occasional loss is acceptable and re-processing would be harmful (duplicate sensor readings skewing aggregates). Maximizes throughput.

**Mechanism:** Producer sends without waiting for acknowledgment (fire-and-forget). Consumer pre-acknowledges before processing (or the broker auto-acks on delivery).

| Broker | At-Most-Once Configuration |
|---|---|
| RabbitMQ | `autoAck=true` on `basicConsume`; or fire-and-forget with no publisher confirms |
| NATS Core | Default (no JetStream). Messages not persisted; if no subscriber, dropped |
| SQS | Not natively supported; standard SQS is at-least-once |
| Kafka | `acks=0` on producer; consumer auto-commits offset before processing |
| Pulsar | `ackTimeout` not set, `subscriptionType=Shared` with auto-ack |

### 2.2 At-Least-Once

A message is delivered one or more times. The broker retries until the consumer acknowledges. Duplicates are possible.

**Mechanism:** Producer waits for broker acknowledgment of receipt (publish confirm). Consumer explicitly acknowledges only after successful processing. Broker redelivers if consumer crashes before acknowledging.

**Idempotent consumers required:** Because duplicates arrive, consumer logic must produce the same outcome when processing a message multiple times. Strategies:
- **Deduplication via unique message ID:** Store processed IDs in a fast store (Redis SET, database unique constraint). On each message, check before processing.
- **Idempotent operations:** Use upserts instead of inserts, set-value instead of increment, conditional writes (compare-and-swap).
- **Natural idempotency:** Some operations are inherently idempotent (setting a status field to the same value, creating a record that already exists with no side effects).

| Broker | At-Least-Once Configuration |
|---|---|
| RabbitMQ | Publisher confirms enabled; consumer uses explicit `basicAck` after processing |
| NATS JetStream | `AckPolicy: explicit`; redelivery on timeout |
| SQS Standard | Default behavior. Messages stay in queue until explicitly deleted |
| Azure Service Bus | Peek-lock mode (default). Message locked during processing, deleted on success |
| GCP Pub/Sub | Default. Message redelivered until acknowledgment deadline |
| Kafka | `acks=1` or `acks=all`; consumer commits offset after processing |
| Pulsar | Default acknowledgment model |

### 2.3 Exactly-Once Semantics (EOS)

A message is processed exactly once — no loss, no duplicates — even across failures and restarts. This is the hardest guarantee and requires cooperation between producer, broker, and consumer.

**True EOS requires:**
1. **Idempotent producer:** The broker deduplicates retried publishes (producer assigns sequence numbers; broker rejects duplicates)
2. **Transactional publish:** Producer publishes atomically across multiple partitions/queues
3. **Transactional consume-then-produce:** Consumer reads, processes, and publishes results atomically, so offset/ack advances only when the whole transaction commits

**Kafka EOS (strongest implementation):**
- `enable.idempotence=true` + producer ID and sequence numbers deduplicate producer retries
- Transactions: `initTransactions()`, `beginTransaction()`, `send()`, `sendOffsetsToTransaction()`, `commitTransaction()` — atomic read-process-write
- Consumer isolation: `isolation.level=read_committed` — consumers only see committed transaction messages

**Azure Service Bus EOS (sessions + deduplication):**
- `requiresDuplicateDetection: true` with a deduplication window (up to 7 days)
- Message ID is the deduplication key — broker discards messages with duplicate IDs within the window
- Combine with sessions for ordered, exactly-once processing per entity

**SQS FIFO EOS:**
- `MessageDeduplicationId` (explicit) or SHA-256 of body (automatic)
- 5-minute deduplication window
- Exactly-once delivery within the deduplication window

**GCP Pub/Sub:** Does not provide true EOS at the broker level. Achieves EOS via subscriber-side deduplication using message IDs plus idempotent consumer logic.

**NATS JetStream:** Supports message deduplication via `Nats-Msg-Id` header and a configurable deduplication window.

**The honest limitation of EOS:** True EOS across broker and external systems (databases, APIs) requires a distributed transaction or outbox pattern. Most brokers provide EOS within the broker boundary only. If a consumer crashes after committing the message but before writing to the database, exactly-once within the broker is irrelevant.

### 2.4 Deduplication Strategies

| Strategy | Mechanism | Best For |
|---|---|---|
| Message ID tracking | Store processed message IDs in a DB/cache with TTL | At-least-once consumers where IDs are reliable |
| Idempotency keys | Business-level keys (order ID, event ID) in a unique constraint | Domain-natural deduplication |
| Conditional writes | `INSERT ... WHERE NOT EXISTS` or optimistic locking | Database-level deduplication |
| Broker-level dedup | SQS FIFO MessageDeduplicationId, Service Bus, NATS | Short-window dedup at source |
| Content hashing | Hash message body, track hash for a window | When message IDs are unavailable |

---

## 3. Event-Driven Architecture

### 3.1 Event Notification vs. Event-Carried State Transfer

**Event Notification** — the event tells receivers that something happened, but does not carry the full state. Receivers must query the source for details.

```json
// Event Notification — thin
{
  "eventType": "order.created",
  "orderId": "ord-9921",
  "occurredAt": "2026-04-13T14:22:00Z"
}
// Receiver must call GET /orders/ord-9921 to get full order
```

**Event-Carried State Transfer (ECST)** — the event carries all the data receivers need, eliminating the need for a callback.

```json
// ECST — fat event
{
  "eventType": "order.created",
  "orderId": "ord-9921",
  "customerId": "cust-441",
  "items": [...],
  "totalAmount": 149.99,
  "shippingAddress": {...},
  "occurredAt": "2026-04-13T14:22:00Z"
}
```

**Trade-off table:**

| Dimension | Event Notification | Event-Carried State Transfer |
|---|---|---|
| Payload size | Small | Large |
| Receiver autonomy | Low (must call back) | High (self-contained) |
| Coupling | Temporal decoupling only | Full decoupling |
| Data freshness | Always fresh (callback) | Stale risk if schema changes |
| Network traffic | 2 round-trips per event | 1 message per event |
| Schema evolution risk | Low | Higher (envelope must evolve) |
| Best for | Notifications, audits | Microservices, cross-domain |

**In practice:** ECST dominates in microservices architectures where services must remain independently deployable. Event notifications are common for internal domain events where the receiver is within the same bounded context.

### 3.2 Domain Events

A domain event records something that happened in the business domain, expressed in ubiquitous language. Domain events:
- Are named in past tense (`OrderPlaced`, `PaymentDeclined`, `ShipmentDispatched`)
- Capture the state change that triggered them
- Are immutable — they record history, not instructions

**Domain event vs. command vs. query:**

| Concept | Direction | Mutating | Example |
|---|---|---|---|
| Command | Sender → Receiver | Intent to change | `PlaceOrder`, `CancelShipment` |
| Query | Sender → Receiver | Read-only | `GetOrderStatus` |
| Domain Event | Publisher → Subscribers | Already happened | `OrderPlaced`, `PaymentFailed` |

### 3.3 Event Sourcing

Instead of storing the current state of an entity, store the sequence of events that produced the state. Current state is reconstructed by replaying events.

```
Traditional: [accounts table: { id: 1, balance: 450 }]

Event Sourcing:
  events:
    1. AccountOpened { id: 1, initialBalance: 1000 }
    2. WithdrawalProcessed { id: 1, amount: 300 }
    3. DepositProcessed { id: 1, amount: 200 }
    4. FeeCharged { id: 1, amount: 50 }
  Replay events 1-4 → balance = 850... wait, let's recalculate:
  1000 - 300 + 200 - 50 = 850 (not 450 — example is illustrative)
```

**Benefits:**
- Complete audit trail by design
- Temporal queries ("what was the account balance on Jan 1st?")
- Event replay enables rebuilding projections
- Natural fit for messaging — events are already the source of truth

**Challenges:**
- Event schema evolution is critical and hard to reverse
- Snapshots required for entities with long event histories
- Eventual consistency between event store and read projections
- Increased operational complexity

**Event store vs. message broker:**
- An event store (EventStoreDB, Marten, Axon) is optimized for append-only event streams per aggregate with ordered reads
- A message broker is optimized for fan-out delivery and consumption
- Kafka can serve as both, but optimizing for one role compromises the other

### 3.4 CQRS (Command Query Responsibility Segregation)

Separate the write model (commands → events → event store) from the read model (projections built from events, optimized for query patterns).

```
Write Side:                        Read Side:
Command Handler                    Event Handler (projection)
  --> Aggregate (apply rules)        --> Read DB (denormalized views)
  --> Event Store (append)           --> Query API
  --> Event Bus (publish)
```

**CQRS without event sourcing:** Valid. Separate read/write models with a synchronization mechanism. The read model is a materialized view or replica optimized for queries.

**CQRS + Event Sourcing:** Common combination. Events are both the write medium and the projection source. Eventual consistency between write and read sides is the main operational challenge.

### 3.5 Saga Pattern

A saga manages a long-running business transaction across multiple services, where each step produces an event or command that triggers the next step. On failure, compensating transactions roll back completed steps.

**Choreography (decentralized):** Each service listens for events and decides what to do next. No central coordinator.

```
OrderService         PaymentService        InventoryService
   |                      |                      |
[OrderCreated] -->        |                      |
                   [PaymentProcessed] -->         |
                                          [InventoryReserved] -->
                                          (success: emit OrderConfirmed)

On failure:
InventoryService: [InventoryReservationFailed] -->
                   PaymentService: [PaymentRefunded] -->
                      OrderService: [OrderCancelled]
```

**Orchestration (centralized):** A saga orchestrator (process manager) sends commands to each service and handles responses, coordinating the workflow.

```
SagaOrchestrator
  --> sends: ProcessPayment (to PaymentService)
  <-- receives: PaymentProcessed or PaymentFailed
  --> sends: ReserveInventory (to InventoryService)
  <-- receives: InventoryReserved or InventoryFailed
  --> sends: ConfirmOrder (to OrderService)
```

**Comparison:**

| Dimension | Choreography | Orchestration |
|---|---|---|
| Coupling | Loose (event-driven) | Tighter (orchestrator knows steps) |
| Visibility | Harder to trace flow | Centralized flow definition |
| Failure handling | Distributed (each service handles) | Centralized (orchestrator decides) |
| Testing | Harder (emergent behavior) | Easier (test orchestrator in isolation) |
| Scalability | Scales naturally | Orchestrator can become bottleneck |
| Best for | Simple, stable flows | Complex flows with many failure paths |

---

## 4. Message Ordering

### 4.1 Total Ordering

Every message is delivered to every consumer in the exact order it was sent. Requires a single, sequential consumer or a single partition/shard.

**Total ordering trade-off:** Prevents horizontal consumer scaling. One consumer per ordered stream. Used when ordering is an absolute requirement (financial ledgers, audit logs).

**Brokers with total ordering (within a queue/partition):**
- Kafka: total order within a partition
- SQS FIFO: total order within a message group
- Azure Service Bus: total order within a session
- Pulsar: total order within a partition
- RabbitMQ: total order within a single-consumer queue (multi-consumer destroys order)

### 4.2 Partition Ordering

Messages are partitioned by a key, with total ordering guaranteed within each partition but not across partitions. Enables horizontal scaling while preserving ordering for related messages.

```
Partition by customer_id:
  customer_id=1001 --> Partition 0 --> Consumer A (ordered for 1001)
  customer_id=1002 --> Partition 1 --> Consumer B (ordered for 1002)
  customer_id=1003 --> Partition 0 --> Consumer A (ordered for 1003, interleaved)
```

**Key insight:** Messages for the same entity (same order ID, same customer ID) go to the same partition, ensuring they are processed in order without blocking other entities.

**Implementations:**
- Kafka: `key` field determines partition via hash(key) % numPartitions
- Pulsar: key-based routing to partitions
- SQS FIFO: `MessageGroupId` maps to an ordering group
- Azure Service Bus: `SessionId` maps to a session (ordered delivery within session)
- Kinesis: partition key maps to shard

### 4.3 Causal Ordering

Messages are delivered in an order that respects causality: if event B was caused by event A, all consumers see A before B, even if A and B are on different partitions.

**Challenge:** Causal ordering across partitions requires vector clocks or logical timestamps, which most brokers do not implement natively. Usually achieved at the application level via:
- Lamport timestamps included in event headers
- Vector clocks propagated through event chains
- Saga/process managers that enforce sequential dispatch

### 4.4 Ordering vs. Parallelism Trade-offs

```
ORDERING vs. THROUGHPUT SPECTRUM

Total Order, 1 Consumer       Partition Order, N Consumers      No Order, N Consumers
[Highest consistency]         [Balanced]                        [Highest throughput]
     Sequential                  Parallel within keys               Fully parallel
     1 consumer/partition        N consumers, 1 per partition        Competing consumers
     Low throughput              Scales with partitions              Maximum throughput
```

**Decision rule:** Determine the smallest unit of ordering required. Usually it is ordering within an entity (order ID, account ID), not total global ordering. This allows partition-based parallelism.

### 4.5 Message Groups and Sessions

**SQS FIFO Message Groups:** Messages with the same `MessageGroupId` are processed in order. Different message groups can be processed in parallel by different consumers. One consumer processes one message group at a time (the group is "locked" to that consumer).

**Azure Service Bus Sessions:** `SessionId` on a message assigns it to a session. Sessions are received as a unit. The consumer explicitly accepts a session, processes all its messages in order, then releases it. Multiple sessions are processed in parallel by different consumers.

**Kafka Consumer Groups:** Partition is the unit. Each partition is consumed by exactly one consumer in a group. Adding partitions increases parallelism; partition count is the upper bound on consumer group parallelism.

---

## 5. Dead-Letter Handling

### 5.1 Dead-Letter Queue (DLQ) Pattern

A DLQ is a holding queue for messages that cannot be processed successfully. Messages land in the DLQ when:
- Max delivery attempts are exceeded
- The message fails validation (poison message)
- The message is explicitly rejected/negatively acknowledged
- The message exceeds its TTL (time-to-live) without being consumed

```
Normal flow:
Producer --> [Main Queue] --> Consumer (success) --> Ack

Failure flow:
Producer --> [Main Queue] --> Consumer (fail) --> Retry n times
                                              --> [Dead-Letter Queue] --> Alert/Monitor
```

**DLQ implementations:**

| Broker | DLQ Mechanism |
|---|---|
| RabbitMQ | Dead Letter Exchange (DLX) — queue attribute `x-dead-letter-exchange` routes rejected/expired messages to a configured exchange |
| SQS | Each queue has an associated DLQ. Set via `RedrivePolicy` with `maxReceiveCount` |
| Azure Service Bus | Built-in DLQ per queue/topic subscription. Accessed via `/<entity>/$deadletterqueue` |
| GCP Pub/Sub | Dead-letter topic configured on subscription with `max_delivery_attempts` |
| NATS JetStream | No native DLQ; implement via consumer with `MaxDeliver` limit, then route to a separate stream |
| Kafka | No native DLQ; implement by routing failed messages to a `<topic>-dlt` topic in consumer error handler |
| Pulsar | `deadLetterPolicy` on consumer with `maxRedeliverCount` and dead letter topic |

### 5.2 Poison Message Handling

A poison message causes the consumer to crash or fail on every processing attempt, blocking the queue. Detection strategies:

1. **Delivery count tracking:** Broker tracks redelivery count. After N attempts, route to DLQ. (Native in SQS, Service Bus, Pulsar, GCP Pub/Sub.)
2. **Consumer-side circuit:** Consumer tracks failure counts per message ID. After N failures, explicitly send to DLQ and acknowledge the original.
3. **Content validation at entry:** Validate schema at message intake (using schema registry or validation gateway) to reject malformed messages before they enter the queue.

### 5.3 Retry Strategies

**Immediate retry:** Reprocess as soon as processing fails. Only appropriate when the failure is transient and extremely short-lived (milliseconds).

**Fixed-delay retry:** Wait a constant interval between attempts (e.g., retry after 30 seconds). Simple but does not adapt to sustained failures.

**Exponential backoff:**
```
Attempt 1: wait 1s
Attempt 2: wait 2s
Attempt 3: wait 4s
Attempt 4: wait 8s
...
Attempt N: wait min(base * 2^(N-1), max_delay)
```
Standard for cloud services. Prevents thundering herd when many consumers fail simultaneously.

**Exponential backoff with jitter:**
```
wait = random(0, min(cap, base * 2^attempt))
```
Avoids synchronized retry storms across many consumers.

**Implementation patterns:**

| Pattern | Description | Broker Support |
|---|---|---|
| In-place retry | Nack + requeue. Simple but can block queue | RabbitMQ, NATS JetStream |
| Delayed retry queue | Send to `topic-retry-30s` queue, consumer waits, re-publishes | SQS (via delay), RabbitMQ (x-delayed-message plugin) |
| Retry topic chain | `topic` → `topic-retry-1` (30s delay) → `topic-retry-2` (60s delay) → DLQ | Common Kafka/Pulsar pattern |
| Visibility timeout | Message becomes invisible during retry window | SQS, Azure Service Bus |

**SQS retry pattern:**
```
MaxReceiveCount: 5          (number of delivery attempts)
VisibilityTimeout: 300s     (lock period per attempt)
RedrivePolicy → DLQ         (after 5 failures)
```

**Azure Service Bus retry:**
```
MaxDeliveryCount: 10        (default, configurable up to 2000)
LockDuration: 5m            (processing window)
MessageTimeToLive: 14d      (max age before DLQ)
```

### 5.4 Circuit Breaker Pattern

When a downstream dependency (database, API) fails repeatedly, stop sending messages to that service and fail fast until the dependency recovers. Prevents resource exhaustion and cascading failures.

```
State machine:
CLOSED (normal) --> failure threshold exceeded --> OPEN (reject requests)
                                                --> timeout --> HALF-OPEN (probe)
                                                               success --> CLOSED
                                                               failure --> OPEN
```

In messaging contexts: the consumer watches its own error rate. When the circuit opens, the consumer stops acknowledging messages (letting them return to the queue or visibility timeout) rather than DLQ-ing them immediately. A circuit breaker library (Polly, Resilience4j, go-circuit) manages state.

### 5.5 DLQ Monitoring and Redrive

**Monitoring:**
- Alert when DLQ message count exceeds zero (strict) or a threshold (lenient)
- CloudWatch Alarm on `ApproximateNumberOfMessagesVisible` for SQS DLQ
- Azure Monitor Alert on `DeadLetteredMessageCount` for Service Bus
- Grafana/Prometheus via broker metrics exporter for RabbitMQ/Kafka/Pulsar

**Redrive (replay from DLQ):**
The process of re-routing messages from the DLQ back to the main queue after the underlying issue is resolved. Steps:
1. Identify and fix the root cause (code bug, downstream outage, schema mismatch)
2. Optionally inspect/transform messages if they need correction
3. Redrive with throttling to avoid overwhelming the repaired consumer
4. Monitor consumer health and DLQ refill rate during redrive

**SQS Redrive:** Built-in "Start DLQ Redrive" in AWS Console or via API. Moves messages from DLQ back to source queue.
**Service Bus:** Use the Azure Service Bus Explorer or SDK to read DLQ messages and resend to original entity.
**RabbitMQ:** `shovel` plugin or manual consumer that reads from DLQ exchange and re-publishes to the original exchange.

---

## 6. Broker Selection Framework

### 6.1 Key Evaluation Dimensions

| Dimension | Questions to Ask |
|---|---|
| Throughput | Messages/sec at target payload size? Peak vs. sustained? |
| Latency | P50, P99, P999 requirements? Sub-millisecond vs. single-digit ms vs. tens of ms? |
| Ordering | Global, partition-level, or none? Entities requiring ordering per key? |
| Delivery guarantees | At-most-once, at-least-once, or exactly-once? |
| Message retention | Fire-and-forget vs. hours vs. days vs. indefinite replay? |
| Protocol support | AMQP, MQTT, HTTP, JMS, native SDK only? |
| Managed vs. self-hosted | Team has ops capacity? Cloud-locked acceptable? |
| Ecosystem | Cloud vendor alignment, language SDKs, connector ecosystem |
| Cost model | Per-message, per-GB, per-connection, compute-based? |
| Compliance | Encryption at rest, VPC isolation, data residency, HIPAA/PCI? |

### 6.2 Broker Comparison Table

| Broker | Type | Throughput | Latency | Retention | Ordering | Managed Option | Protocol |
|---|---|---|---|---|---|---|---|
| RabbitMQ | Traditional broker | Medium (50K msg/s) | Very low (<1ms) | Until consumed | Queue-level | CloudAMQP, AWS MQ | AMQP 0-9-1, MQTT, STOMP |
| NATS / JetStream | Lightweight broker | Very high (10M+ msg/s core) | Very low (<1ms) | Core: none; JS: configurable | Subject-level | Synadia Cloud | NATS protocol |
| Azure Service Bus | Managed broker | Medium (up to 1 GB/s Premium) | Low (few ms) | Up to 14 days | Sessions (per-session) | Native managed | AMQP 1.0, HTTP |
| AWS SQS | Managed queue | High (unlimited with FIFO limits) | Low (few ms) | Up to 14 days | FIFO per group | Native managed | HTTPS |
| AWS SNS | Managed pub/sub | High | Low | None (fire-and-forget) | None | Native managed | HTTPS |
| GCP Pub/Sub | Managed pub/sub | Very high (auto-scales) | Low-medium | Up to 31 days | Within ordering key | Native managed | HTTP, gRPC |
| Apache Kafka | Event streaming | Very high (millions/s) | Low (few ms with tuning) | Indefinite (disk) | Partition-level | Confluent, MSK, Aiven | Kafka protocol, REST |
| Apache Pulsar | Event streaming | Very high | Very low (BookKeeper) | Indefinite (tiered) | Partition-level | StreamNative, Aiven | Pulsar, Kafka compat, AMQP, MQTT |
| Redis Streams | Lightweight streaming | High (single-node bound) | Very low (<1ms) | Configurable (MAXLEN) | Stream-level | Redis Cloud, ElastiCache | Redis protocol (RESP) |

### 6.3 Decision Tree

```
START: What is the primary use case?

1. SIMPLE TASK QUEUE (one producer, competing consumers, work distribution)
   |-- Cloud-agnostic or on-prem? --> RabbitMQ
   |-- AWS? --> SQS
   |-- Azure? --> Service Bus Queue
   |-- Need zero-admin? --> SQS / Service Bus

2. PUB/SUB NOTIFICATIONS (one event, many unrelated subscribers)
   |-- Cloud-agnostic? --> NATS or RabbitMQ fanout
   |-- AWS? --> SNS (with SQS subscriptions for durability)
   |-- Azure? --> Service Bus Topics
   |-- GCP? --> GCP Pub/Sub
   |-- Need fan-out to millions of endpoints? --> SNS / GCP Pub/Sub

3. EVENT STREAMING (high volume, replay, temporal queries)
   |-- Need maximum ecosystem / connector support? --> Kafka
   |-- Need very low latency (<1ms) + tiered storage? --> Pulsar
   |-- Fully managed, minimal ops? --> Confluent Cloud / Amazon MSK
   |-- Already on Azure? --> Event Hubs (Kafka-compatible)
   |-- Already on GCP? --> GCP Pub/Sub (streaming mode) or Dataflow

4. REAL-TIME / LOW LATENCY (<1ms, high msg/s)
   |-- Need persistence? --> NATS JetStream or Redis Streams
   |-- Fire-and-forget acceptable? --> NATS Core
   |-- Already using Redis? --> Redis Streams

5. IoT / MQTT DEVICES
   |-- Need MQTT broker? --> RabbitMQ (MQTT plugin), HiveMQ, Mosquitto
   |-- AWS IoT? --> AWS IoT Core (MQTT) + SQS/SNS/Kinesis backend
   |-- Azure IoT? --> Azure IoT Hub + Service Bus/Event Hubs

6. ORDERED PROCESSING PER ENTITY (e.g., all events for order-123 in order)
   |-- Cloud-agnostic, complex routing? --> RabbitMQ (single consumer per queue)
   |-- Kafka-style streaming? --> Kafka/Pulsar (partition by entity ID)
   |-- AWS? --> SQS FIFO with MessageGroupId
   |-- Azure? --> Service Bus Sessions
```

### 6.4 Managed vs. Self-Hosted Trade-Offs

| Factor | Managed (SQS, Service Bus, Confluent) | Self-Hosted (RabbitMQ, Kafka, Pulsar) |
|---|---|---|
| Operational burden | Very low (SLA-backed, auto-scaling) | High (cluster management, upgrades, monitoring) |
| Cost at low volume | Often cheaper (pay-per-use) | Infrastructure baseline cost even at idle |
| Cost at high volume | Can be expensive (per-message pricing) | Fixed infrastructure, potentially cheaper |
| Customization | Limited to service configuration | Full control over broker behavior |
| Latency | Network call to cloud service | In-datacenter, lower latency possible |
| Data sovereignty | Cloud provider controls storage | Full control over data location |
| Disaster recovery | Provider-managed | Team responsibility |
| Ecosystem lock-in | High (AWS, Azure, GCP APIs) | Low (open protocols, multi-cloud) |

---

## 7. Paradigm Comparison

### 7.1 Traditional Message Brokers

**Examples:** RabbitMQ, Azure Service Bus, AWS SQS/SNS

**Architecture model:**
- Store-and-forward: broker receives, stores (briefly), and forwards to consumers
- Messages are consumed and removed (or expired)
- Designed for task queues, decoupled microservices, async processing
- Typically store messages until acknowledged — not for long-term retention or replay

**Strengths:**
- Flexible routing (RabbitMQ exchanges, Service Bus topic filters)
- Protocol diversity (AMQP, MQTT, STOMP, HTTP)
- Low operational overhead with managed options
- Strong delivery guarantees (exactly-once with dedup)
- Native request/reply, message priority, TTL, scheduling

**Weaknesses:**
- No long-term replay after acknowledgment
- Throughput ceiling (compared to streaming platforms)
- Not designed for temporal queries or event sourcing

### 7.2 Event Streaming Platforms

**Examples:** Apache Kafka, Apache Pulsar

**Architecture model:**
- Append-only, durable log: messages are written to an immutable log and retained
- Consumers track their position (offset) independently — can replay from any point
- Multiple consumer groups read the same data independently
- Designed for high-throughput, long-term event storage, stream processing

**Key architectural difference from traditional brokers:**
```
Traditional Broker:
  Producer → [Broker buffers] → Consumer (message deleted after ack)

Streaming Platform:
  Producer → [Immutable Log] → Consumer Group A (at offset 100)
                             → Consumer Group B (at offset 50, replaying)
                             → Consumer Group C (real-time, offset 150)
```

**Strengths:**
- Unlimited replay (within retention period)
- Multiple independent consumer groups
- Very high throughput (millions of messages/sec)
- Natural fit for event sourcing, audit logs, stream processing (Kafka Streams, Flink, Spark Streaming)
- Tiered storage (Pulsar) enables indefinite, cost-effective retention

**Weaknesses:**
- No flexible routing (topic-based only, no content-based routing)
- Higher operational complexity (Kafka: ZooKeeper/KRaft, brokers, schema registry; Pulsar: ZooKeeper, BookKeeper, brokers)
- Not designed for short-lived task queues (extra work to delete processed messages)
- Partition count is not elastic (Kafka); adding partitions is possible but changes routing

**Kafka vs. Pulsar comparison:**

| Dimension | Kafka | Pulsar |
|---|---|---|
| Storage | Broker-local (coupled) | BookKeeper (decoupled) |
| Scaling | Rebalance on add/remove broker | Add brokers without rebalance |
| Multi-tenancy | Namespace isolation only | Native tenant/namespace/topic hierarchy |
| Geo-replication | MirrorMaker (complex) | Native, built-in |
| Tiered storage | Plugin (S3, GCS) | Native tiered storage |
| Latency | 1-5ms typical | <1ms possible (pub-ack roundtrip) |
| Protocol compat | Kafka protocol only | Kafka compat, AMQP, MQTT, Pulsar native |
| Ecosystem | Largest (Kafka Connect, ksqlDB, 200+ connectors) | Growing (Kafka compat is catch-up) |

### 7.3 Lightweight Pub/Sub

**Examples:** NATS Core/JetStream, Redis Pub/Sub, Redis Streams

**Architecture model:**
- Optimized for ultra-low latency and simplicity
- NATS Core: pure publish/subscribe with no persistence — if no subscriber, message is dropped
- NATS JetStream: adds persistence, consumer acknowledgment, replay
- Redis Pub/Sub: in-memory, no persistence, at-most-once
- Redis Streams: persistent, consumer group model, XACK for acknowledgment

**Strengths:**
- Extremely low latency (sub-millisecond)
- Low resource footprint
- Simple operational model
- NATS: excellent for microservices mesh, IoT, edge computing
- Redis Streams: natural extension if already using Redis

**Weaknesses:**
- Redis: memory-bound (not suitable for high-volume retention)
- NATS Core: no durability guarantee — not suitable for critical business events
- Smaller ecosystem than Kafka or traditional brokers
- Less rich feature set (no complex routing, scheduling, priorities)

### 7.4 Paradigm Selection Summary

```
USE CASE → PARADIGM RECOMMENDATION

Short-lived task queues, work distribution:
  --> Traditional broker (RabbitMQ, SQS, Service Bus)

Fan-out notifications to many subscribers:
  --> Traditional broker pub/sub or SNS/GCP Pub/Sub

Event sourcing, audit log, replay required:
  --> Streaming platform (Kafka, Pulsar, Kinesis)

Stream processing, temporal joins, aggregations:
  --> Streaming platform + stream processor (Kafka Streams, Flink, Spark)

Ultra-low latency, IoT, edge, microservice mesh:
  --> Lightweight (NATS, Redis Streams)

Hybrid (task queue + streaming):
  --> Kafka/Pulsar for streaming, SQS/Service Bus for task queues (dual broker)
  --> Or Pulsar (supports both models natively with queuing subscriptions)
```

---

## 8. Cross-Cutting Concerns

### 8.1 Schema Evolution and Message Versioning

Messages cross service boundaries and are stored for variable periods. Schema evolution — adding, removing, or renaming fields — must not break consumers or producers.

**Compatibility rules:**

| Compatibility Type | Description | Safe Changes | Breaking Changes |
|---|---|---|---|
| Backward compatible | New schema can read old messages | Add optional fields with defaults | Remove required fields, change types |
| Forward compatible | Old schema can read new messages | Remove optional fields | Add required fields |
| Full compatible | Both directions | Add/remove optional fields | Any required field change |
| None | No compatibility guarantee | Any change (versioned namespaces) | n/a |

**Schema evolution strategies:**

1. **Schema Registry (Confluent, Apicurio):** Centralized schema store. Producers and consumers register/validate schemas against the registry. Enforces compatibility rules at publish/subscribe time.

2. **Envelope versioning:** Add a `schemaVersion` or `eventVersion` field to every message. Consumers switch on version, handle each version explicitly.

3. **Additive-only (backward compatible) design:** Never remove or rename fields. Add new optional fields. Old consumers ignore unknown fields (lenient deserialization).

4. **Dual publishing:** During transition, publish both old and new format simultaneously. Consumers migrate at their own pace.

5. **Upcasting / event migration:** Consumer-side transformation layer that converts old event versions to the current version before business logic processes them.

**Format considerations:**

| Format | Schema Evolution Support | Human Readable | Binary | Schema Registry |
|---|---|---|---|---|
| JSON | Manual (no enforcement) | Yes | No | Optional |
| Avro | Native (with registry) | No | Yes | Required |
| Protobuf | Native (field numbers) | No | Yes | Optional |
| JSON Schema | Manual (with registry) | Yes | No | Optional |
| Thrift | Similar to Protobuf | No | Yes | Optional |
| MessagePack | None | No | Yes | No |

**Avro + Confluent Schema Registry** is the dominant choice in Kafka ecosystems. **Protobuf** is growing due to gRPC alignment and better language support. **JSON** remains common for simplicity and human readability, at the cost of schema discipline.

### 8.2 Observability

#### Distributed Tracing with Correlation IDs

Every message should carry trace context to enable end-to-end tracing across services.

**Standard: OpenTelemetry (W3C Trace Context)**
```
Headers to propagate:
  traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
  tracestate:  vendor-specific state
```

**Correlation ID pattern (simpler alternative):**
```json
{
  "messageId": "msg-uuid-here",
  "correlationId": "req-uuid-from-originator",  // links to original request
  "causationId": "msg-uuid-of-cause",           // which message caused this one
  "traceId": "otel-trace-id",
  "spanId": "otel-span-id"
}
```

**Propagation rules:**
- `messageId`: unique per message, generated by publisher
- `correlationId`: preserved from the original request/command through the entire chain
- `causationId`: the messageId of the message that triggered this one

#### Metrics to Monitor

| Metric | What it Reveals | Alert On |
|---|---|---|
| Queue depth / consumer lag | Processing backlog, consumer falling behind | Rising trend, threshold breach |
| Message age (oldest message) | Processing SLA breach | Exceeds SLA budget |
| DLQ message count | Processing failures | > 0 (strict) or threshold (lenient) |
| Publish rate | Traffic pattern changes | Anomalous spike or drop |
| Consumer throughput | Consumer performance | Declining trend |
| Redelivery rate | Consumer failure rate | Rising trend |
| End-to-end latency | Processing delay | P99 exceeds SLA |
| Connection count | Client saturation | Near broker connection limit |

#### Distributed Tracing Integration

Use broker middleware or interceptors to inject/extract trace context:
- **Kafka:** `TracingProducerInterceptor` / `TracingConsumerInterceptor` (OpenTelemetry instrumentation)
- **RabbitMQ:** Message header propagation via AMQP headers exchange
- **SQS:** Message attribute `AWSTraceHeader` (X-Ray) or custom attribute (OpenTelemetry)
- **Service Bus:** `Diagnostic-Id` application property (auto-instrumented by Azure SDK)
- **NATS:** Header propagation via NATS 2.2+ header support

### 8.3 Security

#### Encryption in Transit

All communication between clients and broker should use TLS. Configuration:

| Broker | TLS Configuration |
|---|---|
| RabbitMQ | `ssl_options` in rabbitmq.conf; mutual TLS for client auth |
| Kafka | `security.protocol=SSL`; keystore/truststore configuration |
| NATS | TLS config in server config; mTLS for leaf nodes |
| SQS / SNS | TLS-only (HTTPS enforced; no plaintext option) |
| Service Bus | TLS 1.2+ required; enforced by managed service |
| GCP Pub/Sub | TLS enforced (Google-managed) |

#### Encryption at Rest

| Broker | At-Rest Encryption |
|---|---|
| Kafka | Broker-level: OS/filesystem encryption (LUKS, dm-crypt) or cloud provider (EBS encryption). Kafka does not encrypt message payloads natively. Use client-side encryption for field-level. |
| RabbitMQ | OS/filesystem encryption. No native message-level encryption. |
| SQS | SSE-SQS (AWS-managed key) or SSE-KMS (customer-managed key). Enabled per queue. |
| Service Bus | Azure Storage Service Encryption (AES-256). Customer-managed keys available. |
| GCP Pub/Sub | Google-managed encryption by default. CMEK available. |
| Pulsar | Pulsar E2E encryption: producer encrypts per-message with recipient's public key. Broker stores ciphertext. |

**Pulsar's end-to-end encryption model is unique:** the broker never has access to plaintext. Enables zero-trust broker architecture.

#### Authentication

| Broker | Authentication Mechanisms |
|---|---|
| RabbitMQ | Username/password (PLAIN), LDAP plugin, OAuth 2.0 (rabbitmq-auth-backend-oauth2), x.509 client certificates |
| Kafka | SASL/PLAIN, SASL/SCRAM-SHA-256, SASL/SCRAM-SHA-512, SASL/GSSAPI (Kerberos), SASL/OAUTHBEARER, mTLS |
| NATS | Username/password, NKey (Ed25519 keypair), JWT (decentralized auth), TLS client certificates |
| SQS / SNS | AWS IAM (SigV4 signing). No separate broker auth — access is IAM-based |
| Service Bus | SAS (Shared Access Signature), Azure AD (OAuth 2.0 / RBAC) |
| GCP Pub/Sub | Google OAuth 2.0 / Service Account, Workload Identity |
| Pulsar | JWT tokens, Athenz, Kerberos, OAuth 2.0, TLS client certificates |

#### Authorization

| Broker | Authorization Model |
|---|---|
| RabbitMQ | Virtual host level; configure / write / read permissions per user per vhost |
| Kafka | ACLs per resource (topic, consumer group, cluster). Managed by KafkaACL API. |
| NATS | Account-based isolation; import/export with scoped JWTs; per-subject permissions |
| SQS / SNS | IAM policies (resource-based and identity-based). Queue/topic-level granularity. |
| Service Bus | RBAC roles (Owner, Sender, Receiver, Data Owner, Data Sender, Data Receiver) per namespace/entity |
| GCP Pub/Sub | IAM roles (pubsub.publisher, pubsub.subscriber, pubsub.viewer) per topic/subscription |
| Pulsar | Topic-level permissions: produce, consume, functions. Namespace-level policies. |

#### Network Isolation

| Pattern | Description | Implementation |
|---|---|---|
| VPC / Private Endpoint | Broker accessible only from private network | AWS VPC Endpoint for SQS, Azure Private Link for Service Bus, VPC-native Kafka |
| IP allowlisting | Restrict client IPs to known ranges | Kafka listener config, RabbitMQ firewall rules |
| mTLS (mutual TLS) | Both client and server present certificates | Kafka SSL, NATS TLS, RabbitMQ ssl_options |
| Service Mesh | Sidecar proxies handle mTLS transparently | Istio/Envoy with Kafka or NATS |

---

## 9. Architecture Diagrams (Text Form)

### 9.1 Event-Driven Microservices with DLQ

```
[Order Service]
    |
    | publish: OrderPlaced
    v
[Message Broker / Topic]
    |-- [Inventory Service Consumer] --> process --> [DB]
    |                                   on fail (3x) --> [Inventory DLQ]
    |
    |-- [Email Service Consumer] --> process --> [SMTP]
    |                                on fail (3x) --> [Email DLQ]
    |
    |-- [Analytics Consumer] --> process --> [Data Warehouse]

[DLQ Monitor]
    |-- alerts on message count
    |-- manual/automated redrive after fix
```

### 9.2 Saga Choreography

```
[Order Service]       [Payment Service]     [Inventory Service]
  creates order           |                       |
  publishes:              |                       |
  OrderCreated -->        |                       |
                   listens: OrderCreated           |
                   charges card                   |
                   publishes: PaymentProcessed --> |
                                           listens: PaymentProcessed
                                           reserves stock
                                           publishes: StockReserved
                                                    |
[Order Service] <--- listens: StockReserved
  confirms order

On failure at any step:
  publishes: [StepFailed] event
  upstream services listen and publish compensating events (refunds, cancellations)
```

### 9.3 CQRS with Event Streaming

```
WRITE SIDE                                    READ SIDE
----------                                    ---------
Command API                                   Query API
    |                                             |
Command Handler                             Read Model DB (PostgreSQL/Redis)
    |                                             ^
Aggregate (domain rules)                          |
    |                                       Projection Handler
    v                                             ^
Event Store / Kafka Topic                         |
(immutable log)  ----- fan-out to all consumer groups
```

### 9.4 Broker Topology: RabbitMQ Exchanges

```
Direct Exchange:
  Producer (routing_key: "invoice") --> [Direct Exchange] --> [invoice_queue] --> Consumer

Fanout Exchange:
  Producer --> [Fanout Exchange] --> [queue_A] --> Consumer A
                                --> [queue_B] --> Consumer B
                                --> [queue_C] --> Consumer C

Topic Exchange:
  Producer (orders.created.us-east) --> [Topic Exchange]
    binding: orders.*.us-east --> [us_east_queue] --> US East Consumer
    binding: orders.#        --> [all_orders_queue] --> Analytics Consumer

Headers Exchange:
  Producer (headers: {region: "eu", priority: "high"}) --> [Headers Exchange]
    binding: x-match=all, region=eu, priority=high --> [eu_high_queue]
    binding: x-match=any, region=eu             --> [eu_any_queue]
```

---

## 10. Quick Reference: When to Use Which

### Message Retention Requirements

- **Consume and discard:** RabbitMQ, SQS, Service Bus
- **Hours to days:** Any managed broker (SQS 14d, Service Bus 14d, GCP Pub/Sub 31d)
- **Days to months (replay required):** Kafka, Pulsar
- **Indefinite / archival:** Pulsar (tiered storage to object storage), Kafka (tiered storage plugin)

### Protocol / Integration Requirements

- **AMQP (legacy enterprise):** RabbitMQ, Service Bus, Qpid
- **MQTT (IoT devices):** RabbitMQ (plugin), HiveMQ, AWS IoT Core, Mosquitto
- **Kafka protocol (ecosystem compatibility):** Kafka, Pulsar (compat), Azure Event Hubs, Amazon MSK, Confluent
- **HTTP/REST accessible:** SQS, Service Bus, GCP Pub/Sub, SNS, Confluent REST Proxy
- **gRPC:** GCP Pub/Sub, Pulsar (limited)

### Throughput Tiers

| Tier | Target | Broker Options |
|---|---|---|
| Low (<10K msg/s) | Typical microservices | Any; choose by other criteria |
| Medium (10K-500K msg/s) | High-volume services | Kafka, Pulsar, NATS, Service Bus Premium |
| High (500K-10M msg/s) | Streaming pipelines | Kafka, Pulsar, NATS Core |
| Very high (>10M msg/s) | Data ingestion at scale | Kafka + partitioning, Pulsar, NATS |

### Latency Requirements

| Requirement | Options |
|---|---|
| <1ms (intra-datacenter) | NATS Core, Redis Pub/Sub, Redis Streams |
| 1-5ms | RabbitMQ, NATS JetStream, Kafka (tuned), Pulsar |
| 5-50ms | SQS, Service Bus, GCP Pub/Sub, Kafka (default) |
| >50ms acceptable | Any; choose for features, not latency |
