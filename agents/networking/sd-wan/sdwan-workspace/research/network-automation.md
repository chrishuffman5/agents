# Network Automation Tools — Deep Dive Reference

> Last updated: April 2026 | Ansible 11.x | Terraform 1.10.x | NetBox v4.5

---

## Part 1: Ansible Network Automation

---

## 1. Ansible Network Architecture

Ansible network automation operates via SSH (CLI) or API connections to network devices — no agent is installed on the devices. Network automation uses specific connection plugins and module collections maintained by the community and vendors.

### 1.1 Connection Plugins

| Plugin | Description | Transports |
|---|---|---|
| **network_cli** | CLI over SSH; sends commands, parses output | SSH |
| **netconf** | NETCONF XML over SSH; structured data | SSH (port 830) |
| **httpapi** | Device REST/HTTP APIs; structured JSON/XML | HTTP/HTTPS |

```yaml
# Host inventory with connection type
[cisco_ios]
ios-rtr-01 ansible_host=10.0.0.1

[cisco_ios:vars]
ansible_network_os=cisco.ios.ios
ansible_connection=network_cli
ansible_user=netadmin
ansible_password="{{ vault_password }}"
ansible_become=yes
ansible_become_method=enable
```

### 1.2 Collection Structure

Ansible network automation is delivered via Galaxy collections:

| Collection | Vendor/Platform | Key Modules |
|---|---|---|
| `ansible.netcommon` | Platform-agnostic primitives | `net_ping`, `net_get`, `net_put`, `cli_command`, `cli_config`, `netconf_config`, `netconf_get` |
| `cisco.ios` | Cisco IOS / IOS-XE | `ios_command`, `ios_config`, `ios_facts`, resource modules |
| `cisco.nxos` | Cisco NX-OS | `nxos_command`, `nxos_config`, `nxos_facts`, resource modules |
| `cisco.iosxr` | Cisco IOS-XR | `iosxr_command`, `iosxr_config`, netconf-based |
| `arista.eos` | Arista EOS | `eos_command`, `eos_config`, eAPI (httpapi) or network_cli |
| `junipernetworks.junos` | Juniper Junos | NETCONF-based; `junos_command`, `junos_config` |
| `cisco.asa` | Cisco ASA | `asa_command`, `asa_config` |
| `cisco.nso` | Cisco NSO | NSO API integration |
| `paloaltonetworks.panos` | Palo Alto PAN-OS | `panos_*` resource modules |

---

## 2. ansible.netcommon

`ansible.netcommon` provides platform-agnostic primitives used by all vendor collections.

### 2.1 Key Modules

**`cli_command`** — Run arbitrary CLI commands and return output:
```yaml
- name: Show interfaces
  ansible.netcommon.cli_command:
    command: show interfaces
  register: int_output

- name: Debug output
  debug:
    msg: "{{ int_output.stdout_lines }}"
```

**`cli_config`** — Apply configuration via CLI (platform-agnostic):
```yaml
- name: Configure banner
  ansible.netcommon.cli_config:
    config: "banner motd ^ Authorized access only ^"
```

**`netconf_config`** — Send NETCONF edit-config RPC:
```yaml
- name: Apply NETCONF config
  ansible.netcommon.netconf_config:
    content: "{{ lookup('template', 'interface_config.xml.j2') }}"
    target: candidate
    commit: true
```

**`netconf_get`** — Retrieve NETCONF data:
```yaml
- name: Get interface state
  ansible.netcommon.netconf_get:
    filter: |
      <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
        <interface/>
      </interfaces>
  register: netconf_data
```

---

## 3. cisco.ios Collection

### 3.1 Network Resource Modules

Resource modules manage specific configuration resources in an idempotent, declarative way. They use `state` parameter to control behavior.

| State | Behavior |
|---|---|
| `merged` | Merge provided config into existing (additive) |
| `replaced` | Replace existing config for specified objects |
| `overridden` | Replace entire resource config (removes anything not specified) |
| `deleted` | Remove specified configuration |
| `gathered` | Read running config into structured data (no changes) |
| `rendered` | Generate config text from provided data (no device connection) |
| `parsed` | Parse provided text into structured data (no device connection) |

