# VMware vSphere Diagnostics Reference

Troubleshooting and diagnostic reference for VMware vSphere. Covers esxtop performance analysis, vm-support bundles, PSOD analysis, vMotion failures, storage latency, and HA failover debugging.

---

## esxtop Performance Analysis

`esxtop` is the primary real-time performance tool for ESXi. Run from ESXi Shell or SSH.

### CPU Panel (press `c`)

| Metric | Meaning | Threshold |
|---|---|---|
| %USED | CPU time consumed by the world | Informational |
| %RDY | Time vCPU was ready to run but waiting for a physical CPU | >5% per vCPU = contention |
| %CSTP | Co-stop time (SMP VMs waiting for sibling vCPUs to sync) | >3% = over-allocated vCPUs |
| %MLMTD | CPU limited by resource pool limit or shares | >0% = check resource pool config |
| %SWPWT | Time waiting for swapped memory pages | >0% = severe memory pressure |

**Diagnosis workflow:**
1. High %RDY: host is CPU-overcommitted. Reduce VM vCPU count or migrate VMs to less loaded hosts.
2. High %CSTP: VM has too many vCPUs relative to its workload. Reduce vCPU count.
3. High %MLMTD: resource pool limit is capping VM. Increase limit or adjust shares.

### Memory Panel (press `m`)

| Metric | Meaning | Threshold |
|---|---|---|
| MCTLSZ | Balloon driver target (MB reclaimed from guest) | >0 = memory pressure |
| SWCUR | Currently swapped to .vswp (MB) | >0 = serious memory pressure |
| CACHEUSD | Host cache (SSD swap cache) in use | Informational |
| N%L | NUMA local memory percentage | <80% = NUMA misalignment |
| LLSWPR/s | Low-level swap reads per second | >0 = critical, causes latency |

**Diagnosis workflow:**
1. SWCUR > 0: host is in Hard or Low memory state. Add RAM, reduce VM memory, or migrate VMs.
2. MCTLSZ > 0 but SWCUR = 0: ballooning is working as designed; not necessarily a problem.
3. N%L < 80%: VM spans NUMA nodes. Resize to fit within one node.

### Storage Panel (press `d`)

| Metric | Meaning | Threshold |
|---|---|---|
| DAVG/cmd | Device (array) latency in milliseconds | >20 ms (SSD) or >50 ms (HDD) |
| KAVG/cmd | VMkernel queue latency in milliseconds | >2 ms |
| GAVG/cmd | Guest-observed latency (DAVG + KAVG) | >25 ms (SSD) |
| CMDS/s | Commands per second (IOPS) | Informational |
| APTS/s | ATS (Atomic Test-and-Set) operations per second | High = VMFS locking pressure |

**Diagnosis workflow:**
1. High DAVG: problem is at the storage array or SAN fabric. Check array performance, path selection, and queue depth.
2. High KAVG with low DAVG: VMkernel queue congestion. Check for too many VMs on the same LUN or path selection issues.
3. High GAVG: sum of DAVG + KAVG. Guest applications see this total latency.

### Network Panel (press `n`)

| Metric | Meaning | Threshold |
|---|---|---|
| MbRX/s | Megabits received per second | Informational |
| MbTX/s | Megabits transmitted per second | Informational |
| DRPTX | Dropped transmit packets | >0 = NIC saturation or misconfiguration |
| DRPRX | Dropped receive packets | >0 = buffer overrun |
| %USED | Percentage of NIC bandwidth used | >70% sustained = consider upgrade |

### Batch Mode (CSV export)

```bash
# Capture 60 iterations at 5-second intervals to CSV
esxtop -b -n 60 -d 5 > /tmp/esxtop-$(date +%Y%m%d).csv

# Download CSV and open in Excel or Perfmon for analysis
```

---

## vm-support Diagnostic Bundles

### Generate from CLI
```bash
# Generate bundle (creates .tgz in /tmp/)
vm-support -w /tmp/

# Generate with performance snapshots
vm-support -p -w /tmp/
```

