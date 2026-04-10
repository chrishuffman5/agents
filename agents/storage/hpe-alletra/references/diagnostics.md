# HPE Alletra Diagnostics and Troubleshooting

## InfoSight Predictive Analytics

Cloud-hosted AIOps. 100,000+ systems, every second. Cross-system learning.

### Dashboard Views
**5000/6000 (Nimble-lineage)**: Operational dashboard. Per-array/volume/VM performance. 30/90-day capacity forecasts. Active alerts.
**MP B10000 (GreenLake)**: Wellness Dashboard. Signature-based automation. Prescriptive remediation. Direct support case links.
**VM Analytics**: Per-VM latency/IOPS/throughput. Identifies high-I/O VMs. Correlates with host compute. Hyper-V supported for 5000/6000.
**Cross-Stack**: Correlates storage/server/network telemetry. Identifies root cause across layers. Requires InfoSight agents on VMware/Hyper-V hosts.

### Predictive Capabilities
- Drive failure: days-weeks ahead via SMART + global fleet patterns. Proactive replacement shipped.
- Capacity exhaustion: growth modeling with configurable thresholds (70% warning, 80% critical).
- Performance anomaly (B10000): ML on high-frequency sensors. Prescriptive remediation.
- Controller/component health: environmental monitoring, non-critical degradation lead time.

## Array Health Checks

### Alletra 9000 / Primera CLI (SSH)
```
showsys -d              # System health (look for degraded/failed/faulted)
shownode -s             # Controller nodes (all should show OK)
showalert -n 20         # Recent alerts (investigate FATAL/CRITICAL first)
showvv -state           # Volume status
showcage -d             # Shelf/drive layout and health
showrcopygroup          # Replication Remote Copy Group status
showrcopytarget         # Replication link status (link_state should be Up)
showport -state         # FC and iSCSI port status
statport -iter 5 -interval 2  # Live port performance
```

### Alletra 6000 / Nimble CLI (SSH, admin user)
```
array --info            # Health summary (status should be normal)
vol --list              # Volume status
shelf --list / disk --list  # Shelf and disk status (failed = replace)
perf --array --count 10 --interval 5  # Live performance
network --list / iscsi --list  # Network and iSCSI
partner --list / vol --replication  # Replication partner (reachable: yes)
event --list --severity critical,warning  # Active alerts
```

### Alletra MP B10000 (DSCC + CLI)
DSCC: GreenLake console > Storage > array. Inventory, performance charts, issues tab.
```
showsys -d              # System health
shownode -s             # Controller nodes
showport -state         # Port states
showalert -n 50         # Alerts
statport -iter 5 -interval 2  # I/O stats
```
Note: B10000 shares base CLI syntax with 9000/Primera for hardware queries.

## Performance Diagnostics

### Step 1: Identify Symptom

| Symptom | First Check |
|---|---|
| High latency | InfoSight > Performance > Volume latency |
| Specific VMs slow | InfoSight > VM Analytics |
| Low throughput | InfoSight > Array throughput |
| Slow backups | Snapshot schedule conflicts; StoreOnce throughput |
| Inconsistent performance | Noisy-neighbor volumes; QoS settings |

### Step 2: Determine Scope
- Single volume: workload issue, policy misconfiguration, QoS cap
- Multiple volumes same pool: pool saturation, cache miss, drive failure
- Entire array: controller saturation, network congestion, hardware degradation
- All arrays in group: replication traffic, network issue

### Step 3: InfoSight Analysis
Select affected array > Performance > set time range > review IOPS/throughput/latency/queue depth/cache hit > cross-reference Events timeline > check Recommendations.

### Step 4: Host-Side Verification
```
# Linux multipath
multipath -ll

# Linux I/O latency
iostat -x -d 2 10

# Linux iSCSI sessions
iscsiadm -m session -P 3

# Windows MPIO
mpclaim -s -d

# VMware storage paths
esxcli storage nmp path list
```

### Step 5: Resolve or Escalate
Resolvable: QoS cap hit, pool saturation, cache miss, noisy neighbor.
Requires HPE Support: controller hardware fault, persistent drive errors beyond RAID tolerance, replication sync failures, unexplained latency.

## Connectivity Troubleshooting

### iSCSI
```
iscsi --list                          # 6000
showport -iscsi                       # 9000/B10000
iscsiadm -m discovery -t sendtargets -p <array_ip>  # Host discovery
iscsiadm -m session -P 3             # Active sessions
ping -M do -s 8972 <array_ip>        # MTU test
```
Checklist: MTU 9000 consistent, dedicated VLANs, flow control, multipath `round-robin`, initiator IQN registered.

### Fibre Channel
```
showport -state                       # 9000/B10000
showhost                              # 9000: registered hosts and paths
```
Checklist: single-init/single-target zoning, WWN registered, no duplicate WWNs, ISL not saturated.

### GreenLake/InfoSight Connectivity
Outbound HTTPS (443) to `infosight.hpe.com`. Proxy if needed. DNS resolution. NTP sync (cert validation). If disconnected > 2 hours: open support case (loses predictive analytics).

## Support Case Creation

| Condition | Action |
|---|---|
| Drive failure predicted | Case auto-created; confirm replacement |
| Controller degraded/failed | P1 case immediately |
| Critical wellness event | P2 case within 2 hours |
| Replication partner unreachable > 15 min | Investigate network; case if unresolved |
| Unexplained performance degradation | P3 case with InfoSight export |

Gather: array serial, software version, InfoSight wellness export, timeline, recent changes. Performance: InfoSight export + host iostat. Connectivity: `showport` output + network topology.

Channels: support.hpe.com, InfoSight portal, HPE Pointnext, phone 1-800-474-6836, GreenLake Console Support tab.

## Firmware Management

All models: non-disruptive rolling updates (one node at a time). Schedule during low-activity windows. Read release notes first. Resolve InfoSight wellness events before updating. Verify all nodes return to OK after update. Stay within 2 major versions of current. Critical security patches within 30 days.
