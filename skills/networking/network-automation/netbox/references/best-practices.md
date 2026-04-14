# NetBox Best Practices Reference

## IPAM Design

### Prefix Hierarchy Strategy

Design prefixes in a hierarchy that reflects your IP allocation model:

**Level 1: Aggregates (RIR allocations)**
```
10.0.0.0/8      - RFC 1918 Private (Container)
172.16.0.0/12   - RFC 1918 Private (Container)
192.168.0.0/16  - RFC 1918 Private (Container)
203.0.113.0/24  - Public allocation from ISP (Active)
```

**Level 2: Site allocations**
```
10.0.0.0/8 (Container)
  ├── 10.1.0.0/16 - NYC Data Center (Container)
  ├── 10.2.0.0/16 - LAX Office (Container)
  ├── 10.3.0.0/16 - LDN Office (Container)
  └── 10.100.0.0/16 - Infrastructure (Loopbacks, P2P) (Container)
```

**Level 3: Function allocations**
```
10.1.0.0/16 (NYC, Container)
  ├── 10.1.0.0/24 - Management VLAN (Active, Role: Management)
  ├── 10.1.1.0/24 - Infrastructure P2P links (Active, Role: Infrastructure)
  ├── 10.1.10.0/24 - Users VLAN 10 (Active, Role: User)
  ├── 10.1.20.0/24 - Voice VLAN 20 (Active, Role: Voice)
  ├── 10.1.100.0/24 - Servers VLAN 100 (Active, Role: Server)
  └── 10.1.200.0/24 - Guest WiFi (Active, Role: Guest)
```

### VRF Design
- Create VRFs to match your network's routing domains
- Assign prefixes to VRFs consistently
- Use "Global" (null VRF) only for prefixes that are truly global (e.g., public IP space)
- Document VRF route targets and RD in VRF description or custom fields

### VLAN Group Design
- Create VLAN Groups per site (most common)
- VLAN IDs are unique within a VLAN Group
- Associate VLANs with prefixes to document subnet-to-VLAN mapping
- Use consistent VLAN ID scheme across sites when possible (VLAN 10 = Management everywhere)

### IP Address Assignment Best Practices
- Always set `primary_ip4` on devices used for management (required for Ansible inventory)
- Use IP roles to distinguish primary, secondary, VIP, VRRP addresses
- Assign IPs to specific interfaces (not just devices) for accurate documentation
- Use "available IP" API endpoint for automated allocation (prevents conflicts)
- Reserve IPs for infrastructure services (DNS, NTP, syslog) with "reserved" status

## Naming Conventions

### Device Naming
Establish a consistent naming convention and enforce via custom validators:

**Pattern:** `{function}-{location}-{number}`
- `core-rtr-nyc-01` -- Core router in NYC, unit 01
- `dist-sw-lax-03` -- Distribution switch in LAX, unit 03
- `fw-dmz-nyc-01` -- DMZ firewall in NYC, unit 01
- `ap-fl3-nyc-east` -- Access point, floor 3, NYC, east wing

**Validation rule (custom validator):**
```python
# Enforce device naming convention
import re
if not re.match(r'^[a-z]+-[a-z]+-[a-z]{3}-\d{2}$', instance.name):
    raise ValidationError({
        'name': 'Device name must follow pattern: function-role-site-number'
    })
```

### Site Naming
- Use consistent codes: `NYC-DC1`, `LAX-OFFICE`, `LDN-HQ`
- Match physical address or common organizational names
- Keep codes short (3-6 characters) for use in device names

### Interface Naming
- Use vendor-standard names: `GigabitEthernet0/1` (IOS), `Ethernet1/1` (NX-OS), `xe-0/0/0` (Junos)
- Do not abbreviate inconsistently (Gi vs GigabitEthernet)
- Match what the device actually reports in `show interfaces`

## Custom Fields Design

### Planning Custom Fields
Before creating custom fields, consider:
1. Is this data already modeled in NetBox natively? (Check built-in fields first)
2. Will this field be used by automation? (If yes, standardize the field type and values)
3. Who owns the data? (Define responsible team for maintaining accuracy)
4. How will the field be populated? (Manual, API, automation script)

### Recommended Custom Fields for Network Automation

| Field Name | Type | Applied To | Purpose |
|---|---|---|---|
| `automation_managed` | Boolean | Device | Is this device managed by automation? |
| `ansible_group` | Text | Device | Additional Ansible group membership |
| `ospf_area` | Integer | Device | OSPF area the device participates in |
| `bgp_asn` | Integer | Device | Device's BGP AS number |
| `deployment_tier` | Selection | Device | SLA tier (gold/silver/bronze) |
| `change_window` | Selection | Site | Maintenance window (MW1/MW2/MW3) |
| `circuit_id` | Text | Interface | WAN circuit ID for interface |
| `last_backup` | Date | Device | Last configuration backup date |

### Avoiding Custom Field Sprawl
- Review custom fields quarterly; delete unused fields
- Prefer config contexts (JSON) over many individual custom fields for automation variables
- Document each custom field's purpose, owner, and expected values
- Use selection type (dropdown) instead of free text when values are constrained

## Integration Patterns

### NetBox as Ansible Inventory Source

