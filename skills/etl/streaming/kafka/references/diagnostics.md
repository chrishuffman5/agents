# Apache Kafka Diagnostics Reference

## Consumer Lag

### Symptoms

- Growing gap between log-end-offset and consumer committed offset
- `records-lag-max` metric increasing over time
- `kafka-consumer-groups.sh --describe` shows increasing LAG column

### Root Causes and Resolution

| Cause | Diagnosis | Resolution |
|-------|-----------|------------|
| Slow processing | Processing time per record exceeds throughput rate | Optimize processing logic; increase `max.poll.records`; add consumers (up to partition count) |
| Downstream dependency | External service (DB, API) slow or unavailable | Add circuit breakers; batch writes to external systems; use async processing |
| Insufficient consumers | Fewer consumers than partitions | Scale consumer instances up to partition count |
| Deserialization overhead | Complex schemas or large records | Optimize schema; use Avro/Protobuf over JSON |
| GC pauses | Consumer JVM GC > `max.poll.interval.ms` | Tune JVM heap and GC; reduce `max.poll.records` |
| Network throttling | Broker-side quota limiting fetch rate | Check quotas; increase or exempt consumer |
| Partition skew | Some partitions have much more data | Review key distribution; consider custom partitioner |

### Diagnostic Commands

```bash
# Check consumer group lag
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --describe --group <group-id>

# Check lag for all groups
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --describe --all-groups

# Check consumer group state (Stable, Rebalancing, Empty, Dead)
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --describe --group <group-id> --state

# Show group members and assigned partitions
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --describe --group <group-id> --members --verbose
```

## Rebalancing Storms

### Symptoms

- Frequent, cascading rebalances preventing stabilization
- Consumer group state oscillating between `Rebalancing` and `Stable`
- High `sync-rate` metric
- Throughput drops to zero during rebalances
- Log messages: "Revoking partition assignments", "Attempting to join group"

### Root Causes and Resolution

| Cause | Diagnosis | Resolution |
|-------|-----------|------------|
| Processing exceeds `max.poll.interval.ms` | Consumer too slow between `poll()` calls | Increase `max.poll.interval.ms`; reduce `max.poll.records`; optimize processing |
| Session timeout too low | `session.timeout.ms` < GC pause or network hiccup | Increase to 30-45 seconds |
| Consumer crash loop | Application exception, restart, rebalance | Fix bugs; add error handling |
| Rolling deployments | Sequential restarts trigger chain rebalances | Use static group membership; use cooperative rebalancing |
| Too many consumers joining simultaneously | Large group scaling up at once | Stagger consumer startup; use static membership |
| Network instability | Heartbeats lost, coordinator marks consumer dead | Fix network; increase `session.timeout.ms` |

### Resolution Strategies

1. **Switch to cooperative rebalancing**: `partition.assignment.strategy=org.apache.kafka.clients.consumer.CooperativeStickyAssignor`
2. **Use static group membership**: Set `group.instance.id=<stable-id>` (e.g., K8s pod name)
3. **Upgrade to KIP-848 protocol** (Kafka 4.0+): `group.protocol=consumer` -- server-side assignment eliminates most rebalance issues
4. **Tune timeouts**: Increase `session.timeout.ms` and `max.poll.interval.ms` appropriately

## Under-Replicated Partitions

### Symptoms

- `UnderReplicatedPartitions` metric > 0
- `IsrShrinksPerSec` increasing without corresponding `IsrExpandsPerSec`
- `kafka-topics.sh --describe` shows ISR set smaller than replica set

### Root Causes and Resolution

| Cause | Diagnosis | Resolution |
|-------|-----------|------------|
| Broker overloaded | High CPU, memory, or disk I/O on follower | Rebalance partitions; add brokers; reduce partition count |
| Network issues | Packet loss or high latency between brokers | Check network; move brokers closer; check NICs |
| Disk I/O saturation | Follower can't write fast enough | Use SSDs; spread log dirs across disks |
| Broker down | Follower crashed or unresponsive | Restart broker; check for OOM or disk full |
| GC pauses | Long JVM pauses on follower | Tune GC; right-size heap; use G1GC or ZGC |
| Large messages | Single large record blocking replication | Increase `replica.fetch.max.bytes`; chunk large records |
| `replica.lag.time.max.ms` too low | Followers removed from ISR too aggressively | Increase (default 30s is usually fine) |

