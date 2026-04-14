# Apache Pulsar 4.x — Research Document

**Research Date:** 2026-04-13
**Scope:** Apache Pulsar 4.x (covering 4.0 through 4.2) architecture, subscription types, features, ecosystem, management, best practices, and diagnostics
**Latest Stable:** Apache Pulsar 4.2.0 (BookKeeper 4.17.3, Java 21, Alpine Linux base)

---

## 1. Architecture Overview

Apache Pulsar is an open-source, distributed messaging and streaming platform built for high throughput, low latency, multi-tenancy, and geo-replication. Its defining architectural characteristic is the **separation of serving (broker) and storage (BookKeeper)** layers, which enables independent scaling and zero-copy failover.

### 1.1 Core Layers

```
┌─────────────────────────────────────────────────────┐
│                  Producers / Consumers               │
└─────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────┐
│           Broker Layer (Stateless)                   │
│  - HTTP REST API (port 8080)                         │
│  - Binary TCP Protocol (port 6650)                   │
│  - Topic ownership and load balancing                │
│  - Managed ledger cache                              │
└─────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────┐
│           BookKeeper Layer (Bookies)                 │
│  - Persistent storage via ledgers                    │
│  - Journal (WAL) + Entry logs                        │
│  - Replication across bookie nodes                   │
└─────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────┐
│           Metadata Store                             │
│  - ZooKeeper (default), etcd, RocksDB, or Oxia       │
│  - Topic ownership, broker loads, cluster metadata   │
└─────────────────────────────────────────────────────┘
```

### 1.2 Broker Layer

Brokers are **stateless** components that:
- Handle incoming messages from producers and dispatch messages to consumers.
- Own specific topics (each topic is owned by one broker at a time; ownership transferred on failure).
- Maintain a **managed ledger cache** for tailing consumers (reads served from memory, not disk).
- Run an HTTP REST API server for administrative operations.
- Run an asynchronous TCP dispatcher using a custom binary protocol for high-performance data transfer.
- Perform load balancing using configurable load managers.

Because brokers are stateless, scaling out or recovering from a broker failure requires no data migration — the replacement broker claims topic ownership and reads state directly from BookKeeper.

### 1.3 BookKeeper Storage Layer

Apache BookKeeper provides durable, low-latency storage as a distributed write-ahead log (WAL) system.

**Key storage abstractions:**

- **Ledger**: An append-only sequence of entries assigned to a set of bookie nodes with built-in replication. Once a ledger is sealed (closed), it is immutable. All readers of a sealed ledger see identical content.
- **Managed Ledger**: A topic-level abstraction composed of multiple BookKeeper ledgers internally. Tracks consumer cursor positions and manages ledger lifecycle (creation, sealing, deletion per retention policy).
- **Journal**: BookKeeper transaction log. Every write is recorded to the journal and synced to disk (fsync) before acknowledgment is returned. Journal ensures crash durability.
- **Entry Log**: Long-term storage for actual message data. Entries from multiple ledgers are multiplexed into shared entry log files for I/O efficiency.
- **RocksDB Index**: BookKeeper uses RocksDB as the ledger entry index, mapping `(ledgerId, entryId)` to positions in entry log files.

**Replication model:**
BookKeeper uses three tunable parameters per namespace/topic:
- **Ensemble size (E)**: Number of bookies involved in storing a ledger (data striped across E bookies).
- **Write Quorum (Qw)**: Number of bookie replicas each entry is written to (Qw ≤ E).
- **Ack Quorum (Qa)**: Number of bookies that must acknowledge before a write is confirmed (Qa ≤ Qw).

Default: E=3, Qw=3, Qa=2 (write to 3 bookies, need 2 ACKs).

### 1.4 Metadata Store

Stores cluster metadata: topic-to-broker ownership, broker load data, namespace policies, and schema information.

- **ZooKeeper** (default): Proven, widely deployed.
- **etcd**: Cloud-native environments.
- **RocksDB**: Embedded, single-node development/testing.
- **Oxia**: Apache Pulsar's own large-scale metadata store (recommended for very large clusters, 4.x).

### 1.5 Pulsar Proxy

An optional stateless gateway that provides a single entry point to the cluster. Useful in:
- Kubernetes deployments where broker pods are not directly accessible.
- Cloud environments where clients should not need individual broker addresses.
- Clients update only the proxy address; the proxy handles broker routing transparently.

### 1.6 Topic Naming and Hierarchy

Topics follow a URL-structured naming scheme:

```
{persistent|non-persistent}://{tenant}/{namespace}/{topic}

Example:
persistent://acme-corp/payments/transactions
non-persistent://acme-corp/realtime/user-activity
```

- **persistent**: Messages stored durably in BookKeeper.
- **non-persistent**: Messages exist only in broker memory; no BookKeeper writes. Higher throughput, potential message loss during broker restart.

**Partitioned topics:**
A single logical topic can be backed by multiple internal partitions for horizontal scaling:
```
persistent://tenant/namespace/orders-topic-partition-0
persistent://tenant/namespace/orders-topic-partition-1
...
persistent://tenant/namespace/orders-topic-partition-N
```
The routing policy (round-robin, single, hash by key) is set on the producer.

---

## 2. Multi-Tenancy Model

Multi-tenancy is a first-class design principle in Pulsar, not an add-on. The hierarchy:

```
Instance
  └── Cluster(s)
        └── Tenant(s)
              └── Namespace(s)
                    └── Topic(s)
```

### Tenants

- The top-level administrative unit for capacity allocation and security policies.
- Each tenant can define its own authentication and authorization scheme.
- Tenants specify which clusters they are allowed to use (`--allowed-clusters`).
- Tenant administrators can create namespaces autonomously via REST API or CLI.

**CLI:**
```bash
# Create a tenant
bin/pulsar-admin tenants create acme-corp \
  --admin-roles admin-role \
  --allowed-clusters us-west,us-east

# Update tenant's allowed clusters
bin/pulsar-admin tenants update acme-corp \
  --allowed-clusters us-west,us-east,eu-central

# List tenants
bin/pulsar-admin tenants list

# Get tenant details
bin/pulsar-admin tenants get acme-corp
```

### Namespaces

- Logical groupings of topics within a tenant.
- All retention policies, message TTL, backlog quotas, dispatch rate limits, replication clusters, and encryption are configured at the namespace level.
- Policy changes apply uniformly to all topics in the namespace.
- Support topic-level policy overrides through system topics (`__change_events`).

