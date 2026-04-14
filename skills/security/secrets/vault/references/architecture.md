# HashiCorp Vault — Architecture Internals

Deep reference covering Vault's storage engine, Raft consensus, replication architecture, namespace model, plugin system, and performance characteristics.

---

## Storage Architecture

### The Barrier

Everything Vault stores goes through the barrier — an AES-256-GCM encryption layer. The barrier key (root key) is derived from unseal keys. Without the root key in memory, Vault cannot read or write anything.

The storage backend sees only opaque encrypted blobs. The backend has no concept of Vault's data model — it only stores and retrieves byte arrays at string paths.

```
Vault Core
  ↓ serializes to protobuf
Barrier (encrypt with root key, AES-256-GCM)
  ↓ writes encrypted bytes
Storage Backend (Raft / Consul / S3 / etc.)
```

### Integrated Storage (Raft)

Vault's built-in high-availability storage, based on the Raft consensus algorithm.

**Raft fundamentals**:
- Single leader handles all writes
- Followers replicate from leader via AppendEntries RPCs
- Reads can go to leader (strong consistency) or followers (stale reads)
- Leader election via randomized timeouts (150-300ms default)
- Quorum required: majority of nodes must acknowledge writes

**Vault Raft cluster sizing**:

| Cluster Size | Failure Tolerance | Notes |
|---|---|---|
| 1 node | 0 | Dev/test only |
| 3 nodes | 1 | Minimum for production |
| 5 nodes | 2 | Recommended for production |
| 7 nodes | 3 | Large deployments only; latency increases |

**Raft storage layout**:
```
/vault/data/
  raft/          # Raft WAL and snapshots
    raft.db      # BoltDB database (WAL entries)
    snapshots/   # Periodic snapshots of state machine
```

**Raft snapshots**: Vault periodically compresses the state machine into a snapshot to bound WAL growth. Default: snapshot after 8192 log entries or when WAL exceeds a size threshold.

**Join procedures**:
```bash
# Initialize first node
vault operator init

# Join additional nodes to Raft cluster
vault operator raft join https://active-vault-node:8200

# List Raft peers
vault operator raft list-peers

# Remove a peer (after node failure)
vault operator raft remove-peer <node-id>
```

**Autopilot**: Automatically manages cluster health — dead node removal, version upgrade coordination, redundancy zones.

```bash
vault operator raft autopilot get-config
vault operator raft autopilot state
```

### Storage Backend Comparison

| Backend | HA | Notes |
|---|---|---|
| Raft (integrated) | Yes (built-in) | Recommended; no external dependencies |
| Consul | Yes (via Consul) | Legacy; operational overhead of Consul cluster |
| S3 | No | Single-node only; use with auto-unseal |
| Azure Blob | No | Single-node only |
| GCS | No | Single-node only; supports HA lock via GCS |
| DynamoDB | Yes (via DDB locking) | AWS-native deployments |
| Etcd | Yes | Kubernetes-native deployments |

---

## Replication (Enterprise)

### Performance Replication

Creates one or more read-replica clusters (Performance Secondaries) that handle read requests:

```
Primary Cluster (read+write)
  ↕ Replication stream (WAL)
Performance Secondary 1 (read-only, full token passthrough)
Performance Secondary 2 (read-only, full token passthrough)
```

Key characteristics:
- Secondaries can handle reads: auth, secret reads, token lookups
- Writes must go to primary
- Tokens created on primary are valid on secondaries (token passthrough)
- Local auth mounts on secondary: generate tokens valid only on that secondary
- Replication lag: typically < 1 second on low-latency networks

Use cases: geo-distributed applications, read scaling, regional compliance boundaries.

```bash
vault write -f sys/replication/performance/primary/enable
vault write sys/replication/performance/primary/secondary-token id=secondary-1
# On secondary:
vault write sys/replication/performance/secondary/enable token=<token> primary_api_addr=https://primary:8200
```

### DR Replication

Disaster recovery — passive standby cluster:

- DR Secondary: no reads, no writes during normal operation
- Promotion: DR secondary becomes primary when primary fails
- RPO: near-zero (WAL replication is continuous)
- RTO: minutes (manual promotion or automated with DR operations token)

```bash
vault write -f sys/replication/dr/primary/enable
vault write sys/replication/dr/primary/secondary-token id=dr-1
# On DR secondary:
vault write sys/replication/dr/secondary/enable token=<token>

# Promote DR secondary (emergency)
vault operator generate-root -dr-token  # generate DR ops token
vault write sys/replication/dr/secondary/promote dr_operation_token=<token>
```

---

## Namespace Architecture (Enterprise)

Namespaces provide multi-tenancy within a single Vault cluster:

```
root namespace
├── team-a/       (namespace)
│   ├── secret/   (KV engine, scoped to team-a)
│   ├── auth/     (auth methods, scoped to team-a)
│   └── devops/   (child namespace)
└── team-b/       (namespace)
```

**Isolation**: Each namespace has its own:
- Secret engines (mounted at namespace-relative paths)
- Auth methods
- Policies
- Tokens (scoped to namespace)
- Audit devices

**Root tokens** can operate across all namespaces. Namespace-scoped tokens cannot access parent or sibling namespaces.

```bash
# Create a namespace
vault namespace create team-a

# Operate in a namespace
VAULT_NAMESPACE=team-a vault kv put secret/config key=value

# Or use the -namespace flag
vault -namespace=team-a kv get secret/config

# Nested namespace
vault namespace create -namespace=team-a devops
```

**Use cases**: MSP/multi-tenant deployments, business unit isolation, environment isolation (dev/staging/prod) within enterprise.

---

## Plugin System

All secret engines and auth methods are implemented as plugins. Vault ships with built-in plugins, but custom plugins can be registered.

