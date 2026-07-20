# F5 BIG-IP Architecture Reference

## TMM (Traffic Management Microkernel)

TMM is the core data-plane engine of BIG-IP. It is a custom high-performance packet processing system that bypasses the standard Linux kernel networking stack.

### TMM Design
- Runs as a userspace process on top of TMOS (modified CentOS)
- Handles ALL traffic processing: SSL termination, load balancing, iRules execution, persistence, compression, caching, NAT, protocol inspection
- Single-threaded per TMM instance; multiple TMM instances for multi-core scaling
- Each TMM instance handles a subset of connections determined by flow distribution
- CPU cores are dedicated exclusively to TMM (not shared with management plane)

### TMM Processing Pipeline
```
Packet arrives at ingress interface
    |
    v
Flow distribution (hash of src/dst IP, ports) -> assigns to TMM instance
    |
    v
Packet Filter (if configured)
    |
    v
AFM firewall evaluation (if licensed)
    |
    v
iRule FLOW_INIT event
    |
    v
Virtual server match (destination IP:port)
    |
    v
Profile processing (TCP, HTTP, SSL, compression)
    |
    v
Access policy (APM) evaluation (if configured)
    |
    v
Security policy (ASM/WAF) evaluation (if configured)
    |
    v
Load balancing decision (pool selection, member selection)
    |
    v
Persistence check (if configured)
    |
    v
SNAT/NAT translation
    |
    v
Forward to pool member
```

### TMM Memory Model
- TMM has its own memory allocation separate from the Linux host OS
- Connection table stored in TMM memory
- Persistence records stored in TMM memory
- iRule variables stored per-connection in TMM
- Memory sizing is critical: insufficient TMM memory causes connection refusals

## CMP (Clustered Multiprocessing)

CMP allows TMM to scale across multiple CPU cores:

### How CMP Works
- Multiple TMM instances (one per core assigned to TMM)
- Incoming traffic distributed across TMMs using a deterministic hash
- Hash typically based on: source IP, destination IP, source port, destination port, protocol
- Each TMM instance independently processes its assigned flows
- State shared between TMMs when necessary (persistence mirror, HA state)

### CMP on Different Platforms
- **Appliances (i-series, r-series)**: TMM instances across physical cores
- **VIPRION chassis**: TMM instances across blades, each blade has multiple cores
- **Virtual Edition (VE)**: TMM instances across vCPUs assigned to the VM

### DAG (Disaggregation)
On VIPRION chassis, the CMP Disaggregation Agent distributes incoming traffic across blades before TMM processing. This ensures even distribution at the hardware level.

## TMOS (Traffic Management Operating System)

### TMOS Architecture Layers
```
+----------------------------------+
| GUI / Configuration Utility      |  <-- Web management interface
+----------------------------------+
| TMSH (CLI)                       |  <-- Command-line management
+----------------------------------+
| iControl REST / SOAP API         |  <-- Automation interfaces
+----------------------------------+
| mcpd (Master Control Program)    |  <-- Configuration daemon
+----------------------------------+
| TMM (data plane)                 |  <-- Packet processing
+----------------------------------+
| TMOS Kernel (modified CentOS)    |  <-- Operating system
+----------------------------------+
| Hardware / Hypervisor            |  <-- Physical or virtual platform
+----------------------------------+
```

### mcpd (Master Control Program Daemon)
- Central configuration management process
- All configuration changes (GUI, TMSH, API) go through mcpd
- mcpd validates configuration and pushes changes to TMM
- Configuration stored in `/config/bigip.conf` and related files

### Configuration Objects Hierarchy
```
/Common/                     # Default partition (shared objects)
  /Common/VS_APP             # Virtual server
  /Common/POOL_APP           # Pool
  /Common/NODE_APP1          # Node
  /Common/PROFILE_SSL        # SSL profile
  /Common/IRULE_REDIRECT     # iRule
```

Partitions provide multi-tenant configuration isolation. Non-Common partitions cannot reference objects in other non-Common partitions.

## Module Architecture

