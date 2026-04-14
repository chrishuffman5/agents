# NetBox Architecture Reference

## Data Model Deep Dive

### Site and Location Hierarchy

```
Region (geographic: Americas, EMEA, APAC)
  └── Site Group (organizational: Production, Lab, DR)
        └── Site (physical location: NYC-DC1, LAX-OFFICE)
              └── Location (building/floor/room: Building A, Floor 3, Server Room 1)
                    └── Rack (physical rack: Rack A01)
                          └── Device (at specific U-position)
```

**Design principles:**
- Regions are geographic (continent, country, metro)
- Site Groups are organizational (production, staging, lab)
- Sites represent physical locations with addresses
- Locations provide intra-site granularity (building, floor, room, cage)
- Racks have defined height (42U typical), dimensions, and weight capacity

### Device Model

**Device hierarchy:**
```
Manufacturer (Cisco, Aruba, Juniper, Palo Alto, etc.)
  └── Device Type (C9800-40, AP-535, EX4400-48P, PA-5260)
        └── Device (core-rtr-01, ap-floor3-east, fw-dmz-01)
              ├── Interfaces (GigabitEthernet0/1, eth0, xe-0/0/0)
              ├── Console Ports (console0)
              ├── Power Ports (PSU1, PSU2)
              └── Module Bays (line cards, SFP modules)
```

**Device Type templates:**
- Device Types define the physical form factor (interfaces, ports, bays)
- Community device type library: github.com/netbox-community/devicetype-library
- When a Device is created from a Device Type, interfaces and ports are auto-populated
- Custom device types for non-standard equipment

**Device fields:**
- `name`: Hostname (should match actual device hostname)
- `device_type`: References manufacturer and model
- `role`: Function (router, switch, firewall, AP, server)
- `site`: Physical location
- `rack` + `position`: Physical rack placement (U-position, face)
- `platform`: Operating system (IOS-XE, NX-OS, EOS, Junos, PAN-OS)
- `status`: Active, planned, staged, decommissioning, offline
- `primary_ip4` / `primary_ip6`: Management IP (used for automation inventory)
- `tenant`: Organizational ownership
- `config_context`: JSON data blob for device-specific automation variables

### Interface Model

**Interface types:**
- Physical: 1000BASE-T, 10GBASE-SR, 25GBASE-SR, 100GBASE-LR4, etc.
- Virtual: VLAN interface (SVI), loopback, port-channel/LAG, bridge
- Wireless: 802.11 (for AP radios)

**Interface fields:**
- `name`: Interface name (GigabitEthernet0/1, Ethernet1/1, xe-0/0/0)
- `type`: Physical/virtual type
- `enabled`: Administrative state
- `mac_address`: Interface MAC
- `mtu`: Maximum transmission unit
- `mode`: Access, tagged (trunk), tagged-all
- `untagged_vlan`: Native/access VLAN
- `tagged_vlans`: Trunk allowed VLANs
- `lag`: Parent LAG interface (for member interfaces)
- `cable`: Physical cable connection

### Cable Model

Cables represent physical connections:
```
Device A, Interface 1 ←──── Cable ────→ Device B, Interface 2
```

**Cable features:**
- Type: CAT5e, CAT6, CAT6A, fiber (single-mode, multi-mode), DAC, etc.
- Length and color tracking
- Cable trace: follow complete physical path including patch panels
- Supports patch panel intermediate terminations:
  ```
  Switch Port → Patch Panel Front → Patch Panel Rear → Another Panel → Server NIC
  ```

## IPAM Architecture

### Prefix Hierarchy

```
RIR Aggregate (10.0.0.0/8)
  └── Container: 10.1.0.0/16 (Site NYC)
        ├── 10.1.1.0/24 (MGMT VLAN, VRF: MGMT)
        ├── 10.1.10.0/24 (Users VLAN 10, VRF: CORP)
        ├── 10.1.20.0/24 (Voice VLAN 20, VRF: CORP)
        └── 10.1.100.0/24 (Server VLAN 100, VRF: DC)
              ├── 10.1.100.1/24 (Gateway, assigned to SVI on core switch)
              ├── 10.1.100.10/24 (Web server 1)
              └── 10.1.100.11/24 (Web server 2)
```

**Prefix status values:**
- `Container`: Parent prefix; holds child prefixes (no IP assignment)
- `Active`: In use; IPs can be assigned
- `Reserved`: Reserved for future use
- `Deprecated`: No longer in use; scheduled for cleanup

**Prefix roles:** Custom roles to classify purpose (Infrastructure, Loopback, Management, User, Voice, Server, IoT)

### VRF (Virtual Routing and Forwarding)

VRFs provide IP address space isolation:
- Same prefix can exist in multiple VRFs (overlapping addressing)
- Route distinguisher (RD) and import/export route targets
- Prefixes and IP addresses are assigned to VRFs
- Default VRF (null/global) for non-VRF prefixes

### VLAN Model

```
VLAN Group (scope: site, location, or global)
  └── VLAN (ID: 10, Name: MGMT, Status: active)
        └── Associated Prefix (10.1.1.0/24)
```

**VLAN Groups** scope VLAN IDs:
- Site-scoped: VLAN IDs unique within a site
- Location-scoped: VLAN IDs unique within a location (building, floor)
- Global: VLAN IDs unique globally (rare)

**VLAN-to-Prefix association**: Link VLANs to prefixes to document which VLAN carries which subnet.

### IP Address Assignment

```
IP Address (10.1.1.10/24)
  ├── Status: active
  ├── VRF: MGMT
  ├── Tenant: Network Operations
  ├── assigned_object_type: dcim.interface
  ├── assigned_object_id: 42 (GigabitEthernet0/1 on core-rtr-01)
  └── role: (blank, secondary, anycast, VIP, VRRP, HSRP, GLBP, CARP)
```

