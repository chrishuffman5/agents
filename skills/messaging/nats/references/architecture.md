# NATS Architecture Reference

## Core NATS

Core NATS is the foundational pub/sub layer. At-most-once, best-effort delivery. No persistence. Sub-millisecond latency at scale. Single binary, zero external dependencies.

### Subject-Based Addressing

Subjects are string-based channel names using `.` as token separator:
- Allowed characters: any Unicode except null, space, `.`, `*`, `>`
- Maximum recommended: 16 tokens, 256 characters total
- Reserved prefixes: `$` (system: `$SYS`, `$JS`, `$KV`), `_INBOX` (reply-to)

**Wildcards (subscribers only):**
- `*` -- single token: `orders.*.created` matches `orders.us.created` but not `orders.us.east.created`
- `>` -- multi-token tail (must be last): `orders.>` matches `orders.us`, `orders.us.east.created`

### Queue Groups

Load balancing across subscribers. Server delivers each message to one random member:
```bash
nats sub --queue workers "orders.>"
```
- No server reconfiguration needed to add/remove members
- Geo-affinity: server prefers local queue subscribers before routing cross-cluster
- Graceful draining: `nats sub --queue workers "orders.>" --drain`

### Request/Reply

Built-in RPC using dynamic inbox subjects:
```bash
nats reply "time.now" "$(date -u)"     # responder
nats request "time.now" "" --timeout 2s # requester
```
- `_INBOX.<nuid>` subjects generated automatically
- 503 No Responders if no subscribers exist (with headers support)
- Scatter-gather: multiple responders reply; client picks fastest

## JetStream

### Streams

Persistent, ordered log capturing messages from one or more subjects.

**Key configuration:**

| Parameter | Default | Description |
|---|---|---|
| `Storage` | File | File or Memory |
| `Replicas` | 1 | 1-5 copies in cluster |
| `MaxAge` | unlimited | Maximum message age |
| `MaxBytes` | unlimited | Maximum total stream size |
| `MaxMsgs` | unlimited | Maximum message count |
| `MaxMsgsPerSubject` | unlimited | Per-subject cap |
| `Retention` | LimitsPolicy | Limits, WorkQueue, or Interest |
| `Discard` | DiscardOld | DiscardOld or DiscardNew |
| `Duplicates` | 2 minutes | Deduplication window |
| `Compression` | none | S2 compression (2.10+, file only) |
| `AllowMsgTTL` | false | Per-message TTL via header (2.11+) |
| `AllowAtomicPublish` | false | Atomic batch publishing (2.12+) |
| `AllowMsgSchedules` | false | Delayed scheduling (2.12+) |

**Retention policies:**
- **LimitsPolicy** (default): Retain to configured limits. Best for replay/audit.
- **WorkQueuePolicy**: Consume-once. Message deleted after ack. One consumer per subject.
- **InterestPolicy**: Retain only while active consumers exist.

**CLI:**
```bash
nats stream add ORDERS --subjects "orders.>" --storage file --replicas 3 \
  --retention limits --max-age 7d --discard old
nats stream info ORDERS
nats stream purge ORDERS
nats stream backup ORDERS /backup/ORDERS
nats stream restore ORDERS /backup/ORDERS
```

### Consumers

A consumer is a cursor tracking position in a stream.

**Pull consumers (recommended):**
```bash
nats consumer add ORDERS processor --pull --deliver all --ack explicit \
  --max-deliver 5 --wait 30s --filter "orders.us.>"
nats consumer next ORDERS processor --count 10 --wait 5s
```

**Delivery policies:** DeliverAll, DeliverLast, DeliverNew, DeliverLastPerSubject, DeliverByStartSequence, DeliverByStartTime.

**Ack types:** AckAck (success), AckNak (fail, redeliver), AckProgress (reset timer), AckTerm (stop redelivering), AckNext (ack + request next).

**Key parameters:**
- `AckWait`: Duration before redelivery
- `MaxDeliver`: Maximum attempts (-1 = unlimited)
- `MaxAckPending`: Max unacked in flight
- `FilterSubject` / `FilterSubjects` (2.10+): Server-side filtering
- `PauseUntil` (2.11+): Suspend delivery until timestamp
- `PriorityGroups` (2.11+): Named priority groups for pull consumers

