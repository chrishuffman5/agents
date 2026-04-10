# NetApp ONTAP Diagnostics and Troubleshooting

## CLI Access and Privilege Levels

ONTAP CLI has three privilege levels:
- `admin` — normal operations
- `advanced` — extended diagnostics (toggle with `set -privilege advanced`)
- `diagnostic` — deepest internals (toggle with `set -privilege diagnostic`); use only under NetApp support guidance

```bash
# Enter advanced mode (most diagnostics commands live here)
set -privilege advanced

# Return to admin mode
set -privilege admin
```

---

## Performance Counters and Monitoring

### System-Level Statistics

```bash
# Real-time system statistics (CPU, NFS ops, CIFS ops, disk I/O, net I/O)
# Runs every N seconds; Ctrl+C to stop
statistics show-periodic -preset basic -interval 5

# Detailed periodic statistics with specific objects
statistics show-periodic -object node -counter cpu_busy,read_ops,write_ops -interval 5

# One-time snapshot of all performance counters for a node
statistics show -node <node_name>

# Display system-level sysstat (legacy but still useful)
# From node shell:
system node run -node <node> -command "sysstat -s 5"
```

### Volume-Level Performance

```bash
# Volume IOPS and throughput
statistics show -object volume -instance <vol_name> -counter read_ops,write_ops,read_data,write_data

# Volume latency (microseconds)
statistics show -object volume -instance <vol_name> -counter read_latency,write_latency,other_latency

# All volumes, sorted by read latency descending
statistics show -object volume -counter read_latency -sort-key read_latency -rows 20

# QoS statistics per volume (throughput and latency from QoS policy perspective)
qos statistics volume latency show
qos statistics volume performance show

# Persistent performance data from the performance archive
statistics catalog object show -object volume
```

### Node-Level Performance

```bash
# Node CPU utilization
statistics show -object system -counter cpu_busy -node <node>

# NFS operations per second
statistics show -object nfsv3 -counter read_ops,write_ops,lookup_ops -node <node>

# SMB operations per second
statistics show -object cifs -counter read_ops,write_ops -node <node>

# iSCSI operations
statistics show -object iscsi_lif -counter iscsi_read_ops,iscsi_write_ops

# Disk read/write latency at the aggregate level
statistics show -object aggregate -instance <aggr_name> -counter total_read_ops,total_write_ops,read_latency,write_latency
```

### Network Throughput and Latency Between Nodes

```bash
# Measure throughput and latency between two nodes
network test-path -source-node <node1> -destination-node <node2> -session-type default

# For SnapMirror (async) replication path test
network test-path -source-node <node1> -destination-node <node2> -session-type AsyncMirrorRemote

# For SnapMirror sync replication
network test-path -source-node <node1> -destination-node <node2> -session-type SyncMirrorRemote

# Display interface statistics (errors, drops, throughput)
network interface show -vserver <svm> -fields address,status-oper,is-home
statistics show -object lif -instance <lif_name> -counter recv_data,sent_data,recv_errors,sent_errors
```

---

## Latency Analysis

### Identifying High-Latency Volumes

```bash
# Top volumes by read latency (requires advanced privilege)
set -privilege advanced
statistics top client show -display latency -rows 20

# Show volume latency breakdown by operation type
statistics show -object volume -instance <vol_name> -counter read_latency,write_latency,other_latency,avg_latency

# Active IQ Unified Manager: use for trend analysis and workload correlation
# CLI alternative for latency distribution:
statistics show -object wafl -counter cp_phase_times -node <node>
```

### Disk-Level Latency

```bash
# Check disk response times (I/O service time per physical disk)
storage disk show -fields disk,type,avg-latency,model
# Note: avg-latency requires 'statistics' counters to be running

# Disk throughput and latency via statistics
statistics show -object disk -instance <disk_name> -counter disk_busy,io_pending,read_latency,write_latency

# Identify busy disks in an aggregate
storage aggregate show-status -aggregate <aggr_name>

# Disk utilization summary per aggregate
statistics show -object aggregate -counter disk_busy -interval 5
```

### WAFL Latency (Internal Filesystem Delays)

```bash
# WAFL consistency point timing
statistics show -object wafl -counter cp_count,cp_from_timer,cp_from_nvlog_full -node <node>

# High cp_from_nvlog_full values indicate NVRAM is filling faster than CPs can drain
# — indicates workload exceeds the system's write throughput capacity

# WAFL read/write cache efficiency
statistics show -object wafl -counter read_hits,read_misses,write_hits -node <node>
```

---

## Disk Failures and RAID

### Identifying Failed Disks

```bash
# Show all disks with their state (failed, spare, data, parity)
storage disk show -fields disk,type,state,node,aggregate,position

# Show only failed or broken disks
storage disk show -state broken
storage disk show -state failed

# Show disk errors and error counts
storage disk error show

# Show disk shelf and bay location for physical identification
storage disk show -fields disk,shelf,bay,serial-number,model
```

