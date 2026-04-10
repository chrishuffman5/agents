# Dell Unity XT Diagnostics and Troubleshooting

## Unisphere Monitoring

### Dashboard and Health Overview

The Unisphere home dashboard provides a system-level health summary with three primary views:

- **Health**: Color-coded status (green/yellow/red) for each system component (SPs, drives, fans, power supplies, network ports)
- **Capacity**: Pool utilization bars, subscribed vs. consumed capacity, and per-object breakdown
- **Performance**: Real-time IOPS, throughput, and latency line charts for the entire system

**Navigation for monitoring:**
- `System > Health` — Full component health tree with alert details
- `Storage > Pools` — Per-pool capacity, subscription level, and FAST VP status
- `System > Performance` — System-wide and per-object performance metrics
- `System > Alerts` — All active and historical alerts with severity and recommended actions

### Enabling Metrics Collection

Metrics collection is enabled by default but can be verified or re-enabled:

- **Unisphere**: Settings > Metrics > Metrics Collection — toggle on/off
- **UEMCLI**:
  ```
  uemcli -d <mgmt-IP> -u admin -p <password> /metrics/service show
  uemcli -d <mgmt-IP> -u admin -p <password> /metrics/service set -stat on
  ```

Metrics are stored in a dedicated 16 GB performance database on the first four system drives. Data is retained for varying durations depending on resolution:
- 20-second samples: retained for ~1 hour
- 5-minute averages: retained for several days
- 1-hour averages: retained for weeks

### Alert Configuration

**Email alerts**: Configure under Settings > Notifications > Email

**SNMP traps**: Configure under Settings > Notifications > SNMP; Unity supports SNMP v2c and v3

**Alert thresholds** (configurable per pool):
- Default capacity warning: 85% pool utilization
- Customizable range: 50–84% (user-configurable lower warning)
- System-generated alerts also fire at 90% and 95%
- At 95%: Critical alert generated; check KB article 000343406 for remediation steps

---

## SP Utilization Monitoring

### Key SP Metrics

| Metric | Normal Range | Warning Threshold | Action Threshold |
|--------|-------------|------------------|-----------------|
| SP CPU Utilization | < 50% average | > 70% sustained | > 80% sustained |
| SP Memory Utilization | < 80% | > 85% | > 90% |
| SP Write Cache Usage | Variable | — | 100% (write cache full) |
| Backend (disk) Latency | < 5 ms | > 10 ms | > 20 ms |
| Frontend Response Time | < 2 ms | > 5 ms | > 10 ms |

### Enabling CPU/Memory Monitoring

CPU and memory utilization monitoring is not enabled by default on some OE versions:

**Unisphere**: System > Service > Service Tasks > Enable CPU/Memory Utilization Monitoring > Execute

**UEMCLI** — Retrieve SP CPU utilization at 5-minute intervals (last 5 samples):
```
uemcli -d <mgmt-IP> -u admin -p <password> -noheader -gmtoff 0 \
  /metrics/value/hist \
  -path sp.*.cpu.summary.utilization \
  show -detail -interval 300 -count 5
```

**UEMCLI** — Real-time SP CPU (30-second polling):
```
uemcli -d <mgmt-IP> -u admin -p <password> \
  /metrics/value/rt \
  -path sp.*.cpu.summary.utilization \
  show -detail
```

### Diagnosing High SP CPU

High SP CPU without a corresponding increase in IOPS or throughput often indicates:

1. **Large snapshot queue in destroying state**: A backlog of deleting snapshots causes elevated CPU
   - Check: `Storage > Block > LUNs` — add Snapshots column; look for LUNs with many destroying snapshots
   - Fix: Allow time for deletion to complete; avoid issuing new snapshot operations during heavy deletion
   - Reference: Dell KB 000055095

2. **uDoctor scheduled tasks**: The Dell internal diagnostic collection tool (uDoctor) runs on a schedule and can spike CPU
   - Reference: Dell KB 000058581
   - Fix: Reschedule uDoctor tasks to off-peak hours; see System > Service

3. **FAST VP relocation during peak hours**: Relocation competes with host I/O for back-end drive bandwidth
   - Fix: Reschedule FAST VP relocation window to avoid overlap with peak workload periods

4. **Data reduction processing**: Inline deduplication and compression consume CPU; validate that the data reduction configuration is appropriate for the workload type

### SP Failover and Core Dumps

If an SP reboots unexpectedly, Unisphere generates an alert and creates a core dump:

- **Unisphere**: System > Service > Service Files — download SP dumps for analysis
- **UEMCLI**:
  ```
  uemcli -d <mgmt-IP> -u admin -p <password> /service/dump show
  ```