**CLI:**
```bash
# Create namespace
bin/pulsar-admin namespaces create acme-corp/payments

# List namespaces in a tenant
bin/pulsar-admin namespaces list acme-corp

# Get namespace policies
bin/pulsar-admin namespaces policies acme-corp/payments

# Set retention (retain 100 MiB or 1 week, whichever comes first)
bin/pulsar-admin namespaces set-retention acme-corp/payments \
  --size 100M \
  --time 10080m

# Set message TTL (auto-expire unacknowledged messages after 1 hour)
bin/pulsar-admin namespaces set-message-ttl \
  --messageTTL 3600 acme-corp/payments

# Set backlog quota (hold producer on backlog > 10 GB or 10 hours)
bin/pulsar-admin namespaces set-backlog-quota \
  --limit 10G \
  --limitTime 36000 \
  --policy producer_request_hold \
  acme-corp/payments

# Get backlog quotas
bin/pulsar-admin namespaces get-backlog-quotas acme-corp/payments

# Clear backlog for a subscription
bin/pulsar-admin namespaces clear-backlog \
  --sub my-subscription acme-corp/payments

# Set dispatch rate limit (1000 msgs/sec, 1 MiB/sec)
bin/pulsar-admin namespaces set-dispatch-rate acme-corp/payments \
  --msg-dispatch-rate 1000 \
  --byte-dispatch-rate 1048576 \
  --dispatch-rate-period 1

# Enable geo-replication on namespace
bin/pulsar-admin namespaces set-clusters acme-corp/payments \
  --clusters us-west,us-east

# Delete namespace
bin/pulsar-admin namespaces delete acme-corp/payments
```

---

## 3. Topics and Partitions

### 3.1 Topic Management CLI

```bash
# Create non-partitioned persistent topic
bin/pulsar-admin topics create \
  persistent://acme-corp/payments/transactions

# Create partitioned topic (8 partitions)
bin/pulsar-admin topics create-partitioned-topic \
  persistent://acme-corp/payments/transactions \
  --partitions 8

# Update partition count (can only increase, never decrease)
bin/pulsar-admin topics update-partitioned-topic \
  persistent://acme-corp/payments/transactions \
  --partitions 16

# Get partitioned topic metadata
bin/pulsar-admin topics get-partitioned-topic-metadata \
  persistent://acme-corp/payments/transactions

# List topics in namespace
bin/pulsar-admin topics list acme-corp/payments

# List partitioned topics
bin/pulsar-admin topics list-partitioned-topics acme-corp/payments

# Get topic stats (including per-partition stats)
bin/pulsar-admin topics stats \
  persistent://acme-corp/payments/transactions \
  --get-precise-backlog

# Get partitioned topic stats (breakdown per partition)
bin/pulsar-admin topics partitioned-stats \
  persistent://acme-corp/payments/transactions \
  --per-partition

# Get internal stats (BookKeeper ledger details)
bin/pulsar-admin topics stats-internal \
  persistent://acme-corp/payments/transactions

# Grant produce/consume permissions on topic
bin/pulsar-admin topics grant-permission \
  --actions produce,consume \
  --role payment-service \
  persistent://acme-corp/payments/transactions

# Unload topic (force broker reassignment)
bin/pulsar-admin topics unload \
  persistent://acme-corp/payments/transactions

# Delete topic
bin/pulsar-admin topics delete \
  persistent://acme-corp/payments/transactions
```

### 3.2 Subscription Management via Topics CLI

```bash
# Create subscription at earliest position
bin/pulsar-admin topics create-subscription \
  --subscription payment-processor \
  persistent://acme-corp/payments/transactions

# List subscriptions on a topic
bin/pulsar-admin topics subscriptions \
  persistent://acme-corp/payments/transactions

# Skip all messages in a subscription (purge backlog)
bin/pulsar-admin topics skip-all \
  --subscription payment-processor \
  persistent://acme-corp/payments/transactions

# Skip N messages
bin/pulsar-admin topics skip \
  --subscription payment-processor \
  --count 1000 \
  persistent://acme-corp/payments/transactions

# Reset cursor to specific message ID
bin/pulsar-admin topics reset-cursor \
  --subscription payment-processor \
  --messageId earliest \
  persistent://acme-corp/payments/transactions

# Peek at messages in subscription
bin/pulsar-admin topics peek-messages \
  --subscription payment-processor \
  --count 5 \
  persistent://acme-corp/payments/transactions

# Remove subscription
bin/pulsar-admin topics unsubscribe \
  --subscription payment-processor \
  persistent://acme-corp/payments/transactions
```

---

## 4. Messaging Concepts

### 4.1 Message Structure

Each Pulsar message contains:
- **Payload**: Raw byte data. Default max: 5 MB (configurable).
- **Key**: Optional string identifier used for routing (key_shared) and compaction.
- **Properties**: User-defined key-value metadata pairs.
- **Producer name**: Globally unique producer identifier.
- **Sequence ID**: Used for exactly-once publish deduplication.
- **Message ID**: Broker-assigned position identifier (ledgerId:entryId:partitionIndex:batchIndex).
- **Publish time**: Broker timestamp when message was received.
- **Event time**: Optional application-set timestamp for event-time processing.

### 4.2 Acknowledgment Mechanisms

**Individual acknowledgment:**
```java
consumer.acknowledge(message);
```
Acknowledges one specific message. Applicable to all subscription types.

**Cumulative acknowledgment:**
```java
consumer.acknowledgeCumulative(message);
```
Acknowledges all messages up to and including the specified message. Only valid for **Exclusive** and **Failover** subscription types (not Shared or Key_Shared, since multiple consumers receive different messages).

**Negative acknowledgment (nack):**
```java
consumer.negativeAcknowledge(message);
```
Signals failed processing. Triggers redelivery after a configurable delay. Supports exponential backoff (default multiplier 2, range 1–60 seconds).

**Acknowledgment timeout:**
When a consumer receives a message but does not acknowledge or nack it within a configured timeout, the broker automatically redelivers the message. Configure carefully to avoid redelivering messages still in processing.

### 4.3 Batching

