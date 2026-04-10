# HPE Alletra Diagnostics

## InfoSight Predictive Analytics

### Overview

HPE InfoSight is the primary diagnostic and analytics platform for all Alletra models. It is a cloud-hosted service that ingests telemetry from all connected HPE systems and applies machine learning to predict and prevent issues before they cause downtime.

**Data Scale:**
- Collects and analyzes data from 100,000+ HPE storage systems worldwide, every second
- Cross-system learning: patterns identified on one customer's system benefit all other connected systems
- HPE Alletra Storage MP B10000 uses a high-frequency metric telemetry framework for enhanced AI/ML analytics

**Access:**
- InfoSight portal: https://infosight.hpe.com
- Integrated into HPE GreenLake's Data Services Cloud Console (DSCC) for Alletra MP systems
- HPE InfoSight mobile app for on-call monitoring

---

### InfoSight Dashboard Views

**Operational Dashboard (Alletra 5000/6000/Nimble-lineage):**
- Quick view of array health, performance, and system status
- Performance per array, per volume, and per VM/application
- Capacity trends with 30/90-day forecasts
- Active alerts with severity classification (Critical, Warning, Informational)

**Wellness Dashboard (Alletra MP B10000/GreenLake):**
- Signature-based wellness automation continuously analyzes telemetry
- Proactive issue detection with prescriptive remediation steps
- Wellness events categorized by system component (controller, drives, network, software)
- Direct link to open HPE support cases from wellness event detail pages

**VM Analytics (requires InfoSight for VMware integration):**
- Per-VM storage latency, IOPS, and throughput breakdown
- Identify which specific VMs are generating high I/O load
- Correlate VM storage performance with host compute metrics
- Hyper-V environment monitoring supported for Alletra 5000/6000

**Cross-Stack Analytics:**
- Correlates storage metrics with server and network telemetry
- Identifies whether application latency is caused by storage, compute, or network
- Requires HPE InfoSight agents on VMware hosts or Hyper-V hosts

---

### Predictive Analytics Capabilities

**Drive Failure Prediction:**
- InfoSight's ML models predict drive failures days to weeks in advance based on SMART data, error logs, and historical failure patterns across the global fleet
- When a drive is flagged as high-risk, InfoSight creates a proactive support case and schedules a drive replacement before failure
- HPE ships replacement drives proactively in most cases — the customer often receives a replacement before the original fails

**Capacity Exhaustion Forecasting:**
- Growth trend modeling projects when pools will reach capacity thresholds
- Configurable alert thresholds (default: warning at 70%, critical at 80%)
- Linked to GreenLake ordering workflows for as-a-service environments

**Performance Anomaly Detection (MP B10000):**
- ML-based anomaly detection on high-frequency sensor data
- Flags unusual latency spikes, throughput drops, or IOPS pattern deviations
- Correlates anomalies with array events (firmware updates, node restarts, replication activity)
- Prescriptive remediation: InfoSight recommends specific configuration changes, not just flags the issue

**Controller and Component Health:**
- Fan speed, temperature sensor, power supply, and controller health monitored continuously
- Environmental issues (data center cooling failures, power instability) detected and correlated with hardware stress indicators
- Non-critical degradation alerts provide lead time before failures affect availability

---

## Array Health Checks

### Alletra 9000 / Primera CLI Commands

Access via SSH to the array management IP.

```bash
# Check overall system health
showsys -d

# Check controller node status (all nodes)
shownode -s

# Display all alerts and system messages
showalert -n 20

# Check drive/volume status
showvv -state

# Review cage/shelf drive layout and health
showcage -d

# Check replication Remote Copy Group status
showrcopygroup

# Check replication link status
showrcopytarget

# Display port status (FC and iSCSI)
showport -state

# Check system performance counters (live)
statport -iter 5 -interval 2
```

**What to Look For:**
- `showsys -d`: any component showing `degraded`, `failed`, or `faulted` state
- `shownode -s`: all nodes should show `OK`; any node in `service` state requires immediate attention
- `showalert`: review for unacknowledged alerts; investigate `FATAL` and `CRITICAL` severity first
- `showrcopytarget`: verify `link_state` is `Up` and `options` match expected configuration

---

### Alletra 6000 / Nimble CLI Commands

Access via SSH to the array management IP (`admin` user).

```bash
# Array health summary
array --info

# Volume status
vol --list

# Shelf and disk status
shelf --list
disk --list

# Performance stats (live, 5-second intervals)
perf --array --count 10 --interval 5

# Network connectivity and iSCSI
network --list
iscsi --list

# Replication partner status
partner --list
vol --replication

# Active alerts
event --list --severity critical,warning
```

**What to Look For:**
- `array --info`: check `status` field — should be `normal`; `degraded` requires immediate investigation
- `disk --list`: any disk in `failed` state needs replacement; `spare` drives should exist
- `partner --list`: replication partners should show `reachable: yes`

