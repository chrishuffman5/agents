# RabbitMQ 4.x — Comprehensive Research Document

**Prepared for:** Writer agent (technology skill file authoring)
**Research date:** April 2026
**Versions covered:** RabbitMQ 4.0, 4.1, 4.2 (with 3.13 context for migrations)

---

## 1. VERSION TIMELINE AND MAJOR CHANGES

### RabbitMQ 4.0 (September 2024)

The most significant release since RabbitMQ's creation. Key changes:

- **AMQP 1.0 is now a core protocol** (always enabled; no longer a plugin). Throughput more than doubled compared to 3.13.x on some workloads. Memory usage dropped from 11.1 GB to 4.8 GB (56% reduction) in benchmarks. Now uses 1 Erlang process per session instead of 15.
- **Classic queue mirroring removed** — deprecated since 2021, fully removed. Classic queues remain as non-replicated only.
- **CQv1 storage removed** — only CQv2 (classic queue storage version 2). Configurations with `classic_queue.default_version = 1` will prevent node startup.
- **Quorum queue priorities** — quorum queues now support a simplified two-tier priority (normal vs. high). Message delivery limit default set to 20.
- **Quorum queue checkpoints** — sub-linear recovery using Raft checkpoints on node boot.
- **Default max message size** changed from 128 MiB to 16 MiB.
- **Breaking:** CQv1 config prevents startup; remove `classic_queue.default_version = 1`.
- **Breaking:** Anonymous login now uses `anonymous_login_user` and `anonymous_login_pass`.
- **Erlang 26.2+ required.**

### RabbitMQ 4.1 (April 2025)

- **New Kubernetes peer discovery** — pod with `-0` suffix acts as seed node; no Kubernetes API calls. All other pods join the seed node.
- **AMQP 1.0 filter expressions** — properties and application-properties filters for stream consumers.
- **rabbitmqadmin v2** — major CLI revision with expanded HTTP API coverage (federation, shovels, better interactive mode).
- **Quorum queue log reads offloaded** to channels, improving consumer throughput and reducing publisher/consumer interference.
- **Required feature flags auto-enable** on node boot when all cluster nodes support them.
- **Breaking:** Initial AMQP 0-9-1 max frame size raised from 4096 to 8192 bytes (JWT token compatibility).
- **Breaking:** amqplib Node.js users must upgrade to 0.10.7+.
- **Breaking:** MQTT default max packet size reduced from 256 MiB to 16 MiB.
- **Deprecated:** `rabbitmqctl force_reset` — incompatible with Khepri.
- **Erlang 26.2+ required; Erlang 27.x supported.**

### RabbitMQ 4.2 (Late 2025)

- **Khepri is the default metadata store** for new deployments. The `khepri_db` feature flag is now `Stable` (auto-enabled by `rabbitmqctl enable_feature_flag all`).
- **SQL filter expressions for streams** — AMQP 1.0 clients can define server-side SQL-like filters when consuming from streams.
- **Direct Reply-To for AMQP 1.0** — enables RPC patterns across protocols and between AMQP 1.0 and AMQP 0.9.1.
- **Message Interceptors** — intercept incoming/outgoing messages for AMQP 1.0, AMQP 0.9.1, MQTTv3, and MQTTv5.
- **Local Shovels** — new "local" protocol using intra-cluster connections instead of TCP for within-cluster message movement.
- **Fanout exchange optimization** — up to 42% throughput gains.
- **Quorum queue leadership transfers** now gradual, preventing timeouts in large deployments.
- **Breaking:** AMQP 1.0 messages without explicit durable headers default to non-durable (spec compliance).
- **Breaking:** Prometheus metrics starting with `rabbitmq_raft` renamed/restructured.
- **Default queue type on new deployments:** `quorum` (Amazon MQ for RabbitMQ 4.2 default is quorum).

---

## 2. ARCHITECTURE

### 2.1 Broker Model

RabbitMQ is a message broker implementing a store-and-forward model. Publishers send messages to exchanges; exchanges route to queues or streams; consumers pull or receive (push) from queues/streams.

Core components:
- **Node** — a single RabbitMQ server process (Erlang VM / BEAM)
- **Cluster** — multiple nodes sharing metadata; queues may or may not be replicated
- **Virtual host (vhost)** — logical isolation boundary within a broker; has its own exchanges, queues, bindings, users, policies
- **Exchange** — routing entity; receives messages from publishers and routes to queues/streams/exchanges
- **Queue** — storage entity; holds messages for consumers
- **Stream** — append-only log storage entity
- **Binding** — routing rule linking exchange to queue/stream/exchange
- **Connection** — TCP connection between client and broker
- **Channel** — lightweight virtual connection multiplexed over a TCP connection

### 2.2 Exchange Types

#### Direct Exchange
- Exact routing key match required
- Default exchange (name: `""`) is a pre-declared direct exchange; every queue is automatically bound to it with its own name as the routing key
- Use case: point-to-point, work queues

#### Fanout Exchange
- Ignores routing key entirely
- Routes a copy of every message to every bound queue/stream/exchange
- Use case: broadcast, pub/sub, event fan-out

#### Topic Exchange
- Routing key segments separated by `.`
- `*` matches exactly one segment
- `#` matches zero or more segments
- Example: `orders.*.shipped` matches `orders.us.shipped` but not `orders.shipped`
- Use case: selective pub/sub, log routing by severity and source

#### Headers Exchange
- Routes based on message header attributes (key-value pairs)
- `x-match: all` requires all headers to match; `x-match: any` requires at least one
- Routing key ignored
- Use case: complex attribute-based routing

#### Default Exchange
- Name: empty string `""`
- Pre-declared direct exchange
- Every new queue is automatically bound with its name as the routing key
- Enables publish directly to a named queue without explicit binding

#### Plugin-Provided Exchange Types
- **Local Random** (new in 4.0) — distributes to a random binding among locally-connected consumers
- **Consistent Hashing** — routes messages to queues based on hash of routing key or header
- **JMS Topic** — JMS selector-compatible routing

#### Alternate Exchanges
Configure via `x-alternate-exchange` argument or policy. Unroutable messages (no matching binding) are forwarded to the alternate exchange instead of being dropped.

```bash
rabbitmqctl set_policy AE ".*" '{"alternate-exchange":"my-ae"}' --apply-to exchanges
```

#### Exchange-to-Exchange (E2E) Bindings
Exchanges can be bound to other exchanges. Messages route using the combined bindings of source and destination exchanges without republishing.

### 2.3 Queue Types

#### Classic Queues (CQ)
- **Not replicated** in RabbitMQ 4.x (mirroring removed)
- Storage: CQv2 only (CQv1 removed in 4.0)
- Supports: durable, transient, exclusive, auto-delete, per-message TTL, queue TTL, DLX, max-length, priority (x-max-priority)
- **Lazy mode** (x-queue-mode: lazy) removed in 3.12+; current CQv2 behavior approximates lazy mode
- Best for: non-critical, non-replicated workloads; scratch queues; short-lived data