Producers can batch multiple messages into a single storage entry:
- Reduces storage I/O and network overhead.
- Configurable by count, size, or time delay.
- **Batch index acknowledgment**: When enabled (`acknowledgmentAtBatchIndexLevelEnabled=true` in broker config), consumers can acknowledge individual messages within a batch. Without this, acknowledging one message in a batch marks all prior messages as acknowledged.

### 4.4 Chunking

For messages exceeding `maxMessageSize` (default 5 MB), producers can split messages into smaller chunks:
- Only available for **persistent topics**.
- Cannot be used simultaneously with batching.
- The consumer reassembles chunks transparently.

### 4.5 Compression

Supported compression codecs: LZ4, ZLIB (DEFLATE), ZSTD, SNAPPY.
Set at producer level; metadata records codec so consumers decompress automatically.

---

## 5. Subscription Types

Pulsar supports four subscription types controlling how messages are distributed to consumers within a subscription group.

### 5.1 Exclusive (Default)

- Only **one consumer** is active at a time per subscription.
- Second consumer attempting to subscribe receives an error.
- Guarantees strict message ordering.
- Use case: Single-consumer pipelines, state machines, ordered event sourcing.

```java
Consumer<byte[]> consumer = client.newConsumer()
    .topic("persistent://tenant/ns/topic")
    .subscriptionName("my-exclusive-sub")
    .subscriptionType(SubscriptionType.Exclusive)
    .subscribe();
```

### 5.2 Shared

- Multiple consumers subscribe concurrently.
- Messages are distributed **round-robin** across active consumers.
- **No ordering guarantee**: Each message goes to one consumer, but order is not preserved.
- Supports individual acknowledgment; cumulative acknowledgment is NOT supported.
- Delayed message delivery is supported.
- Use case: Parallel task processing, work queues, fan-out with independent workers.

```java
Consumer<byte[]> consumer = client.newConsumer()
    .topic("persistent://tenant/ns/topic")
    .subscriptionName("worker-pool")
    .subscriptionType(SubscriptionType.Shared)
    .subscribe();
```

### 5.3 Failover

- Multiple consumers subscribe; **one is the active master**, others are standby.
- On master failure, the next consumer in priority order becomes active.
- Ordering is maintained within the active consumer.
- Cumulative acknowledgment is supported.
- Use case: High availability without parallel processing, ordered processing with HA.

```java
Consumer<byte[]> consumer = client.newConsumer()
    .topic("persistent://tenant/ns/topic")
    .subscriptionName("ha-processor")
    .subscriptionType(SubscriptionType.Failover)
    .subscribe();
```

### 5.4 Key_Shared

- Multiple consumers subscribe concurrently.
- Messages with the **same key** are routed to the **same consumer** consistently.
- Maintains per-key ordering while enabling parallelism across keys.
- Cumulative acknowledgment is NOT supported.
- **Pulsar 4.0 improvement (PIP-379)**: Enhanced Key_Shared implementation eliminates unnecessary message blocking during consumer changes; new troubleshooting metrics added.

**Critical requirements:**
- Producers must **disable batching** or **use key-based batching** to prevent different keys being packed into the same batch (which breaks per-key routing).
- Consumer count changes cause key reassignment; brief redelivery during rebalancing.

```java
// Producer: disable batching for key_shared
Producer<byte[]> producer = client.newProducer()
    .topic("persistent://tenant/ns/orders")
    .enableBatching(false)
    .create();

// Consumer: key_shared subscription
Consumer<byte[]> consumer = client.newConsumer()
    .topic("persistent://tenant/ns/orders")
    .subscriptionName("order-processors")
    .subscriptionType(SubscriptionType.Key_Shared)
    .subscribe();
```

### Subscription Type Comparison

| Feature | Exclusive | Shared | Failover | Key_Shared |
|---|---|---|---|---|
| Multiple consumers | No | Yes | Yes (standby) | Yes |
| Ordering guarantee | Strict global | None | Strict (single active) | Per-key |
| Cumulative ack | Yes | No | Yes | No |
| Delayed delivery | Yes | Yes | Yes | Yes |
| Use case | Single pipeline | Work queue | HA pipeline | Per-entity ordering |

---

## 6. Advanced Delivery Features

### 6.1 Retry Letter Topic

For messages that fail processing but need multiple retry attempts with delay:
- Default naming: `{topicname}-{subscriptionname}-RETRY`
- Configurable retry intervals (exponential backoff supported).
- More suitable than nack for scenarios requiring many retries with specific delay patterns.

```java
Consumer<byte[]> consumer = client.newConsumer()
    .topic("persistent://tenant/ns/orders")
    .subscriptionName("order-processor")
    .enableRetry(true)
    .deadLetterPolicy(DeadLetterPolicy.builder()
        .maxRedeliverCount(5)
        .retryLetterTopic("persistent://tenant/ns/orders-order-processor-RETRY")
        .deadLetterTopic("persistent://tenant/ns/orders-order-processor-DLQ")
        .build())
    .subscribe();
```

### 6.2 Dead Letter Topic

Messages that exceed the maximum redelivery count are moved to the Dead Letter Topic (DLT):
- Default naming: `{topicname}-{subscriptionname}-DLQ`
- Applicable to Shared and Key_Shared subscriptions.
- DLT is itself a regular Pulsar topic; subscribe a separate consumer for analysis.

### 6.3 Delayed Message Delivery

Publishers can delay message delivery by a fixed interval:
- Only **Shared** and **Key_Shared** subscription types support delayed delivery.
- Delay is implemented at the broker; messages are stored and released after the delay.

```java
producer.newMessage()
    .value("delayed-payload".getBytes())
    .deliverAfter(30, TimeUnit.SECONDS)
    .send();
```

### 6.4 Message Deduplication

Prevents duplicate messages from being persisted:
- Tracks sequence IDs per producer.
- Configured at namespace or topic level.

```bash
# Enable deduplication on namespace
bin/pulsar-admin namespaces set-deduplication acme-corp/payments \
  --enable

# Enable on individual topic
bin/pulsar-admin topics set-deduplication \
  --enable \
  persistent://acme-corp/payments/transactions
```

---

## 7. Transactions

Pulsar transactions enable **atomic** consume-process-produce patterns across multiple topics and partitions. All operations in a transaction either commit or abort as a unit.

### 7.1 Core Components

