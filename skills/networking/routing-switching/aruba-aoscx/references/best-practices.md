# Aruba AOS-CX Best Practices Reference

## Aruba Central Management

### Zero-Touch Provisioning

- Pre-register switch serial numbers in Aruba Central before powering on
- Switches auto-claim at boot using factory-default cloud redirect
- Configure DHCP option 60 (vendor class "ArubaInstantAP") for PXE-like discovery
- Use site assignments for geographic grouping and template inheritance

### Template Groups

- Create template groups per role (access, aggregation, core, DC leaf)
- Use variables for site-specific values (management IP, VLAN ranges, NTP servers)
- Template compliance checking alerts on configuration drift
- Push notifications for template changes requiring manual approval

### Firmware Management

- Stage firmware uploads to Central before scheduling upgrades
- Use maintenance windows with automatic rollback on health check failure
- Upgrade in waves: pilot site first, then production
- Verify post-upgrade health via Central AIOps dashboard

### AIOps

- Enable AI-powered anomaly detection for proactive issue identification
- Configure baseline periods (minimum 7 days) for accurate anomaly thresholds
- Review AI recommendations daily during initial deployment; tune false positive thresholds
- Use natural language search for quick troubleshooting

## NAE Agent Best Practices

### Development

- Start with pre-built agents from Aruba Developer Hub before writing custom scripts
- Test agents on lab switches before deploying to production
- Use parameters for configurable thresholds (avoid hardcoded values)
- Keep monitoring periods reasonable (30+ seconds for counter-based monitors)

### Resource Management

- NAE agents share switch CPU/memory -- limit concurrent active agents
- Recommended: no more than 10 active agents per switch
- Avoid sub-10-second polling intervals for counter-based monitors
- Use `show nae agents` to monitor agent CPU/memory consumption

### Alerting

- Use ActionSyslog for integration with existing SIEM/monitoring platforms
- Use REST webhooks for ChatOps (Slack, Teams) integration
- Chain alerts: use ActionCLI to collect diagnostic data when anomaly detected
- Example: BGP down alert triggers `show bgp summary` capture for later analysis

### Recommended Built-in Agents

| Agent | Use Case | Platform |
|---|---|---|
| BGP Session Monitor | Peer state change alerting | CX 6200+ |
| OSPF Neighbor Flap | Adjacency stability | CX 6200+ |
| PoE Power Budget | Power capacity warnings | CX 6100/6200 |
| STP Topology Change | STP instability detection | All |
| MAC Table Exhaustion | Table capacity warnings | All |
| COPP Drop Monitor | Control plane overload | CX 6200+ |
| Interface Error Rate | Physical layer issues | All |

## VSX Design

### ISL Design

- Use a dedicated LAG for ISL (minimum 2 x 10G or 1 x 100G)
- ISL carries: control plane sync, MAC/ARP sync, data traffic for orphan ports
- Size ISL bandwidth for worst-case orphan port traffic
- Use diverse physical paths for ISL member links

### Keepalive Design

- Always configure keepalive on a separate path from ISL
- Management VRF with dedicated management interface recommended
- Keepalive detects ISL failure and triggers secondary port shutdown
- Without keepalive, ISL failure causes split-brain -- both switches active with stale state

### Multi-Chassis LAG Design

- Use LACP mode active on all multi-chassis LAGs
- Configure system-mac for consistent LACP system ID
- Test failover: disable ISL, verify secondary disables multi-chassis ports
- Test recovery: re-enable ISL, verify port restoration and MAC sync

### VSX + Routing

- Both switches run independent BGP/OSPF instances
- Advertise both loopback IPs and shared VTEP IP
- ECMP from hosts via single multi-chassis LAG to both switches
- For EVPN: configure shared logical VTEP (loopback 2) with `active-forwarding`

### VSX Upgrade Strategy

- Stage firmware on both VSX peers
- Upgrade secondary first, verify health
- Failover traffic to secondary (disable primary multi-chassis ports)
- Upgrade primary, verify health
- Restore normal operation

## ClearPass Integration

### RADIUS Server Configuration

```bash
radius-server host 10.0.0.50 key plaintext <secret>
    tracking-enable
    auth-port 1812
    acct-port 1813

aaa server-group radius CLEARPASS
    server 10.0.0.50
    server 10.0.0.51
```