#### Quorum Queues (QQ)
- **Replicated** via Raft consensus algorithm (Multi-Raft implementation)
- Default replication factor: 3 (one replica per cluster node by default, up to cluster size)
- Leader + followers; all writes go through leader
- Supports: durable, delivery limits, DLX (including at-least-once), priorities (two-tier: normal/high)
- Does NOT support: non-durable, exclusive, global QoS, server-named queues
- **Default delivery limit in 4.0+:** 20 redeliveries before dead-lettering
- Best for: production workloads requiring durability and replication

#### Streams
- **Append-only, immutable log** — consuming does not remove messages
- Multiple consumers can read same data at different offsets
- Supports: offset tracking, retention by age and/or size, replication, deduplication
- Requires: consumer QoS prefetch set (acks act as credit)
- Best for: event sourcing, audit logs, fan-out to many consumers, replay scenarios

### 2.4 Bindings

A binding is a routing rule associating an exchange with a queue, stream, or another exchange. Properties:
- Source exchange
- Destination (queue/stream/exchange name)
- Routing key (for direct/topic; ignored by fanout)
- Optional arguments (for headers exchange matching)

### 2.5 Virtual Hosts

Each vhost is a completely isolated namespace containing:
- Its own exchanges, queues, bindings
- Its own user permissions
- Its own policies and parameters
- Its own per-vhost limits (connections, channels, queues)

```bash
# Create a vhost
rabbitmqctl add_vhost my-app-production --description "Production environment"

# Set permissions (configure, write, read — all as regex patterns)
rabbitmqctl set_permissions -p my-app-production my-user ".*" ".*" ".*"

# List vhosts
rabbitmqctl list_vhosts name description

# Per-vhost limits
rabbitmqctl set_vhost_limits -p my-vhost '{"max-connections": 100, "max-queues": 500}'
```

### 2.6 Connections and Channels

**Connection:** A long-lived TCP connection. Creating a connection per operation is an anti-pattern. Connections are expensive — use one per application instance (or connection pool for short-lived scenarios).

**Channel:** A lightweight virtual connection multiplexed over a TCP connection. Use multiple channels on a single connection for concurrent operations (e.g., one channel per thread). Channels are cheap to create and close.

**Best practices:**
- Use separate connections for publishing and consuming (flow control is per-connection)
- One channel per thread or coroutine
- Close channels that are no longer needed
- Configure heartbeats ≥ 5 seconds: `heartbeat = 60` in `rabbitmq.conf`
- Limit connections per vhost using `max-connections` vhost limit

---

## 3. KHEPRI METADATA STORE

### 3.1 Overview

Khepri is a Raft-based, tree-structured replicated database that replaces Mnesia for storing RabbitMQ metadata (exchanges, queues, bindings, users, vhosts, policies, etc.).

**Status by version:**
- 3.13: Experimental (opt-in)
- 4.0: Fully supported (opt-in, stable)
- 4.1: Stable (feature flag upgraded)
- 4.2: Default for new deployments (`khepri_db` flag = Stable)
- 4.3+ (planned): Required (Mnesia support dropped)

### 3.2 Why Khepri Replaces Mnesia

**Mnesia problems:**
- Poor partition tolerance — assumes one side can discard data
- Complex conflict resolution required at the RabbitMQ level
- Binding inconsistency issues in network partition scenarios
- Difficult to reason about behavior during failures

**Khepri advantages:**
- Uses same Raft algorithm as quorum queues and streams (unified consensus)
- Well-defined behavior during network partitions
- Tree-structured data (hierarchical nodes, not flat tables)
- Strong consistency guarantees
- Eliminates entire category of binding inconsistency bugs

### 3.3 Data Structure

Khepri uses a tree of nested objects where each node can host a payload. Leaf nodes typically contain data. The tree structure maps naturally to RabbitMQ's hierarchical topology (cluster → vhost → exchange/queue → binding).

### 3.4 Enabling Khepri

```bash
# Enable Khepri on a running cluster (all nodes must support it)
rabbitmqctl enable_feature_flag khepri_db

# In 4.2+, enable all stable feature flags (includes khepri_db)
rabbitmqctl enable_feature_flag all

# Verify metadata store in use
rabbitmq-diagnostics status | grep -i metadata
```

**Migration notes:**
- Migration runs in parallel with normal operations
- Brief pause near end of migration (resource-intensive phase)
- `rabbitmqctl force_reset` is deprecated in 4.1 (incompatible with Khepri)
- Migration is irreversible — plan and test before production deployment

### 3.5 Clustering with Khepri

With Khepri, cluster membership and metadata are both managed via Raft:
- Majority quorum required for metadata operations
- Node joins/leaves require quorum availability
- Better defined split-brain behavior than Mnesia

```bash
# Check current metadata store
rabbitmq-diagnostics metadata_store_status
```

---

## 4. PROTOCOLS

### 4.1 AMQP 0-9-1 (Primary Protocol)

The traditional and most widely used protocol. Default port: **5672** (TLS: **5671**).

Core concepts:
- Exchanges, queues, bindings as first-class entities
- Publisher confirms (extension)
- Consumer acknowledgements
- Channel-level QoS (prefetch)
- Transactions (not recommended — use publisher confirms instead)

Frame structure: method frames, header frames, body frames, heartbeat frames. Initial max frame size: 8192 bytes (raised from 4096 in 4.1).

### 4.2 AMQP 1.0 (Native Core Protocol Since 4.0)

Default port: **5672** (shared with AMQP 0-9-1 via protocol negotiation). Previously a plugin, now always enabled.

**Key architecture difference from 4.0+:**
- No longer proxies via AMQP 0-9-1 internally
- AMQP 1.0 clients publish directly to exchanges and consume directly from queues
- Single Erlang process per session (was 15 processes in 3.13)

**4.0 improvements:**
- Throughput doubled compared to 3.13.x on many workloads
- Memory usage reduced 56% vs 3.13

**4.1 additions:**
- AMQP Filter Expressions — properties and application-properties filters for stream consumers
- Enables multiple concurrent clients to consume subsets while maintaining order

**4.2 additions:**
- SQL-like filter expressions for stream consumption
- Direct Reply-To (RPC pattern) now supported
- Modified outcome — consumers can modify message annotations before requeueing or dead-lettering
- Granular flow control

**4.2 breaking change:** Messages without explicit durable headers now default to non-durable (spec compliance change).

### 4.3 MQTT 5.0

Plugin: `rabbitmq_mqtt`. Default port: **1883** (TLS: **8883**), WebSocket: **15675**.

Supported versions: MQTT 3.1, 3.1.1, and 5.0 (added in 3.13, carried into 4.x).

**Architecture (since 3.12):** Native MQTT — no longer proxies via AMQP 0-9-1. Plugin parses MQTT messages and routes directly to queues.

**4.1 change:** Default max packet size reduced from 256 MiB to 16 MiB (configurable via `mqtt.max_packet_size_authenticated`).

MQTT topics map to AMQP routing keys (`.` separator converted to `/`). QoS levels:
- QoS 0: at-most-once (fire and forget)
- QoS 1: at-least-once (requires acknowledgement)

MQTT 5.0 features supported: user properties, message expiry interval, topic aliases, flow control, reason codes.

