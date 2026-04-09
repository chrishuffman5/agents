# Emerging NOS Deep Dive — SONiC + Containerlab + DENT

## Overview

The open networking movement has produced three notable network operating systems: **SONiC** (cloud hyperscale NOS from Microsoft, now Linux Foundation), **DENT** (enterprise edge Linux switchdev NOS from Amazon/Linux Foundation), and the container-native lab framework **Containerlab** (used to emulate any NOS in CI/CD pipelines). Together they represent the disaggregated networking stack: commodity ASICs + open NOS + orchestration.

---

# SONiC (Software for Open Networking in the Cloud)

## Origins and Governance

- Originated at **Microsoft Azure** as a replacement for vendor-bundled NOS on whitebox switches.
- Open-sourced in 2016; contributed to **Linux Foundation** as the **SONiC Foundation** (2023+).
- Now runs on: Microsoft Azure, Alibaba Cloud (100,000+ devices across 28 regions / 86 AZs), Orange Telecom (telco disaggregation), and growing enterprise deployments.
- **Arista Networks** joined SONiC Foundation as a Premier Member (2025), alongside Auradine, Nexthop.ai, and STORDIS.
- Current release cadence: ~semi-annual; **2025.11** the most recent major release.

---

## Architecture

SONiC's architecture is distinguished by its **Redis-centric database bus** and strict separation between NOS logic and hardware forwarding:

### Redis Database (CONFIG_DB / ASIC_DB / STATE_DB / APP_DB)
- All system state stored in Redis key-value databases.
- **CONFIG_DB** — Desired configuration (interfaces, BGP, ACL, VLAN, routes). Written by operators or automation.
- **APP_DB** — Application-derived state (FRR route table, DHCP bindings).
- **ASIC_DB** — Hardware programming requests; SAI objects translated from application state.
- **STATE_DB** — Operational state (link up/down, port counters, health).
- Databases communicate via pub/sub; daemons subscribe to relevant tables.

### SAI (Switch Abstraction Interface)
- The critical abstraction layer between SONiC applications and ASIC hardware.
- SAI defines a standardized API (C-based) for hardware operations: create/delete/modify forwarding tables, set port attributes, manage tunnels.
- Each ASIC vendor provides a **SAI implementation (libsai)** for their silicon.
- SONiC application code never calls ASIC directly; always through SAI.
- **ASIC Vendors with SAI support**: Broadcom (Trident, Tomahawk, Jericho), Marvell (Prestera, AlleyCat), NVIDIA/Mellanox (Spectrum), Intel (Tofino), Barefoot.

### SwSS (Switch State Service)
- The orchestration layer; monitors CONFIG_DB and translates high-level configuration to ASIC_DB SAI objects.
- Contains: `orchagent` (main orchestrator), `neighsyncd`, `portsyncd`, `intfsyncd`, `routesyncd`.
- Converts intent (e.g., "route 10.0.0.0/8 via 192.168.1.1") into SAI calls that program the ASIC forwarding table.

### syncd
- Bridge between ASIC_DB and the actual SAI hardware library.
- Subscribes to ASIC_DB; calls the vendor libsai to program hardware in real time.
- Also reports ASIC notifications (link state changes, counters) back to STATE_DB.

### teamd
- Manages LAG/LACP; programs bonding state into ASIC via SAI.

### BGP (FRRouting — FRR)
- FRRouting (`bgpd`, `zebra`, `staticd`) provides BGP, OSPF, IS-IS, and static routing.
- Routes learned by FRR → written to APP_DB → orchestrated into ASIC_DB by SwSS → programmed by syncd via SAI.
- Same FRR engine used by OPNsense, DENT, and Cumulus Linux — shared ecosystem.

---

## Supported ASICs

| Vendor | Silicon Families |
|---|---|
| Broadcom | Trident 2/3/4, Tomahawk 2/3/4, Jericho (carrier) |
| Marvell | Prestera (98CX series), AlleyCat (98DX series) |
| NVIDIA/Mellanox | Spectrum 1/2/3/4 |
| Intel | Tofino (P4-programmable) |
| Barefoot | Tofino 2 |
| Innovium | TERALYNX |

