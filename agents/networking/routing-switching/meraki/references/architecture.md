# Cisco Meraki Architecture Reference

## Cloud Management Platform

### Dashboard Infrastructure

Meraki Dashboard runs on Cisco-managed cloud infrastructure (hosted on AWS):
- Globally distributed across multiple regions for low-latency access
- Multi-tenant architecture with organization-level data isolation
- All data encrypted at rest and in transit
- SOC 2 Type II, ISO 27001, and PCI DSS compliant

### Device-to-Cloud Communication

```
Meraki Device <-- HTTPS (TCP 443) --> dashboard.meraki.com
                 <-- Tunnel (TCP/UDP 7351) --> Meraki cloud endpoints
```

**Communication flow:**
1. Device boots and contacts Meraki cloud via HTTPS
2. Device authenticates using its serial number and hardware certificate
3. Cloud pushes current configuration to device (delta update)
4. Device reports state back to cloud (interface status, client counts, health metrics)
5. Persistent connection maintained for real-time configuration pushes
6. If connection lost, device continues forwarding with cached configuration

**Required connectivity:**
- TCP 443 to `dashboard.meraki.com` and regional endpoints
- TCP/UDP 7351 to Meraki cloud (configuration tunnel)
- UDP 7351 for cloud connectivity checks
- Devices must have internet access for management (NAT or proxy supported)

### Configuration Model

- **Desired state**: Dashboard stores the intended configuration
- **Device state**: Device reports its actual operational state
- **Delta sync**: Only changes are pushed (not full configuration on every update)
- **Conflict resolution**: Dashboard is the source of truth. Device always accepts cloud config.
- **Offline behavior**: Devices cache the full running config locally. All forwarding and security policies continue to operate during cloud outages.

## AutoVPN Architecture

### Tunnel Establishment

```
1. MX-A registers with Meraki cloud:
   - Public IP: 203.0.113.10
   - Local subnets: 10.1.0.0/24, 10.2.0.0/24
   - WAN uplinks: WAN1 (primary), WAN2 (backup)

2. MX-B registers with Meraki cloud:
   - Public IP: 198.51.100.20
   - Local subnets: 10.3.0.0/24
   - WAN uplinks: WAN1 (primary)

3. Cloud calculates VPN topology and distributes:
   - IKE parameters (cipher, hash, DH group, PSK)
   - Peer public IPs
   - Subnet advertisements

4. MX-A and MX-B establish IPsec tunnel directly (peer-to-peer)
   - Cloud is NOT in the data path
   - Data flows directly between MX appliances
```

### Topology Options

**Hub-and-Spoke:**
```
        [Hub MX-HQ]
       /     |      \
[Spoke-A] [Spoke-B] [Spoke-C]
```
- Spokes send all (or policy-specified) traffic to hub
- Hub provides centralized security inspection and internet breakout
- Inter-spoke traffic hairpins through hub
- Multiple hubs supported (primary + secondary for failover)

**Full Mesh:**
```
[MX-A] --- [MX-B]
  |    \  /    |
  |     \/     |
  |     /\     |
  |    /  \    |
[MX-C] --- [MX-D]
```
- Direct tunnels between all sites
- Lowest latency (no hub hairpin)
- More tunnels to manage (N*(N-1)/2)
- Each MX maintains tunnels to every other MX

### Concentrator

The VPN Concentrator is a hub MX that:
- Terminates all spoke VPN tunnels
- Does NOT participate in local LAN (no DHCP, no VLAN)
- Pure VPN termination and routing
- Deployed in data center for centralized spoke connectivity

### WAN Health Monitoring

MX continuously monitors WAN link health:
- Latency, jitter, and packet loss per WAN uplink
- ICMP probes to upstream gateways and internet targets
- Dashboard: Security & SD-WAN > SD-WAN & Traffic Shaping > Uplink Status
- Automatic failover when primary WAN degrades below threshold
- SD-WAN policies steer traffic based on real-time link performance

## Product Family Details

### MX Security Appliances

**Hardware architecture:**
- Custom hardware with dedicated security processors
- Deep Packet Inspection (DPI) engine for application classification
- Unified Threat Management (UTM): firewall + VPN + IDS/IPS + content filter + AMP
- Dual WAN ports with automatic failover and load balancing
- Built-in 802.11ac wireless on some models (MX67W, MX68W)

