---
name: overview
description: "Top-level entry point for all messaging, event streaming, and event-driven architecture technologies -- broker/platform selection, event-driven architecture design, delivery-guarantee and ordering trade-offs -- for cross-platform or strategic questions. Use for \"messaging\", \"message broker\", \"message queue\", \"pub/sub\", \"event streaming\", \"event-driven\", \"async messaging\", \"dead letter queue\", \"DLQ\", \"fan-out\", \"AMQP\", \"MQTT\", \"exactly-once\", \"at-least-once\", \"consumer lag\", \"message ordering\", \"which message broker\", \"RabbitMQ vs Kafka\" when no specific technology is named or the question spans multiple brokers. Do NOT use for technology-specific implementation questions -- use the matching technology skill (e.g. `kafka`, `rabbitmq`, `nats`, `aws-sqs-sns`, `azure-service-bus`, `gcp-pubsub`, `pulsar`, `redis-streams`)."
license: MIT
---

# Messaging & Event Streaming Domain Overview

This skill is the top-level entry point for all messaging, event streaming, and event-driven architecture technologies, covering message brokers, pub/sub systems, streaming platforms, and async communication patterns. It points to the technology-specific skills for deep implementation details.

## When to Use This Skill vs. a Technology Skill

**Use this skill when the question is cross-platform or strategic:**
- "Should I use RabbitMQ or Kafka?"
- "Design an event-driven architecture for our microservices"
- "Compare managed messaging services (SQS vs Service Bus vs Pub/Sub)"
- "What delivery guarantee do we need?"
- "Broker vs streaming -- which and when?"
- "How should we handle dead-letter messages across systems?"
- "Message ordering strategy for our e-commerce platform"
- "Schema evolution across messaging systems"

**Read the matching technology skill when the question is technology-specific:**
- "RabbitMQ quorum queue not electing leader" --> the `rabbitmq` skill
- "NATS JetStream consumer lag" --> the `nats` skill
- "Service Bus session deadlock" --> the `azure-service-bus` skill
- "SQS FIFO throughput limits" --> the `aws-sqs-sns` skill
- "GCP Pub/Sub ordering key hot spot" --> the `gcp-pubsub` skill
- "Pulsar geo-replication setup" --> the `pulsar` skill
- "Kafka consumer group rebalancing" --> the `kafka` skill
- "Redis Streams XREADGROUP blocking" --> the `redis-streams` skill

## How to Approach Tasks

1. **Classify** the request:
   - **Broker/platform selection** -- Use the comparison tables below
   - **Architecture / EDA design** -- Load `references/concepts.md` for messaging patterns, delivery guarantees, EDA fundamentals
   - **Broker paradigm** -- Load `references/paradigm-broker.md` or `references/paradigm-streaming.md`
   - **Technology-specific** -- Read the matching technology skill

2. **Gather context** -- Message volume, latency requirements, ordering needs, delivery guarantees, cloud provider, existing infrastructure, team skills, compliance requirements

3. **Analyze** -- Apply messaging principles (delivery guarantees, ordering vs parallelism, dead-letter handling, schema evolution, idempotency)

4. **Recommend** -- Actionable guidance with trade-offs, not a single answer

## Messaging Principles

1. **Design for at-least-once plus idempotent consumers** -- True exactly-once across broker and external systems is impractical. Design producers to retry safely and consumers to handle duplicates via deduplication keys, upserts, or conditional writes.
2. **Order only what must be ordered** -- Total ordering kills parallelism. Partition by entity (order ID, customer ID) to maintain per-entity ordering while scaling horizontally. Most systems need partition ordering, not global ordering.
3. **Dead-letter queues are not optional** -- Every consumer must have a DLQ strategy. Unprocessable messages must go somewhere observable, not loop forever or disappear silently. Monitor DLQ depth as a critical alert.
4. **Separate concerns: routing, storage, processing** -- The broker handles routing and durability. Processing logic belongs in the consumer. Avoid complex routing logic in the broker when possible.
5. **Schema evolution is a messaging contract** -- Messages cross service boundaries and persist for variable durations. Use schema registries, backward-compatible changes, and versioned envelopes. Never deploy a breaking schema change to a shared topic.
6. **Backpressure is your friend** -- When consumers fall behind, slow down producers rather than dropping messages. Use flow control, prefetch limits, and visibility timeouts to prevent consumer overload.
7. **Observe everything** -- Track queue depth, consumer lag, publish rate, DLQ count, end-to-end latency, and redelivery rate. Propagate correlation IDs through message chains for distributed tracing.
8. **Messages are not RPCs** -- Asynchronous messaging decouples timing, not correctness. Design for eventual consistency, compensating transactions (sagas), and idempotent operations.