---

## ODM Hardware

SONiC is commonly deployed on Open Compute Project (OCP)-compatible whitebox switches from:

- **Dell** — S52xx, S54xx series (Dell-branded SONiC Enterprise available via Dell)
- **Edgecore Networks** — AS9516, AS7726, ECS4100 series; STORDIS (Edgecore-backed) provides commercial support
- **Celestica** — DX010, DS4000 series
- **Accton** — AS7535, AS7726 (sold under Edgecore brand)
- **UfiSpace** — S9600 series (carrier-grade)
- **Supermicro** — SSE series

---

## CLI

SONiC CLI evolved through several generations:

### show / config (legacy bash CLI)
```bash
show version                    # SONiC version, platform, ASIC
show interfaces status          # All interface operational status
show interfaces counters        # Packet counters per interface
show ip route                   # IP routing table
show ip bgp summary             # BGP neighbor summary
show vlan brief                 # VLAN configuration
show mac                        # MAC address table
config interface ip add Ethernet0 192.168.1.1/24
config vlan add 100
config vlan member add 100 Ethernet4
config save                     # Persist config to /etc/sonic/config_db.json
config load /etc/sonic/config_db.json   # Reload config from file
```

### sonic-cli (KLISH-based CLI — newer)
- KLISH framework provides a familiar IOS-like CLI experience.
- Supported in newer SONiC builds and enterprise SONiC distributions.
- Hierarchical mode-based (global/interface/router-bgp) command structure.

---

## ConfigDB and YANG Models

- All SONiC configuration expressed in **ConfigDB** (Redis) or the on-disk `/etc/sonic/config_db.json`.
- **YANG models** — SONiC maintains YANG data models for all features; enables model-driven configuration validation and gNMI/RESTCONF support.
- `sonic-cfggen` tool converts ConfigDB JSON to YANG and back; used in provisioning workflows.
- Ansible `network.sonic` collection and Terraform SONiC providers consume YANG models.

---

## SONiC-DASH (Disaggregated API for SONiC Hosts)

- DASH extends SAI to cover **SmartNICs** and **Smart Switches** (host-side network functions).
- Defines SAI-like APIs for: VNET routing, NAT, load balancing, ACL, metering — functions executed on programmable NICs.
- **Use cases**: cloud-native load balancer offload, virtual network gateway offload, SDN data plane on host.
- Implemented by Microsoft Azure (SmartNICs for Azure SDN) and adopters including NVIDIA BlueField DPUs.
- GitHub: `sonic-net/DASH`

---

## Use Cases

1. **Hyperscale Data Center** — Azure, Alibaba: full BGP, large routing tables, ECMP, VXLAN, QoS — all managed via automation.
2. **Enterprise DC Fabric** — Leaf/spine with eBGP underlay and VXLAN/EVPN overlay; cost savings vs. proprietary NOS.
3. **Telco Disaggregation** — Orange running SONiC for IP/MPLS edge; carrier-grade support via Jericho ASICs.
4. **AI/ML Networking** — SONiC Foundation promoting SONiC for AI datacenter workloads (high-bandwidth, low-latency, RoCEv2 support).

---

# Containerlab

## Overview

Containerlab is an open-source tool for orchestrating **container-based network labs**. It enables building realistic multi-vendor network topologies using container images of real network operating systems. Current version: **v0.73** (reviewed March 2026).

- GitHub: `srl-labs/containerlab`
- Licensing: BSD
- Supports: Linux (x86_64, arm64), macOS (via Rosetta/UTM), WSL2 (Windows Subsystem for Linux)

---

## Core Concepts

### Topology YAML Files
- Labs defined in `.clab.yml` topology files (YAML format).
- Declarative: specify nodes, their types (kinds), and links.

```yaml
name: my-lab

topology:
  nodes:
    spine1:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux
    leaf1:
      kind: ceos
      image: ceos:4.32.0F
    router1:
      kind: linux
      image: frrouting/frr:latest

  links:
    - endpoints: ["spine1:e1-1", "leaf1:et1"]
    - endpoints: ["spine1:e1-2", "router1:eth1"]
```

