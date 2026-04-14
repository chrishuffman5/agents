# NetApp ONTAP Diagnostics and Troubleshooting

## CLI Privilege Levels

- `admin` — normal operations
- `advanced` — extended diagnostics (`set -privilege advanced`)
- `diagnostic` — deepest internals; use only under NetApp support guidance

## Performance Counters

### System-Level
```
statistics show-periodic -preset basic -interval 5
statistics show-periodic -object node -counter cpu_busy,read_ops,write_ops -interval 5
statistics show -node <node_name>
```

### Volume-Level
```
statistics show -object volume -instance <vol> -counter read_ops,write_ops,read_data,write_data
statistics show -object volume -instance <vol> -counter read_latency,write_latency,other_latency
statistics show -object volume -counter read_latency -sort-key read_latency -rows 20
qos statistics volume latency show
qos statistics volume performance show
```

### Node-Level
```
statistics show -object system -counter cpu_busy -node <node>
statistics show -object nfsv3 -counter read_ops,write_ops,lookup_ops -node <node>
statistics show -object cifs -counter read_ops,write_ops -node <node>
statistics show -object iscsi_lif -counter iscsi_read_ops,iscsi_write_ops
statistics show -object aggregate -instance <aggr> -counter total_read_ops,total_write_ops,read_latency,write_latency
```

### Network Path Testing
```
network test-path -source-node <n1> -destination-node <n2> -session-type default
network test-path -source-node <n1> -destination-node <n2> -session-type AsyncMirrorRemote
network test-path -source-node <n1> -destination-node <n2> -session-type SyncMirrorRemote
```

## Latency Analysis

### Identifying High-Latency Volumes
```
set -privilege advanced
statistics top client show -display latency -rows 20
statistics show -object volume -instance <vol> -counter read_latency,write_latency,other_latency,avg_latency
```

### Disk-Level Latency
```
storage disk show -fields disk,type,avg-latency,model
statistics show -object disk -instance <disk> -counter disk_busy,io_pending,read_latency,write_latency
storage aggregate show-status -aggregate <aggr>
```

### WAFL Internal Delays
```
statistics show -object wafl -counter cp_count,cp_from_timer,cp_from_nvlog_full -node <node>
# High cp_from_nvlog_full = NVRAM filling faster than CPs can drain = workload exceeds write throughput
statistics show -object wafl -counter read_hits,read_misses,write_hits -node <node>
```

## Disk Failures and RAID

### Identifying Failed Disks
```
storage disk show -fields disk,type,state,node,aggregate,position
storage disk show -state broken
storage disk show -state failed
storage disk error show
storage disk show -fields disk,shelf,bay,serial-number,model
```

### RAID Status and Reconstruction
```
storage aggregate show -state degraded
storage aggregate show -fields raid-status,state,size
storage aggregate show-status -aggregate <aggr>
storage aggregate show -fields reconstruct-percent,reconstruct-eta
```

### Disk Replacement Workflow
1. `storage disk show -state broken` — confirm failure
2. `storage aggregate show -state degraded` — check aggregate
3. Physically replace failed disk; ONTAP auto-reconstructs from spare
4. `storage aggregate show -fields reconstruct-percent` — monitor progress
5. Verify aggregate returns to optimal state

### Spare Disks
```
storage disk assign -disk <disk_id> -owner <node>
storage aggregate show-spare-disks -original-owner <node>
```

## SnapMirror Lag Troubleshooting

### Status and Lag
```
snapmirror show -fields source-path,destination-path,relationship-status,mirror-state,lag-time
snapmirror show -destination-path <svm>:<vol> -fields lag-time,last-transfer-duration,last-transfer-size
snapmirror show -relationship-status transferring,failed,error
```

### Lag Causes
1. Transfer in progress (large baseline or incremental)
2. Scheduled transfer missed (throttle, outage, source/destination busy)
3. Clock skew (check NTP: `cluster time-service ntp status show`)
4. Insufficient network bandwidth
5. Cascaded relationships out of order

### Transfer Failures
```
snapmirror show -fields relationship-status,unhealthy-reason
event log show -severity ERROR -message-name scsimgr*,repl.*,snapmirror.*
snapmirror abort -destination-path <svm>:<vol>
snapmirror update -destination-path <svm>:<vol>
snapmirror resync -destination-path <svm>:<vol>
```

### Optimizing Throughput
```
snapmirror modify -destination-path <svm>:<vol> -throttle 0   # unlimited
network interface show -role intercluster
ping -lif <intercluster_lif> -destination <remote_ip>
```

## Network Troubleshooting

### Interface Status
```
network interface show -vserver <svm>
network interface show -is-home false   # LIFs not on home node
network interface revert -vserver <svm> -lif <lif>
statistics show -object port -instance <node>:<port> -counter recv_errors,sent_errors,link_down_count
network port show -fields node,port,speed,duplex,mtu,link
```

### MTU Verification
```
network port show -fields mtu
network ping -lif <lif> -destination <host_ip> -size 8972   # tests 9000 MTU
network port vlan show
network port ifgrp show
```

### DNS
```
set -privilege advanced
vserver services name-service dns check -vserver <svm>
vserver services name-service dns show
```

## Key Diagnostic Commands Reference

### Storage and Space
```
volume show -fields size,available,used,percent-used,snapshot-reserve-percent
volume show-footprint -vserver <svm> -volume <vol>
storage aggregate show -fields size,used,available,percent-used
volume efficiency show -vserver <svm> -volume <vol> -fields savings-percent,total-saved
```

### Events and Errors
```
event log show -severity error -time-range 1h
system health alert show
storage disk error show
event log show -message-name "raid.*" -severity ERROR
system node autosupport history show
```

### Cluster Health
```
cluster show
system node show
storage failover show -fields takeover-state,can-takeover,giveback-state
system environment sensors show -node <node>
storage shelf show -fields shelf-id,state
```

### SAN Diagnostics
```
lun show -vserver <svm>
lun mapping show -vserver <svm>
iscsi session show -vserver <svm>
fcp initiator show -vserver <svm>
vserver nvme subsystem show
vserver nvme namespace show
```

### AutoSupport
```
system node autosupport invoke -node <node> -type all -message "performance investigation"
system node autosupport show
```

## Performance Investigation Workflow

1. **Baseline**: `statistics show-periodic -preset basic -interval 5 -iterations 12` — look for CPU > 80%, disk busy > 70%, latency > 2ms AFF / > 10ms FAS
2. **Hotspot volumes**: `qos statistics volume latency show -rows 20`
3. **RAID/disk health**: `storage disk show -state broken; storage aggregate show -state degraded`
4. **Network saturation**: `statistics show -object port -instance <node>:<port> -counter recv_data,sent_data` — compare to port speed, > 80% = saturated
5. **QoS limits**: `qos statistics volume latency show` — check "policy" latency for throttling
6. **AutoSupport**: `system node autosupport invoke -node * -type all -message "performance issue"`
