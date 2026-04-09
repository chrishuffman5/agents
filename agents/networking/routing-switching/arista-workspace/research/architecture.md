# Arista EOS Architecture

## Overview

Arista EOS (Extensible Operating System) is a fully programmable, highly modular, Linux-based network operating system. Its core design philosophy centers on separating state from protocol logic through a centralized state database, enabling fault isolation, stateful restarts, and In-Service Software Upgrades (ISSU).

---

## Linux Foundation

EOS runs on an unmodified Linux kernel. The original userland was Fedora-based; subsequent releases rebased on CentOS and later AlmaLinux. This standard Linux base provides:

- On-box tools: `tcpdump`, `bash`, `python3`, `iperf`, `curl`, standard GNU utilities
- Standard process management (systemd/init)
- Linux namespaces and cgroups for VRF implementation
- Full SSH access to the Linux shell via `bash` from EOS CLI
- Ability to run custom daemons, containers (EOS 4.28+), and third-party agents

**Accessing Linux shell from CLI:**
```
switch# bash
[admin@switch ~]$ tcpdump -i eth0
[admin@switch ~]$ python3 /mnt/flash/myscript.py
```

---

## Sysdb — System Database

Sysdb is the heart of EOS. It is an in-memory, process-local key-value store that acts as the authoritative source of all switch state — configuration, operational data, forwarding tables, interface state, protocol state.

### Key Properties

- **Centralized state**: All agents (processes) read and write state through Sysdb, not directly to hardware or to each other.
- **Publish/subscribe model**: Agents subscribe to specific Sysdb paths; changes trigger notifications automatically. No polling required.
- **Persistence**: Sysdb state survives individual agent crashes. When an agent restarts, it re-reads its state from Sysdb and resumes operation — this is the foundation of stateful restart.
- **Hardware abstraction**: The forwarding ASIC driver reads Sysdb and programs hardware. Protocol agents never touch hardware directly.

### Sysdb Paths (conceptual examples)

```
/Smash/eos/bridge/bridgingTable/...      # MAC table
/Smash/routing/route/...                 # RIB entries
/Smash/eos/intfMgr/...                   # Interface state
/Smash/stp/...                           # Spanning tree state
```

### Why Sysdb Matters for Resilience

If the BGP process crashes, the installed routes remain in Sysdb and the FIB is not disturbed. BGP restarts, re-subscribes to Sysdb, and gracefully reconverges. This is fundamentally different from monolithic OS designs where a protocol crash can destabilize the entire forwarding plane.

---

## Multi-Process Architecture

EOS runs more than 100 independent processes called **agents**. Each agent is responsible for a single function:

| Agent | Function |
|---|---|
| `Bgp` | BGP routing protocol |
| `Ospf` | OSPF routing protocol |
| `Isis` | IS-IS routing protocol |
| `Stp` | Spanning Tree Protocol |
| `Mlag` | MLAG control plane |
| `Vxlanctl` | VXLAN data plane management |
| `Cli` | Command-line interface |
| `Snmpagent` | SNMP |
| `ProcMgr` | Process lifecycle management |
| `Fru` | Field Replaceable Unit management (linecards, PSUs) |
| `EthIntf` | Ethernet interface management |

### Fault Isolation

Because each agent is a separate Linux process:
- A crash in one agent does not affect others
- The ASIC driver continues forwarding during agent restarts
- Watchdog processes restart failed agents automatically
- ProcMgr monitors agent health and enforces restart policies

### ISSU (In-Service Software Upgrade)

Because state is in Sysdb (not in individual agents), EOS can upgrade agents one by one while the system continues forwarding:

1. New agent binary is staged
2. Old agent is stopped; Sysdb retains state
3. New agent starts, re-reads Sysdb, resumes operation
4. ASIC continues forwarding throughout

MLAG ISSU extends this to dual-switch upgrades: one peer upgrades while the other continues forwarding, then roles swap.

---

## eAPI — External API