### 4.4 STOMP

Plugin: `rabbitmq_stomp`. Default port: **61613**, WebSocket: **15674**.

Supported: STOMP 1.0, 1.1, 1.2.

Routes messages to exchanges and queues using destination headers. Can interoperate with AMQP 0-9-1 and AMQP 1.0 clients.

### 4.5 Protocol Port Summary

| Protocol         | Default Port | TLS Port | Notes                          |
|-----------------|-------------|----------|-------------------------------|
| AMQP 0-9-1      | 5672        | 5671     | Primary protocol               |
| AMQP 1.0        | 5672        | 5671     | Shared with AMQP 0-9-1         |
| MQTT            | 1883        | 8883     | WebSocket: 15675               |
| STOMP           | 61613       | —        | WebSocket: 15674               |
| Management HTTP | 15672       | —        | HTTP API + Management UI       |
| Prometheus      | 15692       | —        | Metrics endpoint               |
| Inter-node      | 25672       | —        | Erlang distribution            |
| Stream Protocol | 5552        | 5551     | Native stream client protocol  |

---

## 5. QUEUES — DEEP DIVE

### 5.1 Quorum Queues

#### Declaration
```python
# Python pika example
channel.queue_declare(
    queue='my.quorum.queue',
    durable=True,
    arguments={'x-queue-type': 'quorum'}
)
```

#### Replication Factor
- Default: 3 members (or cluster size if smaller)
- Control with: `x-quorum-initial-group-size` argument at declaration
- For 7-node cluster, default is 3 members (not all 7)

#### Fault Tolerance
| Cluster Nodes | Replicas | Tolerated Failures |
|--------------|----------|-------------------|
| 3            | 3        | 1                 |
| 5            | 5        | 2                 |
| 7            | 7        | 3                 |

#### Membership Management CLI
```bash
# Add a replica to a specific node
rabbitmq-queues add_member -p /myvhost my.quorum.queue rabbit@node3

# Remove a replica
rabbitmq-queues delete_member -p /myvhost my.quorum.queue rabbit@node3

# Grow replicas across all nodes
rabbitmq-queues grow rabbit@node3 all

# Shrink replicas from a node
rabbitmq-queues shrink rabbit@node3

# Rebalance leadership across nodes
rabbitmq-queues rebalance quorum
```

#### Continuous Membership Reconciliation (CMR)
Automatically grows replicas to target size. Configure in `rabbitmq.conf`:
```ini
quorum_queue.continuous_membership_reconciliation.enabled = true
quorum_queue.continuous_membership_reconciliation.target_group_size = 3
quorum_queue.continuous_membership_reconciliation.auto_remove = false
quorum_queue.continuous_membership_reconciliation.interval = 3600000
```

#### Delivery Limits (Poison Message Handling)
Default: 20 redeliveries. Messages exceeding limit are dead-lettered or dropped.
```bash
rabbitmqctl set_policy qq-overrides "^qq\." \
  '{"delivery-limit": 50}' \
  --priority 123 --apply-to "quorum_queues"
```

#### At-Least-Once Dead Lettering
Requirements:
- `dead-letter-strategy` policy key = `at-least-once`
- `overflow` = `reject-publish` (not `drop-head`)
- `stream_queue` feature flag enabled
- Target: quorum queue or stream (not classic queue)

#### Key Configuration Parameters
```ini
# advanced.config
[
  {rabbit, [
    {quorum_cluster_size, 3},
    {quorum_commands_soft_limit, 32}
  ]},
  {ra, [
    {wal_max_size_bytes, 536870912},
    {segment_max_entries, 4096}
  ]}
]
```

Tuning `segment_max_entries`:
- Small messages: increase to 32768
- Large messages: decrease to 128

#### Memory Requirements
- ~32 bytes metadata per message (more with TTL/return tracking)
- Allocate 3-4x WAL file size limit for Erlang GC patterns
- Default WAL: 512 MiB → allocate ~2 GiB RAM for queue operations

### 5.2 Classic Queues

```python
channel.queue_declare(
    queue='my.classic.queue',
    durable=True,
    arguments={'x-queue-type': 'classic'}  # or omit (default in pre-4.2)
)
```

#### Classic Queue Priority
```python
channel.queue_declare(
    queue='my.priority.queue',
    durable=True,
    arguments={
        'x-queue-type': 'classic',
        'x-max-priority': 10  # supports 1-255; use 1-10 in practice
    }
)
```

Note: Priority cannot be set via policy (must be queue argument at declaration time).

#### Lazy Mode (Historical Reference)
- Removed in 3.12. CQv2 behavior approximates it.
- Legacy argument `x-queue-mode: lazy` is now ignored.

### 5.3 RabbitMQ Streams

#### Declaration
```python
channel.queue_declare(
    queue='my.stream',
    durable=True,
    arguments={
        'x-queue-type': 'stream',
        'x-max-length-bytes': 10737418240,  # 10 GB
        'x-max-age': '7D',                  # 7 days retention
        'x-stream-max-segment-size-bytes': 524288000  # 500 MB segments
    }
)
```

#### Retention Policies
Evaluated per-segment; both can be combined:
- `x-max-length-bytes` — total stream size limit
- `x-max-age` — age-based expiry (Y, M, D, h, m, s units: e.g., `7D`, `24h`)
- At least one segment is always kept even if limit exceeded

#### Consumer Offset Options
Specified via `x-stream-offset` argument at subscription:
- `first` — start from earliest available message
- `last` — start from final message chunk
- `next` — read only new messages published after subscription
- `<integer>` — specific numeric offset
- `<timestamp>` — POSIX seconds since epoch
- `<interval>` — relative time string (same format as `x-max-age`)

#### Offset Tracking
Offsets persisted in the stream itself as non-message data (minimal disk overhead). Applicable only with stream plugin; AMQP clients must track offsets client-side.

#### Super Streams (Partitioned Streams)
```bash
# Create a super stream with 3 partitions
rabbitmq-streams add_super_stream invoices --partitions 3

# Delete a super stream
rabbitmq-streams delete_super_stream invoices
```

Super streams partition a large logical stream into smaller partition streams. Each partition is a regular stream. Enables horizontal scaling of both publishing and consuming. Integrates with Single Active Consumer to maintain ordering within partitions.

#### Stream Replication CLI
```bash
# Add a replica to a node
rabbitmq-streams add_replica -p /myvhost my.stream rabbit@node3

# Remove a replica
rabbitmq-streams delete_replica -p /myvhost my.stream rabbit@node3

# Check replication status
rabbitmq-streams stream_status -p /myvhost my.stream

# Restart a stream
rabbitmq-streams restart_stream -p /myvhost my.stream
```

#### Message Deduplication
Named producers with stable identity activate deduplication:
- Producer name must be unique per stream and stable across restarts
- Publishing ID: strictly increasing sequence (gaps allowed)
- Broker tracks highest publishing ID per producer; duplicate/earlier IDs are filtered

---

## 6. MESSAGE RELIABILITY

### 6.1 Consumer Acknowledgements