**Plugin types**:
- Built-in: compiled into Vault binary
- External: separate process, communicates via gRPC over Unix socket or localhost TCP

```bash
# Register an external plugin
vault plugin register -sha256=<checksum> secret my-custom-plugin my-custom-plugin-binary

# Enable the plugin
vault secrets enable -path=custom my-custom-plugin

# Reload a plugin (after binary update)
vault plugin reload -plugin=my-custom-plugin
```

**Plugin catalog**: Lists all registered plugins.

```bash
vault plugin list
vault plugin info secret my-custom-plugin
```

---

## Token Architecture

### Token Types

| Type | Use When | Characteristics |
|---|---|---|
| Service Token | Interactive use, apps | Renewable, can create child tokens, persisted |
| Batch Token | High-throughput apps | Non-renewable, lightweight (not persisted), no child tokens |
| Root Token | Initial setup only | Never use in production apps; revoke immediately |

**Token hierarchy**: Tokens can create child tokens. Revoking a parent revokes all children (token tree). Use `orphan` tokens to break parent-child relationship.

### Token Accessor

Every token has an accessor — an identifier that can be used to look up and revoke a token without the token itself. Store accessors (not tokens) in your audit trail.

```bash
vault token create -policy=my-policy
# Returns: token + token_accessor

# Look up via accessor
vault token lookup -accessor <accessor>

# Revoke via accessor
vault token revoke -accessor <accessor>
```

### Token Renewal

Tokens with TTLs must be renewed before expiry. Vault Agent handles this automatically. For manual renewal:

```bash
vault token renew
vault token renew -increment=1h
```

Max TTL caps how long a token can exist regardless of renewals.

---

## Request Processing Pipeline

```
HTTP Request (TLS)
  ↓
Router (maps path to mount)
  ↓
Auth Layer (validates token + capabilities)
  ↓
Policy Engine (checks policy for path + capability)
  ↓
Secret Engine / Auth Method Handler
  ↓
Barrier (encrypt/decrypt)
  ↓
Storage Backend
```

**Lease management**: Most secret reads generate a lease. Leases are tracked in Vault's expiry manager. When a lease expires, the associated secret or credential is revoked automatically (database credentials destroyed, tokens invalidated).

---

## Performance and Capacity Planning

### Throughput Characteristics

- Vault is typically network and storage I/O bound, not CPU bound
- Raft writes require quorum acknowledgment — latency matters
- KV reads: ~10,000 QPS on a standard VM with SSD-backed Raft
- Transit encrypt/decrypt: ~5,000 QPS (RSA-2048), ~50,000 QPS (AES-256)

### Resource Sizing Guidelines

| Deployment | CPU | RAM | Storage | Notes |
|---|---|---|---|---|
| Dev/Test | 2 vCPU | 4 GB | 10 GB SSD | Single node |
| Small Prod | 4 vCPU | 8 GB | 50 GB SSD | 3-node Raft |
| Medium Prod | 8 vCPU | 16 GB | 100 GB SSD | 5-node Raft |
| Large Prod | 16 vCPU | 32 GB | 200 GB SSD | 5-node Raft + perf secondaries |

### Storage Growth

Raft storage grows with:
- Number of secrets (KV versions retained per config)
- Lease entries (one per issued credential)
- Audit log (if using file audit device on same disk)

Monitor: `vault operator raft snapshot save snapshot.gz` to measure current state machine size.

```bash
# Check leader and cluster health
vault status
vault operator raft list-peers
vault operator raft autopilot state
```

### Telemetry

Vault emits metrics via StatsD, Prometheus (via `/v1/sys/metrics`), Circonus, or Datadog.

Key metrics:
- `vault.core.unsealed` — Seal status
- `vault.route.read.*` / `vault.route.write.*` — Per-path operation counts and latency
- `vault.expire.num_leases` — Active lease count
- `vault.runtime.alloc_bytes` — Memory usage
- `vault.raft.apply` — Raft commit latency

```hcl
# vault.hcl — enable Prometheus metrics
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}
```

---

## Operational Procedures

### Backup and Restore

```bash
# Snapshot (Raft) — captures full encrypted state
vault operator raft snapshot save vault-backup-$(date +%Y%m%d).snap

# Restore (destructive — replaces current state)
vault operator raft snapshot restore vault-backup-20250101.snap

# Verify snapshot integrity
vault operator raft snapshot inspect vault-backup-20250101.snap
```

Schedule snapshots to object storage (S3, Azure Blob, GCS) via cron or Vault's Enterprise snapshot agent.

### Upgrade Procedure (Raft Cluster)

1. Verify all nodes are healthy (`vault operator raft list-peers`)
2. Upgrade one standby node (rolling)
3. Wait for upgraded node to join and sync
4. Repeat for remaining standbys
5. Step down leader (`vault operator step-down`) — triggers re-election
6. Upgrade the (now standby) original leader
7. Verify autopilot state

### Lease Cleanup

Excessive leases degrade performance:

```bash
# Count active leases
vault list sys/leases/lookup/

# Revoke all leases for a prefix (e.g., after decommissioning a service)
vault lease revoke -prefix database/creds/app-role

# Force-revoke expired leases (if expiry manager is backed up)
vault write sys/leases/tidy
```

### Emergency Break-Glass

If Vault is sealed and unseal key holders are unavailable:

1. If auto-unseal: check KMS key availability in the cloud provider
2. If Shamir: locate key holders per your key custodian runbook
3. If root token is lost: generate new root token using unseal keys

```bash
# Generate new root token (requires quorum of unseal key holders)
vault operator generate-root -init
# Each key holder: vault operator generate-root -nonce=<nonce>
# Final key holder gets encoded token; decode with OTP
vault operator generate-root -decode=<encoded> -otp=<otp>
```
