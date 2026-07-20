# Apache Kafka Best Practices Reference

## Topic Design

### Partition Count

| Guidance | Recommendation |
|----------|---------------|
| Production starting point | 12-30 partitions per topic (post-KRaft guidance) |
| High-throughput topics | More partitions = more parallelism; each partition sustains ~10 MB/s write |
| Low-throughput topics | 3-6 partitions to reduce overhead |
| Upper limit | KRaft supports millions per cluster, but each partition consumes ~10 KB broker memory |
| Key rule | Partition count can be increased but NEVER decreased without recreating the topic |

**Formula:**
```
partitions >= max(target_throughput / partition_throughput, consumer_count)
```

### Replication Factor

| Setting | Use Case |
|---------|----------|
| `replication.factor=3` | Production standard -- tolerates 1 broker failure with `min.insync.replicas=2` |
| `replication.factor=2` | Budget-constrained; tolerates 1 failure only with `min.insync.replicas=1` |
| `replication.factor=1` | Development/testing only -- no fault tolerance |

Always pair `replication.factor=3` with `min.insync.replicas=2`. This ensures writes fail fast if insufficient replicas are available, preventing silent data loss.

### Naming Conventions

Recommended patterns:
```
<domain>.<entity>.<event-type>         # orders.payment.completed
<team>.<system>.<action>               # billing.invoices.created
<environment>.<domain>.<entity>        # prod.users.profile-updated
```

Rules:
- Use lowercase with dots or hyphens as separators
- NEVER use underscores -- Kafka substitutes `.` with `_` in metric names, causing collisions
- Include environment prefix if multiple environments share a cluster
- Document naming conventions as governance policy

## Producer Tuning

### Configuration Profiles

**Maximum throughput:**
```properties
batch.size=131072          # 128 KB
linger.ms=50               # Wait to fill batches
compression.type=lz4       # Fast compression
buffer.memory=67108864     # 64 MB buffer
acks=1                     # Leader-only ack
```

**Maximum durability:**
```properties
batch.size=16384           # 16 KB default
linger.ms=0                # Send immediately
acks=all                   # All ISR ack
enable.idempotence=true    # Dedup retries
# Broker/topic: min.insync.replicas=2
```

**Low latency:**
```properties
batch.size=16384
linger.ms=0
acks=1
compression.type=none
```

### Key Parameters

| Parameter | Default | Tuning Notes |
|-----------|---------|-------------|
| `batch.size` | 16,384 (16 KB) | 32-128 KB for throughput; larger batches compress better |
| `linger.ms` | 5 (Kafka 4.x) | 5-100 ms; higher = more batching, higher latency |
| `buffer.memory` | 33,554,432 (32 MB) | 64-128 MB for high-throughput; `send()` blocks when full |
| `compression.type` | `none` | `lz4` (speed) or `zstd` (ratio); applied per batch |
| `acks` | `all` | `all` for durability; `1` for lower latency |
| `delivery.timeout.ms` | 120,000 (2 min) | Upper bound on total send time including retries |
| `max.in.flight.requests.per.connection` | 5 | Max 5 for idempotent producer; higher may reorder without idempotence |
| `max.request.size` | 1,048,576 (1 MB) | Must be <= broker's `message.max.bytes` |

### Important Relationships

- `batch.size` and `linger.ms` work together -- larger `batch.size` needs higher `linger.ms` to fill
- Compression is most effective with larger batches
- `buffer.memory` must accommodate all in-flight batches; if exhausted, `send()` blocks for `max.block.ms`

## Consumer Tuning

### Configuration Profiles

**Maximum throughput:**
```properties
max.poll.records=2000
fetch.min.bytes=65536          # 64 KB min fetch
fetch.max.wait.ms=500
max.partition.fetch.bytes=2097152  # 2 MB
```

**Low latency:**
```properties
max.poll.records=100
fetch.min.bytes=1
fetch.max.wait.ms=100
```

**Stable consumer groups (Kubernetes):**
```properties
group.instance.id=<stable-pod-identifier>
session.timeout.ms=30000
heartbeat.interval.ms=10000
max.poll.interval.ms=600000
```

### Key Parameters

