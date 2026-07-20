# Messaging & Event Streaming Concepts Reference

## Messaging Patterns

### Point-to-Point (Queue)

A message is sent to a named queue. Exactly one consumer receives and processes each message. The broker holds the message until a consumer acknowledges it or the message expires.

```
Producer --> [Queue] --> Consumer A
                     (not Consumer B -- only one processes each message)
```

**Key properties:**
- Load distribution: multiple consumers compete for messages from the same queue
- Ordered delivery is possible but constrains parallelism
- Work is guaranteed to happen exactly once (by one consumer) when combined with acknowledgment

**Implementations:** RabbitMQ direct/default exchange, SQS standard queue, Azure Service Bus queue, NATS JetStream consumer with queue group, Pulsar Shared subscription

### Publish/Subscribe (Topic)

A message is published to a topic. All interested subscribers receive a copy. Subscribers are decoupled from publishers.

```
Publisher --> [Topic] --> Subscriber A (gets a copy)
                      --> Subscriber B (gets a copy)
                      --> Subscriber C (gets a copy)
```

**Key properties:**
- Fan-out: one message, many receivers
- Subscribers can join/leave independently
- If no subscribers exist at publish time, messages may be lost unless the broker retains them

**Implementations:** RabbitMQ fanout exchange, SNS, GCP Pub/Sub, Kafka topics (consumer groups as subscription model), Pulsar topics, NATS subjects

### Request/Reply

A producer sends a request and waits for a response via a reply-to address.

```
Requester --> [Request Queue] --> Responder
          <-- [Reply Queue]   <--
```

**Pattern:**
1. Requester generates a correlation ID
2. Requester sets `reply-to` header to a temporary queue or inbox
3. Responder processes and sends response with the same correlation ID
4. Requester correlates response by correlation ID

NATS has built-in request/reply primitives using dynamic inbox subjects. RabbitMQ supports direct reply-to queues. Service Bus uses `ReplyTo` and `CorrelationId` properties.

### Competing Consumers

Multiple consumer instances read from a single queue or consumer group. The broker distributes messages across consumers for horizontal scaling.

**Ordering implication:** Competing consumers on a single queue destroys total ordering unless the broker enforces grouping. SQS FIFO message groups and Service Bus sessions provide ordering within a partition while allowing competing consumers across partitions.

### Fan-Out

A message arrives at a single point and is replicated to multiple destinations:

- **Exchange level** (RabbitMQ fanout exchange): messages copied to all bound queues
- **Topic level** (SNS to multiple SQS queues, Kafka topic to multiple consumer groups)
- **Subscription level** (GCP Pub/Sub multiple subscriptions on one topic)

### Content-Based Routing

The broker inspects message headers or body to determine routing:

- RabbitMQ topic exchange (routing key patterns: `orders.#`, `orders.created.*`)
- RabbitMQ headers exchange (route by header key-value pairs)
- Azure Service Bus topic subscriptions with SQL or correlation filters
- SNS message filtering (subscription filter policy on attributes)
- NATS subject hierarchy (wildcard subscriptions: `orders.>`, `orders.*.us-east`)
- GCP Pub/Sub message attribute filters on subscriptions

## Delivery Guarantees

### At-Most-Once

A message is delivered zero or one times. No retry on failure. Messages may be lost.

**When to use:** Fire-and-forget telemetry, metrics, or events where occasional loss is acceptable.

| Broker | Configuration |
|---|---|
| RabbitMQ | `autoAck=true` on consume; no publisher confirms |
| NATS Core | Default behavior (no JetStream) |
| Kafka | `acks=0` on producer; auto-commit offset before processing |

### At-Least-Once

A message is delivered one or more times. Broker retries until consumer acknowledges. Duplicates are possible.

**Idempotent consumers required.** Strategies:
- Deduplication via unique message ID (Redis SET, database unique constraint)
- Idempotent operations (upserts, set-value, conditional writes)
- Natural idempotency (setting a status to the same value)

| Broker | Configuration |
|---|---|
| RabbitMQ | Publisher confirms; explicit `basicAck` after processing |
| NATS JetStream | `AckPolicy: explicit`; redelivery on timeout |
| SQS Standard | Default. Messages stay until explicitly deleted |
| Azure Service Bus | PeekLock mode (default). Message locked during processing |
| GCP Pub/Sub | Default. Redelivered until ack deadline |
| Kafka | `acks=all`; consumer commits offset after processing |
| Pulsar | Default acknowledgment model |

### Exactly-Once Semantics (EOS)