---

### Alletra Storage MP B10000 CLI and DSCC

**DSCC (Primary Management Interface):**
- Navigate to: HPE GreenLake cloud console → Storage → your array
- Inventory: shows all hardware components and status
- Performance charts: real-time and historical IOPS, latency, throughput per array and per volume
- Issues tab: hardware alerts, wellness events, and software notifications

**CLI (SSH — for advanced diagnostics):**
```bash
# Show system health (all components)
showsys -d

# Show controller nodes
shownode -s

# Show port states
showport -state

# Show alerts
showalert -n 50

# Show active I/O statistics per port
statport -iter 5 -interval 2
```

Note: The Alletra MP B10000 uses the same base CLI syntax as Alletra 9000/Primera for many hardware-level queries.

---

## Performance Issue Diagnostics

### Step 1: Identify the Symptom

| Symptom | First Check |
|---------|-------------|
| Application reports high latency | InfoSight → Performance → Volume latency graph |
| Specific VMs slow | InfoSight → VM Analytics → Per-VM latency |
| Throughput lower than expected | InfoSight → Performance → Array throughput |
| Backup jobs running slow | Check snapshot schedule conflicts; check StoreOnce replication throughput |
| Inconsistent performance (spikes) | Check for competing noisy-neighbor volumes; review QoS settings |

### Step 2: Determine Scope

- **Single volume affected**: likely workload-specific issue, performance policy misconfiguration, or QoS cap hit
- **Multiple volumes on same pool**: pool saturation, cache miss ratio, or drive failure reducing pool performance
- **Entire array affected**: controller saturation, network congestion, or hardware degradation
- **All arrays in group affected**: group-level replication traffic, network issue, or group management overhead

### Step 3: InfoSight Analysis

1. Log into InfoSight portal → select the affected array
2. Open the Performance section → set time range to capture the incident window
3. Review: IOPS, throughput, latency, queue depth, and cache hit ratio
4. Cross-reference with Events timeline: look for hardware events, firmware updates, or replication state changes that coincide with the performance degradation
5. Review the "Recommendations" section: InfoSight often identifies the root cause automatically

### Step 4: Host-Side Verification

```bash
# Linux: check multipath path health
multipath -ll

# Linux: check queue depth and I/O latency at the device level
iostat -x -d 2 10

# Linux: verify iSCSI session status
iscsiadm -m session -P 3

# Windows: check MPIO paths
mpclaim -s -d

# VMware: check storage adapter path status
esxcli storage nmp path list
```

### Step 5: Resolve or Escalate

**Resolvable without HPE Support:**
- QoS cap hit: increase `limitIops` or `limitMbps` on the volume
- Pool saturation: expand pool capacity or migrate hot volumes to a higher-tier array
- Cache miss ratio low: increase cache tier if possible, or accept the workload needs a higher-tier platform
- Noisy neighbor: apply QoS limits to the disruptive volume

**Requires HPE Support:**
- Controller hardware fault detected in `shownode` output
- Persistent drive errors beyond RAID tolerance
- Replication sync failures not resolved by resetting the RCG
- Unexplained latency not explained by workload or hardware

---

## Connectivity Troubleshooting

### iSCSI Connectivity

**Common Issues:**
- Host cannot discover array iSCSI targets
- iSCSI sessions drop intermittently
- High iSCSI error rate in array logs

**Diagnostic Steps:**

```bash
# Verify array iSCSI port IP and status
iscsi --list                          # Nimble/Alletra 6000
showport -iscsi                       # Alletra 9000 / B10000

# From Linux host: test discovery
iscsiadm -m discovery -t sendtargets -p <array_ip>

# Check active sessions
iscsiadm -m session -P 3

# Verify jumbo frames are consistent (if enabled)
ping -M do -s 8972 <array_ip>        # Linux: tests 9000-byte MTU path

# Check for dropped iSCSI packets
netstat -s | grep -i retransmit
```

**Resolution Checklist:**
- Jumbo frames (MTU 9000) configured consistently on all components (array ports, switches, host NICs)
- iSCSI NICs are on dedicated VLANs (no mixing with general network traffic)
- Flow control enabled on switch ports (pause frames or PFC)
- Host multipath software (DM-Multipath) configured with `round-robin` for active-active arrays
- Check that iSCSI initiator IQN is registered in the array access list

---

### Fibre Channel Connectivity

**Common Issues:**
- Host cannot see array LUNs
- Intermittent path failures
- Login failures in fabric logs

**Diagnostic Steps:**

```bash
# On array: check FC port status
showport -state             # Alletra 9000 / B10000
array --info | grep -A5 fc  # Alletra 6000

# Verify host WWNs are in the correct zone
showhost                    # Alletra 9000: shows registered hosts and paths

# Check zone membership from FC switch (Brocade example)
zoneshow "your_zone_name"

# On Linux host: check HBA port status
cat /sys/class/fc_host/host*/port_state
cat /sys/class/fc_host/host*/port_name  # shows host WWN

# Check path state
multipath -ll | grep -E 'status|state'
```