**ios_vlans — VLAN Management:**
```yaml
- name: Configure VLANs
  cisco.ios.ios_vlans:
    config:
      - vlan_id: 10
        name: MGMT
        state: active
      - vlan_id: 20
        name: USER
        state: active
      - vlan_id: 30
        name: VOICE
        state: active
    state: merged

- name: Gather VLAN state
  cisco.ios.ios_vlans:
    state: gathered
  register: vlan_facts
```

**ios_interfaces — Interface Configuration:**
```yaml
- name: Configure interfaces
  cisco.ios.ios_interfaces:
    config:
      - name: GigabitEthernet0/1
        description: "Uplink to Core"
        enabled: true
        speed: "1000"
        duplex: full
      - name: GigabitEthernet0/2
        description: "User Access"
        enabled: true
    state: merged
```

**ios_ospfv2 — OSPF:**
```yaml
- name: Configure OSPF
  cisco.ios.ios_ospfv2:
    config:
      processes:
        - process_id: 1
          router_id: 10.0.0.1
          network:
            - address: 192.168.1.0
              wildcard_bits: 0.0.0.255
              area: 0
            - address: 10.0.0.0
              wildcard_bits: 0.0.255.255
              area: 0
    state: merged
```

**ios_bgp_global** configures BGP globally with `as_number`, `router_id`, and a `neighbors` list (each with `neighbor_address`, `remote_as`, description). Use `state: merged` to add peers without removing existing config.

### 3.2 ios_facts and Config Backup

`cisco.ios.ios_facts` with `gather_subset: [interfaces, routing, default]` returns structured data in `ansible_network_resources` and `ansible_facts`. Use to build dynamic inventory-driven playbooks.

Config backup via `cisco.ios.ios_config` with `backup: yes` and `backup_options` (filename template, dir_path) saves timestamped running configs locally or to a remote file share.

---

## 4. cisco.nxos Collection

NX-OS specific resource modules follow the same patterns as IOS:
- `nxos_vlans`, `nxos_interfaces`, `nxos_l2_interfaces`, `nxos_l3_interfaces`
- `nxos_ospfv2`, `nxos_bgp_global`, `nxos_prefix_lists`
- `nxos_vrf`, `nxos_vrf_interfaces`
- NX-OS supports both `network_cli` (SSH) and `httpapi` (NX-API) connections

---

## 5. arista.eos Collection

Arista EOS supports two connection methods:
- **`network_cli`**: SSH CLI (traditional)
- **`httpapi`**: Arista eAPI (REST/JSON); returns structured data natively; preferred for performance

```yaml
[arista]
eos-sw-01 ansible_host=10.0.1.1

[arista:vars]
ansible_network_os=arista.eos.eos
ansible_connection=httpapi
ansible_httpapi_use_ssl=true
ansible_httpapi_validate_certs=false
```

Key resource modules: `eos_interfaces`, `eos_vlans`, `eos_l2_interfaces`, `eos_l3_interfaces`, `eos_bgp_global`, `eos_ospfv2`, `eos_acls`

---

## 6. junipernetworks.junos Collection

Junos automation uses NETCONF exclusively (more reliable and structured than CLI scraping):

```yaml
[juniper]
junos-rtr-01 ansible_host=10.0.2.1

[juniper:vars]
ansible_network_os=junipernetworks.junos.junos
ansible_connection=netconf
```

Key modules: `junos_config` (load Junos set/XML config), `junos_command`, `junos_facts`, `junos_interfaces`, `junos_vlans`

---

## 7. Jinja2 Templates for Config Generation

Jinja2 is the standard templating engine for generating device configs from data models.

### 7.1 Interface Template Example

```jinja2
{# templates/ios_interface.j2 #}
{% for interface in interfaces %}
interface {{ interface.name }}
 description {{ interface.description | default('No description') }}
 {% if interface.ip is defined %}
 ip address {{ interface.ip }} {{ interface.mask }}
 {% endif %}
 {% if interface.access_vlan is defined %}
 switchport mode access
 switchport access vlan {{ interface.access_vlan }}
 {% else %}
 no switchport
 {% endif %}
 {% if interface.shutdown | default(false) %}
 shutdown
 {% else %}
 no shutdown
 {% endif %}
!
{% endfor %}
```

