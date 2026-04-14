# Ceph Diagnostics and Troubleshooting

## Diagnostic Philosophy

Work from the outside in:
1. Establish cluster-level health (monitors, quorum)
2. Narrow to the affected component (OSDs, PGs, MDS, RGW)
3. Gather evidence before making changes
4. Fix root causes, not symptoms

**Never make CRUSH or pool changes while the cluster is degraded.**

## Cluster Health

```bash
ceph health             # HEALTH_OK / HEALTH_WARN / HEALTH_ERR
ceph health detail      # Full list of active health checks with codes
ceph status             # Full cluster overview
ceph -w                 # Real-time watch mode
```

### Health Check Codes

**Monitor/Quorum:** `MON_DOWN` (check systemctl/network/disk), `MON_CLOCK_SKEW` (sync NTP), `MON_DISK_LOW`/`MON_DISK_CRIT` (free space), `ELECTION_STUCK` (network/NTP/disk stall).

**OSD:** `OSD_DOWN` (check service status), `OSD_NEARFULL` (>75%, rebalance), `OSD_FULL` (>85%, writes blocked), `OSD_BACKFILLFULL` (>80%), `SLOW_OPS` (requests exceeding 30s).

**PG:** `PG_DEGRADED` (replicas missing), `PG_AVAILABILITY` (inactive, I/O blocked), `PG_RECOVERY_FULL` (recovery blocked by full OSDs), `OBJECT_UNFOUND` (data loss risk).

**MDS:** `MDS_DOWN`, `FS_DEGRADED`, `MDS_SLOW_METADATA_IO`, `RECENT_CRASH`.

## OSD Failures

### Assess State

```bash
ceph osd tree                    # CRUSH tree with up/down/in/out
ceph osd stat                    # Summary counts
ceph osd df                      # Per-OSD disk usage
ceph osd perf                    # Per-OSD apply latency
```

### Restart and Maintenance

```bash
systemctl restart ceph-osd@<id>
# Or with Cephadm:
ceph orch daemon restart osd.<id>

# Planned maintenance -- prevent automatic mark-out:
ceph osd set noout
# ... perform maintenance ...
ceph osd unset noout
```

### Full OSD Replacement

```bash
ceph osd out <id>                    # Initiate data movement
ceph -w                              # Wait for recovery
systemctl stop ceph-osd@<id>
ceph osd crush remove osd.<id>
ceph auth del osd.<id>
ceph osd rm <id>
wipefs -a /dev/sdX && sgdisk --zap-all /dev/sdX
ceph-volume lvm create --data /dev/sdX   # Or ceph orch daemon add osd
```

### BlueStore Corruption Repair

```bash
systemctl stop ceph-osd@<id>
ceph-bluestore-tool fsck --path /var/lib/ceph/osd/ceph-<id>
ceph-bluestore-tool repair --path /var/lib/ceph/osd/ceph-<id>
```

## Slow Requests

### Identify

```bash
ceph health detail | grep SLOW_OPS
ceph daemon osd.<id> dump_ops_in_flight
ceph daemon osd.<id> dump_historic_slow_ops
```

### Root Cause Analysis

**Disk latency:** `ceph osd perf` -- high apply_latency_ms on HDDs (>100ms) or SSDs (>10ms). Check with `iostat -x 1`.

**Network:** Verify OSD heartbeat connectivity, check packet loss with ping.

**Recovery throttling:**
```bash
ceph tell osd.* config set osd_recovery_max_active 1
ceph tell osd.* config set osd_recovery_sleep_hdd 0.1
```

## PG States

### Check and Diagnose

```bash
ceph pg stat
ceph pg dump_stuck inactive
ceph pg dump_stuck unclean
ceph pg dump_stuck stale
ceph pg <pgid> query              # Detailed state including blocking info
```

### Key States

| State | I/O | Action |
|-------|-----|--------|
| `active+clean` | Yes | Healthy |
| `active+degraded` | Yes | Watch recovery progress |
| `peering` | No | OSDs negotiating |
| `inactive` | No | Critical -- identify offline OSDs |
| `inconsistent` | Degraded | Trigger `ceph pg repair <pgid>` |

