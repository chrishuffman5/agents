# Dell PowerStore Diagnostics and Troubleshooting

## Performance Monitoring

### PowerStore Manager Performance Dashboards

PowerStore Manager provides real-time and historical performance data through built-in dashboards accessible without any additional monitoring software.

**Available performance metrics:**

| Category | Metrics |
|----------|---------|
| Appliance | Total IOPS, Throughput (MB/s), Latency (avg/max), CPU utilization |
| Volume | IOPS (read/write), Throughput, Latency, Queue depth |
| File System | IOPS, Throughput, Latency, Capacity utilization |
| NAS Server | IOPS, Throughput |
| Host | IOPS, Throughput seen from storage side |
| Front-end Port | IOPS, Throughput, Link utilization |
| Node | CPU, Memory, cache hit rate |

**PowerStoreOS 4.0+ additions:**
- Volume Family Unique Data metrics (data reduction visibility per object)
- Appliance-level and cluster-level space savings metrics

**PowerStoreOS 4.1+ additions:**
- Appliance Utilization metric: consolidated single metric for workload planning
- Max Sustainable IOPS visibility per appliance
- Host offload command impact metrics (XCOPY, UNMAP, WRITE_SAME)
- Carbon footprint and energy usage metrics (integrated with APEX AIOps)

**PowerStoreOS 4.2+ additions:**
- Anomaly detection: automatic visualization of unusual performance deviations in GUI
- Port-level metrics expanded for front-end interface analysis

**PowerStoreOS 4.3+ additions:**
- Top Talkers for file: identifies highest-consuming users/applications by IOPS and bandwidth

### Performance Monitoring Best Practices

- Establish baseline performance profiles during off-peak periods immediately after deployment; use these as the reference for anomaly detection
- Monitor average latency at the volume level rather than only appliance-level; workload isolation issues appear at the volume before manifesting at appliance level
- Check max latency in addition to average — spikes in max latency with stable average indicate queue depth issues or intermittent bottlenecks
- For VMware environments, correlate PowerStore performance metrics with vSphere storage performance metrics to distinguish between storage-side and host-side issues
- Use anomaly detection (4.2+) to set automated alerts for deviations rather than relying solely on threshold-based alerts

### External Monitoring Integration

- **Dynatrace:** Native Dell PowerStore integration available in Dynatrace Hub for unified infrastructure monitoring
- **LogicMonitor:** Pre-built Dell EMC PowerStore monitoring module
- **REST API:** Full metrics available via REST API for ingestion into Prometheus, Grafana, Splunk, or custom monitoring platforms
- **Dell APEX AIOps:** Cloud-based unified monitoring across all PowerStore clusters; supports automated parallel OS updates

---

## SupportAssist

### Overview

SupportAssist is Dell's proactive support framework for PowerStore. When enabled, it transmits telemetry, health data, and alert notifications to Dell's Support Center.

**SupportAssist capabilities:**
- Automatic alert transmission when specific alert conditions are created
- Trending and predictive metrics shared with Dell Support Center
- Enables Dell Support to proactively contact customers before issues escalate
- PowerStoreOS 4.1+: ML-based proactive support predicts and prevents up to 79% of predicted issues before disruption

### SupportAssist Connectivity

**Important change (effective December 31, 2024):**
SupportAssist Direct Connect (legacy direct dial-home) is no longer supported as of December 31, 2024. All PowerStore clusters must use the **Secure Connect Gateway (SCG)** for SupportAssist connectivity.

**Current connectivity path:**
PowerStore Manager > Settings > Support Connectivity > configure SCG gateway appliance

**SCG DNS requirements:**
PowerStoreOS 4.x SupportAssist enablement health checks include:
- DNS resolution of SupportAssist backend server hostnames
- Direct HTTPS access to SupportAssist backend (or SCG proxy access)
- If PowerStore has no external DNS or no direct access to Dell backend servers, the SupportAssist health check will fail — configure DNS and firewall rules accordingly

