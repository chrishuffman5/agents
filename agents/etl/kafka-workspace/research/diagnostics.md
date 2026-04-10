# Apache Kafka Diagnostics

> Research date: 2026-04-09
> Covers: Kafka 3.9 through 4.2 (current)

---

## 1. Common Issues

### Consumer Lag

**Symptoms:**
- Growing gap between producer offset (log-end-offset) and consumer committed offset
- `records-lag-max` metric increasing over time
- `kafka-consumer-groups.sh --describe` shows increasing LAG column

**Root Causes:**

| Cause | Diagnosis | Resolution |
|-------|-----------|------------|
| **Slow processing** | Processing time per record exceeds throughput rate | Optimize processing logic; increase `max.poll.records`; add consumers (up to partition count) |
| **Downstream dependency** | External service (DB, API) slow or unavailable | Add circuit breakers; batch writes to external systems; use async processing |
| **Insufficient consumers** | Fewer consumers than partitions | Scale consumer instances up to partition count |
| **Deserialization overhead** | Complex schemas or large records | Optimize schema; use efficient formats (Avro, Protobuf over JSON) |
| **GC pauses** | Consumer JVM garbage collection > `max.poll.interval.ms` | Tune JVM heap and GC; reduce `max.poll.records` |
| **Network throttling** | Broker-side quota limiting consumer fetch rate | Check `client.quota.callback.class`; increase quota or exempt consumer |
| **Partition skew** | Some partitions have much more data than others | Review partition key distribution; consider custom partitioner |

**Diagnostic Commands:**
```bash
# Check consumer group lag
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --describe --group <group-id>

# Check lag for all groups
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --describe --all-groups

# Check consumer group state
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --describe --group <group-id> --state
```

---

### Rebalancing Storms

**Symptoms:**
- Frequent, cascading rebalances that prevent consumers from stabilizing
- Consumer group state oscillating between `Rebalancing` and `Stable`
- High `sync-rate` metric
- Processing throughput drops to zero during rebalances
- Log messages: "Revoking partition assignments", "Attempting to join group"

**Root Causes:**

| Cause | Diagnosis | Resolution |
|-------|-----------|------------|
| **Processing exceeds `max.poll.interval.ms`** | Consumer takes too long between `poll()` calls | Increase `max.poll.interval.ms`; reduce `max.poll.records`; optimize processing |
| **Session timeout too low** | `session.timeout.ms` < GC pause or network hiccup duration | Increase `session.timeout.ms` (e.g., 30-45 seconds) |
| **Consumer crash loop** | Consumer throws exception, restarts, triggers rebalance | Fix application bugs; add error handling |
| **Rolling deployments** | Sequential consumer restarts trigger chain of rebalances | Use static group membership (`group.instance.id`); use cooperative rebalancing |
| **Too many consumers joining** | Large consumer group scaling up simultaneously | Stagger consumer startup; use static membership |
| **Network instability** | Heartbeats lost, coordinator marks consumer dead | Fix network; increase `session.timeout.ms` |

**Resolution Strategies:**
1. **Switch to cooperative rebalancing**: `partition.assignment.strategy=org.apache.kafka.clients.consumer.CooperativeStickyAssignor`
2. **Use static group membership**: Set `group.instance.id=<stable-id>` (e.g., pod name in K8s)
3. **Upgrade to KIP-848 protocol** (Kafka 4.0+): `group.protocol=consumer` -- server-side assignment eliminates most rebalance issues
4. **Tune timeouts**: Increase `session.timeout.ms` and `max.poll.interval.ms` appropriately

---

### Under-Replicated Partitions

**Symptoms:**
- `UnderReplicatedPartitions` metric > 0
- `IsrShrinksPerSec` increasing without corresponding `IsrExpandsPerSec`
- `kafka-topics.sh --describe` shows ISR set smaller than replica set

**Root Causes:**

| Cause | Diagnosis | Resolution |
|-------|-----------|------------|
| **Broker overloaded** | High CPU, memory, or disk I/O on follower broker | Rebalance partitions; add brokers; reduce partition count |
| **Network issues** | Packet loss or high latency between brokers | Check network; move brokers closer; check NICs |
| **Disk I/O saturation** | Follower can't write to disk fast enough | Use SSDs; spread log dirs across disks; reduce `num.replica.fetchers` |
| **Broker down** | Follower broker crashed or unresponsive | Restart broker; check logs for OOM or disk full |
| **GC pauses** | Long JVM pauses on follower | Tune GC; reduce heap size; use G1GC or ZGC |
| **Large messages** | Single large record blocking replication | Increase `replica.fetch.max.bytes`; consider chunking large records |
| **replica.lag.time.max.ms too low** | Followers removed from ISR too aggressively | Increase (default 30s is usually fine) |