**Resolution Checklist:**
- Single-initiator/single-target zoning (not broad zones)
- Host WWN registered on the array (in access list / host definition)
- Array target WWN present in the fabric zone
- No duplicate WWNs in the fabric (can cause fabric login conflicts)
- ISL (inter-switch links) not saturated if array and host are on different switches

---

### HPE GreenLake / InfoSight Connectivity (Array to Cloud)

**Requirement:** Each Alletra array must maintain connectivity to HPE InfoSight for cloud management, predictive analytics, and GreenLake consumption tracking.

**Connection Requirements:**
- Outbound HTTPS (TCP 443) from the array management IP to `infosight.hpe.com`
- Some environments require proxy configuration on the array

**Verification:**

```bash
# On Alletra 6000/Nimble
network --list
# Check "cloud connection" status in InfoSight portal → My Arrays

# On Alletra 9000 / B10000
showsys               # Look for cloud connectivity indicators in output
```

**InfoSight Array Connection Checklist:**
- Array management IP has a route to the internet via firewall
- Firewall permits outbound TCP 443 from array management IP to HPE InfoSight endpoints
- DNS resolves `infosight.hpe.com` from the array management network
- Proxy settings configured if required (configured in array network settings)
- Clock sync (NTP) is functioning on the array — certificate validation fails if time is significantly skewed

**If Array Shows Disconnected in InfoSight:**
1. Log into array management UI → Network Settings → verify GreenLake/InfoSight connection settings
2. Test DNS from array CLI: `ping infosight.hpe.com`
3. Test HTTPS reachability: try `curl https://infosight.hpe.com` if curl is available
4. Check firewall logs for blocked outbound 443 from array IP
5. Open HPE support case if connectivity cannot be restored within 2 hours — disconnected arrays lose predictive analytics and proactive case creation

---

## Support Case Creation

### When to Open a Case

| Condition | Action |
|-----------|--------|
| Drive failure predicted by InfoSight | Case auto-created; verify and confirm replacement |
| Controller node in degraded/failed state | Open P1 case immediately |
| Array shows "Critical" wellness event | Open P2 case within 2 hours |
| Replication partner unreachable > 15 minutes | Investigate network first; open case if not resolved |
| Performance degradation unexplained by InfoSight | Open P3 case with InfoSight export attached |
| Firmware update failure | Open P2 case with update log attached |

### Information to Gather Before Calling

**For All Issues:**
- Array serial number (found in InfoSight, DSCC, or `showsys` output)
- Current software/OS version
- InfoSight wellness export (from InfoSight → Support → Download Logs)
- Timeline of when the issue began
- Any recent changes (firmware updates, configuration changes, network changes)

**For Performance Issues:**
- InfoSight performance export covering the incident window
- Host-side iostat or Windows Performance Monitor capture
- Application error logs with timestamps

**For Connectivity Issues:**
- Output of `showport -state` (9000/B10000) or `array --info` (6000)
- Network topology diagram showing switch interconnects
- FC fabric zoning export or iSCSI switch VLAN configuration

**For Replication Issues:**
- Output of `showrcopygroup` and `showrcopytarget`
- Network latency measurements between sites (ping RTT, iperf throughput)
- Replication event log from InfoSight

### HPE Support Channels

- **HPE Support Center**: support.hpe.com — case portal, documentation, firmware downloads
- **InfoSight**: infosight.hpe.com — proactive cases created automatically for hardware events
- **HPE Pointnext**: for complex architecture questions, migrations, and on-site support
- **Phone**: 1-800-474-6836 (US); global numbers at hpe.com/support
- **GreenLake Console**: Support tab within DSCC for Alletra MP customers

---

## Firmware and OS Management

### Update Strategy

**Non-Disruptive Updates (All Models):**
- All Alletra firmware updates are designed to be non-disruptive; controllers are updated one at a time (rolling update)
- Schedule updates during low-activity windows anyway — reduced I/O during rolling update prevents latency spikes
- Read the release notes before applying any update: check for known issues, prerequisites, and deprecated features

**Update Sequence:**
1. Review InfoSight for any open wellness events or health issues — resolve before updating
2. Verify current software version: `showsys -d` (9000/B10000) or InfoSight portal (6000/5000)
3. Download firmware from HPE Support Center (requires valid support contract)
4. Upload to array and initiate update from management UI or CLI
5. Monitor update progress; each controller node update typically takes 10–20 minutes
6. Verify all nodes return to `OK` state after update completes
7. Review InfoSight for any new wellness events post-update

**Firmware Cadence:**
- HPE recommends staying within 2 major versions of the current release
- Critical security patches should be applied within 30 days of release
- HPE Pointnext Complete Care customers receive proactive firmware update recommendations via InfoSight
