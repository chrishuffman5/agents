# Cisco IOS-XE Architecture — Technical Deep Dive

## Overview

Cisco IOS XE was introduced in 2008 alongside the ASR 1000 Series Aggregation Services Routers, marking Cisco's architectural shift from a monolithic OS to a modular, Linux-based platform. The core design separates control, data, and management planes, enabling sub-component updates without full system disruption.

---

## Linux-Based Architecture

IOS XE runs on top of a Linux kernel (currently based on a hardened CentOS/RHEL lineage). The OS exposes standard Linux primitives but presents the familiar IOS CLI to operators.

### Key Architectural Layers

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

- IOSd is the main IOS daemon that implements all routing, switching, and protocol logic
- Runs as a single large process within Linux, leveraging the kernel for I/O, scheduling, and memory
- Sub-package modularity allows certain IOS XE components to be installed or upgraded independently
- The IOS XE Database (IOS XE DB) is an in-memory transactional store managing configuration and operational state, preventing inconsistencies during failures or partial updates

### Process Isolation Benefits

- Other processes (telemetry, NETCONF agent, Guest Shell, EEM) run as separate Linux processes
- Crashes in auxiliary processes do not bring down IOSd
- Linux scheduler dynamically allocates CPU to IOSd and hosted application processes
- Hardware acceleration via dedicated ASIC (QuantumFlow Processor on ASR, UADP on Catalyst 9000)

---

## YANG Data Models

IOS XE exposes its configuration and operational state through three families of YANG data models:

### 1. Cisco Native YANG Models
- `Cisco-IOS-XE-native` — main native model; covers the bulk of `show running-config`
- Feature-specific native models: `Cisco-IOS-XE-bgp`, `Cisco-IOS-XE-ospf`, `Cisco-IOS-XE-vlan`, etc.
- Published per-release at: https://github.com/YangModels/yang/tree/master/vendor/cisco/xe
- Most complete coverage; 1:1 mapping with IOS CLI constructs

### 2. OpenConfig Models
- Vendor-neutral models maintained by the OpenConfig Working Group
- IOS XE supports: `openconfig-interfaces`, `openconfig-bgp`, `openconfig-network-instance`, `openconfig-platform`, `openconfig-telemetry`
- Ideal for multi-vendor environments; may have coverage gaps vs. native models
- Path notation: `openconfig-interfaces:interfaces/interface[name=GigE1]/config`

### 3. IETF Models
- Standards-based: `ietf-interfaces` (RFC 8343), `ietf-routing` (RFC 8349), `ietf-ip`
- Most limited feature coverage but most portable across vendors
- Used for basic interface and routing state

### Model Discovery

```
# List all supported YANG models via NETCONF
<get>
  <filter>
    <netconf-state xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring">
      <schemas/>
    </netconf-state>
  </filter>
</get>
```

---

## NETCONF (Port 830)

NETCONF (RFC 6241) is an XML-based network management protocol transported over SSH.

### Enabling NETCONF

```
! Enable NETCONF-YANG agent
netconf-yang
netconf-yang ssh port 830

! Restrict access
ip access-list standard NETCONF-ACL
 permit 10.0.0.0 0.0.255.255
netconf-yang ssh ipv4 access-class NETCONF-ACL
```

### Verification Commands

```
show netconf-yang datastores
show netconf-yang sessions
show netconf-yang statistics
show platform software yang-management process
```

### NETCONF Operations

| Operation      | Description                                      |
|---------------|--------------------------------------------------|
| `<get>`        | Retrieve running state and config                |
| `<get-config>` | Retrieve configuration from a datastore          |
| `<edit-config>`| Modify configuration (merge/replace/delete)      |
| `<commit>`     | Commit candidate config to running               |
| `<lock>`       | Lock a datastore for exclusive access            |
| `<validate>`   | Validate configuration without applying          |

### NETCONF Datastores

