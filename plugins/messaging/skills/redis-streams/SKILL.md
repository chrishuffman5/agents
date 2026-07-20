---
name: redis-streams
description: "Expert coverage of Redis Streams as a lightweight messaging primitive: XADD/XREADGROUP/XACK mechanics, consumer groups, pending-entry claiming, and when Redis Streams is (and isn't) a substitute for a dedicated broker. Use for \"Redis Streams messaging\", \"XADD\", \"XREADGROUP\", \"XACK\", \"Redis consumer group\", \"Redis pub/sub\", \"Redis Streams vs Kafka\", \"Redis Streams vs NATS\", \"Redis as message broker\". Do NOT use for Redis engine internals (data structures, persistence, clustering, Lua scripting, memory eviction) -- that's the `redis` skill in the `database` plugin."
license: MIT
---

# Redis Streams

This skill covers Redis Streams from a messaging-platform angle: the append-only log data type, consumer-group semantics, and how it compares to dedicated message brokers. For Redis engine internals -- persistence, clustering, sentinel, memory management, client libraries, and general operational troubleshooting -- read the `redis` skill in the `database` plugin instead.

### Redis Streams as a Message Broker

Redis Streams provide an append-only log data structure with consumer group support, similar in concept to Kafka topics but implemented as a Redis data type:

- **Append-only log:** Messages are appended with auto-generated or custom IDs (`XADD`)
- **Consumer groups:** `XREADGROUP` distributes messages across consumers (each message to one consumer per group)
- **Acknowledgment:** `XACK` confirms processing; unacknowledged messages tracked in Pending Entries List (PEL)
- **Claiming:** `XCLAIM` and `XAUTOCLAIM` reassign stuck messages from failed consumers
- **Trimming:** `MAXLEN` or `MINID` strategies control stream size

### Redis Streams vs Dedicated Messaging Systems

| Dimension | Redis Streams | Dedicated Broker (Kafka, RabbitMQ, SQS) |
|---|---|---|
| Deployment | Already using Redis? Zero additional infra | Separate system to deploy and manage |
| Throughput | High (single-node bound) | Very high (distributed, partitioned) |
| Persistence | RDB/AOF (configurable) | Purpose-built durable storage |
| Memory | In-memory (memory-bound) | Disk-based (unlimited retention possible) |
| Consumer groups | Yes (XREADGROUP) | Yes (native, more mature) |
| Replay | Yes (XRANGE, XREAD from ID) | Yes (offset/cursor-based) |
| Routing | Stream-name only | Content-based, topic patterns, filters |
| DLQ | Manual (application-level) | Native (most brokers) |
| Exactly-once | No (at-least-once with XACK) | Kafka: yes; others: varies |
| Ordering | Per-stream global order | Per-partition/queue |
| Clustering | Redis Cluster (sharded by stream name) | Native distributed |

### When to Choose Redis Streams for Messaging

**Choose Redis Streams when:**
- You already have Redis in your stack and need lightweight streaming
- Message volume is moderate and fits in memory
- You need sub-millisecond latency
- You want a simple operational model (no new infrastructure)
- You need the Redis data model (hashes, sets, sorted sets) alongside messaging

**Choose a dedicated messaging system when:**
- You need durable, disk-based retention beyond memory capacity
- You need exactly-once delivery guarantees
- You need complex routing, filtering, or content-based delivery
- You need native dead-letter queues and retry policies
- Message volume requires distributed partitioning beyond a single Redis node
- You need mature operational tooling, monitoring, and alerting

### Key Redis Streams Commands for Messaging

```bash
# Produce a message
XADD orders * action create orderId 12345

# Create consumer group
XGROUP CREATE orders order-processors $ MKSTREAM

# Consume messages (blocking, consumer group)
XREADGROUP GROUP order-processors worker-1 COUNT 10 BLOCK 5000 STREAMS orders >

# Acknowledge processed message
XACK orders order-processors 1234567890-0

# Check pending (unacked) messages
XPENDING orders order-processors

# Claim stuck messages from failed consumer
XAUTOCLAIM orders order-processors worker-2 60000 0-0

# Trim stream to max length
XTRIM orders MAXLEN ~ 100000
```

## Cross-References

- The `redis` skill in the `database` plugin -- full Redis engine expertise
- The `overview` skill -- messaging domain cross-broker comparisons
- The `nats` skill -- alternative lightweight messaging
