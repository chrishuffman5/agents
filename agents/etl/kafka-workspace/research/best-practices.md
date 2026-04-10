# Apache Kafka Best Practices

> Research date: 2026-04-09
> Covers: Kafka 3.9 through 4.2 (current)

---

## 1. Topic Design

### Partition Count

| Guidance | Recommendation |
|----------|---------------|
| **Production starting point** | 12-30 partitions per topic (2025+ guidance, post-KRaft) |
| **Old guidance** | 6-12 partitions (based on ZooKeeper metadata limitations, no longer applies with KRaft) |
| **High-throughput topics** | More partitions = more parallelism; each partition can sustain ~10 MB/s write |
| **Low-throughput topics** | Fewer partitions to reduce overhead; 3-6 may suffice |
| **Upper limit consideration** | KRaft supports millions of partitions per cluster, but each partition consumes memory on the broker (~10 KB per partition for replica metadata) |
| **Key rule** | Partition count can be increased but NEVER decreased without recreating the topic |

**Partition Count Formula:**
```
partitions >= max(target_throughput / partition_throughput, consumer_count)
```

### Replication Factor

| Setting | Use Case |
|---------|----------|
| `replication.factor=3` | Production standard -- tolerates 1 broker failure with `min.insync.replicas=2` |
| `replication.factor=2` | Budget-constrained; tolerates 1 failure only with `min.insync.replicas=1` |
| `replication.factor=1` | Development/testing only -- no fault tolerance |
| **Combined with** `min.insync.replicas=2` | Ensures writes fail fast if insufficient replicas (prevents silent data loss) |

### Naming Conventions

Recommended patterns:
```
<domain>.<entity>.<event-type>         # e.g., orders.payment.completed
<team>.<system>.<action>               # e.g., billing.invoices.created
<environment>.<domain>.<entity>        # e.g., prod.users.profile-updated
```

Rules:
- Use lowercase with dots or hyphens as separators (NOT underscores -- Kafka internally substitutes `.` with `_` in metric names, causing collisions)
- Include environment prefix if multiple environments share a cluster
- Keep names descriptive but concise
- Document naming conventions as governance policy

---

## 2. Producer Tuning

### Key Configuration Parameters

| Parameter | Default | Recommendation | Notes |
|-----------|---------|---------------|-------|
| `batch.size` | 16,384 (16 KB) | 32,768-131,072 (32-128 KB) for throughput | Max batch size in bytes per partition |
| `linger.ms` | 5 (Kafka 4.x) | 5-100 ms depending on latency tolerance | Wait time to fill batches; higher = more batching |
| `buffer.memory` | 33,554,432 (32 MB) | 64-128 MB for high-throughput | Total buffer memory; `send()` blocks when full |
| `compression.type` | `none` | `lz4` (speed) or `zstd` (ratio) | Applied per batch; bigger batches = better ratio |
| `acks` | `all` | `all` for durability; `1` for lower latency | `all` required for idempotent/transactional producer |
| `retries` | 2147483647 | Default is fine (effectively infinite) | Combined with `delivery.timeout.ms` |
| `delivery.timeout.ms` | 120,000 (2 min) | Adjust based on SLA requirements | Upper bound on total send time (includes retries) |
| `max.in.flight.requests.per.connection` | 5 | 5 (max for idempotent producer) | Higher increases throughput but may reorder without idempotence |
| `enable.idempotence` | `true` (3.0+) | Keep `true` | Free deduplication; no reason to disable |
| `max.request.size` | 1,048,576 (1 MB) | Increase if sending large records | Must be <= broker's `message.max.bytes` |

### Tuning Strategy

**For maximum throughput:**
```properties
batch.size=131072
linger.ms=50
compression.type=lz4
buffer.memory=67108864
acks=1
```

**For maximum durability:**
```properties
batch.size=16384
linger.ms=0
acks=all
enable.idempotence=true
min.insync.replicas=2  # (broker/topic config)
```

**For low latency:**
```properties
batch.size=16384
linger.ms=0
acks=1
compression.type=none
```