**Troubleshooting SupportAssist enablement failure on 4.x:**
1. Verify DNS resolution from PowerStore management nodes: confirm `ping` and `nslookup` to SupportAssist endpoints work
2. Check firewall rules — PowerStore must reach Dell's SupportAssist backend IPs on HTTPS (TCP 443)
3. If using SCG proxy, verify SCG is registered and reachable from PowerStore management interfaces
4. Known issue: SupportAssist enablement via SCG may fail if DNS check fails — see Dell KB 000251599

### Disabling SupportAssist Notifications for Planned Maintenance

During planned maintenance windows, disable SupportAssist notifications to prevent false-positive support cases:

**Path:** PowerStore Manager > Settings > Support > Disable Notifications

Specify the maintenance window duration. Re-enable notifications after maintenance completes. Failing to disable notifications during planned maintenance (e.g., planned node shutdown, drive replacement, NDU) will generate automatic support cases with Dell.

---

## Alert Management

### Alert Severity Levels

PowerStore uses a tiered alert severity model:

| Severity | Description | Action Required |
|----------|-------------|-----------------|
| Critical | Immediate risk to data availability or system function | Immediate intervention |
| Major | Significant degradation; potential risk if unaddressed | Prioritized intervention |
| Minor | Degraded redundancy; no immediate data risk | Plan resolution |
| Informational | System events, configuration changes, completed operations | Review only |

**Maintenance and upgrade rule:**
- Do NOT perform maintenance operations or Non-Disruptive Upgrades (NDU) when active Critical or Major alerts are present
- Resolve or acknowledge all Critical/Major alerts before initiating any NDU

### Alert Categories

**Common alert categories in PowerStore:**

1. **Drive fault tolerance (Data Path Tier Health):**
   - Triggered when drives fail and RAID/protection level is reduced
   - Alert stays active until failed drive is replaced and rebuild completes
   - KB reference: Dell KB 000221123

2. **SSD offline/failed:**
   - System Health Check detects offline or failed SSDs separately from drive fault tolerance
   - KB reference: Dell KB 000207485

3. **Cluster monitoring alerts:**
   - Appliance add/remove, node shutdown, cluster membership changes
   - KB reference: Dell KB 000182004

4. **Remote Support / SupportAssist alerts:**
   - SupportAssist connectivity failures
   - KB reference: Dell KB 000126457

5. **ONV (Ongoing Network Validation) alerts:**
   - Generated when nodes cannot ICMP ping each other's storage IPs
   - Common cause: direct-attached hosts on bond0 ports (iSCSI/NVMe TCP bond0 restriction)
   - Resolution: move host connections to non-bond0 ports or accept alert as informational for direct-attach topologies

### Alert Notification Configuration

PowerStore Manager supports multiple notification methods:

- **Email (SMTP):** Configure SMTP server, recipients, and alert severity filter
  - PowerStoreOS 4.2+: Secure SMTP with StartTLS supported for compliance
- **SNMP traps:** For integration with enterprise NMS platforms
- **SupportAssist:** Automatic transmission to Dell Support Center
- **REST API webhooks:** Custom integrations via polling or webhook mechanisms

**Best practice:** Configure at minimum two notification recipients; use a distribution list rather than individual email addresses to avoid alert loss during personnel changes.

---

## System Health Checks

### On-Demand Health Checks

Health checks can be initiated manually from PowerStore Manager:

**Path:** PowerStore Manager > Monitoring > System Checks > Run System Check

Health checks evaluate:
- Drive health and RAID rebuild status
- Node hardware (power supplies, fans, memory, CPUs)
- Network interface status and connectivity
- Software service status (container health)
- SupportAssist connectivity (4.x)
- Certificate validity and expiration

**When to run health checks:**
- Before any NDU (Non-Disruptive Upgrade) — run pre-upgrade health check
- Before planned maintenance (node shutdown, drive replacement)
- After any alert cluster event (add/remove appliance)
- Periodically as part of monthly administrative review

### Health Check Packages (Off-Release)

Dell periodically releases Health Check thin packages for issues discovered post-release that are not yet captured by integrated checks:

- Delivered as installable packages to PowerStore Manager
- Contains checks invoked during pre-upgrade health check and on-demand system check
- Download from Dell Support under: PowerStore > System Health Check Packages (KB 000214752)
- Install health check packages before any planned NDU in production environments