### Module Licensing
BIG-IP modules are individually licensed and activated:
- **LTM** (Local Traffic Manager): Foundation -- required for all deployments
- **GTM / BIG-IP DNS**: Global Server Load Balancing
- **ASM / Advanced WAF**: Web Application Firewall
- **APM** (Access Policy Manager): Authentication, VPN, SSO
- **AFM** (Advanced Firewall Manager): Network firewall
- **AVR** (Application Visibility and Reporting): Analytics

### Module Processing Order
The order in which modules process traffic is fixed:
1. **AFM** (network firewall) -- first; can deny before any other processing
2. **LTM** (load balancing) -- virtual server match, pool selection
3. **APM** (access policy) -- authentication, authorization
4. **ASM** (WAF) -- application security inspection

This order matters: AFM rules are evaluated before LTM, so an AFM deny rule blocks traffic before it reaches the virtual server. ASM is last, so WAF inspection happens after authentication (APM).

## High Availability Architecture

### Device Trust
Cryptographic trust relationship between BIG-IP devices using x.509 certificates. Trust must be established before creating device groups.

### Device Groups
| Type | Purpose |
|---|---|
| Sync-Failover | Configuration sync + automatic failover |
| Sync-Only | Configuration sync only (no failover) |

### Traffic Groups
Traffic groups are the failover unit. Each traffic group:
- Contains a set of floating self-IPs and virtual addresses
- Has an "active" device (currently handling traffic for those IPs)
- Can fail over to another device in the device group
- Has configurable failover criteria (HA order, load-aware)

**MAC Masquerade**: Optional feature where a shared MAC address is used for floating IPs. Reduces failover time by eliminating gratuitous ARP processing.

### Failover Triggers
- **Heartbeat failure**: No heartbeat from peer within timeout period
- **Network failover**: Dedicated failover network between peers
- **HA group scoring**: Monitor objects contribute to a score; failover when score drops below threshold
- **Manual failover**: Administrator-initiated via GUI/TMSH

### Config Sync Mechanics
- **Incremental sync**: Only changed objects replicated (default, efficient)
- **Full sync**: Entire configuration pushed (used after device replacement or major changes)
- **Sync direction**: Push (from source to peer) or Pull (peer requests from source)
- **Conflict resolution**: Last sync wins; manual review recommended for conflicting changes

### HA Network Design
```
+-------------+          +-------------+
|  BIG-IP A   |          |  BIG-IP B   |
|  (Active)   |          |  (Standby)  |
+------+------+          +------+------+
       |                        |
       +----[ HA VLAN ]--------+    <-- Dedicated failover/sync
       |                        |
       +----[ Mgmt VLAN ]------+    <-- Management
       |                        |
       +----[ External VLAN ]--+    <-- Client-facing (floating VIP)
       |                        |
       +----[ Internal VLAN ]--+    <-- Server-facing (floating self-IP)
```

## BIG-IQ Centralized Management

BIG-IQ manages fleets of BIG-IP devices:
- **Device inventory**: Discover, backup, restore, upgrade BIG-IP instances
- **Centralized policy**: Deploy LTM, ASM, APM, AFM policies across devices
- **License management**: Utility licensing (ELA, PAYG), pool licensing
- **Analytics**: Application performance data from all managed devices
- **Access management**: Centralized APM policy lifecycle
- **WAF management**: Centralized ASM policy management

## F5 Distributed Cloud (XC)

F5's SaaS platform (formerly Volterra):
- **App-to-App Networking**: Cross-cloud, edge, and on-prem connectivity
- **Distributed Cloud WAF**: Cloud-delivered WAF with ASM rule engine
- **Bot Defense**: ML-powered bot mitigation as a service
- **API Security**: Automatic API discovery, schema enforcement
- **Network Connect**: SD-WAN-like connectivity between cloud VPCs and on-prem
- **Customer Edge (CE)**: Virtual appliance deployed on-prem, connects to XC PoPs

### XC and BIG-IP Integration
- BIG-IP LTM can front-end applications that also use XC services
- XC WAF can complement on-prem ASM for hybrid security posture
- XC Network Connect can provide multi-cloud connectivity to BIG-IP-managed apps
