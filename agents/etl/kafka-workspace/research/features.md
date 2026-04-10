# Apache Kafka Version Features

> Research date: 2026-04-09
> Covers: Kafka 3.9, 4.0, 4.1, 4.2 (current)

---

## 1. Kafka 3.9 (Released November 6, 2024)

**Last version supporting ZooKeeper. Bridge release for KRaft migration.**

### Key Features

| Feature | KIP | Details |
|---------|-----|---------|
| Dynamic KRaft Quorums | KIP-853 | Controller membership is now dynamic; add/remove controller nodes without cluster downtime via `kafka-metadata-quorum.sh` or AdminClient API |
| Tiered Storage GA | KIP-405 | Tiered storage is now production-ready; offload older log segments to remote storage (S3, GCS, Azure Blob) |
| ZK Migration Maturity | KIP-866 | Final and best iteration of ZK-to-KRaft migration; all remaining feature gaps closed, many bugs fixed |
| ELR Preview | KIP-966 | Eligible Leader Replicas preview -- safer leader election during unclean shutdowns |
| Consumer Group Protocol Preview | KIP-848 | Next-gen consumer rebalance protocol available as preview |

### ZooKeeper Deprecation Status
- ZooKeeper mode is **fully deprecated** but still functional
- This is the **mandatory stepping stone** for clusters migrating to Kafka 4.0+
- All clusters MUST migrate to KRaft on 3.9 before upgrading to 4.0

### Upgrade Notes
- KRaft mode is the recommended default for new clusters
- ZooKeeper migration tooling is mature and well-tested at this point
- Tiered storage configuration should be validated before production use

---

## 2. Kafka 4.0 (Released March 18, 2025)

**Major milestone: ZooKeeper REMOVED. KRaft-only. First major version bump since 2012.**

### Breaking Changes

| Change | Details |
|--------|---------|
| **ZooKeeper Removed** | All ZooKeeper code, configurations, and dependencies removed entirely. KRaft is the ONLY metadata management mode. |
| **Java 17 Required (Server)** | Brokers, Connect, and Tools now require Java 17 minimum |
| **Java 11 Required (Client)** | Kafka Clients and Kafka Streams require Java 11 minimum |
| **Configuration Removals** | `delegation.token.master.key` removed (use `delegation.token.secret.key`); `offsets.commit.required.acks` removed; `log.message.timestamp.difference.max.ms` removed (use `log.message.timestamp.before.max.ms` and `log.message.timestamp.after.max.ms`) |
| **Old Consumer Protocol** | Legacy consumer rebalance protocol deprecated on server side |
| **API Version Changes** | Various API version bumps; older clients may need updates |

### New Features

| Feature | KIP | Status | Details |
|---------|-----|--------|---------|
| **KRaft-Only Mode** | KIP-500 | GA | ZooKeeper completely removed; simplified architecture |
| **New Consumer Group Protocol** | KIP-848 | GA | Server-side partition assignment, continuous heartbeat, eliminates stop-the-world rebalances |
| **Share Groups (Queues for Kafka)** | KIP-932 | Early Access | Cooperative consumption without partition-consumer binding; enables queue semantics on Kafka topics |
| **Eligible Leader Replicas** | KIP-966 | Preview | Subset of ISR guaranteed to have data up to high-watermark; prevents data loss during unclean elections. Not enabled by default (set `eligible.leader.replicas.version=1`) |
| **Improved Transaction Performance** | Various | GA | Significant performance improvements for transactional workloads |
| **New Group Coordinator** | KIP-848 | GA | Broker-managed partition assignment replaces consumer-leader model |

### Share Groups Details (KIP-932)
- Introduces a new group type: `share`
- Multiple consumers can read from the same partition cooperatively
- Records are acknowledged individually (per-record, not per-offset)
- Enables queue-like consumption patterns on standard Kafka topics
- More consumers than partitions is now possible
- Not a separate "queue" -- uses regular Kafka topics

### Migration Requirement
- Clusters MUST be on KRaft mode (migrated on Kafka 3.9) before upgrading to 4.0
- No downgrade path from KRaft to ZooKeeper after migration
- Rolling upgrade from 3.9 KRaft to 4.0 is supported

