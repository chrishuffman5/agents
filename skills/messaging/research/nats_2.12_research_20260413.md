# NATS 2.x Research Document (Focus: 2.10–2.12)

**Research Date:** April 2026  
**Target Version:** NATS Server 2.12+ (covers 2.10, 2.11, 2.12 differences)  
**Source:** Official NATS Documentation, Release Notes, Synadia Blog

---

## 1. ARCHITECTURE OVERVIEW

### 1.1 Core NATS (Fire-and-Forget Pub/Sub)

Core NATS is the foundational layer of any NATS system. It operates on a publish-subscribe model using subject/topic-based addressing with **at-most-once, best-effort delivery**. There is no persistence — if no subscriber is active when a message is published, that message is dropped. This is intentional: Core NATS is optimized for speed and simplicity.

**Key characteristics:**
- Sub-millisecond latency at scale (millions of messages/second on commodity hardware)
- Location independence: publishers and subscribers are decoupled by subject name only
- Default many-to-many (M:N) communication pattern
- No load balancers or API gateways required
- Single binary, zero external dependencies

**Message flow:**
1. Publisher sends `PUB <subject> <payload>`
2. Server routes to all active subscribers for that subject
3. No acknowledgment from server to publisher (fire-and-forget)

### 1.2 Subject-Based Addressing

Subjects are string-based channel names using `.` as a token separator. All routing is purely by subject match — no concept of topics, partitions, or brokers per se.

**Subject rules:**
- Tokens separated by `.` (e.g., `orders.us.east.created`)
- Allowed characters: any Unicode except null, space, `.`, `*`, `>`
- Recommended: alphanumeric plus `-` and `_` (case-sensitive, no whitespace)
- Maximum recommended: 16 tokens, 256 characters total
- Reserved prefix `$`: used for system subjects (`$SYS`, `$JS`, `$KV`, `$NRG`)
- Reserved prefix `_INBOX`: used for reply-to inbox addresses

**Wildcard tokens (subscribers only — cannot publish to wildcards):**
- `*` — single token wildcard: `orders.*.created` matches `orders.us.created` and `orders.eu.created` but not `orders.us.east.created`
- `>` — multi-token tail wildcard (must be last token): `orders.>` matches `orders.us`, `orders.us.east`, `orders.us.east.created`
- Wildcards can be combined: `orders.*.>` matches `orders.us.east.created`

**Subject design best practices:**
- Encode business intent, not technical details
- Use early tokens for general namespaces, later tokens for specific entities
- Example: `factory1.tools.group42.unit17.temperature`
- Reserve `$` prefixes for system use
- Avoid over-complicating initial designs; subjects can be hierarchical but should be readable

### 1.3 Queue Groups

Queue groups provide built-in load balancing across multiple subscribers. When multiple subscribers join the same **queue group name** on a subject, the server delivers each message to exactly one randomly chosen member of the group.

**How they work:**
- Subscribers declare queue group membership when subscribing (not a server configuration)
- Server selects one random member per message delivery
- Non-queue subscriptions still receive all messages (fan-out still works alongside queue groups)
- Adding/removing queue members requires no server reconfiguration

**Key behaviors:**
- **Fault tolerance**: If a subscriber fails, remaining members continue processing
- **Graceful scaling**: Spin up new instances, drain old ones, no message loss
- **Draining**: Clients can drain subscriptions before shutting down, processing all in-flight messages
- **No-responders**: Server sends a 503-equivalent if no queue subscribers exist (for request-reply)
- **Geo-affinity**: In clustered/super-cluster deployments, the server prefers local queue subscribers before routing cross-region

**CLI example:**
```bash
# Subscriber 1 joins queue group "workers"
nats sub --queue workers "orders.>"

# Subscriber 2 joins the same queue group (load-balanced with subscriber 1)
nats sub --queue workers "orders.>"

# Publisher — messages distribute across both subscribers
nats pub orders.us.created '{"id": 123}'
```

### 1.4 Request-Reply Pattern

NATS implements synchronous request-reply using Core pub/sub with dynamic reply-to subjects (inboxes).

**How it works:**
1. Requester creates a unique inbox subject (e.g., `_INBOX.abc123`)
2. Requester publishes request to a service subject with reply-to set to inbox
3. Responder receives request, sends reply to the inbox subject
4. Requester receives reply on its inbox subscription

**Inbox addresses:** Dynamically generated, unique subjects (`_INBOX.<nuid>`) — location transparent. The requester and responder do not need to know each other's location.

**Timeout handling:** Client SDKs support configurable timeouts. If no responder exists and the server supports headers, the client receives an immediate reply with status `503 No Responders`.

**Scatter-gather pattern:** Multiple responders can reply; the client library typically returns the first response and discards subsequent ones. This enables low-latency service discovery by picking the fastest responder.

**CLI examples:**
```bash
# Service responder
nats reply "time.now" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Client request (waits up to 2 seconds)
nats request "time.now" "" --timeout 2s
```

---

## 2. JETSTREAM

JetStream is NATS's built-in persistence engine. It adds durable messaging, replay, and stream processing on top of Core NATS, implemented entirely in the nats-server binary with no external dependencies.

### 2.1 Core Concepts

**JetStream vs. Core NATS:**
| Feature | Core NATS | JetStream |
|---|---|---|
| Delivery guarantee | At-most-once | At-least-once or Exactly-once |
| Persistence | No | Yes (file or memory) |
| Replay | No | Yes |
| Consumer tracking | No | Yes (durable state) |
| Flow control | Per-connection | Per-consumer |
| Clustering | Route mesh | RAFT consensus |

**JetStream domain:** A JetStream domain isolates a cluster's JetStream assets. Useful when combining clusters with leaf nodes — leaf node's JetStream domain can differ from the hub cluster.

**Strict mode (2.12 default):** As of 2.12, the server rejects invalid JetStream API requests by default (previously only logged warnings). Disable with `jetstream { strict: false }` if needed for legacy clients.

### 2.2 Streams

A **stream** is a persistent, ordered log of messages. Streams capture messages published to one or more subjects and store them for later consumption.

**Core stream configuration:**

