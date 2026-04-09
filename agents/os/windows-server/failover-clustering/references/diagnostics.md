# Failover Clustering Diagnostics Reference

## Cluster Validation

`Test-Cluster` performs comprehensive validation across multiple categories. Run it before creating a cluster and periodically on running clusters.

### Validation Categories

| Category | Tests Performed |
|---|---|
| Inventory | Node inventory, driver information, firmware versions |
| Network | NIC configuration, DNS resolution, routing, binding order |
| Storage | Disk access, SCSI-3 persistent reservations, MPIO, failover |
| System Configuration | OS version consistency, hotfix level, domain membership |
| Hyper-V Configuration | Virtual switch config (if Hyper-V role installed) |
| Storage Spaces Direct | Disk eligibility, network requirements (if S2D) |

### Running Validation Safely

```powershell
# Full validation (pre-deployment -- may briefly interrupt storage I/O)
Test-Cluster -Node "Node1","Node2","Node3" -ReportName "C:\ClusterValidation\report"

# Safe validation on a running cluster (skip storage disruption)
Test-Cluster -Node "Node1","Node2" -Include "Network","System Configuration","Inventory"

# Storage-only validation (schedule during maintenance window)
Test-Cluster -Node "Node1","Node2" -Include "Storage"
```

Results are saved as an HTML report. Default location: `$env:TEMP\Validation Report <date>.htm`

### Common Validation Failures

| Failure | Resolution |
|---|---|
| NIC driver version mismatch | Update NIC drivers to the same version on all nodes |
| DNS not resolving node names | Check DNS registration, firewall rules, DNS forwarders |
| Disk not visible on all nodes | Verify SAN zoning, iSCSI initiator config, MPIO setup |
| SCSI-3 reservation failure | Storage does not support persistent reservations; update firmware or use S2D |
| OS version mismatch | Perform rolling cluster upgrade to bring nodes to the same level |
| Domain membership different | All nodes must be in the same domain or a trusted domain |
| NTP not synchronized | Configure the same NTP source on all nodes |

---

## Cluster Logging

### Generating Cluster Debug Logs

The cluster log is the primary diagnostic artifact for WSFC troubleshooting.

```powershell
# Generate cluster log on all nodes (default: C:\Windows\Cluster\Reports\)
Get-ClusterLog -Destination "C:\ClusterLogs" -TimeSpan 60   # last 60 minutes

# Generate on a specific node
Get-ClusterLog -Node "Node1" -Destination "C:\ClusterLogs" -TimeSpan 30

# Use local time format for easier correlation
Get-ClusterLog -Destination "C:\ClusterLogs" -UseLocalTime

# Set verbose cluster logging temporarily (revert after troubleshooting)
(Get-Cluster).ClusterLogLevel = 5   # 0=Off, 1=Error, 2=Warn, 3=Info, 4=Verbose, 5=Debug
```

### Cluster Event Channels

| Event Channel | Contents |
|---|---|
| `Microsoft-Windows-FailoverClustering/Operational` | Standard operational events (default enabled) |
| `Microsoft-Windows-FailoverClustering/Diagnostic` | Verbose diagnostic events (disabled by default) |
| `Microsoft-Windows-FailoverClustering-Manager/Admin` | Cluster Manager GUI events |
| `Microsoft-Windows-FailoverClustering/DiagnosticVerbose` | Extremely detailed trace data |

```powershell
# Query cluster events for errors and warnings in the last hour
$since = (Get-Date).AddHours(-1)
Get-WinEvent -LogName "Microsoft-Windows-FailoverClustering/Operational" -MaxEvents 200 |
    Where-Object { $_.TimeCreated -ge $since -and $_.Level -le 3 } |
    Select-Object TimeCreated, Id, LevelDisplayName, Message |
    Format-Table -AutoSize -Wrap

# Enable the diagnostic channel for deeper investigation
wevtutil sl Microsoft-Windows-FailoverClustering/Diagnostic /e:true /q:true
```

### Cluster Log Key Prefixes

When reading cluster logs, these prefixes indicate the subsystem generating the entry:

| Prefix | Subsystem |
|---|---|
| `[GUM]` | Global Update Manager (CLUSDB replication) |
| `[RHS]` | Resource Host Subsystem (resource health) |
| `[RCM]` | Resource Control Manager (failover decisions) |
| `[Netft]` | Network Fault Tolerant driver (heartbeat/network) |
| `[QM]` | Quarantine Manager (node quarantine events) |
| `[FM]` | Failover Manager (group/resource state changes) |
| `[NM]` | Node Manager (node membership) |
| `[CS]` | Cluster Service core |
| `[CSV]` | Cluster Shared Volume operations |