### Pre-Upgrade Health Check

Before every NDU:

1. Download the latest health check package for the target PowerStoreOS version
2. Install the package via PowerStore Manager
3. Run the pre-upgrade health check: Settings > Software > Upgrade > Run Upgrade Extensions
4. Resolve any Critical or Major findings before proceeding
5. Warning-state results for pre-upgrade health checks may not be intuitively obvious in the UI — check KB 000130130 for guidance on interpreting warning states

**For clusters with 3+ appliances upgrading to PowerStoreOS 4.1:** See KB 000286668 for specific pre-upgrade requirements.

---

## Connectivity Troubleshooting

### iSCSI Connectivity Issues

**Symptom:** Hosts cannot discover iSCSI targets or lose connectivity intermittently

**Diagnostic steps:**
1. Verify iSCSI target portal IPs are reachable from host: `ping <target-ip>` from host
2. Check that iSCSI initiator IQN is registered in PowerStore Manager under the host definition
3. Confirm iSCSI CHAP settings match between host and PowerStore if CHAP is configured
4. Verify VLAN tagging is consistent between host NIC, switch port, and PowerStore port
5. Check MTU consistency — if jumbo frames (9000 MTU) are configured on PowerStore, all network hops must support 9000 MTU end-to-end
6. Confirm iSCSI ports are not bond0 ports for direct-attached hosts (bond0 restriction)
7. Review PowerStore Manager > Hardware > Appliance > Network Ports for port link status

**Multipath verification on Linux:**
```
multipath -ll
# Expect at least 2 active paths per LUN; all paths should be "active ready"
```

**Multipath verification on Windows:**
```
mpclaim -s -d
# Verify MPIO paths are present and active
```

### Fibre Channel Connectivity Issues

**Symptom:** Hosts cannot see LUNs or FC paths are missing

**Diagnostic steps:**
1. Verify FC zoning in the fabric switch — each host HBA WWPN should be zoned to the PowerStore target ports
2. Check host definition in PowerStore Manager: confirm the correct HBA WWPNs are registered
3. Verify FC port status in PowerStore Manager > Hardware > Appliance > FC Ports (should show "Up" with login count)
4. Run a fabric login check from the host:
   - Linux: `systool -c fc_host -v | grep port_name`
   - Windows: Check Device Manager > Fibre Channel Adapters > Port properties
5. Confirm LUN masking — the host group must include the host and be mapped to the volume or volume group
6. On VMware: rescan HBAs in vSphere client; check storage adapter paths

**Zoning best practice validation:**
- One initiator WWPN per zone
- All PowerStore target ports for the relevant fabric in the same zone as the initiator
- Verify no stale zones from decommissioned arrays are interfering

### NVMe-oF (NVMe/TCP and NVMe/FC) Issues

**Symptom:** NVMe namespaces not visible to host

**Diagnostic steps:**
1. Verify unique NQN (NVMe Qualified Name) on each host — duplicate NQNs cause connection failures in Kubernetes/OpenShift environments
2. Confirm `nvme-cli` is installed and the nvme kernel modules are loaded on Linux hosts
3. Check NVMe discovery: `nvme discover -t tcp -a <target-ip> -s 4420`
4. Verify NVMe subsystem NQN matches between PowerStore configuration and host connect command
5. For NVMe/FC: confirm FC zoning is complete (same as FC block) and NVMe FC driver is loaded
6. Check that PowerStore NVMe/TCP ports are not bond0 ports

**Linux NVMe path check:**
```
nvme list
nvme list-subsys
```

### Network Validation Alerts (ONV)

**Symptom:** PowerStore generates ICMP connectivity alerts between nodes

**Cause:** Direct-attached iSCSI or NVMe/TCP hosts connected to bond0 ports prevent nodes from reaching each other's storage IPs via ICMP.

**Resolution options:**
1. Move direct-attached host connections to non-bond0 ports
2. If bond0 direct-attach is required for a specific reason, acknowledge the ONV alert as informational and document the exception