---

## 3. Kafka 4.1 (Released September 4, 2025)

**Incremental improvements. Queues preview. Streams rebalance protocol. OAuth support.**

### Key Features

| Feature | KIP | Status | Details |
|---------|-----|--------|---------|
| **Share Groups (Queues)** | KIP-932 | Preview | Queues for Kafka now in preview; available for evaluation and testing, not production |
| **Streams Rebalance Protocol** | KIP-1071 | Early Access | New Kafka Streams rebalance protocol based on the new consumer group protocol (KIP-848) |
| **Transaction API Improvements** | KIP-1050 | GA | Updated error handling logic and documentation for all transaction APIs; simpler to build robust applications |
| **Consumer.close(CloseOptions)** | KIP-1092 | GA | New method to control whether a consumer explicitly leaves its group on shutdown; enables Streams to control rebalance triggers |
| **ELR Enabled by Default** | KIP-966 | GA (default) | Eligible Leader Replicas now enabled by default on new clusters |
| **OAuth Support** | Various | GA | Native OAuth/OIDC support for authentication |

### Improvements
- Better error messages for transactional producers
- Enhanced Streams shutdown behavior
- Improved KRaft controller performance
- Additional admin client capabilities

---

## 4. Kafka 4.2 (Released February 17, 2026) -- CURRENT

**Kafka Queues production-ready. Streams server-side rebalance GA. CLI standardization.**

### Key Features

| Feature | KIP | Status | Details |
|---------|-----|--------|---------|
| **Share Groups (Queues) GA** | KIP-932 | **Production-Ready** | Full production support with RENEW acknowledgement type, adaptive batching, soft/strict record quantity enforcement, comprehensive lag metrics |
| **Streams Rebalance Protocol** | KIP-1071 | GA (limited) | Server-side rebalance protocol for Streams is GA with a limited feature set |
| **Streams Dead Letter Queue** | Various | GA | DLQ support in Kafka Streams exception handlers; failed records routed to DLQ topic |
| **Anchored Wall-Clock Punctuation** | Various | GA | Deterministic scheduling for wall-clock punctuation in Streams |
| **CLI Standardization** | Various | GA | All CLI tools now use `--bootstrap-server` consistently; standardized argument naming |
| **Metric Naming Corrections** | Various | GA | Metrics follow `kafka.COMPONENT` convention consistently |
| **Idle Ratio Metrics** | Various | GA | New metrics for controller and MetadataLoader performance visibility |
| **Java 25 Support** | N/A | GA | Official support for Java 25 |
| **Streams Leave Group Control** | Various | GA | Full control over whether to send a leave group request on consumer close |

### Share Groups Production Features (4.2)
- **RENEW acknowledgement type**: Extended processing time for long-running consumers
- **Adaptive batching**: Share coordinators dynamically adjust batch sizes
- **Soft and strict enforcement**: Configurable limits on quantity of fetched records
- **Comprehensive lag metrics**: Full observability for share group consumption lag

---

## 5. Migration Path: ZooKeeper to KRaft

### Timeline

```
Kafka 2.8 (2021)  --> KRaft early access (dev/test only)
Kafka 3.3 (2022)  --> KRaft production-ready (new clusters)
Kafka 3.5 (2023)  --> KRaft GA; ZK migration tooling available
Kafka 3.9 (2024)  --> Last ZK version; migration tooling mature
Kafka 4.0 (2025)  --> ZooKeeper REMOVED; KRaft-only
Kafka 4.1 (2025)  --> KRaft improvements continue
Kafka 4.2 (2026)  --> Current release
```

### Migration Steps

**Phase 1: Preparation (on Kafka 3.9)**
1. Upgrade cluster to Kafka 3.9 (last ZK-supported version)
2. Document existing configuration: broker count, topics, partitions, custom settings
3. Back up ZooKeeper data and Kafka broker data
4. Plan controller node placement (odd number recommended: 3 or 5)

