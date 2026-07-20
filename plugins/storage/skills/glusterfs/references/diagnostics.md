# GlusterFS Diagnostics

## Essential Commands

```bash
gluster peer status                          # Cluster membership
gluster volume info myvol                    # Volume config
gluster volume status myvol                  # Process status (online/offline, PIDs, ports)
gluster volume status myvol clients          # Connected clients
gluster volume heal myvol info summary       # Heal backlog
gluster volume heal myvol info split-brain   # Split-brain files
```

## Log Locations

| Log | Path |
|-----|------|
| Management daemon | `/var/log/glusterfs/glusterd.log` |
| Self-heal daemon | `/var/log/glusterfs/glustershd.log` |
| Per-brick | `/var/log/glusterfs/bricks/<brick-path>.log` |
| FUSE client | `/var/log/glusterfs/etc-glusterfs-glusterfs.log` |
| Geo-replication | `/var/log/glusterfs/geo-replication/<master>/<slave>/` |

Adjust log level without restart:
```bash
gluster volume set myvol diagnostics.client-log-level DEBUG
gluster volume set myvol diagnostics.brick-log-level DEBUG
```

## Volume Heal

### Understanding

AFR marks files needing heal via `trusted.afr.*` xattrs. The shd crawls `/.glusterfs/indices/xattrop/` to find them.

### Commands

```bash
gluster volume heal myvol info summary               # Count per brick
gluster volume heal myvol info split-brain            # Split-brain files
gluster volume heal myvol                             # Trigger heal
gluster volume heal myvol full                        # Comprehensive crawl
watch -n 30 "gluster volume heal myvol info summary"  # Monitor progress
```

### Heal Not Progressing

1. Check shd is running: `gluster volume status myvol | grep "Self Heal"`
2. All bricks online: `gluster volume status myvol`
3. Split-brain blocking: `gluster volume heal myvol info split-brain`
4. Check shd log: `grep -i error /var/log/glusterfs/glustershd.log`
5. Restart shd: disable then re-enable `cluster.self-heal-daemon`

## Split-Brain Resolution

Split-brain occurs when replica bricks diverge with no authoritative source.

### Identify

```bash
gluster volume heal myvol info split-brain
getfattr -n replica.split-brain-status /mnt/gluster/path/to/file
```

### Resolution Strategies

**Bigger file wins:**
```bash
gluster volume heal myvol split-brain bigger-file /path/to/file
```

**Latest mtime wins:**
```bash
gluster volume heal myvol split-brain latest-mtime /path/to/file
```

**Specific brick as source (single file):**
```bash
gluster volume heal myvol split-brain source-brick server1:/brick1/data /path/to/file
```

**Specific brick for all split-brain:**
```bash
gluster volume heal myvol split-brain source-brick server1:/brick1/data
```

### GFID Split-Brain (Most Severe)

Same filename with different GFIDs on different bricks. Requires manual intervention: identify correct GFID, delete incorrect version from brick filesystem directly, trigger self-heal. Always backup first.

## Brick Failures

### Detecting

```bash
gluster volume status myvol
# Look for Online: N and Pid: N/A
tail -100 /var/log/glusterfs/bricks/data-brick1-data.log
```

### Replacing a Failed Brick

```bash
# Prepare replacement disk
mkfs.xfs -i size=512 -f /dev/sdc
mkdir -p /data/glusterfs/myvol/brick2 && mount /dev/sdc /data/glusterfs/myvol/brick2
mkdir -p /data/glusterfs/myvol/brick2/data

# Replace
gluster volume replace-brick myvol \
  oldserver:/data/brick2/data newserver:/data/brick2/data commit force

# Heal
gluster volume heal myvol
watch -n 30 "gluster volume heal myvol info summary"
```

### reset-brick (Same Path)

```bash
gluster volume reset-brick myvol server2:/data/brick2/data start
# Prepare new disk, mount to same path
gluster volume reset-brick myvol server2:/data/brick2/data server2:/data/brick2/data commit
gluster volume heal myvol
```

## Performance Troubleshooting

### Volume Profiling

```bash
gluster volume profile myvol start
# Wait 5-10 minutes for traffic
gluster volume profile myvol info    # Latency per call type, throughput
gluster volume profile myvol stop
```

### Top Files

```bash
gluster volume top myvol read-perf
gluster volume top myvol write-perf
gluster volume top myvol open
```

### Network Testing

```bash
iperf3 -s  # on target
iperf3 -c server2 -t 30 -P 4  # expect >800 MB/s on 10 GbE
```

## Common Error Patterns

| Error | Cause | Fix |
|---|---|---|
| `Transport endpoint is not connected` | Brick offline or quorum not met | Bring bricks online |
| `Input/output error` | Split-brain | Resolve split-brain |
| `Stale file handle` | GFID changed after brick replace | Allow heal to complete; remount |
| `No space left on device` (partial volume) | One brick full (DHT) | `gluster volume rebalance myvol start` |
| `peer rejected` | Conflicting cluster state | `gluster peer detach` from old pool |
| Geo-rep `Faulty` | SSH key or slave volume issue | Check geo-rep logs, re-run `push-pem` |

## Log Analysis

```bash
grep -i "error\|critical" /var/log/glusterfs/bricks/*.log | tail -50
grep -i "split.brain" /var/log/glusterfs/glustershd.log
grep -i "connected\|disconnected" /var/log/glusterfs/glusterd.log | tail -50
grep -i "ENOSPC" /var/log/glusterfs/bricks/*.log
```
