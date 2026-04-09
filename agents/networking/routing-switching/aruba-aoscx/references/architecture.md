# Aruba AOS-CX Architecture Reference

## Linux Foundation

AOS-CX runs on a hardened Linux kernel providing:

```
┌──────────────────────────────────────────────┐
│         AOS-CX CLI / REST API / NETCONF      │
├──────────────────────────────────────────────┤
│  OVSDB (configuration and state database)    │
├───────────┬──────────┬───────────────────────┤
│  Routing  │  NAE     │  System daemons       │
│  daemons  │  agents  │  (LLDP, LACP, STP)    │
├───────────┴──────────┴───────────────────────┤
│     Linux Kernel (hardened)                  │
├──────────────────────────────────────────────┤
│     ASICs (data plane forwarding)            │
└──────────────────────────────────────────────┘
```

- Each network function runs as isolated Linux process
- Process isolation: daemon crash does not bring down entire switch
- Containerized application support
- Native Python execution for on-box scripting
- Full Linux tooling available (tcpdump, ip, ss)

## OVSDB Configuration Database

### Schema

OVSDB is based on the Open vSwitch Database Management Protocol:
- All configuration stored in structured tables (Interface, VLAN, BGP_Router, etc.)
- Tables have defined columns with typed fields (string, integer, map, set, reference)
- Foreign key relationships between tables (e.g., Port references Interface)

### Transaction Model

- All configuration changes are transactional
- Partial writes are never committed -- atomic commit or full rollback
- CLI, REST API, and NETCONF all write to the same OVSDB tables
- Hardware is programmed from OVSDB state via subscriber daemons

### Configuration Persistence

- `write memory` persists OVSDB to flash
- No "running config" vs "startup config" -- OVSDB is always authoritative
- Checkpoint/rollback for configuration safety:
  ```
  checkpoint create pre-change
  checkpoint rollback pre-change
  ```

## REST API Architecture

### Versioned Endpoints

REST API versions align with AOS-CX software versions:
- v10.08, v10.09, ..., v10.15 -- each release adds new endpoints/fields
- Base URL: `https://<switch>/rest/v10.xx/`
- Swagger UI on-switch: `https://<switch>/rest/swagger-ui`

### Authentication

Cookie-based session authentication:
```
POST /rest/v10.08/login
{"username": "admin", "password": "password"}
Response: Set-Cookie: id=<session_token>
```

### Resource Hierarchy

```
/system
/system/interfaces/{id}
/system/interfaces/{id}/statistics
/system/vrfs/{vrf}/bgp_routers/{asn}
/system/vrfs/{vrf}/bgp_routers/{asn}/bgp_neighbors/{addr}
/system/vlans/{id}
```

URL encoding: interface `1/1/1` becomes `1%2F1%2F1` in URLs.

### Automation Integration

**Ansible (`hpe.aoscx` collection)**:
```yaml
- hosts: switches
  collections:
    - hpe.aoscx
  tasks:
    - name: Configure VLAN
      aoscx_vlan:
        vlan_id: 100
        name: Production
        state: present
```

**Terraform (`hpe/aoscx` provider)**:
```hcl
resource "aoscx_vlan" "production" {
  vlan_id = 100
  name    = "Production"
}
```

## Network Analytics Engine (NAE)

### Agent Architecture

```
┌─────────────────────────────────┐
│  NAE Agent (Python script)      │
│  ├── Manifest (name, params)    │
│  ├── Monitor (data sources)     │
│  ├── Rules (conditions)         │
│  └── Actions (alerting/CLI)     │
├─────────────────────────────────┤
│  NAE Sandbox (isolated runtime) │
├─────────────────────────────────┤
│  OVSDB / REST API telemetry     │
└─────────────────────────────────┘
```

### Agent Lifecycle

1. **Develop**: Python script using NAE framework APIs (`NAEAgent`, `Rule`, `Monitor`)
2. **Upload**: push script to switch via REST API or GUI
3. **Instantiate**: create agent instance with configurable parameters (thresholds, intervals)
4. **Monitor**: agent runs continuously, evaluating rules against live telemetry
5. **Alert/Act**: when conditions are met, execute actions (syslog, REST webhook, CLI command)

### NAE API Components

- **Monitor**: defines data source URI and polling period
- **Rule**: defines condition expression over monitor data
- **Action**: defines response when rule condition is true
  - `ActionSyslog()`: send syslog message
  - `ActionCLI()`: execute CLI command
  - `ActionShell()`: execute shell command
  - `ActionCustomReport()`: generate structured report

### Example: Interface Utilization Monitor