### Lab Lifecycle
```bash
# Deploy lab
sudo clab deploy -t topology.clab.yml

# List running labs
sudo clab inspect -a

# Connect to a node
ssh admin@clab-my-lab-spine1

# Destroy lab
sudo clab destroy -t topology.clab.yml

# Graph topology (HTML/draw.io/Mermaid/Graphviz)
sudo clab graph -t topology.clab.yml
```

---

## Supported Network Operating Systems

Containerlab provides `kind:` definitions for dozens of platforms:

| Kind | NOS | Notes |
|---|---|---|
| `nokia_srlinux` | Nokia SR Linux | Native container image; first-class support |
| `ceos` | Arista cEOS | Container EOS; requires Arista license |
| `xrd` | Cisco XRd | IOS XR container; requires Cisco entitlement |
| `linux` | Any Linux/FRR | Generic; run FRR, BIRD, GoBGP in any container |
| `sonic-vs` | SONiC VS | SONiC virtual switch container |
| `sonic-vm` | SONiC VM | VM-based SONiC via vrnetlab |
| `juniper_crpd` | Juniper cRPD | Containerized Routing Protocol Daemon |
| `vr-vmx` | Juniper vMX | VM-based via vrnetlab |
| `vr-xrv9k` | Cisco XRv9K | VM-based via vrnetlab |
| `vr-csr` | Cisco CSR1000v | VM-based via vrnetlab |
| `dell_sonic` | Dell Enterprise SONiC | Dell-branded SONiC container |
| `ovs-bridge` | Open vSwitch | Bridging/overlay testing |
| `bridge` | Linux bridge | Simple L2 bridging node |

---

## v0.73 Notable Features

- **VSCode Extension** — Community-built IDE integration; Containerlab topology management from VS Code UI; graphical topology view.
- **Enhanced Graph Command** — `clab graph` now outputs: HTML (interactive), draw.io, Mermaid diagram, Graphviz DOT format.
- **exec: key in topology** — Run commands inside containers at startup directly in the topology file; eliminates need for separate provisioning scripts.
- **Improved macOS support** — Better integration with UTM/Lima for ARM-based Macs.
- **WSL2 support** — Full Containerlab functionality under Windows Subsystem for Linux 2.

---

## CI/CD Integration

Containerlab's single-binary design and code-based topology files make it ideal for network CI/CD:

- **GitHub Actions** — Deploy topology, run tests, destroy; automated on pull request.
- **GitLab CI** — Same workflow; single `clab deploy` command in pipeline step.
- **pytest-net** / **nettests** — Python test frameworks that interact with running Containerlab nodes for route verification, connectivity tests, and feature validation.
- Network automation teams use Containerlab to test Ansible playbooks, Terraform configs, and Python netmiko/napalm scripts against realistic topologies before production deployment.

---

# DENT (DentOS)

## Overview

DENT is a Linux Foundation project creating an open-source NOS for **distributed enterprise edge and retail networking**. Current version: **DentOS 3.0 "Cynthia"** (released April 2023; ongoing development).

- Focus: enterprise branch/store/campus networking; PoE switching; cost-sensitive deployments.
- Key adopter: **Amazon** (Just Walk Out Technology infrastructure).

---

## Linux switchdev Model

DENT's fundamental difference from SONiC: it uses the **Linux kernel switchdev** driver model instead of SAI.

### switchdev vs SAI
| Aspect | DENT (switchdev) | SONiC (SAI) |
|---|---|---|
| Abstraction layer | Linux kernel switchdev driver | SAI (vendor-provided library) |
| Route programming | Linux networking stack (ip route, netlink) → offloaded to ASIC via switchdev | Via SONiC SwSS → syncd → vendor SAI |
| OS integration | Native Linux tooling works directly | Requires SONiC-specific CLI/API |
| ASIC support | Kernel driver per ASIC family | Vendor-provided SAI per ASIC |
| Transparency | Full Linux stack visibility | Abstracted behind SAI |