### SSD Failure and Drive Replacement

**Symptom:** Drive fault tolerance alert, SSD offline alert

**Diagnostic steps:**
1. Identify failed drive in PowerStore Manager > Hardware > Appliance > Drives (failed drive shown with red indicator)
2. Note the drive slot location from the UI before physically accessing the array
3. Confirm drive replacement procedure from PowerStore hardware guide — most drives are hot-swappable
4. After physical replacement, monitor PowerStore Manager for rebuild progress (shown as % in drive status)
5. Do NOT initiate NDU during active drive rebuild — wait for rebuild to complete

**Drive rebuild monitoring:**
- PowerStore Manager > Hardware > Appliance > Drives > select drive > view rebuild status
- Rebuild time depends on drive capacity and system I/O load; expect 2–6 hours for typical NVMe drives under light load

---

## Log Collection and Diagnostics Package

### Collecting Diagnostics

For escalated issues requiring Dell Support analysis:

**Path:** PowerStore Manager > Settings > Support > Collect Diagnostics

This collects:
- System logs from all nodes
- Configuration snapshots
- Performance data from recent period
- Hardware event logs

Alternatively, Dell SupportAssist (when connected) can collect and transmit diagnostics automatically when a support case is opened.

### Key Log Locations (accessed via Dell Support or service engagement)

- Node kernel logs: `/var/log/messages`
- PowerStoreOS container logs: via Docker log collection (requires service access)
- Audit logs: PowerStore Manager > Settings > Security > Audit Log

---

## Sources

- Dell PowerStore Monitoring Your System (v4.3, December 2025): https://dl.dell.com/content/manual60020558-dell-emc-powerstore-monitoring-your-system.pdf?language=en-us&ps=true
- Dell PowerStore Monitoring Your System (Dell Docs online): https://www.dell.com/support/manuals/en-us/powerstore-3000/pwrstr-monitoring/
- PowerStore Alerts - Remote Support: https://www.dell.com/support/kbdoc/en-us/000126457/powerstore-alerts-remote-support-alerts
- PowerStore Alerts - Cluster Monitoring: https://www.dell.com/support/kbdoc/en-us/000182004/powerstore-alerts-cluster-monitor-appliance-add-remove-shutdown
- PowerStore Alerts - Drive Fault Tolerance: https://www.dell.com/support/kbdoc/en-us/000221123/powerstore-alerts-victory-data-path-tier-health
- PowerStore SupportAssist Direct Connect End-of-Life: https://www.dell.com/support/kbdoc/en-us/000222594/powerstore-supportassist-direct-connect-support-ending-on-dec-31-2024
- PowerStore SupportAssist SCG Enablement Issue (KB 000251599): https://www.dell.com/support/kbdoc/en-us/000251599/powerstore-supportassist-enablement-fails-on-v4-over-secure-connect-gateway-due-to-dns-check
- PowerStore System Health Check How-To: https://www.dell.com/support/kbdoc/en-us/000198084/powerstore-how-to-use-the-system-health-check-feature
- PowerStore System Health Check Packages (Landing Page): https://www.dell.com/support/kbdoc/en-us/000214752/powerstore-landing-page-for-system-health-check-packages
- PowerStore Pre-Upgrade Health Check: https://www.dell.com/support/kbdoc/en-us/000192601/powerstore-using-the-run-upgrade-extensions-feature-before-starting-a-powerstoreos-upgrade
- PowerStore Active Alerts Detected by Health Checks: https://www.dell.com/support/kbdoc/en-us/000192609/powerstore-active-alerts-were-detected-by-svc-hcs
- PowerStore Direct Attached Host iSCSI/NVMe Restriction: https://www.dell.com/support/kbdoc/en-us/000200739/
- PowerStore: SSD Offline/Failed Health Check: https://www.dell.com/support/kbdoc/en-us/000207485/
- Dynatrace Dell PowerStore Integration: https://www.dynatrace.com/hub/detail/dell-powerstore/
- LogicMonitor Dell EMC PowerStore Monitoring: https://www.logicmonitor.com/support/dell-emc-powerstore-monitoring