| Parameter | Default | Tuning Notes |
|-----------|---------|-------------|
| `max.poll.records` | 500 | 500-2,000; lower if processing is slow |
| `max.poll.interval.ms` | 300,000 (5 min) | Match to worst-case processing time; consumer evicted if exceeded |
| `fetch.min.bytes` | 1 | 1,024-65,536 for throughput; broker waits until satisfied |
| `fetch.max.wait.ms` | 500 | Max time broker waits to satisfy `fetch.min.bytes` |
| `session.timeout.ms` | 45,000 (45 sec) | 10,000-30,000 for faster failure detection |
| `heartbeat.interval.ms` | 3,000 | Set to 1/3 of `session.timeout.ms` |
| `auto.offset.reset` | `latest` | `earliest` for batch/reprocessing; `latest` for real-time |
| `enable.auto.commit` | `true` | `false` for exactly-once or manual control |
| `group.protocol` | `classic` | `consumer` (Kafka 4.0+) for server-side rebalance |

## Exactly-Once Patterns

### Pattern 1: Kafka-to-Kafka with Kafka Streams

```properties
processing.guarantee=exactly_once_v2
```

Simplest approach. Kafka Streams handles everything: atomic read-process-write within Kafka. Use `exactly_once_v2` (not the deprecated `exactly_once`).

### Pattern 2: Kafka-to-Kafka with Manual Transactions

```java
producer.initTransactions();
while (true) {
    records = consumer.poll(Duration.ofMillis(100));
    producer.beginTransaction();
    for (record : records) {
        producer.send(transform(record));
    }
    producer.sendOffsetsToTransaction(offsets, consumer.groupMetadata());
    producer.commitTransaction();
}
```

Consumer: `isolation.level=read_committed`, `enable.auto.commit=false`
Producer: `transactional.id=<unique-stable-id>`, `acks=all`

### Pattern 3: Kafka-to-External with Outbox Pattern

Write to the external system AND a local outbox/dedup table in a single database transaction. Use a deduplication key (Kafka record offset or UUID). Commit consumer offset only after external write is confirmed.

### Pattern 4: Kafka Connect Exactly-Once Sink

Configure `exactly.once.support=required` on the Connect worker. Connector must support idempotent writes (e.g., JDBC Sink with upserts). Available since Kafka 3.3+.

## Schema Evolution Strategies

### General Principles

1. Always set a compatibility mode -- never use `NONE` in production
2. Use `BACKWARD` (default) for most Kafka use cases (allows rewinding consumers)
3. Prefer Avro or Protobuf over JSON Schema (more compact, better tooling)
4. Always provide default values for new optional fields

### Avro Rules

- **Safe**: Add field with default, remove field with default
- **Unsafe**: Remove field without default, change field type, rename field
- Use union types with `"null"` for optional fields: `["null", "string"]`

### Protobuf Rules

- **Safe**: Add new fields (with new field numbers), add new message types
- **Unsafe**: Remove or change field numbers, change field types
- Use `BACKWARD_TRANSITIVE` (adding message types is not forward compatible)
- Use `optional` keyword for fields that may be absent

### Versioning Strategy

- Subject naming: `<topic>-value`, `<topic>-key` (TopicNameStrategy, default)
- Alternative: `RecordNameStrategy` (schema per record type) or `TopicRecordNameStrategy`
- Register schemas before deploying new producer versions
- Test compatibility via Schema Registry REST API before deployment

## Security

### Authentication

| Method | Protocol | Best For |
|--------|----------|----------|
| SASL/SCRAM-SHA-256 | `SASL_SSL` | Username/password (recommended over PLAIN) |
| SASL/SCRAM-SHA-512 | `SASL_SSL` | Stronger hash variant |
| mTLS | `SSL` | Certificate-based; strongest, most complex |
| SASL/GSSAPI | `SASL_SSL` | Kerberos / AD integration |
| SASL/OAUTHBEARER | `SASL_SSL` | OAuth 2.0 / OIDC (native in Kafka 4.1+) |

### Security Checklist

1. Always use `SASL_SSL` -- never `PLAINTEXT` in production
2. Prefer SCRAM-SHA-256/512 or mTLS over SASL/PLAIN
3. Set `allow.everyone.if.no.acl.found=false` (deny by default)
4. Use separate credentials per application
5. Rotate certificates and credentials regularly
6. Encrypt inter-broker communication (`inter.broker.listener.name` + SSL)
7. Audit ACL changes; use infrastructure-as-code for ACL management
8. Limit `super.users` to essential administrative principals

### ACL Management

```bash
# Grant produce permission
kafka-acls.sh --bootstrap-server <broker>:9092 \
  --add --allow-principal User:producer-app \
  --operation Write --topic orders

# Grant consume permission
kafka-acls.sh --bootstrap-server <broker>:9092 \
  --add --allow-principal User:consumer-app \
  --operation Read --topic orders \
  --group consumer-group-1

# List ACLs
kafka-acls.sh --bootstrap-server <broker>:9092 --list
```

## Monitoring

### Critical Broker Metrics (JMX)

