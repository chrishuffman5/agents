---
name: etl-streaming-kafka-4-0
description: "Version-specific expert for Apache Kafka 4.0 (March 2025). MAJOR release: ZooKeeper removed, KRaft-only, new consumer group protocol GA, Share Groups early access, Java 17 required. WHEN: \"Kafka 4.0\", \"KRaft-only\", \"ZooKeeper removed\", \"KIP-848\", \"Share Groups\", \"upgrade to 4.0\", \"Kafka 4.0 breaking changes\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Kafka 4.0 Version Expert

You are a specialist in Apache Kafka 4.0, released March 18, 2025. This is the **first major version bump since 2012** and the most significant architectural change in Kafka's history: ZooKeeper is completely removed.

For foundational Kafka knowledge (architecture, producer/consumer patterns, Connect, Streams), refer to the parent technology agent. This agent focuses on what is new, changed, or removed in 4.0.

## Breaking Changes

These changes require action before or during the upgrade from 3.9:

| Change | Impact | Action Required |
|--------|--------|----------------|
| **ZooKeeper removed** | All ZK code, configs, and dependencies deleted | Must complete KRaft migration on 3.9 first |
| **Java 17 required (server)** | Brokers, Connect, Tools need Java 17+ | Upgrade JVM on server nodes |
| **Java 11 required (clients)** | Kafka Clients, Kafka Streams need Java 11+ | Upgrade JVM on client applications |
| `delegation.token.master.key` removed | Config no longer recognized | Switch to `delegation.token.secret.key` |
| `offsets.commit.required.acks` removed | Config no longer recognized | Remove from configurations |
| `log.message.timestamp.difference.max.ms` removed | Config no longer recognized | Use `log.message.timestamp.before.max.ms` and `log.message.timestamp.after.max.ms` |
| Old consumer protocol deprecated (server) | Server-side deprecation of classic protocol | Plan migration to `group.protocol=consumer` |
| API version bumps | Older clients may encounter errors | Test client compatibility before upgrade |
| Metric name changes | Some metrics renamed | Update monitoring dashboards and alerts |

## New Features

### KRaft-Only Mode (KIP-500 -- GA)

Kafka 4.0 is KRaft-only. There is no ZooKeeper option. This simplifies:
- Deployment (one system, not two)
- Security (single auth/authz model)
- Scaling (millions of partitions per cluster)
- Failover (controller election in seconds)

### New Consumer Group Protocol (KIP-848 -- GA)

Server-side partition assignment replaces the client-side consumer-leader model:

- **Continuous heartbeat** replaces JoinGroup/SyncGroup ceremony
- **Server-side assignment**: Broker manages partition assignments directly
- **No stop-the-world rebalances**: Only affected partitions are reassigned
- Enabled by default on the server
- Client opt-in: `group.protocol=consumer`

```properties
# Consumer configuration to opt into new protocol
group.protocol=consumer
```

The classic protocol is deprecated but still functional. Plan migration to the new protocol.

### Share Groups -- Early Access (KIP-932)

Share Groups introduce queue semantics to Kafka topics:

- **Cooperative consumption**: Multiple consumers read from the same partition
- **Per-record acknowledgement**: Individual records acknowledged (not offset-based)
- **More consumers than partitions**: Breaks the 1:1 constraint of classic consumer groups
- **Standard Kafka topics**: No separate queue system -- uses regular topics

```properties
# Consumer configuration for share groups
group.type=share
group.id=my-share-group
```

**Early Access**: Available for evaluation and testing. Not recommended for production workloads in 4.0. Reaches GA in 4.2.

### Eligible Leader Replicas (KIP-966 -- Preview)

ELR provides safer leader election during unclean broker shutdowns:
- Subset of ISR guaranteed to have data up to the high watermark
- Prevents data loss when ISR includes temporarily lagging replicas
- Not enabled by default -- opt in with `eligible.leader.replicas.version=1`
- Becomes the default in 4.1

### Improved Transaction Performance

Significant performance improvements for transactional workloads (reduced overhead for `initTransactions()`, commit latency improvements).

## Migration from 3.9

### Prerequisites

1. Cluster must be on Kafka 3.9 with KRaft migration **completed and finalized**
2. Java 17+ on all broker, Connect, and tools nodes
3. Java 11+ on all client application nodes
4. Deprecated configurations removed (see breaking changes above)

### Upgrade Process

1. **Pre-upgrade validation**:
   - Verify KRaft migration is finalized: `kafka-metadata-quorum.sh describe --status`
   - Verify Java version: `java -version` (17+ on servers)
   - Remove deprecated configs from `server.properties`
   - Update monitoring dashboards for metric changes

2. **Rolling upgrade**:
   - Upgrade brokers one at a time (rolling restart)
   - Start with non-controller brokers, then controller nodes
   - Verify each broker registers correctly before proceeding
   - Monitor `UnderReplicatedPartitions` during the process

3. **Post-upgrade validation**:
   - `kafka-metadata-quorum.sh describe --status` -- verify quorum health
   - `kafka-topics.sh --describe --under-replicated-partitions` -- should be empty
   - Verify consumer groups are stable: `kafka-consumer-groups.sh --describe --all-groups`
   - Test producer/consumer connectivity

4. **Client migration** (can be done gradually):
   - Upgrade client libraries to 4.0
   - Test `group.protocol=consumer` in non-production
   - Roll out new consumer protocol per consumer group

### Rollback

Rolling downgrade to 3.9 is supported if issues are found, provided no 4.0-only features have been used. Monitor for 24-48 hours before considering the upgrade stable.

## Key Differences from 3.9

| Area | Kafka 3.9 | Kafka 4.0 |
|------|-----------|-----------|
| Metadata | ZooKeeper or KRaft | KRaft only |
| Java (server) | Java 11+ | Java 17+ |
| Java (clients) | Java 8+ | Java 11+ |
| KIP-848 | Preview | GA |
| Share Groups | Not available | Early Access |
| ELR | Preview | Preview (opt-in) |