---

## Critical Event IDs

| Event ID | Source | Description | Severity |
|---|---|---|---|
| 1069 | FailoverClustering | Cluster resource failed | Error |
| 1135 | FailoverClustering | Node removed from active cluster membership | Error |
| 1146 | FailoverClustering | Cluster quorum resource lost | Critical |
| 1177 | FailoverClustering | Lost communication with cluster node | Warning |
| 1196 | FailoverClustering | Cluster IP address resource failed | Error |
| 1222 | FailoverClustering | Failed to create Kerberos principal for cluster name | Error |
| 1254 | FailoverClustering | CSV node is in redirected I/O mode | Warning |
| 1561 | FailoverClustering | S2D disk ineligible | Warning |
| 5120 | FailoverClustering | CSV is unavailable (device error) | Critical |
| 5142 | FailoverClustering | CSV blocked due to transient error | Warning |
| 5145 | FailoverClustering | CSV file system check required | Warning |

---

## Troubleshooting Workflows

### Resource Fails to Come Online

1. Identify which resources are failed:
   ```powershell
   Get-ClusterResource | Where-Object State -ne 'Online'
   ```
2. Review the cluster event log for Event ID 1069 -- note the resource name and error details
3. Generate a focused cluster log and search for `[RHS]` and the resource name:
   ```powershell
   Get-ClusterLog -TimeSpan 5 -Destination "C:\Logs"
   ```
4. Check resource-specific conditions:
   - **Generic Service**: Verify service account credentials, binary path, service dependencies
   - **IP Address**: Verify the IP is not conflicting (ping from outside the cluster), verify network role
   - **Physical Disk**: Check disk state with `Get-Disk`, verify MPIO configuration, check System event log for disk errors
   - **Network Name**: Verify DNS registration, check if the cluster name object (CNO) exists in Active Directory
5. Attempt to bring the resource online for investigation:
   ```powershell
   Start-ClusterResource -Name "Resource Name"
   ```
6. Review the application event log on the node currently owning the resource

### Unexpected Failover (Heartbeat/Network Analysis)

1. Check the system event log for Event ID 1135 (node removed) and note the timestamp
2. On the removed node, generate the cluster log around the time of failure:
   ```powershell
   Get-ClusterLog -Node "RemovedNode" -TimeSpan 10 -Destination "C:\Logs"
   ```
3. Search the cluster log for `[RCM]` and `[Netft]` entries to identify network events
4. Verify NIC statistics for errors or drops:
   ```powershell
   Get-NetAdapterStatistics -Name "Cluster NIC"
   ```
5. Check whether the heartbeat network had packet loss at the time of failure
6. Compare `SameSubnetThreshold` and `SameSubnetDelay` against observed network latency
7. Check for anti-virus software or firewall rules blocking UDP port 3343
8. Review quarantine state if the node has recently rejoined:
   ```powershell
   Get-ClusterNode | Select-Object Name, State, StatusInformation
   ```

### Split-Brain Investigation

Split-brain occurs when two partitions of the cluster each believe they are authoritative. This is a critical condition.

1. Determine which partition holds quorum -- that partition's services should remain online
2. The partition without quorum should have stopped the Cluster Service automatically
3. If both partitions are running services: **emergency** -- verify witness accessibility from both sites immediately
4. Recovery:
   - Stop the Cluster Service on the partition without quorum
   - Fix the network partition or witness failure
   - Rejoin nodes and restart the Cluster Service normally
5. Investigate root cause: network partition, witness failure, or simultaneous node failures

### CSV I/O Errors (Event 5120/5142)

1. Identify which CSVs are in redirected mode:
   ```powershell
   Get-ClusterSharedVolume | Select-Object Name, State,
       @{N='Redirected';E={$_.SharedVolumeInfo.RedirectedIOReason}}
   ```
2. Check storage path health:
   ```powershell
   Get-PhysicalDisk | Select-Object DeviceId, HealthStatus, OperationalStatus
   ```
3. Check MPIO status:
   ```powershell
   Get-MSDSMSupportedHW
   Get-MSDSMGlobalDefaultLoadBalancePolicy
   ```
4. Look for disk errors in the System event log (Disk, Ntfs, or ReFS sources)
5. Check the SMB multichannel connection for CSV redirected I/O:
   ```powershell
   Get-SmbMultichannelConnection
   ```