### 7.2 Using Templates in Playbooks

```yaml
- name: Generate and push interface config
  cisco.ios.ios_config:
    src: "{{ lookup('template', 'ios_interface.j2') }}"
  vars:
    interfaces:
      - name: GigabitEthernet0/1
        description: "Uplink"
        ip: 10.0.0.1
        mask: 255.255.255.0
```

---

## Part 2: Terraform Network Automation

---

## 8. Terraform for Network Infrastructure

Terraform (HashiCorp) manages network infrastructure as code using a declarative HCL (HashiCorp Configuration Language) syntax. The state file tracks real infrastructure vs. desired configuration.

### 8.1 Core Workflow

```
terraform init     → Download providers; initialize backend
terraform plan     → Show what changes will be made (diff against state)
terraform apply    → Apply the plan; update state
terraform destroy  → Remove all managed resources
```

### 8.2 State Management

- **Local state** (`terraform.tfstate`): Default; not suitable for teams
- **Remote state** (S3, Azure Blob, Terraform Cloud): Shared; locked during operations
- **State locking**: Prevents concurrent applies; implemented by backend (DynamoDB for S3, etc.)

---

## 9. Network Terraform Providers

### 9.1 CiscoDevNet/aci (Cisco ACI)

```hcl
provider "aci" {
  username = var.aci_username
  password = var.aci_password
  url      = "https://apic.example.com"
}

resource "aci_tenant" "prod" {
  name        = "PROD"
  description = "Production Tenant"
}

resource "aci_vrf" "prod_vrf" {
  tenant_dn   = aci_tenant.prod.id
  name        = "PROD_VRF"
}

resource "aci_bridge_domain" "app_bd" {
  tenant_dn   = aci_tenant.prod.id
  name        = "APP_BD"
  relation_fv_rs_ctx = aci_vrf.prod_vrf.id
}

resource "aci_application_profile" "app" {
  tenant_dn  = aci_tenant.prod.id
  name       = "APP_PROFILE"
}

resource "aci_application_epg" "web_epg" {
  application_profile_dn = aci_application_profile.app.id
  name                   = "WEB_EPG"
  relation_fv_rs_bd      = aci_bridge_domain.app_bd.id
}
```

### 9.2 cisco-open/meraki (Cisco Meraki)

```hcl
provider "meraki" {
  api_key = var.meraki_api_key
}

resource "meraki_networks_vlans" "office_vlans" {
  network_id   = var.network_id
  id           = 10
  name         = "CORP_USERS"
  subnet       = "192.168.10.0/24"
  appliance_ip = "192.168.10.1"
}
```

### 9.3 paloaltonetworks/panos (Palo Alto)

```hcl
provider "panos" {
  hostname = var.panos_hostname
  username = var.panos_username
  password = var.panos_password
}

resource "panos_address_object" "web_servers" {
  name  = "WEB_SERVERS"
  type  = "ip-netmask"
  value = "10.10.10.0/24"
}

resource "panos_security_policy" "allow_web" {
  rule {
    name                  = "ALLOW_WEB_OUT"
    source_zones          = ["trust"]
    destination_zones     = ["untrust"]
    applications          = ["web-browsing", "ssl"]
    services              = ["application-default"]
    source_addresses      = [panos_address_object.web_servers.name]
    destination_addresses = ["any"]
    action                = "allow"
  }
}
```

### 9.4 fortiosapi/fortios (FortiOS)

```hcl
provider "fortios" {
  hostname = var.fortigate_ip
  token    = var.fortigate_api_token
  insecure = false
}

resource "fortios_firewall_address" "internal_net" {
  name    = "INTERNAL_NET"
  type    = "ipmask"
  subnet  = "10.0.0.0 255.0.0.0"
  comment = "Internal networks"
}

resource "fortios_system_sdwan" "sdwan_config" {
  status = "enable"
}
```

### 9.5 F5Networks/bigip (F5 BIG-IP)