- **Transaction Coordinator**: Manages transaction lifecycle; persists state in transaction log topics backed by Pulsar.
- **Transaction ID (TxnID)**: 128-bit identifier; highest 16 bits identify the coordinating broker.
- **Transaction Buffer**: Stores uncommitted messages invisibly to consumers until commit; discards on abort.
- **Pending Acknowledge State**: Holds acknowledgments within a transaction; persisted in pending-ack log topics.

**Isolation level**: "Read committed" — consumers only see committed messages.

### 7.2 Configuration

Enable in `broker.conf`:
```properties
transactionCoordinatorEnabled=true

# Batched transaction log writes (performance)
transactionLogBatchedWriteEnabled=true
transactionLogBatchedWriteMaxRecords=512
transactionLogBatchedWriteMaxSize=4194304
transactionLogBatchedWriteMaxDelayInMillis=1

# Coordinator limits
maxActiveTransactionsPerCoordinator=1000000
```

### 7.3 Java Transaction API

```java
// Build client with transactions enabled
PulsarClient client = PulsarClient.builder()
    .serviceUrl("pulsar://localhost:6650")
    .enableTransaction(true)
    .build();

// Begin a transaction (5-minute timeout)
Transaction txn = client.newTransaction()
    .withTransactionTimeout(5, TimeUnit.MINUTES)
    .build()
    .get();

// Transactional publish (message invisible until commit)
producer.newMessage(txn)
    .value("order-confirmed".getBytes())
    .sendAsync();

// Transactional consume-acknowledge
Message<byte[]> message = consumer.receive();
consumer.acknowledgeAsync(message.getMessageId(), txn);

// Commit (makes all writes and acks permanent)
txn.commit().get();

// OR: Abort (rolls back, unacknowledged messages redelivered)
txn.abort().get();
```

**Pulsar 4.2 enhancement (PIP-439):** Transaction support added for Pulsar Functions, enabling stateful functions with transactional guarantees.

---

## 8. Topic Compaction

Compaction maintains a "latest-value-per-key" view of a topic, suitable for state tables and configuration stores.

### 8.1 How It Works

1. Pulsar scans the topic from start to end, tracking the most recent message per key.
2. A new BookKeeper ledger is created containing only the most recent message per key.
3. The broker records the **compaction horizon** (last compacted message ID).
4. Consumers reading from a compacted topic receive only the latest value for each key.
5. Messages with empty payloads act as **tombstones** (delete markers).
6. Only applicable to **persistent topics** with messages that have keys set.

### 8.2 Configuration

```properties
# In broker.conf: auto-compact when backlog exceeds 100 MiB
brokerServiceCompactionThreshold=104857600

# Retain messages with null keys during compaction (default: false)
compactionRetainNullKey=false
```

### 8.3 CLI Commands

```bash
# Trigger compaction manually on a topic
bin/pulsar-admin topics compact \
  persistent://acme-corp/config/feature-flags

# Alternative: standalone compaction tool
bin/pulsar compact-topic \
  --topic persistent://acme-corp/config/feature-flags

# Check compaction status
bin/pulsar-admin topics compaction-status \
  persistent://acme-corp/config/feature-flags
```

### 8.4 Reading from Compacted Topic

```java
// Reader starting from compacted state
Reader<byte[]> reader = client.newReader()
    .topic("persistent://acme-corp/config/feature-flags")
    .startMessageId(MessageId.earliest)
    .readCompacted(true)
    .create();
```

---

## 9. Tiered Storage (Offloading)

Pulsar's segment-based architecture enables transparent offloading of cold data to cheaper object storage while keeping hot data in BookKeeper.

### 9.1 How It Works

1. When a BookKeeper ledger is sealed (closed due to size limit, time limit, or manual trigger), it becomes immutable.
2. Sealed segments are eligible for offloading based on namespace policy.
3. Data is transferred to external storage; metadata is updated to reference the new location.
4. After a configurable delay (default: 4 hours), the local BookKeeper copy is deleted.
5. When a consumer requests offloaded data, the broker retrieves it transparently from object storage.

### 9.2 Supported Backends

| Backend | Notes |
|---|---|
| Amazon S3 | Native support; also works with S3-compatible APIs |
| Google Cloud Storage (GCS) | Native GCS driver |
| Microsoft Azure Blob Storage | Native Azure driver |
| Alibaba Cloud OSS | Supported |
| MinIO | S3-compatible on-premises |
| Ceph | S3-compatible on-premises |

**Storage class recommendations:**
- BookKeeper: Fast SSD (hot tier)
- Tiered storage: Standard → Infrequent Access → Archive based on data age

### 9.3 Cost Benefit

Default BookKeeper replication: 3x (write to 3 bookies). Tiered storage uses erasure coding (Reed-Solomon), typically reducing storage cost by 60–70% compared to BookKeeper replication.

### 9.4 Configuration

In `broker.conf` (example for S3):
```properties
managedLedgerOffloadDriver=aws-s3
s3ManagedLedgerOffloadBucket=my-pulsar-offload-bucket
s3ManagedLedgerOffloadRegion=us-east-1
s3ManagedLedgerOffloadCredentialId=ACCESS_KEY_ID
s3ManagedLedgerOffloadCredentialSecret=SECRET_ACCESS_KEY
```

**Namespace offload policy (auto-offload trigger):**
```bash
# Auto-offload when ledger size exceeds 1 GiB
bin/pulsar-admin namespaces set-offload-threshold \
  --size 1073741824 \
  acme-corp/payments

# Set deletion lag after offload (1 hour)
bin/pulsar-admin namespaces set-offload-deletion-lag \
  --lag 3600 \
  acme-corp/payments
```

**Manual offload trigger:**
```bash
bin/pulsar-admin topics offload \
  --size-threshold 100M \
  persistent://acme-corp/payments/transactions
```

---

## 10. Geo-Replication

Pulsar supports native geo-replication for disaster recovery and multi-region active-active deployments.

### 10.1 Replication Modes

**Asynchronous geo-replication:**
- Messages persist locally first, then replicate asynchronously to remote clusters.
- Lower latency for producers; some replication lag possible.
- Suitable for disaster recovery where some data loss (RPO > 0) is acceptable.

**Synchronous geo-replication:**
- Uses BookKeeper region-aware placement policy; data written simultaneously to multiple data centers before ACK.
- Stronger consistency (RPO ≈ 0) at the cost of increased write latency.
- Suitable for financial transactions, compliance data.

### 10.2 Replication Patterns

