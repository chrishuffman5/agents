# Arista EOS CLI and Automation Reference

## CLI Overview

EOS uses a Cisco IOS-style CLI with mode-based configuration. All configuration is hierarchical and idempotent — applying the same config twice is safe.

### CLI Modes

| Mode | Prompt | Purpose |
|---|---|---|
| User EXEC | `switch>` | Read-only, limited show commands |
| Privileged EXEC | `switch#` | Full show commands, copy, reload |
| Global Config | `switch(config)#` | System-wide configuration |
| Interface Config | `switch(config-if-Et1)#` | Per-interface configuration |
| Router Config | `switch(config-router-bgp-65001)#` | Routing protocol configuration |
| VLAN Config | `switch(config-vlan-100)#` | VLAN database configuration |
| MLAG Config | `switch(config-mlag)#` | MLAG domain configuration |

### Entering/Exiting Modes

```
switch> enable                          # Enter privileged EXEC
switch# configure terminal              # Enter global config
switch(config)# interface Ethernet1    # Enter interface config
switch(config-if-Et1)# exit            # Back one level
switch(config)# end                    # Back to privileged EXEC
switch# write memory                   # Save config (= copy running startup)
```

---

## Core Show Commands

### Interface Commands

```
show interfaces                         # All interfaces, counters, errors
show interfaces Ethernet1              # Single interface detail
show interfaces status                  # Summary table (speed, duplex, link)
show interfaces counters               # Tx/Rx packet/byte/error counts
show interfaces counters rates         # Per-interface bandwidth utilization
show ip interface brief                # IP address + link state summary
show lldp neighbors                    # LLDP neighbor discovery
show lldp neighbors detail             # Full LLDP neighbor info (chassis ID, port, caps)
show port-channel summary              # LAG summary (LACP state, member ports)
show port-channel detail               # Detailed LACP negotiation state
```

### Routing Commands

```
show ip route                          # Full IPv4 routing table
show ip route bgp                      # BGP-learned routes only
show ip route ospf                     # OSPF-learned routes only
show ip route 192.0.2.0/24            # Specific prefix lookup
show ip route summary                  # Route count per protocol
show ip route vrf TENANT               # Routes in a specific VRF
show ipv6 route                        # IPv6 routing table
show ip arp                            # ARP table
show ip arp vrf TENANT                 # VRF-specific ARP table
show ip bgp summary                    # BGP peer summary (state, prefixes)
show bgp summary                       # All address-family BGP summary
show bgp neighbors 10.0.0.1           # Detailed BGP neighbor info
show bgp neighbors 10.0.0.1 advertised-routes   # Routes sent to peer
show bgp neighbors 10.0.0.1 received-routes     # Routes received from peer
show ip ospf neighbor                  # OSPF neighbor table
show ip ospf database                  # OSPF LSDB
```

### VXLAN and EVPN Commands

```
show vxlan config-sanity               # VXLAN config consistency check
show vxlan config-sanity detail        # Detailed VXLAN sanity (includes MLAG peer comparison)
show interfaces Vxlan1                 # VXLAN interface state and counters
show vxlan address-table               # VTEP MAC/IP table (local and remote)
show vxlan address-table evpn          # EVPN-learned remote MAC entries
show vxlan flood vtep                  # Flood list (head-end replication VTEPs)
show vxlan vni                         # VNI-to-VLAN mapping table
show bgp evpn summary                  # BGP EVPN peer summary
show bgp evpn                          # Full EVPN BGP table
show bgp evpn route-type mac-ip        # Type-2 MAC/IP advertisement routes
show bgp evpn route-type imet          # Type-3 Inclusive Multicast routes
show bgp evpn route-type ip-prefix     # Type-5 IP prefix routes
show bgp evpn route-type ethernet-segment  # Type-4 ESI routes
show l2rib output mac vlan 100         # L2 RIB MAC entries for VLAN
show arp suppression-cache             # EVPN ARP suppression cache
```

### MLAG Commands

```
show mlag                              # MLAG domain state (active/inactive, peer health)
show mlag detail                       # Full MLAG configuration and state
show mlag interfaces                   # All MLAG interface IDs and port-channels
show mlag config-sanity                # MLAG configuration consistency check
show mlag peers                        # Peer-link state and keepalive status
show port-channel summary              # LAG member state
```

### Security and ACL Commands

