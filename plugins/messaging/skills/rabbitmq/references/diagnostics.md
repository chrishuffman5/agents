# RabbitMQ Diagnostics Reference

## Memory Alarms

### Symptoms
- Publishing connections blocked (reads suspended)
- Management UI shows memory alarm banner
- `rabbitmqctl list_connections` shows `blocked` or `blocking` state
- Log: `memory resource limit alarm set`

### Configuration
```ini
# rabbitmq.conf -- relative (fraction of total RAM)
vm_memory_high_watermark.relative = 0.6

# Absolute (recommended for containers)
vm_memory_high_watermark.absolute = 4Gi
```

### Diagnosis
```bash
rabbitmq-diagnostics memory_breakdown --unit megabytes
rabbitmq-diagnostics status
rabbitmqctl list_queues name messages memory --sort-by memory --limit 20
```

### Resolution
| Cause | Resolution |
|---|---|
| Large queue backlog | Add consumers; increase consumer prefetch; investigate slow consumers |
| Many small queues | Consolidate queues; use lazy mode behavior (CQv2 does this automatically) |
| Connection/channel leak | Identify leaking application; `rabbitmqctl list_connections` / `list_channels` |
| Erlang process overhead | Reduce connection count; check for runaway channels |

**Runtime adjustment:**
```bash
rabbitmqctl set_vm_memory_high_watermark 0.7
rabbitmqctl set_vm_memory_high_watermark absolute "6G"
```

## Disk Alarms

### Symptoms
- Same as memory alarm (publishing blocked cluster-wide)
- Log: `disk resource limit alarm set`

### Configuration
```ini
# Production: match RAM size or set absolute minimum
disk_free_limit.relative = 1.0
disk_free_limit.absolute = 4G
```

Default 50 MB is dangerously low for production.

### Diagnosis
```bash
rabbitmq-diagnostics check_local_alarms
rabbitmq-diagnostics status  # shows disk_free_limit and free_disk_space
```

### Resolution
- Increase disk space
- Purge unnecessary queues: `rabbitmqctl purge_queue -p /vhost queue-name`
- Reduce message retention (TTL, max-length)
- Enable tiered storage (streams) or offload to external storage

## Queue Buildup

### Symptoms
- `rabbitmq_detailed_queue_messages` metric growing
- Consumer lag increasing
- Memory alarm approaching

### Diagnostic Commands
```bash
# Top queues by message count
rabbitmqctl list_queues -p /vhost name messages consumers memory \
  --sort-by messages --limit 20

# Check consumer count per queue
rabbitmqctl list_queues name consumers messages_unacknowledged

# Check unresponsive queues
rabbitmq-diagnostics list_unresponsive_queues
```

### Root Causes and Resolution
| Cause | Resolution |
|---|---|
| No consumers | Deploy consumers; check application health |
| Slow consumers | Optimize processing; increase prefetch; add consumers |
| Consumer crash loop | Fix application bugs; check DLX for poison messages |
| Publisher outpacing consumers | Add consumers; implement backpressure; reduce publish rate |
| Unacked message buildup | Check `max.poll.interval.ms` equivalent; verify ack logic |

## Network Partitions

### Detection
```bash
rabbitmq-diagnostics cluster_status
# Look for "partitions" field in output
```
- Management UI: warning banner on overview page
- Log: `mnesia_event got {inconsistent_database, running_partitioned_network}`

### Recovery (Manual)
1. Identify trusted partition (most up-to-date state)
2. Stop all nodes NOT in trusted partition
3. Restart them -- they rejoin and adopt trusted state
4. Restart trusted partition nodes to clear warnings

### Prevention
- Use `pause_minority` for cross-rack/AZ deployments (3+ nodes)
- Never use `pause_minority` with 2-node clusters
- Use quorum queues (Raft handles partitions gracefully)
- Ensure reliable network between cluster nodes
- Set `cluster_partition_handling = pause_minority` in `rabbitmq.conf`

## Quorum Queue Issues

### Leader Election Failure
```bash
# Check quorum queue status
rabbitmq-queues check_if_node_is_quorum_critical
rabbitmqctl list_queues name type leader members online
```

**Cause:** Majority of replicas unavailable. **Resolution:** Restore quorum (majority of nodes online).

### High Memory Usage
Quorum queues store metadata in memory (~32 bytes per message). Large backlogs consume significant RAM.

```bash
# Check per-queue memory
rabbitmqctl list_queues name type messages memory --sort-by memory
```

**Resolution:** Consume backlog, set delivery limits, add consumers, increase memory allocation.

### Replica Management
```bash
# Add replica
rabbitmq-queues add_member -p /vhost queue-name rabbit@node

# Remove replica
rabbitmq-queues delete_member -p /vhost queue-name rabbit@node

# Rebalance leadership
rabbitmq-queues rebalance quorum

# Check if safe to stop node
rabbitmq-queues check_if_node_is_quorum_critical
```

## Connection and Channel Issues

### Connection Leaks
```bash
# List connections with details
rabbitmqctl list_connections name user state channels client_properties

# Close a specific connection
rabbitmqctl close_connection "<connection-name>" "cleaning up leak"
```

**Signs:** Connection count growing without corresponding consumer/producer count increase.

