# Ceph Diagnostics and Troubleshooting

## Diagnostic Philosophy

Work from the outside in:
1. Establish cluster-level health (monitors, quorum)
2. Narrow to the affected component (OSDs, PGs, MDS, RGW)
3. Gather evidence before making changes
4. Fix root causes, not symptoms

**Never make CRUSH or pool changes while the cluster is degraded.** This can cascade into additional PG unavailability.

---

## ceph health — Cluster Status

### Quick health check

```bash
ceph health          # HEALTH_OK / HEALTH_WARN / HEALTH_ERR
ceph health detail   # Full list of active health checks with codes
ceph status          # Full cluster overview: MON, OSD, PG, client I/O
ceph -w              # Real-time watch mode (follows cluster events)
ceph -s              # Alias for ceph status
```

### Health check codes

**Monitor / Quorum:**

| Code | Meaning | Action |
|------|---------|--------|
| `MON_DOWN` | One or more monitors are down | Check `systemctl status ceph-mon@<name>`, network, disk |
| `MON_CLOCK_SKEW` | Clock difference between monitors exceeds 0.05s | Sync NTP; `chronyc tracking` on each mon |
| `MON_DISK_LOW` | Monitor data partition < 5% free | Free space or expand; mon RocksDB compaction |
| `MON_DISK_CRIT` | Monitor data partition < 1% free | Critical; monitor may stop working |
| `ELECTION_STUCK` | Monitors cannot complete an election | Network partition, NTP skew, disk I/O stall |

**OSD:**

| Code | Meaning | Action |
|------|---------|--------|
| `OSD_DOWN` | One or more OSDs down | `systemctl status ceph-osd@<id>`, kernel logs |
| `OSD_NEARFULL` | OSD > 75% full | Rebalance, add capacity, or delete data |
| `OSD_FULL` | OSD > 85% full | Writes blocked; immediate action required |
| `OSD_BACKFILLFULL` | OSD > 80%, blocks backfill targets | |
| `OSD_TOO_MANY_REPAIRS` | High repair count suggests hardware issues | Check disk SMART data |
| `SLOW_OPS` | Requests taking longer than `osd_op_complaint_time` (30s default) | See slow ops section below |

**PG:**

| Code | Meaning | Action |
|------|---------|--------|
| `PG_DEGRADED` | Some replicas missing | Normal during recovery; watch for progression |
| `PG_DEGRADED_FULL` | Degraded + nearfull; cannot recover | Immediate: add capacity or remove data |
| `PG_AVAILABILITY` | Some PGs are inactive (no I/O) | Critical; identify offline OSDs |
| `PG_RECOVERY_FULL` | Recovery blocked by full OSDs | Expand cluster or delete data |
| `OBJECT_MISPLACED` | Objects in wrong OSD (after CRUSH change) | Normal; will self-resolve via backfill |
| `OBJECT_UNFOUND` | Objects with no readable replica | Data loss risk; see unfound section |
| `PG_NOT_SCRUBBED` | PG not scrubbed within deadline | Check scrub flags, scheduling |
| `PG_NOT_DEEP_SCRUBBED` | PG not deep scrubbed within deadline | Check `osd_deep_scrub_interval` |

**MDS:**

| Code | Meaning | Action |
|------|---------|--------|
| `MDS_DOWN` | MDS ranks have no active daemon | Check `ceph fs status`, start MDS |
| `FS_DEGRADED` | Some MDS ranks are failed or damaged | `ceph fs status <fsname>` for detail |
| `MDS_SLOW_METADATA_IO` | MDS experiencing slow I/O | Check metadata pool latency |
| `RECENT_CRASH` | Daemons crashed recently | `ceph crash ls` and `ceph crash info <id>` |

---

## OSD Failures

### Assess OSD state

```bash
ceph osd tree                          # Full CRUSH tree with up/down/in/out status
ceph osd stat                          # Summary: X osds, Y up, Z in
ceph osd df                            # Per-OSD disk usage and variance
ceph osd find <id>                     # Location metadata for a specific OSD
ceph osd metadata <id>                 # Full OSD metadata (kernel, hardware, version)
ceph osd blocked-by                    # Which OSDs are blocking client operations
```

### OSD daemon restart