**Phase 2: Provision KRaft Controllers**
1. Deploy KRaft controller nodes (can be combined with broker role for small clusters)
2. Configure `controller.quorum.voters` on all nodes
3. Start KRaft controllers -- they form the metadata quorum
4. Generate a cluster ID: `kafka-storage.sh random-uuid`

**Phase 3: Broker Migration (Rolling)**
1. Configure brokers for dual-write mode (both ZK and KRaft)
2. Rolling restart brokers with migration configuration
3. Metadata is written to BOTH ZooKeeper and KRaft quorum during this phase
4. Verify metadata consistency between ZK and KRaft

**Phase 4: Finalize**
1. Verify all brokers are registered with the KRaft controller
2. Run `kafka-metadata.sh` to validate metadata completeness
3. Finalize migration (irreversible step) -- switches to KRaft-only
4. Decommission ZooKeeper nodes

### Critical Considerations
- **No Downgrade**: After finalizing, there is NO path back to ZooKeeper
- **Rollback Window**: Until the finalize step, rollback to ZK is possible
- **Resource Impact**: Dual-write mode increases CPU and memory usage temporarily
- **Version Lock**: Must migrate on 3.9 BEFORE upgrading to 4.0
- **Testing**: Validate in non-production first; migration tooling has been hardened through thousands of cluster migrations

---

## 6. Breaking Changes: 3.x to 4.0 Summary

| Category | Change | Action Required |
|----------|--------|----------------|
| **Metadata** | ZooKeeper removed | Must complete KRaft migration on 3.9 first |
| **Java** | Server requires Java 17+ | Upgrade JVM on brokers, Connect, tools |
| **Java** | Clients require Java 11+ | Upgrade JVM on client applications |
| **Config** | `delegation.token.master.key` removed | Switch to `delegation.token.secret.key` |
| **Config** | `offsets.commit.required.acks` removed | Remove from configurations |
| **Config** | `log.message.timestamp.difference.max.ms` removed | Use `before.max.ms` and `after.max.ms` variants |
| **Protocol** | Old consumer rebalance protocol deprecated server-side | Plan migration to new protocol (`group.protocol=consumer`) |
| **API** | Various API version bumps | Test client compatibility before upgrade |
| **Metrics** | Some metric names changed | Update monitoring dashboards and alerts |

---

## Sources

- [Apache Kafka 3.9.0 Release Announcement](https://kafka.apache.org/blog/2024/11/06/apache-kafka-3.9.0-release-announcement/)
- [Apache Kafka 4.0.0 Release Announcement](https://kafka.apache.org/blog/2025/03/18/apache-kafka-4.0.0-release-announcement/)
- [Apache Kafka 4.1.0 Release Announcement](https://kafka.apache.org/blog/2025/09/04/apache-kafka-4.1.0-release-announcement/)
- [Apache Kafka 4.2.0 Release Announcement](https://kafka.apache.org/blog/2026/02/17/apache-kafka-4.2.0-release-announcement/)
- [Confluent - Kafka 3.9 Release](https://www.confluent.io/blog/introducing-apache-kafka-3-9/)
- [Confluent - Kafka 4.0 Release](https://www.confluent.io/blog/latest-apache-kafka-release/)
- [Confluent - Kafka 4.1 Release](https://www.confluent.io/blog/introducing-apache-kafka-4-1/)
- [Confluent - Kafka 4.2 Release](https://www.confluent.io/blog/apache-kafka-4-2-release/)
- [Confluent - ZooKeeper to KRaft Migration](https://docs.confluent.io/platform/current/installation/migrate-zk-kraft.html)
- [Apache Kafka - Upgrading to 4.0](https://kafka.apache.org/40/getting-started/upgrade/)
- [Instaclustr - Kafka 4.0 Key Changes](https://www.instaclustr.com/blog/kafka-4-0-unveiled-key-changes-and-how-they-impact-developers/)
- [InfoQ - Kafka 4.0 KRaft Architecture](https://www.infoq.com/news/2025/04/kafka-4-kraft-architecture/)
- [Strimzi - KRaft Migration](https://strimzi.io/blog/2024/03/21/kraft-migration/)