### RAID Group Status

```bash
# Check aggregate RAID status (degraded, reconstructing, etc.)
storage aggregate show -state degraded
storage aggregate show -fields raid-status,state,size

# Detailed RAID group view
storage aggregate show-status -aggregate <aggr_name>

# Show reconstruction progress (percent complete and time remaining)
storage aggregate show -fields reconstruct-percent,reconstruct-eta

# List all RAID groups in an aggregate
storage aggregate show-status -aggregate <aggr_name> -fields disk-name,position,state,used-size
```

### Disk Replacement Workflow

```bash
# 1. Confirm disk failure
storage disk show -state broken

# 2. Check if aggregate is degraded
storage aggregate show -state degraded

# 3. Pull the failed disk (physical replacement)
# After replacement, ONTAP auto-reconstructs from a spare

# 4. Monitor reconstruction progress
storage aggregate show -fields reconstruct-percent
# or
event log show -severity NOTICE -message-name raid.rg.recons*

# 5. Verify aggregate returns to optimal state
storage aggregate show -aggregate <aggr_name> -fields state,raid-status
# Expected: state=online, raid-status=raid_dp (or raid_tec)
```

### Adding Spare Disks

```bash
# Assign unowned disks as spare to a node
storage disk assign -disk <disk_id> -owner <node_name>

# Show spare disks available
storage aggregate show-spare-disks -original-owner <node>

# Manually add a spare to an aggregate (ONTAP auto-assigns normally)
storage aggregate add-disks -aggregate <aggr_name> -diskcount 1
```

---

## SnapMirror Lag Troubleshooting

### Checking SnapMirror Status and Lag

```bash
# Show all SnapMirror relationships with lag time
snapmirror show -fields source-path,destination-path,relationship-status,mirror-state,lag-time

# Show lag time for a specific relationship
snapmirror show -destination-path <svm>:<vol> -fields lag-time,last-transfer-duration,last-transfer-size

# Show the exported (last transferred) Snapshot
snapmirror show -destination-path <svm>:<vol> -fields exported-snapshot,lag-time

# Show relationships in error state
snapmirror show -relationship-status transferring,failed,error
```

### Understanding Lag Time Calculation
SnapMirror lag = system time on destination — timestamp of the last transferred Snapshot when the transfer completed.

Common causes of elevated lag:
1. **Transfer in progress**: a long baseline or large incremental transfer is running
2. **Scheduled transfer missed**: throttle limits, network outage, or source/destination busy
3. **Clock skew**: source and destination system clocks are not synchronized (use NTP)
4. **Network bandwidth insufficient**: transfers take longer than the schedule interval
5. **Cascaded relationships out of order**: the intermediate destination hasn't completed its transfer before the final destination attempts its transfer

```bash
# Check system time on source and destination
cluster time-service ntp status show
date

# Check NTP servers
cluster time-service ntp server show

# View transfer history
snapmirror show -fields last-transfer-end-timestamp,last-transfer-duration,last-transfer-size
```

### Troubleshooting Transfer Failures

```bash
# Show SnapMirror transfer errors
snapmirror show -fields relationship-status,unhealthy-reason
snapmirror list-destinations

# View SnapMirror event log
event log show -severity ERROR -message-name scsimgr*,repl.*,snapmirror.*

# Abort a stuck transfer and restart
snapmirror abort -destination-path <svm>:<vol>
snapmirror update -destination-path <svm>:<vol>

# Full resync after relationship goes out of sync
snapmirror resync -destination-path <svm>:<vol>

# Check network path quality for SnapMirror traffic
network test-path -source-node <src_node> -destination-node <dst_node> -session-type AsyncMirrorRemote
```

### Optimizing SnapMirror Throughput

```bash
# Set throttle on a relationship (KB/s)
snapmirror modify -destination-path <svm>:<vol> -throttle 0  # 0 = unlimited
snapmirror modify -destination-path <svm>:<vol> -throttle 100000  # ~100 MB/s

# Check intercluster LIF connectivity
network interface show -role intercluster
ping -lif <intercluster_lif> -destination <remote_intercluster_ip>

# Monitor transfer in real time
snapmirror show -fields source-path,destination-path,transfer-bytes,transfer-snapshot
```

---

## Network Troubleshooting

### Interface Status and Errors

```bash
# Show all LIFs and their current home/current port
network interface show -vserver <svm>

# Show LIFs that are NOT on their home node (may indicate failover event)
network interface show -is-home false

# Revert a LIF to its home port
network interface revert -vserver <svm> -lif <lif_name>

# Show physical port statistics (link errors, drops, CRC errors)
network port show -node <node> -port <port>
statistics show -object port -instance <node>:<port> -counter recv_errors,sent_errors,link_down_count

# Show port speed and duplex
network port show -fields node,port,speed,duplex,mtu,link

# Ping from a specific LIF to test reachability
network ping -lif <lif_name> -destination <ip> -count 5
```