- **Full-mesh**: Every cluster replicates to every other cluster.
- **Active-active**: Two clusters, producers and consumers operate at either location.
- **Aggregation (edge-to-cloud)**: Multiple edge clusters replicate to a central data center; consumers at center only.

### 10.3 Setup CLI

```bash
# Step 1: Register remote cluster
bin/pulsar-admin clusters create us-east \
  --broker-url pulsar://us-east-broker:6650 \
  --url http://us-east-broker:8080

# Step 2: Create tenant with allowed clusters
bin/pulsar-admin tenants create acme-corp \
  --admin-roles admin \
  --allowed-clusters us-west,us-east

# Step 3: Create namespace
bin/pulsar-admin namespaces create acme-corp/payments

# Step 4: Enable geo-replication on namespace
bin/pulsar-admin namespaces set-clusters acme-corp/payments \
  --clusters us-west,us-east

# Step 5: (Optional) Topic-level replication override
bin/pulsar-admin topics set-replication-clusters \
  --clusters us-west,us-east \
  persistent://acme-corp/payments/transactions
```

### 10.4 Replicated Subscriptions

Subscriptions can be replicated across clusters so consumer position is maintained on failover:

```java
Consumer<String> consumer = client.newConsumer(Schema.STRING)
    .topic("persistent://acme-corp/payments/transactions")
    .subscriptionName("payment-processor")
    .replicateSubscriptionState(true)
    .subscribe();
```

**Broker config for replicated subscriptions:**
```properties
enableReplicatedSubscriptions=true
replicatedSubscriptionsSnapshotFrequencyMillis=1000
replicatedSubscriptionsSnapshotTimeoutSeconds=30
```

### 10.5 Monitoring Replication Lag

```bash
# Check replication stats in topic stats output
bin/pulsar-admin topics stats \
  persistent://acme-corp/payments/transactions

# Look for "replication" section in output:
# - msgRateIn, msgRateOut per cluster
# - replicationBacklog (messages pending replication)
# - connected (true/false per remote cluster)
```

---

## 11. Schema Registry

Pulsar has a built-in schema registry per topic, enabling structured data with type safety.

### 11.1 Supported Schema Types

| Type | Description |
|---|---|
| AVRO | Apache Avro schemas |
| JSON | JSON Schema |
| PROTOBUF | Protocol Buffers |
| PROTOBUF_NATIVE | Protobuf v4 native (added in 4.2) |
| KEY_VALUE | Key-value pair messages |
| BYTES | Raw bytes (no schema enforcement) |
| STRING | UTF-8 strings |
| INT8/INT16/INT32/INT64 | Primitive integer types |
| FLOAT/DOUBLE | Primitive float types |

### 11.2 Schema Evolution and Compatibility

Schemas support compatibility strategies:
- `ALWAYS_COMPATIBLE`: All changes allowed.
- `ALWAYS_INCOMPATIBLE`: No changes allowed.
- `BACKWARD`: New schema can read old data.
- `FORWARD`: Old schema can read new data.
- `FULL`: Both backward and forward compatible.

**CLI:**
```bash
# Get schema for a topic
bin/pulsar-admin schemas get \
  persistent://acme-corp/payments/transactions

# Upload/update schema
bin/pulsar-admin schemas upload \
  persistent://acme-corp/payments/transactions \
  --filename schema.json

# Delete schema
bin/pulsar-admin schemas delete \
  persistent://acme-corp/payments/transactions
```

---

## 12. Ecosystem

### 12.1 Pulsar Functions

Serverless compute framework for lightweight message processing without deploying full applications.

**Languages supported:** Java, Python, Go.

**Function types:**
- **Standard functions**: Message transformation, filtering, enrichment.
- **Stateful functions**: Use BookKeeper table service for persistent state (e.g., word count).
- **Window functions**: Process batches of messages over time windows (sliding, tumbling).

**Deployment modes:**
- **Thread** (default, dev): Runs in broker JVM.
- **Process**: Separate OS process per function instance.
- **Kubernetes**: Separate pod per function instance.

**CLI:**
```bash
# Deploy a function from JAR
bin/pulsar-admin functions create \
  --function-config-file function-config.yaml \
  --jar target/my-functions.jar

# Get function info
bin/pulsar-admin functions get \
  --tenant acme-corp \
  --namespace payments \
  --name order-enricher

# Check function status
bin/pulsar-admin functions status \
  --tenant acme-corp \
  --namespace payments \
  --name order-enricher

# Query stateful function state
bin/pulsar-admin functions querystate \
  --tenant acme-corp \
  --namespace payments \
  --name word-counter \
  --key the

# Update function
bin/pulsar-admin functions update \
  --function-config-file function-config.yaml \
  --jar target/my-functions-v2.jar

# Delete function
bin/pulsar-admin functions delete \
  --tenant acme-corp \
  --namespace payments \
  --name order-enricher
```

**Function config YAML example:**
```yaml
tenant: acme-corp
namespace: payments
name: order-enricher
className: com.acme.OrderEnricherFunction
inputs:
  - persistent://acme-corp/payments/raw-orders
output: persistent://acme-corp/payments/enriched-orders
parallelism: 3
runtime: JAVA
```

### 12.2 Pulsar IO (Connectors)

Framework for integrating Pulsar with external systems.

**Connector types:**
- **Source connectors**: Pull data from external systems into Pulsar topics.
- **Sink connectors**: Push data from Pulsar topics to external systems.

**Built-in connectors (sample):**

| Connector | Type | Notes |
|---|---|---|
| Kafka | Source + Sink | Bi-directional Kafka bridge |
| Cassandra | Sink | Write to Apache Cassandra |
| Debezium (MySQL, PostgreSQL) | Source | CDC from databases |
| Elasticsearch | Sink | Index to ES |
| RabbitMQ | Source + Sink | Bridge to RabbitMQ |
| HDFS | Sink | Write to Hadoop |
| Kinesis | Source + Sink | AWS Kinesis bridge |
| JDBC | Sink | Write to any JDBC database |

**Processing guarantees:**
- `ATMOST_ONCE`: Messages processed at most once (potential loss).
- `ATLEAST_ONCE`: Messages processed at least once (default; potential duplicates).
- `EFFECTIVELY_ONCE`: Each message produces exactly one output (requires idempotent sink).