eAPI is a JSON-RPC 2.0 interface that allows programmatic execution of any EOS CLI command and retrieval of structured JSON output. It operates over HTTP or HTTPS.

### Enabling eAPI

```
management api http-commands
   protocol https
   no shutdown
```

### Request Format

HTTP POST to `https://<switch>/command-api`

```json
{
  "jsonrpc": "2.0",
  "method": "runCmds",
  "params": {
    "version": 1,
    "cmds": ["show version", "show interfaces"],
    "format": "json"
  },
  "id": "1"
}
```

### curl Example

```bash
curl -s -k -u admin:password \
  -H "Content-Type: application/json" \
  -X POST https://192.0.2.1/command-api \
  -d '{
    "jsonrpc": "2.0",
    "method": "runCmds",
    "params": {
      "version": 1,
      "cmds": ["show version"],
      "format": "json"
    },
    "id": "1"
  }'
```

### pyeapi (Python Client)

```python
import pyeapi

# Connect to device
node = pyeapi.connect(host='192.0.2.1', username='admin', password='password', return_node=True)

# Run commands
result = node.run_commands(['show version', 'show interfaces'])
print(result[0]['version'])

# Configuration
node.run_commands(['enable', 'configure', 'hostname new-name'])
```

### eAPI Transport Options

| Transport | Port | Use Case |
|---|---|---|
| HTTPS | 443 | Production (recommended) |
| HTTP | 80 | Lab/internal only |
| Unix socket | N/A | On-box scripts |

---

## CloudVision (CVP / CVaaS)

CloudVision is Arista's network management, automation, and analytics platform. It is available as:
- **CVP**: On-premises appliance (single node or cluster)
- **CVaaS**: CloudVision as a Service (Arista-hosted SaaS)

### Core Capabilities

| Feature | Description |
|---|---|
| **Telemetry** | Streaming per-device state at scale via gRPC |
| **Config Management** | Configlets, provisioning, desired-state enforcement |
| **Image Management** | EOS software image repository and upgrade workflows |
| **Change Control** | Structured, approval-gated configuration change workflows |
| **Studios** | Intent-based provisioning (L3LS, Campus, etc.) |
| **Pathfinder** | WAN path visualization and SD-WAN analytics |
| **Compliance** | Config drift detection, audit trail |
| **Topology** | Live network-wide topology maps |

### Studios

Studios provide intent-driven provisioning without per-device configuration. Key studios:
- **L3 Leaf-Spine**: Automated DC fabric provisioning
- **Campus": Automated campus topology provisioning
- **Static Configuration Studio**: Used by AVD cv_deploy role for IaC deployments (CVaaS and CVP 2024.1+)
- **Inventory & Topology Studio**: Device onboarding and topology tracking

### CloudVision REST/gRPC API

CVP exposes a gRPC-based API (Resource API). Authentication uses service account tokens. Regional CVaaS endpoints:
- US: `www.cv-staging.corp.arista.io`
- EU: `www.arista.eu`

---

## Streaming Telemetry — gRPC/gNMI/OpenConfig

### Architecture

EOS implements a gNMI server (default port TCP/6030) that serves both OpenConfig-modeled and EOS-native paths. Clients can subscribe using:
- **ONCE**: Single snapshot
- **POLL**: On-demand polling
- **STREAM**: Continuous push (SAMPLE, ON_CHANGE, TARGET_DEFINED)

### Configuration

```
management api gnmi
   transport grpc openmgmt
      vrf management
      port 6030
   provider eos-native
```

Adding `provider eos-native` enables subscriptions to EOS-native Sysdb paths in addition to OpenConfig paths.

### OpenConfig Models Supported

- `openconfig-interfaces`
- `openconfig-bgp`
- `openconfig-isis`
- `openconfig-ospfv2`
- `openconfig-network-instance` (VRFs)
- `openconfig-platform`
- `openconfig-lldp`
- `openconfig-mpls`

### Telemetry Pipeline Example