**Diagnostic Commands:**
```bash
# Check topic replication status
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --describe --under-replicated-partitions

# Check specific topic
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --describe --topic <topic-name>

# Check broker log for replication errors
# Look in server.log for "ISR" or "replica" related messages
```

---

## 2. Performance Bottlenecks

### Network Saturation

**Indicators:**
- `BytesInPerSec` / `BytesOutPerSec` approaching NIC capacity
- `NetworkProcessorAvgIdlePercent` < 30%
- High `request-latency-avg` for produce and fetch requests
- Increasing `RequestQueueSize`

**Diagnosis:**
```bash
# Check network throughput metrics
# Monitor BytesInPerSec and BytesOutPerSec per broker
# Compare against NIC bandwidth (e.g., 10 Gbps = ~1.25 GB/s)
```

**Resolution:**
- Enable compression (`lz4` or `zstd`) to reduce wire traffic
- Increase `num.network.threads` (default 3) to handle more concurrent connections
- Distribute load across more brokers
- Use dedicated NICs for replication vs. client traffic
- Consider rack-aware replica placement to reduce cross-rack traffic

### Disk I/O

**Indicators:**
- `LogFlushRateAndTimeMs` P99 > 100ms
- `RequestHandlerAvgIdlePercent` < 30%
- High `iowait` at OS level
- Producer latency increasing

**Diagnosis:**
```bash
# OS-level disk monitoring
iostat -x 1        # Check %util, await, r/s, w/s per disk
df -h              # Check disk space
```

**Resolution:**
- **Upgrade to SSDs** -- critical for Kafka; NVMe preferred
- **Multiple log directories** across separate physical disks (`log.dirs=/disk1/kafka,/disk2/kafka`)
- **Separate OS disk from Kafka data disk**
- **Tune page cache** -- Kafka relies heavily on OS page cache; ensure sufficient free memory
- **Enable tiered storage** (Kafka 3.9+) to offload cold data to remote storage
- **Adjust flush settings**: `log.flush.interval.messages` and `log.flush.interval.ms` (usually OS-managed is fine)

### GC Pauses

**Indicators:**
- Broker JVM GC logs showing long pauses (> 200ms)
- Intermittent spikes in request latency
- Followers falling out of ISR periodically
- Consumer rebalances triggered by missed heartbeats

**Diagnosis:**
```bash
# Enable GC logging
-Xlog:gc*:file=/var/log/kafka/gc.log:time,tags:filecount=10,filesize=100M

# Analyze GC logs
# Look for: Full GC events, pause times, heap utilization patterns
```

**Resolution:**
- **Use G1GC** (default for Kafka) with tuned parameters:
  ```
  -XX:+UseG1GC
  -XX:MaxGCPauseMillis=20
  -XX:InitiatingHeapOccupancyPercent=35
  -XX:G1HeapRegionSize=16M
  ```
- **Consider ZGC** (Java 17+) for ultra-low-pause requirements:
  ```
  -XX:+UseZGC
  ```
- **Right-size heap**: 6-8 GB is typical; too large causes long GC pauses, too small causes frequent GC
- **Leave memory for page cache**: Kafka's performance depends on OS page cache; don't give all RAM to JVM heap
- **Recommended split**: ~60-70% of RAM for page cache, ~30-40% for JVM heap (across all JVMs on the machine)

---

## 3. Troubleshooting Tools

### kafka-consumer-groups.sh

```bash
# List all consumer groups
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 --list

# Describe a specific group (partitions, offsets, lag, consumer IDs)
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --describe --group <group-id>

# Show group state (Stable, Rebalancing, Empty, Dead)
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --describe --group <group-id> --state

# Show group members and assigned partitions
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --describe --group <group-id> --members --verbose

# Reset offsets to earliest (DRY RUN)
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --group <group-id> --reset-offsets --to-earliest \
  --topic <topic> --dry-run

# Reset offsets to earliest (EXECUTE -- group must be stopped)
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --group <group-id> --reset-offsets --to-earliest \
  --topic <topic> --execute

# Reset offsets to specific timestamp
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --group <group-id> --reset-offsets \
  --to-datetime 2026-04-09T00:00:00.000 \
  --topic <topic> --execute

# Delete a consumer group (must have no active members)
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --delete --group <group-id>
```

### kafka-topics.sh