```hcl
provider "bigip" {
  address  = "https://192.168.1.1"
  username = "admin"
  password = var.bigip_password
}

resource "bigip_ltm_node" "app_node" {
  name    = "/Common/app-server-1"
  address = "192.168.10.11"
}

resource "bigip_ltm_pool" "app_pool" {
  name                = "/Common/APP_POOL"
  load_balancing_mode = "least-connections-member"
  monitors            = ["/Common/http"]
}

resource "bigip_ltm_pool_attachment" "app_member" {
  pool = bigip_ltm_pool.app_pool.name
  node = "/Common/app-server-1:80"
}
```

### 9.6 Network-Specific Patterns

- Use Terraform modules to encapsulate reusable network objects (VLAN, EPG, pool)
- Use `for_each` with a local map to create multiple network objects from a data structure
- Remote state enables cross-team references (networking team exports VPC IDs consumed by app team)
- `terraform plan` output should be reviewed in CI before `apply` in production pipelines

---

## Part 3: NetBox

---

## 10. NetBox v4.5 — Source of Truth

NetBox is an open-source IPAM (IP Address Management) + DCIM (Data Center Infrastructure Management) platform designed to model network infrastructure. In automation workflows, NetBox serves as the single source of truth (SSoT) for inventory and network data.

### 10.1 Core Data Model

**Sites and Topology:**
- Sites → Regions/Site Groups → Locations → Racks → Devices
- Tenant model: Tenants / Tenant Groups for multi-tenancy

**DCIM (Physical/Virtual Infrastructure):**
- **Devices**: Network devices (routers, switches, firewalls, servers)
- **Device Types**: Manufacturer + model template (defines interfaces, power ports)
- **Interfaces**: Physical/virtual interfaces on devices; link type, MAC, speed
- **Racks**: Physical rack inventory; device placement with U-position
- **Cables**: Physical cable connections between interfaces; supports patch panels
- **Power**: Power ports, power feeds, power panels

**IPAM:**
- **Prefixes**: IP blocks (10.0.0.0/8); organized by VRF, role, site
- **IP Addresses**: Specific IPs with status (active, reserved, deprecated) and interface assignment
- **VLANs**: VLAN IDs with name, site, group; status tracking
- **VRFs**: Virtual routing instances with assigned prefixes
- **ASNs**: BGP AS number tracking (linked to sites, providers)
- **FHRP Groups**: VRRP/HSRP/GLBP virtual IP tracking

**Circuits:**
- Circuit types, circuits (with provider), circuit terminations (linked to sites/devices)

### 10.2 NetBox v4.5 Highlights

- Requires Python 3.12, 3.13, or 3.14
- **Owner model**: Most objects can be assigned to an owner (user/group set) — enables object-level ownership tracking
- **Port Mapping model**: Bidirectional front-to-rear port mapping (replaces previous many-to-one limitation)
- **GraphQL cursor-based pagination** (v4.5.2): More efficient pagination for large datasets
- **GraphQL filtering**: Filter device components by site/location/rack directly in GraphQL queries
- **REST API prefix length**: Specify prefix length when using `/api/ipam/prefixes/<id>/available-ips/`
- Custom fields support on most models; custom validators

---

## 11. NetBox REST API

### 11.1 API Structure

Base URL: `https://netbox.example.com/api/`

Namespaces:
- `/api/dcim/` — devices, interfaces, racks, cables, sites
- `/api/ipam/` — prefixes, IP addresses, VLANs, VRFs
- `/api/circuits/` — providers, circuits
- `/api/tenancy/` — tenants, tenant groups
- `/api/extras/` — custom fields, tags, webhooks, scripts
- `/api/virtualization/` — VMs, clusters
- `/api/users/` — user management

### 11.2 Common REST Operations

Authentication: `Authorization: Token <token>` header on all requests.

Key patterns:
- `GET /api/dcim/devices/?site=NYC` — filter devices by site
- `GET /api/ipam/prefixes/15/available-ips/?prefix_length=30` — get next available IPs from a prefix (v4.5: specify prefix_length)
- `POST /api/dcim/devices/` with JSON body — create device
- `PATCH /api/ipam/ip-addresses/42/` — update IP address (e.g., assign to interface via `assigned_object_type` + `assigned_object_id`)