### Important Relationships
- `batch.size` and `linger.ms` work together -- adjust both; larger `batch.size` often needs higher `linger.ms` to fill effectively
- `compression.type` is most effective with larger batches
- `buffer.memory` must accommodate all in-flight batches; if exhausted, `send()` blocks for `max.block.ms`

---

## 3. Consumer Tuning

### Key Configuration Parameters

| Parameter | Default | Recommendation | Notes |
|-----------|---------|---------------|-------|
| `max.poll.records` | 500 | 500-2,000 depending on processing speed | Records per `poll()` call; lower if processing is slow |
| `max.poll.interval.ms` | 300,000 (5 min) | Match to worst-case processing time | Consumer removed from group if exceeded |
| `fetch.min.bytes` | 1 | 1,024-65,536 for throughput | Broker waits until this many bytes available; reduces fetch frequency |
| `fetch.max.wait.ms` | 500 | 100-500 ms | Max time broker waits to satisfy `fetch.min.bytes` |
| `fetch.max.bytes` | 52,428,800 (50 MB) | Default usually fine | Max data per fetch response across all partitions |
| `max.partition.fetch.bytes` | 1,048,576 (1 MB) | Increase for large records | Max data per partition per fetch |
| `session.timeout.ms` | 45,000 (45 sec) | 10,000-30,000 for faster failure detection | Lower = faster rebalance on consumer failure, but risk of false positives |
| `heartbeat.interval.ms` | 3,000 | 1/3 of `session.timeout.ms` | Heartbeat frequency to group coordinator |
| `auto.offset.reset` | `latest` | `earliest` for batch/reprocessing; `latest` for real-time | What to do when no committed offset exists |
| `enable.auto.commit` | `true` | `false` for exactly-once or manual control | Set `false` when using transactional consumers |
| `group.protocol` | `classic` | `consumer` (Kafka 4.0+) | Opt into new server-side rebalance protocol |

### Tuning Strategy

**For maximum throughput:**
```properties
max.poll.records=2000
fetch.min.bytes=65536
fetch.max.wait.ms=500
max.partition.fetch.bytes=2097152
```

**For low latency:**
```properties
max.poll.records=100
fetch.min.bytes=1
fetch.max.wait.ms=100
```

**For stable consumer groups (Kubernetes):**
```properties
group.instance.id=<stable-pod-identifier>
session.timeout.ms=30000
heartbeat.interval.ms=10000
max.poll.interval.ms=600000
```

---

## 4. Exactly-Once Patterns in Data Pipelines

### Pattern 1: Kafka-to-Kafka (Kafka Streams)
```
processing.guarantee=exactly_once_v2
```
- Simplest approach; Kafka Streams handles everything
- Atomic read-process-write within Kafka
- Use `exactly_once_v2` (not `exactly_once` which is deprecated)

### Pattern 2: Kafka-to-Kafka (Manual Transactions)
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
- Consumer: `isolation.level=read_committed`, `enable.auto.commit=false`
- Producer: `transactional.id=<unique-stable-id>`, `acks=all`

### Pattern 3: Kafka-to-External (Outbox Pattern)
- Write to external system AND a local outbox/dedup table in a single DB transaction
- Use idempotent writes with a deduplication key (Kafka record offset or a UUID)
- Consumer commits offset only after external write is confirmed

### Pattern 4: Kafka Connect Exactly-Once Sink
- Kafka Connect 3.3+ supports exactly-once sink delivery
- Configure: `exactly.once.support=required` on the Connect worker
- Connector must support it (e.g., JDBC Sink with idempotent upserts)

---

## 5. Schema Evolution Strategies

### General Principles
1. **Always set a compatibility mode** -- never use `NONE` in production
2. **Use `BACKWARD` (default) for most Kafka use cases** -- allows rewinding consumers
3. **Prefer Avro or Protobuf** over JSON Schema for production (more compact, better tooling)
4. **Always provide default values** for new optional fields

### Avro Evolution Rules
- **Safe**: Add field with default, remove field with default
- **Unsafe**: Remove field without default, change field type, rename field
- Use union types with `"null"` for optional fields: `["null", "string"]`