- **running** — active configuration
- **candidate** — staging datastore (requires `netconf-yang candidate-datastore` on 17.x)
- **startup** — persistent startup configuration

### NETCONF Example: Get Interface State

```xml
<rpc message-id="1" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <get>
    <filter type="subtree">
      <interfaces-state xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
        <interface>
          <name>GigabitEthernet1</name>
        </interface>
      </interfaces-state>
    </filter>
  </get>
</rpc>
```

---

## RESTCONF (HTTPS)

RESTCONF (RFC 8040) provides a stateless HTTP/S interface for CRUD operations over YANG models.

### Default Port and Base URL

```
https://<device>/restconf/data/
https://<device>/restconf/operations/   # RPCs
https://<device>/restconf/yang-library-version
```

### Enable RESTCONF

```
ip http server
ip http secure-server
ip http authentication local
restconf
```

### RESTCONF Example: Get Interface

```bash
curl -s -u admin:password \
  -H "Accept: application/yang-data+json" \
  "https://192.168.1.1/restconf/data/ietf-interfaces:interfaces/interface=GigabitEthernet1"
```

### Config Translation (17.7+)

```
show running-config | format netconf-xml
show running-config | format restconf-json
```

### HTTP Methods Mapping

| HTTP Method | YANG Operation          |
|-------------|------------------------|
| GET         | Read                   |
| PUT         | Create or Replace      |
| POST        | Create (returns 201)   |
| PATCH       | Merge/Update           |
| DELETE      | Delete                 |

---

## gNMI / gRPC Streaming Telemetry

gNMI (gRPC Network Management Interface) provides a gRPC-based protocol for configuration management and streaming telemetry.

### Enable gNMI

```
gnmi-yang
gnmi-yang server
gnmi-yang port 9339
gnmi-yang secure-server
gnmi-yang secure-client-auth
```

### gNMI Operations

| Operation   | Purpose                                          |
|-------------|--------------------------------------------------|
| `Get`       | Retrieve operational or config data              |
| `Set`       | Apply configuration changes                      |
| `Subscribe` | Stream telemetry (SAMPLE, ON_CHANGE, ONCE)       |
| `Capabilities` | Discover supported models and encodings       |

### Model-Driven Telemetry (MDT)

Telemetry subscriptions push data to collectors without polling:

```
! Configure MDT subscription
telemetry ietf subscription 101
 encoding encode-kvgpb
 filter xpath /interfaces/interface/statistics
 stream yang-push
 update-policy periodic 6000
 receiver ip address 10.0.0.10 57000 protocol grpc-tcp
```

### Subscription Modes

- **Periodic**: Data pushed at fixed interval (cadence in centiseconds)
- **On-Change**: Data pushed only when values change
- **Once**: Single snapshot, then subscription terminates

### Telemetry Verification

```
show telemetry ietf subscription all
show telemetry ietf subscription 101 detail
show telemetry internal sensor path /interfaces/interface/statistics
```

---

## SD-Access (Software-Defined Access)

SD-Access is Cisco's intent-based networking solution for campus networks, built on a fabric using LISP (control plane) and VXLAN (data plane).

### Architecture Planes

| Plane       | Technology                    | Function                              |
|-------------|-------------------------------|---------------------------------------|
| Management  | Catalyst Center (DNA Center)  | Intent, automation, assurance         |
| Control     | LISP (RFC 6830)               | Endpoint-to-RLOC mapping database     |
| Data        | VXLAN (RFC 7348)              | Overlay encapsulation                 |
| Policy      | CTS/TrustSec (SGT)            | Group-based policy enforcement        |

### LISP Control Plane

- **Map Server (MS)**: Accepts registrations from xTRs, maintains EID-to-RLOC mapping database
- **Map Resolver (MR)**: Handles map requests from ITRs, queries MS
- **xTR (Ingress/Egress Tunnel Router)**: Edge nodes that register endpoints and encapsulate traffic
- EID (Endpoint Identifier) = endpoint IP/MAC address
- RLOC (Routing Locator) = underlay IP of the xTR

