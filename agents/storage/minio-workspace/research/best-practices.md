# MinIO Best Practices

## Hardware Sizing

### Recommended Production Configuration (AIStor / High-Performance)

| Component | Recommendation                                            |
|-----------|-----------------------------------------------------------|
| CPU       | Single socket, 64+ cores, 128+ PCIe lanes, AVX-512 support|
| RAM       | 256 GiB or more free for the MinIO process               |
| Storage   | 30.72 TB / 61.44 TB / 122.88 TB NVMe 4.0 or 5.0 drives  |
| Network   | 100 GbE minimum; 400 GbE for maximum throughput          |

### Minimum Viable Deployment (Development / Small Production)

- 4 nodes minimum for distributed mode with erasure coding.
- 4 drives per node minimum (16 drives total = 8 data + 8 parity).
- 10 GbE networking is functional but will cap throughput well below NVMe speeds.
- 16 GiB RAM per node minimum; recommend 32+ GiB.

### Homogeneous Node Configuration

All nodes in a server pool must be homogeneous:
- Same OS and kernel version across all nodes.
- Same number of drives per node (asymmetric configurations are not supported within a pool).
- Same drive size per node. Mixed drive sizes within a node cause MinIO to cap all drives to the smallest capacity.
- Same network interface and speed.

Different pools can have different hardware specifications, enabling phased hardware refresh.

### Drive Selection

- **Direct-attached NVMe** is strongly preferred. Avoid SAN, NAS, or network-attached block devices for data paths — latency variability destroys performance predictability.
- Do not use hardware RAID. MinIO's erasure coding is the redundancy mechanism; hardware RAID adds cost and complexity for no benefit and hides drive failures from MinIO's healing system.
- Drive capacity matters as much as count. Fewer, higher-capacity NVMe drives allow you to max out MinIO's throughput with fewer nodes.
- Use JBOD (Just a Bunch Of Disks) with no hardware RAID controller in data path.

### Filesystem

| Filesystem | Recommendation                                            |
|------------|-----------------------------------------------------------|
| XFS        | Strongly preferred. Best POSIX semantics, high-perf      |
| ZFS        | Supported; useful if you want filesystem-level snapshots  |
| Btrfs      | Supported                                                 |
| ext4       | Avoid. Does not honor POSIX semantics; can cause data corruption|

Mount XFS with these options for production:
```bash
# /etc/fstab entry
UUID=<uuid> /mnt/disk1 xfs defaults,noatime,nodiratime 0 2
```

`noatime` eliminates unnecessary write amplification from access-time updates.

---

## Erasure Coding Selection

### Default: Trust the Defaults

MinIO's default of N/2 data + N/2 parity is the recommended starting point for virtually all workloads. It provides:
- The strongest protection against simultaneous drive failures.
- Full read availability down to N/2 surviving drives.
- Acceptable storage efficiency (50% overhead).

### When to Deviate

Only deviate from default EC ratios after using the MinIO Erasure Code Calculator (min.io/product/erasure-code-calculator) and understanding the tradeoffs:

| Parity Level | Storage Efficiency | Failure Tolerance | Use Case                              |
|-------------|-------------------|-------------------|---------------------------------------|
| EC:2        | 87.5% (on 16 drives)| 2 drives         | Dev/test, cost-sensitive, low risk    |
| EC:4        | 75%               | 4 drives          | Balanced production                   |
| EC:8 (default 16-drive)| 50%    | 8 drives          | Mission-critical, regulatory          |

### Erasure Set Size Considerations

- MinIO auto-computes the erasure set size from total drives in a pool. For example, 4 nodes × 4 drives = 16 drives → 1 erasure set of 16 drives.
- Prefer erasure set sizes that are multiples of the node count for even distribution.
- Larger erasure sets (16 drives) offer better storage efficiency vs. smaller sets (4 drives) at the same parity level.
- The erasure set size is fixed at deployment. Plan capacity before starting.

### Drive Failure Scenarios

With a 16-drive erasure set (EC:8):
- 1–8 drives fail: full read/write operation continues.
- 9 drives fail: reads still work but writes fail (below write quorum).
- 9+ drives fail: data loss risk (below read quorum).

---

## Bucket Design

### Naming Conventions

- Use lowercase, hyphens, no underscores, no dots (dots cause SSL wildcard cert issues).
- Avoid overly generic names; include environment and purpose: `prod-ml-training-data`, `dev-app-logs`.
- Keep names short — they appear in every S3 API call and IAM policy.