### Protobuf Evolution Rules
- **Safe**: Add new fields (with new field numbers), add new message types
- **Unsafe**: Remove or change field numbers, change field types
- Use `BACKWARD_TRANSITIVE` (adding new message types is not forward compatible)
- Use `optional` keyword for fields that may be absent

### JSON Schema Evolution Rules
- Less strict than Avro/Protobuf -- more prone to accidental breaking changes
- Define `additionalProperties: true` to allow forward compatibility
- Use `FULL_TRANSITIVE` for maximum safety

### Versioning Strategy
- Subject naming: `<topic>-value`, `<topic>-key` (TopicNameStrategy, default)
- Alternative: `RecordNameStrategy` (schema per record type) or `TopicRecordNameStrategy`
- Register schemas before deploying new producer versions
- Test compatibility via Schema Registry REST API before deployment

---

## 6. Kafka Connect Deployment Patterns

### Standalone Mode
- **When**: Development, testing, single-agent scenarios (e.g., log shipping from one server)
- **How**: Single worker process; configuration via `.properties` files
- **Limitations**: No fault tolerance, no horizontal scaling, no REST API management

### Distributed Mode (Recommended for Production)
- **When**: Production workloads requiring HA, scalability, and manageability
- **How**: Multiple worker processes; configuration via REST API
- **Features**: Automatic task distribution, failover on worker failure, rolling upgrades
- **Internal topics**: `connect-offsets`, `connect-configs`, `connect-status` (configure with `replication.factor=3`)

### Deployment Best Practices

| Practice | Details |
|----------|---------|
| **Separate Connect clusters** | Run separate Connect clusters for source vs. sink, or by team/domain |
| **Resource isolation** | Don't run Connect on broker nodes in production |
| **Connector-per-topic** | Generally one connector per source/sink system, not per topic |
| **Error handling** | Always configure `errors.tolerance=all` and DLQ for sink connectors |
| **Monitoring** | Monitor connector status via REST API; alert on FAILED state |
| **Config management** | Store connector configs in version control; deploy via CI/CD using REST API |
| **Converter consistency** | Use the same converter (e.g., AvroConverter) across all connectors for a given topic |

---

## 7. Monitoring

### Critical Broker Metrics (JMX)

| Metric | MBean | Alert Threshold |
|--------|-------|----------------|
| **Under-replicated partitions** | `kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions` | > 0 for > 5 min |
| **Active controller count** | `kafka.controller:type=KafkaController,name=ActiveControllerCount` | != 1 (exactly one expected) |
| **Offline partitions** | `kafka.controller:type=KafkaController,name=OfflinePartitionsCount` | > 0 |
| **ISR shrink rate** | `kafka.server:type=ReplicaManager,name=IsrShrinksPerSec` | > 0 sustained |
| **ISR expand rate** | `kafka.server:type=ReplicaManager,name=IsrExpandsPerSec` | Should follow shrinks |
| **Request handler idle %** | `kafka.server:type=KafkaRequestHandlerPool,name=RequestHandlerAvgIdlePercent` | < 30% |
| **Network handler idle %** | `kafka.network:type=SocketServer,name=NetworkProcessorAvgIdlePercent` | < 30% |
| **Log flush latency** | `kafka.log:type=LogFlushStats,name=LogFlushRateAndTimeMs` | P99 > 100ms |
| **Bytes in/out per sec** | `kafka.server:type=BrokerTopicMetrics,name=BytesInPerSec` | Approaching NIC capacity |

### Consumer Lag Metrics

| Metric | Source | Alert Threshold |
|--------|--------|----------------|
| **Consumer lag (records)** | `kafka.consumer:type=consumer-fetch-manager-metrics,client-id=*,topic=*,partition=*,name=records-lag-max` | Growing consistently |
| **Consumer lag via tool** | `kafka-consumer-groups.sh --describe` | LAG column increasing |
| **Commit rate** | `kafka.consumer:type=consumer-coordinator-metrics,name=commit-rate` | Dropping to 0 |

### Producer Metrics

