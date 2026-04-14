# NATS Best Practices Reference

## Subject Namespace Design

```
# Pattern: <domain>.<entity>.<operation>[.<qualifiers>]
orders.us.created
inventory.warehouse-1.reserved
sensors.factory-a.line-2.temperature

# Services (request-reply):
service.orders.get
api.v2.users.lookup
```

**Guidelines:**
- Maximum 16 tokens, 256 characters
- Use early tokens for broad categories, later tokens for specifics
- Avoid encoding technical implementation details in subjects
- Reserve `$` prefix for system use
- Plan for wildcards in subscription patterns from the start
- Use `-` or `_` for multi-word tokens (case-sensitive)

## Stream Configuration

### Storage Selection
- **File:** Durability, production workloads. Always for data that matters.
- **Memory:** Performance-critical, ephemeral data. Acceptable to lose on restart.

### Replica Recommendations
- Development: R=1
- Production: R=3 (tolerates 1 failure)
- Maximum fault tolerance: R=5 (requires 5+ nodes)
- Always use odd counts

### Retention Strategy

| Use Case | Retention Policy | Configuration |
|---|---|---|
| Replay, audit, event sourcing | LimitsPolicy | MaxAge + MaxBytes + MaxMsgs |
| Work queue (process once) | WorkQueuePolicy | Message deleted after ack |
| Fan-out to active consumers | InterestPolicy | Dropped if no consumers |

### Deduplication
- Default window: 2 minutes. Sufficient for most retry scenarios.
- Always use `Nats-Msg-Id` header for at-least-once publishers.
- Avoid very large windows (memory overhead per tracked ID).

### Compression (2.10+)
- Enable S2 for text-heavy or compressible workloads
- Per-block compression (not per-message)
- Minimal CPU overhead, significant storage savings

### Encryption (2.10+)
```conf
jetstream {
  store_dir: /data/js
  cipher: chacha    # or aes
  key: $JS_KEY      # env variable
}
```

### Per-Message TTL (2.11+)
```bash
nats stream add EVENTS --subjects "events.>" --allow-msg-ttl
nats pub events.temp '{"sensor":"A"}' --header "Nats-TTL: 30s"
```

## Consumer Tuning

### Pull vs Push

| Dimension | Pull (recommended) | Push |
|---|---|---|
| Flow control | Client-controlled | Server-driven |
| Scaling | Multiple clients on same consumer | Dedicated delivery subject |
| Work queue | Natural fit | Requires queue group delivery subject |
| New designs | Always prefer | Legacy or specific replay scenarios |

### Ack Wait Configuration
Set `AckWait` to at least the 99th percentile of message processing time. Use `AckProgress` (in-progress ack) for long-running tasks to reset the timer without completing.

### MaxDeliver
Set to 3-10 for most workloads. Messages exceeding MaxDeliver receive `AckTerm` treatment. Implement dead-letter routing in consumer logic:

```go
// Pseudo-code: DLQ pattern for NATS JetStream
msg, _ := sub.Fetch(1)
if msg.Headers.Get("Nats-Num-Delivered") >= maxRetries {
    // Publish to dead-letter stream
    js.Publish("dlq.orders", msg.Data)
    msg.Term() // stop redelivering
} else {
    err := process(msg)
    if err != nil {
        msg.NakWithDelay(time.Second * 30)
    } else {
        msg.Ack()
    }
}
```

### MaxAckPending
Controls in-flight messages. Start with 100-1000. Increase for high-throughput consumers; decrease if processing is slow and you want to limit redeliveries.

### Consumer Pausing (2.11+)
```bash
nats consumer pause ORDERS processor --until "2026-04-11T00:00:00Z"
```
Heartbeats continue during pause. Auto-resumes at deadline.

### Priority Groups (2.11+)
Named groups with Overflow, Pinned, and Prioritized policies for flexible failover across regions.

## Security Hardening

### Production Checklist
1. Enable TLS for all client and cluster connections
2. Use NKey or JWT authentication (not plain username/password)
3. Use accounts for multi-tenant isolation
4. Restrict per-user publish/subscribe permissions
5. Use `verify_and_map` for mTLS identity mapping
6. Bind monitoring port to localhost or firewall
7. Set connection limits per account
8. Rotate credentials regularly
9. Use Auth Callout (2.10+) for enterprise auth integration

### TLS Configuration
```conf
tls {
  cert_file: "/etc/nats/server-cert.pem"
  key_file:  "/etc/nats/server-key.pem"
  ca_file:   "/etc/nats/ca.pem"
  verify:    true
  min_version: "1.3"
}
```

### Account Isolation
```conf
accounts: {
  APP_A: {
    users: [{ user: app_a, password: "$2a$..." }]
    jetstream: enabled
    exports: [{ stream: "events.>", accounts: ["APP_B"] }]
  }
  APP_B: {
    imports: [{ stream: { account: APP_A, subject: "events.>" }, prefix: "from_a" }]
  }
}
```

## Monitoring Setup

### Critical Alerts

| What to Monitor | Alert Threshold |
|---|---|
| `/healthz` status | Not `ok` |
| JetStream meta-leader available | Meta-leader absent |
| Stream consumer pending count | Growing trend |
| Slow consumer count | > 0 sustained |
| Connection count | Near configured limit |
| CPU/memory usage | > 80% sustained |

### Prometheus Setup
1. Deploy `prometheus-nats-exporter` alongside each server
2. Or use NATS Surveyor for single-exporter cluster monitoring
3. Import community Grafana dashboards
4. Set `http_port: 8222` for monitoring endpoints

### System Account Events
```bash
# Subscribe to connect/disconnect events
nats sub --creds sys.creds '$SYS.ACCOUNT.*.CONNECT'
nats sub --creds sys.creds '$SYS.ACCOUNT.*.DISCONNECT'
```

## Cluster Sizing

| Deployment | Nodes | Notes |
|---|---|---|
| Development | 1 | No HA; R=1 streams only |
| Production (standard) | 3 | Tolerates 1 failure; R=3 streams |
| Production (high HA) | 5 | Tolerates 2 failures; R=5 streams |
| Edge / leaf node | 1 | Local processing; hub provides HA |

### Leaf Node Topology
```
[Cloud Hub Cluster (3 nodes)]
        │
   ┌────┼────┐
   │    │    │
[Edge] [Edge] [Edge]
  1 node each, leaf connection to hub
  Local traffic stays local
  Selective hub routing
```

## Version-Specific Features

| Feature | Version |
|---|---|
| S2 compression, subject transforms, multi-filter consumers | 2.10 |
| Auth Callout, v2 route pools | 2.10 |
| Per-message TTL, consumer pausing, priority groups | 2.11 |
| Distributed message tracing | 2.11 |
| Atomic batch publish, distributed counters, delayed scheduling | 2.12 |
| Mirror promotion, strict JetStream validation (default) | 2.12 |
| `isolate_leafnode_interest`, `connect_backoff` | 2.12 |

## Downgrade Safety

- 2.12 -> 2.11.9+: Safe (offline asset mode)
- Do NOT downgrade from 2.12 to pre-2.11.9
- 2.10 storage format incompatible with pre-2.9.22
