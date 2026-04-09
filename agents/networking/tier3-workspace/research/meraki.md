# Cisco Meraki Deep Dive

## Overview

Cisco Meraki is a cloud-managed networking platform that centralizes all configuration, monitoring, and troubleshooting in the Meraki Dashboard — a SaaS-based management plane hosted by Cisco. Unlike traditional network platforms where management lives on-device or in on-premises software, Meraki devices phone home to Cisco's cloud and receive their entire configuration from the Dashboard. Zero-touch deployment, consistent policy enforcement, and a simplified operator experience are Meraki's core value propositions.

Product families:
- **MX** — Security and SD-WAN appliances
- **MS** — Managed switches
- **MR** — Wireless access points
- **MT** — IoT environmental sensors
- **MV** — Smart cameras (AI-powered video)
- **MG** — Cellular gateways

---

## Cloud-Managed Architecture

### Dashboard as Single Pane of Glass

The Meraki Dashboard (dashboard.meraki.com) is the sole management interface for all Meraki products. Key principles:
- **No on-premises management server required**: configuration stored entirely in Meraki cloud
- **Automatic firmware updates**: Meraki pushes firmware on administrator-scheduled windows
- **Real-time device state**: Dashboard reflects live device status within seconds
- **Hierarchy**: Organization > Network > Devices

**Organization**: Top-level container (a company or MSP customer account)
**Network**: Logical grouping of devices at a site (a branch, campus, or combined network)
**Device**: Individual appliance, switch, AP, or sensor

A device physically located in London can be managed from any browser anywhere — there is no VPN or jump host required to access management.

### Device-to-Cloud Communication

Every Meraki device maintains a persistent HTTPS connection to Meraki's cloud infrastructure (hosted on AWS):
- Devices poll the cloud for configuration changes
- Configuration delta is pushed to the device within seconds of a Dashboard change
- If cloud connectivity is lost, devices continue forwarding based on last-known configuration
- Management plane is cloud-dependent; data plane operates independently

All management traffic uses TCP 443 (HTTPS) and TCP/UDP 7351 (Meraki-specific tunnel). Devices must have internet access to reach dashboard.meraki.com and its cloud endpoints.

---

## MX Security and SD-WAN Appliances

### Overview

MX appliances provide:
- Stateful firewall (Layer 3-7)
- SD-WAN with AutoVPN
- IDS/IPS (Snort-based, Sourcefire Talos signatures)
- Content filtering (URL/application categories)
- Advanced Malware Protection (AMP) via Cisco Talos
- Traffic shaping / QoS

### AutoVPN

AutoVPN is Meraki's flagship SD-WAN capability — it creates a full-mesh or hub-and-spoke VPN topology between MX appliances automatically:

1. Each MX registers its public IP and subnet information with the Meraki cloud
2. Meraki cloud orchestrates IPsec tunnel parameters between peers
3. Tunnels are established automatically — no manual IKE/IPsec configuration
4. Topology is configurable: Full Mesh or Hub-and-Spoke

**Hub-and-Spoke:**
- Spoke sites forward all or specific traffic to a hub MX
- Hub MX handles inter-site routing, firewall, and internet breakout
- Useful for centralized security inspection

**Full Mesh:**
- Direct spoke-to-spoke tunnels for lowest latency between branches
- Requires more tunnels but avoids hub bottleneck

**Configuration example:**
```
Security & SD-WAN > Site-to-site VPN
VPN mode: Hub (Mesh) or Spoke
Hub(s): Select which networks act as hubs
Subnets: Auto-detected from connected VLANs
```

### Traffic Shaping

MX supports per-application traffic shaping:
- Application recognition using NBAR-like Deep Packet Inspection
- Assign bandwidth limits (upload/download min/max) per application or category
- Priority levels: High, Normal, Low
- SD-WAN policies: steer specific apps over preferred WAN links (e.g., video conferencing over MPLS, bulk traffic over broadband)
- Link health monitoring: continuous latency, jitter, and packet loss monitoring per WAN link; automatic failover

### Content Filtering

- Category-based URL filtering (adult content, gambling, social media, etc.)
- Powered by Cisco Talos threat intelligence
- SafeSearch enforcement for search engines
- HTTPS inspection (requires certificate deployment)
- Deny lists with custom URL entries

### IDS/IPS

- Snort-based intrusion detection/prevention engine
- Rule sets from Cisco Talos (updated automatically)
- Three modes: Detection (log only), Prevention (block matched), or Disabled
- Custom allow-lists for false positive suppression
- Available on MX with Security license tier

### MX Platform Models

- **MX67/MX68**: Small branch (max 50/300 users); stateful throughput 450/750 Mbps
- **MX84**: Mid-size branch; 500 Mbps stateful
- **MX95/MX105**: 1/3 Gbps stateful; branch and campus edge
- **MX250/MX450**: Data center/campus; up to 6/10 Gbps stateful
- **vMX**: Virtual appliance for AWS, Azure, VMware deployments