- switchdev means Linux's own routing table is the source of truth; forwarding entries are "offloaded" to hardware automatically when the driver supports it.
- Standard Linux tools (`ip`, `bridge`, `tc`, `iproute2`) manage the switch; hardware acceleration is transparent.

---

## Key Features

- **PoE and PoE+** — Power over Ethernet management for cameras, APs, VoIP phones; critical for retail/branch deployments.
- **IPv6** — Full IPv6 support including NDP, stateless autoconfiguration.
- **NAT** — Network Address Translation via Linux netfilter; offloaded to ASIC where supported.
- **L2 Bridging** — VLAN-aware bridging; STP/RSTP.
- **FRRouting (FRR)** — Same FRR stack as SONiC and OPNsense; BGP, OSPF for branch uplinks.
- **Network Management** — YANG models + NETCONF/RESTCONF for programmatic management (DentOS 3.0 addition).
- **Rapid Release Cycle** — 3.0 introduced a more frequent release cadence for faster security patches and features.

---

## Amazon Just Walk Out

Amazon uses DentOS to power the networking infrastructure behind **Just Walk Out Technology** (cashierless retail):

- Connects and manages thousands of edge devices: cameras, weight sensors, entry/exit gates, access points.
- Deployed across Amazon Go stores and partner retail locations.
- Amazon's choice demonstrates production readiness for high-density PoE branch networking.
- Amazon is a DENT founding member and primary industrial driver of the project.

---

## Enterprise Edge and Retail Focus

DENT targets use cases where SONiC is over-engineered:

- **Retail stores** — High port density L2 switching with PoE; simplified management; cost-sensitive.
- **Warehouses** — Large sensor/device deployments; automation-friendly via Linux tooling.
- **Branch offices** — WAN uplink routing via FRR; local L2 switching; remote management.
- **Campus edge** — Replace proprietary switches with open, commodity hardware.

DENT's value proposition: **open-source at the same cost as locked proprietary switches** with more flexibility and no vendor lock-in.

---

## Comparison: SONiC vs DENT vs OPNsense

| Dimension | SONiC | DENT | OPNsense |
|---|---|---|---|
| Hardware target | Data center switching ASIC | Enterprise edge/branch switch | x86 router/firewall |
| Hardware abstraction | SAI (vendor lib) | switchdev (Linux kernel) | FreeBSD pf |
| Use case | DC fabric, hyperscale | Enterprise edge, retail, PoE | NGFW, routing, VPN |
| Forwarding plane | Hardware ASIC (Broadcom/Mellanox) | Hardware ASIC (switchdev-enabled) | Software (x86 CPU) |
| Routing | FRR | FRR | FRR (plugin) |
| Management | Redis/YANG/gNMI | NETCONF/YANG/Linux tools | REST API / WebGUI |
| Foundation | Linux Foundation | Linux Foundation | Community (Deciso) |

---

## References

- [SONiC Architecture Deep Dive — SONiC Foundation](https://sonicfoundation.dev/deep-dive-into-sonic-architecture-design/)
- [SONiC DASH GitHub](https://github.com/sonic-net/DASH)
- [SONiC OCP EMEA 2025](https://sonicfoundation.dev/sonic-the-leading-open-nos-for-cloud-and-enterprise-networking-showcases-innovation-at-ocp-emea-summit-2025/)
- [SONiC Enterprise Adoption — ONUG](https://onug.net/blog/state-of-enterprise-sonic-adoption-the-open-networking-shift-accelerates-in-the-ai-era/)
- [Containerlab GitHub](https://github.com/srl-labs/containerlab)
- [Containerlab v0.73 Review](https://opensourcenetworksimulators.com/2026/03/containerlab-network-emulator-v0-73-review/)
- [DentOS 3.0 Announcement — Linux Foundation](https://www.linuxfoundation.org/press/dentos-3.0-unveiled-open-source-nos-powering-distributed-enterprise-edge-brings-network-management-scalability-and-security-via-new-rapid-release-cycle)
- [DentOS GitHub](https://github.com/dentproject/dentOS)
