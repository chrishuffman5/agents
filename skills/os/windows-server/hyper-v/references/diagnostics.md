# Hyper-V Diagnostics Reference

## VM Health Monitoring

### Core Health Cmdlets

```powershell
# All VMs with basic state
Get-VM | Select-Object Name, State, Status, CPUUsage, MemoryAssigned, Uptime, Version, Generation

# Integration service health
Get-VMIntegrationService -VMName "VM1" |
    Select-Object Name, Enabled, PrimaryStatusDescription, SecondaryStatusDescription

# Replication health
Get-VMReplication |
    Select-Object VMName, State, Health, LastReplicationTime, ReplicationFrequency, ReplicationMode

# VM heartbeat (quick liveness check)
(Get-VMIntegrationService -VMName "VM1" -Name "Heartbeat").PrimaryStatusDescription
# Returns: OK, No Contact, Lost Communication
```

### Hyper-V Event Logs

| Log | Key Events |
|---|---|
| `Microsoft-Windows-Hyper-V-VMMS-Admin` | VM lifecycle events, errors, configuration changes |
| `Microsoft-Windows-Hyper-V-VMMS-Operational` | VM start/stop/pause operations |
| `Microsoft-Windows-Hyper-V-Worker-Admin` | VM worker process events (per VM) |
| `Microsoft-Windows-Hyper-V-Hypervisor-Admin` | Hypervisor-level events |
| `Microsoft-Windows-Hyper-V-Migration-Admin` | Live migration events and failures |
| `Microsoft-Windows-Hyper-V-VID-Admin` | Virtual Infrastructure Driver events |
| `Microsoft-Windows-Hyper-V-SynthStor-Admin` | Synthetic storage events |
| `Microsoft-Windows-Hyper-V-SynthNic-Admin` | Synthetic NIC events |

```powershell
# Query admin event log for errors in last 24 hours
Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-VMMS-Admin" -MaxEvents 100 |
    Where-Object { $_.LevelDisplayName -in "Error","Warning" -and
                   $_.TimeCreated -gt (Get-Date).AddHours(-24) } |
    Select-Object TimeCreated, LevelDisplayName, Id, Message |
    Format-Table -AutoSize -Wrap
```

---

## Performance Diagnostics

### Key Performance Counters

| Category | Counter | Description |
|---|---|---|
| `Hyper-V Hypervisor Logical Processor` | `% Total Run Time` | Total CPU per logical processor |
| `Hyper-V Hypervisor Logical Processor` | `% Hypervisor Run Time` | CPU time in hypervisor (overhead) |
| `Hyper-V Hypervisor Logical Processor` | `% Guest Run Time` | CPU time in VMs |
| `Hyper-V Hypervisor Virtual Processor` | `% Total Run Time` | Per-VM vCPU usage |
| `Hyper-V Dynamic Memory VM` | `Current Pressure` | Memory pressure (>100 = shortage) |
| `Hyper-V Dynamic Memory VM` | `Physical Memory` | Currently assigned physical memory |
| `Hyper-V Virtual Storage Device` | `Read Bytes/sec` | VHDX read throughput |
| `Hyper-V Virtual Storage Device` | `Write Bytes/sec` | VHDX write throughput |
| `Hyper-V Virtual Storage Device` | `Average Read Latency` | Per-request read latency (ms) |
| `Hyper-V Virtual Storage Device` | `Average Write Latency` | Per-request write latency (ms) |
| `Hyper-V Virtual Network Adapter` | `Bytes Received/sec` | VM NIC receive throughput |
| `Hyper-V Virtual Network Adapter` | `Bytes Sent/sec` | VM NIC send throughput |
| `Hyper-V Virtual Switch` | `Dropped Packets Incoming/sec` | Packets dropped inbound |
| `Hyper-V Virtual Switch` | `Dropped Packets Outgoing/sec` | Packets dropped outbound |

### CPU Diagnostics

Normal thresholds:
- `% Hypervisor Run Time` > 10% per logical processor: Consider host overloading or excessive VMEXIT rate
- `% Guest Run Time` + `% Hypervisor Run Time` > 90% per LP consistently: Host is CPU saturated
- VP dispatch latency > 1 ms: Scheduler contention

Causes of high hypervisor overhead:
- Deep emulation (Gen1 VMs with many emulated device accesses)
- Unenlightened guest OSes (older Linux without LIS)
- Excessive timer interrupts from guest
- Nested virtualization overhead