### Diagnostic Commands

```bash
# Show under-replicated partitions across all topics
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --describe --under-replicated-partitions

# Show partitions with no leader
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --describe --unavailable-partitions

# Describe specific topic (partitions, replicas, ISR, leader)
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --describe --topic <topic-name>
```

## Performance Bottlenecks

### Network Saturation

**Indicators:**
- `BytesInPerSec`/`BytesOutPerSec` approaching NIC capacity
- `NetworkProcessorAvgIdlePercent` < 30%
- High `request-latency-avg`; increasing `RequestQueueSize`

**Resolution:**
- Enable compression (`lz4` or `zstd`)
- Increase `num.network.threads` (default 3)
- Distribute load across more brokers
- Use dedicated NICs for replication vs client traffic
- Consider rack-aware replica placement

### Disk I/O Saturation

**Indicators:**
- `LogFlushRateAndTimeMs` P99 > 100ms
- `RequestHandlerAvgIdlePercent` < 30%
- High `iowait` at OS level

**Resolution:**
- Upgrade to SSDs (NVMe preferred)
- Multiple log directories across separate disks (`log.dirs=/disk1/kafka,/disk2/kafka`)
- Separate OS disk from Kafka data disk
- Ensure sufficient free memory for OS page cache (Kafka relies heavily on it)
- Enable tiered storage (3.9+) for cold data offloading

### GC Pauses

**Indicators:**
- JVM GC logs showing pauses > 200ms
- Intermittent request latency spikes
- Followers falling out of ISR periodically
- Consumer rebalances from missed heartbeats

**Resolution:**
- Use G1GC (default) with tuning:
  ```
  -XX:+UseG1GC -XX:MaxGCPauseMillis=20
  -XX:InitiatingHeapOccupancyPercent=35 -XX:G1HeapRegionSize=16M
  ```
- Consider ZGC (Java 17+) for ultra-low-pause:
  ```
  -XX:+UseZGC
  ```
- Right-size heap: 6-8 GB typical; too large = long pauses, too small = frequent GC
- Leave memory for page cache: ~60-70% RAM for page cache, ~30-40% for JVM heap

## CLI Tools Reference

### kafka-consumer-groups.sh

```bash
# List all consumer groups
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 --list

# Describe group (partitions, offsets, lag, consumer IDs)
kafka-consumer-groups.sh --bootstrap-server <broker>:9092 \
  --describe --group <group-id>

# Reset offsets to earliest (DRY RUN first)
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

# Describe a topic
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --describe --topic <topic-name>

# Create a topic
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --create --topic <topic-name> \
  --partitions 12 --replication-factor 3

# Increase partition count (cannot decrease)
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --alter --topic <topic-name> --partitions 24

# Delete a topic
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --delete --topic <topic-name>
```

### kafka-configs.sh

```bash
# Describe topic configuration overrides
kafka-configs.sh --bootstrap-server <broker>:9092 \
  --entity-type topics --entity-name <topic-name> --describe

# Set topic configuration
kafka-configs.sh --bootstrap-server <broker>:9092 \
  --entity-type topics --entity-name <topic-name> \
  --alter --add-config retention.ms=86400000

# Delete topic config override (revert to broker default)
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
# Describe KRaft quorum status
kafka-metadata-quorum.sh --bootstrap-controller <controller>:9093 \
  describe --status

# Show metadata replication status
kafka-metadata-quorum.sh --bootstrap-controller <controller>:9093 \
  describe --replication
```

### kafka-reassign-partitions.sh

```bash
# Generate reassignment plan
kafka-reassign-partitions.sh --bootstrap-server <broker>:9092 \
  --topics-to-move-json-file topics.json \
  --broker-list "1,2,3,4" --generate

# Execute with throttle (ALWAYS throttle in production)
kafka-reassign-partitions.sh --bootstrap-server <broker>:9092 \
  --reassignment-json-file plan.json --execute \
  --throttle 50000000  # 50 MB/s

# Verify progress
kafka-reassign-partitions.sh --bootstrap-server <broker>:9092 \
  --reassignment-json-file plan.json --verify
```

### Console Tools