### Generate from vSphere Client
Host > Actions > Export System Logs > Select host > Choose logs > Download

### Bundle Contents
- VMkernel logs (`vmkernel.log`)
- Host daemon logs (`hostd.log`, `vpxa.log`)
- ESXi configuration (`esxcfg-*` output)
- Network configuration (vswitch, vmk, firewall)
- Storage configuration (devices, paths, datastores)
- VM event logs and configuration
- Core dumps (if PSOD occurred)

### vCenter Support Bundle
Generate from VAMI: `https://<vcsa>:5480` > Support > Create Support Bundle. Includes vpxd logs, PostgreSQL logs, and vCenter service logs.

---

## Purple Screen of Death (PSOD)

A PSOD is ESXi's kernel panic. The host halts and displays a diagnostic screen.

### Common Causes
- Memory ECC errors (uncorrectable)
- NIC or HBA driver bugs
- Firmware incompatibility
- Resource exhaustion (VMkernel heap overflow)
- Storage errors causing VMkernel assertions

### Response Procedure
1. Photograph or record the PSOD screen (or retrieve core dump after reboot)
2. Check hardware logs (iDRAC, iLO, IPMI) for concurrent hardware faults
3. Reboot the host (VMs restart via HA on other hosts)
4. Collect vm-support bundle immediately after reboot
5. Core dumps: `/var/core/` on ESXi, or configured network core dump server
6. Review `/var/log/vmkernel.log` and `/var/log/vmkwarning.log` for errors before the PSOD
7. Update drivers, firmware, and ESXi to latest supported versions from VMware HCL
8. Open VMware Support case with PSOD output, core dump, and vm-support bundle

### Prevention
- Keep ESXi, drivers, and firmware at HCL-validated versions
- Monitor CIM hardware health for early warnings
- Enable network core dump collection for headless hosts
- Deploy HA so VMs auto-restart on surviving hosts

---

## vMotion Failure Troubleshooting

### Common Failure Causes

| Symptom | Likely Cause | Fix |
|---|---|---|
| "CPU incompatible" | Different CPU features between hosts | Enable EVC at cluster level |
| "Network not found" | Port group name mismatch on destination | Create matching port group on destination |
| "No shared datastore" | Destination host cannot see the datastore | Rescan storage on destination; verify LUN masking |
| "Timeout" | vMotion network too slow for dirty page rate | Upgrade vMotion NIC to 10+ GbE; add parallel vMotion NICs |
| "Cannot complete" | VM has device connected to local resource | Disconnect CD/ISO on local datastore; remove serial ports |
| "Insufficient resources" | Destination host lacks CPU/memory headroom | Check DRS, admission control, resource pool limits |

### Diagnostic Steps
1. Check vMotion VMkernel port on both hosts: `esxcli network ip interface list`
2. Ping between vMotion vmk IPs: `esxcli network diag ping --host=<dest-vmk-ip>`
3. Verify shared storage: `esxcli storage filesystem list` on both hosts
4. Check CPU compatibility: compare EVC baseline and CPU features
5. Review logs: `/var/log/hostd.log` (source and destination), `/var/log/vpxd.log` (vCenter)
6. Test with a small VM first to isolate network vs resource issues

---

## Storage Latency Troubleshooting

### Step-by-Step Diagnosis

1. **Identify the VM**: use vCenter Performance Charts to find VMs with high disk latency
2. **Check esxtop**: run `esxtop`, press `d` for disk panel
   - DAVG > threshold: array-side problem
   - KAVG > 2 ms: VMkernel queue problem
3. **Check snapshot chains**: snapshots cause I/O amplification
   ```bash
   # On ESXi: find delta disks for a VM
   ls -la /vmfs/volumes/datastore1/vmname/*delta*
   ```
4. **Check datastore utilization**: >80% causes performance degradation for thin provisioning
   ```powershell
   Get-Datastore | Where-Object {($_.CapacityGB - $_.FreeSpaceGB) / $_.CapacityGB -gt 0.8}
   ```