Three protocol methods:
- `basic.ack` — positive; message processed successfully
- `basic.nack` — negative (RabbitMQ extension); supports bulk with `multiple=True`
- `basic.reject` — negative; no bulk support

**Delivery tags:** Monotonically increasing integers, scoped per channel. Must be acked on the same channel where delivery occurred.

**Acknowledgement modes:**
- **Auto (automatic):** Message acked immediately upon TCP delivery. Maximum throughput, no safety guarantee. Avoid for critical workloads.
- **Manual:** Explicit ack required. Recommended for production.

```python
# Manual ack
channel.basic_ack(delivery_tag=method.delivery_tag)

# Bulk ack (acknowledges all up to and including this tag)
channel.basic_ack(delivery_tag=method.delivery_tag, multiple=True)

# Reject and requeue
channel.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

# Reject and dead-letter (don't requeue)
channel.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
```

**Redelivery loop prevention:** If all consumers nack with requeue=True, messages loop indefinitely. Use dead letter exchanges and delivery limits (quorum queues) to break the loop.

**Automatic requeue on disconnect:** Unacked messages are automatically requeued when a connection or channel closes. Consumers must handle redeliveries idempotently. Redelivered messages have the `redelivered` flag set to `True`.

### 6.2 Publisher Confirms

Channel must be put into confirm mode first:
```python
channel.confirm_delivery()  # pika
# or
channel.tx_select()  # transactions (not recommended)
```

After `confirm.select`:
- Broker sends `basic.ack` for successfully handled messages
- Broker sends `basic.nack` for internal errors
- For persistent messages on durable queues: confirm sent after disk persistence

**Batch confirms:**
```python
# Enable confirm mode
channel.confirm_delivery()

# Publish multiple messages
for msg in messages:
    channel.basic_publish(exchange='', routing_key='my.queue', body=msg)

# Wait for all confirms
channel.wait_for_confirms_or_die()
```

### 6.3 Consumer Prefetch (QoS)

Limits unacknowledged messages outstanding on a channel:
```python
channel.basic_qos(prefetch_count=50)
```

Quorum queues do NOT support global QoS (`global=True`). Use per-consumer QoS only.

**Prefetch tuning guidelines:**
- CPU-bound tasks: 1-5
- I/O-bound tasks: 10-50
- Fast consumers: 100-300
- Very fast consumers with low latency: up to 1000
- `prefetch_count=0` = unlimited (disable flow control; risky)

---

## 7. DEAD LETTER EXCHANGES AND TTL

### 7.1 Dead Letter Exchange (DLX)

Messages are dead-lettered when:
1. **Rejected** — `basic.nack` or `basic.reject` with `requeue=False`
2. **Expired** — message TTL exceeded
3. **Queue overflow** — queue at max-length, overflow = drop-head or reject-publish
4. **Delivery limit exceeded** — quorum queue redelivery limit (default 20 in 4.0+)

#### Configuration via Policy (Recommended)
```bash
rabbitmqctl set_policy DLX ".*" \
  '{"dead-letter-exchange":"dlx.exchange","dead-letter-routing-key":"dlx.routing.key"}' \
  --apply-to queues --priority 7
```

#### Configuration via Queue Arguments
```python
channel.queue_declare(
    queue='my.queue',
    durable=True,
    arguments={
        'x-dead-letter-exchange': 'dlx.exchange',
        'x-dead-letter-routing-key': 'dlx.routing.key'
    }
)
```

#### Dead Letter Headers Added
- `x-death` (AMQP 0-9-1) / `x-opt-deaths` (AMQP 1.0): array of death records
- Each record contains: queue, reason, count, time, exchange, routing-keys
- `x-first-death-reason`, `x-first-death-queue`, `x-first-death-exchange`
- `x-last-death-reason`, `x-last-death-queue`, `x-last-death-exchange`

**Dead letter reasons in headers:**
- `rejected` — consumer nacked
- `expired` — TTL exceeded
- `maxlen` — queue overflow
- `delivery_limit` — quorum queue redelivery limit hit

### 7.2 TTL (Time-To-Live)

#### Queue-Wide Message TTL
```bash
rabbitmqctl set_policy TTL ".*" '{"message-ttl": 60000}' --apply-to queues
```
Or at declaration:
```python
channel.queue_declare(
    queue='my.ttl.queue',
    arguments={'x-message-ttl': 60000}  # milliseconds
)
```

#### Per-Message TTL
Set by publisher in message properties:
```python
channel.basic_publish(
    exchange='my-exchange',
    routing_key='my.key',
    body='message body',
    properties=pika.BasicProperties(expiration='30000')  # milliseconds as string
)
```

When both queue-wide and per-message TTL are set, the lower value applies.

#### Queue TTL (Expiry)
Expires unused queues (must be positive integer, not 0):
```python
channel.queue_declare(
    queue='my.temp.queue',
    arguments={'x-expires': 1800000}  # 30 minutes in milliseconds
)
```

#### TTL and Dead Letter Interaction
Expired messages at the head of queue are dead-lettered. The original TTL is stripped from the message to prevent expiry in the DLX target queue. For quorum queues, expired messages dead-letter only when they reach queue head.

---

## 8. CLUSTERING

### 8.1 Cluster Basics

- All nodes share metadata (users, vhosts, exchanges, bindings, policies)
- Queue replicas may or may not be distributed (depends on queue type)
- Nodes communicate via Erlang distribution protocol (port 25672)
- Cluster membership secured by Erlang cookie (shared secret)

**Erlang cookie location:**
- Server: `/var/lib/rabbitmq/.erlang.cookie`
- CLI user: `$HOME/.erlang.cookie`
- Must be identical across all cluster members

### 8.2 Peer Discovery

Configure in `rabbitmq.conf`:
```ini
cluster_formation.peer_discovery_backend = rabbit_peer_discovery_classic_config
```

#### Classic Config (Static)
```ini
cluster_formation.classic_config.nodes.1 = rabbit@node1.example.com
cluster_formation.classic_config.nodes.2 = rabbit@node2.example.com
cluster_formation.classic_config.nodes.3 = rabbit@node3.example.com
```

#### DNS-Based
```ini
cluster_formation.peer_discovery_backend = rabbit_peer_discovery_dns
cluster_formation.dns.hostname = rabbitmq.cluster.internal
```
DNS returns A/AAAA records; requires 1-20 second random startup delay to avoid race conditions.

#### Kubernetes (RabbitMQ 4.1 New Plugin)
```ini
cluster_formation.peer_discovery_backend = rabbit_peer_discovery_k8s
```
- Pod with `-0` suffix is the seed node (forms initial cluster)
- All other pods join the seed node
- No Kubernetes API calls required
- `publishNotReadyAddresses: true` must be set on the headless service
- Reduce CoreDNS caching to 5-10 seconds (from default 30s)

#### AWS EC2
```ini
cluster_formation.peer_discovery_backend = rabbit_peer_discovery_aws
cluster_formation.aws.region = us-east-1
cluster_formation.aws.use_autoscaling_group = true
```

#### Consul
```ini
cluster_formation.peer_discovery_backend = rabbit_peer_discovery_consul
cluster_formation.consul.host = consul.example.com
```

