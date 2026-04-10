# GlusterFS Diagnostics and Troubleshooting

## Essential Reference Commands

```bash
# Cluster and peer state
gluster peer status
gluster pool list

# Volume configuration
gluster volume info
gluster volume info myvol

# Volume process status (online/offline, PIDs, ports)
gluster volume status myvol
gluster volume status myvol detail     # includes counters and memory usage
gluster volume status myvol clients    # connected clients

# Self-heal overview
gluster volume heal myvol info
gluster volume heal myvol info summary
gluster volume heal myvol info split-brain

# Trigger manual heal
gluster volume heal myvol
gluster volume heal myvol full         # comprehensive crawl (slow, use during maintenance)
```

---

## Log File Locations

| Log File | Contents |
|---|---|
| `/var/log/glusterfs/glusterd.log` | Management daemon (cluster membership, volume config changes) |
| `/var/log/glusterfs/glustershd.log` | Self-heal daemon (files being healed, sources and sinks) |
| `/var/log/glusterfs/bricks/<brick-path>.log` | Per-brick process log (IO errors, xattr issues) |
| `/var/log/glusterfs/etc-glusterfs-glusterfs.log` | FUSE mount client log |
| `/var/log/glusterfs/glfsheal-<volname>.log` | Heal info command output log |
| `/var/log/glusterfs/geo-replication/<master>/<slave>/` | Geo-replication gsync daemon logs |
| `/var/log/nfs-ganesha.log` | NFS-Ganesha server log |

Log level can be adjusted without restart:
```bash
gluster volume set myvol diagnostics.client-log-level DEBUG
gluster volume set myvol diagnostics.brick-log-level DEBUG
```

---

## Volume Heal

### Understanding the Heal Index

GlusterFS AFR (replication) marks files needing heal by writing xattrs to bricks:
- `trusted.afr.<volname>-client-N` — Non-zero values indicate pending heal for data (first 8 bytes) or metadata (next 8 bytes).
- `/.glusterfs/indices/xattrop/` — Hard links to files with non-zero AFR xattrs. The self-heal daemon and `glfsheal` scan this directory.

### Heal Status Commands

```bash
# Count of files needing heal across all bricks
gluster volume heal myvol info summary

# Full list of files needing heal (can be very long on large clusters)
gluster volume heal myvol info

# Only files in split-brain state
gluster volume heal myvol info split-brain

# Detailed heal statistics
gluster volume heal myvol statistics
gluster volume heal myvol statistics heal-count
gluster volume heal myvol statistics heal-count replica server1:/brick1
```

### Triggering and Monitoring Heal

```bash
# Trigger heal (non-blocking; heal runs in background)
gluster volume heal myvol

# Force full crawl of all inodes (blocking; use during maintenance)
gluster volume heal myvol full

# Watch heal progress (poll every 30s)
watch -n 30 "gluster volume heal myvol info summary"

# Check shd log for active healing
tail -f /var/log/glusterfs/glustershd.log
```

### Common Heal Issues

**Heal not progressing (count not decreasing):**
1. Check if self-heal daemon is running: `gluster volume status myvol | grep "Self Heal Daemon"`
2. Verify all bricks are online: `gluster volume status myvol`
3. Check for split-brain entries blocking heal: `gluster volume heal myvol info split-brain`
4. Check shd log for errors: `grep -i error /var/log/glusterfs/glustershd.log`
5. Restart self-heal daemon if stuck: `gluster volume heal myvol enable` / `gluster volume heal myvol disable` then re-enable

**Self-heal daemon not starting:**
```bash
# Check status
gluster volume get myvol cluster.self-heal-daemon

# Enable if disabled
gluster volume set myvol cluster.self-heal-daemon on

# Check glusterd log for errors
grep "self-heal" /var/log/glusterfs/glusterd.log
```

---

## Split-Brain Detection and Resolution

### What is Split-Brain

