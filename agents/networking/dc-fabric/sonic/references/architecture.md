# SONiC Architecture Reference

## Origins and Governance

- Originated at **Microsoft Azure** as a replacement for vendor-bundled NOS on whitebox switches
- Open-sourced in 2016; contributed to **Linux Foundation** as the **SONiC Foundation** (2023+)
- Production deployments: Microsoft Azure, Alibaba Cloud (100,000+ devices across 28 regions / 86 AZs), Orange Telecom, growing enterprise adoption
- **Arista Networks** joined SONiC Foundation as Premier Member (2025), alongside Auradine, Nexthop.ai, and STORDIS
- Release cadence: ~semi-annual; **2025.11** the most recent major release

---

## Redis Database Architecture

SONiC's architecture is distinguished by its **Redis-centric database bus**. All system state is stored in Redis key-value databases, and daemons communicate via pub/sub subscriptions.

### CONFIG_DB

- **Purpose**: Desired configuration (interfaces, BGP, ACL, VLAN, routes)
- **Written by**: Operators via CLI, config_db.json, gNMI, RESTCONF, automation tools
- **Read by**: SwSS daemons (orchagent and subsidiary daemons)
- **Persistence**: Saved to `/etc/sonic/config_db.json` via `config save`
- **Schema**: Defined by SONiC YANG models; validated on load

Key tables:
```
INTERFACE          -- IP addresses on physical/loopback/VLAN interfaces
PORT               -- Physical port configuration (speed, MTU, FEC, admin status)
VLAN               -- VLAN definitions
VLAN_MEMBER        -- Port-to-VLAN membership
BGP_NEIGHBOR       -- BGP peer definitions
ACL_TABLE          -- ACL table definitions
ACL_RULE           -- ACL rule entries
PORTCHANNEL        -- LAG/bond definitions
PORTCHANNEL_MEMBER -- LAG member ports
NTP_SERVER         -- NTP server addresses
SYSLOG_SERVER      -- Syslog server addresses
```

### APP_DB

- **Purpose**: Application-derived state (routes from FRR, DHCP bindings, LLDP neighbors)
- **Written by**: Application daemons (FRR via fpmsyncd, lldpd, dhcp_relay)
- **Read by**: orchagent (translates to ASIC_DB)
- **Not persistent**: Rebuilt from running applications on restart

Key tables:
```
ROUTE_TABLE        -- Routes from FRR (prefix -> nexthop)
NEIGH_TABLE        -- ARP/NDP neighbor entries
INTF_TABLE         -- Interface operational state
LAG_TABLE          -- LAG operational state
LLDP_ENTRY_TABLE   -- LLDP neighbor information
```

### ASIC_DB

- **Purpose**: Hardware programming requests in SAI object format
- **Written by**: orchagent (translates APP_DB entries to SAI objects)
- **Read by**: syncd (calls vendor SAI library to program hardware)
- SAI objects include: routes, next-hops, next-hop groups, ACL entries, FDB entries, neighbors

### STATE_DB

- **Purpose**: Operational state feedback from hardware and system
- **Written by**: syncd (ASIC notifications), portsyncd (link state), system monitors
- **Read by**: CLI (show commands), monitoring, alerting

Key tables:
```
PORT_TABLE         -- Link state (up/down), speed, operational status
TRANSCEIVER_INFO   -- SFP/QSFP module information
FAN_INFO           -- Fan speed and status
TEMPERATURE_INFO   -- Sensor temperature readings
```

### COUNTERS_DB

- **Purpose**: Port, queue, and ACL statistics
- **Written by**: syncd (polls ASIC counters via SAI)
- **Read by**: CLI (`show interfaces counters`), streaming telemetry
- Counters updated at configurable intervals (default: 1 second for port, 10 seconds for queue)

### Inter-Database Communication

