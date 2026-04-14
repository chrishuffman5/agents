# NATS Diagnostics Reference

## Consumer Lag

### Symptoms
- `nats consumer info STREAM CONSUMER` shows growing `Num Pending`
- Processing throughput declining
- End-to-end latency increasing

### Diagnostic Commands
```bash
# Consumer info (pending, redelivered, ack floor)
nats consumer info ORDERS processor

# Stream info (total messages, bytes, consumer count)
nats stream info ORDERS

# Cluster-wide JetStream report
nats server report jetstream
```

### Root Causes and Resolution

| Cause | Diagnosis | Resolution |
|---|---|---|
| Slow processing | Processing time exceeds publish rate | Optimize processing; add pull consumer clients |
| MaxAckPending too low | Consumer bottlenecked at in-flight limit | Increase MaxAckPending |
| AckWait too short | Messages redelivered before processing completes | Increase AckWait; use AckProgress for long tasks |
| Network latency | High RTT between consumer and server | Deploy consumer closer to server; use leaf nodes |
| Redelivery storm | High NumRedelivered count | Check MaxDeliver; implement DLQ pattern |

## Stream Issues

### Stream Not Accepting Messages

```bash
nats stream info ORDERS  # check state, limits
```

| Cause | Resolution |
|---|---|
| DiscardNew with limits reached | Increase limits or switch to DiscardOld |
| Stream sealed | Unseal or create new stream |
| No JetStream meta-leader | Restore cluster quorum |
| Strict mode rejection (2.12) | Fix invalid API request; or set `strict: false` |

### Stream Replication Lag

```bash
nats server report jetstream  # shows lag per stream/consumer
```

**Cause:** Network latency between cluster nodes, overloaded follower, disk I/O saturation.
**Resolution:** Check network between nodes, verify disk performance, ensure RAFT group has quorum.

## Cluster Health

### Meta-Leader Issues

```bash
nats server report jetstream       # JetStream status
nats server cluster step-down      # Force meta-leader re-election
nats server cluster peer-remove <name>  # Remove permanently failed peer
```

**No meta-leader:** Without a meta-leader, no JetStream operations are possible. Restore quorum (majority of JetStream-enabled nodes must be online).

### Server Connectivity

```bash
nats server ls                # List all servers
nats server ping              # Connectivity check
nats server info              # Detailed server info
nats server check             # Health checks
nats server report connections  # Connection details
```

### RAFT Troubleshooting

**Symptoms:** JetStream operations failing, streams unavailable, consumers not processing.

**Steps:**
1. Check cluster size: `nats server ls` -- all expected nodes present?
2. Check JetStream status: `nats server report jetstream` -- leaders elected?
3. Check stream status: `nats stream info <STREAM>` -- replicas healthy?
4. Force step-down if leader is unresponsive: `nats server cluster step-down`
5. Remove permanently failed peer: `nats server cluster peer-remove <name>`

## Connectivity Issues

### Client Cannot Connect

| Symptom | Cause | Resolution |
|---|---|---|
| Connection refused | Server not running or wrong port | Check `nats-server` process; verify port 4222 |
| Auth error | Wrong credentials | Check username/password, creds file, NKey |
| TLS handshake failure | Certificate mismatch | Verify CA, cert, key; check TLS version |
| 503 No Responders | No subscriber for request subject | Deploy service; check subject spelling |

### Leaf Node Not Connecting

```bash
# Check leaf connections on hub
curl http://hub:8222/leafz
```

| Cause | Resolution |
|---|---|
| Wrong URL | Use `nats-leaf://` scheme |
| Credential mismatch | Verify leaf credentials match hub account |
| Firewall blocking port 7422 | Open leaf node port |
| TLS handshake first mismatch | Align `handshake_first` setting (2.10+) |

## Slow Consumers

### Symptoms
- Server log: `Slow Consumer Detected`
- `/varz` shows non-zero `slow_consumers`
- Messages dropped for affected subscriber

### Resolution
1. Increase subscriber processing speed
2. Use queue groups to distribute load
3. Increase client's pending buffer size
4. Switch from push to pull consumers (JetStream)
5. Deploy more consumer instances

## Memory Issues

### Diagnosis
```bash
curl http://localhost:8222/varz | jq '.mem, .jetstream.stats'
```

### Common Causes
| Cause | Resolution |
|---|---|
| Large JetStream memory streams | Switch to file storage |
| Many in-memory consumers | Reduce consumer count or switch to pull |
| Large deduplication windows | Reduce stream `Duplicates` window |
| High connection count | Reduce connections; use shared NATS connections |

### Tuning (2.12)
Set `GOMEMLIMIT` to prevent OOM from elastic pointers in filestore caches:
```bash
export GOMEMLIMIT=4GiB
```

## CLI Reference

### Core Messaging
```bash
nats pub orders.created '{"id": 1}'
nats sub "orders.>"
nats request service.ping "" --timeout 2s
nats reply service.ping "pong"
```

### Contexts
```bash
nats context add local --server nats://localhost:4222
nats context add prod --server nats://prod:4222 --creds prod.creds
nats context select prod
nats context ls
```

### Streams
```bash
nats stream ls
nats stream add ORDERS --subjects "orders.>" --storage file --replicas 3
nats stream info ORDERS
nats stream purge ORDERS
nats stream rm ORDERS
nats stream backup ORDERS /backup/
nats stream restore ORDERS /backup/
```

### Consumers
```bash
nats consumer ls ORDERS
nats consumer add ORDERS proc --pull --deliver all --ack explicit --max-deliver 5
nats consumer info ORDERS proc
nats consumer next ORDERS proc --count 10 --wait 5s
nats consumer pause ORDERS proc --until "2026-04-11T00:00:00Z"  # 2.11+
nats consumer rm ORDERS proc
```

### KV Store
```bash
nats kv add config --history 10 --replicas 3
nats kv put config db.host "db.example.com"
nats kv get config db.host
nats kv watch config
nats kv history config db.host
nats kv del config db.host
```

### Object Store
```bash
nats object add files --replicas 3
nats object put files /path/to/file
nats object get files filename --output /tmp/out
nats object ls files
```

### Server Operations
```bash
nats server ls
nats server ping
nats server info
nats server check
nats server check --prometheus-output
nats server report jetstream
nats server report connections
nats server report accounts
nats server cluster step-down
nats server cluster peer-remove <name>
```

### Benchmarking
```bash
nats bench js --pub 10 --sub 10 --size 512 --msgs 1000000 orders
nats cheat    # show all command examples
```

## Health Check Sequence

```bash
# 1. Server reachable
nats server ping

# 2. Server healthy
curl -s http://localhost:8222/healthz

# 3. JetStream operational
nats server report jetstream

# 4. Streams have leaders
nats stream info <STREAM>

# 5. Consumers processing
nats consumer info <STREAM> <CONSUMER>

# 6. No slow consumers
curl -s http://localhost:8222/varz | jq '.slow_consumers'
```