### Force Recovery

```bash
ceph pg force-recovery <pgid>
ceph pg force-backfill <pgid>
ceph pg repair <pgid>                    # After inconsistency
ceph pg <pgid> mark_unfound_lost revert  # Last resort -- data loss
```

## Recovery and Backfill

### Monitor Progress

```bash
ceph status       # Shows recovery rate, objects remaining
ceph -w           # Live updates
```

### Throttle Recovery

```bash
# Slow down (prioritize client I/O)
ceph tell osd.* config set osd_recovery_max_active_hdd 1
ceph tell osd.* config set osd_recovery_sleep_hdd 0.1

# Speed up (prioritize data safety)
ceph tell osd.* config set osd_recovery_max_active_hdd 5
ceph tell osd.* config set osd_recovery_sleep_hdd 0
```

### Maintenance Flags

```bash
ceph osd set noout       # Don't auto mark-out
ceph osd set norecover   # Don't start recovery
ceph osd set nobackfill  # Don't start backfill
# After maintenance:
ceph osd unset noout && ceph osd unset norecover && ceph osd unset nobackfill
```

## Clock Skew

Monitors require accurate clocks (Paxos). Even 0.05s differences trigger warnings.

```bash
ceph health detail | grep CLOCK_SKEW
chronyc tracking           # Check offset on each monitor
chronyc makestep           # Force NTP sync
```

Use the same NTP server for all cluster nodes.

## Network Partitions

Symptoms: multiple OSDs marked down simultaneously, election stuck, bulk PG transitions to inactive.

```bash
ceph quorum_status
ip link show
netstat -s | grep -E "(retransmit|reset|error)"
nc -z -v <peer_osd_host> 6800
```

Recovery: restore connectivity, OSDs re-peer automatically. If monitors lost quorum, rebuild monitor map with `ceph-mon --extract-monmap`.

## Configuration Management

```bash
# Persistent (config database)
ceph config set osd osd_memory_target 8589934592
ceph config show osd.5
ceph daemon osd.5 config diff

# Runtime-only (temporary)
ceph tell osd.* config set <key> <value>

# Admin socket
ceph daemon osd.<id> perf dump
ceph daemon osd.<id> dump_ops_in_flight
ceph daemon osd.<id> bluestore stats
```

## Log Analysis

| Daemon | Log Path |
|--------|----------|
| Monitor | `/var/log/ceph/ceph-mon.<hostname>.log` |
| OSD | `/var/log/ceph/ceph-osd.<id>.log` |
| Manager | `/var/log/ceph/ceph-mgr.<hostname>.log` |
| MDS | `/var/log/ceph/ceph-mds.<hostname>.log` |
| RGW | `/var/log/ceph/ceph-client.rgw.<name>.log` |

With Cephadm: `ceph log last 50`, `journalctl -u ceph-osd@<id>`, `ceph orch daemon logs osd.<id>`.

### Increase Verbosity

```bash
ceph tell osd.<id> injectargs '--debug-osd=10 --debug-ms=1'
# Reset after:
ceph tell osd.<id> injectargs '--debug-osd=0 --debug-ms=0'
```

## Crash Reports

```bash
ceph crash ls
ceph crash info <crash-id>
ceph crash archive-all     # Clear RECENT_CRASH warning
```

## Quick Diagnostic Runbooks

### HEALTH_WARN Triage

```bash
ceph health detail
ceph status
ceph osd tree | grep -E "(down|out)"
ceph pg dump_stuck
ceph df
```

### HEALTH_ERR Emergency

```bash
ceph quorum_status                # Monitor quorum intact?
ceph pg dump_stuck inactive       # I/O blocked PGs?
ceph pg <pgid> query              # Which OSDs needed?
systemctl start ceph-osd@<id>    # Bring them back
```

### Performance Diagnosis

```bash
ceph status | grep -A 5 "io:"    # Throughput and IOPS
ceph osd perf                     # Per-OSD latency
ceph iostat 1                     # 1-second interval
```