- After OE 5.4: Use Managed File Transfer (MFT) to send dumps directly to Dell Support:
  ```
  uemcli -d <mgmt-IP> -u admin -p <password> /service/dump transfer -id <dump-id>
  ```
- Reference: Dell KB 000082028 for UnityOS 5.0.x unexpected SP reboot issues

---

## Pool Exhaustion Diagnostics

### Identifying Pool Capacity Issues

**Unisphere — Pool capacity view:**
- `Storage > Pools` — Select pool, then Capacity tab
- Review: Physical Used, Subscribed, Free Physical, Free Subscribed
- Key distinction: A pool can be under-subscribed (provisioned less than physical) but still fill up due to snapshot growth or write activity

**UEMCLI — Show all pools with detail:**
```
uemcli -d <mgmt-IP> -u admin -p <password> /stor/config/pool show -detail
```

Key fields to review:
- `Size remaining`: Physical free space remaining in the pool
- `Subscription`: How much has been thin-provisioned (can exceed 100%)
- `Current Allocation`: Actual physical blocks consumed

**UEMCLI — Expand pool (add drives):**
```
uemcli -d <mgmt-IP> -u admin -p <password> \
  /stor/config/pool -name <pool-name> \
  set -addDriveCount <count> -diskTierType performance
```

### Pool Exhaustion Causes and Remediation

| Cause | Detection | Remediation |
|-------|-----------|-------------|
| Snapshot accumulation | High snapshot space in pool capacity view | Delete expired snapshots; adjust retention policies |
| Preallocated space | High "Preallocated" vs "Written" ratio | Verify thin provisioning on all objects |
| Over-subscription without space management | Subscription > 100% with low free physical | Expand pool or delete unused storage objects |
| FAST VP promotion without flash tier capacity | Flash tier at 100% in tiered pool | Add flash drives to pool or adjust tiering policy |

### Pool Alert States and Automatic Actions

| Threshold | Alert Type | System Action |
|-----------|-----------|---------------|
| 85% (default) | Warning | Email/SNMP notification sent |
| 90% | Warning-High | Performance may degrade |
| 95% | Critical | Automatic snapshot deletion of expired snapshots |
| 100% | Error | New writes to thin objects fail; I/O errors to hosts |

**When automatic snapshot deletion triggers at 95%:**
- Unisphere generates alert code `flr::check_if_storage_pool_recovery_is_required_3`
- The system attempts to reclaim space by deleting snapshots past their retention period
- If space is not recovered, manual intervention is required (expand pool or delete objects)

---

## Replication Failure Diagnostics

### Checking Replication Session Status

**Unisphere**: Data Protection > Replication > Sessions — filter by state (Active, Idle, Paused, Failed)

**UEMCLI — List all replication sessions:**
```
uemcli -d <mgmt-IP> -u admin -p <password> /prot/rep/session show -detail
```

Key fields:
- `Health`: OK / Degraded / Minor / Major / Critical
- `Current Amount`: Data transferred in current sync cycle
- `Last Sync Time`: When the last successful synchronization completed
- `Estimated Completion`: For in-progress sessions

**UEMCLI — Show specific session by name:**
```
uemcli -d <mgmt-IP> -u admin -p <password> /prot/rep/session -name <session-name> show -detail
```

### Common Replication Failure Scenarios

**Scenario 1: Replication lag increasing (async)**
- Symptom: "Last Sync Time" is falling behind the RPO target
- Check: Network bandwidth utilization on replication interfaces; competing I/O from backups or migrations
- Fix: Throttle competing traffic; consider dedicated replication VLAN; reduce RPO to allow more frequent but smaller sync cycles

**Scenario 2: Replication session in Paused state**
- Symptom: Session shows "Paused" state; no sync occurring
- Cause: Often a pre-upgrade health check paused sessions, or manual pause was performed
- Fix (UEMCLI):
  ```
  uemcli -d <mgmt-IP> -u admin -p <password> /prot/rep/session -name <session-name> resume
  ```

**Scenario 3: Replication connection failure**
- Symptom: Health Check Error `check_replication` blocks OE upgrade; sessions show connection lost
- Check: Network connectivity between source and destination management interfaces and replication interfaces
- Fix: Update replication connection:
  ```
  uemcli -d <mgmt-IP> -u admin -p <password> /prot/rep/connection show
  uemcli -d <mgmt-IP> -u admin -p <password> /prot/rep/connection -id <conn-id> set -dstAddress <new-IP>
  ```
- Reference: Dell KB 000019432, KB 000058805

