# Proxmox VE Diagnostics Reference

Troubleshooting and diagnostic reference for Proxmox VE. Covers web UI monitoring, CLI diagnostics, cluster health, Ceph status, and log locations.

---

## Web UI Monitoring

The Proxmox web UI (port 8006) provides real-time monitoring:

- **Node Summary:** CPU, RAM, uptime, disk I/O, network I/O
- **VM/CT List:** Status, CPU %, RAM %, disk I/O per guest
- **Ceph Dashboard:** OSD status, PG health, I/O throughput, capacity
- **Task Log:** All operations with timestamps, results, and duration
- **Syslog Viewer:** Per-node journal viewer in web UI (Node > Syslog)

---

## VM Diagnostics (qm)

```bash
# List all VMs with status
qm list

# VM status and configuration
qm status <vmid>
qm config <vmid>

# Show QEMU launch command (useful for debugging)
qm showcmd <vmid>

# Query guest agent (requires qemu-guest-agent in guest)
qm agent <vmid> ping
qm agent <vmid> network-get-interfaces    # Get guest IP addresses
qm agent <vmid> info                      # Guest agent version

# Enter QEMU monitor (HMP) for low-level diagnostics
qm monitor <vmid>
# Useful monitor commands:
#   info block         -- disk devices and their status
#   info network       -- NIC details
#   info status        -- VM running state
#   info cpus          -- vCPU info
```

### Common VM Issues

| Symptom | Check | Resolution |
|---|---|---|
| VM won't start | `qm start <vmid>` error output | Check storage availability, disk locks |
| VM unresponsive | `qm agent <vmid> ping` | Guest agent not installed or guest hung |
| Disk I/O slow | Web UI performance graphs | Check storage backend, snapshot chains |
| No network | `qm config <vmid>` net0 | Verify bridge exists, VLAN tag correct |
| Migration fails | Task log in web UI | Check shared storage, network, CPU compat |

---

## Container Diagnostics (pct)

```bash
# List all containers with status
pct list

# Container status and configuration
pct status <ctid>
pct config <ctid>

# Disk usage inside container
pct df <ctid>

# Run diagnostic command inside container
pct exec <ctid> -- systemctl --failed
pct exec <ctid> -- df -h
pct exec <ctid> -- free -m
```

---

## Cluster Health

```bash
# Cluster and quorum status
pvecm status

# Cluster membership
pvecm nodes
cat /etc/pve/.members

# Quorum details
corosync-quorumtool -s

# HA resource status
ha-manager status

# Cluster resources overview (API)
pvesh get /cluster/resources --type node
pvesh get /cluster/resources --type vm
pvesh get /cluster/resources --type storage
```

### Cluster Health Checks

| Check | Command | Healthy State |
|---|---|---|
| Quorum | `pvecm status` | "Quorate: Yes" |
| All nodes online | `pvecm nodes` | All nodes listed, status "M" |
| HA resources | `ha-manager status` | All resources "started" |
| Corosync rings | `corosync-cfgtool -s` | All rings active |

---

## Ceph Diagnostics

```bash
# Overall cluster health
ceph status
ceph health detail

# OSD status
ceph osd status                    # Up/down, in/out per OSD
ceph osd df                        # Disk usage per OSD
ceph osd tree                      # CRUSH tree structure

# Pool status
ceph df                            # Pool usage summary
rados df                           # Object store stats

# Placement group health
ceph pg stat                       # PG summary
ceph pg dump_stuck                 # Stuck PGs (stale, inactive, unclean)

# Performance
ceph osd perf                      # OSD commit/apply latency
ceph tell osd.0 bench              # Benchmark specific OSD
```

### Common Ceph Issues

| Symptom | Check | Resolution |
|---|---|---|
| HEALTH_WARN | `ceph health detail` | Follow specific warning guidance |
| OSD down | `ceph osd status` | Check node, disk, restart OSD |
| Degraded PGs | `ceph pg stat` | Wait for recovery or add OSDs |
| Full OSDs | `ceph osd df` | Add capacity, rebalance, delete data |
| Slow requests | `ceph health detail` | Check OSD latency, network |

---

## Log Locations

| Service | Log Command / Path |
|---|---|
| Proxmox daemon | `journalctl -u pvedaemon` |
| Web UI proxy | `journalctl -u pveproxy` |
| Corosync | `journalctl -u corosync` |
| HA Manager | `journalctl -u pve-ha-lrm` and `pve-ha-crm` |
| Specific VM | `journalctl -u qemu-server@<vmid>` |
| Ceph | `journalctl -u ceph.target` |
| Firewall | `journalctl -u pve-firewall` |
| Active tasks | `tail -f /var/log/pve/tasks/active` |
| Syslog | `/var/log/syslog` |

### Useful Log Searches

```bash
# Recent errors across all services
journalctl -p err --since "1 hour ago"

# VM-specific events
journalctl -u qemu-server@100 --since today

# Corosync membership changes
journalctl -u corosync | grep -i "member\|join\|leave"

# HA failover events
journalctl -u pve-ha-crm | grep -i "fence\|restart\|migrate"

# Storage errors
journalctl | grep -i "ceph\|zfs\|lvm" | grep -i "error\|fail\|warn" | tail -20
```

---

## Network Diagnostics

```bash
# Bridge status
brctl show                          # List bridges and enslaved interfaces
ip link show vmbr0                  # Bridge state

# VLAN verification
bridge vlan show                    # VLAN assignments per port

# Bonding status
cat /proc/net/bonding/bond0         # Bond mode, slave status, link state

# SDN status
pvesh get /cluster/sdn/vnets       # List VNets
pvesh get /cluster/sdn/zones       # List zones

# General connectivity
ping -c 4 <target>                 # Basic connectivity
traceroute <target>                # Path analysis
ss -tlnp                           # Listening ports
```

---

## Performance Troubleshooting

### High CPU Usage
1. Check web UI Node Summary for overall CPU
2. Identify top VM/CT consumers in VM list
3. Check CPU overcommit ratio: `pvesh get /cluster/resources --type node`
4. Inside guest: `top` or `htop` to identify process

### High Memory Usage
1. Check node memory: `free -h` on host
2. Check ZFS ARC usage: `cat /proc/spl/kvm/arcstats | grep size`
3. Check KSM activity: `cat /sys/kernel/mm/ksm/pages_shared`
4. Identify memory-hungry VMs in web UI

### Storage Performance
1. Web UI: check per-VM disk I/O graphs
2. Host-level: `iostat -x 1 5` for per-device stats
3. Ceph: `ceph osd perf` for OSD latency
4. ZFS: `zpool iostat -v 1 5` for pool I/O

### Network Performance
1. Check link status: `ip link show`
2. Check bond status: `cat /proc/net/bonding/bond0`
3. Bandwidth test: `iperf3 -c <target>` between nodes
4. Check for dropped packets: `ip -s link show vmbr0`
