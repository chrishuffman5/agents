# Apache Kafka Research Summary

> Research date: 2026-04-09
> Researcher: Claude Opus 4.6 (1M context)
> Scope: Kafka as a streaming data integration platform (versions 3.9-4.2)

---

## Key Findings

### 1. Kafka Has Undergone a Major Architectural Shift (High Confidence)

Kafka 4.0 (March 2025) removed ZooKeeper entirely, completing a multi-year transition to KRaft (Kafka Raft) for metadata management. This is the most significant architectural change in Kafka's history. Key implications:
- Simplified operations (one system instead of two)
- Better scalability (millions of partitions vs. ~200K with ZooKeeper)
- Faster controller failover (seconds instead of potentially minutes)
- All organizations on ZooKeeper-based Kafka MUST migrate through Kafka 3.9 before upgrading to 4.0+

### 2. Kafka Now Supports Queue Semantics (High Confidence)

Kafka 4.0 introduced Share Groups (KIP-932) as early access, which reached production-ready status in Kafka 4.2 (February 2026). Share groups enable:
- Queue-like cooperative consumption on standard Kafka topics
- More consumers than partitions (breaking the 1:1 constraint)
- Per-record acknowledgement instead of per-offset
- This directly challenges traditional message queues (RabbitMQ, ActiveMQ) on their home turf

### 3. Consumer Rebalancing Has Been Fundamentally Redesigned (High Confidence)

KIP-848 (GA in Kafka 4.0) moves partition assignment to the server side:
- Eliminates "stop-the-world" rebalances
- Continuous heartbeat mechanism replaces JoinGroup/SyncGroup ceremony
- Broker manages assignments directly, removing the consumer-leader concept
- Opt-in via `group.protocol=consumer` on the client

### 4. Exactly-Once Semantics Are Mature (High Confidence)

The three-component model (idempotent producer + transactional producer + read_committed consumer) is well-established and production-proven. Kafka Streams' `exactly_once_v2` (Kafka 2.5+) simplifies this for stream processing. EOS within Kafka is reliable; the challenge remains for Kafka-to-external-system patterns (which require outbox/dedup patterns).

### 5. Tiered Storage Is Production-Ready (High Confidence)

Tiered storage (KIP-405), production-ready since Kafka 3.9, enables offloading older log segments to object storage (S3, GCS, Azure Blob). This fundamentally changes Kafka's cost model for long-retention use cases.

### 6. Schema Registry Is Essential for Production Pipelines (High Confidence)

Schema Registry (Confluent, or compatible alternatives like Karapace/Apicurio) with BACKWARD compatibility mode is the standard approach for managing data contracts in Kafka. Avro remains the most mature format; Protobuf is gaining adoption.

---

## Version Summary

| Version | Release Date | Key Theme |
|---------|-------------|-----------|
| **Kafka 3.9** | Nov 2024 | Last ZooKeeper version; migration bridge; tiered storage GA |
| **Kafka 4.0** | Mar 2025 | ZooKeeper removed; KRaft-only; KIP-848 GA; Share Groups EA |
| **Kafka 4.1** | Sep 2025 | Share Groups preview; Streams rebalance; OAuth; ELR default |
| **Kafka 4.2** | Feb 2026 | Share Groups GA; Streams DLQ; CLI standardization; Java 25 |

---

## Confidence Levels

| Topic | Confidence | Notes |
|-------|-----------|-------|
| Core architecture (brokers, topics, partitions, replicas) | **High** | Well-documented, stable concepts |
| KRaft architecture and migration | **High** | Extensively documented by Apache and Confluent; thousands of migrations completed |
| Kafka 4.0 features and breaking changes | **High** | Official release announcement and documentation available |
| Kafka 4.1 features | **High** | Official release announcement available |
| Kafka 4.2 features | **High** | Official release announcement from February 2026 available |
| Producer/consumer internals and tuning | **High** | Well-documented; consistent across sources |
| Kafka Connect architecture | **High** | Stable, mature component with extensive documentation |
| Kafka Streams internals | **High** | Well-documented client library |
| Schema Registry compatibility modes | **High** | Confluent documentation is definitive |
| Exactly-once semantics | **High** | Formally verified (TLA+); production-proven at scale |
| Monitoring and JMX metrics | **High** | Multiple independent sources confirm same metrics |
| Security (SASL, TLS, ACLs) | **High** | Well-documented; standard patterns |
| Diagnostics and troubleshooting | **High** | Consistent guidance across Confluent, Red Hat, and community sources |
| MirrorMaker 2 patterns | **Medium-High** | Well-documented but real-world complexity varies by topology |
| Tiered storage details | **Medium** | Production-ready but relatively new; fewer production case studies |
| Share Groups (Queues) in practice | **Medium** | GA in 4.2 but adoption is still early; limited production experience reports |
| Kafka 4.2 specific improvements | **Medium** | Recent release; fewer third-party validation sources |