**Scenario 4: Synchronous replication fault**
- Symptom: Metro Node alerts; sync replication degrades to async mode
- Check: Metro Node health and inter-site link latency
- Fix: Restore inter-site connectivity; after link restoration, resync from Metro Node management interface
- Reference: Dell KB 000019787

### Replication and OE Upgrades

A failed replication health check blocks NDU (non-disruptive upgrade). To clear:
1. Identify sessions in Warning or Error state
2. For Warning state: Pause all replication sessions from the source system
   ```
   uemcli -d <mgmt-IP> -u admin -p <password> /prot/rep/session pause -async
   ```
3. For Error state: Update or delete and recreate the replication connection
4. Retry the OE upgrade health check after sessions are in Paused or OK state

---

## Performance Analysis

### Gathering Performance Data for Analysis

Dell recommends collecting the following before engaging support for a performance issue:

**Unisphere Performance Charts:**
- Navigate: System > Performance > System — view SP-level CPU, cache, read/write IOPS, latency
- Navigate: System > Performance > LUN or File System — drill into per-object metrics
- Export charts as CSV: Available on each chart view for trend analysis in Excel/external tools

**UEMCLI Performance Collection:**

Get historical latency for all LUNs (5-minute intervals, last 60 samples):
```
uemcli -d <mgmt-IP> -u admin -p <password> \
  /metrics/value/hist \
  -path lun.*.responseTime.reads \
  show -detail -interval 300 -count 60
```

Get IOPS for storage pools:
```
uemcli -d <mgmt-IP> -u admin -p <password> \
  /metrics/value/hist \
  -path sp.*.storage.pool.*.iops \
  show -detail -interval 300 -count 12
```

List available metrics paths:
```
uemcli -d <mgmt-IP> -u admin -p <password> /metrics/metric show
```

### Performance Troubleshooting Framework

**Step 1: Determine scope**
- Is the problem system-wide (all LUNs/file systems) or isolated to specific objects?
- Is SP CPU high, or is it disk-side latency?

**Step 2: Check backend disk latency**
- Navigate: System > Performance > Disks
- Backend latency > 10 ms sustained indicates disk contention or drive failure
- Check drive health: Storage > Drives — look for drives in Faulted or Reconstructing state

**Step 3: Check SP cache**
- Write cache full (100%) means the system cannot absorb new writes fast enough; backend drives are the bottleneck
- Read cache miss rate: High miss rate combined with high read latency suggests working set exceeds FAST Cache/system cache capacity

**Step 4: Analyze FAST VP tier distribution**
- Navigate: Storage > Pools > [pool] > Tiers tab — check data distribution across tiers
- If too much active data sits on the Capacity (HDD) tier, FAST VP is not promoting it fast enough
- Resolution: Increase Extreme Performance tier size, or change FAST VP schedule to run more frequently

**Step 5: Collect SP dumps if crash-related**
- Service > Service Files > SP Dumps — collect and transfer to Dell Support
- Core dumps are automatically generated on SP panics; check System > Alerts for SP reboot events

### uDoctor Diagnostic Tool

uDoctor is Dell's built-in diagnostic collection engine that gathers system health data:

- Runs on a schedule (may cause CPU spikes; reference KB 000058581)
- Can be triggered manually from Service > Service Tasks for on-demand diagnostics
- Output is bundled into a service file uploadable to Dell via Managed File Transfer (OE 5.4+) or manual upload to Dell Support portal

### Key UEMCLI Commands Reference

| Purpose | Command |
|---------|---------|
| Show pool health and capacity | `uemcli /stor/config/pool show -detail` |
| Show all alerts | `uemcli /event/alert show -detail` |
| Show SP hardware status | `uemcli /phys/sp show -detail` |
| Show drive health | `uemcli /phys/disk show -detail` |
| Show NAS server status | `uemcli /net/nas show -detail` |
| Show replication sessions | `uemcli /prot/rep/session show -detail` |
| Show replication connections | `uemcli /prot/rep/connection show -detail` |
| List service files | `uemcli /service/dump show` |
| Show metrics collection status | `uemcli /metrics/service show` |
| Show available metric paths | `uemcli /metrics/metric show` |
| Real-time SP CPU | `uemcli /metrics/value/rt -path sp.*.cpu.summary.utilization show -detail` |
| Historical SP CPU | `uemcli /metrics/value/hist -path sp.*.cpu.summary.utilization show -interval 300 -count 12` |
| Pause replication session | `uemcli /prot/rep/session -name <name> pause` |
| Resume replication session | `uemcli /prot/rep/session -name <name> resume` |
| Expand pool (add drives) | `uemcli /stor/config/pool -name <name> set -addDriveCount <n>` |
