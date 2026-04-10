# Dell PowerStore Best Practices

## Volume Provisioning

### Thin Provisioning

All volumes are thin-provisioned by default. Thin provisioning overcommits physical capacity, so maintain adequate monitoring headroom:

- Monitor consumed capacity at both the volume and appliance level
- Set capacity threshold alerts in PowerStore Manager at 70% consumed to allow time for planning
- Never allow a volume to reach 100% physical capacity — this causes I/O errors to the host
- Use capacity forecasting tools in PowerStore Manager (or Dell APEX AIOps) to project growth

### Volume Naming and Organization

- Establish a naming convention that encodes: application, environment, site, and purpose (e.g., `SQL01-PROD-SITE-A-DATA-01`)
- Use Volume Groups to logically group volumes belonging to the same application or workload
- Enable write-order consistency on Volume Groups to ensure that protection policies (snapshots, replication) apply simultaneously to all member volumes — this is the default when creating a Volume Group but verify it is selected

### Volume Groups

- All volumes in a Volume Group must reside on the same appliance within a multi-appliance cluster; if a volume is on the wrong appliance, migrate it before adding to the group
- Use Volume Groups for any workload requiring crash-consistent snapshots across multiple LUNs (e.g., database data + log volumes)
- Keep Volume Group membership stable during active replication to avoid replication consistency issues

### Block Size Alignment

- PowerStore handles block size alignment transparently; no manual alignment configuration is required for modern operating systems (Windows 2012+, RHEL 7+)
- For legacy OS environments, verify OS partition alignment to 4K boundaries before migrating

### Size Planning

- PowerStore volumes support online thin expansion; no offline resize is required
- Plan initial sizes conservatively when using thin provisioning; expand as needed
- For Metro Volume configurations, both volumes (primary and secondary) are always the same size; size changes must be applied to both

### NVMe/TCP and iSCSI Host Configuration

- For iSCSI and NVMe/TCP: do NOT use bond0 ports (ports 0 and 1 on the 4-port card) for direct-attached hosts — these ports are reserved for PowerStore internal node-to-node communication; use switch-connected ports instead
- Direct-attached iSCSI hosts connected to bond0 ports will generate ONV (Ongoing Network Validation) ICMP alerts because the nodes cannot ping each other's storage IPs
- Always use redundant paths to storage — minimum 2 paths per host, using separate physical network interfaces for multipath redundancy

---

## Performance Groups (Performance Policies)

PowerStore assigns a performance policy to every block storage resource. These policies govern I/O priority during periods of system resource contention.

### Policy Tiers

| Policy | Resource Allocation | When to Use |
|--------|---------------------|-------------|
| High | Reserves the most compute resources during contention | Mission-critical only: OLTP databases, ERP systems, latency-sensitive VMs |
| Medium (default) | Standard allocation | Most production workloads |
| Low | Fewest resources during contention | Archival, backup targets, dev/test, non-critical batch workloads |

### Best Practices for Policy Assignment

- **Do not assign High to all volumes.** High policy is most effective when reserved for a small set of critical workloads. If everything is High, no differentiation occurs during contention.
- Review policy assignments when onboarding new workloads — default Medium is appropriate for most cases
- Identify workloads with SLA-defined latency requirements and assign High explicitly; document the business justification
- Assign Low to any volume serving as a backup target, snapshot staging area, or dev/test environment
- Audit policy assignments periodically (quarterly) as application criticality changes

### Monitoring for Contention

- Use PowerStore Manager performance charts to identify periods when High-policy volumes experience elevated latency — this indicates genuine system saturation, not just policy tuning
- If High-policy volumes consistently show latency above SLA thresholds, evaluate adding an appliance to the cluster or migrating workloads

---

## Data Protection Best Practices

### Protection Policies

- Create protection policies before provisioning production volumes; assign the policy at volume creation time
- Build policies using layered snapshot rules:
  - Example: 4-hour snapshots retained 24 hours (6 recovery points in last 24 hours)
  - Example: Daily snapshots retained 7 days
  - Example: Weekly snapshots retained 4 weeks
- Avoid creating individual snapshots manually in production — use policy-driven snapshots for consistency and automation
- Assign the same protection policy to all volumes in a Volume Group to ensure consistent recovery points

### Secure Snapshots (Ransomware Protection)