All list endpoints support `limit`/`offset` pagination; GraphQL supports cursor-based pagination (v4.5.2).

### 11.3 Python Integration (pynetbox)

`pynetbox` is the official Python client: `nb = pynetbox.api(url, token=token)`. Use `nb.dcim.devices.filter(site="nyc", status="active")` to query; `nb.ipam.ip_addresses.create(...)` to create; `nb.ipam.ip_addresses.update([...])` for bulk updates. All objects are Python objects with attribute access matching NetBox field names.

---

## 12. NetBox GraphQL API

NetBox provides a read-only GraphQL API (powered by Strawberry Django). Endpoint: `https://netbox.example.com/graphql/`

Key query patterns:
- `device_list(site_id: [1], status: "active")` — filter devices by site/status; request interfaces and IPs in same query
- `interface_list(device__rack_id: [5])` — filter components by rack (v4.5 feature); returns name/type/speed
- Cursor-based pagination introduced in v4.5.2 for efficient large result iteration

---

## 13. NetBox as Source of Truth for Ansible

The `netbox.netbox.nb_inventory` plugin generates Ansible inventory from NetBox:
```yaml
# inventory/netbox.yml
plugin: netbox.netbox.nb_inventory
api_endpoint: https://netbox.example.com
token: "{{ lookup('env', 'NETBOX_TOKEN') }}"
config_context: true
group_by: [device_roles, sites, platforms]
query_filters:
  - status: active
  - has_primary_ip: true
```

Run: `ansible-inventory -i inventory/netbox.yml --list`

In playbooks, query NetBox's REST API via `uri` module and use the structured JSON response as input to resource modules — e.g., transform `nb_interfaces.json.results` into `cisco.ios.ios_interfaces` config data via a custom filter plugin.

---

## 14. NetBox as Source of Truth for Terraform

Use the `http` data source to query NetBox REST API and feed the results into Terraform resources. The typical pattern uses `jsondecode` on the API response, builds a local map with `for` expressions, then drives resource creation with `for_each`. This lets NetBox be the authoritative registry while Terraform handles provisioning.

---

## 15. NetBox Custom Fields and Plugins

**Custom Fields:**
- Add organization-specific fields to any NetBox model
- Types: text, integer, boolean, select, multi-select, date, URL, JSON, object FK
- Used to store automation metadata (e.g., OSPF area, BGP community, deployment tier)

**Custom Validators:**
- Python-based validation rules on save events
- Enforce naming conventions, IP assignment rules, required fields

**Plugins (ecosystem examples):**
- `netbox-bgp`: BGP session and community modeling
- `netbox-dns`: DNS zone/record management
- `netbox-routing`: Routing table modeling (routes, next-hops)
- `netbox-topology-views`: Visual network topology diagrams

---

## References

- [Ansible Network Resource Modules Documentation](https://docs.ansible.com/projects/ansible/11/network/user_guide/network_resource_modules.html)
- [Ansible Network Connection Types (2026)](https://oneuptime.com/blog/post/2026-02-21-ansible-network-connection-types/view)
- [arista.eos GitHub Collection](https://github.com/ansible-collections/arista.eos)
- [EOS Platform Options — Ansible](https://docs.ansible.com/ansible/latest/network/user_guide/platform_eos.html)
- [Terraform F5 BIG-IP Provider](https://registry.terraform.io/providers/F5Networks/bigip/latest/docs)
- [Terraform CiscoDevNet/aci Provider](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs)
- [Infrastructure as Code for Networking (Terraform + Cisco) 2026](https://www.thenetworkdna.com/2026/03/infrastructure-as-code-for-networking.html)
- [NetBox v4.5 Release Notes](https://netboxlabs.com/docs/netbox/release-notes/version-4.5)
- [NetBox REST API Overview](https://netboxlabs.com/docs/v4.2/netbox/integrations/rest-api/)
- [NetBox GraphQL API](https://netboxlabs.com/docs/netbox/integrations/graphql-api/)
- [NetBox community/netbox DeepWiki](https://deepwiki.com/netbox-community/netbox)
