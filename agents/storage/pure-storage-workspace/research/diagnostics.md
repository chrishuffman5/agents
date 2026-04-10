# Pure Storage FlashArray Diagnostics and Troubleshooting

## Overview

Pure Storage FlashArray operates with a "call-home" telemetry model — every connected array continuously streams diagnostic data to Pure1. Pure Support has deep visibility into array health before most customers are aware of issues. Approximately 70% of issues are proactively resolved by Pure1 before they cause downtime. This document covers monitoring tools, common issue categories, diagnostic procedures, and remediation paths.

---

## Pure1 Monitoring Platform

### Accessing Pure1
- URL: https://pure1.purestorage.com
- Mobile app: "Pure 1" on iOS App Store and Google Play
- All FlashArrays with outbound internet access (port 443 HTTPS to Pure's cloud endpoints) automatically register and report
- Authentication: Pure1 uses SSO/SAML integration; admin user accounts managed in Pure1 portal

### Dashboard Overview
The Pure1 global dashboard provides:
- Fleet-wide status: all arrays across all sites in one view
- Per-array tiles showing: performance (IOPS, latency, bandwidth), capacity (used, available, effective), health status
- Alert feed: active alerts sorted by severity (critical, warning, info)
- Support cases: open cases linked to alerts
- Replication status: pod health, lag metrics, mediator state

### Array-Level Performance Dashboards
Drill into an individual array for:
- Real-time IOPS (read/write split)
- Latency histograms (average, 95th percentile, 99th percentile)
- Bandwidth (MB/s read/write)
- Queue depth
- Data reduction ratio (current and 30-day trend)
- Capacity breakdown (unique data, dedup savings, compression savings, snapshots)

### Historical Analysis
- Up to 1 year of performance history stored in Pure1
- Trend charts for capacity forecasting (Workload Planner overlays growth projections)
- Event timeline overlay: correlate performance anomalies with events (snapshot schedules, replication, controller events)

---

## Pure1 Meta AIOps Alerts

### Alert Types and Severity Levels
| Severity | Description | Action Required |
|----------|-------------|-----------------|
| Critical | Immediate risk to data availability or performance | Pure Support notified automatically; investigate immediately |
| Warning | Degraded but operational state; risk of escalation | Review within hours; follow remediation steps |
| Info | Advisory; no immediate risk | Review during next maintenance window |

### Proactive Issue Detection
Pure1 Meta uses ML models trained on the global fleet to detect:
- **Hardware degradation:** DFM wear indicators, controller component failure prediction, fan/power anomalies
- **Capacity trending:** Projects when arrays will reach capacity thresholds
- **Replication health:** Detects replication lag trends before they exceed SLA thresholds
- **Performance anomalies:** Detects latency spikes and bandwidth saturation ahead of user-reported impact
- **Software faults:** Purity OS crash risk detection based on pattern matching against known failure signatures

When a potential problem is identified, Pure1 automatically:
1. Generates an alert in the Pure1 dashboard
2. Opens a support case with Pure Support
3. Attaches relevant telemetry to the case
4. Notifies the array admin via email (if email notification configured)

### Pure1 Security Assessment
- Dedicated security posture dashboard in Pure1
- Checks SafeMode configuration coverage: which volumes are protected, which are not
- Verifies Purity version currency: flags arrays on old versions with known security fixes pending
- Recommends snapshot policy configurations and eradication delay settings
- Updated continuously; review quarterly at minimum

---

## Performance Troubleshooting

### High Latency Investigation

**Step 1: Determine scope**
- Is latency elevated on one volume, one host, or all volumes?
- Check Pure1 performance dashboard: filter by volume, host, or protocol
- Compare latency on affected volumes vs. unaffected volumes at the same time

**Step 2: Check host-side vs. array-side latency**
- Pure1 shows array-side latency (from when I/O enters the array to when it is acknowledged)
- If array latency is normal but application latency is high, the issue is on the host side (HBA queue depth, driver, multipath configuration, OS scheduling)
- If array latency is elevated, investigate the array

**Step 3: Array-side latency causes**
- **High queue depth:** More I/Os in flight than the array can service simultaneously; check if a specific volume or host is generating abnormal I/O volume
- **Data reduction pressure:** Unusual data patterns reducing effectiveness of dedup/compression; check data reduction ratio trend
- **Replication impact (rare):** ActiveCluster synchronous writes can add latency if inter-array network latency is at the limit (approaching 11ms RTT); check replication network metrics
- **DFM health:** A degraded DFM forces I/Os to rebuild from parity; check component health for any DFMs in rebuilding state

**Step 4: Use Pure1 VM Analytics**
- If workload is virtualized, use VM Analytics to correlate VM-level I/O with array-level performance
- Identify VMs generating disproportionate I/O
- Check for VM balloon memory pressure causing swap I/O

### IOPS Saturation
- Review the array's maximum IOPS specification vs. current utilization
- Identify top consumers via Pure1's "Top Volumes" and "Top Hosts" views
- If a single volume is dominating, consider setting an explicit per-volume IOPS limit temporarily
- For sustained saturation: engage Pure1 Workload Planner to model controller or DFM expansion

### Bandwidth Saturation
- Check front-end (host-to-array) port utilization in Pure1
- Verify multipath is active: saturating one path while another is idle indicates multipath misconfiguration
- Check back-end (array-to-DFM) bandwidth — internal saturation is rare but possible during rebuilds

---

## Connectivity Issues

### Host Cannot See Array Volumes

**Fibre Channel:**
1. Verify zoning: initiator WWPN must be in a zone with at least one array target WWPN
2. Check host group and volume connections: `purehost list --connect` on the array CLI
3. Verify FC fabric login: check array FC port login events in Pure1 event log
4. Check host HBA driver version — out-of-date HBA drivers are a common source of FC connectivity issues
5. Verify ALUA mode is active on host-side multipath; check TPGS settings

**iSCSI:**
1. Verify iSCSI target IQN discovery: `iscsiadm -m discovery -t st -p <array-ip>` on Linux
2. Check iSCSI portal reachability: ping from host to array iSCSI IP on data VLAN (not mgmt VLAN)
3. Verify MTU consistency — jumbo frame mismatch (host 9000, switch 1500) silently breaks iSCSI at larger transfer sizes
4. Check CHAP credentials if enabled — mismatch causes authentication failure without clear error on host
5. Verify host is logged in: `iscsiadm -m session` should show active sessions to array portals

**NVMe/TCP:**
1. Verify NVMe/TCP initiator is installed and enabled: `nvme list` on Linux
2. Discover targets: `nvme discover -t tcp -a <array-ip> -s 4420`
3. Verify MTU — NVMe/TCP is sensitive to MTU mismatches like iSCSI
4. Check Purity version supports NVMe/TCP (6.4.2+ for default support)

### Array Not Appearing in Pure1
- Verify outbound HTTPS (port 443) connectivity from array management interface to `pure1.purestorage.com`
- Check proxy configuration if the management network uses an HTTP proxy: `purearray list --proxy`
- Verify DNS resolution from array management interface
- Re-register array: contact Pure Support to reset Pure1 registration token if needed

---

## Replication Lag and ActiveCluster Issues

### Checking Replication Status

**Via Pure1 (recommended):**
- Navigate to Pure1 > Replication tab
- Active Replication Monitoring shows:
  - Pod status (synced / syncing / degraded / suspended)
  - Cloud Mediator state (connected / disconnected)
  - ActiveDR lag (seconds behind source)
  - FlashBlade object replication lag

**Via CLI:**
```
# Check pod status
purepod list

# Check replication performance
purepod replica list

# Check mediator connectivity
purepod mediator test --name <pod-name>
```

### ActiveDR Lag Investigation
- Normal lag: seconds (continuous replication, no schedule)
- Elevated lag (minutes+): investigate:
  1. Replication network bandwidth: is the link saturated? Check Pure1 replication port metrics
  2. High write rate on source: is the source writing faster than the WAN link can carry?
  3. Network quality: packet loss or retransmissions on replication network cause lag accumulation
  4. Remote array under load: if target array is busy, it processes incoming replication writes slower

**Remediation for sustained lag:**
- Reduce replication bandwidth consumption by deferring large bulk writes during peak hours
- Increase replication network bandwidth (add interfaces or upgrade uplinks)
- If lag exceeds RPO SLA, notify application owner and document in incident log

### ActiveCluster Pod Degraded State
A pod enters "degraded" state when the two arrays cannot maintain full synchronization:
- One array may have become temporarily unreachable
- Replication network may have experienced a transient failure
- The pod continues serving I/O from the remaining array (zero RTO achieved)

**Recovery steps:**
1. Check Pure1 for the triggering event: which array went offline, when, and for how long
2. Once both arrays are healthy and connected, pod resync begins automatically
3. Monitor resync progress: `purepod list` shows sync percentage
4. Verify mediator connectivity after resync: `purepod mediator test`

### ActiveCluster Split-Brain Scenario
If both arrays lose mediator connectivity simultaneously:
- Arrays use pre-election results from Purity 5.3+ mediator polling to agree on a winner
- One pod continues I/O; the other suspends to prevent divergent writes
- After mediator connectivity is restored, the suspended pod resyncs automatically
- Do not manually force-unsuspend a pod during mediator outage without confirming which array has the current data

### Planned Failover Testing
```
# Test failover (non-destructive, replication continues)
purepod failover --name <pod-name>

# Verify pod is serving from target array
purepod list

# Fail back
purepod failover --name <pod-name>
```

---

## Array Health and Component Monitoring

### Hardware Component States
- **Healthy:** Normal operation
- **Degraded:** Component is functioning but at reduced reliability (e.g., DFM nearing wear threshold)
- **Failed:** Component is offline; array is running on remaining redundancy
- **Rebuilding:** Array is reconstructing data onto a replacement component

Check via Pure1 (Hardware tab on array detail) or CLI:
```
puredrive list
purehw list
```

### DFM (DirectFlash Module) Health
- DFMs report wear indicators continuously to Purity and Pure1
- Pure1 generates predictive alerts before DFM failure — typically 30-90 days ahead
- When a DFM fails: array automatically begins reconstruction using RAID parity
- Reconstruction time depends on array load and DFM capacity — monitor via Pure1 rebuild progress
- Do not insert new DFMs without Pure Support guidance during a rebuild

### Controller Health
- Dual controllers provide active/active operation; one controller can fail with zero impact on I/O
- Controller failover is automatic and transparent (part of NDU design)
- If a controller fails: Pure1 generates an alert and Pure Support opens a case automatically
- Controller replacement is performed by Pure Support field engineers under the Evergreen support model

### Environmental Monitoring
- Temperature, fan speed, and power supply status visible in Pure1 Hardware tab
- Alerts trigger when temperature approaches thermal limits
- Pure1 predictive analytics detect fan degradation trends before failure

---

## Support and Case Management

### Automatic Case Opening
- Pure1 opens support cases automatically for critical and warning-level hardware alerts
- Cases include: array serial number, error codes, relevant telemetry snapshot, recommended action
- Admin receives email notification for each case opened

### Manual Case Creation
- Open via Pure1 > Support > Cases > New Case
- Provide: array serial number (or let Pure1 pre-populate), symptom description, business impact, and desired resolution timeframe
- For P1 (production down): call Pure Support directly; do not rely solely on portal case creation

### Log Collection
- Pure1 has already collected logs continuously — Support can pull historical logs without requiring a log bundle from the admin
- If Support requests a local log bundle: `purearray phonehome` triggers an immediate upload of current logs
- For offline arrays: `purearray export log` generates a local bundle for manual upload

### Purity Upgrade Process
- Upgrades managed through Pure1: navigate to array > Actions > Upgrade
- Pure1 shows available Purity versions and validates compatibility before allowing upgrade
- Upgrade is non-disruptive (NDU) — controllers upgrade one at a time; I/O continues
- Schedule upgrades during low-activity windows as a best practice even though NDU guarantees availability
- Pure1 validates all prerequisites (replication state, pod health, component health) before initiating upgrade

---

## Common Issues Quick Reference

| Symptom | First Check | Common Cause |
|---------|-------------|--------------|
| High application latency | Pure1 latency chart: array-side vs. host-side | Host multipath misconfiguration; HBA queue depth |
| Volume not visible to host | Zoning (FC) or iSCSI discovery; host group connection | Missing zone; volume not connected to host |
| ActiveDR lag growing | Replication network bandwidth; source write rate | WAN saturation; peak write burst |
| ActiveCluster pod degraded | Pure1 event log; network between arrays | Replication network failure; array unreachable |
| Array not in Pure1 | Port 443 outbound; DNS; proxy config | Firewall blocking Pure1 call-home |
| Data reduction ratio dropping | Workload data compressibility change | Encrypted data or pre-compressed data being written |
| Snapshot schedule missed | Protection group state; array events | Array overloaded; storage low; schedule conflict |
| Purity upgrade failed | Pure1 upgrade pre-check report | Unhealthy component; replication out of sync |
| iSCSI sessions dropping | MTU consistency; network interface errors | Jumbo frame mismatch; NIC driver issue |
| SafeMode lock cannot release | By design — only Pure Support can release | Requires identity verification call to Pure Support |

---

## References
- Pure1 AIOps: https://www.purestorage.com/products/aiops/pure1.html
- Pure1 Troubleshooting Demo: https://www.purestorage.com/demos/platform/managing-at-scale/pure1-troubleshooting/6365163371112.html
- FlashArray Performance Monitoring Deep Dive: https://www.purestorage.com/demos/platform/what-is-the-pure-storage-platform/flasharray-technical-walkthrough-part-3/6368218905112.html
- SafeMode Recovery: https://blog.purestorage.com/products/ransomware-pure-storage-flasharray/
- SolarWinds Storage Resource Monitor for Pure: https://www.solarwinds.com/storage-resource-monitor/use-cases/pure-storage-monitoring
- eG Innovations FlashArray Monitoring: https://www.eginnovations.com/documentation/Pure-Storage/Monitoring-Pure-Storage-FlashArray.htm
- ActiveCluster Configuration Validation: https://www.purestorage.com/products/storage-software/purity/active-cluster.html
- Active Replication Monitoring (Pure1): https://www.purestorage.com/products/aiops/pure1/optimize.html
- Pure1 Security Assessment 2025: https://blog.purestorage.com/purely-technical/pure1-data-protection-assessment-tool/