## Technology Comparison

### Traditional Brokers (Store-and-Forward)

| Technology | Protocol | Ordering | Managed Option | Best For | Trade-offs |
|---|---|---|---|---|---|
| **RabbitMQ** | AMQP 0-9-1/1.0, MQTT, STOMP | Queue-level | CloudAMQP, Amazon MQ | Flexible routing, multi-protocol, work queues | No replay after ack, operational overhead (self-hosted) |
| **Azure Service Bus** | AMQP 1.0, HTTP | Sessions (per-entity) | Azure-native | Enterprise messaging, ordered processing, transactions | Azure lock-in, Premium tier cost, 256 KB default message size |
| **AWS SQS/SNS** | HTTPS | FIFO per message group | AWS-native | Serverless fan-out, Lambda integration, zero-ops | No replay, 256 KB limit, 14-day max retention, FIFO throughput caps |

### Event Streaming Platforms

| Technology | Storage | Ordering | Managed Option | Best For | Trade-offs |
|---|---|---|---|---|---|
| **Apache Kafka** | Broker-local (coupled) | Partition-level | Confluent, MSK, Aiven | High-throughput event streaming, CDC, ecosystem | Operational complexity, partition design critical |
| **Apache Pulsar** | BookKeeper (decoupled) | Partition-level | StreamNative, Aiven | Multi-tenancy, geo-replication, tiered storage | Smaller ecosystem, BookKeeper complexity |

### Lightweight Pub/Sub

| Technology | Persistence | Ordering | Managed Option | Best For | Trade-offs |
|---|---|---|---|---|---|
| **NATS** | Core: none; JetStream: file/memory | Subject-level | Synadia Cloud | Ultra-low latency, microservice mesh, edge/IoT | Smaller ecosystem, JetStream less mature than Kafka |
| **Redis Streams** | In-memory + AOF/RDB | Stream-level | Redis Cloud, ElastiCache | Lightweight streaming if already using Redis | Memory-bound, single-node bottleneck, not a dedicated broker |

## Decision Framework

### Step 1: What is the primary use case?

| Pattern | Description | Typical Tools |
|---|---|---|
| **Task queue** | Competing consumers, work distribution | RabbitMQ, SQS, Service Bus queue |
| **Pub/sub notifications** | Fan-out to many subscribers | SNS, Service Bus topics, RabbitMQ fanout, NATS |
| **Event streaming** | High volume, replay, temporal queries | Kafka, Pulsar, NATS JetStream |
| **Request/reply** | Synchronous-over-async RPC | NATS (native), RabbitMQ (reply-to) |
| **IoT/edge** | Device telemetry, constrained networks | NATS (leaf nodes), RabbitMQ (MQTT), AWS IoT Core |

### Step 2: Do you need replay?

| Requirement | Recommendation |
|---|---|
| Consume and discard | Traditional broker (RabbitMQ, SQS, Service Bus) |
| Hours to days retention | Any managed broker (SQS 14d, Service Bus 14d, GCP Pub/Sub 31d) |
| Days to months with replay | Kafka, Pulsar, NATS JetStream |
| Indefinite archival | Pulsar (tiered storage), Kafka (tiered storage) |

### Step 3: Ordering requirements?

| Ordering Need | Approach |
|---|---|
| No ordering needed | Standard SQS, RabbitMQ competing consumers, Pulsar Shared |
| Per-entity ordering | SQS FIFO (MessageGroupId), Service Bus (SessionId), Kafka (partition key), Pulsar (Key_Shared) |
| Total ordering | Single partition/consumer (any broker), but severely limits throughput |

### Step 4: Cloud provider alignment?