### Memory Diagnostics

```powershell
# Dynamic Memory pressure per VM
Get-Counter -Counter "\Hyper-V Dynamic Memory VM(*)\Current Pressure" |
    Select-Object -ExpandProperty CounterSamples |
    Where-Object { $_.InstanceName -ne "_total" } |
    Sort-Object CookedValue -Descending |
    Select-Object InstanceName, @{n="Pressure%";e={[math]::Round($_.CookedValue,1)}}
```

Memory pressure interpretation:
| Pressure % | Meaning | Action |
|---|---|---|
| 0-80 | VM has excess memory (DM may reclaim) | Normal |
| 80-100 | All assigned RAM in use | Normal, monitor |
| 100-150 | VM needs more RAM; DM attempting to add | Monitor; may need tuning |
| >150 | Severe pressure; likely paging to disk | Increase min/max RAM or add host RAM |

### Disk I/O Diagnostics

```powershell
# VHD/VHDX file health and metadata
Get-VHD -Path "D:\VMs\VM1\OSDisk.vhdx" |
    Select-Object Path, VhdType, FileSize, Size, FragmentationPercentage, Alignment, Attached
```

Storage latency targets:
- VHDX on SSD/NVMe: < 1 ms average read/write latency
- VHDX on SAS HDD RAID: < 10 ms
- Latency > 20 ms consistently: Storage bottleneck -- investigate underlying storage

### Network Diagnostics

```powershell
# Virtual switch packet drops
Get-Counter -Counter "\Hyper-V Virtual Switch(*)\Dropped Packets Outgoing/sec",
                     "\Hyper-V Virtual Switch(*)\Dropped Packets Incoming/sec" |
    Select-Object -ExpandProperty CounterSamples |
    Where-Object { $_.CookedValue -gt 0 }
```

Packet drops indicate bandwidth saturation, vSwitch misconfiguration, or QoS policy enforcement.

---

## Troubleshooting Workflows

### VM Won't Start

**Error: "The virtual machine could not be started because the hypervisor is not running"**
- Enable virtualization in BIOS (Intel VT-x / AMD-V)
- Verify: `bcdedit /enum | Select-String "hypervisorlaunchtype"`
- Fix: `bcdedit /set hypervisorlaunchtype auto` then reboot

**Error: "Not enough memory to start the VM"**
- Check host available memory vs VM Startup RAM
- Enable Dynamic Memory or reduce Startup RAM
- Smart Paging can bridge temporary shortage but is very slow

**Error: "Access denied"**
- VM Worker Process runs as `NT VIRTUAL MACHINE\<GUID>`
- Check NTFS permissions on the VHDX path and VM configuration directory
- Ensure the Hyper-V Administrators group has access

**Error: "The configuration of the virtual machine is corrupt"**
- Restore .vmcx from backup
- Or rebuild the VM configuration and reattach the VHDX

**General checklist**:
```powershell
# Verify Hyper-V services
Get-Service -Name vmms, hvhost, vmcompute | Select-Object Name, Status, StartType

# Check hypervisor launch type
bcdedit /enum | Select-String "hypervisorlaunchtype"
```

### Live Migration Failures

| Error | Cause | Resolution |
|---|---|---|
| "Migration failed at source" | Authentication failure | Verify Kerberos SPN or CredSSP config |
| "Incompatible processor" | CPU feature mismatch | Enable Processor Compatibility Mode |
| "Insufficient resources" | Not enough RAM/CPU on target | Free resources on destination host |
| "Logon failure" | CredSSP credential issue | Re-delegate credentials; check WinRM |
| Storage migration fails | VHDX path not accessible | Verify SMB share access; check firewall |
| Migration extremely slow | Wrong NIC used | Configure migration network binding |

```powershell
# Pre-flight migration test
Test-VMMigration -VMName "VM1" -DestinationHost "HV-HOST02"

# Check migration network configuration
Get-VMMigrationNetwork -ComputerName "HV-HOST01"
```

### Slow VM Performance

**NUMA misalignment**:
```powershell
# Detect VMs spanning multiple NUMA nodes
Get-VM | ForEach-Object {
    $vm = $_
    $numaNodes = Get-VMNumaNodeStatus -VM $vm
    if ($numaNodes.Count -gt 1) {
        Write-Warning "VM '$($vm.Name)' spans $($numaNodes.Count) NUMA nodes"
    }
}
```