- Enable secure snapshots for any workload with regulatory requirements or ransomware exposure
- Secure snapshots cannot be deleted by any user until the retention period expires, including Storage Administrators
- For block: available in PowerStoreOS 3.x+
- For file: available in PowerStoreOS 4.1+
- Consider secure snapshots as a last line of defense — they do not replace backup or replication

### Encryption (Data-at-Rest)

- D@RE (Data-at-Rest Encryption) is enabled by default on all PowerStore systems using FIPS 140-2 validated modules
- No per-volume or per-LUN configuration is required
- Drive self-encryption (SED) combined with PowerStore key management ensures that removed or failed drives cannot be read outside the system
- External key management (via KMIP-compatible servers) is supported for environments requiring centralized key control

### Replication Strategy

- For zero RPO requirements: use Metro Volume (block) or Metro File Replication (file, PowerStoreOS 4.3+)
- For RPO 5–60 minutes: use native asynchronous replication over Ethernet or Fibre Channel
- For RPO hours–days: use schedule-based snapshots with optional remote backup rules
- Test failover quarterly by performing non-disruptive failover tests to the replication destination

### Replication Transport Selection

| Scenario | Recommended Transport |
|----------|-----------------------|
| Existing FC fabric, no replication IP VLAN | FC async replication (4.2+) |
| IP replication network available | Ethernet (Dell proprietary protocol, 3.0+) |
| Metro block (zero RPO/RTO) | Ethernet required (5ms RTT max) |
| Metro file (zero RPO/RTO) | Ethernet required (4.3+) |
| NAS async replication | Ethernet or FC (4.3+) |

### Backup Integration

- PowerStore is compatible with Dell PowerProtect Data Manager (PPDM) for application-consistent backup
- PPDM can discover PowerStore volumes and volume groups for policy-based backup
- Use PPDM crash-consistent snapshot discovery for block workloads
- For VMware environments, PPDM with vProxy integration provides VM-level recovery granularity

---

## VMware Integration Best Practices

### vVols vs. Traditional Datastores

| Factor | vVols (VASA) | VMFS/NFS Datastore |
|--------|-------------|-------------------|
| Storage policy per-VM | Yes (SPBM) | No (datastore-level) |
| Snapshot granularity | Per-VM/VMDK | Per-datastore |
| Provisioning control | Fine-grained via SPBM | Coarse-grained |
| Recommended for | New deployments, greenfield | Legacy, large shared environments |

**vVols best practices:**
- Create dedicated storage containers per workload tier (Gold, Silver, Bronze) with appropriate storage policies
- Register VASA provider through PowerStore Manager UI — avoid manual vCenter-side registration (PSM handles VASA registration from PowerStoreOS 2.0+)
- Maintain one storage container per appliance to avoid cross-appliance complexity
- Use SPBM to assign vVols storage policies at VM creation time; this ensures proper QoS and data protection from day 1

### VMFS Datastore Best Practices

- Use VMFS-6 (not VMFS-5) for all new datastores — VMFS-6 supports automatic UNMAP for space reclamation
- Size VMFS datastores to host 8–16 VMs maximum to limit blast radius during datastore unavailability events
- Enable Storage I/O Control (SIOC) on datastores to throttle noisy-neighbor VMs during peak load
- Enable VAAI: confirm NMP (Native Multipath Plugin) is using PowerStore-specific SATP/PSP rules

### Multipathing for VMware

- Use PowerStore-recommended SATP and PSP rules (documented in Host Configuration Guide)
- For iSCSI: configure separate VMkernel ports for storage traffic on each NIC; use jumbo frames (MTU 9000) end-to-end
- For FC: zone one initiator to all PowerStore target ports per host; avoid single-initiator/single-target zoning
- Verify path counts in vSphere (should show at least 4 active paths per datastore for FC configurations)

### PowerStore X (AppsON) VMware Best Practices

- Assign vSphere Enterprise Plus licenses before deploying AppsON workloads
- Do not run storage-saturating workloads as AppsON VMs — heavy storage I/O from AppsON VMs competes with the 50% CPU/RAM reserved for storage services
- Keep AppsON VM density low (typically edge/branch workloads); use T-Series for high-VM-density deployments
- Use vMotion and Storage vMotion freely between PowerStore X nodes and external ESXi hosts — this is a supported, tested migration path