#### Manual Cluster Operations
```bash
# Stop RabbitMQ app (keeps Erlang VM running)
rabbitmqctl stop_app

# Reset node (removes from cluster)
rabbitmqctl reset

# Join cluster
rabbitmqctl join_cluster rabbit@node1

# Start RabbitMQ app
rabbitmqctl start_app

# Remove a down node
rabbitmqctl forget_cluster_node rabbit@dead-node

# Full cluster status
rabbitmqctl cluster_status
```

### 8.3 Network Partitions

**Detection:** Nodes detect peer failure after 60 seconds by default. Reconnection after belief of peer being down triggers partition detection.

**Detection indicators:**
- Server logs: `mnesia_event got {inconsistent_database, running_partitioned_network}`
- CLI: `rabbitmq-diagnostics cluster_status`
- HTTP API: `GET /api/nodes` — `partitions` field
- Management UI: Warning banner on overview page

#### Partition Handling Strategies

Configure in `rabbitmq.conf`:
```ini
cluster_partition_handling = pause_minority
```

| Strategy        | Behavior                                               | Use Case                              |
|----------------|-------------------------------------------------------|---------------------------------------|
| `ignore`        | No automatic action; nodes continue independently     | Highest reliability network, same rack|
| `pause_minority`| Pauses nodes in minority (≤50% of cluster)            | Cross-rack/AZ deployment, 3+ nodes    |
| `autoheal`      | Restarts nodes not in winning partition               | Prioritize continuity over consistency|
| `pause_if_all_down` | Pauses if specified nodes unreachable            | Custom topology requirements          |

**pause_minority** checks every second for cluster restoration. Erlang VM keeps running but stops listening on client ports.

**autoheal** winning partition determination: most clients connected → most nodes → random.

**Do NOT use pause_minority with 2-node clusters** — any failure causes both nodes to pause.

#### `pause_if_all_down` Configuration
```ini
cluster_partition_handling = pause_if_all_down
cluster_partition_handling.pause_if_all_down.recover = ignore
cluster_partition_handling.pause_if_all_down.nodes.1 = rabbit@node1
cluster_partition_handling.pause_if_all_down.nodes.2 = rabbit@node2
```

#### Manual Split-Brain Recovery
1. Identify trusted partition (has most up-to-date state)
2. Stop all nodes NOT in trusted partition
3. Restart them — they rejoin and adopt trusted state
4. Restart trusted partition nodes to clear partition warnings

---

## 9. MANAGEMENT AND OPERATIONS

### 9.1 Management UI

Enabled via plugin: `rabbitmq_management`. Accessible on port **15672**.

Features:
- Overview dashboard with cluster-wide metrics
- Queue/exchange/binding management
- User and vhost management
- Policy management
- Message publishing/getting (testing only)
- Connections and channels listing
- Node health indicators
- Definitions export/import

**Note (4.0+):** Performance-related metrics are being deprecated from the Management UI in favor of Prometheus. Metrics from Management UI may not be available in future versions.

```bash
# Enable management plugin
rabbitmq-plugins enable rabbitmq_management

# Enable management agent (on all nodes, for aggregated stats)
rabbitmq-plugins enable rabbitmq_management_agent
```

### 9.2 CLI Tools

#### rabbitmqctl — Primary Management Tool
```bash
# Node health
rabbitmqctl status
rabbitmqctl node_health_check  # deprecated; use rabbitmq-diagnostics

# User management
rabbitmqctl list_users
rabbitmqctl add_user myuser mypassword
rabbitmqctl delete_user myuser
rabbitmqctl change_password myuser newpassword
rabbitmqctl set_user_tags myuser administrator management

# Vhost management
rabbitmqctl list_vhosts name description
rabbitmqctl add_vhost /myvhost --description "My vhost"
rabbitmqctl delete_vhost /myvhost

# Permissions
rabbitmqctl set_permissions -p /myvhost myuser ".*" ".*" ".*"
rabbitmqctl list_permissions -p /myvhost
rabbitmqctl clear_permissions -p /myvhost myuser

# Queue operations
rabbitmqctl list_queues -p /myvhost name messages consumers memory
rabbitmqctl purge_queue -p /myvhost my.queue
rabbitmqctl delete_queue -p /myvhost my.queue

# Exchange listing
rabbitmqctl list_exchanges -p /myvhost name type durable

# Binding listing
rabbitmqctl list_bindings -p /myvhost

# Policy management
rabbitmqctl list_policies -p /myvhost
rabbitmqctl set_policy -p /myvhost MyPolicy "^amq\." '{"max-length":1000}' --apply-to queues
rabbitmqctl clear_policy -p /myvhost MyPolicy

# Connection management
rabbitmqctl list_connections name user state channels
rabbitmqctl close_connection "connection-name" "reason"

# Channel listing
rabbitmqctl list_channels name connection messages_unacknowledged

# Memory watermarks (runtime)
rabbitmqctl set_vm_memory_high_watermark 0.6
rabbitmqctl set_vm_memory_high_watermark absolute "4G"
rabbitmqctl set_disk_free_limit "2G"

# Feature flags
rabbitmqctl list_feature_flags
rabbitmqctl enable_feature_flag khepri_db
rabbitmqctl enable_feature_flag all

# Definitions export/import
rabbitmqctl export_definitions /tmp/definitions.json
rabbitmqctl import_definitions /tmp/definitions.json

# Cluster operations
rabbitmqctl cluster_status
rabbitmqctl forget_cluster_node rabbit@dead-node
rabbitmqctl join_cluster rabbit@seed-node
```

#### rabbitmq-diagnostics — Inspection and Health Checks
```bash
# Basic health checks (staged approach)
rabbitmq-diagnostics ping
rabbitmq-diagnostics status
rabbitmq-diagnostics check_running
rabbitmq-diagnostics check_local_alarms
rabbitmq-diagnostics check_alarms
rabbitmq-diagnostics check_port_connectivity
rabbitmq-diagnostics check_virtual_hosts
rabbitmq-diagnostics check_certificate_expiration --unit weeks --within 4

# Memory analysis
rabbitmq-diagnostics memory_breakdown
rabbitmq-diagnostics memory_breakdown --unit gigabytes

# Cluster analysis
rabbitmq-diagnostics cluster_status

# Queue inspection
rabbitmq-diagnostics list_queues
rabbitmq-diagnostics list_unresponsive_queues
rabbitmq-diagnostics maybe_stuck  # samples Erlang process stack traces

# Log streaming
rabbitmq-diagnostics log_tail
rabbitmq-diagnostics log_tail_stream --duration 60

# Real-time event streaming
rabbitmq-diagnostics consume_event_stream

# Runtime observer (top-like interface)
rabbitmq-diagnostics observer

# Erlang/version info
rabbitmq-diagnostics erlang_version
rabbitmq-diagnostics server_version

# Peer discovery
rabbitmq-diagnostics discover_peers
```