```bash
# List all topics
kafka-topics.sh --bootstrap-server <broker>:9092 --list

# Describe a topic (partitions, replicas, ISR, leader)
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --describe --topic <topic-name>

# Show under-replicated partitions across all topics
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --describe --under-replicated-partitions

# Show partitions with no leader
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --describe --unavailable-partitions

# Create a topic
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --create --topic <topic-name> \
  --partitions 12 --replication-factor 3

# Alter partition count (increase only)
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --alter --topic <topic-name> --partitions 24

# Delete a topic
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --delete --topic <topic-name>
```

### kafka-configs.sh

```bash
# Describe topic-level configuration overrides
kafka-configs.sh --bootstrap-server <broker>:9092 \
  --entity-type topics --entity-name <topic-name> --describe

# Set topic configuration
kafka-configs.sh --bootstrap-server <broker>:9092 \
  --entity-type topics --entity-name <topic-name> \
  --alter --add-config retention.ms=86400000

# Delete topic configuration override (reverts to broker default)
kafka-configs.sh --bootstrap-server <broker>:9092 \
  --entity-type topics --entity-name <topic-name> \
  --alter --delete-config retention.ms

# Describe broker configuration
kafka-configs.sh --bootstrap-server <broker>:9092 \
  --entity-type brokers --entity-name <broker-id> --describe

# Set client quota
kafka-configs.sh --bootstrap-server <broker>:9092 \
  --entity-type users --entity-name <user> \
  --alter --add-config producer_byte_rate=1048576,consumer_byte_rate=2097152
```

### kafka-metadata-quorum.sh (KRaft, Kafka 3.9+)

```bash
# Describe the KRaft quorum status
kafka-metadata-quorum.sh --bootstrap-controller <controller>:9093 describe --status

# Show replication status of metadata
kafka-metadata-quorum.sh --bootstrap-controller <controller>:9093 describe --replication
```

### kafka-reassign-partitions.sh

```bash
# Generate reassignment plan (based on broker list)
kafka-reassign-partitions.sh --bootstrap-server <broker>:9092 \
  --topics-to-move-json-file topics.json \
  --broker-list "1,2,3,4" --generate

# Execute reassignment plan
kafka-reassign-partitions.sh --bootstrap-server <broker>:9092 \
  --reassignment-json-file plan.json --execute

# Verify reassignment progress
kafka-reassign-partitions.sh --bootstrap-server <broker>:9092 \
  --reassignment-json-file plan.json --verify

# Throttle reassignment to limit impact
kafka-reassign-partitions.sh --bootstrap-server <broker>:9092 \
  --reassignment-json-file plan.json --execute \
  --throttle 50000000  # 50 MB/s
```

### Additional Tools

```bash
# Produce test messages
kafka-console-producer.sh --bootstrap-server <broker>:9092 \
  --topic <topic-name>

# Consume messages (from beginning)
kafka-console-consumer.sh --bootstrap-server <broker>:9092 \
  --topic <topic-name> --from-beginning

# Consume with key display
kafka-console-consumer.sh --bootstrap-server <broker>:9092 \
  --topic <topic-name> --from-beginning \
  --property print.key=true --property key.separator=:

# Check log segment details
kafka-dump-log.sh --files <segment-file>.log --print-data-log

# Dump log with index verification
kafka-dump-log.sh --files <segment-file>.log --deep-iteration --verify-index-only
```

---

## 4. Log Compaction Issues

### Common Problems

| Issue | Symptoms | Resolution |
|-------|----------|------------|
| **Compaction not running** | Dirty ratio growing, old keys not removed | Check `log.cleaner.enable=true` (broker); verify `cleanup.policy=compact` on topic |
| **Compaction falling behind** | High `max-compaction-delay-secs` metric; dirty ratio consistently above threshold | Increase `log.cleaner.threads` (default 1); increase `log.cleaner.dedupe.buffer.size` |
| **OOM during compaction** | Broker OOM errors during log cleaning | Reduce `log.cleaner.dedupe.buffer.size`; increase broker heap (carefully) |
| **Tombstones not cleaned** | Deleted keys (null value) still visible | Wait for `delete.retention.ms` (default 24h) to expire; check `min.compaction.lag.ms` |
| **Unexpected data loss** | Records disappear sooner than expected | Check `min.cleanable.dirty.ratio`, `min.compaction.lag.ms`, `max.compaction.lag.ms` |
| **Log cleaner disabled** | Compaction thread crashed and was disabled | Check broker logs for `Log cleaner thread exited`; restart broker; fix underlying cause |