### Prefix (Directory) Structure

S3 has no real directories; prefixes with `/` simulate hierarchy. Design prefixes for access pattern alignment:
```
mybucket/
  raw/2025/01/15/           # date-partitioned ingestion
  processed/model-v3/       # versioned output artifacts
  archive/                  # cold data pending transition
```

Good prefix design:
- Aligns with ILM rule scopes (apply expiration to `raw/` prefix only).
- Enables fine-grained IAM policies (grant read access to `processed/` only).
- Avoids "hot prefix" problems — many objects under the same prefix don't hurt MinIO (unlike DynamoDB), but do affect listing performance at scale.

### Versioning Decision

Enable versioning when:
- Objects are overwritten regularly and rollback is needed.
- WORM/object locking is required (locking requires versioning).
- Bucket is used as a target for replication (replication requires versioning).

Do not enable versioning when:
- High-churn data (logs, telemetry) is written once and never updated — versioning creates storage overhead with no benefit.
- You want simplest possible delete semantics.

Always pair versioning with ILM noncurrent-version expiration to control storage growth.

### Quota Setting

Set hard quotas on buckets used by external teams or applications to prevent storage surprise:
```bash
mc quota set myminio/team-data-science --size 50TiB
```

---

## Security Hardening

### TLS Everywhere

- Enable TLS on all MinIO endpoints — S3 API, console, and internode communication.
- Use ECDSA or EdDSA certificates (lower CPU overhead vs. RSA for high-throughput workloads).
- Minimum TLS version: 1.2 (MinIO default). TLS 1.3 preferred.
- For Kubernetes: let the Operator auto-generate certificates via the `certificates.k8s.io` API.
- For bare metal: use cert-manager or Vault PKI to automate certificate rotation.

### Network Isolation

- Do not expose the MinIO S3 port (9000) or console port (9001) directly to the internet.
- Place a reverse proxy (NGINX, Traefik, HAProxy) in front of MinIO for:
  - mTLS termination for specific clients.
  - IP allowlisting for console access.
  - Rate limiting to protect against credential stuffing.
  - HSTS headers.
- Keep internode communication (distributed mode) on a dedicated backend network, isolated from the S3 API network.

### Least Privilege IAM

- Never use the root (admin) credentials for application access.
- Create per-application service accounts with inline policies scoped to the minimum required buckets and operations.
- Example minimal read-only service account policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:HeadObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::ml-training-data",
      "arn:aws:s3:::ml-training-data/*"
    ]
  }]
}
```

- Rotate service account credentials regularly.
- Audit access keys periodically with `mc admin user list` and `mc admin accesskey list`.

### Encryption at Rest

- Enable SSE-KMS with an external KMS (HashiCorp Vault, AWS KMS) for production.
- Set bucket-level default encryption so all objects are encrypted automatically without requiring per-PUT header:

```bash
mc encrypt set sse-kms my-kms-key-id myminio/mybucket
```

- Use SSE-S3 as a minimum for non-regulated workloads where external KMS is not feasible.

### Disable Unnecessary Features

```bash
# Disable anonymous (public) access at cluster level
mc anonymous set none myminio

# Disable anonymous listing (if not needed)
mc anonymous set none myminio/mybucket
```

### Audit Logging

Enable MinIO audit logs to capture all API operations with caller identity, timestamp, and resource:
```bash
mc admin config set myminio logger_webhook:audit \
  endpoint="https://logging.example.com/minio-audit" \
  auth_token="Bearer TOKEN"
```

Send to a SIEM (Splunk, Elasticsearch, Loki) for correlation and alerting.

---

## Kubernetes Deployment Best Practices

### Use the MinIO Operator

- Never deploy MinIO in Kubernetes using plain Deployments or StatefulSets without the Operator. The Operator manages the full lifecycle: pod scheduling, TLS cert provisioning, health checks, and rolling upgrades.
- Pin the Operator version in your Helm values to prevent unintentional upgrades.

### Storage Class

- Use a `StorageClass` backed by local NVMe PersistentVolumes with `volumeBindingMode: WaitForFirstConsumer`.
- Do not use network-attached storage (NFS, iSCSI, Ceph RBD) for MinIO PVs — latency variance degrades performance and can cause healing storms.
- Use the `local-storage` provisioner or similar CSI driver for direct-attached NVMe.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-nvme
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
```

### Resource Requests and Limits