```bash
# Check service status
systemctl status ceph-osd@<id>

# Restart the OSD daemon
systemctl restart ceph-osd@<id>

# If using Cephadm:
ceph orch daemon restart osd.<id>

# Verify it came back up
ceph osd tree | grep osd.<id>
```

### Mark OSD out (safe maintenance)

```bash
# Mark OSD out — triggers data redistribution away from this OSD
ceph osd out <id>

# Watch recovery progress
ceph -w

# Re-add after maintenance
ceph osd in <id>
```

### Prevent automatic marking-out (planned maintenance)

```bash
# Set noout flag before maintenance
ceph osd set noout

# Perform maintenance (restart nodes, etc.)

# Clear after maintenance
ceph osd unset noout
```

### Full OSD replacement workflow

```bash
# 1. Document the OSD
ceph osd find <id>
ceph osd metadata <id>

# 2. Mark out (initiates data movement)
ceph osd out <id>

# 3. Wait for recovery to complete
ceph -w   # watch for HEALTH_OK or no more "recovering" in status

# 4. Stop the daemon
systemctl stop ceph-osd@<id>
# Or with Cephadm:
ceph orch daemon stop osd.<id>

# 5. Remove from CRUSH map, auth, and OSD list
ceph osd crush remove osd.<id>
ceph auth del osd.<id>
ceph osd rm <id>

# 6. Wipe the old device
wipefs -a /dev/sdX
sgdisk --zap-all /dev/sdX

# 7. Create new OSD on replacement device
ceph-volume lvm create --data /dev/sdX
# Or with Cephadm:
ceph orch daemon add osd <hostname>:/dev/sdX

# 8. Verify
ceph osd tree
ceph osd stat
ceph -w
```

### BlueStore corruption repair

```bash
# Stop the OSD first
systemctl stop ceph-osd@<id>

# Check for consistency errors
ceph-bluestore-tool fsck \
    --path /var/lib/ceph/osd/ceph-<id>

# Attempt repair
ceph-bluestore-tool repair \
    --path /var/lib/ceph/osd/ceph-<id>

# Check BlueFS stats
ceph-bluestore-tool bluefs-stats \
    --path /var/lib/ceph/osd/ceph-<id>
```

---

## Slow Requests

Slow ops occur when an OSD request takes longer than `osd_op_complaint_time` (default 30 seconds). They appear as `SLOW_OPS` in `ceph health detail`.

### Identify slow ops

```bash
# Cluster-level slow op count
ceph health detail | grep SLOW_OPS

# List in-flight operations on a specific OSD
ceph daemon osd.<id> dump_ops_in_flight

# List recently completed slow ops
ceph daemon osd.<id> dump_historic_ops

# List slow ops with op details
ceph daemon osd.<id> dump_historic_slow_ops

# Performance counters for an OSD
ceph daemon osd.<id> perf dump
# Or via admin socket:
ceph --admin-daemon /var/run/ceph/ceph-osd.<id>.asok perf dump
```

### Root cause analysis

**Check OSD disk latency:**
```bash
ceph osd perf                          # Apply latency (write commit) per OSD
# High apply_latency_ms on HDDs (>100ms) or SSDs (>10ms) = disk issue

# Check OS-level I/O stats
iostat -x 1 /dev/sdX
# Look for: await (queue latency), svctm (service time), %util
```

**Check network:**
```bash
# Verify OSD heartbeat connectivity
ceph daemon osd.<id> dump_watchers

# Check for packet loss or high RTT between OSD hosts
ping -c 100 <peer-osd-host>
```

**Check system resources:**
```bash
# CPU and memory pressure
top -b -n 1 | head -20

# Check kernel logs for I/O errors, filesystem issues
dmesg | tail -50
dmesg | grep -E "(error|fault|oom|blk_update_request)"

# Check OSD log for slow request patterns
grep -i "slow request" /var/log/ceph/ceph-osd.<id>.log | tail -20
grep -E "(suicide|assert|segfault)" /var/log/ceph/ceph-osd.<id>.log
```

**Recovery throttling (if recovery I/O is causing slowness):**
```bash
# Reduce recovery concurrency temporarily
ceph tell osd.* config set osd_recovery_max_active 1
ceph tell osd.* config set osd_recovery_max_active_hdd 1
ceph tell osd.* config set osd_recovery_max_active_ssd 2

# Restore after addressing root cause
ceph tell osd.* config set osd_recovery_max_active 3
```