```
CONFIG_DB changes
    -> Redis pub/sub notification
    -> orchagent subscribes, receives change event
    -> orchagent processes change, writes to ASIC_DB
    -> syncd subscribes to ASIC_DB, receives SAI object
    -> syncd calls vendor libsai to program ASIC
    -> ASIC sends notification (link change, counter update)
    -> syncd writes notification to STATE_DB / COUNTERS_DB
```

---

## SAI (Switch Abstraction Interface) Deep Dive

### SAI Object Model

SAI defines a hierarchical object model for ASIC programming:

| SAI Object | Description |
|---|---|
| **sai_switch** | Top-level switch object; global attributes (MAC, hash algorithm) |
| **sai_port** | Physical port; speed, FEC, admin state, breakout |
| **sai_vlan** | VLAN; member ports, STP state |
| **sai_router_interface** | L3 interface; VLAN interface or routed port |
| **sai_route_entry** | IP route; destination prefix -> next-hop or next-hop group |
| **sai_next_hop** | Next-hop IP address; associated with router interface |
| **sai_next_hop_group** | ECMP group; multiple next-hops for equal-cost paths |
| **sai_neighbor_entry** | ARP/NDP entry; IP -> MAC mapping |
| **sai_acl_table** | ACL table; defines match fields (src IP, dst IP, protocol, L4 port) |
| **sai_acl_entry** | ACL rule within a table; match + action |
| **sai_bridge** | L2 bridge domain |
| **sai_fdb_entry** | MAC address table entry |
| **sai_tunnel** | VXLAN/GRE tunnel endpoint |
| **sai_policer** | Rate limiter / traffic policer |
| **sai_qos_map** | QoS mapping (DSCP -> TC, TC -> queue) |

### SAI Vendor Implementations

Each ASIC vendor provides a libsai shared library:

```
/usr/lib/libsai.so -> vendor-specific implementation

Broadcom:  libsai.so linked against Memory Allocation (MA) + MEMORY ABSTRACTION (SAL) + NPL
Mellanox:  libsai.so linked against sx_sdk (Spectrum SDK)
Marvell:   libsai.so linked against cpss (Common Platform Support System)
```

### SAI Attributes per ASIC

| Feature | Broadcom TH4 | Mellanox Spectrum-4 | Marvell Prestera |
|---|---|---|---|
| Max routes | 128K+ IPv4 | 512K+ IPv4 | 16K-64K IPv4 |
| ECMP groups | 4K | 4K | 1K |
| ACL entries | 4K-16K (TCAM) | 16K+ (algorithmic) | 2K-8K |
| VXLAN tunnels | 4K | 4K | 1K |
| LAG groups | 256 | 256 | 128 |

---

## SwSS (Switch State Service) Deep Dive

### orchagent

The main orchestrator daemon in SONiC:

- Subscribes to CONFIG_DB and APP_DB tables
- Translates high-level configuration intent into SAI object operations
- Writes SAI objects to ASIC_DB
- Manages object lifecycle: create, set, remove
- Handles dependencies (e.g., route requires next-hop, which requires neighbor, which requires interface)

### orchagent Sub-modules

| Module | Responsibility |
|---|---|
| **RouteOrch** | IP routes -> SAI route entries + next-hop groups |
| **NeighOrch** | ARP/NDP neighbors -> SAI neighbor entries |
| **PortsOrch** | Port configuration -> SAI port attributes |
| **IntfsOrch** | Interface IPs -> SAI router interfaces |
| **AclOrch** | ACL rules -> SAI ACL tables and entries |
| **VlanOrch** | VLANs -> SAI VLAN objects and membership |
| **TunnelOrch** | VXLAN tunnels -> SAI tunnel objects |
| **QosOrch** | QoS policies -> SAI QoS maps, schedulers, policers |
| **MirrorOrch** | Port mirroring -> SAI mirror sessions |
| **FdbOrch** | MAC learning -> SAI FDB entries |

### Subsidiary Daemons