### Key Compaction Configurations

```properties
# Broker-level
log.cleaner.enable=true                     # Enable log cleaner (default true)
log.cleaner.threads=2                       # Number of cleaner threads (default 1)
log.cleaner.dedupe.buffer.size=134217728    # Buffer for dedup (default 128 MB)
log.cleaner.io.buffer.size=524288           # I/O buffer (default 512 KB)
log.cleaner.io.max.bytes.per.second=1.7976931348623157E308  # Throttle (default unlimited)
log.cleaner.backoff.ms=15000                # Backoff if no logs to clean (default 15s)

# Topic-level
cleanup.policy=compact                      # Enable compaction
min.cleanable.dirty.ratio=0.5              # Min dirty ratio before compaction (default 0.5)
min.compaction.lag.ms=0                     # Min time before record eligible for compaction
max.compaction.lag.ms=9223372036854775807   # Max time before forced compaction (default Long.MAX)
delete.retention.ms=86400000               # Tombstone retention (default 24h)
segment.ms=604800000                       # Segment roll time (default 7 days)
```

### Diagnosing Compaction Issues

```bash
# Check log cleaner status in broker logs
# Look for: "Cleaner", "Log cleaning", "compaction" messages

# Verify topic cleanup policy
kafka-configs.sh --bootstrap-server <broker>:9092 \
  --entity-type topics --entity-name <topic> --describe

# Check log segment details
kafka-dump-log.sh --files /kafka-data/<topic>-<partition>/00000000000000000000.log \
  --print-data-log | head -20

# Monitor compaction metrics
# kafka.log:type=LogCleaner,name=max-compaction-delay-secs
# kafka.log:type=LogCleaner,name=max-dirty-percent
# kafka.log:type=LogCleaner,name=cleaner-recopy-percent
```

---

## 5. Partition Reassignment and Balancing

### When to Reassign

| Scenario | Approach |
|----------|----------|
| **New broker added** | Reassign partitions to include new broker for load distribution |
| **Broker decommissioning** | Move all partitions off the broker before shutdown |
| **Hot partition** | Move high-throughput partition to a less-loaded broker |
| **Rack awareness** | Redistribute replicas across racks for fault tolerance |
| **Disk balancing** | Move partitions between log directories on the same broker |

### Reassignment Process

1. **Generate a plan**: Use `kafka-reassign-partitions.sh --generate` or create manually
2. **Review the plan**: Verify the proposed moves make sense
3. **Execute with throttle**: ALWAYS throttle to limit impact on production traffic
4. **Monitor progress**: Use `--verify` to check completion
5. **Remove throttle**: After completion, verify throttle is removed

### Best Practices

- **Always throttle reassignment** (`--throttle`): Start at 50 MB/s, increase if cluster can handle it
- **Reassign during low-traffic periods** when possible
- **Move partitions in small batches** rather than all at once
- **Monitor under-replicated partitions** during reassignment -- they will temporarily increase
- **Verify completion** before starting the next batch
- **Use Cruise Control** (LinkedIn) for automated, intelligent rebalancing

### Automated Rebalancing Tools

| Tool | Description |
|------|-------------|
| **Cruise Control** (LinkedIn) | Automated cluster balancing, anomaly detection, self-healing |
| **kafka-reassign-partitions.sh** | Built-in manual reassignment tool |
| **Confluent Auto Data Balancer** | Commercial auto-balancing (Confluent Platform) |
| **Strimzi Cruise Control** | Cruise Control integration for Kubernetes-deployed Kafka |

---

## 6. Broker Failure and Recovery Scenarios

### Scenario 1: Single Broker Failure (Uncontrolled Shutdown)

**What Happens:**
1. Broker stops responding to heartbeats
2. Controller detects failure after `broker.session.timeout.ms` (KRaft, default 18s)
3. Controller elects new leaders for all partitions where failed broker was leader
4. ISR sets are updated to exclude the failed broker
5. Consumers/producers receive `NOT_LEADER` errors and refresh metadata
6. Clients automatically reconnect to new leaders

**Recovery:**
1. Investigate root cause (OOM, disk failure, OS crash)
2. Fix underlying issue
3. Restart broker -- it will:
   - Re-register with the controller
   - Begin fetching data for its assigned replicas
   - Rejoin ISR sets once caught up (within `replica.lag.time.max.ms`)
   - Become preferred leader again (if `auto.leader.rebalance.enable=true`, default)

### Scenario 2: Controlled (Graceful) Shutdown