```
! LISP registration on edge node
router lisp
 locator-set UNDERLAY
  IPv4-interface Loopback0 priority 10 weight 10
 !
 eid-table default instance-id 0
  database-mapping 10.0.1.0/24 locator-set UNDERLAY
```

### VXLAN Data Plane

- Encapsulates Layer 2/3 frames in UDP (port 4789)
- Uses VNID (24-bit Virtual Network ID) for tenant isolation — L2 VNI per VLAN, L3 VNI per VRF
- SD-Access uses VXLAN with a modified header carrying the SGT

### CTS/SGT (Scalable Group Tags)

```
! Assign SGT to users
cts role-based sgt-map 10.0.1.0/24 sgt 10

! SGT policy enforcement
cts role-based permissions from 10 to 20 list PERMIT-WEB
```

- SGT values (1-65535) assigned at ingress based on: 802.1X identity, subnet, VLAN
- Policies enforced at egress without IP address dependency
- Inline tagging (CTS) or SGT Exchange Protocol (SXP) for non-CTS-capable devices

---

## Catalyst Center (DNA Center) Integration

Catalyst Center (formerly DNA Center) is the management plane for SD-Access and broader IOS XE automation.

### Key Capabilities

- **Intent-based provisioning**: Translates business intent to device configuration
- **Network Discovery**: SNMP/SSH/CDP-based device discovery
- **REST API**: Northbound API for integration with ITSM, IPAM, and custom tools
- **SD-Access fabric provisioning**: Automates LISP/VXLAN/SGT configuration across all nodes
- **Assurance**: Network health scores, AI-driven anomaly detection, path trace

### Catalyst Center API (v2.x)

```bash
# Authenticate
POST https://catalyst-center/dna/system/api/v1/auth/token
Authorization: Basic <base64 credentials>

# Get devices
GET https://catalyst-center/dna/intent/api/v1/network-device

# Get device detail
GET https://catalyst-center/dna/intent/api/v1/network-device/{id}
```

### PnP (Plug and Play) via Catalyst Center

- Devices contact PnP server (`devicehelper.cisco.com` or local redirect via DHCP option 43)
- Catalyst Center claims device, assigns site, pushes day-0 configuration
- Requires Cisco Smart Account linkage for cloud redirect

---

## Zero-Touch Provisioning (ZTP / PnP)

### ZTP (Open Standard)

ZTP allows automated device provisioning at first boot without manual intervention.

```
! DHCP server provides script location
ip dhcp pool ZTP-POOL
 network 192.168.1.0 255.255.255.0
 default-router 192.168.1.1
 option 67 ascii http://10.0.0.10/ztp/ztp.py
```

ZTP bootstrap sequence:
1. Device boots, no startup config
2. DHCP request, gets option 67 (bootfile URL)
3. Downloads Python script via HTTP
4. Guest Shell executes script, applies configuration

### PnP (Cisco Plug and Play)

- Cisco proprietary; integrates tightly with Catalyst Center
- Discovery via DHCP option 43, DNS (`pnpserver.<domain>`), or cloud redirect
- Supports image upgrade, configuration provisioning, and certificate enrollment

---

## Guest Shell

Guest Shell is a Linux container (LXC) embedded in IOS XE, providing a persistent Python runtime environment.

### Enable and Access Guest Shell

```
! Enable IOx application framework
iox

! Enable Guest Shell
guestshell enable

! Access the shell
guestshell run bash
guestshell run python3 /flash/myscript.py
```

### Python on-box Capabilities

- Full Python 3 environment with access to Cisco-provided libraries
- `cli` module: Run IOS XE CLI commands from Python
- `eem` module: Interface with EEM policies

```python
import cli
output = cli.execute("show interfaces GigabitEthernet1")
print(output)

# Configure via Python
cli.configure("interface GigabitEthernet1\n description Test\n")
```

