# Dell Unity XT Diagnostics and Troubleshooting

## Unisphere Monitoring

### Dashboard Views
- Health: color-coded (green/yellow/red) per component
- Capacity: pool utilization, subscribed vs consumed
- Performance: real-time IOPS, throughput, latency
- Navigation: System > Health, Storage > Pools, System > Performance, System > Alerts

### Metrics Collection
Enabled by default. Verify: Settings > Metrics > Metrics Collection. UEMCLI: `uemcli /metrics/service show`. Retention: 20s samples (1 hour), 5-min averages (days), 1-hour averages (weeks).

### Alerts
Email (Settings > Notifications > Email), SNMP v2c/v3 (Settings > Notifications > SNMP). Thresholds: 85% warning, 90% high warning, 95% critical + auto snapshot deletion. KB 000343406 for 95% remediation.

## SP Utilization

| Metric | Normal | Warning | Action |
|---|---|---|---|
| SP CPU | < 50% | > 70% sustained | > 80% sustained |
| SP Memory | < 80% | > 85% | > 90% |
| Backend Latency | < 5 ms | > 10 ms | > 20 ms |
| Frontend Response | < 2 ms | > 5 ms | > 10 ms |

### Enabling CPU/Memory Monitoring
System > Service > Service Tasks > Enable CPU/Memory Utilization Monitoring > Execute.

### UEMCLI SP CPU
```
# Historical (5-min intervals, last 5 samples)
uemcli /metrics/value/hist -path sp.*.cpu.summary.utilization show -detail -interval 300 -count 5

# Real-time (30-second polling)
uemcli /metrics/value/rt -path sp.*.cpu.summary.utilization show -detail
```

### High CPU Without Proportional IOPS
1. Large snapshot deletion queue (check Snapshots column for destroying state, KB 000055095)
2. uDoctor scheduled tasks (KB 000058581, reschedule to off-peak)
3. FAST VP relocation during peak hours (reschedule relocation window)
4. Data reduction processing

### SP Failover/Core Dumps
Unisphere: System > Service > Service Files. UEMCLI: `uemcli /service/dump show`. OE 5.4+: MFT transfer directly to Dell Support. KB 000082028 for unexpected SP reboots.

## Pool Exhaustion

### Checking Capacity
Unisphere: Storage > Pools > select pool > Capacity tab. Key: Physical Used, Subscribed, Free Physical.
```
uemcli /stor/config/pool show -detail
```

### Causes and Remediation

| Cause | Fix |
|---|---|
| Snapshot accumulation | Delete expired, adjust retention |
| Over-subscription | Expand pool or delete unused objects |
| Flash tier full | Add flash drives or adjust tiering policy |

### Alert Thresholds
85%: warning. 90%: performance may degrade. 95%: critical + auto snapshot deletion. 100%: new writes fail.

### Expand Pool
```
uemcli /stor/config/pool -name <pool> set -addDriveCount <n> -diskTierType performance
```

## Replication Troubleshooting

### Check Status
```
uemcli /prot/rep/session show -detail
uemcli /prot/rep/session -name <session> show -detail
```

### Common Failures

**Lag increasing (async)**: Check bandwidth on replication interfaces. Throttle competing traffic. Consider dedicated VLAN.

**Paused state**: Often pre-upgrade health check paused sessions. Resume: `uemcli /prot/rep/session -name <name> resume`.

**Connection failure (blocks NDU)**: Update connection: `uemcli /prot/rep/connection -id <id> set -dstAddress <new-IP>`. KB 000019432, KB 000058805.

**Synchronous fault**: Metro Node alerts. Restore inter-site connectivity then resync. KB 000019787.

### Replication and OE Upgrades
Failed replication health check blocks NDU. To clear: pause all sessions from source, or fix/recreate connections in error state. Retry health check.

## Performance Analysis

### Gathering Data
Unisphere: System > Performance > System/LUN/File System. Export CSV for trend analysis.

```
# Historical latency for all LUNs
uemcli /metrics/value/hist -path lun.*.responseTime.reads show -detail -interval 300 -count 60

# Pool IOPS
uemcli /metrics/value/hist -path sp.*.storage.pool.*.iops show -detail -interval 300 -count 12

# List available metrics
uemcli /metrics/metric show
```

### Troubleshooting Framework
1. **Scope**: system-wide or specific objects?
2. **Backend disk latency**: System > Performance > Disks. > 10ms = contention or drive failure
3. **SP cache**: write cache full = backend bottleneck. High read miss = working set exceeds cache
4. **FAST VP tier distribution**: Storage > Pools > Tiers tab. Too much data on Capacity tier = insufficient flash
5. **SP dumps if crash**: Service > Service Files

## Key UEMCLI Reference

| Purpose | Command |
|---|---|
| Pool health | `uemcli /stor/config/pool show -detail` |
| All alerts | `uemcli /event/alert show -detail` |
| SP hardware | `uemcli /phys/sp show -detail` |
| Drive health | `uemcli /phys/disk show -detail` |
| NAS server status | `uemcli /net/nas show -detail` |
| Replication sessions | `uemcli /prot/rep/session show -detail` |
| Service files | `uemcli /service/dump show` |
| Real-time SP CPU | `uemcli /metrics/value/rt -path sp.*.cpu.summary.utilization show -detail` |
| Pause replication | `uemcli /prot/rep/session -name <name> pause` |
| Resume replication | `uemcli /prot/rep/session -name <name> resume` |