| Metric | MBean | What It Tells You |
|--------|-------|-------------------|
| **Record send rate** | `kafka.producer:type=producer-metrics,name=record-send-rate` | Throughput |
| **Record error rate** | `kafka.producer:type=producer-metrics,name=record-error-rate` | Production failures |
| **Request latency** | `kafka.producer:type=producer-metrics,name=request-latency-avg` | Broker response time |
| **Batch size avg** | `kafka.producer:type=producer-metrics,name=batch-size-avg` | Batching efficiency |
| **Buffer available bytes** | `kafka.producer:type=producer-metrics,name=buffer-available-bytes` | Back-pressure risk |

### Monitoring Tools
- **Prometheus + Grafana**: JMX Exporter for Kafka metrics; community dashboards available
- **Burrow** (LinkedIn): Specialized consumer lag monitoring with lag evaluation
- **Cruise Control** (LinkedIn): Automated cluster balancing and anomaly detection
- **AKHQ / Conduktor / Kafka UI**: Web-based cluster management and monitoring
- **Datadog / New Relic / Dynatrace**: Commercial APM with Kafka integrations

---

## 8. Security

### Authentication

| Method | Protocol | Best For |
|--------|----------|----------|
| **SASL/SCRAM-SHA-256** | `SASL_SSL` | Username/password auth (recommended over PLAIN) |
| **SASL/SCRAM-SHA-512** | `SASL_SSL` | Stronger hash variant |
| **mTLS (mutual TLS)** | `SSL` | Certificate-based auth; strongest, most complex |
| **SASL/GSSAPI** | `SASL_SSL` | Kerberos integration (enterprise AD/LDAP) |
| **SASL/OAUTHBEARER** | `SASL_SSL` | OAuth 2.0 / OIDC tokens (Kafka 4.1+ native support) |
| **SASL/PLAIN** | `SASL_SSL` | Simple username/password (ONLY with TLS) |

### Encryption

| Layer | Config | Notes |
|-------|--------|-------|
| **In-transit (client-broker)** | `security.protocol=SSL` or `SASL_SSL` | Always enable in production |
| **In-transit (broker-broker)** | `inter.broker.listener.name` + SSL | Encrypt inter-broker traffic |
| **At-rest** | OS-level or disk-level encryption | Kafka does not natively encrypt at rest |

### Authorization

**ACLs (Access Control Lists):**
- Built into Apache Kafka (no external dependency)
- Grant/deny permissions per principal, per resource (topic, group, cluster, transactional ID)
- Managed via `kafka-acls.sh` tool
- **Critical**: Set `allow.everyone.if.no.acl.found=false` (deny by default)

**RBAC (Role-Based Access Control):**
- Available in Confluent Platform (not open-source Apache Kafka)
- Predefined roles: ClusterAdmin, DeveloperManage, DeveloperRead, DeveloperWrite, ResourceOwner
- More manageable than individual ACLs at scale

### Security Best Practices
1. Always use `SASL_SSL` (authentication + encryption) -- never `PLAINTEXT` in production
2. Prefer SCRAM-SHA-256/512 or mTLS over SASL/PLAIN
3. Set `allow.everyone.if.no.acl.found=false` to deny by default
4. Use separate credentials/certificates per application
5. Rotate certificates and credentials regularly
6. Encrypt inter-broker communication
7. Audit ACL changes; use infrastructure-as-code for ACL management
8. Limit `super.users` to essential administrative principals

---

## 9. Multi-Datacenter

### MirrorMaker 2 (MM2) -- Open Source

Built on Kafka Connect, MM2 provides cross-cluster replication:

**Components:**
- **MirrorSourceConnector**: Replicates records from source to target cluster
- **MirrorCheckpointConnector**: Synchronizes consumer offsets between clusters
- **MirrorHeartbeatConnector**: Monitors replication health and topology

**Topologies:**
- **Active-Passive**: One primary, one DR cluster; MM2 replicates unidirectionally
- **Active-Active**: Bidirectional replication; topic prefixes prevent infinite loops (e.g., `dc1.orders`, `dc2.orders`)
- **Fan-out**: One source replicates to multiple targets
- **Aggregation**: Multiple sources replicate to a central cluster

