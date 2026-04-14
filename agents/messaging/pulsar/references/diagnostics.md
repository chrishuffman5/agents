# Apache Pulsar Diagnostics Reference

## Backlog Growth

### Symptoms
- `msgBacklog` increasing in topic stats
- Producer experiencing `ProducerBlockedQuotaExceeded` errors
- Consumer lag growing

### Diagnosis
```bash
# Check topic backlog
bin/pulsar-admin topics stats persistent://acme/payments/txns --get-precise-backlog

# Check per-subscription backlog
bin/pulsar-admin topics partitioned-stats persistent://acme/payments/txns --per-partition

# Check namespace backlog quotas
bin/pulsar-admin namespaces get-backlog-quotas acme/payments
```

### Resolution
| Cause | Resolution |
|---|---|
| No consumers | Deploy consumer; create subscription |
| Slow consumers | Add consumers (Shared); optimize processing |
| Consumer disconnected | Reconnect; check client logs |
| Key_Shared rebalancing | Wait for stabilization; check for consumer churn |
| Backlog quota policy blocking producer | Clear backlog or increase quota |

### Clear Backlog
```bash
# Skip all messages for a subscription
bin/pulsar-admin topics skip-all --subscription processor persistent://acme/payments/txns

# Skip N messages
bin/pulsar-admin topics skip --subscription processor --count 1000 persistent://acme/payments/txns

# Reset cursor to earliest/latest
bin/pulsar-admin topics reset-cursor --subscription processor --messageId earliest persistent://acme/payments/txns
```

## BookKeeper Issues

### Bookie Disk Full
**Symptoms:** Write failures, producer timeouts, `NoWritableEntryLogException`.

**Resolution:**
1. Check disk usage on bookie nodes
2. Run garbage collection: trigger compaction on bookies
3. Configure tiered storage to offload old data
4. Add more bookie nodes or disk capacity

### Journal Latency Spikes
**Symptoms:** High publish latency, `BookKeeperException.OperationRejectedException`.

**Diagnosis:** Check bookie journal latency metrics. Verify journal disk is SSD/NVMe and not shared with entry logs.

**Resolution:**
- Separate journal and entry log disks
- Upgrade to faster storage (NVMe)
- Reduce `journalFlushWhenQueueEmpty` threshold

### Bookie Node Failure
**Symptoms:** Under-replicated ledgers, auto-recovery triggered.

**Recovery:**
1. BookKeeper auto-recovery replicates under-replicated ledgers to remaining bookies
2. Monitor auto-recovery progress: `bin/bookkeeper shell listunderreplicated`
3. If auto-recovery is slow, manually trigger: `bin/bookkeeper shell recover <bookie-id>`
4. Add replacement bookie node

## Broker Failures

### Topic Ownership Transfer
When a broker fails, topics are reassigned to other brokers. Stateless brokers resume from BookKeeper cursor position. Clients reconnect automatically.

### Broker Overload
```bash
# Check broker load
bin/pulsar-admin brokers list

# Unload topic from broker (force reassignment)
bin/pulsar-admin topics unload persistent://acme/payments/txns
```

**Symptoms:** High CPU, request timeouts, slow dispatch.

**Resolution:**
- Unload busy topics to other brokers
- Add broker nodes
- Use partitioned topics to distribute load
- Configure load balancer thresholds

## Consumer Lag

### Diagnosis
```bash
# Check subscription stats
bin/pulsar-admin topics stats persistent://acme/payments/txns
# Look for: msgBacklog, msgRateOut, unackedMessages per subscription
```

### Resolution by Subscription Type
| Type | Resolution |
|---|---|
| Exclusive | Processing too slow; optimize or use partitioned topic + Failover |
| Shared | Add more consumer instances; increase receive queue size |
| Failover | Active consumer overloaded; check failover standby health |
| Key_Shared | Hot key; redistribute keys; check for batching issues |

## Compaction Issues

### Compaction Not Running
```bash
bin/pulsar-admin topics compaction-status persistent://acme/config/flags
```

**Cause:** `brokerServiceCompactionThreshold` not set or compaction backlog below threshold.