A message is processed exactly once -- no loss, no duplicates -- even across failures.

**True EOS requires:** idempotent producer (broker deduplicates retries), transactional publish (atomic writes across partitions), and transactional consume-then-produce (offset/ack advances atomically with output).

**Broker-level EOS implementations:**
- **Kafka:** Idempotent producer + transactions + `read_committed` consumers. Strongest implementation.
- **Azure Service Bus:** `requiresDuplicateDetection` with message ID deduplication window (up to 7 days).
- **SQS FIFO:** `MessageDeduplicationId` with 5-minute window.
- **NATS JetStream:** `Nats-Msg-Id` header deduplication plus `AckSync()`.
- **Pulsar:** Producer deduplication via sequence IDs plus transactions.

**The honest limitation:** True EOS across broker and external systems requires outbox pattern or distributed transactions. Most brokers provide EOS within the broker boundary only.

## Event-Driven Architecture

### Event Notification vs. Event-Carried State Transfer

**Event Notification** -- thin event telling receivers something happened; receivers query source for details.
**Event-Carried State Transfer (ECST)** -- fat event carrying all data receivers need.

| Dimension | Event Notification | ECST |
|---|---|---|
| Payload size | Small | Large |
| Receiver autonomy | Low (callback required) | High (self-contained) |
| Coupling | Temporal decoupling only | Full decoupling |
| Schema evolution risk | Low | Higher |
| Best for | Internal domain events | Microservices, cross-domain |

### Domain Events

Domain events record something that happened in the business domain, expressed in past tense (`OrderPlaced`, `PaymentDeclined`). They are immutable records of history, not instructions.

| Concept | Direction | Example |
|---|---|---|
| Command | Sender to Receiver | `PlaceOrder`, `CancelShipment` |
| Query | Sender to Receiver | `GetOrderStatus` |
| Domain Event | Publisher to Subscribers | `OrderPlaced`, `PaymentFailed` |

### Event Sourcing

Store the sequence of events that produced an entity's state instead of the current state. Current state is reconstructed by replaying events.

**Benefits:** Complete audit trail, temporal queries, event replay for rebuilding projections.
**Challenges:** Event schema evolution, snapshots for long histories, eventual consistency.

**Event store vs. message broker:** An event store (EventStoreDB, Marten) is optimized for append-only event streams per aggregate. A message broker is optimized for fan-out delivery. Kafka can serve as both, but optimizing for one role compromises the other.

### CQRS

Separate the write model (commands, events, event store) from the read model (projections optimized for queries). Often combined with event sourcing: events are both the write medium and the projection source.

### Saga Pattern

Manages long-running business transactions across multiple services, with compensating transactions on failure.

**Choreography (decentralized):** Each service listens for events and decides what to do next. Loose coupling but harder to trace.

**Orchestration (centralized):** A saga orchestrator sends commands to each service. Centralized flow but tighter coupling to the orchestrator.

| Dimension | Choreography | Orchestration |
|---|---|---|
| Coupling | Loose (event-driven) | Tighter (orchestrator knows steps) |
| Visibility | Harder to trace | Centralized flow definition |
| Testing | Harder (emergent behavior) | Easier (test orchestrator) |
| Best for | Simple, stable flows | Complex flows with many failure paths |

## Message Ordering

### Total Ordering

Every message delivered in exact send order. Requires single sequential consumer or single partition. Prevents horizontal scaling.

### Partition Ordering

Messages partitioned by key with total ordering within each partition but not across partitions. Enables horizontal scaling while preserving per-entity ordering.

| Broker | Mechanism |
|---|---|
| Kafka | Partition key hash determines partition |
| Pulsar | Key-based routing to partitions |
| SQS FIFO | `MessageGroupId` maps to ordering group |
| Azure Service Bus | `SessionId` maps to session |
| GCP Pub/Sub | Ordering key |
| NATS JetStream | Subject-based with single consumer per subject |

**Decision rule:** Determine the smallest unit of ordering required. Usually ordering within an entity (order ID, account ID), not total global ordering.

### Causal Ordering

Messages delivered in an order that respects causality. Requires vector clocks or logical timestamps at the application level -- most brokers do not implement this natively.

## Dead-Letter Handling

### Dead-Letter Queue Pattern

A DLQ holds messages that cannot be processed successfully after max delivery attempts, validation failure, TTL expiration, or explicit rejection.