Special IP roles:
- `secondary`: Secondary IP on an interface
- `anycast`: Anycast IP (same IP on multiple devices)
- `vip`: Virtual IP for load balancing
- `vrrp/hsrp/glbp/carp`: FHRP virtual IP

### Available IP/Prefix Allocation

NetBox can allocate the next available IP from a prefix or the next available prefix from a parent:

```
GET /api/ipam/prefixes/15/available-ips/
# Returns: first available IP in prefix 15

POST /api/ipam/prefixes/15/available-ips/
# Creates the next available IP and returns it

GET /api/ipam/prefixes/15/available-prefixes/
# Returns available child prefixes

POST /api/ipam/prefixes/15/available-prefixes/
{"prefix_length": 28}
# Creates and returns the next available /28 from prefix 15
```

## API Architecture

### REST API Design

Base URL: `https://netbox.example.com/api/`

**Namespaces:**
| Namespace | Resources |
|---|---|
| `/api/dcim/` | Sites, locations, racks, devices, interfaces, cables, modules |
| `/api/ipam/` | Prefixes, IPs, VLANs, VRFs, ASNs, FHRP groups |
| `/api/circuits/` | Providers, circuits, circuit terminations |
| `/api/tenancy/` | Tenants, tenant groups, contacts |
| `/api/extras/` | Custom fields, tags, webhooks, scripts, config templates |
| `/api/virtualization/` | Virtual machines, clusters, VM interfaces |
| `/api/users/` | Users, groups, permissions, tokens |
| `/api/wireless/` | Wireless LANs, wireless links |

**Response format:**
```json
{
  "count": 42,
  "next": "https://netbox.example.com/api/dcim/devices/?limit=50&offset=50",
  "previous": null,
  "results": [
    {
      "id": 1,
      "url": "https://netbox.example.com/api/dcim/devices/1/",
      "name": "core-rtr-01",
      "device_type": { "id": 5, "url": "...", "manufacturer": {...}, "model": "C9800-40" },
      "role": { "id": 1, "name": "Router" },
      "site": { "id": 1, "name": "NYC-DC1" },
      "status": { "value": "active", "label": "Active" },
      "primary_ip4": { "id": 10, "address": "10.1.1.1/24" }
    }
  ]
}
```

### GraphQL API Design

Endpoint: `POST /graphql/`

**Advantages over REST:**
- Single request for complex queries (device + interfaces + IPs in one call)
- Client specifies exactly which fields to return (no over-fetching)
- Cursor-based pagination for large datasets (v4.5.2+)

**Limitations:**
- Read-only (use REST for write operations)
- Complex filters may be slower than targeted REST queries
- Schema changes with NetBox versions (regenerate client code on upgrade)

### Webhook Architecture

NetBox sends HTTP POST to external URLs on object create/update/delete:
```
Event (device created) → Webhook → External system (Ansible Tower, ServiceNow, Slack)
```

Configure via Admin > Webhooks:
- Trigger on: create, update, delete
- Content types: specify which object types trigger the webhook
- Payload: JSON with object data
- Headers: custom headers for authentication to the receiver
- SSL verification: configurable

**Use cases:**
- Trigger Ansible job when new device added to NetBox
- Create ServiceNow CI when device status changes
- Notify Slack channel when IP assignment changes
- Trigger Terraform run when prefix is allocated

## Plugin Architecture

### Plugin Ecosystem

NetBox supports community plugins that extend the data model and functionality:

**Popular plugins:**
- `netbox-bgp`: BGP session modeling (peers, communities, prefix lists)
- `netbox-dns`: DNS zone and record management
- `netbox-routing`: Routing table modeling (static routes, OSPF, BGP routes)
- `netbox-topology-views`: Visual network topology diagrams generated from cable data
- `netbox-inventory`: Enhanced inventory management and reporting
- `netbox-config-diff`: Configuration diff and compliance checking

### Custom Fields

Extend any NetBox model with organization-specific data:

**Field types:** text, integer, boolean, date, URL, JSON, selection, multi-select, object (foreign key)

**Examples:**
- `ospf_area` (integer) on Device: OSPF area the device participates in
- `bgp_community` (text) on Prefix: BGP community tag for the prefix
- `deployment_tier` (selection: gold/silver/bronze) on Device: SLA tier
- `automation_managed` (boolean) on Device: whether Ansible/Terraform manages the device
- `change_window` (selection: MW1/MW2/MW3) on Site: maintenance window schedule

### Custom Validators

Python-based rules that run on object save:
- Enforce naming conventions (device names must match `^[a-z]+-[a-z]+-\d{2}$`)
- Require fields (all active devices must have a primary IP)
- Cross-model validation (prefix must have a VLAN association if role is "user")

### Config Contexts

JSON data blobs attached to devices, roles, sites, or platforms:
- Used to store automation variables (NTP servers, syslog servers, SNMP community per site)
- Hierarchical: site config context + role config context + device config context merged
- Exposed via Ansible inventory plugin (`config_context: true`)
- Enables NetBox to store device-specific variables for automation

```json
// Config context on site "NYC-DC1"
{
  "ntp_servers": ["10.0.0.100", "10.0.0.101"],
  "syslog_servers": ["10.0.0.200"],
  "dns_servers": ["10.0.0.50", "10.0.0.51"],
  "snmp_community": "public_nyc"
}
```

In Ansible:
```yaml
# Available as hostvars when config_context: true in inventory plugin
- name: Configure NTP
  cisco.ios.ios_ntp_global:
    config:
      servers: "{{ ntp_servers }}"
```