**CLI:**
```bash
# Create a Cassandra sink connector
bin/pulsar-admin sinks create \
  --archive connectors/pulsar-io-cassandra-4.0.0.nar \
  --inputs persistent://acme-corp/payments/transactions \
  --name cassandra-sink \
  --sink-config-file cassandra-config.yaml \
  --processing-guarantees ATLEAST_ONCE

# Create a Debezium MySQL source
bin/pulsar-admin sources create \
  --archive connectors/pulsar-io-debezium-mysql-4.0.0.nar \
  --name mysql-cdc \
  --destination-topic-name persistent://acme-corp/cdc/mysql-orders \
  --source-config-file debezium-mysql.yaml

# Update sink
bin/pulsar-admin sinks update \
  --name cassandra-sink \
  --processing-guarantees EFFECTIVELY_ONCE

# Get sink status
bin/pulsar-admin sinks status --name cassandra-sink
```

### 12.3 Pulsar SQL (Trino/Presto)

Enables SQL queries directly against Pulsar topics, reading from BookKeeper rather than through consumer interfaces.

**Architecture:**
- Built on Trino (formerly Presto SQL).
- The Pulsar Trino plugin enables workers to read directly from BookKeeper ledgers.
- Supports concurrent reads from multiple BookKeeper nodes for high throughput.
- Requires topics to have a registered schema (AVRO, JSON, Protobuf).

**Configuration (`trino/conf/catalog/pulsar.properties`):**
```properties
connector.name=pulsar
pulsar.web-service-url=http://localhost:8080
pulsar.zookeeper-uri=localhost:2181

# Authentication (optional)
pulsar.authorization-enabled=true
pulsar.broker-binary-service-url=pulsar://localhost:6650
pulsar.auth-plugin=org.apache.pulsar.client.impl.auth.AuthenticationToken
pulsar.auth-params=token:eyJ...
```

**Upgrade note:** Users upgrading from Pulsar 2.11 or earlier must copy config files from `conf/presto/` to `trino/conf/`.

**Example queries:**
```sql
-- Query all messages in a topic
SELECT * FROM pulsar."acme-corp/payments".transactions LIMIT 10;

-- Filter by time range (using __publish_time__ system column)
SELECT order_id, amount, __publish_time__
FROM pulsar."acme-corp/payments".transactions
WHERE __publish_time__ > TIMESTAMP '2026-01-01 00:00:00'
  AND amount > 1000.00;

-- Aggregate
SELECT COUNT(*), SUM(amount)
FROM pulsar."acme-corp/payments".transactions
WHERE status = 'COMPLETED';
```

**System columns available in all queries:**
- `__message_id__`: Pulsar message ID
- `__key__`: Message key
- `__publish_time__`: Publish timestamp
- `__event_time__`: Event time (if set)
- `__producer_name__`: Producing application name

### 12.4 Kafka-on-Pulsar (KoP)

A Pulsar protocol handler that allows Kafka clients to connect to Pulsar without code changes.

**How it works:**
- Install the KoP NAR file as a protocol handler on Pulsar brokers.
- Kafka producers/consumers connect to the Pulsar broker using standard Kafka protocol.
- Messages are stored in Pulsar topics (under `public/default` tenant by default).
- Kafka topics map to Pulsar partitioned topics.

**Broker configuration (`broker.conf`):**
```properties
messagingProtocols=kafka
protocolHandlerDirectory=./protocols
kafkaListeners=PLAINTEXT://0.0.0.0:9092
kafkaAdvertisedListeners=PLAINTEXT://localhost:9092

# Enable transaction support for Kafka 3.2+ clients
kafkaTransactionCoordinatorEnabled=true
brokerDeduplicationEnabled=true
```

**Limitations:**
- Consumer groups map to Pulsar subscriptions (Shared type).
- Not all Kafka APIs are supported (e.g., admin operations are limited).
- Kafka consumer groups use Shared subscription; per-key ordering differs from Pulsar key_shared.

### 12.5 WebSocket API

Pulsar exposes a WebSocket API for browser and lightweight client access:

```
ws://broker:8080/ws/v2/producer/persistent/{tenant}/{namespace}/{topic}
ws://broker:8080/ws/v2/consumer/persistent/{tenant}/{namespace}/{topic}/{subscription}
ws://broker:8080/ws/v2/reader/persistent/{tenant}/{namespace}/{topic}
```

Useful for web applications, IoT devices, and environments where installing a Pulsar client library is impractical.

---

## 13. Pulsar 4.x Release Highlights

### 13.1 Pulsar 4.0 (October 2024)

- **Enhanced Key_Shared (PIP-379)**: Eliminated unnecessary message blocking during consumer changes; new diagnostic metrics added.
- **Alpine Linux + Java 21 Docker images**: Reduced from 12 CVEs to zero. Java 21 Generational ZGC provides sub-millisecond GC pause times.
- **Unified Rate Limiting (PIP-322)**: Token bucket algorithm unifying rate limiting across broker, topic, and resource group levels; reduced CPU overhead and lock contention.
- **Upgrade path**: 2.x users must upgrade 2.10.6 → 3.0.7 → 4.0.0 (cannot jump directly).
- **Security**: All Java clients below 3.0.7, 3.3.2, or 4.0.0 carry CVE-2024-47561 and must upgrade.

### 13.2 Pulsar 4.1 (Early 2025)

- BookKeeper updated to 4.17.x.
- Various security patches and library updates.
- Stability improvements and bug fixes.

### 13.3 Pulsar 4.2 (2025)

- **PIP-437**: Granular and fixed-delay message delivery policies.
- **PIP-439**: Transaction support for Pulsar Functions.
- **PIP-442**: Memory limits for namespace topic operations.
- **PIP-446**: Native OpenTelemetry tracing in Pulsar Java client (OTLP exporter).
- **PIP-447**: Customizable Prometheus labels for topic metrics.
- **PIP-452**: Customizable topic listing with properties.
- **PIP-454**: Metadata store migration framework.
- BookKeeper upgraded to 4.17.3.
- Protobuf v4 schema compatibility support added.
- Java 25 support added across tooling.
- Ubuntu 24.04 adopted for CI workflows.
- Jetty upgraded to 12.1.x; Spring updated to 6.2.12; OpenTelemetry upgraded to 1.56.0.
- Flume and Twitter connectors removed.

---

## 14. Management Tooling

### 14.1 pulsar-admin CLI