```bash
# Produce test messages
kafka-console-producer.sh --bootstrap-server <broker>:9092 \
  --topic <topic-name>

# Consume from beginning
kafka-console-consumer.sh --bootstrap-server <broker>:9092 \
  --topic <topic-name> --from-beginning

# Consume with key display
kafka-console-consumer.sh --bootstrap-server <broker>:9092 \
  --topic <topic-name> --from-beginning \
  --property print.key=true --property key.separator=:

# Dump log segment
kafka-dump-log.sh --files <segment-file>.log --print-data-log
```

## Log Compaction Issues

### Common Problems

| Issue | Symptoms | Resolution |
|-------|----------|------------|
| Compaction not running | Dirty ratio growing, old keys not removed | Check `log.cleaner.enable=true`; verify `cleanup.policy=compact` on topic |
| Compaction falling behind | High `max-compaction-delay-secs`; dirty ratio above threshold | Increase `log.cleaner.threads` (default 1); increase `log.cleaner.dedupe.buffer.size` |
| OOM during compaction | Broker OOM during log cleaning | Reduce `log.cleaner.dedupe.buffer.size`; carefully increase heap |
| Tombstones not cleaned | Deleted keys still visible | Wait for `delete.retention.ms` (default 24h); check `min.compaction.lag.ms` |
| Log cleaner disabled | Compaction thread crashed | Check logs for `Log cleaner thread exited`; restart broker |

### Key Compaction Configurations

```properties
# Broker-level
log.cleaner.enable=true
log.cleaner.threads=2                    # Default 1; increase for more compaction throughput
log.cleaner.dedupe.buffer.size=134217728 # 128 MB default

# Topic-level
cleanup.policy=compact
min.cleanable.dirty.ratio=0.5
min.compaction.lag.ms=0
max.compaction.lag.ms=9223372036854775807
delete.retention.ms=86400000             # 24h tombstone retention
```

## Partition Reassignment

### When to Reassign

| Scenario | Approach |
|----------|----------|
| New broker added | Reassign partitions to include new broker |
| Broker decommissioning | Move all partitions off before shutdown |
| Hot partition | Move high-throughput partition to less-loaded broker |
| Rack awareness | Redistribute replicas across racks |
| Disk balancing | Move partitions between log directories on same broker |

### Best Practices

- ALWAYS throttle reassignment (`--throttle`): start at 50 MB/s
- Reassign during low-traffic periods when possible
- Move partitions in small batches
- Monitor `UnderReplicatedPartitions` during reassignment (temporarily increases)
- Verify completion before starting next batch
- Use Cruise Control for automated, intelligent rebalancing

## Broker Failure and Recovery

### Single Broker Failure (Uncontrolled)

1. Controller detects failure after `broker.session.timeout.ms` (KRaft, default 18s)
2. Controller elects new leaders for affected partitions from ISR
3. ISR sets updated to exclude failed broker
4. Clients get `NOT_LEADER` errors, refresh metadata, reconnect automatically

**Recovery**: Fix root cause, restart broker. It re-registers, fetches replica data, rejoins ISR when caught up, becomes preferred leader again (if `auto.leader.rebalance.enable=true`).

### Controlled (Graceful) Shutdown

Leadership transferred BEFORE shutdown. Partitions unavailable for only milliseconds during transfer. Always use graceful shutdown for maintenance.

### Multiple Broker Failure

| Replicas | Min ISR | Brokers Down | Outcome |
|----------|---------|-------------|---------|
| 3 | 2 | 1 | Fully operational |
| 3 | 2 | 2 | Writes FAIL; reads may work |
| 3 | 1 | 2 | Writes succeed (reduced durability) |
| 3 | 2 | 3 | Complete outage |

**Priority**: Restore at least `min.insync.replicas` brokers. Monitor `UnderReplicatedPartitions`. Consider temporarily lowering `min.insync.replicas` if writes are blocked (trade durability for availability).

### Controller Failure (KRaft)

New active controller elected via Raft consensus (typically < 10 seconds). No impact on produce/consume during election (brokers cache metadata). 3-node quorum tolerates 1 failure; 5-node tolerates 2.

### Recovery Monitoring Checklist

```
[ ] All brokers registered with controller
[ ] UnderReplicatedPartitions = 0
[ ] OfflinePartitionsCount = 0
[ ] All ISR sets at full replica count
[ ] Consumer lag returning to normal
[ ] No ongoing partition reassignments
[ ] Preferred leader election complete
```