| Parameter | Description | Default |
|---|---|---|
| `Name` | Unique name within account | Required |
| `Subjects` | Subjects to capture (supports wildcards) | Required |
| `Storage` | `File` or `Memory` | `File` |
| `Replicas` | Number of copies in cluster (1–5) | 1 |
| `MaxAge` | Maximum message age (nanoseconds) | 0 (unlimited) |
| `MaxBytes` | Maximum total stream size | -1 (unlimited) |
| `MaxMsgs` | Maximum total message count | -1 (unlimited) |
| `MaxMsgSize` | Maximum single message size | -1 (unlimited) |
| `MaxMsgsPerSubject` | Per-subject message cap | 0 (unlimited) |
| `MaxConsumers` | Maximum consumers on this stream | -1 (unlimited) |
| `Retention` | `LimitsPolicy`, `WorkQueuePolicy`, `InterestPolicy` | `LimitsPolicy` |
| `Discard` | `DiscardOld` or `DiscardNew` | `DiscardOld` |
| `DiscardNewPerSubject` | Apply DiscardNew per-subject when using per-subject limits | false |
| `Duplicates` | Deduplication window (duration) | 2 minutes |
| `AllowRollup` | Allow rollup via `Nats-Rollup` header | false |
| `DenyDelete` | Prevent individual message deletion | false |
| `DenyPurge` | Prevent stream purge | false |
| `Sealed` | No further messages or consumers allowed | false |
| `Compression` | On-disk compression: `s2` or `none` (file storage only, 2.10+) | `none` |
| `SubjectTransform` | Transform subject before storing (2.10+) | none |
| `RePublish` | Re-broadcast stored messages to alternate subjects | none |
| `AllowMsgTTL` | Enable per-message TTL via `Nats-TTL` header (2.11+) | false |
| `AllowAtomicPublish` | Atomic batch publishing (2.12+) | false |
| `AllowMsgCounter` | Distributed counter CRDT (2.12+) | false |
| `AllowMsgSchedules` | Delayed message scheduling (2.12+) | false |
| `Metadata` | Arbitrary user key-value pairs (2.10+) | none |
| `FirstSeq` | Set initial sequence number (2.10+) | 1 |

**Retention policies:**

- **`LimitsPolicy`** (default): Messages retained up to configured limits (`MaxMsgs`, `MaxBytes`, `MaxAge`). Best for replay/audit use cases.
- **`WorkQueuePolicy`**: Each message can be consumed exactly once. Message is deleted after acknowledgment. Only one consumer per subject at a time — overlapping consumers are rejected.
- **`InterestPolicy`**: Messages retained only while active consumers have not yet acknowledged them. If no consumers exist, messages are dropped immediately.

**Discard policies:**
- **`DiscardOld`**: Remove oldest messages when limits are hit (rolling window behavior)
- **`DiscardNew`**: Reject new messages when limits are hit (preserve existing data)

**CLI stream management:**
```bash
# Create a stream
nats stream add ORDERS \
  --subjects "orders.>" \
  --storage file \
  --replicas 3 \
  --retention limits \
  --max-age 7d \
  --discard old

# List streams
nats stream ls

# View stream info
nats stream info ORDERS

# Purge a stream
nats stream purge ORDERS

# Delete a stream
nats stream rm ORDERS

# Backup a stream
nats stream backup ORDERS /backup/ORDERS

# Restore a stream
nats stream restore ORDERS /backup/ORDERS
```

### 2.3 Consumers

A **consumer** is a view on a stream — a cursor that tracks which messages have been delivered and acknowledged. Multiple consumers can independently track different positions in the same stream.

**Consumer types:**

| Dimension | Options |
|---|---|
| Pull vs. Push | Pull consumers (recommended for new work) or Push consumers |
| Durable vs. Ephemeral | Durable (named, persists server-side state) or Ephemeral (temporary, memory-only) |

**Pull consumers** (recommended):
- Client requests messages on demand (`Fetch`, `FetchBatch`)
- Supports horizontal scaling: multiple clients pull from the same durable consumer
- Explicit flow control: clients control their own consumption rate
- Required for work queue semantics with multiple processors
- In 2.11+: supports priority groups, pinning, overflow policies, and pausing

**Push consumers:**
- Server pushes messages to a configured delivery subject
- Requires a dedicated delivery subject (can be a queue group subject for load-balanced push)
- Better for replay/fan-out scenarios
- Less common for new designs; pull consumers are generally preferred

**Durable consumers:**
- Explicit `Name` or `Durable` field set
- Server persists consumer state (last delivered sequence, pending acks)
- Survives server restarts; resumes where it left off
- Required for pull consumers
- `InactiveThreshold`: how long after last activity before the consumer is removed (default: 5 seconds for ephemeral)

**Ephemeral consumers:**
- No name or durable field
- Exist only in server memory; automatically cleaned up after `InactiveThreshold`
- Useful for temporary subscriptions or one-time replay

**Delivery policies (where to start consuming):**

| Policy | Behavior |
|---|---|
| `DeliverAll` | From the beginning of the stream |
| `DeliverLast` | Most recent message only |
| `DeliverNew` | Only messages published after consumer creation |
| `DeliverLastPerSubject` | Latest message per filtered subject |
| `DeliverByStartSequence` | From a specific sequence number |
| `DeliverByStartTime` | From a specific timestamp |

**Acknowledgment policies:**

| Policy | Behavior |
|---|---|
| `AckExplicit` | Each message must be individually acknowledged (default for pull) |
| `AckAll` | Acknowledging message N implicitly acknowledges messages 1 through N-1 |
| `AckNone` | No acknowledgment required; server assumes delivery = success |

**Acknowledgment types:**
- `AckAck` — message processed successfully
- `AckNak` — processing failed, redeliver (with optional delay)
- `AckProgress` — working on it; reset ack wait timer (prevents redelivery)
- `AckTerm` — stop redelivering this message (dead-letter behavior)
- `AckNext` — pull-mode: ack current and request next

**Key consumer configuration options:**

| Parameter | Description |
|---|---|
| `AckWait` | Duration server waits for ack before redelivery |
| `MaxDeliver` | Maximum redelivery attempts (-1 = unlimited) |
| `MaxAckPending` | Maximum unacknowledged messages in flight |
| `FilterSubject` | Server-side single-subject filter |
| `FilterSubjects` | Multiple disjoint subject filters (2.10+) |
| `ReplayPolicy` | `ReplayInstant` (default) or `ReplayOriginal` (simulate original timing) |
| `SampleFrequency` | Percent of acks to sample for metrics |
| `PauseUntil` | Suspend delivery until this timestamp (2.11+) |
| `PriorityGroups` | Named priority group for pull consumer pinning (2.11+) |
| `Metadata` | Arbitrary user key-value pairs (2.10+) |

**CLI consumer management:**
```bash
# Create a durable pull consumer
nats consumer add ORDERS order-processor \
  --pull \
  --deliver all \
  --ack explicit \
  --max-deliver 5 \
  --wait 30s \
  --filter "orders.us.>"

# Create a push consumer
nats consumer add ORDERS order-auditor \
  --push \
  --deliver-to "audit.orders" \
  --deliver all \
  --ack none

# List consumers
nats consumer ls ORDERS

# View consumer info (includes pending, redelivered, ack floor)
nats consumer info ORDERS order-processor

# Pull the next message
nats consumer next ORDERS order-processor

# Pull a batch of messages
nats consumer next ORDERS order-processor --count 10 --wait 5s

# Pause a consumer (2.11+)
nats consumer pause ORDERS order-processor --until "2026-04-11T00:00:00Z"

# Delete consumer
nats consumer rm ORDERS order-processor
```