**Configuration:**
```properties
clusters=source,target
source.bootstrap.servers=source-broker:9092
target.bootstrap.servers=target-broker:9092
source->target.enabled=true
source->target.topics=.*              # Replicate all topics
replication.factor=3
sync.topic.configs.enabled=true
sync.topic.acls.enabled=true
emit.checkpoints.enabled=true
emit.heartbeats.enabled=true
```

**Key Considerations:**
- Replication is asynchronous -- some data loss possible during failover
- Consumer offset translation enables consumer failover between clusters
- Topic names are prefixed by source cluster alias (e.g., `source.my-topic`)
- Monitor replication lag via heartbeat topics

### Cluster Linking -- Confluent Platform Only

Confluent's alternative to MM2:
- **Byte-for-byte replication** (no re-serialization) -- preserves offsets exactly
- **No topic renaming** -- mirror topics have identical names
- **Consumer failover** without offset translation (offsets are identical)
- **Lower latency** than MM2 (direct broker-to-broker replication)
- **Simpler configuration** -- single command to set up a link
- **Commercial feature** -- requires Confluent Platform or Confluent Cloud

### Multi-Datacenter Best Practices
1. **Choose topology based on requirements**: active-passive for DR, active-active for geo-distribution
2. **Test failover procedures regularly** -- automate runbooks
3. **Monitor replication lag** between clusters as a key SLA metric
4. **Account for network latency** -- cross-region replication adds latency
5. **Use compression** for cross-datacenter traffic to reduce bandwidth
6. **Separate replication traffic** from client traffic (dedicated listeners/NICs)
7. **Design for eventual consistency** in active-active setups -- handle conflicts at the application layer

---

## Sources

- [Conduktor - Topic Design Guidelines](https://www.conduktor.io/glossary/kafka-topic-design-guidelines)
- [Confluent - Kafka Partition Strategy](https://www.confluent.io/learn/kafka-partition-strategy/)
- [Confluent - Producer Configuration](https://docs.confluent.io/platform/current/installation/configuration/producer-configs.html)
- [Strimzi - Producer Tuning](https://strimzi.io/blog/2020/10/15/producer-tuning/)
- [Strimzi - Consumer Tuning](https://strimzi.io/blog/2021/01/07/consumer-tuning/)
- [Red Hat - Kafka Configuration Tuning](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/2.7/html/kafka_configuration_tuning/con-high-volume-config-properties-str)
- [Confluent - Monitoring Kafka with JMX](https://docs.confluent.io/platform/7.4/kafka/monitoring.html)
- [Confluent - Consumer Lag Monitoring](https://docs.confluent.io/platform/current/monitor/monitor-consumer-lag.html)
- [Datadog - Monitoring Kafka Performance](https://www.datadoghq.com/blog/monitoring-kafka-performance-metrics/)
- [Instaclustr - Kafka Monitoring Key Metrics 2025](https://www.instaclustr.com/education/apache-kafka/kafka-monitoring-key-metrics-and-5-tools-to-know-in-2025/)
- [AutoMQ - Kafka Security Best Practices](https://www.automq.com/blog/kafka-security-all-you-need-to-know-and-best-practices)
- [Conduktor - Kafka Security Best Practices](https://www.conduktor.io/glossary/kafka-security-best-practices)
- [Confluent - Schema Registry Best Practices](https://www.confluent.io/blog/best-practices-for-confluent-schema-registry/)
- [Confluent - Cross-Datacenter Replication](https://www.confluent.io/blog/kafka-cross-data-center-replication-decision-playbook/)
- [Conduktor - MirrorMaker 2](https://www.conduktor.io/glossary/kafka-mirrormaker-2-for-cross-cluster-replication)
- [Apache Kafka - Geo-Replication](https://kafka.apache.org/41/operations/geo-replication-cross-cluster-data-mirroring/)
- [New Relic - Tuning Kafka Consumers](https://newrelic.com/blog/apm/tuning-apache-kafka-consumers)
- [Instaclustr - Kafka Performance Best Practices 2026](https://www.instaclustr.com/education/apache-kafka/kafka-performance-7-critical-best-practices-in-2026/)
