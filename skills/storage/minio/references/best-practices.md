# MinIO Best Practices

## Hardware Sizing

**Production (high-performance):** Single socket 64+ cores with AVX-512, 256 GiB+ RAM, 30-122 TB NVMe 4.0/5.0 drives, 100 GbE minimum.

**Minimum viable:** 4 nodes, 4 drives/node (16 total), 10 GbE, 16-32 GiB RAM/node.

**Homogeneous nodes required:** Same OS/kernel, same drive count and size per pool, same NIC speed. Different pools can have different specs.

**Drive selection:** Direct-attached NVMe preferred. No hardware RAID (MinIO erasure coding is the redundancy). JBOD only.

**Filesystem:** XFS strongly preferred. Mount with `noatime,nodiratime`. Avoid ext4 (POSIX semantics issues). ZFS and Btrfs supported.

## Erasure Coding Selection

Default N/2 data + N/2 parity recommended for most workloads (strongest protection, 50% overhead).

| Parity | Storage Efficiency | Failure Tolerance | Use Case |
|--------|-------------------|-------------------|----------|
| EC:2 | 87.5% (16 drives) | 2 drives | Dev/test |
| EC:4 | 75% | 4 drives | Balanced production |
| EC:8 (default 16-drive) | 50% | 8 drives | Mission-critical |

Erasure set size fixed at deployment. Plan capacity before starting.

## Bucket Design

- Lowercase names, hyphens, no dots (SSL wildcard cert issues). Include environment and purpose.
- Design prefixes for access pattern alignment and ILM rule scoping.
- Enable versioning only when needed (overwrites, WORM, replication). Always pair with noncurrent version expiration.
- Set hard quotas on shared buckets: `mc quota set myminio/bucket --size 50TiB`

## Security Hardening

**TLS everywhere:** S3 API, console, internode. ECDSA/EdDSA certificates. Minimum TLS 1.2.

**Network isolation:** Never expose ports 9000/9001 directly. Use reverse proxy (NGINX/HAProxy) with rate limiting. Dedicated backend network for internode traffic.

**Least privilege IAM:** Never use root credentials for apps. Per-application service accounts with inline policies. Rotate credentials regularly.

**Encryption at rest:** SSE-KMS with external KMS for production. Bucket-level default encryption: `mc encrypt set sse-kms key-id myminio/bucket`.

**Audit logging:** `mc admin config set myminio logger_webhook:audit endpoint="https://..." auth_token="Bearer TOKEN"`

## Kubernetes Deployment

- Always use the MinIO Operator (not plain StatefulSets)
- StorageClass backed by local NVMe PVs with `volumeBindingMode: WaitForFirstConsumer`
- Do not use NFS/iSCSI/Ceph RBD for MinIO PVs
- Set explicit CPU/memory requests; avoid CPU limits that throttle erasure coding
- Pod anti-affinity across physical nodes
- Deploy each tenant in its own namespace with NetworkPolicies
- Pin to specific image digest, not `latest`

## Performance Tuning

**Object size:** Optimized for >= 1 MiB. Aggregate small objects before writing.

**Parallelism:** Use multipart uploads for objects > 16 MiB. Set client concurrency to 16-32 for bulk loads.

**Network saturation:** 4-node 100 GbE cluster should achieve ~40 Gbps aggregate PUT. Use `mc support perf myminio --throughput` to identify bottlenecks.

**CPU:** Ensure AVX-512 enabled (not disabled by BIOS/hypervisor). VM deployments need CPU passthrough.

**Go runtime:** Set `GOMAXPROCS=$(nproc)` in containers.

## Backup Strategy

MinIO erasure coding protects against hardware failures, not logical errors. Layer protection:

1. **Versioning + Object Locking** -- retain all versions, GOVERNANCE/COMPLIANCE mode
2. **Site Replication** -- 2-3 geographic sites, near-zero RTO/RPO for infra failures
3. **Bucket Replication to separate account** -- true logical backup with object locking
4. **Batch Replication for cold archive** -- periodic push to cold storage

Test restores regularly: `mc cp --version-id <uuid> myminio/bucket/file /tmp/restore/`