**Resolution:** Trigger manually or lower threshold:
```bash
bin/pulsar-admin topics compact persistent://acme/config/flags
```

## Geo-Replication Lag

### Monitor
```bash
bin/pulsar-admin topics stats persistent://acme/payments/txns
# Check "replication" section: replicationBacklog, connected, msgRateIn/Out per cluster
```

### Common Causes
| Cause | Resolution |
|---|---|
| Network latency between clusters | Expected lag; monitor SLA compliance |
| Replication connection lost | Check `connected: false` in stats; verify network |
| Producer rate exceeds replication bandwidth | Increase network capacity; reduce producer rate |
| Remote cluster unavailable | Check remote cluster health; messages buffer locally |

## CLI Reference (pulsar-admin)

### Tenants
```bash
bin/pulsar-admin tenants list
bin/pulsar-admin tenants create acme --admin-roles admin --allowed-clusters us-west,us-east
bin/pulsar-admin tenants get acme
```

### Namespaces
```bash
bin/pulsar-admin namespaces list acme
bin/pulsar-admin namespaces create acme/payments
bin/pulsar-admin namespaces policies acme/payments
bin/pulsar-admin namespaces set-retention acme/payments --size 100M --time 10080m
bin/pulsar-admin namespaces set-message-ttl --messageTTL 3600 acme/payments
bin/pulsar-admin namespaces set-backlog-quota --limit 10G --policy producer_request_hold acme/payments
bin/pulsar-admin namespaces clear-backlog --sub processor acme/payments
```

### Topics
```bash
bin/pulsar-admin topics list acme/payments
bin/pulsar-admin topics create persistent://acme/payments/txns
bin/pulsar-admin topics create-partitioned-topic persistent://acme/payments/txns --partitions 8
bin/pulsar-admin topics stats persistent://acme/payments/txns
bin/pulsar-admin topics stats-internal persistent://acme/payments/txns
bin/pulsar-admin topics unload persistent://acme/payments/txns
bin/pulsar-admin topics delete persistent://acme/payments/txns
```

### Subscriptions
```bash
bin/pulsar-admin topics subscriptions persistent://acme/payments/txns
bin/pulsar-admin topics create-subscription --subscription proc persistent://acme/payments/txns
bin/pulsar-admin topics skip-all --subscription proc persistent://acme/payments/txns
bin/pulsar-admin topics reset-cursor --subscription proc --messageId earliest persistent://acme/payments/txns
bin/pulsar-admin topics peek-messages --subscription proc --count 5 persistent://acme/payments/txns
bin/pulsar-admin topics unsubscribe --subscription proc persistent://acme/payments/txns
```

### Functions
```bash
bin/pulsar-admin functions create --function-config-file config.yaml --jar target/func.jar
bin/pulsar-admin functions status --tenant acme --namespace payments --name enricher
bin/pulsar-admin functions get --tenant acme --namespace payments --name enricher
bin/pulsar-admin functions delete --tenant acme --namespace payments --name enricher
```

### Connectors
```bash
bin/pulsar-admin sinks create --archive connector.nar --inputs persistent://acme/payments/txns \
  --name cassandra-sink --sink-config-file config.yaml
bin/pulsar-admin sinks status --name cassandra-sink
bin/pulsar-admin sources create --archive source.nar --name mysql-cdc \
  --destination-topic-name persistent://acme/cdc/orders --source-config-file config.yaml
```

### Schema
```bash
bin/pulsar-admin schemas get persistent://acme/payments/txns
bin/pulsar-admin schemas upload persistent://acme/payments/txns --filename schema.json
bin/pulsar-admin schemas delete persistent://acme/payments/txns
```

## Health Check Sequence

1. Broker health: `bin/pulsar-admin brokers list` -- all expected brokers present
2. Topic ownership: `bin/pulsar-admin topics stats <topic>` -- has assigned broker
3. BookKeeper health: `bin/bookkeeper shell listbookies -rw` -- all bookies writable
4. Under-replication: `bin/bookkeeper shell listunderreplicated` -- should be empty
5. Consumer lag: check `msgBacklog` in topic stats -- not growing
6. Geo-replication: check `replicationBacklog` and `connected` -- connected and low lag