**inventory/netbox.yml:**
```yaml
plugin: netbox.netbox.nb_inventory
api_endpoint: https://netbox.example.com
token: "{{ lookup('env', 'NETBOX_TOKEN') }}"
config_context: true
group_by:
  - device_roles       # Groups: router, switch, firewall
  - sites              # Groups: NYC-DC1, LAX-OFFICE
  - platforms          # Groups: cisco_ios, arista_eos
  - regions            # Groups: Americas, EMEA
query_filters:
  - status: active
  - has_primary_ip: true
compose:
  ansible_host: primary_ip4.address | ansible.utils.ipaddr('address')
  ansible_network_os: >-
    {%- if platform.slug == 'ios-xe' -%}cisco.ios.ios
    {%- elif platform.slug == 'nxos' -%}cisco.nxos.nxos
    {%- elif platform.slug == 'eos' -%}arista.eos.eos
    {%- elif platform.slug == 'junos' -%}junipernetworks.junos.junos
    {%- endif -%}
```

**Key points:**
- `config_context: true` exposes NetBox config contexts as host variables
- `compose` maps NetBox fields to Ansible variables
- `group_by` creates Ansible groups from NetBox attributes
- Platform slug maps to `ansible_network_os` for connection plugin selection

### NetBox as Terraform Data Source

```hcl
data "http" "netbox_prefixes" {
  url = "${var.netbox_url}/api/ipam/prefixes/?site=NYC&role=server"
  request_headers = {
    Authorization = "Token ${var.netbox_token}"
  }
}

locals {
  prefixes = jsondecode(data.http.netbox_prefixes.response_body).results
  prefix_map = { for p in local.prefixes : p.prefix => p }
}

# Create ACI bridge domains from NetBox prefix data
resource "aci_bridge_domain" "server_bds" {
  for_each  = local.prefix_map
  tenant_dn = aci_tenant.prod.id
  name      = "${replace(each.key, "/", "_")}_BD"
}
```

### NetBox Reconciliation Script

Periodically compare NetBox data against actual device state:

```python
import pynetbox
from netmiko import ConnectHandler

nb = pynetbox.api("https://netbox.example.com", token="token")

# Get devices from NetBox
devices = nb.dcim.devices.filter(site="nyc", status="active", role="switch")

for device in devices:
    # Connect to device
    conn = ConnectHandler(
        device_type="cisco_ios",
        host=str(device.primary_ip4).split("/")[0],
        username="admin",
        password="password"
    )

    # Get actual VLANs from device
    output = conn.send_command("show vlan brief", use_textfsm=True)

    # Compare against NetBox VLANs for this site
    nb_vlans = nb.ipam.vlans.filter(site=device.site.slug)

    # Report discrepancies
    for actual_vlan in output:
        if not any(v.vid == int(actual_vlan["vlan_id"]) for v in nb_vlans):
            print(f"DRIFT: VLAN {actual_vlan['vlan_id']} on {device.name} not in NetBox")
```

### Webhook-Driven Automation

Trigger automation when NetBox data changes:

```python
# Flask webhook receiver
from flask import Flask, request
import subprocess

app = Flask(__name__)

@app.route('/webhook/device-created', methods=['POST'])
def device_created():
    data = request.json
    device_name = data['data']['name']

    # Trigger Ansible playbook to provision new device
    subprocess.run([
        'ansible-playbook',
        'playbooks/provision_device.yml',
        '--limit', device_name,
        '-i', 'inventory/netbox.yml'
    ])

    return {'status': 'ok'}, 200
```

## Data Population Strategies

### Initial Population

**Phase 1: Sites and infrastructure**
- Create regions, site groups, sites, locations
- Import from existing CMDB or spreadsheet via API
- Validate site data with physical facilities team

**Phase 2: Device types**
- Import from community device type library (github.com/netbox-community/devicetype-library)
- Create custom device types for non-standard equipment
- Validate interface counts and types match actual hardware

**Phase 3: Devices and racks**
- Bulk create devices via API with site, role, device type
- Assign rack positions for data center equipment
- Set platform for each device (maps to ansible_network_os)

**Phase 4: IPAM**
- Create VRFs and VLAN groups
- Import prefix hierarchy (aggregates, containers, active prefixes)
- Import VLAN definitions per site
- Associate VLANs with prefixes

**Phase 5: Interfaces and IPs**
- Import interface data from device discovery (SNMP, SSH, API)
- Assign IP addresses to interfaces
- Set primary IPs on devices
- Create cables between interfaces (from physical documentation or LLDP/CDP discovery)

### Ongoing Maintenance

**Automated updates:**
- Scheduled scripts that query devices and update NetBox (interface status, IP assignments)
- Webhook-triggered updates when automation provisions new resources
- CI/CD pipeline updates NetBox after successful deployments

**Manual processes:**
- New device procurement -> add to NetBox before rack and stack
- Decommissioning -> update device status to "decommissioning" -> remove after physical removal
- IP allocation requests -> use NetBox "available IP" API

## Data Quality

### Quality Metrics
Track and report on data quality:
- % of active devices with primary IP assigned
- % of active interfaces with cable connections documented
- % of active prefixes with VLAN associations
- % of devices with accurate platform assignment
- % of rack positions documented

### Quality Enforcement
- Custom validators prevent saving objects with missing required data
- Periodic audit scripts report on data quality metrics
- Ownership model: each data domain has a responsible team
- Link NetBox updates to change management process (device changes require NetBox update)

### Data Freshness
- Display "last updated" timestamps on dashboards
- Alert when devices have not been queried/updated in 30+ days
- Reconciliation scripts detect drift between NetBox and reality
- Decommission stale devices (status: offline for 90+ days with no change ticket)