---

## PG States

### Check PG states

```bash
ceph pg stat                           # Summary of all PG states
ceph pg dump                           # Full PG table (can be large)
ceph pg dump pgs_brief                 # Condensed PG table
ceph pg dump_stuck inactive            # Inactive PGs (I/O blocked)
ceph pg dump_stuck unclean             # Unclean PGs (recovery incomplete)
ceph pg dump_stuck stale               # PGs with no recent status report
ceph pg dump_stuck undersized          # PGs with fewer replicas than min_size
ceph pg dump_stuck degraded            # PGs with missing replicas
```

### PG state reference

| State | Meaning | I/O Possible |
|-------|---------|-------------|
| `active+clean` | Healthy; all replicas present and consistent | Yes |
| `active+degraded` | Fewer replicas than `size` but above `min_size` | Yes |
| `active+recovering` | Missing replicas being restored from existing | Yes |
| `active+backfilling` | OSD rejoined; data being moved to it | Yes |
| `active+remapped` | CRUSH mapping changed; data not yet moved | Yes |
| `peering` | OSDs negotiating authoritative object set | No |
| `inactive` | No I/O; all OSDs for this PG unavailable | No |
| `stale` | No status report from primary OSD | No |
| `undersized` | Active but below min_size replicas | No (write) |
| `inconsistent` | Scrub found data mismatch between replicas | Yes (degraded) |
| `repair` | Automatic repair after inconsistency | Yes |
| `snaptrimming` | Snap trim in progress | Yes |
| `wait` | Waiting for cluster resources | — |

### Diagnose a specific PG

```bash
# Detailed PG state including blocking info
ceph pg <pgid> query

# Force recovery for a stuck PG
ceph pg force-recovery <pgid>

# Force backfill for a stuck PG
ceph pg force-backfill <pgid>

# Trigger a repair after inconsistency
ceph pg repair <pgid>

# Mark an object as "lost" (last resort, data loss)
ceph pg <pgid> mark_unfound_lost revert
ceph pg <pgid> mark_unfound_lost delete
```

### Inactive PG recovery sequence

An inactive PG means no I/O is possible for that PG. The typical cause is all OSDs hosting that PG are down or not in quorum.

```bash
# Step 1: Check monitor quorum
ceph quorum_status
# All monitors should be in quorum. If not, fix monitors first.

# Step 2: Identify which OSDs the PG needs
ceph pg <pgid> query | grep -A 5 "acting"

# Step 3: Check those OSDs
ceph osd tree | grep "osd\.<id>"
systemctl status ceph-osd@<id>

# Step 4: If all OSDs for the PG are down and can be recovered, bring them up
systemctl start ceph-osd@<id>

# Step 5: If maintenance flags were set, clear them
ceph osd unset norecover
ceph osd unset nobackfill
ceph osd unset noin
ceph osd unset nodown

# Step 6: Watch recovery
ceph -w
```

---

## Recovery and Backfill

### Recovery vs backfill

- **Recovery:** Restoring missing replicas after an OSD was down. The cluster knows what was lost and actively re-creates it.
- **Backfill:** Migrating data to a new or rejoined OSD that needs to be populated with its assigned PGs.

### Monitor recovery progress

```bash
ceph status                            # Shows recovery rate, objects remaining
ceph -w                                # Live updates as recovery progresses
ceph pg stat                           # Shows degraded/misplaced object counts
```

Recovery output example:
```
recovery io 52 MiB/s, 23 keys/s, 345 objects/s
recovering 1234 objects
```

### Throttle recovery (balance with client I/O)

```bash
# Slow down recovery (allow more client I/O)
ceph tell osd.* config set osd_recovery_max_active_hdd 1
ceph tell osd.* config set osd_recovery_max_active_ssd 2
ceph tell osd.* config set osd_recovery_sleep_hdd 0.1    # 100ms sleep between ops

# Speed up recovery (prioritize data safety)
ceph tell osd.* config set osd_recovery_max_active_hdd 5
ceph tell osd.* config set osd_recovery_max_active_ssd 10
ceph tell osd.* config set osd_recovery_sleep_hdd 0

# Throttle backfill separately
ceph tell osd.* config set osd_max_backfills 2
```

### Set maintenance flags for controlled outages

