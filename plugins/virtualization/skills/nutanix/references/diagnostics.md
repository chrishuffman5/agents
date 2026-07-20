# Nutanix AHV Diagnostics Reference

## acli Diagnostic Commands

### VM Status

```bash
# List all VMs with status
acli vm.list

# Detailed VM info (CPU, memory, disks, NICs, host assignment)
acli vm.get <vm_name>

# Host inventory
acli host.list
acli host.get <host_ip>
```

### Network Diagnostics

```bash
# List all networks and their VLAN assignments
acli net.list
acli net.get <network_name>

# Check OVS bridge status (from AHV host)
ovs-vsctl show
ovs-ofctl dump-flows br0
```

## ncli Diagnostic Commands

### Cluster Health

```bash
# Cluster overview
ncli cluster info
ncli cluster get-storage-info
ncli cluster health-summary-get

# Host status
ncli host list
ncli host get id=<host_id>

# Storage container status
ncli container list
ncli container get name=<name>

# Disk health
ncli disk list
ncli disk get id=<disk_id>

# Active alerts
ncli alert list
ncli alert resolve id=<alert_id>
```

### Protection Domain Status

```bash
# List protection domains and schedules
ncli protection-domain list
ncli protection-domain get name=<pd_name>

# List snapshots for a protection domain
ncli snapshot list protection-domain-name=<pd_name>

# Remote site connectivity
ncli remote-site list
```

## NCC Health Checks

NCC (Nutanix Cluster Check) is the primary diagnostic framework with hundreds of checks across hardware, software, and configuration.

```bash
# Run all health checks
ncc health_checks run_all

# Save output to file for review
ncc health_checks run_all --log_file=/home/nutanix/ncc_output.log

# Targeted checks
ncc health_checks system_checks cvm_services_status_check run
ncc health_checks hardware_checks disk_checks run
ncc health_checks network_checks host_cvm_connectivity_check run
ncc health_checks data_protection_checks protection_domain_check run

# View NCC results via ncli
ncli health-check list
```

## CVM Service Management

```bash
# Check all services on local CVM
genesis status

# Check services across all CVMs
allssh "genesis status"

# Restart a specific service
genesis restart stargate
genesis restart prism

# Run command across all CVMs
allssh "uptime"
allssh "df -h"
allssh "free -m"

# SSH to CVM from AHV host (always .254 on internal bridge)
ssh nutanix@192.168.5.254
```

## Log Locations (on CVM)

| Log File | Contents |
|----------|----------|
| `/home/nutanix/data/logs/stargate.INFO` | Data I/O engine -- reads, writes, compression, dedup |
| `/home/nutanix/data/logs/cassandra.INFO` | Metadata store operations |
| `/home/nutanix/data/logs/curator.INFO` | Background tasks -- rebalancing, EC, tiering |
| `/home/nutanix/data/logs/acropolis.out` | VM lifecycle operations |
| `/home/nutanix/data/logs/genesis.out` | Process manager -- service start/stop, upgrades |
| `/home/nutanix/data/logs/prism_gateway.log` | Prism web UI and REST API operations |
| `/home/nutanix/data/logs/zookeeper.out` | Cluster coordination |
| `/home/nutanix/data/logs/hades.out` | Disk health monitoring |

## Common Issues and Resolutions

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| CVM service not running | Service crash or upgrade issue | `genesis restart <service>` on affected CVM; check service log |
| High storage latency | Data locality lost or SSD tier full | Check locality percentage in Prism; verify SSD capacity |
| VM migration failure | Insufficient memory on target host | Check host memory availability; free memory or add nodes |
| Disk marked offline | Drive failure or firmware issue | Check `ncli disk list`; run `ncc hardware_checks disk_checks run` |
| Protection domain replication failing | Remote site unreachable or bandwidth saturated | Verify remote site connectivity; check network bandwidth |
| NCC warnings before upgrade | Pre-existing hardware/config issues | Resolve all NCC warnings before proceeding with upgrade |
| Prism UI inaccessible | Prism service down on cluster leader | `genesis restart prism`; check `/home/nutanix/data/logs/prism_gateway.log` |
| High CVM CPU usage | Stargate under heavy I/O or Curator running | Check Stargate logs; verify if Curator background tasks are active |
| Cluster cannot tolerate failure | Degraded disk or node | Check RF status; replace failed hardware; verify rebuild completion |
| Metro Availability split-brain | Witness unreachable | Verify witness VM health; check network between sites |

## Performance Monitoring

```bash
# Stargate I/O stats (HTTP interface)
curl http://localhost:2009/h/traces

# Check data locality
ncli cluster get-storage-info

# CVM resource usage
top -b -n1
iostat -x 1 5
free -m

# Network throughput between CVMs
iperf3 -c <remote_cvm_ip> -t 10
```

## Support Bundle Collection

```bash
# Collect NCC log bundle for Nutanix Support
ncc log_collector run_all

# Output saved to /home/nutanix/data/log_collector/
# Upload to Nutanix Support portal for case analysis
```