### MTU and Jumbo Frame Verification

```bash
# Verify MTU on ONTAP ports
network port show -fields mtu

# Test MTU to a host (large packet ping)
network ping -lif <lif_name> -destination <host_ip> -size 8972  # 9000 - IP/ICMP headers

# Show VLAN configuration
network port vlan show

# Show interface group (LACP/802.3ad) configuration
network port ifgrp show
```

### DNS and Name Resolution

```bash
# Test DNS resolution from the cluster
set -privilege advanced
vserver services name-service dns check -vserver <svm>

# Show DNS configuration
vserver services name-service dns show

# Resolve a hostname from a specific SVM
vserver services name-service getxxbyyy getaddrinfo -vserver <svm> -hostname <hostname>
```

---

## Key Diagnostic Commands Reference

### Storage and Space

```bash
# Volume space usage (including Snapshot and reserve)
volume show -fields size,available,used,percent-used,snapshot-reserve-percent

# Detailed space breakdown (footprint: data, metadata, Snapshot)
volume show-footprint -vserver <svm> -volume <vol>

# Aggregate free space
storage aggregate show -fields size,used,available,percent-used

# File system IOPS and latency top clients
statistics top client show -rows 20

# Show efficiency savings
volume efficiency show -vserver <svm> -volume <vol> -fields total-saved,savings-percent
```

### Events and Errors

```bash
# Show recent error events
event log show -severity error -time-range 1h

# Show all recent events
event log show -rows 50

# Show hardware-related alerts
system health alert show

# Show disk errors
storage disk error show

# EMS (Event Management System) — show messages matching pattern
event log show -message-name "raid.*" -severity ERROR
event log show -message-name "wafl.*" -severity ERROR

# Show ASUP (AutoSupport) history
system node autosupport history show
```

### Cluster Health

```bash
# Overall cluster health
cluster show

# Node status
system node show

# HA pair status (failover state)
storage failover show

# Takeover eligibility
storage failover show -fields takeover-state,can-takeover,giveback-state

# Check for failed fans, power supplies, temperature
system environment sensors show -node <node>
storage shelf show -fields shelf-id,state
storage shelf port show

# Disk ownership
storage disk show -fields disk,owner,home-owner -state present

# Show all active jobs (reconstruct, deduplication, etc.)
job show
```

### SAN-Specific Diagnostics

```bash
# Show LUN status and mapped igroups
lun show -vserver <svm>
lun mapping show -vserver <svm>

# iSCSI session status
iscsi session show -vserver <svm>

# FC initiator connections
fcp initiator show -vserver <svm>

# NVMe subsystem and namespace mapping
vserver nvme subsystem show
vserver nvme namespace show

# NVMe host connections
vserver nvme subsystem host show

# LUN alignment (4K vs 512-byte sector alignment)
lun show -fields alignment
```

### AutoSupport and Diagnostics Upload

```bash
# Trigger an on-demand AutoSupport
system node autosupport invoke -node <node> -type all -message "performance investigation"

# Show AutoSupport configuration
system node autosupport show

# Check Active IQ status
system node autosupport history show -rows 10

# Generate a performance archive bundle for NetApp support
system node run -node <node> -command "perfstat8 -i 5 -t 60 -x -output /mroot/etc/log/perfstat"
```

---

## Performance Investigation Workflow

### Step 1: Establish Baseline
```bash
statistics show-periodic -preset basic -interval 5 -iterations 12
# Capture 60 seconds of data. Look for: CPU busy > 80%, disk busy > 70%,
# read/write latency > 2ms on AFF, > 10ms on FAS HDD
```

### Step 2: Identify Hotspot Volumes
```bash
qos statistics volume latency show -rows 20
# Sort by latency; identify top offenders
statistics show -object volume -counter read_latency,write_latency -sort-key read_latency -rows 10
```

### Step 3: Check RAID/Disk Health
```bash
storage disk show -state broken
storage aggregate show -state degraded
# Any degraded aggregate will show elevated latency due to reconstruction I/O
```

### Step 4: Check Network Saturation
```bash
statistics show -object port -instance <node>:<port> -counter recv_data,sent_data -interval 5
# Compare to port speed; > 80% utilization = network saturation
```

### Step 5: Check QoS Limits
```bash
qos statistics volume latency show
# Throttled workloads show elevated "policy" latency
qos policy-group show -fields max-throughput,used-iops
```

### Step 6: Engage AutoSupport and Active IQ
```bash
system node autosupport invoke -node * -type all -message "performance issue <ticket>"
# Active IQ Risk Advisor will analyze and flag anomalies
```