### Authentication Order

- 802.1X first (strongest: certificate/EAP-TLS or credentials/PEAP)
- MAC-Auth fallback for devices without supplicant (printers, IP phones, IoT)
- Configure concurrent authentication for mixed environments (10.15+)

### Dynamic VLAN Assignment

ClearPass returns RADIUS attributes:
- `Tunnel-Type = VLAN`
- `Tunnel-Medium-Type = IEEE-802`
- `Tunnel-Private-Group-Id = <vlan-id>`

Switch dynamically assigns port to returned VLAN.

### Downloadable ACLs

ClearPass returns `Filter-Id` attribute with ACL name:
- ACL must be pre-configured on switch (unless using Aruba downloadable user roles)
- Use role-based ACLs for scalable policy enforcement

### User-Based Tunneling (UBT)

```bash
interface 1/1/1
    aaa authentication port-access client-mode single
    aaa authentication port-access dot1x authenticator
    aaa authentication port-access auth-mode client-mode
```

ClearPass returns UBT role with tunnel destination:
- GRE tunnel from switch to Aruba Mobility Controller/Gateway
- Centralized firewall, QoS, and policy enforcement
- Enables consistent policy across wired + wireless

### ClearPass Best Practices

- Deploy ClearPass in HA cluster (publisher + subscriber) for redundancy
- Use RADIUS CoA (Change of Authorization) for dynamic policy updates
- Enable RADIUS accounting for session tracking and audit trails
- Profile devices using ClearPass Device Insight for accurate classification
- Test authentication flows in ClearPass sandbox before production deployment

## Campus Network Design

### Access Layer

```bash
# Standard access port
interface 1/1/1
    no shutdown
    description "User Access"
    vlan access 100
    spanning-tree port-type admin-edge
    spanning-tree bpdu-guard enable
    loop-protect
```

### Trunk Port

```bash
interface 1/1/49
    no shutdown
    description "Uplink to Distribution"
    vlan trunk native 1 allowed 100,200,300
    spanning-tree port-type admin-network
```

### VRRP for Gateway Redundancy

```bash
interface vlan 100
    ip address 10.100.0.2/24
    vrrp 1
        virtual-ip 10.100.0.1
        priority 110
        preempt
```

### Spanning Tree

- Use MSTP or RPVST+ depending on environment
- Set explicit root priority on distribution/core switches
- Enable BPDU Guard on all access ports
- Enable Loop Protect on all access ports
- Use admin-edge port type (equivalent to PortFast) on access ports

## Security Hardening

### Management Access

```bash
ssh server vrf mgmt
no telnet server vrf mgmt
ip ssh minimum-hostkey-size 2048
user admin group administrators password plaintext <password>
```

### Access Lists

```bash
access-list ip MGMT-ACCESS
    10 permit tcp 10.0.0.0/8 any eq ssh
    20 permit tcp 10.0.0.0/8 any eq https
    30 deny any any any

interface mgmt
    apply access-list ip MGMT-ACCESS in
```

### SNMP

```bash
snmpv3 user MONITOR auth sha auth-pass <pass> priv aes priv-pass <pass>
snmpv3 context all user MONITOR security-model usm
```

### Syslog

```bash
logging 10.0.0.100 severity info
logging facility local7
```

## Upgrade Procedures

### Pre-Upgrade

1. `show version` -- current version and platform
2. `show system` -- hardware health
3. `checkpoint create pre-upgrade` -- save rollback point
4. Review release notes for target version
5. Verify Central compatibility (if managed)

### Upgrade Steps

```bash
# Copy image
copy scp://user@server/AOS-CX_10.15.bin flash:

# Boot from new image
boot set-default primary flash:AOS-CX_10.15.bin

# Reboot
boot system
```

### Post-Upgrade

```bash
show version                              # Confirm target version
show system                               # Hardware health
show vsx status                           # VSX peer state
show bgp summary                          # BGP sessions
show evpn summary                         # EVPN state
show nae agents                           # NAE agent health
```

### Rollback

```bash
checkpoint rollback pre-upgrade           # revert configuration
boot set-default primary flash:AOS-CX_10.14.bin  # revert image
boot system
```