**vMX (Virtual MX):**
- Virtual appliance for AWS, Azure, and VMware environments
- Same feature set as physical MX (AutoVPN, firewall, traffic shaping)
- Deployed as EC2 instance (AWS), VM (Azure), or VMware guest
- Use case: extend AutoVPN into cloud environments

### MS Managed Switches

**Architecture:**
- ASIC-based hardware forwarding (wire-speed L2/L3)
- Cloud management via Dashboard (no local CLI for configuration)
- Local status page at `my.meraki.com` (read-only diagnostics)
- Zero-touch provisioning: plug in, connect to internet, pull config from cloud

**Stacking architecture (MS390):**
- Physical stacking via dedicated stacking cables
- Up to 8 switches per stack
- Stack acts as single logical switch in Dashboard
- Stack master handles control plane; all members forward independently
- If stack master fails, election promotes new master without data plane disruption

**Port profiles:**
- Reusable port configuration templates
- Define: VLAN, PoE, STP, port type (access/trunk), allowed VLANs
- Apply to individual ports or ranges in Dashboard
- Change profile to reconfigure multiple ports at once

### MR Wireless Access Points

**Architecture:**
- Cloud-managed radios with local data forwarding
- Client traffic switched locally (no hairpin to cloud for data)
- Management traffic to cloud for configuration, monitoring, and analytics
- On-AP packet capture and RF analysis remotely accessible from Dashboard

**Radio Resource Management (RRM):**
- Automatic channel assignment based on RF environment scan
- Automatic power adjustment to minimize co-channel interference
- Runs continuously in the background (not one-time at deployment)
- Dashboard: Wireless > Radio Settings > RF Spectrum

**Air Marshal:**
- Dedicated scanning radio on capable APs (MR46, MR56, MR78)
- Detects rogue APs, ad-hoc networks, and wireless threats
- Containment: send deauthentication frames to clients on rogue APs
- Configurable: always-on scanning or time-scheduled

### MT IoT Sensors

- Environmental monitoring: temperature, humidity, water, door, power, air quality
- Communicate via Bluetooth LE to nearby MR access points (gateway)
- No direct IP connectivity required -- MR acts as BLE gateway
- Dashboard: Sensors > Environmental
- Alerting: threshold-based email/webhook/SMS notifications

### MV Smart Cameras

- On-camera computer vision (people counting, motion detection, object detection)
- Video stored locally on camera (up to 512 GB)
- No cloud video processing required -- reduces bandwidth
- Dashboard: Cameras > Live View / Playback / Motion Search
- MV Sense API: REST or MQTT for real-time analytics data

## Template System

### Configuration Templates

Templates provide consistent configuration across multiple networks:

**Template hierarchy:**
```
Template (master configuration)
  |- Bound Network 1 (inherits template config)
  |- Bound Network 2 (inherits template config)
  |- Bound Network 3 (inherits template config)
```

**What templates control:**
- Firewall rules, traffic shaping, content filtering
- SSID configuration (wireless)
- VLAN configuration
- Switch port profiles
- VPN settings
- Alert configuration

**Template overrides:**
- Some settings can be overridden at the network level
- Override-capable settings are marked in Dashboard
- Non-override settings are locked to template values
- Best practice: minimize overrides for consistency

### Auto-VPN with Templates

- Template defines hub/spoke VPN role and topology
- Bound networks inherit VPN configuration
- Subnet advertisements automated based on VLAN configuration
- New sites deployed by binding to template and plugging in hardware

## Firmware Management

### Automatic Updates

Meraki manages firmware lifecycle:
- Dashboard: Organization > Firmware Upgrades
- Schedule upgrade windows (day of week, time range)
- Staged rollout: upgrade percentage of devices, validate, then proceed
- Rollback: revert to previous firmware if issues detected
- Release tracks: Stable (production), RC (release candidate), Beta

### Upgrade Behavior

- Firmware downloaded during non-peak hours
- Reboot occurs during scheduled upgrade window
- Upgrade takes 5-15 minutes per device (model dependent)
- Dashboard shows upgrade progress and post-upgrade device health
- Devices remain functional on current firmware until reboot