Primary administrative interface. All commands follow the pattern:
```
bin/pulsar-admin <resource-type> <operation> [options]
```

Resource types: `tenants`, `namespaces`, `topics`, `schemas`, `subscriptions`, `sources`, `sinks`, `functions`, `clusters`, `brokers`, `bookies`, `resource-quotas`.

### 14.2 Pulsar Shell (pulsarctl)

Interactive shell for admin operations:
```bash
bin/pulsar-shell

# Inside shell:
> admin topics list public/default
> admin namespaces set-retention ...
```

### 14.3 Pulsar Manager UI

Web-based management console:
- Topic browser, subscription management, monitoring dashboard.
- Deployed as a separate Docker container.
- Default port: 9527.

```bash
docker run -it \
  -p 9527:9527 -p 7750:7750 \
  -e SPRING_CONFIGURATION_FILE=/pulsar-manager/pulsar-manager/application.properties \
  apachepulsar/pulsar-manager:latest
```

### 14.4 Prometheus and Grafana

**Metrics endpoints:**
- Broker: `http://broker:8080/metrics/`
- BookKeeper: `http://bookie:8000/metrics`
- ZooKeeper: `http://zookeeper:8000/metrics`

Prometheus scrape config (`prometheus.yml`):
```yaml
scrape_configs:
  - job_name: pulsar-brokers
    static_configs:
      - targets: ['broker-1:8080', 'broker-2:8080']

  - job_name: pulsar-bookies
    static_configs:
      - targets: ['bookie-1:8000', 'bookie-2:8000', 'bookie-3:8000']
```

**Community Grafana dashboards:**
- `streamnative/apache-pulsar-grafana-dashboard` (GitHub): Supports both Kubernetes and bare-metal.
- Automatically included in Pulsar Helm chart deployments (`pulsar-grafana`).

**OpenTelemetry (4.2+, experimental):**
OTLP export supported; configure via `openTelemetry.*` broker properties. OTLP is the recommended future path per Pulsar 4.x roadmap.

---

## 15. Best Practices

### 15.1 Namespace Design

- One namespace per application or service domain (not per team).
- Set retention, TTL, and backlog quota at namespace level before creating topics.
- Namespace backlog quotas: choose `producer_request_hold` (pause producers) over `producer_exception` (drop messages) for most use cases.
- Use descriptive naming: `{org}/{service}-{environment}` (e.g., `acme/payments-prod`).

### 15.2 Topic Partitioning

- Use partitioned topics for throughput > ~100 MiB/sec per topic.
- Set partition count at creation; you can only increase, never decrease.
- Choose partition count as a multiple of broker count for even distribution.
- For ordered processing with parallelism, combine partitioned topics with Key_Shared subscription.
- Non-partitioned topics are simpler; use when throughput fits within a single broker.

### 15.3 Subscription Type Selection

| Requirement | Subscription Type |
|---|---|
| Strict global ordering, single consumer | Exclusive |
| Parallel processing, no ordering needed | Shared |
| High availability with ordering | Failover |
| Parallel processing with per-entity ordering | Key_Shared |

### 15.4 Message Acknowledgment Patterns

- For Shared/Key_Shared: always use individual acknowledgment.
- For Exclusive/Failover: cumulative acknowledgment reduces broker overhead for sequential workflows.
- Enable batch index acknowledgment when using batching with Shared/Key_Shared to prevent unnecessary redelivery.
- Set acknowledgment timeout conservatively — too short causes spurious redeliveries.
- Use retry letter topic for business-level retry logic; use nack for transient failures.

### 15.5 Cluster Sizing

**Broker nodes:**
- Start with 3 brokers for HA.
- Size based on peak message throughput and managed ledger cache size.
- More brokers = more parallel topic ownership.

**BookKeeper bookie nodes:**
- Minimum 3 for default E=3 ensemble.
- Add bookies to increase storage capacity (horizontally scalable).
- Separate journal and ledger directories onto different physical disks.

**Metadata store (ZooKeeper):**
- 3 or 5 nodes (odd number for quorum).
- Small, fast SSDs. ZooKeeper is latency-sensitive.
- Consider migrating to Oxia for clusters with > 1 million topics.

### 15.6 BookKeeper Tuning

**Journal configuration:**
```properties
# Journal directory (fast SSD recommended)
journalDirectories=/fast-ssd/bk-journal

# Ledger directories (separate from journal for I/O isolation)
ledgerDirectories=/storage-ssd/bk-ledger

# Sync behavior (true = full durability, false = OS page cache flush)
journalSyncData=true

# Group commit (batch fsync operations)
journalAdaptiveGroupWrites=true
journalMaxGroupWaitMSec=1
journalBufferedWritesThreshold=524288
```

**RocksDB index tuning:**
```properties
# Allocate 2+ GiB for RocksDB block cache
dbLedgerStorageLocation=/ssd/rocksdb
rocksdb.block.cache.size=2147483648
```

**Replication parameters (set at namespace or broker level):**
```properties
managedLedgerDefaultEnsembleSize=3
managedLedgerDefaultWriteQuorum=3
managedLedgerDefaultAckQuorum=2
```

**Managed ledger cache:**
- The cache stores tailing messages across topics for fast consumer delivery.
- Size with `managedLedgerCacheSize` (default: 10% of JVM heap). Increase for high-fan-out scenarios.

### 15.7 GC Tuning (Java 21+)

Pulsar 4.0 ships with Java 21 and recommends Generational ZGC:
```
-XX:+UseZGC -XX:+ZGenerational
-Xmx8g -Xms8g
-XX:MaxGCPauseMillis=20
```

For high-throughput brokers (Java 21):
- ZGC with generational mode provides sub-millisecond pause times.
- Avoid G1GC for large heaps (> 16 GB) in latency-sensitive deployments.
- Monitor GC logs; excessive GC is often a sign of managed ledger cache misconfiguration.

### 15.8 Tiered Storage Configuration

- Set offload threshold to match your cost vs. access pattern.
- Use infrequent-access storage class for data older than 7 days.
- Monitor offload lag with `pulsar_ml_offloaded_ledger_count` Prometheus metric.
- Test retrieval latency from tiered storage before setting very long retention.

---

## 16. Diagnostics

### 16.1 Key Prometheus Metrics

**Broker metrics** (port 8080 `/metrics/`):

