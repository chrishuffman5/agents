# Traditional Message Brokers Paradigm Reference

## What Are Traditional Message Brokers?

Traditional message brokers implement a **store-and-forward** model: the broker receives messages from producers, stores them temporarily, and forwards them to consumers. Once a consumer acknowledges a message, it is removed from the broker. Brokers are designed for task queues, decoupled microservices, and asynchronous processing -- not for long-term retention or replay.

**Examples:** RabbitMQ, Azure Service Bus, AWS SQS/SNS

## Architecture Model

```
Producer --> [Broker stores message] --> Consumer (message deleted after ack)
```

Messages are consumed and removed (or expired). The broker is a transient intermediary, not a permanent store. Consumers cannot rewind or replay after acknowledgment.

## When to Use Traditional Brokers

### Strong Fit

- **Work queues and task distribution:** Competing consumers pull from a shared queue, processing jobs in parallel. The broker handles load balancing and retry.
- **Decoupled microservice communication:** Services publish events without knowing consumers. The broker buffers messages during consumer downtime.
- **Request buffering:** Absorb traffic spikes before downstream services. SQS is particularly effective as a buffer in front of databases or APIs.
- **Ordered per-entity processing:** Service Bus sessions and SQS FIFO message groups provide per-entity ordering with parallel processing across entities.
- **Transactional messaging:** Service Bus supports atomic transactions across queue operations. RabbitMQ provides publisher confirms and consumer acknowledgments.
- **Protocol diversity:** RabbitMQ supports AMQP 0-9-1, AMQP 1.0, MQTT 5.0, and STOMP simultaneously -- useful when integrating IoT devices, legacy systems, and modern services.

### Weak Fit

- **Event replay or reprocessing:** After acknowledgment, messages are gone. If you need to replay from a point in time, use an event streaming platform.
- **High-throughput event streaming:** Traditional brokers top out at tens of thousands to hundreds of thousands of messages per second. Kafka and Pulsar handle millions.
- **Stream processing:** Windowed aggregations, stream joins, and temporal queries require a streaming platform with offset-based consumption.
- **Long-term event storage:** Traditional brokers are not designed for weeks or months of retention. Use Kafka with tiered storage or Pulsar with offloading.

## Broker Comparison

### RabbitMQ

**Model:** Exchange-binding-queue architecture. Producers publish to exchanges; exchanges route to queues via bindings; consumers subscribe to queues.

**Strengths:**
- Most flexible routing of any broker (direct, fanout, topic, headers exchanges; exchange-to-exchange bindings)
- Multi-protocol (AMQP 0-9-1, AMQP 1.0, MQTT, STOMP)
- Quorum queues provide Raft-based replication for durability
- Streams add append-only log semantics for replay within RabbitMQ
- Rich plugin ecosystem (shovel, federation, delayed message exchange)
- Strong open-source community; no vendor lock-in

**Weaknesses:**
- Operational overhead for self-hosted clusters (Erlang runtime, clustering, upgrades)
- No native replay after acknowledgment (streams address this partially)
- Throughput ceiling vs. streaming platforms
- Cluster recovery from network partitions requires careful strategy selection

**Best for:** Multi-protocol environments, complex routing requirements, work queues, teams that need an open-source broker without cloud lock-in.

### Azure Service Bus

**Model:** Namespace-scoped queues and topics with subscriptions. Fully managed PaaS with no infrastructure to manage.

**Strengths:**
- Sessions provide guaranteed FIFO per entity with session state storage
- Built-in duplicate detection (message ID tracking with configurable window)
- SQL and correlation filters on topic subscriptions for content-based routing
- Transactions across queue operations (send + complete atomically)
- Scheduled message delivery and message deferral
- Built-in dead-letter subqueue per entity
- Premium tier provides dedicated compute (messaging units), VNET integration, and 100 MB messages
- Geo-disaster recovery and geo-replication (Premium)

**Weaknesses:**
- Azure lock-in (AMQP 1.0 protocol is standard, but SDK ecosystem is Azure-specific)
- Premium tier required for predictable performance, VNET, large messages
- Standard tier uses shared infrastructure with throttling risk
- 256 KB default message size on Standard/Basic

**Best for:** Azure-native architectures, enterprise messaging with ordering and transaction requirements, regulated environments needing VNET isolation.

### AWS SQS/SNS

**Model:** SQS provides pull-based queues; SNS provides push-based pub/sub topics. Typically combined: SNS fans out to multiple SQS queues.

**Strengths:**
- Zero operations: fully managed, auto-scaling, no infrastructure
- SQS Standard: unlimited throughput, at-least-once delivery
- SQS FIFO: exactly-once processing with MessageDeduplicationId, ordered per MessageGroupId
- SNS message filtering: subscription filter policies reduce unnecessary processing
- Native Lambda integration via Event Source Mapping with partial batch responses
- Built-in DLQ with redrive (`StartMessageMoveTask`)
- Server-side encryption (SSE-SQS free, SSE-KMS for compliance)
- Cost-effective at low volumes (pay per request)

**Weaknesses:**
- 256 KB message size limit (Extended Client Library for S3 overflow)
- 14-day maximum retention
- No replay after deletion
- FIFO throughput: 300 msg/s without batching, 3,000 with batching (70,000 in high-throughput mode)
- HTTPS-only protocol (no AMQP, MQTT)
- SNS FIFO topics can only deliver to SQS FIFO queues

**Best for:** AWS-native serverless architectures, Lambda-driven event processing, zero-ops requirements, fan-out patterns.

## Paradigm Patterns

### Work Queue Pattern

```
Producer --> [Queue] --> Consumer A (processes msg 1, 4, 7...)
                     --> Consumer B (processes msg 2, 5, 8...)
                     --> Consumer C (processes msg 3, 6, 9...)
```

All three brokers support this natively. RabbitMQ uses round-robin with prefetch. SQS uses visibility timeout. Service Bus uses PeekLock.

### Fan-Out Pattern

```
Producer --> [Exchange/Topic/SNS] --> Queue A --> Consumer A
                                  --> Queue B --> Consumer B
                                  --> Queue C --> Consumer C
```

RabbitMQ: fanout exchange with bound queues. SNS: topic with SQS subscriptions. Service Bus: topic with subscriptions and filter rules.

### Dead-Letter Pattern

All three provide native DLQ support:
- RabbitMQ: Dead Letter Exchange (`x-dead-letter-exchange`) on the source queue
- SQS: `RedrivePolicy` with `maxReceiveCount` pointing to a DLQ queue
- Service Bus: Built-in `/$deadletterqueue` subqueue per entity

### Delayed/Scheduled Message Pattern

- RabbitMQ: `x-delayed-message` plugin or TTL + DLX chain
- SQS: `DelaySeconds` per message (up to 900s) or queue-level delay
- Service Bus: `ScheduledEnqueueTimeUtc` property with cancel support

## Selection Guidance

| Criterion | RabbitMQ | Service Bus | SQS/SNS |
|---|---|---|---|
| Cloud-agnostic | Yes | No (Azure) | No (AWS) |
| Zero-ops | No (self-hosted) | Yes | Yes |
| Protocol diversity | AMQP, MQTT, STOMP | AMQP 1.0 | HTTPS only |
| Complex routing | Best (exchanges) | Good (filters) | Good (SNS filters) |
| Ordering | Queue-level | Sessions | FIFO message groups |
| Transactions | Publisher confirms | Cross-entity | No |
| Max message size | 16 MB (default) | 100 MB (Premium) | 256 KB |
| Replay | Streams only | No | No |
| Cost model | Infrastructure | Per MU/hour (Premium) | Per request |
