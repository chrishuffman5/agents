# Dell PowerStore Diagnostics and Troubleshooting

## Performance Monitoring

### PowerStore Manager Dashboards
Real-time and historical metrics. No additional monitoring software required.

| Category | Metrics |
|---|---|
| Appliance | Total IOPS, throughput, latency, CPU utilization |
| Volume | IOPS (read/write), throughput, latency, queue depth |
| File System | IOPS, throughput, latency, capacity |
| Front-end Port | IOPS, throughput, link utilization |
| Node | CPU, memory, cache hit rate |

Version additions: 4.0: Volume Family Unique Data, space savings metrics. 4.1: Appliance Utilization, Max Sustainable IOPS, carbon metrics. 4.2: anomaly detection, port-level metrics. 4.3: Top Talkers for file.

### Best Practices
- Establish baselines during off-peak after deployment
- Monitor volume-level latency (not just appliance-level)
- Check max latency in addition to average — spikes indicate queue depth issues
- For VMware: correlate PowerStore metrics with vSphere storage performance
- Use anomaly detection (4.2+) for automated deviation alerts

### External Integration
Dynatrace, LogicMonitor, REST API (Prometheus/Grafana/Splunk), Dell APEX AIOps.

## SupportAssist

**Critical**: Direct Connect discontinued Dec 31, 2024. All clusters require Secure Connect Gateway (SCG).

Configuration: PowerStore Manager > Settings > Support Connectivity > configure SCG gateway.

Requirements: DNS resolution of SupportAssist endpoints, HTTPS (TCP 443) to Dell backend.

Troubleshooting enablement failure:
1. Verify DNS from management nodes
2. Check firewall rules (TCP 443)
3. Verify SCG registration and reachability
4. See Dell KB 000251599 for SCG DNS check failures

Disable notifications during planned maintenance to prevent false-positive support cases.

## Alert Management

| Severity | Action |
|---|---|
| Critical | Immediate intervention |
| Major | Prioritized intervention |
| Minor | Plan resolution |
| Informational | Review only |

**Rule**: Do NOT perform maintenance or NDU with active Critical/Major alerts. Resolve or acknowledge first.

Common categories: Drive fault tolerance (KB 000221123), SSD offline/failed (KB 000207485), cluster monitoring (KB 000182004), SupportAssist connectivity (KB 000126457), ONV ICMP alerts (bond0 restriction).

Alert notifications: Email (SMTP, StartTLS in 4.2+), SNMP traps, SupportAssist, REST API webhooks. Configure 2+ recipients; use distribution lists.

## Health Checks

### On-Demand
PowerStore Manager > Monitoring > System Checks > Run System Check. Evaluates drives, hardware, network, services, SupportAssist, certificates. Run before NDU, maintenance, and monthly.

### Off-Release Packages
Dell releases health check thin packages for post-release issues (KB 000214752). Install before any planned NDU.

### Pre-Upgrade
1. Download latest package for target version
2. Install via PowerStore Manager
3. Run: Settings > Software > Upgrade > Run Upgrade Extensions
4. Resolve Critical/Major findings before proceeding
5. 3+ appliance clusters upgrading to 4.1: review KB 000286668

## Connectivity Troubleshooting

### iSCSI
1. Verify target IPs reachable from host
2. Check IQN registration in PowerStore Manager host definition
3. Confirm CHAP settings match
4. Verify VLAN consistency
5. Verify MTU end-to-end (9000 on all hops if jumbo frames)
6. Confirm NOT using bond0 ports for direct-attach
7. Check port link status in Manager

Linux multipath: `multipath -ll` (expect 2+ active ready paths). Windows: `mpclaim -s -d`.

### Fibre Channel
1. Verify FC zoning (initiator WWPN to PowerStore target ports)
2. Check host WWPNs in host definition
3. Verify FC port status (Up with login count)
4. Host fabric login check: Linux `systool -c fc_host -v`, Windows Device Manager
5. Confirm LUN masking (host group mapped to volume/volume group)
6. VMware: rescan HBAs, check storage adapter paths

### NVMe-oF
1. Verify unique NQN on each host (duplicates cause failures in K8s)
2. Confirm nvme-cli installed and kernel modules loaded
3. Discover: `nvme discover -t tcp -a <target-ip> -s 4420`
4. Verify subsystem NQN matches
5. NVMe/FC: confirm FC zoning and NVMe FC driver
6. NOT using bond0 ports

### ONV Alerts
Direct-attached hosts on bond0 prevent inter-node ICMP. Move to non-bond0 ports or acknowledge as informational.

### Drive Replacement
Identify in PowerStore Manager > Hardware > Drives. Hot-swappable. Monitor rebuild (2-6 hours under light load). Do NOT initiate NDU during rebuild.

## Log Collection
PowerStore Manager > Settings > Support > Collect Diagnostics. Collects system logs, config snapshots, performance data, hardware logs. SupportAssist can auto-collect when support case opened.