| Daemon | Function |
|---|---|
| **portsyncd** | Monitors kernel netlink for port events; writes to APP_DB |
| **neighsyncd** | Monitors kernel neighbor table; writes to APP_DB |
| **intfsyncd** | Monitors interface IP changes; writes to APP_DB |
| **fpmsyncd** | Receives routes from FRR via FPM (Forwarding Plane Manager); writes to APP_DB |
| **natsyncd** | NAT table synchronization |
| **fdbsyncd** | FDB (MAC table) synchronization from kernel |

---

## syncd Deep Dive

syncd is the bridge between the ASIC_DB (software) and the actual ASIC hardware:

```
ASIC_DB (Redis)
    |
    v
syncd process
    |
    +-- Subscribes to ASIC_DB via Redis
    +-- Translates ASIC_DB objects to SAI API calls
    +-- Calls vendor libsai.so functions
    +-- Receives ASIC notifications (link state, FDB learn, etc.)
    +-- Writes notifications back to STATE_DB / COUNTERS_DB
    |
    v
ASIC Hardware (forwarding tables)
```

### syncd Modes

| Mode | Description |
|---|---|
| **Normal** | Full SAI programming; production mode |
| **Virtual** | No actual ASIC; SAI calls go to virtual switch (testing) |
| **mlnx_sai / memory_sai** | Vendor-specific SAI stubs for debugging |

---

## FRRouting (FRR) Integration

SONiC uses FRRouting for all routing protocols:

### Routing Daemons

| Daemon | Protocol |
|---|---|
| **bgpd** | BGP-4, MP-BGP (IPv4/IPv6 unicast, EVPN, VPNv4) |
| **zebra** | Routing table manager; kernel route installation; redistribution |
| **ospfd** | OSPFv2 |
| **ospf6d** | OSPFv3 |
| **staticd** | Static routes |
| **bfdd** | BFD (Bidirectional Forwarding Detection) |

### Route Flow

```
BGP peer advertises route
    -> bgpd receives, applies policy, installs in BGP RIB
    -> bgpd pushes best route to zebra
    -> zebra installs in kernel routing table
    -> zebra sends route to fpmsyncd via FPM socket
    -> fpmsyncd writes route to APP_DB ROUTE_TABLE
    -> orchagent (RouteOrch) reads APP_DB
    -> orchagent creates SAI route_entry + next_hop in ASIC_DB
    -> syncd programs ASIC forwarding table via SAI
```

### FRR Configuration in SONiC

FRR configuration is managed in two ways:

1. **Integrated config mode** -- FRR reads from `/etc/sonic/frr/bgpd.conf`, etc.
2. **ConfigDB-driven** -- BGP configuration in CONFIG_DB translated to FRR config via bgpcfgd

```
# FRR vtysh access
sudo vtysh

# BGP configuration
router bgp 65001
  bgp router-id 10.0.0.1
  neighbor 10.0.0.2 remote-as 65002
  address-family ipv4 unicast
    network 10.1.0.0/24
    neighbor 10.0.0.2 route-map IMPORT in
```

---

## ConfigDB / YANG Deep Dive

### config_db.json Structure

```json
{
  "DEVICE_METADATA": {
    "localhost": {
      "hostname": "leaf01",
      "hwsku": "Accton-AS7726-32X",
      "platform": "x86_64-accton_as7726_32x-r0",
      "type": "LeafRouter",
      "bgp_asn": "65001"
    }
  },
  "LOOPBACK_INTERFACE": {
    "Loopback0|10.0.0.1/32": {}
  },
  "INTERFACE": {
    "Ethernet0|10.0.1.0/31": {},
    "Ethernet4|10.0.1.2/31": {}
  },
  "BGP_NEIGHBOR": {
    "10.0.1.1": {
      "asn": "65100",
      "name": "spine1"
    },
    "10.0.1.3": {
      "asn": "65100",
      "name": "spine2"
    }
  }
}
```

### sonic-cfggen

- Generates CONFIG_DB from templates (Jinja2 + YAML variables)
- Converts between ConfigDB JSON and YANG representation
- Used in zero-touch provisioning (ZTP) workflows