| Metric | MBean | Alert Threshold |
|--------|-------|----------------|
| Under-replicated partitions | `kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions` | > 0 for > 5 min |
| Active controller count | `kafka.controller:type=KafkaController,name=ActiveControllerCount` | != 1 |
| Offline partitions | `kafka.controller:type=KafkaController,name=OfflinePartitionsCount` | > 0 |
| ISR shrink rate | `kafka.server:type=ReplicaManager,name=IsrShrinksPerSec` | > 0 sustained |
| Request handler idle % | `kafka.server:type=KafkaRequestHandlerPool,name=RequestHandlerAvgIdlePercent` | < 30% |
| Network handler idle % | `kafka.network:type=SocketServer,name=NetworkProcessorAvgIdlePercent` | < 30% |
| Log flush latency | `kafka.log:type=LogFlushStats,name=LogFlushRateAndTimeMs` | P99 > 100ms |
| Bytes in/out per sec | `kafka.server:type=BrokerTopicMetrics,name=BytesInPerSec` | Approaching NIC capacity |

### Consumer Lag Metrics

| Metric | Source | Alert Threshold |
|--------|--------|----------------|
| Consumer lag (records) | `kafka.consumer:type=consumer-fetch-manager-metrics,name=records-lag-max` | Growing consistently |
| Consumer lag via CLI | `kafka-consumer-groups.sh --describe` | LAG column increasing |
| Commit rate | `kafka.consumer:type=consumer-coordinator-metrics,name=commit-rate` | Dropping to 0 |

### Producer Metrics

| Metric | What It Tells You |
|--------|-------------------|
| `record-send-rate` | Throughput |
| `record-error-rate` | Production failures |
| `request-latency-avg` | Broker response time |
| `batch-size-avg` | Batching efficiency |
| `buffer-available-bytes` | Back-pressure risk |

### Monitoring Tools

- **Prometheus + Grafana**: JMX Exporter for Kafka metrics; community dashboards available
- **Burrow** (LinkedIn): Specialized consumer lag monitoring with evaluation logic
- **Cruise Control** (LinkedIn): Automated cluster balancing and anomaly detection
- **AKHQ / Conduktor / Kafka UI**: Web-based cluster management and monitoring
- **Datadog / New Relic / Dynatrace**: Commercial APM with Kafka integrations

## Multi-Datacenter Replication

### MirrorMaker 2 (MM2)

Built on Kafka Connect, MM2 provides cross-cluster replication:

**Components:**
- **MirrorSourceConnector**: Replicates records from source to target
- **MirrorCheckpointConnector**: Synchronizes consumer offsets between clusters
- **MirrorHeartbeatConnector**: Monitors replication health and topology

**Topologies:**
- **Active-Passive**: One primary, one DR. Unidirectional replication.
- **Active-Active**: Bidirectional. Topic prefixes prevent infinite loops (e.g., `dc1.orders`, `dc2.orders`).
- **Fan-out**: One source to multiple targets.
- **Aggregation**: Multiple sources to one central cluster.

**Configuration:**
```properties
clusters=source,target
source.bootstrap.servers=source-broker:9092
target.bootstrap.servers=target-broker:9092
source->target.enabled=true
source->target.topics=.*
replication.factor=3
sync.topic.configs.enabled=true
emit.checkpoints.enabled=true
emit.heartbeats.enabled=true
```

### Multi-DC Best Practices

1. Choose topology based on requirements: active-passive for DR, active-active for geo-distribution
2. Test failover procedures regularly -- automate runbooks
3. Monitor replication lag between clusters as a key SLA metric
4. Account for network latency -- cross-region replication adds latency
5. Use compression for cross-datacenter traffic
6. Separate replication traffic from client traffic (dedicated listeners/NICs)
7. Design for eventual consistency in active-active -- handle conflicts at application layer

## Kafka Connect Deployment

### Production Deployment (Distributed Mode)

- Multiple workers; configuration via REST API; automatic task failover
- Internal topics (`connect-offsets`, `connect-configs`, `connect-status`) with `replication.factor=3`
- Resource isolation: do not run Connect on broker nodes

### Best Practices

| Practice | Details |
|----------|---------|
| Separate Connect clusters | By source vs sink, or by team/domain |
| Error handling | Always configure `errors.tolerance=all` and DLQ for sink connectors |
| Monitoring | Monitor connector status via REST API; alert on FAILED state |
| Config management | Store connector configs in version control; deploy via CI/CD using REST API |
| Converter consistency | Use same converter across all connectors for a given topic |
| One connector per system | One connector per source/sink system, not per topic |