| Broker | DLQ Mechanism |
|---|---|
| RabbitMQ | Dead Letter Exchange (DLX) via `x-dead-letter-exchange` queue argument |
| SQS | Separate DLQ queue via `RedrivePolicy` with `maxReceiveCount` |
| Azure Service Bus | Built-in DLQ per entity: `/<entity>/$deadletterqueue` |
| GCP Pub/Sub | Dead-letter topic with `max_delivery_attempts` |
| NATS JetStream | No native DLQ; use `MaxDeliver` + route to separate stream |
| Kafka | No native DLQ; route to `<topic>-dlt` in consumer error handler |
| Pulsar | `deadLetterPolicy` with `maxRedeliverCount` |

### Poison Message Handling

A poison message causes the consumer to fail on every attempt. Detection strategies:
1. **Delivery count tracking:** Broker tracks redelivery count; route to DLQ after N attempts
2. **Consumer-side circuit:** Track failure counts per message ID in consumer logic
3. **Content validation at entry:** Schema registry or validation gateway at publish time

### Retry Strategies

- **Exponential backoff with jitter:** `wait = random(0, min(cap, base * 2^attempt))`. Prevents synchronized retry storms.
- **Retry topic chain:** Route failed messages through delay topics with increasing wait times before final DLQ.
- **Visibility timeout:** Message becomes invisible during retry window (SQS, Service Bus).

### DLQ Monitoring and Redrive

- Alert when DLQ message count exceeds zero or threshold
- Fix root cause before redriving
- Redrive with throttling to avoid overwhelming consumers
- SQS: built-in `StartMessageMoveTask`. Service Bus: Service Bus Explorer. RabbitMQ: shovel plugin.

## Schema Evolution

### Compatibility Types

| Type | Description | Safe Changes |
|---|---|---|
| Backward | New schema reads old data | Add optional fields with defaults, delete fields |
| Forward | Old schema reads new data | Add fields, delete optional fields with defaults |
| Full | Both directions | Add/delete optional fields with defaults |

### Strategies

1. **Schema Registry** (Confluent, Apicurio, Pulsar built-in): Centralized validation at publish/subscribe time
2. **Envelope versioning:** `schemaVersion` field in every message; consumers switch on version
3. **Additive-only:** Never remove or rename fields; old consumers ignore unknown fields
4. **Dual publishing:** Publish old and new format simultaneously during transition

### Format Guidance

| Format | Schema Evolution | Binary | Schema Registry |
|---|---|---|---|
| Avro | Native (with registry) | Yes | Required |
| Protobuf | Native (field numbers) | Yes | Optional |
| JSON Schema | Manual | No | Optional |
| JSON | None enforced | No | No |

## Observability

### Correlation IDs

Every message should carry trace context for end-to-end tracing:

```
messageId:     unique per message (publisher generates)
correlationId: preserved from original request through entire chain
causationId:   messageId of the message that triggered this one
traceId:       OpenTelemetry trace ID (W3C Trace Context)
```

### Key Metrics

| Metric | Alert On |
|---|---|
| Queue depth / consumer lag | Rising trend, threshold breach |
| Message age (oldest unacked) | Exceeds SLA |
| DLQ message count | > 0 (strict) or threshold |
| Publish rate | Anomalous spike or drop |
| Consumer throughput | Declining trend |
| Redelivery rate | Rising trend |
| End-to-end latency | P99 exceeds SLA |
| Connection count | Near broker limit |

## Security

### Encryption

- **In transit:** TLS between clients and broker. All managed services enforce TLS.
- **At rest:** OS/filesystem encryption for self-hosted brokers. Managed services provide server-side encryption (SSE-SQS, Azure SSE, Google-managed). Pulsar uniquely supports end-to-end encryption where the broker never sees plaintext.

### Authentication

| Broker | Methods |
|---|---|
| RabbitMQ | Username/password, LDAP, OAuth 2.0, x.509 |
| Kafka | SASL/SCRAM, mTLS, OAUTHBEARER, Kerberos |
| NATS | Username/password, NKey (Ed25519), JWT (decentralized), mTLS |
| SQS/SNS | AWS IAM (SigV4) |
| Service Bus | SAS tokens, Azure AD (OAuth 2.0 / RBAC) |
| GCP Pub/Sub | Google OAuth 2.0, Workload Identity |
| Pulsar | JWT, Athenz, Kerberos, OAuth 2.0, mTLS |

### Network Isolation

Use VPC endpoints (AWS), Private Link (Azure), VPC-native clusters, or mTLS for network-level isolation. Bind monitoring endpoints to localhost or use firewall rules.