```python
Manifest = {
    'Name': 'interface_utilization_monitor',
    'Description': 'Alert when interface utilization exceeds threshold',
    'Version': '1.0',
    'Parameters': [
        {'Name': 'threshold', 'Type': 'integer', 'Default': 80}
    ]
}

class Agent(NAEAgent):
    def __init__(self):
        uri = '/rest/v10.08/system/interfaces/{}?attributes=statistics'
        m1 = self.monitor(uri, 'Interface TX utilization', period=30)
        self.rule = Rule('High utilization rule')
        self.rule.condition('percent(sum({m1})) >= {}', [m1],
                          params=[self.params['threshold']])
        self.rule.action(self.high_utilization_action)

    def high_utilization_action(self, event):
        ActionSyslog('Interface utilization exceeded threshold: {}'.format(event))
        ActionCLI('show interface {}'.format(event.interface))
```

## VSX Architecture

### Control Plane

```
┌───────────────┐    ISL (lag 99)    ┌───────────────┐
│  VSX Primary  │◄──────────────────►│  VSX Secondary │
│  (own routing │    keepalive       │  (own routing  │
│   table)      │◄──────────────────►│   table)       │
└───────┬───────┘    (mgmt VRF)      └───────┬───────┘
        │                                     │
    lag 10 ──── multi-chassis ──── lag 10
        │                                     │
        └──────────── Host ──────────────────┘
```

- Both switches have independent control planes
- L3 NOT shared: each switch maintains separate routing table, OSPF/BGP adjacencies
- L2 logically shared: multi-chassis LAGs span both switches
- ISL carries control sync, MAC sync, and data plane traffic for orphan ports
- Keepalive monitors peer health; configured on separate path (mgmt VRF recommended)

### VSX Synchronization

Objects synchronized via ISL:
- MAC address table
- ARP/ND table
- LACP state
- STP state (for multi-chassis LAGs)
- IGMP snooping state
- DHCP snooping bindings

Objects NOT synchronized:
- Routing tables (independent)
- Management sessions (independent)
- NAE agent state (independent)

### Split-Brain Prevention

- Keepalive link detects ISL failure
- If ISL fails and keepalive is up: secondary disables multi-chassis LAG ports
- If both ISL and keepalive fail: secondary assumes primary is dead, keeps ports up (potential split-brain)
- DAD (Dual Active Detection): additional detection via LLDP on downstream links

## EVPN-VXLAN Architecture

### Supported Platforms

- CX 8100/8325/8360: leaf switches
- CX 9300: spine switches
- CX 10000: leaf with DPU-accelerated services

### Underlay Options

- OSPF (point-to-point on all fabric links)
- eBGP (ASN-per-leaf or ASN-per-rack)

### Overlay

- MP-BGP with L2VPN EVPN address family
- Route reflectors at spine for overlay scalability
- VXLAN encapsulation (UDP 4789)

### Symmetric IRB

- Distributed L3 gateway at each leaf
- Anycast gateway: identical IRB MAC and IP on all leaves
- Inter-VLAN routing happens locally without hair-pinning
- L3VNI used for inter-VRF routing

### ESI Multi-Homing

- Ethernet Segment Identifier for EVPN-aware multi-homing
- Integrates with VSX for active-active access
- DF (Designated Forwarder) election per segment

## Dynamic Segmentation

### Authentication Flow

```
Client ──► CX Switch ──► ClearPass (RADIUS)
                              │
                         Authenticate
                         (802.1X/MAC-Auth)
                              │
                         Return Role
                         (VLAN/ACL/UBT)
                              │
CX Switch ◄── Enforce Policy ──┘
```

### Distributed Mode

- Switch enforces VLAN assignment, downloadable ACLs, rate limiting
- No tunnel; policy applied at the access port
- Best for standard wired access deployments

### Centralized Mode (UBT)

- Switch creates GRE tunnel to Aruba gateway/controller
- All user traffic tunneled to gateway for centralized policy
- Enables consistent wired + wireless policy enforcement
- Requires Aruba Mobility Controller or Gateway as tunnel endpoint

### Per-Port Authentication

```
aaa authentication port-access dot1x authenticator
    aaa-server-group CLEARPASS
aaa authentication port-access mac-auth
    aaa-server-group CLEARPASS

interface 1/1/1
    aaa authentication port-access dot1x authenticator
        cached-reauth-enable
    aaa authentication port-access mac-auth
        auth-enable
```

## CX 10000 DPU Architecture

The CX 10000 integrates AMD Pensando DPUs (Data Processing Units) per line card:

- **Stateful firewall**: line-rate east-west firewall without external appliances
- **NAT**: distributed NAT at the switch
- **Micro-segmentation**: policy enforcement at ASIC speed
- **Pensando PSM**: Policy and Services Manager for DPU policy management
- **Aruba Fabric Composer**: unified data center fabric management
- Eliminates the need for separate firewall appliances for east-west traffic