Split-brain occurs when bricks in a replica set have diverged — different file content or metadata — and there is no authoritative source for automatic resolution. This happens when:
- Both bricks were written to independently while they couldn't communicate (network partition).
- A brick rejoined after failure but had concurrent writes on both sides.
- GFID mismatch: files or directories in different replica pairs have different GFIDs (most severe form).

Symptoms:
- `Input/output error` when accessing affected files from a FUSE mount.
- Files listed in `gluster volume heal myvol info split-brain`.
- `Is in split-brain` annotation in `gluster volume heal myvol info` output.

### Step 1: Identify Split-Brain Files

```bash
# List all split-brain files
gluster volume heal myvol info split-brain

# On the mount point, check a specific file
getfattr -n replica.split-brain-status /mnt/gluster/path/to/file
```

### Step 2: Choose Resolution Strategy

**Option A: Bigger-file wins (for data split-brain)**
Use when you know the larger file is the correct version:
```bash
gluster volume heal myvol split-brain bigger-file /path/to/file
```

**Option B: Latest modification time wins**
Use when the most recently modified version is correct:
```bash
gluster volume heal myvol split-brain latest-mtime /path/to/file
```

**Option C: Designate a specific brick as authoritative (single file)**
Use when you know which brick has the correct data:
```bash
# Get the list of bricks
gluster volume info myvol

# Use a specific brick as source for one file
gluster volume heal myvol split-brain source-brick server1:/brick1/data /path/to/file
```

**Option D: Designate a brick as authoritative for all split-brain files**
Resolves all split-brain files on the volume using the named brick as source:
```bash
gluster volume heal myvol split-brain source-brick server1:/brick1/data
```

**Option E: Manual resolution via mount point extended attributes**

```bash
# Check split-brain status for a file
getfattr -n replica.split-brain-status /mnt/gluster/path/to/file

# List available choices (shows GFID and brick for each version)
getfattr -n replica.split-brain-choice /mnt/gluster/path/to/file

# Select the authoritative copy
setfattr -n replica.split-brain-choice -v "choice0" /mnt/gluster/path/to/file

# Finalize healing
setfattr -n replica.split-brain-heal-finalize -v "choice0" /mnt/gluster/path/to/file

# Reset choice to allow normal IO
setfattr -n replica.split-brain-choice -v "none" /mnt/gluster/path/to/file
```

Note: Mount-point xattr resolution does not work for entry (GFID) split-brain or via NFS mounts.

### GFID Split-Brain (Most Severe)

GFID split-brain occurs when the same filename on different bricks has been assigned different GFIDs. This is the hardest to resolve and typically requires manual intervention:

```bash
# Identify GFID mismatch
getfattr -n trusted.gfid /brick1/path/to/file
getfattr -n trusted.gfid /brick2/path/to/file
# If values differ, this is a GFID split-brain

# Resolution: decide which GFID is correct, then on the incorrect brick:
# 1. Copy the correct file to a temp location
# 2. Delete the file from the brick's filesystem directly (not via mount)
# 3. Trigger self-heal to restore it with the correct GFID
```

GFID split-brain often requires escalation and careful manual steps. Always make backups before attempting GFID split-brain resolution.

---

## Brick Failures

### Detecting Brick Failures

```bash
# Check brick status
gluster volume status myvol

# Look for bricks showing "N" in Online column
# Example output:
# Brick                    TCP Port RDMA Port Online Pid
# server1:/data/brick1/data  49152    0         Y     1234
# server2:/data/brick2/data  N/A      N/A       N     N/A  <-- offline

# Check brick logs for root cause
tail -100 /var/log/glusterfs/bricks/data-glusterfs-myvol-brick1-data.log
```

### Starting an Offline Brick

If a brick process crashed but the disk is healthy:
```bash
# Restart all brick processes for a volume
gluster volume stop myvol
gluster volume start myvol

# Or restart glusterd on the affected node (starts all brick processes)
systemctl restart glusterd
```

### Replacing a Failed Brick

Use this procedure when a disk has physically failed and must be replaced.

**Step 1: Identify the failed brick**
```bash
gluster volume status myvol
gluster volume heal myvol info summary
```