6. Review the CSV state info for the specific redirection reason:
   ```powershell
   Get-ClusterSharedVolume | Select-Object Name, State, StateInfo
   ```
7. Common causes: VSS snapshot in progress, BitLocker initialization, storage firmware issue, transient connectivity loss

**Redirected I/O reason codes**:
| Code | Meaning |
|---|---|
| 1 | Not blocked or redirected (direct I/O) |
| 2 | No disk connectivity |
| 4 | File system not mounted |
| 8 | In maintenance mode |
| 16 | Volume too large for direct I/O |
| 32 | BitLocker initialization in progress |
| 64 | Disk timeout |

### Node Isolation (Cannot Communicate)

1. Verify the node can ping other nodes on all cluster networks
2. Check cluster network binding:
   ```powershell
   Get-NetAdapter | Select-Object Name, Status, LinkSpeed
   Get-ClusterNetworkInterface | Select-Object Node, Name, Network, State
   ```
3. Verify Windows Firewall rules for cluster communication:
   ```powershell
   Get-NetFirewallRule | Where-Object DisplayName -like '*Cluster*' |
       Select-Object DisplayName, Enabled, Direction, Action
   ```
4. Check DNS resolution from each node:
   ```powershell
   Resolve-DnsName <nodename>
   ```
5. Verify the Cluster Service is running:
   ```powershell
   Get-Service ClusSvc | Select-Object Status, StartType
   ```
6. Review the cluster log for `[QM]` quarantine manager entries
7. If the node is quarantined, wait for the quarantine duration to expire or investigate the repeated failures that triggered quarantine

---

## Quorum Loss and Recovery

### When Quorum Is Lost

- All cluster resources immediately go offline (ungraceful stop)
- Cluster Service stops on all remaining nodes
- Event ID 1146 is logged: "The cluster quorum resource failed"

### Forced Quorum Start (Emergency)

```powershell
# Force start cluster ignoring quorum -- EMERGENCY USE ONLY
Start-ClusterNode -FixQuorum

# Legacy approach:
# net start clussvc /fixquorum
```

### Post-Recovery Steps

1. Identify why quorum was lost (network partition, witness failure, simultaneous node failures)
2. Restore missing nodes or reconfigure the witness
3. Stop the forced-start node, verify quorum configuration, restart the Cluster Service normally on all nodes
4. Validate the cluster: `Test-Cluster -Include "System Configuration","Network"`
5. Review and potentially adjust quorum thresholds and witness configuration

### Quorum Investigation Events

- Event ID 1177: "The cluster lost the connection to cluster node"
- Event ID 1146: "The cluster quorum resource failed"
- Event ID 1135: "Cluster node was removed from the active failover cluster membership"
- Event ID 1069: "Cluster resource failed" (includes quorum resource failures)

---

## Diagnostic Quick Reference

### Essential Commands

```powershell
# Cluster status snapshot
Get-Cluster | Format-List *
Get-ClusterNode | Format-Table Name, State, DrainStatus, NodeWeight, DynamicWeight
Get-ClusterGroup | Sort-Object State | Format-Table Name, State, OwnerNode
Get-ClusterResource | Where-Object State -ne 'Online' | Format-Table Name, State, ResourceType, OwnerGroup
Get-ClusterSharedVolume | Select-Object Name, State, OwnerNode

# Quorum
Get-ClusterQuorum | Format-List

# Node management
Suspend-ClusterNode -Name "Node" -Drain
Resume-ClusterNode -Name "Node" -Failback Immediate

# Logging
Get-ClusterLog -Destination "C:\Logs" -TimeSpan 30
(Get-Cluster).ClusterLogLevel = 3   # Info level

# Validation (safe on live cluster)
Test-Cluster -Node "n1","n2" -Include "Network","System Configuration"
```

### Critical File Paths

| Path | Description |
|---|---|
| `C:\Windows\Cluster\CLUSDB` | Cluster database binary hive |
| `C:\Windows\Cluster\Reports\` | Cluster log output directory |
| `C:\ClusterStorage\` | CSV namespace root |
| `%SystemRoot%\Cluster\clus*.log` | Cluster service debug logs |

### Cluster Ports

| Port | Protocol | Purpose |
|---|---|---|
| 3343 | UDP/TCP | Cluster heartbeat and communication |
| 445 | TCP | SMB (CSV redirected I/O, file share witness) |
| 135 | TCP | RPC endpoint mapper |
| 49152-65535 | TCP | RPC dynamic port range |
