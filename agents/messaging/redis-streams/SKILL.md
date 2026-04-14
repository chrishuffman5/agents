---
name: messaging-redis-streams
description: "Cross-reference routing agent for Redis Streams within the messaging domain. Routes to the primary Redis agent in the database domain while providing messaging-specific context for Redis Streams as a lightweight event streaming data structure. WHEN: \"Redis Streams messaging\", \"XADD\", \"XREADGROUP\", \"XACK\", \"Redis consumer group\", \"Redis pub/sub\", \"Redis Streams vs Kafka\", \"Redis Streams vs NATS\", \"Redis as message broker\"."
author: christopher huffman
license: MIT
metadata:
  version: "1.0.0"
---

# Redis Streams — Messaging Domain Cross-Reference

This is a routing agent. The primary Redis expert lives at `agents/database/redis/SKILL.md` and covers all Redis capabilities including data structures, persistence, clustering, Lua scripting, and Redis Streams.

## When to Route to the Primary Redis Agent

**Always route to `agents/database/redis/SKILL.md`** for:
- Redis Streams commands (XADD, XREAD, XREADGROUP, XACK, XRANGE, XLEN, XTRIM)
- Consumer group management (XGROUP CREATE, XGROUP DELCONSUMER, XINFO)
- Redis Pub/Sub (SUBSCRIBE, PUBLISH -- non-persistent, at-most-once)
- Redis cluster mode and sentinel configuration
- Persistence (RDB snapshots, AOF, mixed mode)
- Memory management and eviction policies
- Redis configuration and operational troubleshooting
- Client library usage across languages

## Messaging-Specific Context for Redis Streams

When the question is about Redis Streams in a **messaging context**, provide this additional framing before routing:

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

- **Primary agent:** `agents/database/redis/SKILL.md` -- Full Redis expertise
- **Parent domain:** `../SKILL.md` -- Messaging domain routing and cross-broker comparisons
- **NATS comparison:** `../nats/SKILL.md` -- Alternative lightweight messaging