---

## MS Managed Switches

### Auto-Provisioning

MS switches are zero-touch provisioned:
1. Plug in and connect to internet
2. Switch calls home to Meraki cloud
3. Pulls configuration from Dashboard (VLANs, port profiles, QoS, ACLs)
4. Ready for production within minutes

### Features

- Port profiles: assign port configurations (VLAN, PoE, STP settings) as reusable profiles
- VLAN trunking and access port assignment
- RSTP/MSTP spanning tree
- Layer 3 routing on select models (MS390, MS410, MS425)
- QoS: DSCP marking, CoS queuing
- ACLs: per-port and VLAN-based access control
- **Stacking**: physical stacking for MS390 and MS425 series (up to 8 switches/stack)
- Port scheduling: time-based PoE enable/disable

### Switch Families

- **MS120/MS125**: Access layer, 8-48 port, PoE options
- **MS130**: Compact, multi-gigabit options
- **MS210/MS225**: Aggregation with 10G uplinks
- **MS250**: Distribution, L3 capable
- **MS350/MS355**: Enterprise aggregation, multi-gig, 10G SFP+
- **MS390**: Modular access switch, stacking, advanced L3
- **MS410/MS425**: Aggregation/distribution, QSFP+ 40G uplinks

---

## MR Wireless Access Points

### Dashboard Management

All MR APs are managed via Dashboard:
- SSID configuration: authentication (WPA2/WPA3, 802.1X, PSK), VLAN assignment, bandwidth limits
- RF management: auto channel and power (RRM — Radio Resource Management)
- Floor plan upload with AP placement visualization
- Client association and roaming event history

### Features

- **Air Marshal**: dedicated RF scanning for rogue AP detection and containment
- **Packet capture**: on-AP packet capture accessible from Dashboard remotely
- **Client fingerprinting**: device type identification (iOS, Android, Windows, IoT)
- **Splash pages**: captive portal with click-through, sign-on, or billing integration
- **MR46/MR56/MR78**: Wi-Fi 6/6E access points for high-density environments

---

## Dashboard REST API v1

Meraki provides a comprehensive REST API for programmatic management.

**Base URL:** `https://api.meraki.com/api/v1`

**Authentication:** `X-Cisco-Meraki-API-Key` header

### Key Resource Hierarchy

```
/organizations
/organizations/{orgId}/networks
/organizations/{orgId}/devices
/networks/{networkId}/devices
/networks/{networkId}/clients
/networks/{networkId}/appliance/firewall/l3FirewallRules
/networks/{networkId}/switch/accessPolicies
/networks/{networkId}/wireless/ssids
```

### Example API Calls

```bash
# List all organizations
curl -X GET https://api.meraki.com/api/v1/organizations \
  -H "X-Cisco-Meraki-API-Key: <api_key>"

# Get all networks in org
curl -X GET https://api.meraki.com/api/v1/organizations/12345/networks \
  -H "X-Cisco-Meraki-API-Key: <api_key>"

# Get live clients in a network
curl -X GET "https://api.meraki.com/api/v1/networks/{netId}/clients?timespan=3600" \
  -H "X-Cisco-Meraki-API-Key: <api_key>"

# Update firewall rules
curl -X PUT https://api.meraki.com/api/v1/networks/{netId}/appliance/firewall/l3FirewallRules \
  -H "X-Cisco-Meraki-API-Key: <api_key>" \
  -H "Content-Type: application/json" \
  -d '{"rules": [{"comment":"Deny Telnet","policy":"deny","protocol":"tcp","destPort":"23","destCidr":"Any","srcPort":"Any","srcCidr":"Any"}]}'
```

### Pagination

Large result sets use cursor-based pagination:
```bash
# First page returns Link header with next cursor
Link: <https://api.meraki.com/api/v1/organizations/.../networks?startingAfter=xxx>; rel=next
```

### Rate Limiting

- Default: 10 API calls per second per organization
- Response header: `X-Request-Id`, `Retry-After` (on 429)
- Meraki Python SDK handles rate limiting automatically

---

## Webhooks

Meraki sends real-time event notifications via HTTP POST webhooks:
- Configure webhook receivers in Dashboard: Network > Alerts > Webhooks
- Events: device offline, VPN tunnel change, client association, intrusion detection
- Payload format: JSON with event type, timestamp, organization, network, and device context

```json
{
  "sentAt": "2025-09-15T14:52:00Z",
  "organizationId": "12345",
  "networkId": "L_12345",
  "networkName": "Branch Office",
  "alertType": "VPN connectivity changed",
  "alertTypeId": "vpn_connectivity_change",
  "deviceName": "MX84",
  "deviceMac": "00:11:22:33:44:55"
}
```