#### rabbitmq-plugins — Plugin Management
```bash
rabbitmq-plugins list
rabbitmq-plugins enable rabbitmq_prometheus
rabbitmq-plugins enable rabbitmq_management
rabbitmq-plugins enable rabbitmq_mqtt
rabbitmq-plugins enable rabbitmq_stomp
rabbitmq-plugins enable rabbitmq_shovel
rabbitmq-plugins disable rabbitmq_stomp
```

#### rabbitmq-queues — Quorum Queue Operations
```bash
rabbitmq-queues add_member -p /vhost queue-name rabbit@node
rabbitmq-queues delete_member -p /vhost queue-name rabbit@node
rabbitmq-queues grow rabbit@node all
rabbitmq-queues shrink rabbit@node
rabbitmq-queues rebalance quorum
rabbitmq-queues check_if_node_is_quorum_critical
rabbitmq-queues check_if_node_is_mirror_sync_critical
```

#### rabbitmq-streams — Stream Operations
```bash
rabbitmq-streams add_replica -p /vhost stream-name rabbit@node
rabbitmq-streams delete_replica -p /vhost stream-name rabbit@node
rabbitmq-streams stream_status -p /vhost stream-name
rabbitmq-streams restart_stream -p /vhost stream-name
rabbitmq-streams add_super_stream stream-name --partitions 3
rabbitmq-streams delete_super_stream stream-name
```

#### rabbitmqadmin v2 (HTTP API Client, New in 4.1)
```bash
# Install
pip install rabbitmqadmin

# List operations
rabbitmqadmin list queues
rabbitmqadmin list exchanges
rabbitmqadmin list bindings
rabbitmqadmin list connections

# Declare resources
rabbitmqadmin declare exchange name=my.exchange type=direct durable=true
rabbitmqadmin declare queue name=my.queue durable=true arguments='{"x-queue-type":"quorum"}'
rabbitmqadmin declare binding source=my.exchange destination=my.queue routing_key=my.key

# Delete resources
rabbitmqadmin delete exchange name=my.exchange
rabbitmqadmin delete queue name=my.queue

# Publish and consume (testing only)
rabbitmqadmin publish exchange=my.exchange routing_key=my.key payload="hello"
rabbitmqadmin get queue=my.queue count=5

# Definitions
rabbitmqadmin export /tmp/definitions.json
rabbitmqadmin import /tmp/definitions.json
```

### 9.3 HTTP API

Base URL: `http://node:15672/api/`

Key endpoints:
```
GET  /api/overview                    — Cluster-wide stats
GET  /api/nodes                       — Node list with health info
GET  /api/nodes/{node}                — Specific node details
GET  /api/queues                      — All queues
GET  /api/queues/{vhost}/{name}       — Specific queue
DELETE /api/queues/{vhost}/{name}     — Delete queue
POST /api/queues/{vhost}/{name}/purge — Purge queue
GET  /api/exchanges                   — All exchanges
GET  /api/bindings                    — All bindings
GET  /api/connections                 — All connections
DELETE /api/connections/{name}        — Close connection
GET  /api/vhosts                      — Virtual hosts
PUT  /api/vhosts/{name}               — Create vhost
GET  /api/policies/{vhost}            — Policies for vhost
PUT  /api/policies/{vhost}/{name}     — Create/update policy
GET  /api/definitions                 — Export definitions
POST /api/definitions                 — Import definitions
GET  /api/users                       — List users
GET  /api/health/checks/alarms        — Health check: alarms
GET  /api/health/checks/node-is-quorum-critical — Quorum check
```

Authentication: HTTP Basic Auth. Default: guest/guest (localhost only).

### 9.4 Prometheus Metrics

Enable plugin:
```bash
rabbitmq-plugins enable rabbitmq_prometheus
```

Endpoints on port 15692:
- `/metrics` — aggregated metrics (low overhead, recommended for most)
- `/metrics/per-object` — individual entity metrics (expensive for large deployments)
- `/metrics/detailed?family=queue_coarse_metrics&vhost=myvhost` — filtered per-object

**Key metrics:**
```
rabbitmq_detailed_queue_messages                  # Total queue depth
rabbitmq_detailed_queue_messages_ready            # Messages ready for delivery
rabbitmq_detailed_queue_messages_unacked          # Unacknowledged messages
rabbitmq_detailed_queue_consumers                 # Active consumers
rabbitmq_detailed_connections_opened_total        # Cumulative connections
rabbitmq_detailed_channels_opened_total           # Cumulative channels
rabbitmq_detailed_process_resident_memory_bytes   # Node memory
rabbitmq_detailed_process_open_fds                # File descriptors
rabbitmq_detailed_erlang_processes_used           # Erlang processes
rabbitmq_detailed_exchange_messages_published_total # Messages to exchanges
rabbitmq_detailed_exchange_messages_confirmed_total # Confirmed publishes
```

Recommended scrape interval: 15-30 seconds. Use Grafana dashboards from `grafana.com/orgs/rabbitmq`.

### 9.5 Definitions Export/Import

Definitions capture broker topology (exchanges, queues, bindings, users, vhosts, policies) but NOT messages.

```bash
# Export via CLI
rabbitmqctl export_definitions /path/to/definitions.json

# Export via HTTP API
curl -u guest:guest http://localhost:15672/api/definitions > definitions.json

# Import via CLI
rabbitmqctl import_definitions /path/to/definitions.json

# Import via HTTP API
curl -u guest:guest -X POST http://localhost:15672/api/definitions \
  -H "Content-Type: application/json" \
  -d @definitions.json
```

---

## 10. MEMORY AND DISK ALARMS

### 10.1 Memory Configuration

Default threshold: 60% of available RAM.

```ini
# rabbitmq.conf
# Relative threshold (fraction of total RAM)
vm_memory_high_watermark.relative = 0.6

# Absolute threshold (recommended for containers)
vm_memory_high_watermark.absolute = 4Gi
vm_memory_high_watermark.absolute = 4096MiB
```

Runtime adjustment:
```bash
rabbitmqctl set_vm_memory_high_watermark 0.7
rabbitmqctl set_vm_memory_high_watermark absolute "4G"
rabbitmqctl set_vm_memory_high_watermark 0  # block all publishing immediately
```

**Paging threshold:** When memory usage reaches the paging threshold (typically 50% of watermark), RabbitMQ starts writing messages to disk to free memory before the alarm triggers.

**Memory breakdown:**
```bash
rabbitmq-diagnostics memory_breakdown
rabbitmq-diagnostics memory_breakdown --unit megabytes
```

### 10.2 Disk Alarms

Default minimum free disk: 50 MB (development default; dangerously low for production).

```ini
# rabbitmq.conf
disk_free_limit.relative = 1.0    # Match RAM size
disk_free_limit.absolute = 4G     # Absolute minimum free space
disk_free_limit.absolute = 4Gi
```

Runtime adjustment:
```bash
rabbitmqctl set_disk_free_limit "2G"
rabbitmqctl set_disk_free_limit mem_relative 1.5
```

**Production recommendation:** Set `disk_free_limit.absolute` equal to or greater than the memory high watermark value.

### 10.3 Flow Control Behavior

When memory or disk alarm triggers:
1. All publishing connections are **blocked** (reads suspended)
2. Consuming-only connections continue unaffected
3. Cluster-wide effect — one node's alarm blocks all nodes
4. Connection heartbeat monitoring is deactivated during alarm state