### Exactly-Once

1. **Publisher deduplication:** Set `Nats-Msg-Id` header. Server tracks within `Duplicates` window.
2. **Consumer double-ack:** Use `AckSync()` -- wait for server confirmation of ack.

### Mirrors and Sources

**Mirrors:** One-way async replication from one source. Read-only. Preserves sequence numbers. 2.12: mirror promotion for DR.

**Sources:** Aggregate multiple streams into one. Clients can still publish directly. Does not preserve original sequence numbers.

```bash
nats stream add ORDERS-MIRROR --mirror ORDERS
nats stream add ALL-EVENTS --source ORDERS --source RETURNS
# Promote mirror (2.12)
nats stream edit ORDERS-MIRROR --no-mirror
```

## KV Store

Built on JetStream (stream `KV_<bucket>`).

```bash
nats kv add my-config --history 10 --ttl 24h --replicas 3
nats kv put my-config db.host "db.example.com"
nats kv get my-config db.host
nats kv watch my-config          # real-time updates
nats kv history my-config db.host
```

**Compare-and-swap:** `Create` (only if no value), `Update` (only if revision matches). Optimistic concurrency.

## Object Store

Large binary objects with automatic chunking (128 KB default):
```bash
nats object add files --storage file --replicas 3
nats object put files /path/to/large.bin
nats object get files large.bin --output /tmp/out
```

## Clustering

### Route-Based (Full Mesh)

```conf
cluster {
  name: my-cluster
  port: 6222
  routes: [nats://nats-1:6222, nats://nats-2:6222, nats://nats-3:6222]
}
```

Multi-route connections (2.10+): pool of TCP connections per pair (default 3). Optional account pinning and compression.

### JetStream RAFT Groups

1. **Meta Group:** All JetStream servers. Manages API and asset placement.
2. **Stream Groups:** Per-stream RAFT group with R servers.
3. **Consumer Groups:** Per-durable-consumer RAFT group.

Fault tolerance: R=3 tolerates 1 failure, R=5 tolerates 2.

### Super-Cluster (Gateways)

Connect clusters with reduced connection overhead:
```conf
gateway {
  name: east-cluster
  port: 7222
  gateways: [
    { name: west-cluster, urls: ["nats://west-1:7222"] }
  ]
}
```

Interest-only mode: only forward messages for subjects with registered interest.

### Leaf Nodes

Lightweight extensions bridging local NATS to remote cluster:
```conf
leafnodes {
  remotes: [{
    url: "nats-leaf://hub:7422"
    credentials: "/etc/nats/leaf.creds"
  }]
}
```

Use cases: IoT edge gateways, hybrid cloud, multi-region with selective routing.

## Security

### Accounts

Strong isolation. Each account has own subject namespace, JetStream assets, connection limits. Cross-account sharing via explicit import/export.

### Authentication Methods

- **Username/password:** Basic auth with bcrypt
- **NKey:** Ed25519 keypair. Server stores public key only.
- **JWT (decentralized):** Operator -> Account -> User trust chain. No server config update per user.
- **mTLS:** Client certificate with `verify_and_map` for identity mapping
- **Auth Callout (2.10+):** Delegate auth to external NATS service (LDAP, OAuth, custom)

### NSC Tool
```bash
nsc add operator --generate-signing-key --sys --name my-op
nsc add account my-app
nsc add user my-service
nsc edit user my-service --allow-pub "orders.>" --allow-sub "orders.>" "_INBOX.>"
nsc generate creds --account my-app --user my-service > my-service.creds
```

## Monitoring

### HTTP Endpoints (port 8222)

| Endpoint | Data |
|---|---|
| `/varz` | Server state, CPU/memory, message counters |
| `/connz` | Active connections |
| `/routez` | Cluster routes |
| `/gatewayz` | Gateway details |
| `/leafz` | Leaf node connections |
| `/jsz` | JetStream streams, consumers, API usage |
| `/healthz` | Server health (ok/error) |

### nats-top
```bash
nats-top -s nats-server:8222 -n 50 -d 2
```

### Prometheus
- `prometheus-nats-exporter`: Scrapes HTTP endpoints
- NATS Surveyor: Single exporter for entire deployment via NATS protocol
- `nats server check --prometheus-output`