Set explicit resource requests so the Kubernetes scheduler places MinIO pods on appropriate nodes:
```yaml
resources:
  requests:
    cpu: "16"
    memory: "64Gi"
  limits:
    cpu: "32"
    memory: "128Gi"
```

Avoid setting CPU limits that cause throttling on erasure-coding operations — CPU limits can create artificial bottlenecks.

### Pod Anti-Affinity

Ensure MinIO pods are spread across different physical nodes (or availability zones):
```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: "kubernetes.io/hostname"
        labelSelector:
          matchLabels:
            app: minio
```

### Namespace Isolation

Deploy each MinIO tenant in its own namespace with dedicated NetworkPolicies restricting ingress/egress to authorized services only.

### Image Management

- Pin to a specific MinIO image digest in production, not `latest`.
- Use a private registry mirror to avoid Docker Hub rate limits and ensure image availability.

---

## Performance Tuning

### Object Size

MinIO is optimized for large objects (>= 1 MiB). For small-object workloads:
- Aggregate small objects into larger ones before writing (e.g., using Apache Arrow, Parquet, or tar archives).
- If small objects are unavoidable, ensure NVMe drives with high IOPS and low latency are used, and benchmark with `mc support perf` to identify bottlenecks.

### Parallelism

- Use multipart uploads for objects > 16 MiB. S3 SDK libraries handle this automatically when configured correctly.
- Set concurrency appropriately in your S3 client. AWS SDK v2 defaults to 8 parallel parts; increase to 16-32 for high-throughput bulk loads.

### Network Bandwidth Saturation

- MinIO is designed to saturate available network bandwidth. With 100 GbE, a 4-node cluster should achieve ~40 Gbps aggregate throughput on PUT operations.
- If throughput is below expected, use `mc support perf myminio --throughput` to identify whether the bottleneck is network, CPU (erasure coding), or storage.

### CPU for Erasure Coding

- Ensure AVX-512 is enabled in the CPU (not disabled by BIOS/hypervisor).
- For VM deployments, use CPU passthrough or at least enable AVX-512 feature flags in the VM configuration.
- Monitor CPU utilization during heavy write workloads. If erasure coding is CPU-bound, reduce parity (e.g., EC:4 instead of EC:8) or scale horizontally.

### Read Performance

- For read-heavy workloads, MinIO reads from the minimum required drives (read quorum). This means read I/O is spread across all drives in the erasure set automatically.
- Bitrot verification on every read adds minimal overhead (HighwayHash is extremely fast); do not disable it.

### Go Runtime Tuning

Set `GOMAXPROCS` to match available CPU cores (usually automatic but relevant in container environments):
```bash
export GOMAXPROCS=$(nproc)
```

---

## Backup Strategy

### MinIO Is Not a Backup Target by Default

MinIO provides high availability via erasure coding, not backup. Erasure coding protects against hardware failures; it does not protect against logical errors (accidental deletion, ransomware, application bugs).

### Recommended Layered Approach

**Layer 1: Versioning + Object Locking**
- Enable bucket versioning to retain all object versions.
- Enable object locking with GOVERNANCE or COMPLIANCE mode for critical data.
- Configure ILM to expire non-current versions after a retention period.

**Layer 2: Site Replication (Active-Active)**
- Configure 2-3 geographic sites with site replication.
- Provides near-zero RTO/RPO for infrastructure failures and disaster recovery.
- Does not protect against logical errors (a deleted object replicates as deleted).

**Layer 3: Bucket Replication to Separate Account (Logical Backup)**
- Replicate critical buckets to a separate MinIO deployment with a different root credential and no replication back.
- Use object locking on the backup target to prevent deletion.
- This creates a true logical backup independent of the primary cluster's IAM.

**Layer 4: Batch Replication for Cold Archive**
- Periodically run batch replication jobs to push data to cold storage (tape, object glacier tier, separate S3-compatible cold store).

### RPO/RTO Targets

| Strategy                     | RPO              | RTO              |
|------------------------------|------------------|------------------|
| Erasure coding only          | 0 (no data loss) | Minutes (healing)|
| + Site replication           | Near 0           | Seconds (DNS failover)|
| + Versioned bucket replication| 0 for non-deleted objects | Minutes |
| + External backup            | Last backup cycle| Hours             |

### Testing Restores

Regularly test restore procedures:
```bash
# Verify a specific version can be retrieved
mc cp --version-id <version-uuid> myminio/mybucket/critical-file.parquet /tmp/restore-test/

# Verify site failover
mc ls myminio-site2/mybucket
```