```
EOS (gNMI server) → Telegraf (gNMI input plugin) → InfluxDB → Grafana
EOS (gNMI server) → gNMIc → Prometheus → Grafana
EOS (gNMI server) → CloudVision (built-in consumer)
```

### gNMIc Subscribe Example

```bash
gnmic -a 192.0.2.1:6030 -u admin -p password --insecure \
  subscribe --path "openconfig:/interfaces/interface/state/counters" \
  --mode stream --stream-mode sample --sample-interval 10s
```

---

## MLAG — Multi-Chassis Link Aggregation

MLAG allows two Arista switches to present a single logical LAG to downstream devices, providing active-active redundancy without STP blocking.

### Key Components

| Component | Purpose |
|---|---|
| **Domain ID** | Shared identifier tying two peers together |
| **Peer Link** | Port-channel carrying control and backup data traffic |
| **Peer-keepalive** | Out-of-band heartbeat for peer health detection |
| **MLAG interfaces** | Port-channels with matched MLAG IDs on both peers |
| **Virtual MAC** | Shared MAC address for ARP/MAC stability |

See `features.md` for full configuration details.

---

## ECMP — Equal-Cost Multi-Path

EOS supports hardware ECMP for load-balancing across multiple equal-cost next-hops. Key characteristics:
- Hashing based on src/dst IP, protocol, src/dst port (L3/L4 hash)
- Up to 512 ECMP groups per switch (platform-dependent)
- `maximum-paths 128 ecmp 128` under BGP for large fabrics
- ECMP with IP tunnels (VXLAN underlay) supported
- Resilient ECMP (hash table stability across membership changes): `load-balance hardware ecmp resilient hashing`

---

## VXLAN/EVPN

VXLAN (Virtual Extensible LAN) provides L2/L3 overlay across an IP underlay. EVPN (BGP control plane) automates VTEP discovery, MAC/IP learning, and ARP suppression.

See `features.md` for full VXLAN/EVPN configuration reference.

### Key Architectural Points

- **VTEP**: Each leaf switch (or MLAG pair) is a VTEP (Virtual Tunnel Endpoint)
- **VNI**: 24-bit identifier mapping VLANs to overlay segments
- **Symmetric IRB**: Both ingress and egress VTEPs route; intermediate IP-VRF VNI carries inter-subnet traffic
- **ARP suppression**: EVPN Type-2 routes with MAC-IP bindings eliminate ARP flooding in the overlay

---

## On-Box Linux Access and Programmability

### Direct Linux Shell

```
switch# bash
[admin@switch ~]$ ip link show
[admin@switch ~]$ ip route show vrf TENANT
[admin@switch ~]$ python3
>>> import eossdk
```

### On-Box Python

EOS ships with Python 3 and the `eossdk` Python bindings. Scripts can interact with Sysdb directly:

```python
import eossdk
import sys

class MyAgent(eossdk.AgentHandler, eossdk.IntfHandler):
    def __init__(self, sdk):
        self.agentMgr = sdk.get_agent_mgr()
        eossdk.AgentHandler.__init__(self, self.agentMgr)
```

### EOS SDK (C++/Python)

The EOS SDK provides a high-performance, event-driven API for building custom agents that run natively on EOS and interact with Sysdb. Agents built with EOS SDK:
- Get notified of state changes (interface up/down, route changes, BGP events)
- Can modify switch state (add routes, configure ACLs)
- Run as standard Linux processes with full process isolation guarantees

---

## Sources

- [Arista EOS Product Page](https://www.arista.com/en/products/eos)
- [Understanding EOS and Sysdb - EosSdk Wiki](https://github.com/aristanetworks/EosSdk/wiki/Understanding-EOS-and-Sysdb)
- [EOS Extensibility AAG](https://www.arista.com/assets/data/pdf/EOS_Extensibility_AAG.pdf)
- [OpenConfig gNMI Configuration - Arista Open Management](https://aristanetworks.github.io/openmgmt/configuration/openconfig/)
- [Arista Networks - Wikipedia](https://en.wikipedia.org/wiki/Arista_Networks)