**Step 2: Prepare the replacement disk**
```bash
# Format new disk with XFS (isize=512 is critical)
mkfs.xfs -i size=512 -f /dev/sdc

# Mount to the same or new path
mkdir -p /data/glusterfs/myvol/brick2
mount /dev/sdc /data/glusterfs/myvol/brick2

# Add to fstab
echo "/dev/sdc /data/glusterfs/myvol/brick2 xfs defaults,inode64,noatime 0 0" >> /etc/fstab

# Create brick export subdirectory
mkdir -p /data/glusterfs/myvol/brick2/data
```

**Step 3: Replace the brick**
```bash
# Replace in the volume
gluster volume replace-brick myvol \
  server2:/data/glusterfs/myvol/brick2/data \
  server2:/data/glusterfs/myvol/brick2/data \
  commit force

# If replacing with a brick on a NEW node (add node to pool first):
gluster peer probe newserver
gluster volume replace-brick myvol \
  oldserver:/data/glusterfs/myvol/brick2/data \
  newserver:/data/glusterfs/myvol/brick2/data \
  commit force
```

**Step 4: Trigger self-heal**
```bash
gluster volume heal myvol

# Monitor progress
watch -n 30 "gluster volume heal myvol info summary"
```

**Step 5: Verify**
```bash
gluster volume info myvol
gluster volume status myvol
gluster volume heal myvol info summary
# All bricks should be Online, heal count should reach 0
```

### Alternative: reset-brick Procedure

For same-path replacement (disk replaced, same server, same mount point):
```bash
# Step 1: Reset the brick
gluster volume reset-brick myvol server2:/data/brick2/data start

# Step 2: Prepare new disk and mount to same path (see above)

# Step 3: Commit the reset
gluster volume reset-brick myvol server2:/data/brick2/data server2:/data/brick2/data commit

# Step 4: Heal
gluster volume heal myvol
```

---

## Performance Troubleshooting

### Identifying Slow Operations

```bash
# Enable volume profiling
gluster volume profile myvol start

# Wait for traffic to accumulate (5-10 minutes minimum)
# Read profile stats
gluster volume profile myvol info

# Disable profiling
gluster volume profile myvol stop
```

Key metrics in profile output:
- `Latency` per call type (LOOKUP, READ, WRITE, STAT) — high values indicate bottlenecks
- `Cumulative Bytes Read/Written` — raw throughput indicator
- `Number of calls` — identifies hot operation types

### Top Files by Activity

```bash
# Top files by read performance
gluster volume top myvol read-perf

# Top files by write performance
gluster volume top myvol write-perf

# Most opened files
gluster volume top myvol open

# Most active directories (readdir)
gluster volume top myvol readdir

# Top brick IO (per brick)
gluster volume top myvol read bs 128 count 10 nfs=on
```

### Diagnosing High Heal Backlog

A sustained and growing heal backlog degrades write performance (AFR must coordinate healing). Root causes:

1. **Network instability** — bricks frequently going offline/online. Check: `ping` between nodes, network error counters.
2. **Slow disk on one brick** — healer can't keep up with incoming changes. Check brick disk IO stats.
3. **Too many small files** — heal of millions of small files is slow. Normal; allow time to drain.
4. **Self-heal daemon crashed** — `gluster volume status myvol | grep "Self Heal"`. Restart glusterd if needed.

```bash
# Check if heal backlog is growing or shrinking
gluster volume heal myvol statistics heal-count
# Run twice 5 minutes apart and compare
```

### Network Performance Testing

```bash
# Test raw network throughput between nodes (iperf3)
# On receiver:
iperf3 -s

# On sender:
iperf3 -c server2 -t 30 -P 4

# Expected minimum for GlusterFS: >800 MB/s on 10GbE
```

### Strace / Debug Mode

For deep investigation of specific file operation hangs:
```bash
# Enable debug logging on client mount
mount -t glusterfs -o log-level=DEBUG server1:myvol /mnt/debug-mount

# Or set dynamically (no remount needed)
gluster volume set myvol diagnostics.client-log-level DEBUG

# Trace system calls for a specific process
strace -f -e trace=file,desc -p <glusterfs-client-pid>
```

