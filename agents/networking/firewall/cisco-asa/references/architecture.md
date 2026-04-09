# Cisco ASA Architecture Reference

## Security Levels

Interfaces assigned levels 0 (lowest/outside) to 100 (highest/inside):
- Higher -> Lower: Permitted by default (NAT may apply)
- Lower -> Higher: Denied unless permitted by ACL
- Same -> Same: Denied unless `same-security-traffic permit inter-interface`

## Operating Modes

### Routed Mode (Default)
- L3 router/gateway; each interface in separate subnet
- NAT typically required; supports all features (VPN, ACL, MPF, failover, clustering)

### Transparent Mode
- L2 bridge; no IP on data interfaces (management IP on BVI)
- Up to 250 bridge groups; ACLs, MPF inspection, ARP inspection supported
- Does NOT support: NAT, routing protocols, DHCP server, VPN termination

### Multiple Context Mode
- Independent virtual firewalls with own interfaces, ACLs, NAT, routing
- System context manages chassis; user contexts are independent firewalls
- Supports routed and transparent per context (not mixed)
- FTD does NOT support contexts

## Failover

### Active/Standby
- Active owns IP/MAC; standby synchronized
- Stateful: connections, NAT xlate, ARP, VPN tunnels, routing replicated
- VPN sessions survive failover
- Triggers: interface failure, hardware failure, process crash, manual
- Dedicated failover link (100Mbps+ recommended)

### Active/Active
- Requires multi-context mode
- Two failover groups; each active on different ASA
- Each group independently fails over
- VPN only on admin context (significant limitation)

## Clustering (Firepower 4100/9300)

- Up to 16 nodes as single logical ASA
- Control node: management plane, routing elections
- Data nodes: traffic forwarding via Spanned EtherChannel
- CCL (Cluster Control Link) for inter-node state

### VPN in Clustering
- **Centralized**: All VPN to control node only (no scaling)
- **Distributed S2S (IKEv2, 9.20+)**: VPN distributed across data nodes
- AnyConnect/RA VPN remains centralized

## Modular Policy Framework (MPF)

### Components
1. **Class-Map**: Traffic classifier (match criteria)
2. **Policy-Map**: Actions for matched traffic (inspect, set connection, police, priority, drop)
3. **Service-Policy**: Binds policy to interface or global

### Processing Order
Actions applied in predefined order: `set connection` -> `inspect` -> `police`

### Default Inspections (class inspection_default)
DNS, FTP, H.323, HTTP, ICMP, ICMP error, MGCP, NetBIOS, PPTP, RSH, RTSP, SIP, Skinny, SNMP, SQLnet, SUNRPC, TFTP, XDMCP

## NAT (Same as FTD)

### Processing Order
1. Section 1 (Manual NAT, pre-auto): First match wins
2. Section 2 (Auto-NAT): Object-based, auto-ordered
3. Section 3 (Manual NAT, `after-auto`): Catch-all

## ASA 9.x Versions

### 9.20 (2023)
- IKEv2 enhancements, Secure Client cert pinning, BGP improvements
- Distributed S2S VPN (IKEv2) in cluster mode
- TLS 1.3 for management connections

### 9.22 (2024)
- Maintenance/patch release; security and stability fixes

### 9.24 (2025)
- Concurrent with planned FTD 10.0 release
- Long-term sustaining release track for ASA-only deployments

### General 9.x Policy (2023-2026)
- Sustaining engineering: security patches + critical bugs only
- No new feature development (all new features are FTD-exclusive)
- ASA with FirePOWER Services (SFR module) is EOL

## ASDM
- Java-based GUI; all config equivalent to CLI
- ASDM version tracks ASA version
- Java dependency increasingly problematic on modern OS
- Not recommended for complex environments; use CLI or CDO

## ASA vs FTD Feature Comparison

| Feature | ASA | FTD |
|---|---|---|
| Security contexts | Yes (up to 250) | No |
| Snort IPS | No | Yes (Snort 3) |
| Application ID | No | Yes (AppID) |
| URL filtering | No | Yes (licensed) |
| SSL decryption | No | Yes |
| File/malware inspection | No | Yes (AMP) |
| User identity policy | No | Yes (ISE, AD, Azure AD) |
| ZTNA | No | Yes (7.4+) |
| Clientless WebVPN | Yes | No (ZTAA replacement) |
| VPN load balancing | Yes | No |
| Distributed S2S VPN | Yes (cluster, IKEv2) | No |
| New hardware support | Legacy only | All new platforms |