---

## Action Batches

Action Batches enable bulk API operations in a single atomic call:
- Up to 100 actions per batch (synchronous) or 1000 actions (asynchronous)
- All-or-nothing: if any action fails, the batch is rolled back
- Use cases: mass VLAN deployment, bulk firewall rule updates, multi-site configuration sync

```python
import meraki
dashboard = meraki.DashboardAPI('<api_key>')
dashboard.organizations.createOrganizationActionBatch(
    organizationId='12345',
    actions=[
        {'resource': '/networks/L_111/appliance/vlans', 'operation': 'create',
         'body': {'id': 10, 'name': 'Prod', 'subnet': '10.0.10.0/24', 'applianceIp': '10.0.10.1'}},
        {'resource': '/networks/L_222/appliance/vlans', 'operation': 'create',
         'body': {'id': 10, 'name': 'Prod', 'subnet': '10.0.11.0/24', 'applianceIp': '10.0.11.1'}},
    ],
    confirmed=True,
    synchronous=False
)
```

---

## MT (IoT Sensors) and MV (Smart Cameras)

### MT Sensors

MT sensors monitor physical environment conditions:
- Temperature, humidity, water presence, door open/close, power draw, indoor air quality
- Communicate via Bluetooth to a nearby MR AP (which acts as gateway)
- Data visible in Dashboard > Sensors
- Alerting: thresholds trigger email/webhook/SMS notifications
- **MT40**: multi-function environmental sensor

### MV Smart Cameras

MV cameras integrate computer vision directly into the camera hardware:
- Motion detection, people counting, object detection (no cloud video processing required)
- Video stored on camera (up to 512 GB local storage depending on model)
- Dashboard provides live view, playback, and motion search
- **MV Sense API**: access real-time and historical people count, motion data, and object bounding boxes via REST or MQTT
- Use case: occupancy analytics, security monitoring, retail foot traffic

```bash
# Get snapshot from camera
GET /networks/{networkId}/cameras/{serial}/snapshot

# Get people count data
GET /devices/{serial}/camera/analytics/recent
```

---

## Licensing Models

### Co-Term Licensing (Legacy)

- All devices in an organization share a single expiry date
- New device license terms are co-termed (adjusted) to match existing licenses
- Simpler for organizations where all devices were deployed simultaneously
- Renewal requires aligning all licenses

### Per-Device Licensing (PDL) — Current Model

- Each device has its own license term (1, 3, 5, or 7 years)
- Different devices can have different expiry dates
- Licenses are reusable — can be reassigned to replacement hardware
- Simpler for phased deployments or device refresh programs
- New organizations default to PDL

### MX License Tiers

- **Enterprise**: SD-WAN, AutoVPN, content filtering, traffic shaping
- **Advanced Security (formerly MX-SEC)**: adds IDS/IPS, AMP, URL category filtering
- **Secure SD-WAN Plus**: all Advanced Security features + Meraki Insight (WAN health, app health monitoring, VoIP health)

**Important**: MX licensing must be uniform across an organization — all MX devices must have the same license tier.

---

## When Meraki vs Traditional

### Choose Meraki When:

- IT team is small or has limited network expertise — Dashboard simplicity reduces OPEX
- Multi-site distributed deployments with no on-site IT staff
- Fast deployment timelines — ZTP eliminates pre-staging
- Consistent policy across many sites without per-device CLI management
- Integration with Cisco SecureX, Umbrella, or Duo
- Cloud-first organization comfortable with SaaS dependency

### Choose Traditional (Catalyst, Nexus, Juniper) When:

- Deep protocol customization required (complex routing policies, MPLS, advanced QoS)
- Regulatory/compliance requirements prohibit cloud management dependency
- Large-scale data center environments (Meraki is primarily campus/branch)
- Existing team expertise is CLI-driven and values on-premises control
- TCO analysis favors perpetual licensing at scale

### Hybrid Deployments

Meraki coexists well with traditional networking:
- Meraki MX connects via AutoVPN or static VPN to non-Meraki firewalls
- MS switches can uplink to traditional campus cores
- Dashboard API enables integration with external ITSM, monitoring, and IPAM tools

---

## Summary

Meraki excels in distributed enterprise environments where operational simplicity and centralized visibility outweigh deep protocol flexibility. Its Dashboard-centric model, AutoVPN, and rich API make it ideal for multi-site deployments managed by lean IT teams. The licensing model is subscription-based — Meraki is fundamentally a cloud service, and the devices become paperweights without active licenses.

**Best for**: Distributed retail/branch networks, SMB to mid-enterprise, MSP-managed deployments, organizations prioritizing operational simplicity over protocol depth.

**Consider alternatives when**: Data center switching is the primary use case, protocol customization depth is needed, or cloud management dependency is a blocker.