Connection states visible in management UI and `rabbitmqctl list_connections`:
- `blocking` — has not yet attempted to publish; can continue
- `blocked` — has published; now paused

Client notification via `connection.blocked` protocol extension (modern clients support this).

---

## 11. TLS CONFIGURATION

### 11.1 Basic TLS Setup

```ini
# rabbitmq.conf
listeners.ssl.default = 5671

ssl_options.cacertfile = /path/to/ca_certificate.pem
ssl_options.certfile   = /path/to/server_certificate.pem
ssl_options.keyfile    = /path/to/server_key.pem
ssl_options.verify     = verify_peer
ssl_options.fail_if_no_peer_cert = true

# TLS version restrictions (disable older versions)
ssl_options.versions.1 = tlsv1.3
ssl_options.versions.2 = tlsv1.2
```

### 11.2 Inter-Node TLS

```ini
# advanced.config
[
  {rabbit, [
    {cluster_nodes, {['rabbit@node1', 'rabbit@node2'], disc}},
    {ssl_dist_opt, [
      {server_certfile, "/path/to/server_certificate.pem"},
      {server_keyfile, "/path/to/server_key.pem"},
      {server_cacertfile, "/path/to/ca_certificate.pem"},
      {server_verify, verify_peer},
      {server_fail_if_no_peer_cert, true}
    ]}
  ]}
].
```

**Performance note:** TLS adds CPU overhead for encryption/decryption. For internal services within a trusted VPC, VPC peering provides comparable security with better performance.

### 11.3 Certificate Monitoring
```bash
# Check certificate expiration
rabbitmq-diagnostics check_certificate_expiration --unit weeks --within 4
```

---

## 12. BEST PRACTICES

### 12.1 Queue Type Selection

| Scenario                                    | Recommended Queue Type |
|--------------------------------------------|----------------------|
| Critical business data, needs HA            | Quorum               |
| Event streaming, replay, large fan-out      | Stream               |
| Temporary scratch queues, non-critical      | Classic              |
| Work queue with exactly-once processing     | Quorum               |
| IoT message ingestion at scale              | Stream               |
| Scheduled task queues                       | Quorum               |
| Request-reply (RPC patterns)                | Classic or Quorum    |

### 12.2 Exchange Topology Patterns

**Work Queue Pattern:**
- Default exchange + queue name as routing key
- Multiple consumers on one queue
- Round-robin delivery

**Publish/Subscribe Pattern:**
- Fanout exchange
- Each subscriber has their own queue bound to the exchange
- All subscribers receive all messages

**Routing Pattern:**
- Direct exchange with specific routing keys
- Selective message delivery to different queues

**Topic-Based Routing:**
- Topic exchange
- Wildcards enable flexible subscription patterns
- e.g., `logs.*.error` catches all error logs from any service

**Dead Letter Topology:**
- Source queue → DLX exchange → DL queue
- Always configure DLX on quorum queues in production

### 12.3 Connection and Channel Management

```
Anti-pattern: new connection per request
Best practice: long-lived connection + channel per thread
```

Rules:
1. One TCP connection per application instance
2. Multiple channels per connection (one per thread/coroutine)
3. Separate connections for publishing and consuming
4. Close unused channels promptly
5. Avoid channels with large numbers of unacked messages accumulating
6. Set heartbeats: `heartbeat = 60` (seconds)
7. Handle `connection.blocked` notifications in client code

### 12.4 Cluster Sizing

- Minimum production: **3 nodes** (tolerates 1 failure)
- Recommended: **odd number** (3, 5, 7) to maintain quorum
- Maximum practical: ~7 nodes per cluster; use multiple clusters for larger scale
- Do not colocate with other data services
- Use dedicated NVMe/SSD storage
- Minimum per node: 4 CPU cores, 4 GiB RAM

### 12.5 Policy Management

Policies are the preferred way to configure queue and exchange behavior (vs. hardcoded arguments):
- Dynamically updateable without redeployment
- Applied to multiple queues/exchanges via regex
- Priority system (higher number = higher priority)
- Cannot override queue type, priority max (these require queue arguments)

```bash
# Apply policy to all queues in a vhost
rabbitmqctl set_policy -p /prod global-defaults ".*" \
  '{"max-length": 100000, "dead-letter-exchange": "dlx"}' \
  --apply-to queues --priority 1

# Apply higher-priority override to specific queues
rabbitmqctl set_policy -p /prod critical-queues "^critical\." \
  '{"max-length": 1000000, "delivery-limit": 5}' \
  --apply-to quorum_queues --priority 10
```

---

## 13. DIAGNOSTICS AND TROUBLESHOOTING

### 13.1 Memory Issues

**Symptoms:** `blocked` connections, high memory alarm, slow publishing.

```bash
# Check memory breakdown
rabbitmq-diagnostics memory_breakdown --unit megabytes

# Check for alarms
rabbitmq-diagnostics check_alarms

# Identify queue memory consumers
rabbitmqctl list_queues name memory messages consumers --sort-by memory

# Temporarily lower watermark to trigger paging
rabbitmqctl set_vm_memory_high_watermark 0.3

# Emergency: block all publishing
rabbitmqctl set_vm_memory_high_watermark 0
```

**Common causes:**
- Large number of unacknowledged messages (consumers too slow)
- Queue buildup due to absent/slow consumers
- Too many connections/channels (each has memory overhead)
- Message payloads too large

### 13.2 Queue Buildup / Consumer Lag

**Symptoms:** Queue depth growing, message delivery rate lagging publish rate.

```bash
# List queues with message counts and consumer count
rabbitmqctl list_queues name messages messages_ready messages_unacknowledged consumers

# Find queues with 0 consumers
rabbitmqctl list_queues name messages consumers | grep " 0$"

# Prometheus: alert on
# rabbitmq_detailed_queue_messages > threshold AND rabbitmq_detailed_queue_consumers == 0

# Purge a stuck queue (DESTRUCTIVE)
rabbitmqctl purge_queue -p /myvhost stuck.queue
```

**Solutions:**
- Add more consumers
- Increase consumer prefetch
- Scale consumer processes/containers
- Check for consumer-side errors causing constant nack loops
- Verify dead letter configuration to prevent message loss

### 13.3 Unresponsive Queues

```bash
# Find queues not responding to health queries
rabbitmq-diagnostics list_unresponsive_queues

# Check if a node is Raft-critical before maintenance
rabbitmq-queues check_if_node_is_quorum_critical

# Sample stack traces for stuck processes
rabbitmq-diagnostics maybe_stuck
```

### 13.4 Network Partition Recovery

```bash
# Detect partitions
rabbitmq-diagnostics cluster_status
# Look for "partitions" in output

# HTTP API partition check
curl -u guest:guest http://localhost:15672/api/nodes | jq '.[].partitions'

# Identify nodes in partition
rabbitmqctl cluster_status | grep -A5 "partitions"

# Manual recovery: stop non-trusted nodes
rabbitmqctl -n rabbit@untrusted-node stop_app
rabbitmqctl -n rabbit@untrusted-node reset
rabbitmqctl -n rabbit@untrusted-node start_app
```

