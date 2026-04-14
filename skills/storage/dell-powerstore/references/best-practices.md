# Dell PowerStore Best Practices

## Volume Provisioning

### Thin Provisioning
All volumes are thin by default. Monitor consumed capacity at volume and appliance level. Set alerts at 70% consumed. Never allow 100% physical — causes I/O errors. Use capacity forecasting in PowerStore Manager or APEX AIOps.

### Naming and Organization
Convention: `<app>-<env>-<site>-<role>-<number>` (e.g., `SQL01-PROD-SITE-A-DATA-01`). Use Volume Groups for related volumes.

### Volume Groups
Enable write-order consistency for crash-consistent snapshots across members. All volumes must reside on the same appliance in multi-appliance clusters. Keep membership stable during active replication.

### Host Configuration
Do NOT use bond0 ports (ports 0/1) for direct-attached iSCSI/NVMe TCP hosts — reserved for internal node communication. Use switch-connected non-bond0 ports. Minimum 2 paths per host for multipath redundancy.

### Size Planning
Online thin expansion supported. For Metro Volume: both volumes always same size, changes must be applied to both.

## Performance Policies

| Policy | When to Use |
|---|---|
| High | Mission-critical only: OLTP databases, ERP, latency-sensitive VMs |
| Medium (default) | Most production workloads |
| Low | Archival, backup targets, dev/test, batch |

Do not assign High to all volumes — eliminates differentiation during contention. Audit quarterly as criticality changes.

## Data Protection

### Protection Policies
Create before provisioning production volumes. Layered snapshot rules: 4-hour/24h retention + daily/7d + weekly/4w. Assign same policy to all Volume Group members. Avoid manual production snapshots — use policy-driven.

### Secure Snapshots
Cannot be deleted until retention expires, including by Storage Administrators. Block (3.x+) and file (4.1+). Last line of defense — does not replace backup or replication.

### Encryption
D@RE enabled by default (FIPS 140-2). No per-volume configuration. External KMIP key management supported.

### Replication Strategy

| RPO Requirement | Solution |
|---|---|
| Zero | Metro Volume (block) or Metro File (4.3+) |
| 5-60 minutes | Native async over Ethernet or FC |
| Hours-days | Schedule-based snapshot rules |

Test failover quarterly. FC async (4.2+) eliminates need for IP replication network.

## VMware Integration

### vVols vs Traditional Datastores
vVols: per-VM storage policy via SPBM, fine-grained. VMFS/NFS: datastore-level, legacy. Create dedicated storage containers per workload tier. Register VASA through PowerStore Manager UI.

### VMFS Best Practices
VMFS-6 for new datastores (automatic UNMAP). 8-16 VMs max per datastore. Enable SIOC for noisy-neighbor throttling. Use PowerStore-specific SATP/PSP rules.

### Multipathing
iSCSI: separate VMkernel ports per NIC, jumbo frames (MTU 9000) end-to-end. FC: zone one initiator to all PowerStore targets per host, verify 4+ active paths.

### AppsON (X-Series)
Assign vSphere Enterprise Plus licenses first. Do not run storage-saturating workloads as AppsON VMs. Keep density low for edge/branch. vMotion to/from external ESXi fully supported.

## Migration from Unity/VNX

### Planning
Inventory source. Verify NTP sync. Confirm DNS, VLAN, connectivity. Allow 18-24 months for complete migration.

### Block (Universal Import)
No agents or hardware required. Online migration while production continues. Cutover: host rescan to new paths. Minutes of downtime for reconnection.

### File (NAS Import, 4.0+)
Dedicated migration interface (`nas_migration_<n>`) on source. One CIFS server per source VDM. Source locked after migration begins. Open files can block migration.

### Post-Migration
Re-enable dynamic DNS on new PowerStore NAS server (parameter set to 2). Update DNS records. Remove old zoning.

### Timeline
Weeks 1-2: discovery and planning. Week 3: configure migration interfaces. Week 4+: migrate non-critical first. Final: Tier-1 during maintenance. Post: monitor 2 weeks, decommission.