### Channel Leaks
```bash
rabbitmqctl list_channels name connection messages_unacknowledged consumer_count
```

**Signs:** Channel count growing on a single connection. Usually caused by not closing channels after use.

### Flow Control
When a connection is in flow control, the broker throttles its publish rate.

```bash
# Check for connections in flow state
rabbitmqctl list_connections name state send_pend
```

**Cause:** Publisher outpacing broker write capacity. **Resolution:** Reduce publish rate, increase broker capacity, use publisher confirms with backpressure.

## TLS Issues

### Certificate Expiration
```bash
rabbitmq-diagnostics check_certificate_expiration --unit weeks --within 4
```

### TLS Handshake Failure
Common causes:
- Mismatched TLS versions (server requires 1.2+, client sends 1.0)
- Expired certificates
- CA certificate not trusted
- Hostname mismatch in SAN/CN

**Debug:**
```bash
openssl s_client -connect localhost:5671 -CAfile ca.pem
```

## Khepri Migration Issues

### Migration Stuck
```bash
rabbitmq-diagnostics metadata_store_status
```

**If migration stalls:** Check that all nodes are online and reachable. Migration requires quorum. Brief pause is normal near the end.

**Irreversibility warning:** Once Khepri migration completes, you cannot revert to Mnesia. Always test in staging first.

## CLI Tool Reference

### rabbitmqctl
```bash
rabbitmqctl status                                    # Node status
rabbitmqctl cluster_status                            # Cluster health
rabbitmqctl list_queues name messages consumers       # Queue overview
rabbitmqctl list_exchanges name type durable          # Exchange listing
rabbitmqctl list_bindings                             # Binding listing
rabbitmqctl list_connections name user state channels  # Connection listing
rabbitmqctl list_channels name messages_unacknowledged # Channel listing
rabbitmqctl list_users                                # User listing
rabbitmqctl list_policies -p /vhost                   # Policy listing
rabbitmqctl export_definitions /tmp/defs.json         # Export topology
rabbitmqctl import_definitions /tmp/defs.json         # Import topology
rabbitmqctl enable_feature_flag all                   # Enable all stable flags
```

### rabbitmq-diagnostics
```bash
rabbitmq-diagnostics ping                             # Basic connectivity
rabbitmq-diagnostics check_running                    # Is broker running
rabbitmq-diagnostics check_local_alarms               # Memory/disk alarms
rabbitmq-diagnostics check_alarms                     # Cluster-wide alarms
rabbitmq-diagnostics check_port_connectivity          # Port checks
rabbitmq-diagnostics check_virtual_hosts              # Vhost health
rabbitmq-diagnostics memory_breakdown --unit megabytes # Memory analysis
rabbitmq-diagnostics list_unresponsive_queues         # Stuck queues
rabbitmq-diagnostics maybe_stuck                      # Erlang process stacks
rabbitmq-diagnostics observer                         # Top-like interface
rabbitmq-diagnostics log_tail                         # Stream logs
rabbitmq-diagnostics consume_event_stream             # Real-time events
rabbitmq-diagnostics metadata_store_status            # Khepri/Mnesia status
```

### rabbitmq-queues
```bash
rabbitmq-queues add_member -p /vhost queue rabbit@node
rabbitmq-queues delete_member -p /vhost queue rabbit@node
rabbitmq-queues grow rabbit@node all
rabbitmq-queues shrink rabbit@node
rabbitmq-queues rebalance quorum
rabbitmq-queues check_if_node_is_quorum_critical
```

### rabbitmq-streams
```bash
rabbitmq-streams add_replica -p /vhost stream rabbit@node
rabbitmq-streams delete_replica -p /vhost stream rabbit@node
rabbitmq-streams stream_status -p /vhost stream
rabbitmq-streams restart_stream -p /vhost stream
rabbitmq-streams add_super_stream name --partitions 3
rabbitmq-streams delete_super_stream name
```

### rabbitmqadmin v2 (4.1+)
```bash
pip install rabbitmqadmin
rabbitmqadmin list queues
rabbitmqadmin list exchanges
rabbitmqadmin declare queue name=my.queue durable=true arguments='{"x-queue-type":"quorum"}'
rabbitmqadmin declare exchange name=my.exchange type=direct durable=true
rabbitmqadmin declare binding source=my.exchange destination=my.queue routing_key=my.key
rabbitmqadmin publish exchange=my.exchange routing_key=my.key payload="test"
rabbitmqadmin get queue=my.queue count=5
rabbitmqadmin export /tmp/definitions.json
rabbitmqadmin import /tmp/definitions.json
```

## Health Check Sequence

Staged health check approach (from least to most expensive):

```bash
rabbitmq-diagnostics ping                              # 1. Node reachable
rabbitmq-diagnostics check_running                     # 2. Broker running
rabbitmq-diagnostics check_local_alarms                # 3. No local alarms
rabbitmq-diagnostics check_alarms                      # 4. No cluster alarms
rabbitmq-diagnostics check_port_connectivity           # 5. Ports accessible
rabbitmq-diagnostics check_virtual_hosts               # 6. Vhosts healthy
rabbitmq-diagnostics check_certificate_expiration \
  --unit weeks --within 4                              # 7. Certs valid
```
