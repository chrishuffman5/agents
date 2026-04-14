# Btrfs/Snapper Best Practices Reference

Best practices for Btrfs filesystem management and Snapper snapshot operations on SLES 15+.

---

## Snapshot Retention Policies

### Recommended SLES Default

```ini
TIMELINE_CREATE="yes"
TIMELINE_LIMIT_HOURLY="4"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="6"
TIMELINE_LIMIT_YEARLY="0"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
```

This retains ~21 timeline snapshots at steady state, plus up to 50 number-cleanup snapshots including zypper pre/post pairs.

### Disk Space Planning

Rule of thumb: snapshots consume space proportional to change rate. A busy system may accumulate 5-20 GB per week. Plan for at least 20-40% extra disk space beyond OS data.

```bash
btrfs filesystem usage /      # Detailed free/used/allocated breakdown
btrfs qgroup show -reF /      # Per-snapshot exclusive usage (if qgroups enabled)
```

### High-Change Systems

For systems with frequent package updates or configuration changes, reduce retention:

```ini
TIMELINE_LIMIT_HOURLY="2"
TIMELINE_LIMIT_DAILY="3"
TIMELINE_LIMIT_WEEKLY="2"
TIMELINE_LIMIT_MONTHLY="3"
NUMBER_LIMIT="30"
```

### Minimal-Change Systems

For stable production servers with infrequent changes, increase retention:

```ini
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="14"
TIMELINE_LIMIT_WEEKLY="8"
TIMELINE_LIMIT_MONTHLY="12"
TIMELINE_LIMIT_YEARLY="2"
NUMBER_LIMIT="100"
```

---

## Maintenance Schedule

### Scrub (Data Integrity)

Run monthly on production systems. Reads all data and metadata, verifies checksums, repairs corrupt blocks using redundant copies.

```bash
# SLES ships btrfs-scrub@.timer
systemctl enable --now btrfs-scrub@-.timer
systemctl status btrfs-scrub@-.timer

# Manual scrub
btrfs scrub start /
btrfs scrub status /
```

### Balance (Space Reclamation)

Run quarterly or when metadata saturation is observed. Redistributes data across block groups and reclaims underused space.

```bash
# Conservative balance (only half-empty chunks)
btrfs balance start -dusage=50 -musage=50 /

# Full balance (long-running, schedule in maintenance window)
btrfs balance start /
```

Balance is I/O-intensive. Use `-dusage=` filters to limit scope.

### Defragmentation

Run only when fragmentation is confirmed and there are no active snapshots to preserve. Defragmentation breaks CoW sharing.

```bash
# Defrag specific directory (recompresses with zstd)
btrfs filesystem defragment -r -v -czstd /usr

# Defrag RPM database
btrfs filesystem defragment -v /var/lib/rpm/rpmdb.sqlite
```

### Timer Verification

```bash
systemctl list-timers | grep -E 'btrfs|snapper'
# Should show: btrfs-scrub@-.timer, snapper-timeline.timer, snapper-cleanup.timer
```

---

## Backup Integration

### Btrfs send/receive (Incremental)

The most bandwidth-efficient backup method for Btrfs. Sends only changed extents since a parent snapshot.

```bash
# Full send
btrfs send /.snapshots/42/snapshot | btrfs receive /mnt/backup/

# Incremental (parent must exist on destination)
btrfs send -p /.snapshots/41/snapshot /.snapshots/42/snapshot | btrfs receive /mnt/backup/

# Over SSH with compression
btrfs send -p /.snapshots/41/snapshot /.snapshots/42/snapshot | \
  ssh backup-host "btrfs receive /mnt/backup/"
```

Requirements: Both source snapshots must be read-only. Parent snapshot must exist on destination.

### Snapper + rsync

Snapshots provide a consistent point-in-time view for rsync:

```bash
rsync -avz --delete /.snapshots/42/snapshot/etc /backup/etc/
rsync -avz --delete /.snapshots/42/snapshot/home /backup/home/
```

### Critical: Snapshots Are NOT Backups

Snapshots reside on the same physical device. A device failure, `mkfs`, or ransomware with write access destroys all snapshots with the live data. Always maintain off-device backups.

---

## CoW Optimization

### Disable CoW for Database and VM Files

```bash
# Per-directory (before creating files)
mkdir /var/lib/mysql
chattr +C /var/lib/mysql

# Verify
lsattr -d /var/lib/mysql
# Should show 'C' attribute

# Recommended nodatacow paths:
# /var/lib/libvirt/images/
# /var/lib/mysql/
# /var/lib/pgsql/
# /var/lib/docker/
```

### Compression Strategy

- Text, logs, source code: `zstd:3` (60-80% reduction)
- Binary executables: `zstd:3` (30-50%)
- Already-compressed data: skip with `chattr +m`
- SAP HANA data volumes: use XFS, not Btrfs

---

## Subvolume Design

### Adding Custom Subvolumes

When deploying new applications, create dedicated subvolumes to control snapshot behavior:

```bash
# Create subvolume for application data (excluded from root snapshots)
btrfs subvolume create /var/lib/myapp

# Add to fstab for independent mounting
echo '/dev/sda2  /var/lib/myapp  btrfs  defaults,subvol=@/var/lib/myapp  0 0' >> /etc/fstab
```

### Subvolume Guidelines

1. Data that should survive rollback: create a separate subvolume (databases, user data)
2. Data that should roll back with the OS: keep in the root subvolume (config in /etc)
3. Temporary data: separate subvolume with `nodatacow` if high churn
4. VM images: separate subvolume with `nodatacow` and no compression

---

## Monitoring

### Key Metrics to Watch

```bash
# Metadata saturation (most critical)
btrfs filesystem usage / | grep -A2 "Metadata"

# Device errors (hardware health)
btrfs device stats /

# Snapshot count (performance indicator)
btrfs subvolume list / | wc -l

# Qgroup count (write overhead indicator)
btrfs qgroup show / 2>/dev/null | wc -l
```

### Alert Thresholds

| Metric | Warning | Critical |
|---|---|---|
| Metadata usage | 75% | 90% |
| Device error counters | Any non-zero | Increasing trend |
| Snapshot count | >100 | >200 |
| Scrub errors | Any | Uncorrectable |