5. **Check multipath policy**: Round Robin distributes I/O better than Fixed
   ```bash
   esxcli storage nmp device list
   ```
6. **Check SCSI errors in VMkernel log**:
   ```bash
   grep -E "H:0x[^0]|D:0x[^0]" /var/log/vmkernel.log | tail -20
   ```
7. **Check array-side**: consult storage admin for array utilization, thin reclamation, rebuild activity

---

## HA Failover Troubleshooting

### Diagnosis Steps

1. **Verify HA is enabled and healthy**:
   ```powershell
   Get-Cluster | Select-Object Name, HAEnabled, HAAdmissionControlEnabled
   ```
2. **Check host connection state**: disconnected or not-responding hosts trigger HA
3. **Review FDM logs on primary host**: `/var/log/fdm.log`
4. **Check admission control**: if the cluster lacks capacity, HA cannot restart VMs
5. **Verify datastore heartbeats**: HA uses datastore heartbeating to distinguish network partition from host failure
6. **Check VM restart priority**: disabled or low-priority VMs may not restart in resource-constrained scenarios
7. **Check for isolation response**: if a host is network-isolated, its VMs may be powered off and restarted elsewhere

### Common HA Issues

| Issue | Cause | Resolution |
|---|---|---|
| VMs not restarted | Admission control insufficient capacity | Add hosts or reduce reservations |
| HA reports "Insufficient resources" | Too many VM reservations | Reduce per-VM memory/CPU reservations |
| Host shows "Disconnected" | Management network failure | Check vmk0, physical NIC, switch port |
| Split-brain (VMs on two hosts) | Network partition without proper fencing | Configure datastore heartbeats; fix network |
| HA reconfiguration errors | FDM cannot communicate with vCenter | Restart vpxa on affected host; check DNS |

---

## Log Locations Quick Reference

| Component | Path | Key Events |
|---|---|---|
| VMkernel | `/var/log/vmkernel.log` | Storage errors, network events, driver messages |
| hostd | `/var/log/hostd.log` | VM operations, API calls, authentication |
| vpxa | `/var/log/vpxa.log` | vCenter agent communication |
| FDM (HA) | `/var/log/fdm.log` | HA heartbeating, failover decisions |
| Shell | `/var/log/shell.log` | ESXi Shell and SSH command history |
| Auth | `/var/log/auth.log` | Login attempts, lockouts |
| vCenter (vpxd) | `/var/log/vmware/vpxd/vpxd.log` | vCenter core operations |
| vCenter DB | `/var/log/vmware/vpostgres/` | Database operations |

### Log Searching

```bash
# Search VMkernel for storage errors
grep -i "scsi\|nmp\|device\|path" /var/log/vmkernel.log | tail -50

# Search for vMotion events
grep -i "vmotion\|migrate" /var/log/hostd.log | tail -30

# Search for HA events
grep -i "fault\|failover\|restart\|isolation" /var/log/fdm.log | tail -30

# Search for authentication failures
grep -i "fail\|denied\|invalid" /var/log/auth.log | tail -20
```

---

## Performance Charts Reference

### Key vCenter Counters

| Object | Counter | Meaning |
|---|---|---|
| VM | `cpu.ready.summation` | CPU ready time in ms |
| VM | `mem.swapped.average` | Swapped memory in KB |
| VM | `disk.maxTotalLatency.latest` | Highest disk latency in ms |
| Host | `cpu.usage.average` | Overall CPU utilization % |
| Host | `mem.usage.average` | Overall memory utilization % |
| Datastore | `disk.numberReadAveraged.average` | Read IOPS |
| Datastore | `disk.numberWriteAveraged.average` | Write IOPS |

### Statistics Collection Levels

| Level | Data Collected | Use Case |
|---|---|---|
| 1 (default) | Averages only | General monitoring |
| 2 | Averages + summations | Troubleshooting |
| 3 | Level 2 + per-device | Detailed analysis |
| 4 | All counters including min/max | Short-term deep analysis |

Increase collection level temporarily (1-2 days) for detailed troubleshooting. Level 4 significantly increases vCenter database size.
