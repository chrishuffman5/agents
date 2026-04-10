# Nutanix AHV Best Practices

## Sizing Guidelines

| Resource | Guidance |
|----------|----------|
| CVM vCPU | 4 minimum; 8-12 for heavy workloads or high VM density |
| CVM RAM | 32 GB typical; 48 GB for dense clusters or dedup-heavy workloads |
| RF selection | RF2 for dev/test; RF3 for production databases and critical workloads |
| SSD tier | Target 20% or more of active working set fits in SSD/NVMe tier |
| Node uniformity | All nodes in a cluster should match hardware configuration |
| Cluster minimum | 3 nodes for RF2; 5 nodes for RF3 (Nutanix recommendation) |

## Replication Factor Selection

- **RF2** -- Suitable for development, test, and non-critical workloads. Tolerates one node failure. Lower capacity overhead (2x raw).
- **RF3** -- Required for production databases, ERP systems, and workloads where a second failure during rebuild would cause data loss. Tolerates two node failures. Higher capacity overhead (3x raw) and double write I/O.
- Set RF per storage container, not per VM. Group workloads with similar criticality into the same container.

## Data Locality Optimization

- Minimize unnecessary VM migrations -- each migration disrupts data locality and causes cross-network I/O until Curator re-converges data.
- Use host affinity policies for workloads that benefit from persistent data locality (databases, analytics).
- Monitor data locality percentage via Prism analytics. Values below 80% indicate excessive migration churn.
- Curator re-convergence is a background task with lower priority than user I/O. Under heavy cluster load, re-convergence takes longer.

## Storage Container Design

- **Separate containers by workload type** -- VDI desktops, databases, and general-purpose VMs have different compression, dedup, and RF requirements.
- **Enable compression by default** -- LZ4 compression has minimal CPU overhead and typically achieves 1.5-2x savings.
- **Enable dedup selectively** -- Dedup is most effective for VDI (many similar OS images). For unique data (databases), dedup adds overhead with minimal savings.
- **Enable erasure coding for cold data** -- EC-X reduces capacity overhead for infrequently accessed data without affecting write performance.
- **Do not over-provision containers** -- Nutanix containers share the underlying storage pool. Over-provisioning one container does not reserve physical capacity but can mislead capacity planning.

## NCC Health Checks

- **Run NCC before every upgrade** -- `ncc health_checks run_all`. Never upgrade if NCC reports disk failures, CVM service issues, or cluster warnings.
- **Schedule regular NCC runs** -- Weekly NCC checks catch issues before they become outages.
- **Address warnings promptly** -- NCC warnings often indicate degraded redundancy or configuration drift that reduces fault tolerance.
- **Use targeted checks for specific issues** -- `ncc health_checks system_checks cvm_services_status_check run` for CVM health; `ncc health_checks hardware_checks disk_checks run` for disk issues.

## Upgrade Order and Rules

1. Foundation (if applicable)
2. AOS (cluster operating system)
3. AHV (hypervisor)
4. NCC (diagnostic framework)
5. Prism Central

- AOS and AHV upgrades are rolling -- one node at a time, cluster stays online.
- Use LCM (Life Cycle Manager) in Prism to manage firmware and software versions.
- Verify AOS + AHV + PC version compatibility matrix before starting.
- Never upgrade if NCC reports unresolved issues.

## Network Design

- **Bond all uplinks** -- Use LACP (802.3ad) where switch support exists; fall back to active-backup otherwise.
- **Dedicate uplinks for CVM traffic** -- CVM-to-CVM replication and iSCSI traffic should not compete with VM traffic.
- **Use VLANs for traffic isolation** -- Separate management, CVM, VM, and backup traffic.
- **10 GbE minimum for production** -- 1 GbE is insufficient for DSF replication under load.
- **25 GbE recommended** -- Modern Nutanix platforms benefit from 25 GbE for both storage and VM traffic.

## Data Protection Strategy

- **Define RPO per workload** -- Not all workloads need NearSync or Metro. Match protection level to business impact.
- **Configure remote sites before creating protection domain schedules** -- Replication fails silently without a valid target.
- **Test DR regularly** -- Use Leap test failover (non-disruptive) to validate recovery plans quarterly.
- **Monitor replication lag** -- NearSync and async DR show replication status in Prism. Alert if lag exceeds RPO target.
- **Separate replication traffic** -- Dedicate network bandwidth for async/NearSync replication to prevent impact on production traffic.

## CVM Management

- **Never power off or restart CVMs without following the proper procedure** -- Use `cvm_shutdown -P now` from within the CVM, not from the hypervisor.
- **Monitor CVM services** -- Run `genesis status` regularly. A failed Stargate or Cassandra degrades the entire cluster.
- **Use allssh for cluster-wide commands** -- `allssh "genesis status"` checks all CVMs at once.
- **Do not modify CVM networking or storage directly** -- All changes should go through Prism or ncli to maintain cluster consistency.
- **CVM password rotation** -- Change the default `nutanix` user password after initial deployment. Use `passwd` on each CVM or automate with `allssh`.

## Security Hardening

- **Enable Prism HTTPS certificates** -- Replace the self-signed Prism certificate with a CA-signed certificate for production clusters.
- **Configure RBAC in Prism Central** -- Assign least-privilege roles (Cluster Admin, User Admin, Viewer) instead of sharing the default admin account.
- **Enable Flow microsegmentation** -- Use category-based policies to enforce east-west traffic controls between application tiers.
- **Restrict CVM SSH access** -- Limit SSH access to CVMs from authorized management subnets only.
- **Enable STIG hardening** -- Nutanix provides STIG hardening scripts for AHV and CVM. Apply in regulated environments.
- **Audit log retention** -- Configure syslog forwarding from Prism to a central SIEM for compliance and forensics.

## Capacity Planning

- **Monitor cluster runway** -- Prism provides capacity runway projections based on historical growth. Review monthly and plan node additions before runway drops below 60 days.
- **Right-size VMs** -- Over-provisioned VMs waste CVM-managed resources. Use Prism analytics to identify VMs with consistently low CPU or memory utilization.
- **Plan for RF overhead** -- RF2 requires 2x raw capacity; RF3 requires 3x. Factor replication overhead into sizing from the start, not after data is stored.
- **Reserve capacity for rebuild** -- A node failure triggers data rebuild. Clusters at 80% or higher capacity cannot rebuild efficiently, extending the vulnerability window.