```
show ip access-lists                   # All IPv4 ACLs
show ip access-lists ACL_NAME         # Specific ACL with hit counters
show mac address-table                 # L2 MAC table
show mac address-table dynamic        # Dynamically learned MACs only
show mac security                      # MACsec session state
show aaa                               # AAA configuration summary
show tacacs                            # TACACS+ server state
show radius                            # RADIUS server state
show sflow                             # sFlow configuration and statistics
```

### System Commands

```
show version                           # EOS version, serial number, model, uptime
show hostname                          # Hostname and FQDN
show clock                             # System clock
show logging                           # Syslog buffer
show environment all                   # Temperature, fan, power (chassis)
show running-config                    # Active running configuration
show startup-config                    # Startup (saved) configuration
show diff running-config startup-config  # Unsaved changes
show processes top                     # CPU/memory per process (top-like)
show system resources                  # CPU, memory, disk summary
show management api http-commands      # eAPI service status
show management api gnmi               # gNMI server status
```

---

## eAPI — Programmatic Interface

### Enable eAPI

```
management api http-commands
   protocol https
   no shutdown
   !
   vrf management
      no shutdown
```

### curl JSON-RPC Examples

**Single command:**
```bash
curl -s -k -u admin:password \
  -H "Content-Type: application/json" \
  -X POST https://192.0.2.1/command-api \
  -d '{"jsonrpc":"2.0","method":"runCmds","params":{"version":1,"cmds":["show version"],"format":"json"},"id":"1"}'
```

**Multiple commands:**
```bash
curl -s -k -u admin:password \
  -H "Content-Type: application/json" \
  -X POST https://192.0.2.1/command-api \
  -d '{
    "jsonrpc": "2.0",
    "method": "runCmds",
    "params": {
      "version": 1,
      "cmds": [
        "show interfaces status",
        "show ip bgp summary",
        "show bgp evpn summary"
      ],
      "format": "json"
    },
    "id": "1"
  }'
```

**Configuration change via eAPI:**
```bash
curl -s -k -u admin:password \
  -H "Content-Type: application/json" \
  -X POST https://192.0.2.1/command-api \
  -d '{
    "jsonrpc": "2.0",
    "method": "runCmds",
    "params": {
      "version": 1,
      "cmds": [
        "enable",
        "configure",
        "interface Ethernet1",
        "description Uplink-to-Spine1",
        "no shutdown"
      ],
      "format": "json"
    },
    "id": "1"
  }'
```

**Text (non-JSON) output:**
```bash
curl -s -k -u admin:password \
  -H "Content-Type: application/json" \
  -X POST https://192.0.2.1/command-api \
  -d '{"jsonrpc":"2.0","method":"runCmds","params":{"version":1,"cmds":["show running-config"],"format":"text"},"id":"1"}'
```

### pyeapi Library

**Installation:**
```bash
pip install pyeapi
```

**~/.eapi.conf (connection profile):**
```ini
[connection:leaf1]
host: 192.0.2.1
username: admin
password: mypassword
transport: https
```

**Basic usage:**
```python
import pyeapi

# Direct connection
node = pyeapi.connect(
    host='192.0.2.1',
    username='admin',
    password='password',
    transport='https',
    return_node=True
)

# Run show commands
output = node.run_commands(['show version', 'show bgp evpn summary'])
version = output[0]['version']
bgp_peers = output[1]['vrfs']['default']['peers']

# Configuration
node.run_commands([
    'enable',
    'configure',
    'hostname leaf1-new',
    'end'
])

# Using config file profile
node = pyeapi.connect_to('leaf1')
node.run_commands(['show version'])
```

---

## Ansible — arista.eos Collection

### Installation

```bash
ansible-galaxy collection install arista.eos
```

### Inventory Setup

```yaml
# inventory/hosts.yaml
all:
  children:
    leafs:
      hosts:
        leaf1:
          ansible_host: 192.0.2.1
          ansible_user: admin
          ansible_password: "{{ vault_password }}"
          ansible_connection: network_cli
          ansible_network_os: arista.eos.eos
          ansible_become: yes
          ansible_become_method: enable
```

### Key Modules