| Cloud | Native Queue | Native Pub/Sub | Kafka-Compatible | Notes |
|---|---|---|---|---|
| **AWS** | SQS | SNS | MSK, Confluent | SQS+SNS is the default; MSK for streaming |
| **Azure** | Service Bus | Service Bus Topics | Event Hubs | Service Bus for enterprise; Event Hubs for Kafka compat |
| **GCP** | -- | Pub/Sub | Managed Kafka | Pub/Sub handles both queue and pub/sub patterns |
| **Multi-cloud** | RabbitMQ, NATS | RabbitMQ, NATS, Kafka | Confluent Cloud | Open-source for portability |

### Step 5: Latency and throughput?

| Requirement | Recommendation |
|---|---|
| Sub-millisecond, fire-and-forget | NATS Core |
| Low millisecond, durable | NATS JetStream, RabbitMQ, Redis Streams |
| High throughput (millions msg/s) | Kafka, Pulsar |
| Managed, auto-scaling | SQS, GCP Pub/Sub, Service Bus Premium |

## Cross-Plugin References

| Technology | Cross-Reference | When |
|---|---|---|
| Kafka (ETL context) | the `kafka` skill in the `etl` plugin | Kafka as a data integration / stream-processing pipeline (Connect, Streams, CDC) rather than broker ops |
| Redis | the `redis` skill in the `database` plugin | Redis as a database engine; Streams is one capability of it |

## Technology Routing

| Request Pattern | Read Skill |
|---|---|
| **Traditional Brokers** | |
| RabbitMQ, AMQP, exchange, quorum queue, stream, Khepri, vhost | `rabbitmq` |
| Azure Service Bus, namespace, session, topic subscription, peek-lock | `azure-service-bus` |
| SQS, SNS, FIFO queue, message group, fan-out, visibility timeout | `aws-sqs-sns` |
| **Event Streaming** | |
| Kafka, topic, partition, consumer group, offset, Connect, Streams | `kafka` |
| Pulsar, tenant, namespace, BookKeeper, bookie, geo-replication | `pulsar` |
| **Lightweight Pub/Sub** | |
| NATS, JetStream, subject, queue group, leaf node, KV store | `nats` |
| GCP Pub/Sub, subscription, ordering key, dead-letter topic | `gcp-pubsub` |
| Redis Streams, XADD, XREADGROUP, consumer group (Redis) | `redis-streams` |
| **Cross-cutting** | |
| Broker comparison, selection, architecture assessment | This skill |
| Event-driven architecture, saga, CQRS, event sourcing | Load `references/concepts.md` |
| Traditional broker paradigm questions | Load `references/paradigm-broker.md` |
| Event streaming paradigm questions | Load `references/paradigm-streaming.md` |

## Anti-Patterns

1. **"Using a message broker as a database"** -- Brokers are optimized for transient message delivery, not long-term queryable storage. Use a database for state and a broker for events. Kafka blurs this line intentionally, but even Kafka topics are not a replacement for a database.
2. **"One giant topic for everything"** -- A single topic carrying all event types destroys independent scaling, retention, and schema management. Use one topic per event type or bounded context.
3. **"Fire-and-forget for critical business events"** -- At-most-once delivery (no ack, no retry) is only acceptable for metrics and telemetry. Business events require at-least-once with idempotent consumers.
4. **"Ignoring dead-letter queues"** -- Poison messages that loop forever block queues, waste compute, and hide failures. Every queue needs a DLQ with monitoring and a redrive strategy.
5. **"Synchronous messaging"** -- Using request/reply over a broker when a direct HTTP call would suffice adds latency and complexity. Use async messaging for decoupling, not for synchronous communication.
6. **"Breaking schema changes on shared topics"** -- Removing required fields, changing types, or renaming fields breaks all downstream consumers. Use additive-only changes and schema registries.

## Reference Files

- `references/concepts.md` -- Messaging patterns (point-to-point, pub/sub, request/reply), delivery guarantees (at-most-once, at-least-once, exactly-once), event-driven architecture (domain events, event sourcing, CQRS, sagas), message ordering, dead-letter handling, schema evolution, observability. Read for architecture and comparison questions.
- `references/paradigm-broker.md` -- When and why to use traditional message brokers (RabbitMQ, Service Bus, SQS/SNS). Store-and-forward model, flexible routing, protocol diversity, managed options. Read when evaluating broker-style messaging.
- `references/paradigm-streaming.md` -- When and why to use event streaming platforms (Kafka, Pulsar, NATS JetStream). Append-only log, replay, consumer groups, stream processing. Read when evaluating streaming requirements.