```bash
# Before planned maintenance (prevents unnecessary rebalancing)
ceph osd set noout          # Don't automatically mark OSDs out
ceph osd set norecover      # Don't start new recovery
ceph osd set nobackfill     # Don't start new backfill

# After maintenance
ceph osd unset noout
ceph osd unset norecover
ceph osd unset nobackfill
```

---

## Clock Skew

Ceph monitors are extremely sensitive to clock skew. The Paxos consensus protocol requires accurate clocks; even 0.05 second differences trigger health warnings.

### Detect clock skew

```bash
ceph health detail | grep CLOCK_SKEW
ceph time-sync-status              # Show NTP status from monitor's perspective
```

### Fix clock skew

```bash
# On each monitor host, check NTP sync
chronyc tracking                    # Check offset and time source
timedatectl status                  # Verify NTP synchronization is active

# Force NTP sync
chronyc makestep

# Recommended: Use the same NTP server for all cluster nodes
# Configure /etc/chrony.conf or /etc/ntp.conf:
# server ntp.internal.example.com iburst prefer

# Monitors can peer with each other as NTP sources for sub-cluster accuracy
```

### Clock skew tolerance

The default tolerance is configurable but not recommended to increase beyond 1 second:
```bash
ceph tell mon.* config set mon_clock_drift_allowed 0.5  # increase tolerance temporarily
```

---

## Network Partitions

### Symptoms

- Multiple OSDs marked down simultaneously (especially across a network segment)
- Monitor election stuck
- PGs transitioning to inactive/peering in bulk
- `SLOW_OPS` on all OSDs in a rack or segment

### Diagnose

```bash
# Check monitor quorum status
ceph quorum_status

# Check OSD connectivity
ceph daemon osd.<id> dump_watchers    # Which OSDs this OSD watches
ceph tell osd.<id> get_backoff        # Check if OSD is backing off connections

# Check kernel-level network
ip link show
ethtool eth0                          # Link speed, duplex
netstat -s | grep -E "(retransmit|reset|error)"

# Test OSD-to-OSD connectivity
# From OSD host, connect to peer OSD's cluster port (default 6800+)
nc -z -v <peer_osd_host> 6800
```

### Recovery from network partition

```bash
# 1. Restore network connectivity (switch, cable, NIC)

# 2. OSDs that went down during the partition will re-peer automatically
#    Watch for peering completion:
ceph -w | grep "peering"

# 3. If OSDs got marked out during the partition and `noout` was not set:
ceph osd in <id>   # or let autofill bring them back

# 4. If monitors lost quorum and cannot recover:
#    Use monmaptool to rebuild the monitor map manually
ceph-mon --extract-monmap --name mon.<name> /tmp/monmap
monmaptool --print /tmp/monmap
# Edit as needed, then re-inject
ceph-mon --inject-monmap --name mon.<name> /tmp/monmap
```

---

## ceph tell Commands

The `ceph tell` command sends commands directly to running daemons without going through the socket file.

### Configuration injection (runtime, non-persistent)

```bash
# Apply to all OSDs
ceph tell osd.* config set <key> <value>
ceph tell osd.* injectargs '--<key>=<value>'

# Apply to a specific OSD
ceph tell osd.5 config set osd_recovery_max_active 1

# Apply to monitors
ceph tell mon.* config set <key> <value>

# Apply to a specific monitor
ceph tell mon.mon0 config set mon_osd_down_out_interval 600
```

**Important:** `injectargs` changes are runtime-only. For persistent changes, use `ceph config set`.

### Persistent configuration (config database)

```bash
# Set in the cluster-wide config database (persistent across restarts)
ceph config set osd osd_memory_target 8589934592
ceph config set osd.5 osd_memory_target 4294967296   # specific OSD

# View effective config for an OSD
ceph config show osd.5
ceph daemon osd.5 config show

# View config diff from defaults
ceph daemon osd.5 config diff
```

### OSD admin socket commands

```bash
# List all available admin socket commands for an OSD
ceph daemon osd.<id> help

# Performance counters
ceph daemon osd.<id> perf dump
ceph daemon osd.<id> perf reset            # Reset counters

# Operation inspection
ceph daemon osd.<id> dump_ops_in_flight    # Currently executing ops
ceph daemon osd.<id> dump_historic_ops     # Recently completed ops
ceph daemon osd.<id> dump_historic_slow_ops  # Recently completed slow ops

# BlueStore stats
ceph daemon osd.<id> bluestore stats

# PG queries
ceph daemon osd.<id> dump_pgs             # All PGs on this OSD

# Log level adjustment (temporary)
ceph daemon osd.<id> log-level debug       # Enable debug logging
ceph daemon osd.<id> log-level info        # Back to info
```