NUMA misalignment causes higher memory latency for ~50% of accesses (cross-node) and scheduler overhead as vCPUs migrate between nodes.

Remediation:
1. Reduce vCPU count to fit within one NUMA node
2. Enable NUMA spanning only if the VM must exceed single-node capacity
3. Set explicit NUMA topology: `Set-VMProcessor -VMName "VM1" -MaximumCountPerNumaNode 16`

**High vCPU overcommit**: Check the vCPU-to-pCore ratio. Ratios above 4:1 cause scheduling contention.

**Storage bottleneck**: Check VHDX latency counters. If average latency > 20 ms, investigate the underlying storage (IOPS capacity, queue depth, fragmentation).

**Dynamic Memory contention**: Check memory pressure. If > 150%, the VM is paging to disk. Increase Minimum/Maximum RAM or add host memory.

### Replication Lag and RPO Violations

```powershell
# Check replication lag
Get-VMReplication | ForEach-Object {
    $lag = (Get-Date) - $_.LastReplicationTime
    [PSCustomObject]@{
        VMName     = $_.VMName
        State      = $_.State
        Health     = $_.Health
        LagMinutes = [math]::Round($lag.TotalMinutes, 1)
        RPO_Sec    = $_.ReplicationFrequency
    }
} | Sort-Object LagMinutes -Descending

# Extended statistics
Measure-VMReplication -VMName "VM1"
```

RPO violation causes:
- **WAN link saturation**: Increase bandwidth or increase the replication interval
- **High change rate on VM**: Increase replication frequency or bandwidth
- **Temporary network outage**: Replication catches up automatically if within the recovery window
- **Replica host disk I/O bottleneck**: Check disk latency on the replica server

### Integration Services Issues

```powershell
# Check IS status for all VMs
Get-VM | ForEach-Object {
    $vm = $_
    $services = Get-VMIntegrationService -VMName $vm.Name
    $issues = $services | Where-Object { -not $_.Enabled -or $_.PrimaryStatusDescription -notin 'OK','No Contact' }
    if ($issues) {
        [PSCustomObject]@{
            VM = $vm.Name
            Issues = ($issues | ForEach-Object { "$($_.Name): $($_.PrimaryStatusDescription)" }) -join '; '
        }
    }
} | Format-Table -AutoSize -Wrap
```

Common IS issues:
- **"Protocol version mismatch"**: Update Integration Services via Windows Update inside the guest
- **Heartbeat "Lost Communication"**: Guest OS is hung, overloaded, or IS drivers are not loaded
- **Time Sync disabled**: May be intentional for domain-joined VMs (domain time sync preferred)

---

## Hyper-V Service Reference

| Service | Display Name | Purpose |
|---|---|---|
| vmms | Hyper-V Virtual Machine Management | Core VM management service |
| hvhost | HV Host Service | Host compute service |
| vmcompute | Hyper-V Host Compute Service | Container and VM lifecycle |

```powershell
Get-Service -Name vmms, hvhost, vmcompute | Select-Object Name, Status, StartType
```

---

## Diagnostic Quick Reference

### Essential Commands

```powershell
# VM overview
Get-VM | Select-Object Name, State, CPUUsage, MemoryAssigned, Uptime | Format-Table -AutoSize

# Host info
Get-VMHost | Select-Object ComputerName, LogicalProcessorCount, MemoryCapacity,
    VirtualMachineMigrationEnabled, NumaSpanningEnabled

# VHDX health
Get-VM | Get-VMHardDiskDrive | ForEach-Object {
    if ($_.Path) { Get-VHD -Path $_.Path -ErrorAction SilentlyContinue }
} | Select-Object Path, VhdType, FileSize, Size, FragmentationPercentage

# Replication status
Get-VMReplication | Format-Table VMName, State, Health, LastReplicationTime -AutoSize

# Checkpoint inventory
Get-VM | Get-VMSnapshot -ErrorAction SilentlyContinue |
    Select-Object VMName, Name, CreationTime, SnapshotType | Format-Table -AutoSize

# Integration services
Get-VM | ForEach-Object {
    [PSCustomObject]@{
        VM = $_.Name; ISVersion = $_.IntegrationServicesVersion
        Heartbeat = (Get-VMIntegrationService -VMName $_.Name -Name "Heartbeat" -ErrorAction SilentlyContinue).PrimaryStatusDescription
    }
} | Format-Table -AutoSize
```
