# Cisco ACI Diagnostics Reference

## Health Scores

ACI uses a 0-100 health score system (higher is healthier) across all objects:

### Scope

| Object | Where to Check |
|---|---|
| Fabric | Fabric > Inventory > Fabric Health |
| Node (switch/APIC) | Fabric > Inventory > Pod > Node |
| Tenant | Tenants > [tenant] > Operational > Health |
| Application Profile | Tenants > [tenant] > Application Profiles > [app] > Health |
| EPG | Tenants > [tenant] > Application Profiles > [app] > EPGs > [epg] > Health |
| Bridge Domain | Tenants > [tenant] > Networking > Bridge Domains > [bd] > Health |

### Health Score Calculation

Health scores degrade based on fault severity:
- Critical fault: -25 points per fault
- Major fault: -10 points per fault
- Minor fault: -5 points per fault
- Warning: -1 point per fault

A score of 100 means no active faults on the object.

### API Query for Health

```
GET /api/node/class/fabricHealthTotal.json              # Fabric health
GET /api/node/mo/uni/tn-Production.json?rsp-subtree-include=health  # Tenant health
GET /api/node/class/healthInst.json?query-target-filter=lt(healthInst.cur,"80")  # Objects below 80
```

## Faults

### Fault Lifecycle

```
Raised -> Raised-Clearing (condition resolved, waiting for clear interval) -> Cleared -> Retaining (kept for retention period) -> Deleted
```

### Fault Severity

| Severity | Impact | Example |
|---|---|---|
| Critical | Service affecting | Interface down, APIC cluster quorum loss |
| Major | Significant degradation | Contract misconfiguration, endpoint flapping |
| Minor | Non-critical issue | Minor configuration warning, approaching threshold |
| Warning | Informational | Audit log, non-impacting event |

### Fault Query Commands

```bash
# CLI on APIC
moquery -c faultInst                                    # All faults
moquery -c faultInst -f 'fault.Inst.severity=="critical"'  # Critical faults
moquery -c faultInst -f 'fault.Inst.lc=="raised"'      # Active (raised) faults
moquery -c faultDelegate                                # Delegated faults (from child objects)

# REST API
GET /api/node/class/faultInst.json
GET /api/node/class/faultInst.json?query-target-filter=eq(faultInst.severity,"critical")
GET /api/node/class/faultInst.json?query-target-filter=and(eq(faultInst.severity,"critical"),eq(faultInst.lc,"raised"))
```

### Common Fault Codes

| Code | Description | Resolution |
|---|---|---|
| F0532 | Interface Physical Down | Check cabling, SFP, port status |
| F0467 | Resolution failure (EPG to domain) | Verify domain/AAEP/VLAN pool binding |
| F1386 | Contract scope mismatch | Ensure VRF scope matches contract scope |
| F0952 | Endpoint is rogue | Tune rogue EP detection parameters or fix duplicate IP |
| F0103 | APIC cluster health degraded | Check APIC node status, disk, services |
| F0321 | VLAN pool exhausted | Expand VLAN pool range |

## ELAM (Embedded Logic Analyzer Module)

ELAM is a hardware-level packet capture on Nexus 9000 in ACI mode. It captures the first packet matching a trigger through the ASIC pipeline.

### ELAM Procedure

```bash
# SSH to leaf switch
# Enter ELAM shell
vsh_lc

# Select module and ASIC
module 1
debug platform internal tah elam asic 0

# Configure trigger
trigger reset
trigger init in-select 6 out-select 0

# Set match criteria (outer packet headers)
set outer ipv4 src_ip 10.1.1.100 dst_ip 10.2.2.200
# Or for VXLAN inner headers:
set inner ipv4 src_ip 10.1.1.100 dst_ip 10.2.2.200

# Start capture
start

# Wait for packet to match, then view report
status
report
```

### ELAM Report Fields

| Field | Meaning |
|---|---|
| `src_id` | Source interface or VTEP |
| `dst_id` | Destination interface or VTEP |
| `vpc` | VPC ID if applicable |
| `epg_vnid` | EPG VNID of the packet |
| `bd_vnid` | Bridge Domain VNID |
| `vrf_vnid` | VRF VNID |
| `sup_redirect` | Whether packet was redirected to supervisor |
| `acl_hit` | Whether an ACL (contract) was matched |
| `drop` | Whether packet was dropped and drop reason |

### When to Use ELAM