**What Happens:**
1. Broker initiates graceful shutdown
2. Leadership is transferred to other ISR members BEFORE shutdown
3. Partitions are unavailable for only a few milliseconds during leader transfer
4. `controlled.shutdown.enable=true` (default) ensures this behavior

**Best Practice:** Always use graceful shutdown for maintenance.

### Scenario 3: Multiple Broker Failure

**Risk Assessment:**

| Replicas | Min ISR | Brokers Down | Outcome |
|----------|---------|-------------|---------|
| 3 | 2 | 1 | Fully operational, writes succeed |
| 3 | 2 | 2 | Writes FAIL (insufficient ISR); reads may work from remaining replica |
| 3 | 1 | 2 | Writes succeed to remaining replica (reduced durability) |
| 3 | 2 | 3 | Complete outage for affected partitions |

**Recovery Priority:**
1. Restore at least `min.insync.replicas` brokers to allow writes
2. Monitor `UnderReplicatedPartitions` as brokers recover
3. Once all brokers are back, verify ISR convergence
4. Consider temporarily lowering `min.insync.replicas` if writes are blocked (trade durability for availability)

### Scenario 4: Controller Failure (KRaft)

**What Happens (KRaft quorum):**
1. Active controller fails
2. Remaining controller quorum members detect failure
3. New active controller elected via Raft consensus (typically < 10 seconds)
4. Brokers reconnect to new active controller
5. No impact on produce/consume operations during controller election (brokers cache metadata)

**Key Point:** With a 3-node controller quorum, the cluster tolerates 1 controller failure. With 5 nodes, it tolerates 2.

### Scenario 5: Disk Failure on Broker

**What Happens:**
- If broker has multiple log directories and only one disk fails:
  - Partitions on the failed disk go offline
  - Partitions on other disks continue operating
  - Broker marks the failed directory as offline
- If all disks fail, same as full broker failure

**Resolution:**
1. Replace failed disk
2. If JBOD (multiple log dirs): broker continues with remaining disks; reassign partitions from failed disk
3. If single disk: treat as broker failure; restart after disk replacement
4. Replicas on other brokers are elected as leaders

### Recovery Monitoring Checklist

```
[ ] All brokers registered with controller
[ ] UnderReplicatedPartitions = 0
[ ] OfflinePartitionsCount = 0
[ ] All ISR sets at full replica count
[ ] Consumer lag returning to normal levels
[ ] No ongoing partition reassignments
[ ] Preferred leader election complete (if auto.leader.rebalance.enable=true)
```

---

## Sources

- [Confluent - Kafka Issues in Production](https://www.confluent.io/learn/kafka-issues-production/)
- [Confluent - Debug Kafka Consumer Rebalance](https://www.confluent.io/blog/debug-apache-kafka-pt-3/)
- [Redpanda - Kafka Lag](https://www.redpanda.com/guides/kafka-performance-kafka-lag)
- [Redpanda - Kafka Consumer Lag](https://www.redpanda.com/guides/kafka-performance-kafka-consumer-lag)
- [meshIQ - Common Kafka Performance Issues](https://www.meshiq.com/blog/common-kafka-performance-issues-and-how-to-fix-them/)
- [meshIQ - Advanced Kafka Performance Tuning](https://www.meshiq.com/blog/advanced-kafka-performance-tuning-for-large-clusters/)
- [Instaclustr - Kafka Performance Best Practices 2026](https://www.instaclustr.com/education/apache-kafka/kafka-performance-7-critical-best-practices-in-2026/)
- [Michal Drozd - Kafka Rebalance Storms](https://www.michal-drozd.com/en/blog/kafka-consumer-rebalance-storm/)
- [NashTech - Common Kafka Rebalancing Problems](https://blog.nashtechglobal.com/apache-kafka-rebalancing-series-common-kafka-rebalancing-problems-and-debugging/)
- [Confluent - Manage Consumer Groups](https://docs.confluent.io/kafka/operations-tools/manage-consumer-groups.html)
- [Confluent - Log Compaction](https://docs.confluent.io/kafka/design/log_compaction.html)
- [Strimzi - Partition Reassignment](https://strimzi.io/blog/2022/09/16/reassign-partitions/)
- [Netdata - Kafka Consumer Lag](https://www.netdata.cloud/academy/apache-kafka-consumer-lags/)
- [AutoMQ - Kafka Performance Tuning](https://www.automq.com/blog/apache-kafka-performance-tuning-tips-best-practices)
- [Apache Kafka - Topic Configs (4.2)](https://kafka.apache.org/42/configuration/topic-configs/)