### 2.4 Exactly-Once Semantics

JetStream achieves exactly-once delivery by combining two mechanisms:

**1. Publisher-side deduplication (idempotent publishing):**
- Set the `Nats-Msg-Id` header with a unique message ID on each publish
- JetStream tracks IDs within the stream's `Duplicates` window (default 2 minutes)
- Duplicate IDs within the window are acknowledged but not stored again
- The body is ignored for deduplication — only the ID matters
- Use case: safe retries on publish failure

```bash
# Publish with deduplication header
nats pub orders.us.created '{"id": 123}' \
  --header "Nats-Msg-Id: order-123-v1"
```

**2. Consumer-side double-acknowledgment:**
- Use `AckSync()` instead of `Ack()` in client SDKs
- `AckSync` sets a reply subject on the ack and waits for server confirmation
- Guarantees the server received and recorded the acknowledgment
- Prevents redelivery even if the client crashes after processing but before the ack is received by the server

**Combined pattern for exactly-once:**
1. Publisher sends with `Nats-Msg-Id` header and retries until acknowledged
2. Consumer processes message idempotently
3. Consumer uses `AckSync()` to confirm acknowledgment was recorded

### 2.5 Stream Mirrors and Sources

**Mirrors:**
- One-way, asynchronous replication from exactly one source stream
- Read-only: clients cannot publish directly to a mirror
- Preserves original sequence numbers and timestamps
- Configuration is one-sided (the mirror is configured, not the source)
- Use case: geographic distribution, read replicas, DR standby
- In 2.12: **mirror promotion** — promote a mirror to a primary stream by removing mirror config and adding original subjects

**Sources:**
- Aggregate data from multiple streams into one
- Clients can still publish directly to the stream (unlike mirrors)
- Does not preserve original sequence numbers (preserves relative ordering per source)
- Supports subject transforms when sourcing
- Use case: aggregating regional streams, combining event types

**Configuration options for both:**
- `Name`: Source stream name
- `StartSeq`: Begin replication from this sequence
- `StartTime`: Begin from this timestamp
- `FilterSubject`: Single-subject filter (incompatible with SubjectTransforms)
- `SubjectTransforms`: Transform subjects during replication
- `Domain`: Remote JetStream domain (hub-and-spoke with leaf nodes)
- `External`: External API prefix for cross-account/domain access

**Limitations:**
- `WorkQueuePolicy` streams: mirrors are only partially supported, problematic with intermittent connections
- `InterestPolicy` streams: mirroring is not supported

**CLI examples:**
```bash
# Create a mirror of ORDERS stream
nats stream add ORDERS-MIRROR \
  --mirror ORDERS \
  --mirror-start-seq 1

# Create a stream aggregating multiple sources
nats stream add ALL-EVENTS \
  --source ORDERS \
  --source RETURNS \
  --source SHIPMENTS

# Promote a mirror to primary (2.12)
nats stream edit ORDERS-MIRROR --no-mirror
```

---

## 3. KEY-VALUE STORE

NATS KV is built on JetStream streams (internally named `KV_<bucket>`). It provides immediately consistent, persistent associative arrays with watch semantics.

### 3.1 Bucket Operations

**Create a bucket:**
```bash
nats kv add my-config \
  --history 10 \
  --ttl 24h \
  --replicas 3 \
  --storage file
```

**CRUD operations:**
```bash
# Put (create or update)
nats kv put my-config database.host "db.example.com"

# Get
nats kv get my-config database.host

# Delete (places a delete marker, not immediate removal)
nats kv del my-config database.host

# Purge (removes key and all history markers)
nats kv purge my-config database.host

# List all keys
nats kv keys my-config

# Watch a key for changes (blocks, receives updates in real-time)
nats kv watch my-config database.host

# Watch all keys in bucket
nats kv watch my-config
```

### 3.2 Key Features

**Compare-and-swap (CAS):**
- `Create`: Only sets the key if no current value exists (atomic create)
- `Update`: Sets the key only if the current revision matches the provided revision
- Enables optimistic concurrency control without explicit locks

**History:**
- Buckets can retain multiple historical values per key (up to 64)
- Default history depth is 1 (only current value retained)
- History includes both value changes and delete operations
- Access via `nats kv history my-config database.host`

**TTL (Time-to-Live):**
- Bucket-level TTL: all keys expire after the configured duration
- Per-key TTL (2.11+): set `Nats-TTL` header on individual put operations (requires `AllowMsgTTL: true` on the underlying stream)
- Per-key TTL overrides bucket-level TTL for that key

**Watch semantics:**
- Watch is like a subscription — provides all current values on start, then streams updates
- Can watch a specific key, a wildcard pattern, or all keys in a bucket
- Applications receive `KeyValueEntry` events including: key, value, revision, operation (Put/Delete/Purge), timestamp

**Valid key characters:** `a-z`, `A-Z`, `0-9`, `-`, `_`, `.`, `=`, `/`

### 3.3 Implementation Details

KV buckets are JetStream streams with configuration:
- Stream name: `KV_<bucket>`
- Subject pattern: `$KV.<bucket>.>`
- `MaxMsgsPerSubject`: set to history depth
- Retention: LimitsPolicy with MaxMsgsPerSubject enforcing history
- `AllowRollup: true` (for purge operations)
- `DenyDelete: true` and `DenyPurge: true` on the stream (KV manages these via markers)

---

## 4. OBJECT STORE

NATS Object Store extends KV for large binary objects, automatically chunking files of arbitrary size.

### 4.1 Core Operations

```bash
# Create a bucket
nats object add my-files --storage file --replicas 3

# Upload a file
nats object put my-files /path/to/large-file.bin

# Download a file
nats object get my-files large-file.bin --output /tmp/large-file.bin

# List objects in bucket
nats object ls my-files

# Watch for changes
nats object watch my-files

# Delete an object
nats object del my-files large-file.bin
```

### 4.2 Implementation Details

- **Chunking:** Objects are automatically split into chunks (default chunk size: 128KB)
- **Metadata:** Each object stores metadata including name, size, chunk count, content type, checksum (SHA-256)
- **Storage:** Implemented as two streams per bucket:
  - `OBJ_<bucket>` — chunk data stream
  - Metadata stored on subjects `$OBJ.<bucket>.M.<name>` and `$OBJ.<bucket>.C.<chunk>`
- **Links:** Objects can link to other objects or entire buckets (like symlinks)
- **Limitation:** Not a distributed storage system — all objects in a bucket must fit on the server's file system
- **Watch:** Provides notifications on `put` and `del` operations

---

## 5. CLUSTERING

### 5.1 Route-Based Clustering

NATS clusters form a **full mesh topology** through a gossip protocol. Each server discovers and connects to all other servers it knows about.

**Key routing rule:** Each server only forwards messages received from a **client** to adjacent route-connected servers. Messages received from routes are delivered only to local clients, preventing message circulation.