| Metric | Description |
|---|---|
| `pulsar_broker_rate_in` | Message rate into broker |
| `pulsar_broker_rate_out` | Message rate out of broker |
| `pulsar_broker_storage_size` | Total data stored |
| `pulsar_broker_msg_backlog` | Total pending messages |
| `pulsar_broker_producers_count` | Active producers |
| `pulsar_broker_consumers_count` | Active consumers |

**Topic metrics** (enable with `exposeTopicLevelMetricsInPrometheus=true`):

| Metric | Description |
|---|---|
| `pulsar_rate_in` / `pulsar_rate_out` | Per-topic message rate |
| `pulsar_throughput_in` / `pulsar_throughput_out` | Per-topic byte throughput |
| `pulsar_storage_backlog_size` | Backlog bytes per topic |
| `pulsar_storage_backlog_age_seconds` | Age of oldest unacked message |
| `pulsar_storage_write_latency_le_*` | Write latency histogram buckets |

**Subscription metrics:**

| Metric | Description |
|---|---|
| `pulsar_subscription_msg_ack_rate` | Acknowledgment rate |
| `pulsar_subscription_msg_rate_out` | Delivery rate to consumers |
| `pulsar_subscription_blocked_on_unacked_messages` | 1 if flow control blocked |
| `pulsar_subscription_msg_rate_redeliver` | Redelivery rate |
| `pulsar_subscription_last_acked_timestamp` | Last ack time |

**BookKeeper metrics** (port 8000 `/metrics`):

| Metric | Description |
|---|---|
| `bookie_SERVER_STATUS` | 1=writable, 0=read-only |
| `bookkeeper_server_ADD_ENTRY_count` | Write operation count |
| `bookkeeper_server_READ_ENTRY_count` | Read operation count |
| `bookie_journal_JOURNAL_SYNC` | Journal fsync latency |
| `bookie_ledgers_count` | Total open ledgers |
| `bookie_read_cache_hits` / `bookie_read_cache_misses` | Cache effectiveness |

### 16.2 Diagnosing Backlog Growth

**Step 1:** Check `pulsar_storage_backlog_size` and `pulsar_storage_backlog_age_seconds` per topic.

**Step 2:** Check `pulsar_subscription_msg_rate_out`. If near zero for an active topic, consumers are stalled.

**Step 3:** Check `pulsar_subscription_blocked_on_unacked_messages = 1`. This indicates the consumer has too many unacknowledged messages and flow control has halted delivery.

**Step 4:** Check `pulsar_subscription_msg_rate_redeliver`. High redeliver rate = consumer failures; check application logs.

**Step 5:** Verify consumer connectivity:
```bash
bin/pulsar-admin topics stats persistent://tenant/ns/topic
# Check "subscriptions" → "consumers" section for active connections
```

**Remediation:**
- Increase consumer parallelism (add consumers to Shared subscription).
- Increase consumer-side unacked message limit if processing is healthy but slow.
- Check for application-side exceptions causing nacks.
- Use `topics skip-all` to purge irrelevant backlog.
- Enable backlog quota at namespace level to prevent unbounded growth.

### 16.3 Broker Load Balancing Issues

Enable load balancing metrics:
```properties
# In broker.conf
loadManagerClassName=org.apache.pulsar.broker.loadbalance.impl.ModularLoadManagerImpl
loadBalancerEnabled=true
exposeBundlesMetricsInPrometheus=true
```

Monitor bundle (topic group) distribution:
```bash
# Check broker resource usage
bin/pulsar-admin brokers get-all-dynamic-configurations
bin/pulsar-admin broker-stats monitoring-metrics

# Force topic bundle split (for hot bundles)
bin/pulsar-admin namespaces split-bundle \
  acme-corp/payments \
  --bundle 0x00000000_0x7fffffff \
  --unload
```

### 16.4 BookKeeper Issues

**Bookie goes read-only:**
- Triggered when disk usage exceeds `diskUsageThreshold`.
- Monitor `bookie_SERVER_STATUS = 0`.
- Resolution: Free disk space, increase disk, or add more bookies.

**High journal latency:**
- Monitor `bookie_journal_JOURNAL_SYNC` percentiles.
- Causes: Slow disk, heavy write load, OS page cache pressure.
- Fixes: Move journal to dedicated fast SSD, reduce `journalMaxGroupWaitMSec`, check OS I/O scheduler.

**High read latency:**
- Monitor `bookkeeper_server_READ_ENTRY_count` vs. `bookie_read_cache_misses`.
- High cache miss rate → increase `dbLedgerStorageLocation` RocksDB cache size.
- For cold reads (tiered storage retrieval), expect higher latency; set consumer expectations accordingly.

**Ledger fragmentation:**
- Run bookie garbage collection:
```bash
bin/bookkeeper shell ledger -ledgerid LEDGER_ID
bin/bookkeeper shell bookiesanity
```

### 16.5 GC Tuning Diagnostics

Monitor GC with:
```bash
# Enable GC logging (JVM args)
-Xlog:gc*:file=/var/log/pulsar/gc.log:time,uptime:filecount=5,filesize=50m
```

Alert on:
- GC pause time > 200ms (should be < 20ms with ZGC).
- GC frequency > 1/sec for major collections.
- Heap utilization consistently > 80% after GC.

---

## 17. Reference: Topic URL Formats

```
# Persistent topic (default)
persistent://tenant/namespace/topic

# Non-persistent topic
non-persistent://tenant/namespace/topic

# Partitioned topic partition (internal)
persistent://tenant/namespace/topic-partition-0

# System topics
persistent://tenant/namespace/__change_events
persistent://tenant/namespace/__transaction_buffer_snapshot
```

## 18. Reference: Retention vs. TTL vs. Backlog Quota

| Mechanism | What It Controls | Where Set |
|---|---|---|
| **Retention** | How long acked messages are kept (for replay/Pulsar SQL) | Namespace or topic |
| **Message TTL** | Auto-expires unacked messages after N seconds | Namespace |
| **Backlog quota** | Limits unacked message accumulation; applies policy on breach | Namespace |
| **Tiered storage** | Offloads old ledgers to object storage | Namespace + broker config |

**Interaction note:** Retention and TTL can conflict. TTL expires unacked messages; Retention only applies to acked messages. A message acked at t=0 with retention=1h will be kept until t=1h. An unacked message at t=0 with TTL=30m will be auto-expired at t=30m regardless of retention setting.