### Monitor admin socket commands

```bash
# Monitor status
ceph daemon mon.<name> mon_status
ceph daemon mon.<name> quorum_status

# Store inspection
ceph daemon mon.<name> dump_historic_ops

# Via socket file:
ceph --admin-daemon /var/run/ceph/ceph-mon.<name>.asok mon_status
```

---

## Log Analysis

### Log locations

| Daemon | Log path |
|--------|----------|
| Monitor | `/var/log/ceph/ceph-mon.<hostname>.log` |
| OSD | `/var/log/ceph/ceph-osd.<id>.log` |
| Manager | `/var/log/ceph/ceph-mgr.<hostname>.log` |
| MDS | `/var/log/ceph/ceph-mds.<hostname>.log` |
| RGW | `/var/log/ceph/ceph-client.rgw.<name>.log` |

With Cephadm (containerized), use:
```bash
ceph log last 50                             # Last 50 cluster log entries
ceph log last 100 debug                      # Debug-level entries
journalctl -u ceph-osd@<id>                 # Systemd journal for OSD
ceph orch daemon logs osd.<id>              # Cephadm container logs
```

### Useful grep patterns

```bash
# Slow requests
grep -i "slow request" /var/log/ceph/ceph-osd.1.log | tail -30

# OSD crashes
grep -E "(suicide|assert|segfault|SIGSEGV)" /var/log/ceph/ceph-osd.1.log

# Network/heartbeat issues
grep -i "heartbeat_check" /var/log/ceph/ceph-osd.1.log | tail -20

# RocksDB / BlueStore errors
grep -i "(bluestore|rocksdb)" /var/log/ceph/ceph-osd.1.log | grep -i error | tail -20

# PG peering events
grep "peering" /var/log/ceph/ceph-osd.1.log | tail -30

# Real-time monitoring
tail -f /var/log/ceph/ceph-osd.1.log | grep -E "(error|warn|slow)"
```

### Increase log verbosity temporarily

```bash
# Increase OSD logging (runtime, for debugging only)
ceph tell osd.<id> injectargs '--debug-osd=10 --debug-ms=1'

# Reset to defaults after debugging
ceph tell osd.<id> injectargs '--debug-osd=0 --debug-ms=0'
```

---

## Crash Reports

Ceph daemons write crash reports to `/var/lib/ceph/crash/` and report them to the MGR crash module.

```bash
# List crashes
ceph crash ls

# Detailed crash info (stack trace, version, etc.)
ceph crash info <crash-id>

# Archive a crash (mark as acknowledged)
ceph crash archive <crash-id>
ceph crash archive-all

# Remove RECENT_CRASH health warning after reviewing crashes
ceph crash archive-all
```

---

## Quick Diagnostic Runbook

### Cluster is HEALTH_WARN — initial triage

```bash
ceph health detail                          # Identify all active health codes
ceph status                                 # Check OSD/PG/MON counts
ceph osd tree | grep -E "(down|out)"        # Find down/out OSDs
ceph pg dump_stuck                          # Find stuck PGs
ceph df                                     # Check capacity
```

### Cluster is HEALTH_ERR — emergency triage

```bash
# Is monitor quorum intact?
ceph quorum_status

# Are there inactive PGs (I/O blocked)?
ceph pg dump_stuck inactive

# Which OSDs are these PGs waiting on?
ceph pg <pgid> query

# Bring those OSDs back if possible
systemctl start ceph-osd@<id>
ceph osd in <id>
```

### Data availability check

```bash
# Pool availability score (Tentacle 20.2+)
ceph osd pool availability-status

# Can we read/write to a pool?
rados -p <pool> put test-obj /etc/hostname
rados -p <pool> get test-obj /tmp/test-obj-out
rados -p <pool> rm test-obj
```

### Performance diagnosis

```bash
# Overall throughput and IOPS
ceph status | grep -A 5 "io:"

# Per-OSD latency
ceph osd perf

# Client I/O breakdown by pool
ceph iostat 1                               # 1-second interval
```