---

## gluster volume info / status — Output Reference

### `gluster volume info`

```
Volume Name: myvol
Type: Distributed-Replicate
Volume ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Status: Started
Snapshot Count: 0
Number of Bricks: 2 x 3 = 6
Transport-type: tcp
Bricks:
Brick1: server1:/data/brick1/data
Brick2: server2:/data/brick1/data
Brick3: server3:/data/brick1/data
Brick4: server4:/data/brick2/data
Brick5: server5:/data/brick2/data
Brick6: server6:/data/brick2/data
Options Reconfigured:
...
```

Interpretation:
- `Type: Distributed-Replicate` confirms DHT + AFR stack.
- `2 x 3 = 6` means 2 distributed sets of replica-3. Order matters: bricks 1-3 are replica set 1, bricks 4-6 are replica set 2.
- `Status: Started` — volume is running. `Status: Created` means not yet started.

### `gluster volume status myvol`

```
Status of volume: myvol
Gluster process                             TCP Port  RDMA Port  Online  Pid
-------------------------------------------------------------------------------
Brick server1:/data/brick1/data              49152     0          Y       12345
Brick server2:/data/brick1/data              49153     0          Y       12346
Brick server3:/data/brick1/data              49152     0          N       N/A
...
Self Heal Daemon on localhost                N/A       N/A        Y       12400
...
Task Status of Volume myvol
-------------------------------------------------------------------------------
There are no active volume tasks
```

Key fields:
- `Online: Y/N` — Whether the brick process is reachable.
- `Pid: N/A` — Brick process is not running.
- `Self Heal Daemon` — Should always show `Y` for replicated volumes.

### `gluster volume heal myvol info summary`

```
Brick server1:/data/brick1/data
 Number of entries: 0

Brick server2:/data/brick1/data
 Number of entries: 5

Brick server3:/data/brick1/data
 Number of entries: 5
```

`Number of entries: 0` on all bricks = healthy state, no pending heals.

---

## Common Error Patterns and Fixes

| Error | Likely Cause | Fix |
|---|---|---|
| `Transport endpoint is not connected` | Brick offline or quorum not met | `gluster volume status`; bring bricks online |
| `Input/output error` on file access | Split-brain condition | `gluster volume heal myvol info split-brain`; resolve split-brain |
| `Stale file handle` after remount | GFID changed (often after brick replace without heal) | Allow heal to complete; remount client |
| `No space left on device` on partially-full volume | One brick is full while others have space (DHT issue) | Rebalance: `gluster volume rebalance myvol start`; also check individual brick usage |
| Heal count not decreasing | Self-heal daemon issue or split-brain blocking | Check shd log; resolve split-brain entries |
| Very high latency on replicated volume | Network issue between replica nodes | Check inter-node latency and packet loss |
| `peer rejected` on peer probe | Conflicting cluster state | Check if target node already belongs to a different pool; clear with `gluster peer detach` |
| Geo-rep session `Faulty` state | SSH key issue or slave volume error | Check geo-rep logs in `/var/log/glusterfs/geo-replication/`; re-run `push-pem` |

---

## Log Analysis Patterns

```bash
# Check for brick-level errors in last 100 lines
grep -i "error\|critical\|warn" /var/log/glusterfs/bricks/data-brick1-data.log | tail -50

# Find split-brain events in self-heal log
grep -i "split.brain\|split-brain" /var/log/glusterfs/glustershd.log

# Find heal source/sink assignments
grep -i "source\|sink" /var/log/glusterfs/glustershd.log | tail -20

# Identify peer connection events
grep -i "connected\|disconnected\|peer" /var/log/glusterfs/glusterd.log | tail -50

# Check for full brick warnings
grep -i "ENOSPC\|no space" /var/log/glusterfs/bricks/*.log

# Geo-replication sync errors
grep -i "ERROR\|FAIL" /var/log/glusterfs/geo-replication/myvol/slave-server1-slave-vol/gsyncd.log
```
