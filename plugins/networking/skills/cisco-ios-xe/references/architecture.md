# Cisco IOS-XE Architecture Reference

## Linux-Based Architecture

IOS-XE runs on a hardened Linux kernel (CentOS/RHEL lineage). The architecture separates control, data, and management planes:

```
┌─────────────────────────────────────────────┐
│           IOS CLI / Configuration           │
├─────────────────────────────────────────────┤
│  IOSd (IOS daemon) — monolithic IOS process │
├────────────────┬────────────────────────────┤
│  IOS XE DB     │  Forwarding Manager (FMan) │
│  (in-memory    │  — translates config to    │
│   config/state │    hardware/FP tables       │
│   datastore)   │                            │
├────────────────┴────────────────────────────┤
│         Linux Kernel (process scheduler,    │
│         memory mgmt, device drivers)        │
├─────────────────────────────────────────────┤
│       ASICs / FPGAs / NPUs (data plane)     │
└─────────────────────────────────────────────┘
```

### IOSd Process

- Runs as a single large process implementing all routing, switching, and protocol logic
- IOS XE Database is an in-memory transactional store for config/operational state
- Sub-package modularity allows independent component upgrades

### Process Isolation

- NETCONF agent, Guest Shell, EEM, telemetry run as separate Linux processes
- Crashes in auxiliary processes do not bring down IOSd
- Hardware acceleration via UADP ASIC (Catalyst 9000) or QuantumFlow Processor (ASR)

## YANG Models

Three families of YANG models:

### Cisco Native Models
- `Cisco-IOS-XE-native` covers the bulk of `show running-config`
- Feature-specific: `Cisco-IOS-XE-bgp`, `Cisco-IOS-XE-ospf`, `Cisco-IOS-XE-vlan`
- Most complete coverage; 1:1 mapping with CLI

### OpenConfig Models
- Vendor-neutral: `openconfig-interfaces`, `openconfig-bgp`, `openconfig-network-instance`
- May have coverage gaps vs native models

### IETF Models
- Standards-based: `ietf-interfaces` (RFC 8343), `ietf-routing` (RFC 8349)
- Most limited but most portable

## NETCONF (Port 830)

```
netconf-yang
netconf-yang ssh port 830
```

Operations: `<get>`, `<get-config>`, `<edit-config>`, `<commit>`, `<lock>`, `<validate>`

Datastores: running, candidate (requires `netconf-yang candidate-datastore`), startup

Config translation (17.7+): `show running-config | format netconf-xml` and `| format restconf-json`

## RESTCONF (HTTPS)

```
ip http secure-server
restconf
```

Base URLs: `https://<device>/restconf/data/` and `https://<device>/restconf/operations/`

HTTP methods: GET (read), PUT (create/replace), POST (create), PATCH (merge), DELETE (delete)

## gNMI / Streaming Telemetry

```
gnmi-yang
gnmi-yang server
gnmi-yang port 9339
```

Operations: Get, Set, Subscribe (SAMPLE, ON_CHANGE, ONCE), Capabilities

Telemetry subscriptions push data without polling:
```
telemetry ietf subscription 101
 encoding encode-kvgpb
 filter xpath /interfaces/interface/statistics
 stream yang-push
 update-policy periodic 6000
 receiver ip address 10.0.0.10 57000 protocol grpc-tcp
```

## SD-Access Architecture

| Plane | Technology | Function |
|---|---|---|
| Management | Catalyst Center | Intent, automation, assurance |
| Control | LISP (RFC 6830) | EID-to-RLOC mapping database |
| Data | VXLAN (RFC 7348) | Overlay encapsulation (UDP 4789) |
| Policy | CTS/TrustSec (SGT) | Group-based policy enforcement |

### LISP Control Plane
- Map Server (MS): Accepts registrations, maintains EID-to-RLOC database
- Map Resolver (MR): Handles map requests from ITRs
- xTR: Edge nodes registering endpoints and encapsulating traffic

### CTS/SGT
- SGT values (1-65535) assigned at ingress based on identity, subnet, or VLAN
- Policies enforced at egress without IP dependency
- Inline tagging or SGT Exchange Protocol (SXP) for non-CTS devices

## Catalyst Center Integration

- Intent-based provisioning, network discovery, REST API
- SD-Access fabric automation (LISP/VXLAN/SGT config across all nodes)
- Assurance: health scores, AI-driven anomaly detection, path trace
- PnP: devices contact `devicehelper.cisco.com` or local DHCP option 43 redirect

## Zero-Touch Provisioning

ZTP bootstrap: device boots without config, gets DHCP option 67 (bootfile URL), downloads Python script, Guest Shell executes it.

PnP: Cisco proprietary; DHCP option 43, DNS (`pnpserver.<domain>`), or cloud redirect to Catalyst Center.

## Guest Shell

LXC container with Python 3 runtime:
```
iox
guestshell enable
guestshell run bash
guestshell run python3 /flash/myscript.py
```

Python `cli` module: `cli.execute("show interfaces")` and `cli.configure("interface Gi1\n description Test")`

## EEM (Embedded Event Manager)

Event-driven automation reacting to syslog patterns, SNMP OID thresholds, CLI commands, timers, interface state changes, and OIR events.

Applets use `event` + `action` syntax. Python policies via `event manager policy my_policy.py`.

## StackWise / StackWise Virtual

### StackWise (Cat 9200/9300)
- Physical ring via dedicated cables, up to 8 members
- 480 Gbps ring bandwidth (Cat 9300)
- Single management plane (one IP, one config)

### StackWise Virtual (Cat 9400/9500/9600)
- Logical stack over standard 40G/100G links, 2 chassis
- DAD via PAgP, BFD, or fast-hello for split-brain detection
- SVL link carries control + management + data plane traffic