---

## Migration from Unity and VNX

### Planning Phase

- Inventory source system: volumes, NAS servers, CIFS servers, NFS exports, snapshots, hosts, and zoning
- Verify that the destination PowerStore has sufficient licensed capacity
- Ensure NTP synchronization between source (Unity/VNX) and destination PowerStore — clock skew causes migration failures
- Confirm all source interfaces are up, pingable, and DNS-resolvable from the destination
- All interfaces involved in migration must be on the same VLAN

### Block Data Migration (Universal Import)

PowerStore's Universal Import tool supports block migration from VNX, Unity, and any third-party array with FC or iSCSI connectivity:

- No additional hardware or agents required
- Migration can proceed while hosts continue I/O to the source (online migration)
- Cutover window is brief: host rescans new LUN paths, removes old paths
- Plan migration during low I/O periods to minimize cutover time
- Test with non-critical workloads before migrating production databases

### File Data Migration (Import from VNX/Unity)

For NAS migrations (NFS/CIFS file systems):

**Pre-migration requirements:**
- Source VDM (VNX) or NAS Server (Unity) must have a dedicated migration interface: `nas_migration_<n>`
- Migration interface must be on a different DNS domain/subdomain than the production CIFS interface
- For CIFS import: only one CIFS server per source VDM is supported — reconfigure if multiple exist
- Disable FTP services on all NAS servers involved in migration before starting
- Confirm sufficient destination capacity before starting

**Migration execution:**
- Perform during low I/O periods or consider closing application access to source file systems
- Open files can prevent full migration — coordinate with application teams
- Do not change the source array configuration once migration begins; treat the VNX/Unity as locked down
- Do not attempt to change the migration source array after the session starts

**Post-migration:**
- Re-enable dynamic DNS updates on the new PowerStore NAS server (parameter set to 2) — this setting migrates as disabled from source
- Verify CIFS shares and NFS exports are accessible from all clients before decommissioning source
- Update DNS records to point to new PowerStore file interface IPs
- Remove old zoning/masking from decommissioned source

### VNX2 Port Requirements for File Import

- FC ports on VNX2 must be online and zoned to PowerStore
- Ethernet ports used for file migration must have IP connectivity to PowerStore management and replication IPs
- Review Dell KB for current port requirements before migration (requirements vary by VNX2 model)

### Migration Timeline Recommendation

1. **Week 1–2:** Discovery and planning; run Universal Import compatibility assessment
2. **Week 3:** Configure migration interfaces on source; validate connectivity
3. **Week 4–N:** Migrate non-critical workloads; validate; migrate Tier 2 workloads
4. **Final week:** Migrate Tier 1/production workloads during scheduled maintenance window
5. **Post-migration:** Monitor for 2 weeks; decommission source after sign-off

---

## Sources

- Dell PowerStore Best Practices Guide (H18241): https://www.delltechnologies.com/asset/en-us/products/storage/industry-market/h18241-dell-powerstore-best-practices-guide.pdf
- Dell PowerStore VMware vSphere Best Practices (Scribd): https://www.scribd.com/document/743398360/h18116-dell-powerstore-vmware-vsphere-best-practices-2
- Dell PowerStore Configuring Volumes (Dell Docs): https://www.dell.com/support/manuals/en-us/powerstore-25-dae/pwrstr-cfg-vols/
- Dell PowerStore Protecting Your Data (Dell Docs): https://www.dell.com/support/manuals/en-us/powerstore-1000/pwrstr-protect-data/
- Dell PowerStore Importing External Storage Guide: https://www.dell.com/support/manuals/en-us/powerstore-9000t/pwrstr-import/
- Dell PowerStore Migration Technologies (Info Hub): https://infohub.delltechnologies.com/en-us/l/dell-powerstore-migration-technologies/
- Dell PowerStore Microsoft Hyper-V Best Practices: https://infohub.delltechnologies.com/en-us/l/dell-powerstore-microsoft-hyper-v-best-practices/
- PowerStore: Direct Attached Host iSCSI/NVMe TCP Limitation KB: https://www.dell.com/support/kbdoc/en-us/000200739/
- VASA Best Practices (Info Hub): https://infohub.delltechnologies.com/en-us/l/dell-powerstore-vmware-vsphere-best-practices-2/vasa-16/1/