**Configuration:**
```conf
# nats-server cluster node configuration
server_name: nats-1
host: 0.0.0.0
port: 4222

cluster {
  name: my-cluster
  host: 0.0.0.0
  port: 6222
  routes: [
    nats://nats-1:6222
    nats://nats-2:6222
    nats://nats-3:6222
  ]
}
```

**Multi-route connections (v2.10+):** NATS 2.10 introduced route pools — multiple TCP connections between servers in a cluster (default: 3 routes). Accounts can be pinned to specific route connections, and traffic can optionally be compressed.

**Cluster sizing recommendations:**
- Odd number of nodes (3 or 5) for RAFT quorum clarity
- 3-node cluster: tolerates 1 failure
- 5-node cluster: tolerates 2 failures
- Avoid even-sized clusters (split-brain risk)

### 5.2 JetStream Clustering

JetStream uses an optimized RAFT consensus algorithm for distributed persistence.

**RAFT groups in a cluster:**
1. **Meta Group**: All JetStream-enabled servers participate. Manages the JetStream API and asset placement. Elects a meta-leader. Without a meta-leader, no JetStream operations are possible.
2. **Stream Groups**: Each stream forms its own RAFT group with R servers (where R is the stream's replica count). The stream leader processes writes and acknowledgments.
3. **Consumer Groups**: Each durable consumer has its own RAFT group, co-located with stream group members.

**Fault tolerance table:**

| Stream Replicas (R) | Servers Needed for Write | Tolerable Failures |
|---|---|---|
| R=1 | 1 | 0 |
| R=3 | 2 (quorum) | 1 |
| R=5 | 3 (quorum) | 2 |

**Quorum formula:** `floor(R/2) + 1`

**Write acknowledgment:** A published message is acknowledged only after being replicated to a quorum of the stream's RAFT group. This provides linearizable consistency for writes.

**Replica placement (unique_tag):** Use `unique_tag` in the JetStream configuration to ensure replicas are placed on servers with different tag values (e.g., different availability zones):

```conf
jetstream {
  store_dir: /data/js
  unique_tag: "az"  # each replica must be on a server with different "az" tag
}
```

**JetStream clustering configuration:**
```conf
server_name: nats-1
port: 4222

system_account: SYS
accounts {
  SYS { users: [{ user: sys, password: "$2a$11$..." }] }
}

jetstream {
  store_dir: /data/jetstream
  max_mem: 4G
  max_file: 100G
}

cluster {
  name: my-js-cluster
  port: 6222
  routes: [
    nats-route://nats-1:6222
    nats-route://nats-2:6222
    nats-route://nats-3:6222
  ]
}
```

**Peer management:**
```bash
# View cluster/RAFT status
nats server report jetstream

# Force meta-leader step-down (trigger re-election)
nats server cluster step-down

# Remove a permanently failed peer
nats server cluster peer-remove <server-name>
```

### 5.3 Super-Cluster with Gateways

Gateways connect multiple clusters into a **super-cluster**. Unlike clustering routes (full mesh within a cluster), gateways reduce connection overhead:

- Full mesh routing: `N(N-1)/2` connections
- Gateway connections: `Ni × (M-1)` where Ni = nodes in gateway i, M = total gateway count
- Example: 3 clusters × 10 nodes each → full mesh needs 1,035 connections; gateways need only 60

**Interest propagation in gateways:**
- **Interest-only mode**: Gateway A sends messages to gateway B only for subjects where B has registered interest
- Interest maps update dynamically as subscriptions are added/removed
- **Queue subscriptions**: Each queue group is propagated once per account per subject; servers always prefer local queue subscribers before routing cross-cluster

**Gateway configuration:**
```conf
gateway {
  name: east-cluster
  port: 7222
  gateways: [
    { name: west-cluster, urls: ["nats://west-1:7222", "nats://west-2:7222"] }
    { name: eu-cluster, urls: ["nats://eu-1:7222", "nats://eu-2:7222"] }
  ]
}
```

**Requirements:**
- All servers in a cluster must have the same gateway `name`
- Every gateway node must be reachable by every other gateway node
- Dedicated port separate from client and cluster ports

### 5.4 Leaf Nodes

Leaf nodes are lightweight extensions that bridge a local NATS server (or cluster) to a remote cluster. They are ideal for edge computing, IoT gateways, and hybrid deployments.

**Key properties:**
- Leaf nodes do not need to be directly reachable (unlike cluster routes or gateway nodes)
- Enable explicitly configured acyclic graph topologies
- Clients authenticate locally to the leaf node; the leaf node authenticates to the hub using separate credentials
- Local traffic stays local; only relevant messages traverse the leaf-to-hub link
- Prefer local queue subscribers before routing upstream

**Leaf node configuration:**
```conf
# On the leaf node server
leafnodes {
  remotes: [
    {
      url: "nats-leaf://hub-server-1:7422"
      credentials: "/etc/nats/leaf.creds"
      tls {
        handshake_first: true  # TLS before protocol handshake (2.10+/2.11+)
      }
    }
  ]
}

# On the hub server, enable leaf connections
leafnodes {
  port: 7422
}
```

**Leaf node use cases:**
- IoT edge gateways: local devices connect to leaf, only aggregate data sent to cloud hub
- Hybrid cloud: bridge on-premises NATS to managed NATS service (e.g., Synadia NGS)
- Multi-region: low-latency local messaging with selective hub routing
- Access control: leaf node enforces local auth policy independently of hub

**`isolate_leafnode_interest` (2.12):** Reduces east-west traffic in large leaf node deployments by limiting interest propagation scope.

**`disabled: true` (2.12):** Disable a leaf connection via config reload without removing configuration.

---

## 6. SECURITY

### 6.1 Multi-Tenancy with Accounts

Accounts provide strong isolation in a shared NATS deployment. Each account has:
- Its own subject namespace (completely isolated from other accounts)
- Its own JetStream streams and consumers
- Its own connection limits and permissions
- Explicit import/export required to share any data across accounts

```conf
accounts: {
  APP_A: {
    users: [{ user: app_a_user, password: "secret" }]
    jetstream: enabled
    exports: [
      { stream: "events.>", accounts: ["APP_B"] }   # share stream
      { service: "api.>", accounts: ["APP_B"] }      # share service
    ]
  }
  APP_B: {
    users: [{ user: app_b_user, password: "secret" }]
    imports: [
      { stream: { account: APP_A, subject: "events.>" }, prefix: "from_a" }
      { service: { account: APP_A, subject: "api.>" }, to: "app_a_api" }
    ]
  }
  $SYS: {}  # system account (required for monitoring/cluster)
}
```

**Import/export types:**
- **Stream export**: Publish-once, consume-many (APP_B sees APP_A's events)
- **Service export**: Request-reply service (APP_B can call APP_A's service)
- Subject remapping: Importing account can remap subjects with `prefix` (streams) or `to` (services)

### 6.2 Authentication Methods

**Username/Password:**
```conf
authorization {
  users: [
    { user: alice, password: "$2a$11$..." }  # bcrypt recommended
    { user: bob, password: "$2a$11$...", permissions: { publish: ">" } }
  ]
}
```

**NKey Authentication:**
- Ed25519 public/private key pairs
- Server stores public key only; private key never transmitted
- Client signs a server challenge with private key to authenticate

**JWT Authentication (decentralized):**
- Three-tier trust chain: Operator → Account → User
- JWTs describe entities and their permissions
- Server validates chain without needing user database access
- User JWTs can be issued by account teams independently

**TLS / Mutual TLS:**
```conf
tls {
  cert_file: "/etc/nats/server-cert.pem"
  key_file:  "/etc/nats/server-key.pem"
  ca_file:   "/etc/nats/ca.pem"
  verify:    true           # require client certificates
  min_version: "1.3"
  timeout:   2.0
}
```

With `verify_and_map: true`, client certificate Subject Alternative Names (SANs) or certificate subjects map directly to user identities — no separate username/password required.

**Auth Callout (2.10+):**
- Pluggable authentication: delegate auth to an external NATS service
- Supports LDAP, SAML, OAuth, custom IAM backends
- Works in both centralized and decentralized (operator/JWT) deployments
- Auth service receives credential claims, returns authorization claims
- One-time keypair prevents replay attacks

### 6.3 Decentralized JWT Authentication

The operator/account/user JWT model enables full decentralized authentication without server configuration updates per user.

**Trust hierarchy:**
```
Operator (trusted by server)
  └── Account JWT (signed by Operator)
        └── User JWT (signed by Account)
```

**Validation flow:**
1. User presents JWT to server on connect
2. User signs server's cryptographic challenge with private NKey
3. Server retrieves Account JWT (from resolver) and verifies issuer = trusted Operator
4. Server confirms Account JWT was signed by trusted Operator

**Resolver types:**
- **Memory resolver**: Account JWTs embedded directly in server config (small deployments)
- **Full resolver** (built-in): Server stores account JWTs in local directory, updated via `nsc push`
- **URL resolver**: Server fetches account JWTs from external HTTP endpoint (nats-account-server)

**Server config for JWT auth:**
```conf
operator: /etc/nats/operator.jwt

resolver: {
  type: full
  dir: /data/nats/resolver
  allow_delete: false
  interval: 2m
  limit: 1000
}
```

### 6.4 NSC Tool (Credential Management)

`nsc` is the command-line tool for creating and managing operator/account/user JWTs and NKeys.

**Setup workflow:**
```bash
# Create operator with signing keys and system account
nsc add operator --generate-signing-key --sys --name my-operator

# Set service URL
nsc edit operator --service-url nats://localhost:4222

# Create an account
nsc add account my-app

# Create a user
nsc add user my-service

# Restrict user permissions
nsc edit user my-service \
  --allow-pub "orders.>" \
  --allow-sub "orders.>" "_INBOX.>"

# Generate server resolver config
nsc generate config --nats-resolver > resolver.conf

# Push accounts to NATS resolver
nsc push -A -u nats://localhost:4222

# Generate credentials file for use by clients
nsc generate creds --account my-app --user my-service > my-service.creds
```

**Using credentials:**
```bash
# Connect using credentials file
nats sub --creds my-service.creds "orders.>"
nats pub --creds my-service.creds orders.us.created '{"id": 123}'

# Create a named context for reuse
nats context add prod --server nats://prod:4222 --creds my-service.creds
nats context select prod
```

---

## 7. MANAGEMENT AND MONITORING

### 7.1 NATS CLI

The `nats` CLI is the primary management tool for day-to-day NATS operations.

**Connection contexts:**
```bash
nats context add local --server nats://localhost:4222
nats context add prod --server nats://prod:4222 --creds prod.creds
nats context select prod
nats context ls
```

**Core messaging:**
```bash
nats pub orders.created '{"id": 1}'
nats sub "orders.>"
nats request service.ping "" --timeout 2s
nats reply service.ping "pong"
```

**Server operations:**
```bash
nats server ls              # list all servers
nats server ping            # connectivity check
nats server info            # detailed server info
nats server check           # health checks
nats server report jetstream  # JetStream status across cluster
nats server report accounts   # account usage
nats server report connections  # connection details
nats server cluster step-down   # force leader re-election
nats server cluster peer-remove <name>  # remove failed peer
```

**JetStream cheat sheet:**
```bash
nats cheat    # show all command examples by category
nats bench js --pub 10 --sub 10 --size 512 --msgs 1000000 orders
nats stream ls
nats consumer ls ORDERS
nats consumer next ORDERS processor --count 100 --wait 5s
nats kv put config key value
nats kv get config key
nats kv watch config
nats object put files /path/to/file
nats object get files filename --output /tmp/out
```

### 7.2 HTTP Monitoring Endpoints

Enable the monitoring HTTP server:
```conf
# In nats-server.conf
http_port: 8222
# or for TLS
https_port: 8222
```

**Available endpoints:**

| Endpoint | Data |
|---|---|
| `/varz` | Server state, uptime, CPU/memory, message counters, config |
| `/connz` | Active connections (sortable, pageable) |
| `/routez` | Cluster route connections |
| `/gatewayz` | Super-cluster gateway details |
| `/leafz` | Leaf node connections |
| `/subsz` | Subscription routing and statistics |
| `/accountz` | Active accounts |
| `/accstatz` | Per-account stats (messages, bytes, connections) |
| `/jsz` | JetStream streams, consumers, API usage |
| `/healthz` | Server health (returns `ok` or error) |

**Note:** The monitoring port has no built-in authentication. Bind to localhost or use firewall rules in production.

### 7.3 nats-top

`nats-top` is a `top`-like real-time monitoring tool for NATS servers.

```bash
# Install
go install github.com/nats-io/nats-top@latest

# Run with monitoring port
nats-top -s nats-server:8222

# Show top 50 connections, refresh every 2 seconds
nats-top -n 50 -d 2

# Sort by messages received
nats-top -sort msgs_to
```

**Displayed metrics:** CPU, memory, connections, in/out message rates, in/out byte rates, subscriptions, slow consumers. Per-connection: client ID, subscriptions, pending bytes, messages in/out, language/version.

**Sort options:** `cid`, `subs`, `pending`, `msgs_to`, `msgs_from`, `bytes_to`, `bytes_from`, `lang`, `version`

### 7.4 Prometheus Integration

**Prometheus NATS Exporter** (`prometheus-nats-exporter`):
- Scrapes NATS HTTP monitoring endpoints
- Aggregates `varz`, `connz`, `subz`, `routez`, `healthz` into Prometheus format
- Default endpoint: `http://0.0.0.0:7777/metrics`
- Pre-built Grafana dashboards available

**NATS Surveyor** (recommended for clusters):
- Single exporter for entire NATS deployment
- Subscribes to system account events using NATS protocol (no per-server sidecars)
- Collects stream and consumer metrics (v0.9.1+)
- Caution: collecting all replica metrics can cause high cardinality in large deployments

**NATS CLI Prometheus integration:**
```bash
# Run health checks as Prometheus metrics
nats server check --prometheus-output
```

### 7.5 System Account Monitoring

The system account (`$SYS` by default) provides event-driven monitoring via NATS subjects. Configure a system account user to subscribe to:

```
$SYS.ACCOUNT.*.CONNECT    # client connect events
$SYS.ACCOUNT.*.DISCONNECT # client disconnect events
$SYS.SERVER.ACCOUNT.*     # server account statistics
$SYS.REQ.SERVER.PING.IDZ  # server identity ping
$SYS.REQ.USER.INFO        # user info request (2.10+)
```

**Configuration reload via system account (2.10+):**
```bash
# Reload a specific server's config via NATS message
nats request '$SYS.REQ.SERVER.<server-id>.RELOAD' '{}'
```

---

## 8. VERSION-SPECIFIC CHANGES

### 8.1 NATS 2.10 (Released: late 2023)

**Breaking/critical changes:**
- **On-disk storage format change**: New format for significant performance improvements; incompatible with pre-2.9.22 servers. Downgrade requires 2.9.22+.
- Default ingest rate limits applied to JetStream streams (128MB size, 10,000 messages per stream in 2.11+)

**JetStream streams (2.10 new):**
- `SubjectTransform`: Per-stream subject transformation before storage
- `Metadata`: Arbitrary user-defined key-value annotations
- `FirstSeq`: Set the starting sequence number for a new stream
- `Compression`: S2 on-disk compression for file-based streams
- `RePublish`: Editable after stream creation; includes `Nats-Time-Stamp` header
- Multi-filter consumers via `FilterSubjects` (multiple disjoint subjects)

**Clustering (2.10 new):**
- **v2 Routes**: Pool of TCP connections between cluster servers (default: 3 connections per pair), optional account pinning, optional compression

**Leaf nodes (2.10 new):**
- `handshake_first`: TLS negotiation before NATS protocol handshake
- Dual-remote configurations now allowed

**Auth (2.10 new):**
- **Auth Callout**: Pluggable authentication delegation to external services

**Monitoring (2.10 new):**
- `/varz`: Added `unique_tag` and `slow_consumer_stats` fields
- Config reload via system account message: `$SYS.REQ.SERVER.<id>.RELOAD`
- New system responders: `$SYS.REQ.SERVER.PING.IDZ`, `$SYS.REQ.USER.INFO`
- Glob expression support in `nats-server --signal` commands

**JetStream config:**
```conf
jetstream {
  store_dir: /data/js
  cipher: chacha    # chacha or aes
  key: $JS_KEY      # encryption key (env var)
  sync_interval: 2m
}
```

### 8.2 NATS 2.11 (Released: 2024)

**JetStream streams (2.11 new):**
- **Per-message TTL** (`AllowMsgTTL: true`): Individual messages can expire via `Nats-TTL` header
- **Subject delete markers**: When `MaxAge` removes the last message for a subject, a marker is placed with `Nats-Marker-Reason` header
- **Ingest rate limiting**: New `max_buffered_size` (default 128MB) and `max_buffered_msgs` (default 10,000) in JetStream config

**Consumers (2.11 new):**
- **Consumer pausing**: Temporarily suspend delivery with `PauseUntil` config or Pause API; heartbeats continue during pause; consumer auto-resumes at deadline
- **Pull consumer priority groups**: `PriorityGroups` with named groups, `Overflow` and `Pinned` policies for flexible failover; `Prioritized` group overflows to others before load-balancing

**Observability (2.11 new):**
- **Distributed message tracing**: `Nats-Trace-Dest` header enables end-to-end message tracing across servers, accounts, and subject mappings

**Operations (2.11 new):**
- Replication traffic routing: `cluster_traffic` property routes JetStream replication within the owner account rather than system account (reduces head-of-line blocking in multi-tenant deployments)
- **TLS-first leafnode handshake**: `handshake_first` in leafnode TLS block
- Config state digest: `nats-server -t` generates hash for detecting config file changes
- Windows TPM encryption for filestore keys

**Breaking changes (2.11):**
- Exit code: graceful SIGTERM shutdown now exits with code 0 (was 1)
- Server/cluster/gateway names containing spaces are now invalid (prevents startup)
- Default ingest rate limits: 128MB size and 10,000 messages per stream (configurable)

**Per-message TTL example:**
```bash
# Create a stream with per-message TTL enabled
nats stream add EVENTS \
  --subjects "events.>" \
  --allow-msg-ttl

# Publish with per-message TTL
nats pub events.temp '{"sensor": "A"}' \
  --header "Nats-TTL: 30s"
```

### 8.3 NATS 2.12 (Released: March 2025)

NATS moved to a 6-month predictable release cycle starting with 2.12.

**Atomic Batch Publishing (`AllowAtomicPublish`):**
- Atomically write a batch of messages into a stream
- All per-message checks execute first; batch commits only if all pass
- Prevents partial writes; all-or-nothing guarantee
- Supports replicated and non-replicated streams
- Batches are scoped to a single stream

**Distributed Counter CRDT (`AllowMsgCounter`):**
- Each unique subject in the stream holds an increment/decrement counter value
- No explicit size limit (uses `big.Int`)
- Supports mirroring and sourcing with configurable aggregation
- Suitable for distributed counters, rate limiters, aggregations

**Delayed Message Scheduling (`AllowMsgSchedules`):**
- Schedule messages for future publishing using delay headers
- Consumers do not act on messages until scheduled time
- Currently single-message scheduling; future potential for cron-like patterns

**Prioritized Pull Consumer Policy:**
- New `Prioritized` policy in Consumer Priority Groups (extends 2.11 priority groups)
- Fast failover: immediately allows remote clients to receive if no local clients are pulling
- Complements existing Overflow and Pinned policies

**Stream Mirror Promotion:**
- Mirrors can be promoted to primary streams for disaster recovery
- Remove mirror configuration, add original stream subjects
- No data loss during promotion

**Operational improvements:**
- `server_metadata` map: string key-value pairs describing server attributes (complements `server_tags`)
- `connect_backoff`: Exponential backoff (1–30 seconds) for route and gateway reconnection attempts
- Offline asset mode: unsupported features during downgrade place streams/consumers in offline status
- Enhanced stream/consumer scaleup protections for replicated and in-memory streams during failover
- Strict JetStream API validation enabled by **default** (`jetstream { strict: false }` to disable)

**Security (2.12):**
- Improved cipher suite handling: automatic additions, disabled insecure defaults
- `allow_insecure_cipher_suites` option to re-enable removed ciphers if needed

**Performance (2.12):**
- Replicated streams now asynchronously flush to disk without sacrificing consistency
- Elastic pointers in filestore caches reduce OOM conditions (recommend tuning `GOMEMLIMIT`)
- `GOMAXPROCS` and `GOMEMLIMIT` included in server statistics (`/varz`)

**Leaf nodes (2.12):**
- `isolate_leafnode_interest`: Reduces east-west traffic in large leaf node deployments
- `disabled: true`: Disable leaf connection via config reload

**Downgrade path:** 2.12 → 2.11.9+ is safe (offline mode). Do not downgrade to pre-2.11.9 from 2.12.

**New subject transform functions (2.12):**
- `partition(n)`: Partition-aware subject routing
- `random(n)`: Random selection subject routing

---

## 9. BEST PRACTICES

### 9.1 Subject Namespace Design

```
# Pattern: <domain>.<entity>.<operation>[.<qualifiers>]
# Examples:
orders.us.created
orders.eu.updated
inventory.warehouse-1.reserved
sensors.factory-a.line-2.temperature
telemetry.device.{device_id}.heartbeat

# Service patterns (request-reply):
service.orders.get
service.inventory.check
api.v2.users.lookup

# Internal/system patterns (use $):
$SYS.*.*
$JS.API.*
$KV.<bucket>.*
```

**Guidelines:**
- Maximum 16 tokens, 256 characters
- Use early tokens for broad categories, later tokens for specifics
- Avoid encoding technical implementation details in subjects
- Avoid putting too much data into subjects (use message body/headers)
- Reserve `$` prefix for system use
- Plan for wildcards in your subscription patterns from the start

### 9.2 Stream Configuration

**Storage selection:**
- Use `File` storage for durability and production workloads
- Use `Memory` storage only for performance-critical, ephemeral streams where data loss on restart is acceptable

**Replica recommendations:**
- Development: R=1
- Production with HA requirements: R=3
- Maximum fault tolerance: R=5 (requires 5+ node cluster)
- Always use odd replica counts to maintain quorum clarity

**Retention strategy:**
- `LimitsPolicy`: Default for most use cases; configure MaxAge + MaxBytes + MaxMsgs
- `WorkQueuePolicy`: Exactly-one-consumer processing pipelines
- `InterestPolicy`: Fan-out where messages are needed only by active consumers

**Deduplication:**
- Set `Duplicates` window based on expected publisher retry window
- Default 2 minutes is often sufficient; avoid very large windows (memory overhead)
- Always use `Nats-Msg-Id` header for at-least-once publishers

**Compression (2.10+):**
- Enable S2 compression for text-heavy or compressible workloads
- Compression is per-block (not per-message), so high throughput streams benefit most
- Minimal CPU overhead for S2; significant storage savings for text payloads

**Encryption (2.10+):**
```conf
jetstream {
  cipher: chacha         # recommended: chacha (ChaCha20-Poly1305)
  key: $JS_KEY           # from environment variable, not config file
  prev_encryption_key: $JS_OLD_KEY  # for key rotation
}
```

### 9.3 Consumer Design

**Use pull consumers by default** for new work. They provide:
- Better flow control
- Horizontal scalability without server-side fan-out
- Explicit message rate control
- No dedicated delivery subject required

**Pull consumer fetch patterns:**
```go
// Fetch with timeout (preferred for work loops)
msgs, err := consumer.Fetch(100, nats.MaxWait(5*time.Second))

// Fetch single message
msg, err := consumer.FetchOne(nats.MaxWait(5*time.Second))
```

**MaxAckPending tuning:**
- Too high: risk of slow-consumer conditions, high memory usage
- Too low: unnecessary back-pressure limiting throughput
- Typical range: 1,000–50,000 depending on workload

**AckWait sizing:**
- Must exceed your maximum processing time
- Add buffer for network latency and transient slowdowns
- Use `AckProgress` for long-running operations to reset the timer

**Dead-letter handling:**
- Use `MaxDeliver` to cap retries
- Use `AckTerm` in consumer to signal permanent failure
- Monitor `nats consumer info` for `num_redelivered` metric

### 9.4 Flow Control

**Push consumer flow control:**
- `MaxAckPending` is the primary flow control mechanism
- Set appropriate `AckWait` to prevent cascading redeliveries
- Use queue groups on push consumers for horizontal scaling

**Pull consumer flow control:**
- Clients control their own rate by controlling fetch frequency and batch size
- Fetch size + worker count determines maximum throughput
- Use timeout on fetch to avoid blocking indefinitely

**Publisher flow control:**
- Core NATS: use request-reply pattern to meter publishing speed
- JetStream: stream limits (`MaxBytes`, `MaxMsgs`) with `DiscardNew` apply backpressure to publishers

### 9.5 Connection Management

**Reconnection:**
```go
nc, err := nats.Connect(
    "nats://server1:4222,nats://server2:4222",
    nats.MaxReconnects(-1),          // retry forever
    nats.ReconnectWait(2*time.Second),
    nats.ReconnectJitter(500*time.Millisecond, 2*time.Second),
    nats.DisconnectErrHandler(func(nc *nats.Conn, err error) { /* log */ }),
    nats.ReconnectHandler(func(nc *nats.Conn) { /* log */ }),
)
```

**Draining for graceful shutdown:**
```go
// Drain processes all in-flight messages before closing
err := nc.Drain()
// Wait for drain to complete, then conn is closed
```

**Key practices:**
- Always implement reconnection with jitter to prevent thundering herd
- Use `Drain()` instead of `Close()` when possible for graceful shutdown
- Specify multiple server URLs for built-in failover
- Reconnect jitter is especially important when many clients reconnect simultaneously

### 9.6 Cluster Topology

**3-node cluster (standard):**
```
[Client] → [nats-1] ↔ [nats-2] ↔ [nats-3]
                   ↕─────────────────────↕
```

**Super-cluster (multi-region):**
```
[East Cluster] ←→ [Gateway] ←→ [West Cluster]
     ↑ leaf nodes              ↑ leaf nodes
```

**Hub-and-leaf for edge IoT:**
```
[Cloud Hub Cluster]
  ↑ leaf node
[Edge Server] ← [local IoT devices]
```

---

## 10. DIAGNOSTICS AND TROUBLESHOOTING

### 10.1 Slow Consumers

**Detection levels:**
- **Client-side**: Internal subscription buffer fills up; async error callback fires with "slow consumer, messages dropped"
- **Server-side**: Server write buffer fills; `write_deadline` expires; server disconnects client and logs "Slow Consumer Detected"; increments `slow_consumers` counter in `/varz`

**Tuning options:**
```conf
# Server config — increase write buffer deadline (use cautiously)
write_deadline: "5s"  # default 10s
```

```go
// Client-side — increase pending limits
sub.SetPendingLimits(1024*1000, 1024*50000)  // messages, bytes
```

**Solutions:**
1. Add queue group subscribers to distribute load
2. Partition subjects to allow independent scaling
3. Throttle publishers (request-reply for flow control)
4. Migrate to JetStream pull consumers with explicit rate control
5. Catch slow consumer errors at client before server disconnects

**Monitoring:**
```bash
# Check slow consumer count
curl -s http://localhost:8222/varz | jq '.slow_consumers'

# Check per-connection pending bytes
curl -s "http://localhost:8222/connz?sort=pending" | jq '.connections[0:5]'
```

### 10.2 Stream Lag and Consumer Lag

**Consumer lag** = messages in stream not yet delivered/acknowledged by a consumer.

```bash
# Check consumer lag
nats consumer info ORDERS my-processor
# Look for: "num_pending" (undelivered) and "num_redelivered"

# Report on all consumers in stream
nats consumer report ORDERS

# Report JetStream health across cluster
nats server report jetstream
```

**Investigating high lag:**
1. Check if consumer is active: `nats consumer ls ORDERS`
2. Check consumer configuration: `AckWait`, `MaxAckPending`, `MaxDeliver`
3. Check for redeliveries: high `num_redelivered` indicates processing failures
4. Check stream health: `nats stream info ORDERS` for any errors
5. Check cluster RAFT health: `nats server report jetstream`

### 10.3 JetStream Cluster Issues

**Cluster health checks:**
```bash
# List all servers and JetStream status
nats server ls
nats server ping

# Check JetStream API availability
nats account info

# Detailed JetStream report (shows stream placements, cluster status)
nats server report jetstream

# Check if JetStream has a meta-leader
nats server info | grep -i leader
```

**Common issues:**

| Symptom | Likely Cause | Resolution |
|---|---|---|
| JetStream API errors | No meta-leader | Check quorum; `nats server cluster step-down` |
| Stream offline | Insufficient replicas available | Check server health; `peer-remove` for dead nodes |
| High redelivery rate | Processing too slow or crashes | Increase `AckWait`, fix consumer logic |
| Publish rejected | Stream at capacity (DiscardNew) | Increase limits or consume faster |
| Consumer stuck | MaxAckPending reached | Process and ack pending messages |

**Recovering from failed peer:**
```bash
# If a server will never return, remove it from all RAFT groups
nats server cluster peer-remove <dead-server-name>
```

**Stream/consumer admin:**
```bash
# Check stream state
nats stream info ORDERS --json | jq '.state'

# Check RAFT state for stream
nats stream info ORDERS --json | jq '.cluster'

# Force stream leader step-down
nats stream leader-down ORDERS
```

### 10.4 Enabling Debug Logging

```conf
# In nats-server.conf (or command line flags)
debug: true    # -D flag
trace: true    # -V flag (verbose — shows all protocol messages)
```

**Via runtime signal:**
```bash
# Toggle debug/trace without restart
nats-server --signal ldm=<pid>   # lame duck mode
nats-server --signal reopen=<pid>  # reopen log files
```

**Structured connection logs (2.12):** Connection logs now include account name and user information. Connection closure logs include remote server name.

### 10.5 Audit Trail / JetStream Advisor

**JetStream API audit via system account:**
- All JetStream API calls are published to system account subjects
- Subscribe to `$SYS.ACCOUNT.*.JS.API.AUDIT.*` for API audit trail

**Event monitoring:**
```bash
# Watch all server events (requires system account credentials)
nats --creds sys.creds sub "$SYS.>"

# Monitor JetStream API calls
nats --creds sys.creds sub "$SYS.ACCOUNT.*.JS.API.*"

# Monitor connect/disconnect events
nats --creds sys.creds events --filter "connect,disconnect"
```

---

## 11. QUICK REFERENCE: CONFIGURATION TEMPLATES

### 11.1 Minimal Single-Node JetStream Server

```conf
server_name: nats-dev
port: 4222
http_port: 8222

jetstream {
  store_dir: /data/nats
  max_mem: 1G
  max_file: 10G
}
```

### 11.2 3-Node JetStream Cluster (per node)

```conf
server_name: nats-1    # change per node: nats-1, nats-2, nats-3
port: 4222
http_port: 8222

system_account: SYS

accounts {
  SYS {}
}

jetstream {
  store_dir: /data/nats/jetstream
  max_mem: 4G
  max_file: 100G
  unique_tag: "az"
}

cluster {
  name: prod-cluster
  port: 6222
  routes: [
    nats-route://nats-1:6222
    nats-route://nats-2:6222
    nats-route://nats-3:6222
  ]
}

tls {
  cert_file: /etc/nats/server.pem
  key_file:  /etc/nats/server-key.pem
  ca_file:   /etc/nats/ca.pem
  verify:    true
}
```

### 11.3 Secure Multi-Account Server with JWT Auth

```conf
server_name: nats-secure
port: 4222
http_port: 8222

operator: /etc/nats/operator.jwt

system_account: SYS

resolver: {
  type: full
  dir: /data/nats/resolver
  allow_delete: false
  interval: 2m
}

jetstream {
  store_dir: /data/nats/jetstream
  cipher: chacha
  key: $JS_ENCRYPTION_KEY
}

tls {
  cert_file: /etc/nats/server.pem
  key_file:  /etc/nats/server-key.pem
  ca_file:   /etc/nats/ca.pem
  min_version: "1.3"
}
```

### 11.4 Super-Cluster Gateway Config Fragment

```conf
# On each node in east-cluster
gateway {
  name: east-cluster
  port: 7222
  gateways: [
    {
      name: west-cluster
      urls: ["nats://west-1.example.com:7222", "nats://west-2.example.com:7222"]
    }
    {
      name: eu-cluster
      urls: ["nats://eu-1.example.com:7222"]
    }
  ]
  tls {
    cert_file: /etc/nats/gw-server.pem
    key_file:  /etc/nats/gw-key.pem
    ca_file:   /etc/nats/ca.pem
  }
}
```

---

## 12. KEY METRICS FOR PRODUCTION MONITORING

| Metric | Source | Alert Condition |
|---|---|---|
| `slow_consumers` | `/varz` | > 0 |
| `mem` | `/varz` | > 80% of system RAM |
| Pending bytes per connection | `/connz` | Individual connections > 64MB |
| JetStream meta-leader | `/jsz` | No leader elected |
| Stream `num_pending` | Consumer info | Growing trend (not keeping up) |
| Stream `num_redelivered` | Consumer info | Spike (processing failures) |
| Stream write errors | `/jsz` | Any errors |
| Route/gateway connectivity | `/routez`, `/gatewayz` | Disconnected routes |
| Leaf node connectivity | `/leafz` | Disconnected leaves |
| `js_disabled` | `/jsz` | true (JetStream not running) |

---

*Sources: NATS Official Documentation (docs.nats.io), NATS Server Release Notes (2.10, 2.11, 2.12), Synadia Blog, NATS GitHub Repository*