---

## Research Gaps

| Gap | Impact | Mitigation |
|-----|--------|------------|
| **Share Groups production patterns** | Medium | Feature is GA in 4.2 but real-world best practices are still emerging; revisit in 6 months |
| **Tiered storage performance characteristics** | Medium | Benchmarks for specific object storage backends (S3, GCS) under various workloads are limited |
| **KIP-848 protocol migration experience** | Low-Medium | Protocol is GA but migration from classic protocol at scale has limited case studies |
| **Kafka 4.2 stability reports** | Low | Release is ~2 months old; long-term stability data not yet available |
| **RBAC details (open-source)** | Low | RBAC is Confluent-specific; open-source Kafka only has ACLs |
| **Cluster Linking internals** | Low | Commercial Confluent feature; not relevant for open-source deployments |
| **Kafka Streams exactly_once_v2 performance overhead** | Low | General guidance available but workload-specific benchmarks vary |

---

## Research Files Produced

| File | Content |
|------|---------|
| `architecture.md` | Core architecture, producer/consumer internals, KRaft, Connect, Streams, Schema Registry, storage, EOS |
| `features.md` | Version features (3.9, 4.0, 4.1, 4.2), migration path, breaking changes |
| `best-practices.md` | Topic design, producer/consumer tuning, EOS patterns, schema evolution, Connect deployment, monitoring, security, multi-DC |
| `diagnostics.md` | Common issues, performance bottlenecks, CLI tools, log compaction, partition reassignment, broker failure/recovery |
| `research-summary.md` | This file -- key findings, confidence levels, gaps |

---

## Primary Sources

### Official Documentation
- [Apache Kafka Documentation (4.2)](https://kafka.apache.org/42/documentation/)
- [Apache Kafka Release Announcements](https://kafka.apache.org/blog/releases/)
- [Apache Kafka 4.0.0 Release](https://kafka.apache.org/blog/2025/03/18/apache-kafka-4.0.0-release-announcement/)
- [Apache Kafka 4.1.0 Release](https://kafka.apache.org/blog/2025/09/04/apache-kafka-4.1.0-release-announcement/)
- [Apache Kafka 4.2.0 Release](https://kafka.apache.org/blog/2026/02/17/apache-kafka-4.2.0-release-announcement/)
- [Confluent Documentation](https://docs.confluent.io/)

### Key KIPs Referenced
- [KIP-500: ZooKeeper Removal](https://cwiki.apache.org/confluence/display/KAFKA/KIP-500) -- KRaft foundation
- [KIP-848: Consumer Rebalance Protocol](https://cwiki.apache.org/confluence/display/KAFKA/KIP-848) -- Next-gen consumer protocol
- [KIP-932: Queues for Kafka](https://cwiki.apache.org/confluence/display/KAFKA/KIP-932) -- Share groups
- [KIP-966: Eligible Leader Replicas](https://cwiki.apache.org/confluence/display/KAFKA/KIP-966) -- Safer leader election
- [KIP-405: Tiered Storage](https://cwiki.apache.org/confluence/display/KAFKA/KIP-405) -- Remote storage
- [KIP-853: Dynamic KRaft Quorums](https://cwiki.apache.org/confluence/display/KAFKA/KIP-853) -- Controller membership changes
- [KIP-866: ZooKeeper to KRaft Migration](https://cwiki.apache.org/confluence/display/KAFKA/KIP-866) -- Migration tooling
- [KIP-833: Mark KRaft Production Ready](https://cwiki.apache.org/confluence/display/KAFKA/KIP-833) -- KRaft GA

### Vendor and Community Sources
- [Confluent Blog](https://www.confluent.io/blog/) -- Primary vendor, Kafka creator company
- [Strimzi Blog](https://strimzi.io/blog/) -- Kubernetes-native Kafka operator
- [Instaclustr Education](https://www.instaclustr.com/education/apache-kafka/) -- Managed Kafka provider
- [Conduktor Glossary](https://www.conduktor.io/glossary/) -- Kafka management tooling
- [Redpanda Guides](https://www.redpanda.com/guides/) -- Kafka-compatible alternative (useful for Kafka concept explanations)
- [Red Hat Streams Documentation](https://docs.redhat.com/en/documentation/red_hat_streams_for_apache_kafka/) -- Enterprise Kafka distribution
