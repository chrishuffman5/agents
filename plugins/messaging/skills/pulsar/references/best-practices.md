# Apache Pulsar Best Practices Reference

## Topic Design

- Use partitioned topics for high throughput (scale producers and consumers independently)
- Partition count can only increase, never decrease -- start conservatively
- Use `persistent://` for all production data; `non-persistent://` only for ephemeral streams
- Follow naming: `persistent://tenant/namespace/entity-type` (e.g., `persistent://acme/payments/transactions`)

## Subscription Selection

| Use Case | Type | Notes |
|---|---|---|
| Single ordered pipeline | Exclusive | Strict global order; one consumer |
| Work queue / task distribution | Shared | Round-robin; no ordering guarantee |
| HA ordered pipeline | Failover | Standby consumers for failover |
| Per-entity ordered processing | Key_Shared | Per-key routing; disable batching |
| Event sourcing / replay | Exclusive or Failover | Cumulative ack; replay from earliest |

## Producer Tuning

### Batching
- Enable for throughput: `enableBatching(true)` with `batchingMaxMessages`, `batchingMaxBytes`, `batchingMaxPublishDelay`
- Disable for Key_Shared subscriptions (or use key-based batching)
- Batch index acknowledgment (`acknowledgmentAtBatchIndexLevelEnabled=true`) for per-message ack within batches

### Compression
- Enable compression for all production producers
- LZ4 for speed, ZSTD for best ratio
- Consumer decompresses automatically (codec in metadata)

### Deduplication
```bash
bin/pulsar-admin namespaces set-deduplication acme-corp/payments --enable
```
Tracks producer sequence IDs. Prevents duplicate messages from retries.

## Consumer Tuning

### Acknowledgment Strategy
- **Individual ack** for Shared/Key_Shared (each message independently)
- **Cumulative ack** for Exclusive/Failover (ack up to position)
- Use negative ack with backoff for retriable failures
- Configure `ackTimeout` carefully to avoid premature redelivery

### Dead Letter Policy
```java
.deadLetterPolicy(DeadLetterPolicy.builder()
    .maxRedeliverCount(5)
    .deadLetterTopic("persistent://tenant/ns/topic-DLQ")
    .build())
```

### Delayed Delivery (Shared/Key_Shared Only)
```java
producer.newMessage().value(data).deliverAfter(30, TimeUnit.SECONDS).send();
```

## Namespace Policies

### Retention (How Long to Keep Data)
```bash
bin/pulsar-admin namespaces set-retention acme-corp/payments --size 100M --time 10080m
```
Both size and time limits apply (whichever triggers first). Set -1 for unlimited. 0 = delete immediately after ack.

### Backlog Quotas (How Much Unacked Data to Allow)
```bash
bin/pulsar-admin namespaces set-backlog-quota acme-corp/payments \
  --limit 10G --policy producer_request_hold
```
Policies: `producer_request_hold` (block producer), `producer_exception` (reject publish), `consumer_backlog_eviction` (drop oldest).

### Message TTL (Auto-Expire Unacked Messages)
```bash
bin/pulsar-admin namespaces set-message-ttl --messageTTL 3600 acme-corp/payments
```

### Dispatch Rate Limits
```bash
bin/pulsar-admin namespaces set-dispatch-rate acme-corp/payments \
  --msg-dispatch-rate 1000 --byte-dispatch-rate 1048576
```

## Geo-Replication Patterns

| Pattern | Description | Use Case |
|---|---|---|
| Active-passive | Unidirectional replication | Disaster recovery |
| Active-active | Bidirectional replication | Multi-region write |
| Full mesh | All clusters replicate to all | Global distribution |
| Edge-to-cloud | Edge clusters replicate to central | IoT aggregation |

### Replicated Subscriptions
```java
consumer = client.newConsumer(Schema.STRING)
    .topic("persistent://acme/payments/txns")
    .subscriptionName("processor")
    .replicateSubscriptionState(true)
    .subscribe();
```

```properties
# broker.conf
enableReplicatedSubscriptions=true
replicatedSubscriptionsSnapshotFrequencyMillis=1000
```

## Security

### Authentication
- JWT tokens (recommended for most deployments)
- OAuth 2.0 (enterprise SSO integration)
- mTLS (certificate-based)
- Kerberos (legacy enterprise)

### Authorization
```bash
bin/pulsar-admin topics grant-permission --actions produce,consume --role payment-service \
  persistent://acme/payments/transactions
```

### End-to-End Encryption
Unique to Pulsar: producer encrypts per-message with recipient's public key. Broker stores ciphertext only. Zero-trust broker.

## Monitoring

### Key Metrics

| Metric | Source | Alert Threshold |
|---|---|---|
| Backlog size | `topics stats` output | > backlog quota |
| Replication lag | `replicationBacklog` in stats | Growing trend |
| Publish latency | Producer metrics | P99 > SLA |
| Consumer throughput | `msgRateOut` per subscription | Declining |
| BookKeeper journal latency | Bookie metrics | P99 > 10ms |
| Function failures | Function status | > 0 sustained |

### CLI Monitoring
```bash
bin/pulsar-admin topics stats persistent://acme/payments/txns --get-precise-backlog
bin/pulsar-admin topics partitioned-stats persistent://acme/payments/txns --per-partition
bin/pulsar-admin topics stats-internal persistent://acme/payments/txns
```

## BookKeeper Tuning

### Storage Recommendations
- Separate disks for journal (write-ahead log) and entry logs
- SSD/NVMe for journal (write latency critical)
- HDD acceptable for entry logs (sequential reads)
- Separate garbage collection for entry logs

### Key Configuration
```properties
# bookie.conf
journalDirectory=/mnt/journal
ledgerDirectories=/mnt/ledger1,/mnt/ledger2
# Flush interval (lower = more durable, higher latency)
journalFlushWhenQueueEmpty=false
journalBufferedWritesThreshold=524288
# GC
gcWaitTime=900000
minorCompactionThreshold=0.2
majorCompactionThreshold=0.8
```
