# Apache Pulsar Architecture Reference

## Core Layers

### Broker Layer (Stateless)
Handles incoming messages and dispatches to consumers. Owns topics (one broker per topic). Maintains managed ledger cache for tailing consumers. HTTP REST API (port 8080) and binary TCP (port 6650). Adding/removing brokers requires no data migration.

### BookKeeper Layer (Bookies)
Durable, low-latency storage as distributed WAL. Key abstractions:
- **Ledger:** Append-only sequence of entries replicated across bookies. Sealed ledgers are immutable.
- **Managed Ledger:** Topic-level abstraction of multiple BookKeeper ledgers. Tracks cursor positions.
- **Journal:** Transaction log. fsync before ack. Ensures crash durability.
- **Entry Log:** Long-term data storage. Entries from multiple ledgers multiplexed.
- **RocksDB Index:** Maps (ledgerId, entryId) to entry log positions.

**Replication:** E (ensemble), Qw (write quorum), Qa (ack quorum). Default: E=3, Qw=3, Qa=2.

### Metadata Store
ZooKeeper (default), etcd, RocksDB (dev), Oxia (large clusters, 4.x).

### Pulsar Proxy
Optional stateless gateway. Single entry point for clients. Handles broker routing transparently.

## Multi-Tenancy

```
Instance --> Cluster(s) --> Tenant(s) --> Namespace(s) --> Topic(s)
```

**Tenants:** Top-level admin unit. Own auth scheme and allowed clusters.
```bash
bin/pulsar-admin tenants create acme-corp --admin-roles admin --allowed-clusters us-west,us-east
```

**Namespaces:** Logical topic groupings. All policies configured here: retention, TTL, backlog quotas, dispatch rates, replication, encryption.
```bash
bin/pulsar-admin namespaces create acme-corp/payments
bin/pulsar-admin namespaces set-retention acme-corp/payments --size 100M --time 10080m
bin/pulsar-admin namespaces set-message-ttl --messageTTL 3600 acme-corp/payments
bin/pulsar-admin namespaces set-backlog-quota --limit 10G --policy producer_request_hold acme-corp/payments
```

## Topics and Partitions

Topic naming: `{persistent|non-persistent}://{tenant}/{namespace}/{topic}`

**Partitioned topics:** Backed by N internal partition topics for horizontal scaling. Partition count can only increase.
```bash
bin/pulsar-admin topics create-partitioned-topic persistent://acme-corp/payments/txns --partitions 8
bin/pulsar-admin topics update-partitioned-topic persistent://acme-corp/payments/txns --partitions 16
```

## Subscription Types

### Exclusive (Default)
One consumer. Strict ordering. Error on second subscriber.

### Shared
Multiple consumers, round-robin. No ordering. Individual ack only. Delayed delivery supported.

### Failover
Multiple consumers, one active. Others standby. Ordering maintained on active. Cumulative ack.

### Key_Shared
Multiple consumers. Same key routed to same consumer consistently. Per-key ordering. 4.0 PIP-379: enhanced implementation eliminates unnecessary blocking.

**Critical:** Disable batching or use key-based batching for Key_Shared.

## Acknowledgment

- **Individual:** `consumer.acknowledge(message)` -- one specific message
- **Cumulative:** `consumer.acknowledgeCumulative(message)` -- all up to and including (Exclusive/Failover only)
- **Negative ack:** `consumer.negativeAcknowledge(message)` -- redeliver with backoff
- **Ack timeout:** Auto-redeliver if no ack within configured timeout

## Message Features

- **Batching:** Multiple messages per storage entry. Configurable by count/size/delay. Batch index ack available.
- **Chunking:** Messages > maxMessageSize (5 MB) split into chunks. Persistent topics only. Cannot combine with batching.
- **Compression:** LZ4, ZLIB, ZSTD, SNAPPY. Set at producer level.
- **Deduplication:** Per-producer sequence IDs. Enable at namespace or topic level.

## Retry and Dead Letter Topics

```java
Consumer<byte[]> consumer = client.newConsumer()
    .topic("persistent://tenant/ns/orders")
    .subscriptionName("processor")
    .enableRetry(true)
    .deadLetterPolicy(DeadLetterPolicy.builder()
        .maxRedeliverCount(5)
        .retryLetterTopic("persistent://tenant/ns/orders-processor-RETRY")
        .deadLetterTopic("persistent://tenant/ns/orders-processor-DLQ")
        .build())
    .subscribe();
```

## Geo-Replication

**Async:** Messages persist locally first, replicate asynchronously. Lower latency, some replication lag.
**Sync:** BookKeeper region-aware placement. Write to multiple DCs before ack. RPO near 0.

```bash
bin/pulsar-admin clusters create us-east --broker-url pulsar://us-east:6650 --url http://us-east:8080
bin/pulsar-admin namespaces set-clusters acme-corp/payments --clusters us-west,us-east
```

**Replicated subscriptions:** Consumer position maintained across clusters for failover.

## Tiered Storage

Sealed BookKeeper segments offloaded to object storage (S3, GCS, Azure Blob, MinIO). Transparent to consumers. Erasure coding reduces cost 60-70% vs BookKeeper replication.

```bash
bin/pulsar-admin namespaces set-offload-threshold --size 1073741824 acme-corp/payments
```

## Schema Registry

Built-in per-topic. Types: AVRO, JSON, PROTOBUF, PROTOBUF_NATIVE (4.2), KEY_VALUE, primitives. Compatibility: BACKWARD, FORWARD, FULL, ALWAYS_COMPATIBLE.

## Transactions (4.0+)

Atomic consume-process-produce across topics. Transaction Coordinator manages lifecycle. Read-committed isolation.

```java
Transaction txn = client.newTransaction().withTransactionTimeout(5, TimeUnit.MINUTES).build().get();
producer.newMessage(txn).value("data".getBytes()).sendAsync();
consumer.acknowledgeAsync(msg.getMessageId(), txn);
txn.commit().get();
```

4.2: Transaction support for Pulsar Functions.

## Topic Compaction

Latest-value-per-key view. Messages with empty payloads are tombstones.
```bash
bin/pulsar-admin topics compact persistent://acme-corp/config/flags
```

## Ecosystem

### Pulsar Functions
Serverless compute. Java, Python, Go. Thread/Process/Kubernetes deployment. Stateful functions with BookKeeper table service.

### Pulsar IO
Source and sink connectors. Kafka, Debezium, Cassandra, Elasticsearch, JDBC, HDFS. Processing guarantees: ATMOST_ONCE, ATLEAST_ONCE, EFFECTIVELY_ONCE.

### Pulsar SQL
Trino (Presto) integration. SQL queries on topics reading directly from BookKeeper. Requires registered schema.

### KoP (Kafka-on-Pulsar)
Kafka protocol handler. Existing Kafka clients connect to Pulsar without code changes.