```bash
# Generate config from template
sonic-cfggen -d -t /usr/share/sonic/templates/bgp.conf.j2

# Load minigraph (legacy provisioning format)
sonic-cfggen -m /etc/sonic/minigraph.xml --write-to-db
```

### YANG Models

SONiC YANG models cover:

- `sonic-port.yang` -- Port configuration
- `sonic-vlan.yang` -- VLAN configuration
- `sonic-interface.yang` -- Interface IP configuration
- `sonic-acl.yang` -- ACL tables and rules
- `sonic-bgp-neighbor.yang` -- BGP neighbor configuration
- `sonic-ntp.yang` -- NTP configuration

YANG validation prevents invalid configurations from being applied to CONFIG_DB.

---

## SONiC-DASH Architecture

DASH (Disaggregated API for SONiC Hosts) extends SAI to SmartNICs:

```
VM / Container workload
    |
    v
SmartNIC / DPU (NVIDIA BlueField, etc.)
    |
    +-- DASH pipeline (SAI-like APIs)
    |   +-- VNET routing (virtual network routing)
    |   +-- NAT (network address translation)
    |   +-- Load balancing (connection-level)
    |   +-- ACL (access control)
    |   +-- Metering (traffic accounting)
    |
    v
Physical network
```

### DASH vs Traditional SAI

| Aspect | SAI (switch) | DASH (SmartNIC) |
|---|---|---|
| **Target hardware** | ASIC switch silicon | DPU / SmartNIC |
| **Functions** | L2/L3 forwarding, ACL, QoS | VNET, NAT, LB, metering |
| **Scale** | Network-wide (per switch) | Per-host (per SmartNIC) |
| **Control plane** | SONiC on switch | SONiC or SDN controller |

---

## Use Cases

### Hyperscale Data Center

- Microsoft Azure, Alibaba Cloud: full BGP, large routing tables, ECMP, VXLAN, QoS
- Tens of thousands of switches per deployment
- Automation-driven (no manual CLI configuration)

### Enterprise DC Fabric

- Leaf/spine with eBGP underlay and VXLAN/EVPN overlay
- Cost savings vs proprietary NOS (Cisco, Arista, Juniper)
- Enterprise SONiC distributions (Dell, STORDIS) for commercial support

### Telco Disaggregation

- Orange running SONiC for IP/MPLS edge
- Carrier-grade support via Broadcom Jericho ASICs
- MPLS and segment routing support evolving

### AI/ML Networking

- SONiC Foundation promoting SONiC for AI datacenter workloads
- High-bandwidth (400G/800G), low-latency
- RoCEv2 (RDMA over Converged Ethernet) support for GPU-to-GPU communication
- Lossless Ethernet (PFC, ECN) configuration for storage and AI traffic

---

## Troubleshooting Reference

### Redis Database Inspection

```bash
# Connect to Redis
redis-cli -n 4   # CONFIG_DB
redis-cli -n 0   # APP_DB
redis-cli -n 1   # ASIC_DB
redis-cli -n 6   # STATE_DB

# List all keys in CONFIG_DB
redis-cli -n 4 KEYS "*"

# Get specific entry
redis-cli -n 4 HGETALL "INTERFACE|Ethernet0|10.0.1.0/31"

# Check route in APP_DB
redis-cli -n 0 HGETALL "ROUTE_TABLE:10.1.0.0/24"

# Check port state
redis-cli -n 6 HGETALL "PORT_TABLE|Ethernet0"
```

### Service Status

```bash
# Check all SONiC services
sudo systemctl status sonic.target

# Check specific daemon
sudo systemctl status swss
sudo systemctl status syncd
sudo systemctl status bgp

# View daemon logs
sudo journalctl -u swss --no-pager -n 100
sudo journalctl -u syncd --no-pager -n 100
```

### FRR Troubleshooting

```bash
# Enter FRR shell
sudo vtysh

# BGP status
show ip bgp summary
show ip bgp neighbors <ip> received-routes
show ip bgp neighbors <ip> advertised-routes

# Route debugging
show ip route
show ip route <prefix>
debug bgp updates
```
