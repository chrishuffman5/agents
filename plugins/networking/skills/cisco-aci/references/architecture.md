# Cisco ACI Architecture Reference

## APIC Internals

### Cluster Formation

APIC cluster uses a distributed hash table (DHT) for shard-based data distribution:
- Each APIC owns a set of shards (data partitions)
- Minimum 3 nodes for quorum (2 of 3 must be reachable)
- 5 or 7 APICs distribute shards for larger fabrics
- Cluster health visible at: Fabric > Inventory > Controllers

### APIC Sizing

| Cluster Size | Max Leaf Switches | Max Endpoints | Use Case |
|---|---|---|---|
| 3 APICs | 80 | 10,000 | Standard enterprise |
| 5 APICs | 200 | 50,000 | Large enterprise |
| 7 APICs | 400 | 100,000 | Service provider / hyperscale |

### APIC Communication

- **Northbound**: REST API (HTTPS), GUI, CLI, SDK
- **Southbound**: OpFlex over TCP to leaf and spine switches
- **East-West**: Cluster sync (Raft consensus for APIC election, DHT for data)

## OpFlex Protocol Details

### Message Types

| Message | Direction | Purpose |
|---|---|---|
| Policy Resolve | Node -> APIC | Request policy for a managed object |
| Policy Update | APIC -> Node | Push updated policy |
| Endpoint Declare | Node -> APIC | Report discovered endpoint (MAC/IP/location) |
| Endpoint Resolve | Node -> APIC | Query endpoint location for proxy forwarding |
| State Report | Node -> APIC | Report operational state (faults, stats, health) |

### OpFlex Resilience

- Nodes cache their policy set locally
- If APIC is unreachable, nodes enforce cached policies indefinitely
- New endpoint learning continues locally even without APIC
- Policy changes require APIC connectivity

## Policy Model Deep Dive

### Management Information Tree (MIT)

Every object in ACI is a node in the MIT. Key classes:

```
uni (universe)
  tn-<tenant> (fvTenant)
    ctx-<vrf> (fvCtx)
    BD-<bd> (fvBD)
      subnet-<ip> (fvSubnet)
    ap-<app-profile> (fvAp)
      epg-<epg> (fvAEPg)
        rsprov-<contract> (fvRsProv)     # provider binding
        rscons-<contract> (fvRsCons)     # consumer binding
    brc-<contract> (vzBrCP)
      subj-<subject> (vzSubj)
        rsSubjFiltAtt-<filter> (vzRsSubjFiltAtt)
    flt-<filter> (vzFilter)
      e-<entry> (vzEntry)
    l3out-<l3out> (l3extOut)
      instP-<ext-epg> (l3extInstP)
  infra (infraInfra)
    accportprof-<profile> (infraAccPortP)
    funcprof (infraFuncP)
      accportgrp-<name> (infraAccPortGrp)
```

### Object Relationships

ACI uses relation objects (Rs* classes) to link objects:
- `fvRsBd`: EPG to Bridge Domain binding
- `fvRsProv`: EPG to Contract provider binding
- `fvRsCons`: EPG to Contract consumer binding
- `fvRsCtx`: BD to VRF binding
- `fvRsDomAtt`: EPG to Domain (physical, VMM) binding

### Access Policies

Access policies define how physical infrastructure connects to the logical policy model:

```
VLAN Pool -> Domain -> AAEP -> Interface Policy Group -> Interface Profile -> Switch Profile
```

- **VLAN Pool**: Range of VLANs available (static or dynamic allocation)
- **Domain**: Physical, VMM (vCenter), L3, or external domain
- **AAEP (Attachable Access Entity Profile)**: Links domains to interface policies
- **Interface Policy Group**: Bundle of interface policies (CDP, LLDP, LACP, storm control)
- **Interface Profile**: Maps interface policy group to specific ports
- **Switch Profile**: Associates interface profile with specific leaf switches

### VMM Integration

ACI integrates with hypervisor managers for automatic endpoint classification:

**VMware vCenter:**
- APIC creates a VMware DVS on vCenter
- VMs attached to the DVS port groups are automatically classified into EPGs
- Endpoint learning: APIC monitors VM MAC/IP via vCenter events
- Dynamic VLAN allocation from the VMM domain VLAN pool

**Kubernetes / OpenShift:**
- ACI CNI plugin on worker nodes
- Pods classified into EPGs based on namespace/deployment annotations
- NetworkPolicy maps to ACI contracts

## Fabric Discovery Process

1. APIC connects to leaf switch 1 via its management port (typically Eth1/1 on leaf)
2. APIC discovers leaf 1 via LLDP
3. Leaf 1 discovers spine switches via LLDP on fabric uplinks
4. Spines discover remaining leaf switches via IS-IS and LLDP
5. Each discovered node is added to APIC inventory with serial number, role, and TEP address
6. Nodes must be explicitly approved (or pre-registered) in APIC before joining the fabric

## VXLAN in ACI

### Encapsulation

ACI uses three types of VXLAN VNIs:
- **EPG VNID**: Identifies an EPG on the fabric (maps EPG to VXLAN segment)
- **BD VNID**: Identifies a bridge domain for L2 forwarding
- **VRF VNID (L3 VNI)**: Identifies a VRF for inter-subnet routed traffic

### Forwarding Modes

**Bridge Domain L2 forwarding:**
- **Hardware Proxy**: Unknown unicast sent to spine proxy (recommended). Spine looks up destination in COOP database and forwards to correct leaf.
- **Flood**: Unknown unicast flooded to all ports in the BD. Works like a traditional VLAN. Higher bandwidth consumption.

**Bridge Domain L3 forwarding:**
- **Optimized**: ARP requests for known endpoints answered locally by leaf (ARP glean from COOP). Unknown destinations trigger ARP glean via spine.
- **Flood**: ARP requests flooded within the BD. Higher bandwidth but simpler.

### Endpoint Learning

Endpoints are learned via:
1. **Local learning**: Leaf learns MAC/IP from data plane (first packet or ARP)
2. **Remote learning**: Leaf learns remote endpoints via COOP (Council of Oracles Protocol) on spines
3. **VMM learning**: APIC pushes VM endpoint information from vCenter/SCVMM
4. **Static binding**: Admin manually binds an endpoint to a port/EPG

### COOP (Council of Oracles Protocol)

Spines run COOP to maintain a distributed endpoint database:
- Each spine holds a full copy of all known endpoints
- Leaves report locally learned endpoints to spines
- Spines answer proxy queries from leaves looking for remote endpoints
- COOP ensures any spine can answer an endpoint location query

## Multi-Pod Architecture

### Inter-Pod Network (IPN)

Requirements for the IPN connecting pods:
- OSPF for underlay reachability between pods
- PIM BiDir or BGP EVPN for multicast/BUM handling
- DHCP relay for APIC discovery across pods
- MTU 9150+ for VXLAN encapsulation
- Latency: <50ms RTT recommended

### Multi-Pod APIC Distribution

- All APICs in a single cluster (not per-pod)
- Distribute APICs across pods for resilience (e.g., 2 in Pod-1, 1 in Pod-2 for a 3-APIC cluster)
- APIC-to-APIC communication traverses the IPN

## Multi-Site (NDO) Architecture

### Schema and Template Model

NDO uses schemas and templates to organize policy:
- **Schema**: Top-level container (e.g., "Production-Network")
- **Template**: A set of objects (tenants, VRFs, BDs, EPGs, contracts) assigned to one or more sites
- **Stretched template**: Template deployed to multiple sites (objects exist on all associated sites)
- **Local template**: Template deployed to a single site (site-specific objects)

### Inter-Site Network (ISN)

Requirements:
- BGP EVPN peering between site spine switches (or dedicated border leaf/spine)
- VXLAN encapsulation over IP underlay
- No OSPF or PIM required (unlike Multi-Pod IPN)
- Latency: <500ms RTT supported (but stretched L2 should be <100ms for practical use)