### 13.5 Node Health Checks (Staged Approach)

```bash
# Stage 1: Is the Erlang VM running?
rabbitmq-diagnostics ping -n rabbit@target-node

# Stage 2: Is RabbitMQ running? Any basic issues?
rabbitmq-diagnostics status -n rabbit@target-node

# Stage 3: Is RabbitMQ app running? Any alarms?
rabbitmq-diagnostics check_running -n rabbit@target-node
rabbitmq-diagnostics check_local_alarms -n rabbit@target-node

# Stage 4: Are listeners up?
rabbitmq-diagnostics check_port_connectivity -n rabbit@target-node

# Stage 5: Are vhosts healthy?
rabbitmq-diagnostics check_virtual_hosts -n rabbit@target-node

# Full cluster alarm check
rabbitmq-diagnostics check_alarms
```

### 13.6 Log Analysis

Default log location: `/var/log/rabbitmq/rabbit@<hostname>.log`

**Common log patterns:**
```
# Memory alarm triggered
{resource_limit,memory,rabbit@node1}

# Disk alarm triggered
{resource_limit,disk,rabbit@node1}

# Connection closed unexpectedly
closing AMQP connection <0.xxx.0> (client closed TCP connection)

# Channel error
AMQP connection <0.xxx.0>, channel 1 - error:
{amqp_error,precondition_failed,...}

# Network partition detected
Mnesia(rabbit@node): ** ERROR ** mnesia_event got {inconsistent_database,...}

# Node joining cluster
Node rabbit@node2 up; nodes in cluster: [rabbit@node1,rabbit@node2]

# Queue master failover (quorum queues)
quorum_queue: ~s new leader elected: ~p
```

Live log streaming:
```bash
rabbitmq-diagnostics log_tail_stream --duration 300
```

### 13.7 File Descriptor Exhaustion

```bash
# Check current fd usage
rabbitmq-diagnostics status | grep -i "file descriptors"

# Check system limit
ulimit -n

# Prometheus metric
rabbitmq_detailed_process_open_fds
```

Production recommendation: Set fd limit to 50,000-500,000 for the RabbitMQ OS user.

```bash
# /etc/security/limits.conf or systemd unit
rabbitmq soft nofile 65536
rabbitmq hard nofile 65536
```

---

## 14. CONFIGURATION REFERENCE

### 14.1 Key rabbitmq.conf Settings

```ini
# Networking
listeners.tcp.default = 5672
listeners.ssl.default = 5671
management.tcp.port = 15672

# Memory
vm_memory_high_watermark.relative = 0.6
vm_memory_high_watermark.absolute = 4Gi  # use for containers

# Disk
disk_free_limit.relative = 1.0
disk_free_limit.absolute = 4G

# Heartbeat (seconds)
heartbeat = 60

# Frame size (AMQP 0-9-1; min 8192 in 4.1+)
frame_max = 131072

# Default queue type (4.2+ new installs)
default_queue_type = quorum

# Cluster
cluster_name = my-rabbitmq-cluster
cluster_partition_handling = pause_minority

# Logging
log.file.level = info
log.console = true
log.console.level = info

# Anonymous login (disable for production)
anonymous_login_user = none
anonymous_login_pass = none

# Prometheus metrics collection interval
collect_statistics_interval = 10000

# Max message size (4.0 default: 16 MiB)
max_message_size = 16777216
```

### 14.2 Feature Flags Management

```bash
# List all feature flags and their status
rabbitmqctl list_feature_flags

# Enable a specific feature flag
rabbitmqctl enable_feature_flag khepri_db

# Enable all supported feature flags (run after each upgrade)
rabbitmqctl enable_feature_flag all
```

Feature flag states:
- `disabled` — not enabled
- `enabled` — active
- `stable` — enabled by `enable_feature_flag all`
- `required` — always enabled; cannot be disabled

---

## 15. COMMON ERROR MESSAGES

```
# Queue already exists with different properties
{amqp_error,precondition_failed,
  "inequivalent arg 'x-queue-type' for queue 'my.queue' in vhost '/': 
   received the value 'classic' of type 'longstr' but current is the value 'quorum'",
  'queue.declare'}

# Node not a cluster member
{error,{not_a_cluster_member, rabbit@node2}}

# Memory alarm — publishing blocked
basic.return message: The AMQP connection's publisher has been rate limited

# Classic queue CQv1 config preventing startup (4.0+)
BOOT FAILED
===========
Error description:
   {error,{inconsistent_value,classic_queue.default_version,1,2}}

# Delivery limit exceeded (quorum queue)
message rejected: delivery limit exceeded for queue 'my.queue'

# Erlang cookie mismatch
{error, {could_not_connect_to_rabbit, rabbit@node2, 
         {failed_to_auth, "authentication failed"}}}

# Partition detected in logs
Mnesia(rabbit@node1): ** ERROR ** mnesia_event got 
  {inconsistent_database, running_partitioned_network, rabbit@node2}
```

---

## 16. SOURCES AND REFERENCES

- RabbitMQ Official Documentation: https://www.rabbitmq.com/docs/
- Quorum Queues: https://www.rabbitmq.com/docs/quorum-queues
- Streams: https://www.rabbitmq.com/docs/streams
- Exchanges: https://www.rabbitmq.com/docs/exchanges
- Dead Letter Exchanges: https://www.rabbitmq.com/docs/dlx
- TTL: https://www.rabbitmq.com/docs/ttl
- Confirms: https://www.rabbitmq.com/docs/confirms
- Memory Alarms: https://www.rabbitmq.com/docs/memory
- Partitions: https://www.rabbitmq.com/docs/partitions
- Cluster Formation: https://www.rabbitmq.com/docs/cluster-formation
- Prometheus: https://www.rabbitmq.com/docs/prometheus
- Monitoring: https://www.rabbitmq.com/docs/monitoring
- Production Checklist: https://www.rabbitmq.com/docs/production-checklist
- Metadata Store (Khepri): https://www.rabbitmq.com/docs/metadata-store
- 4.0 Release Notes: https://github.com/rabbitmq/rabbitmq-server/blob/main/release-notes/4.0.1.md
- 4.1 Release Notes: https://github.com/rabbitmq/rabbitmq-server/blob/main/release-notes/4.1.0.md
- 4.2 Release Notes: https://github.com/rabbitmq/rabbitmq-server/blob/main/release-notes/4.2.0.md
- Native AMQP 1.0 Blog: https://www.rabbitmq.com/blog/2024/08/05/native-amqp
- CloudAMQP RabbitMQ 4.0: https://www.cloudamqp.com/blog/rabbitmq-403.html
- CloudAMQP RabbitMQ 4.2: https://www.cloudamqp.com/blog/cloudamqp-announcing-rabbitmq-version-4-2.html
- Khepri Default Roadmap: https://www.rabbitmq.com/blog/2025/09/01/6-khepri-default
- RabbitMQ 4.1 K8s Peer Discovery: https://www.rabbitmq.com/blog/2025/04/04/new-k8s-peer-discovery