| Module | Purpose |
|---|---|
| `arista.eos.eos_command` | Run arbitrary show/exec commands |
| `arista.eos.eos_config` | Push configuration blocks |
| `arista.eos.eos_facts` | Gather device facts |
| `arista.eos.eos_vlans` | Manage VLANs |
| `arista.eos.eos_interfaces` | Manage interface configuration |
| `arista.eos.eos_l2_interfaces` | L2 interface (access/trunk) |
| `arista.eos.eos_l3_interfaces` | L3 interface (IP addressing) |
| `arista.eos.eos_bgp_global` | BGP global configuration |
| `arista.eos.eos_bgp_address_family` | BGP address family config |
| `arista.eos.eos_prefix_lists` | Prefix list management |
| `arista.eos.eos_route_maps` | Route map management |
| `arista.eos.eos_acls` | ACL management |
| `arista.eos.eos_banner` | Login/MOTD banner |
| `arista.eos.eos_ntp_global` | NTP configuration |
| `arista.eos.eos_hostname` | Hostname management |
| `arista.eos.eapi` | Direct eAPI calls |

### Playbook Examples

**Gather facts:**
```yaml
- name: Gather EOS facts
  hosts: leafs
  tasks:
    - arista.eos.eos_facts:
        gather_subset: all
    - debug:
        var: ansible_net_version
```

**Push interface configuration:**
```yaml
- name: Configure uplink interfaces
  hosts: leafs
  tasks:
    - arista.eos.eos_l3_interfaces:
        config:
          - name: Ethernet1
            ipv4:
              - address: 10.0.0.1/31
        state: merged
```

**Run show command and register output:**
```yaml
- name: Verify BGP EVPN peers
  hosts: leafs
  tasks:
    - arista.eos.eos_command:
        commands:
          - show bgp evpn summary
      register: bgp_output
    - debug:
        var: bgp_output.stdout_lines
```

---

## Terraform — Arista EOS Provider

The `arista/eos` Terraform provider manages EOS configuration as infrastructure code.

### Provider Setup

```hcl
terraform {
  required_providers {
    eos = {
      source  = "arista/eos"
      version = "~> 1.0"
    }
  }
}

provider "eos" {
  address  = "192.0.2.1"
  username = "admin"
  password = var.eos_password
}
```

### Resource Examples

```hcl
resource "eos_interface" "uplink" {
  name        = "Ethernet1"
  description = "Uplink to Spine1"
  shutdown    = false
}

resource "eos_ip_interface" "uplink_ip" {
  name    = "Ethernet1"
  address = "10.0.0.1/31"
}
```

---

## CloudVision REST API

CVP exposes a Resource API over gRPC (HTTP/2). Authentication requires a service account token.

### Token-Based Authentication

```bash
# Set token in header
curl -H "Authorization: Bearer <token>" \
  https://www.cv-staging.corp.arista.io/api/resources/inventory/v1/Device
```

### Key API Endpoints (Resource API)

| Endpoint | Purpose |
|---|---|
| `/api/resources/inventory/v1/Device` | Device inventory |
| `/api/resources/configlet/v1/Configlet` | Configlet management |
| `/api/resources/changecontrol/v1/ChangeControl` | Change control lifecycle |
| `/api/resources/tag/v2/Tag` | Device/interface tagging |
| `/api/resources/workspace/v1/Workspace` | Workspace management |
| `/api/resources/studio/v1/Studio` | Studios management |

### ansible-cvp Collection

```bash
ansible-galaxy collection install arista.cvp
```

Key modules:
- `arista.cvp.cv_device_v3` — Device management
- `arista.cvp.cv_configlet_v3` — Configlet CRUD
- `arista.cvp.cv_container_v3` — Container hierarchy
- `arista.cvp.cv_change_control_v3` — Change control creation and approval

---

## CloudVision Studios

Studios provide intent-based provisioning. Instead of per-device config, the operator defines fabric intent (topology, ASNs, IP pools) and Studios generates EOS configurations.

### Key Studios

| Studio | Use Case |
|---|---|
| **L3 Leaf-Spine** | Automated spine-leaf EVPN fabric provisioning |
| **Campus** | Campus L2/L3 access provisioning |
| **Static Configuration Studio** | Used by AVD cv_deploy for IaC; pushes rendered configs from AVD |
| **Inventory & Topology** | Device onboarding and topology discovery |

### Studios Workflow

1. Navigate to CloudVision Studios
2. Select or create a Studio (e.g., L3 Leaf-Spine)
3. Define inputs: topology, ASNs, VRFs, VLAN pools
4. Studios generates per-device configuration
5. Submit to Workspace → build → create Change Control
6. Approve and execute Change Control

### Static Configuration Studio (AVD Integration)

The `arista.avd.cv_deploy` Ansible role uses this Studio to push AVD-rendered EOS configs to CVaaS:

```yaml
# AVD group_vars
cv_server: www.cv-staging.corp.arista.io
cv_token: "{{ vault_cv_token }}"
cv_submit_workspace: true
cv_run_change_control: false   # Leave in pending approval state
```

---

## NAPALM — Network Automation and Programmability Abstraction Layer

NAPALM provides a multi-vendor abstraction layer. The Arista EOS driver uses eAPI.

```python
from napalm import get_network_driver

driver = get_network_driver('eos')
device = driver(
    hostname='192.0.2.1',
    username='admin',
    password='password',
    optional_args={'transport': 'https'}
)

device.open()

# Get facts
facts = device.get_facts()
print(facts['hostname'], facts['os_version'])

# Get interfaces
interfaces = device.get_interfaces()

# Get BGP neighbors
bgp = device.get_bgp_neighbors()

# Get route table
routes = device.get_route_to('10.0.0.0/8')

# Load and commit config
device.load_merge_candidate(config="interface Ethernet1\n description New Description\n")
diff = device.compare_config()
print(diff)
device.commit_config()

device.close()
```

---

## AVD — Arista Validated Designs

AVD is an Ansible collection (`arista.avd`) that provides opinionated, structured automation for Arista data center fabrics.

### Installation

```bash
ansible-galaxy collection install arista.avd
pip install pyavd  # Python library component
```

### AVD Workflow

1. **Define fabric intent** in YAML group_vars (topology, ASNs, VRFs, VLANs, peers)
2. **Run `eos_designs` role** — generates structured device-specific data model
3. **Run `eos_cli_config_gen` role** — renders full EOS CLI configurations from data model
4. **Run `eos_config_deploy_eapi` or `cv_deploy`** — pushes configs to devices or to CVaaS

### Example AVD fabric_vars.yaml

```yaml
# DC fabric topology
fabric_name: DC1-FABRIC

# Spine switches
spine:
  nodes:
    DC1-SPINE1:
      id: 1
      bgp_as: 65100
      loopback_ipv4_address: 10.255.0.1/32
    DC1-SPINE2:
      id: 2
      bgp_as: 65100
      loopback_ipv4_address: 10.255.0.2/32

# Leaf switches
l3leaf:
  defaults:
    bgp_as_range: "65101-65199"
    loopback_ipv4_pool: 10.255.1.0/24
    vtep_loopback_ipv4_pool: 10.255.2.0/24
    mlag_peer_ipv4_pool: 10.255.252.0/24
    spanning_tree_mode: mstp
    uplink_switches: [DC1-SPINE1, DC1-SPINE2]
    mtu: 9214
    bfd: true
  nodes:
    DC1-LEAF1A:
      id: 1
      bgp_as: 65101
      mgmt_ip: 192.168.0.11/24
    DC1-LEAF1B:
      id: 2
      bgp_as: 65101
      mgmt_ip: 192.168.0.12/24
```

### AVD Roles Summary

| Role | Function |
|---|---|
| `eos_designs` | Convert fabric intent YAML to structured device data model |
| `eos_cli_config_gen` | Render Jinja2 templates into EOS CLI configurations |
| `eos_config_deploy_eapi` | Deploy rendered configs directly via eAPI |
| `cv_deploy` | Deploy configs through CVaaS Static Configuration Studio |
| `eos_validate_state` | Post-deployment state validation (BGP, MLAG, VXLAN health) |
| `eos_snapshot` | Capture device state snapshots for before/after comparison |

---

## Sources

- [Ansible arista.eos collection documentation](https://docs.ansible.com/projects/ansible/latest/collections/arista/eos/index.html)
- [GitHub - ansible-collections/arista.eos](https://github.com/ansible-collections/arista.eos)
- [GitHub - arista-eosplus/pyeapi](https://github.com/arista-eosplus/pyeapi)
- [GitHub - aristanetworks/ansible-cvp](https://github.com/aristanetworks/ansible-cvp)
- [Arista AVD cv_deploy Role](https://avd.arista.com/4.9/roles/cv_deploy/index.html)
- [GitHub - arista-netdevops-community/arista_eos_automation_with_eAPI](https://github.com/arista-netdevops-community/arista_eos_automation_with_eAPI)
- [gNMIc Examples - Open Management](https://aristanetworks.github.io/openmgmt/examples/gnmi-clients/gnmic/)
- [CVP Configlet, Change Control, and Rollback - ATD Lab Guides](https://labguides.testdrive.arista.com/2025.1/cloudvision_portal/cvp_configlet_cc/)