- Packets are being dropped at the leaf and you need to confirm which ASIC lookup is failing
- Contract deny is suspected but not confirmed by contract hit counts
- VXLAN encapsulation issues (wrong VNI, wrong VTEP destination)
- Endpoint learning failures (packet arrives but endpoint not learned)

## Contract Hit Counts

### GUI Path

Tenants > [tenant] > Application Profiles > [app] > EPGs > [epg] > Operational > Contract

### Per-Leaf Zoning Rules

```bash
# SSH to leaf switch
show zoning-rule                           # All zoning rules on this leaf
show zoning-rule scope <vrf-vnid>          # Rules for specific VRF
show zoning-rule filter <epg-vnid>         # Rules matching specific EPG
show zoning-rule statistics                # Hit counts per rule
```

### Interpreting Zoning Rules

Each contract between EPGs translates to one or more zoning rules on each leaf:
- Source pcTag: class ID of the source EPG
- Destination pcTag: class ID of the destination EPG
- Filter ID: references the contract filter (protocol/port match)
- Action: permit, deny, redirect, copy, log

### Verifying Contract Enforcement

```bash
# On leaf switch
show system internal policy-mgr prefix    # EPG to pcTag mappings
show system internal epm endpoint ip <ip> # Endpoint details including pcTag
show zoning-rule scope <vrf> filter <src-pcTag> <dst-pcTag>  # Specific rule
```

## Endpoint Reachability

### Endpoint Query

```bash
# APIC CLI
fabric <node-id> show endpoint detail                # All endpoints on a node
fabric <node-id> show endpoint ip <ip>               # Specific endpoint
fabric <node-id> show endpoint mac <mac>             # Specific MAC

# moquery
moquery -c fvCEp -f 'fv.CEp.ip=="10.1.1.5"'         # Find by IP
moquery -c fvCEp -f 'fv.CEp.mac=="00:50:56:XX:XX:XX"'  # Find by MAC

# REST API
GET /api/node/class/fvCEp.json?query-target-filter=eq(fvCEp.ip,"10.1.1.5")
```

### Endpoint Flags

| Flag | Meaning |
|---|---|
| L (Local) | Endpoint learned locally on this leaf |
| R (Remote) | Endpoint learned remotely via COOP |
| P (Peer) | Endpoint on vPC peer leaf |
| S (Static) | Statically configured endpoint |

### Endpoint Troubleshooting

```bash
# Check if endpoint is bouncing
fabric <node-id> show endpoint statistics               # Look for move count

# Check COOP on spine
fabric <spine-id> show coop internal info ip <ip>       # COOP entry for IP

# Check ARP/ND table
fabric <node-id> show ip arp vrf <tenant>:<vrf>

# Endpoint tracker (if enabled)
moquery -c fvTrackEp
```

## Central CLI

APIC provides a centralized CLI for running commands across fabric nodes:

```bash
# Run command on specific node(s)
fabric 101 show bgp summary                 # Single node
fabric 101-105 show bgp summary             # Range of nodes
fabric 101,103,105 show bgp summary         # Comma-separated list

# Run on all leaves
fabric leaf show interface status

# Run on all spines
fabric spine show isis adjacency

# Common diagnostic commands via Central CLI
fabric <node-id> show vlan extended          # VLAN to EPG mapping
fabric <node-id> show lldp neighbors         # Physical connectivity
fabric <node-id> show port-channel summary   # Port-channel status
fabric <node-id> show vpc                    # vPC status
```

## Atomic Counters

Atomic counters measure packet drops between two EPGs or endpoints at the leaf level:

### Configuration

```
Fabric > Fabric Policies > Policies > Troubleshooting > Atomic Counter Policy
```

### Interpretation

- **TX Count**: Packets sent from source leaf
- **RX Count**: Packets received at destination leaf
- **Drop Count**: TX - RX = fabric drops
- Captures over a configurable time window (default 5 minutes)
- Useful for detecting fabric-level packet loss (bad optics, overloaded spine)

## Troubleshooting Workflow

1. **Check health scores**: Start at fabric level, drill into degraded objects
2. **Query faults**: Filter for critical/major raised faults on affected objects
3. **Verify endpoint**: Confirm endpoint is learned on correct leaf with correct EPG classification
4. **Check contracts**: Verify zoning rules and hit counts between source and destination EPGs
5. **ELAM capture**: If contract/forwarding issue suspected, capture packet at ingress leaf
6. **Check fabric links**: Verify all leaf-spine links are up, no CRC errors or interface drops
7. **Verify access policies**: Confirm VLAN pool, domain, AAEP, interface policy group chain is complete