### Persistent Storage

- Guest Shell home directory: `/home/guestshell/`
- Access to IOS XE flash: `/flash/` (mapped from IOS `flash:`)
- Survives reloads; `guestshell destroy` wipes the container

---

## EEM (Embedded Event Manager)

EEM provides event-driven automation directly on the device, reacting to syslog messages, SNMP traps, CLI, timers, and hardware events.

### EEM Applet (Simple)

```
event manager applet LINK-DOWN
 event syslog pattern "Interface GigabitEthernet1, changed state to down"
 action 1.0 syslog msg "ALERT: GigabitEthernet1 went down - initiating recovery"
 action 2.0 cli command "enable"
 action 3.0 cli command "configure terminal"
 action 4.0 cli command "interface GigabitEthernet1"
 action 5.0 cli command "shutdown"
 action 6.0 wait 5
 action 7.0 cli command "no shutdown"
```

### EEM Python Policy

```
event manager policy my_policy.py type user persist-time 3600 username admin
```

```python
# my_policy.py
import eem
import cli

eem.action_syslog(msg="EEM Python triggered")
output = cli.execute("show interfaces")
# Process and respond
```

### EEM Event Types

| Event Detector  | Description                              |
|----------------|------------------------------------------|
| `syslog`        | Pattern match on syslog messages         |
| `snmp`          | SNMP OID threshold crossing             |
| `cli`           | CLI command pattern match                |
| `timer`         | Periodic, countdown, absolute timers     |
| `interface`     | Interface state changes                  |
| `oir`           | Online insertion/removal events          |
| `track`         | IP SLA / object tracking changes         |

---

## StackWise / StackWise Virtual

### StackWise (Physical Stack — Catalyst 9200/9300)

- Physical ring topology via dedicated StackWise cables
- Up to 8 members in a stack (Catalyst 9300)
- Single management plane: one IP, one config, active/standby supervisor roles
- Bandwidth: 480 Gbps (StackWise-480) on Catalyst 9300

```
! Stack member priority (higher = preferred active)
switch 1 priority 15
switch 2 priority 10

! Renumber stack member
switch 3 renumber 2
```

### StackWise Virtual (SVL — Catalyst 9400/9500/9600)

- Logical stack over standard 40G/100G links — no dedicated cables
- Two chassis appear as a single logical switch
- SVL link carries control, management, and data plane traffic
- Dual-Active Detection (DAD) via PAGP, BFD, or fast-hello to handle split-brain

```
! Configure StackWise Virtual
stackwise-virtual
 domain 1
!
interface TenGigabitEthernet1/0/1
 stackwise-virtual link 1
!
interface TenGigabitEthernet1/0/2
 stackwise-virtual dual-active-detection
```

### StackWise vs. Traditional HA Comparison

| Feature                | StackWise          | StackWise Virtual     | VSS (older)        |
|-----------------------|--------------------|-----------------------|--------------------|
| Platforms             | Cat 9200/9300      | Cat 9400/9500/9600    | Cat 4500/6500      |
| Physical link         | Dedicated ring     | Standard 40/100G      | Dedicated VSL      |
| Max members           | 8                  | 2                     | 2                  |
| Upgrade               | Rolling (ISSU)     | SSO + ISSU            | SSO + ISSU         |

---

## References

- Cisco IOS XE Programmability Config Guide 17.15: https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/1715/b_1715_programmability_cg/
- Cisco IOS XE NETCONF/YANG Config Guide: https://www.cisco.com/c/en/us/support/docs/storage-networking/management/200933-YANG-NETCONF-Configuration-Validation.html
- SD-Access Design Guide: https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/cisco-sda-design-guide.html
- IOS XE Hardening Guide: https://sec.cloudapps.cisco.com/security/center/resources/IOS_XE_hardening
- gNMI Lab (GitHub): https://github.com/jeremycohoe/cisco-ios-xe-programmability-lab-module-5-gnmi
