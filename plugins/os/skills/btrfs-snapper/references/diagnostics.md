# Btrfs/Snapper Diagnostics Reference

Troubleshooting procedures for Btrfs filesystem and Snapper snapshot issues on SLES 15+.

---

## Health Monitoring

### Quick Health Check

```bash
btrfs filesystem show /                    # Filesystem UUID, devices, total size
btrfs filesystem df /                      # Block group allocation by type/profile
btrfs filesystem usage /                   # Detailed free/used/allocated breakdown
btrfs device stats /                       # Error counters per device
btrfs scrub status /                       # Last scrub result
```

### dmesg Btrfs Errors

```bash
dmesg | grep -i btrfs
journalctl -k | grep -i btrfs
```

Common error patterns:

| Error | Likely Cause |
|---|---|
| `checksum mismatch` | Bit rot or RAM error; run scrub |
| `parent transid verify failed` | Filesystem corruption; may need btrfsck |
| `No space left` but df shows space | Metadata full; run balance |
| `Transaction aborted` | I/O error; check device stats and dmesg |

### Monitoring Commands

```bash
btrfs check --readonly /dev/sda2           # Offline check (read-only safe)
btrfs rescue zero-log /dev/sda2            # Clear log tree if blocking mount
btrfs rescue super-recover /dev/sda2       # Try backup superblocks
```

---

## Troubleshooting: ENOSPC ("No space left on device")

### Problem

`df` shows available space, but writes fail with ENOSPC. Btrfs metadata has its own block groups. When metadata is 100% allocated but data block groups have free space, Btrfs reports ENOSPC.

### Diagnosis

```bash
btrfs filesystem usage /
# Look for: Metadata: used much higher than free
# Also check: "Unallocated" space -- if zero, no new block groups can be created
```

### Resolution

```bash
# Free underused metadata block groups
btrfs balance start -musage=50 /

# If balance fails with ENOSPC:
btrfs balance start -musage=100 /

# Balance data too if needed
btrfs balance start -dusage=50 /

# Emergency: delete old snapshots to free metadata
snapper delete 1-20
btrfs balance start -musage=50 /
```

---

## Troubleshooting: Slow Write Performance

### Causes

1. Qgroup overhead (most common on systems with many snapshots)
2. Fragmentation from CoW scattered extents
3. Too many snapshots (each write checks CoW sharing)

### Diagnosis

```bash
iostat -x 1 10                            # Check I/O wait
btrfs qgroup show / 2>/dev/null | wc -l  # Number of qgroups (high = overhead)
btrfs subvolume list / | wc -l           # Number of subvolumes/snapshots
filefrag -v /path/to/slow/file           # Check fragmentation of specific file
```

### Resolution

```bash
# If qgroup overhead is the cause
btrfs quota disable /

# Delete excess snapshots
snapper cleanup number
snapper cleanup timeline

# If fragmentation is confirmed (verify space impact first)
btrfs filesystem defragment -r /usr
```

---

## Troubleshooting: Snapshot Accumulation / Disk Full

### Diagnosis

```bash
snapper list | wc -l                      # Total snapshot count
btrfs qgroup show -reF / | sort -k4 -h   # Largest exclusive-use snapshots
btrfs filesystem usage /                  # Overall space status
```

### Resolution

```bash
# Delete old snapshots
snapper delete 1-50

# Run all cleanup algorithms
snapper cleanup number
snapper cleanup timeline
snapper cleanup empty-pre-post

# Reduce retention policy in /etc/snapper/configs/root
# Then run cleanup again
```

---

## Troubleshooting: Failed Scrub

### Diagnosis

```bash
btrfs scrub status /
btrfs device stats /                      # Which device has errors
```

### Resolution

```bash
# If RAID 1 and one device is bad, replace it
btrfs replace start /dev/sda /dev/sdb /
btrfs replace status /

# If single device with uncorrectable errors
# Restore from backup -- scrub cannot repair without redundancy
```

---

## Troubleshooting: System Won't Boot After Update

### Resolution

1. At GRUB, select a snapshot entry from before the update
2. System boots into read-only snapshot
3. From the snapshot shell:
   ```bash
   snapper rollback
   reboot
   ```
4. System boots into the pre-update state as new writable root

### If GRUB Snapshot Entries Are Missing

```bash
rpm -q grub2-snapper-plugin               # Verify plugin installed
grub2-mkconfig -o /boot/grub2/grub.cfg    # Regenerate GRUB config
snapper list                               # Verify snapshots exist
```

---

## Troubleshooting: Qgroup Overhead

### Symptoms

- Write latency increases as snapshot count grows
- `btrfs qgroup show` is slow to complete
- System load increases during snapshot creation/deletion

### Diagnosis

```bash
btrfs qgroup show / | wc -l              # Count of qgroups
time btrfs qgroup show /                  # Time to query (>5s = overhead)
```

### Resolution

```bash
# Disable qgroups (loses per-snapshot size reporting)
btrfs quota disable /

# After disabling, snapper list will not show space usage
# Re-enable if needed later:
btrfs quota enable /
btrfs quota rescan /
```

---

## Troubleshooting: Btrfs Corruption

### Read-Only Check

Always start with read-only mode. Never run `btrfs check --repair` without SUSE support guidance.

```bash
# Offline read-only check (unmounted filesystem)
btrfs check --readonly /dev/sda2

# If log tree is corrupt and preventing mount
btrfs rescue zero-log /dev/sda2

# If superblock is corrupt
btrfs rescue super-recover /dev/sda2
```

### When to Contact SUSE Support

- `parent transid verify failed` errors
- `btrfs check --readonly` reports errors
- Filesystem mounts as read-only automatically
- Device stats show increasing `corruption_errs` or `generation_errs`

---

## Balance Status and Monitoring

```bash
btrfs balance status /
# "No balance found" or running balance details

# Monitor a running balance
watch -n 10 'btrfs balance status /'
```

---

## Subvolume and Snapshot Inventory

```bash
# Total subvolumes (including snapshots)
btrfs subvolume list / | wc -l

# Snapper-managed snapshots
snapper list | wc -l

# Default subvolume (boot target)
btrfs subvolume get-default /

# Verify snapshot is read-only
btrfs property get /.snapshots/42/snapshot ro
```
