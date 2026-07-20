# Cisco FTD Architecture Reference

## Dual-Engine Design

### LINA Engine (ASA Code)
- L2 processing (MAC, ARP, VLAN)
- Routing (static, OSPF, BGP, EIGRP, PBR in 7.4+)
- NAT (Auto-NAT, Manual/Twice-NAT)
- VPN termination (IPsec IKEv2, SSL/DTLS)
- Prefilter policy (FastPath/Block/Analyze at L3/L4)
- Stateful connection tracking (TCP state machine, UDP pseudo-states)
- Hardware bypass/failsafe (platform-dependent)
- Access via: `system support diagnostic-cli`
- Syslog messages: `%ASA-` identifiers

### Snort Engine (L7 Inspection)
- Security Intelligence (IP/URL/DNS reputation)
- SSL/TLS policy (decrypt-resign, decrypt-known-key, do-not-decrypt, block)
- URL filtering (category + reputation)
- Application identification (AppID)
- Identity policy (user/group-based access)
- Access Control Policy L7 rules
- IPS (Snort rules, Talos signatures)
- File/Malware policy (AMP, Threat Grid)

**Snort does NOT drop packets directly** -- returns verdict to LINA. LINA enforces.

### Snort 3 vs Snort 2

| Feature | Snort 2 | Snort 3 |
|---|---|---|
| Process model | Multiple processes per core | Single multi-threaded |
| Config format | Preprocessor-based | Inspector-based (LUA) |
| Reload behavior | Full restart on deploy | Reload without restart |
| SnortML | Not supported | Supported (7.6+) |
| Default engine | Pre-7.0 | Default 7.0+; mandatory 7.6+ |

## Packet Flow

```
Ingress -> LINA (L2, route, Prefilter, NAT un-translate, VPN decrypt, ACL)
  -> Snort (SI, SSL, URL/App/User, IPS, File/Malware) -> verdict
  -> LINA (apply verdict, NAT translate, VPN encrypt, route, egress)
```

### FastPath (Prefilter Trust)
Bypasses Snort entirely. LINA handles all subsequent packets via connection table. Highest performance.

### Connection Reuse
Established permitted connections: LINA uses connection table for fast forwarding. ACL/Snort only for new connections.

## Deployment Modes

### Routed (Default)
L3 gateway; each interface in separate subnet/zone; NAT required; supports all features.

### Transparent
L2 bump-in-the-wire; bridge groups; no NAT; no VPN termination; supports IPS/ACP/URL.

### Inline Sets (IPS Mode)
Two interfaces paired; active (drop malicious) or tap (copy only).

### Passive (IDS Mode)
SPAN/mirror port; analysis only; no enforcement.

## FMC Architecture

### On-Premises FMC
- Hardware or virtual (VMware, KVM, Hyper-V, AWS, Azure, GCP, OCI)
- FMC version >= FTD version (always upgrade FMC first)
- sftunnel over TCP 8305 (encrypted)
- Stores all event/log data

### cdFMC (Cloud-Delivered)
- SaaS within CDO/Security Cloud Control
- No on-premises appliance required
- FTD must have internet access
- Manages FTD 7.2+ devices

### FDM (On-Box Management)
- Built-in web UI for single-device management
- No multi-device, no advanced correlation, limited FlexConfig

### Policy Deployment Process
1. FMC collects policies for target device(s)
2. Builds Snort config package + LINA config package
3. Transfers via sftunnel
4. FTD validates and applies
5. Snort reload (Snort 3) or restart (Snort 2)
6. Success/failure reported to FMC

## High Availability

### Active/Standby Failover
- Two identical FTD units; active processes traffic; standby synchronized
- Stateful: connection state, NAT xlate, VPN tunnels, routing replicated
- Dedicated failover link for heartbeat and state
- Triggers: interface failure, >50% Snort down, disk >90%, heartbeat failure
- FMC manages HA pair as single logical device

### Clustering (4100/9300)
- Up to 16 nodes as single logical device
- Control node (management) + data nodes (traffic)
- Spanned EtherChannel for load balancing
- Cluster Control Link (CCL) for inter-node state
- FMC manages cluster as single device

### Multi-Instance (3100, 4100, 4200, 9300)
- Multiple independent FTD container instances per chassis
- Each instance: own FTD image, management IP, FMC registration
- FXOS supervisor allocates CPU, memory, interfaces
- Instance-level HA (separate chassis pairs)

## NAT Architecture (LINA-based)

### Processing Order
1. **Section 1 (Manual NAT, pre-auto)**: First match wins
2. **Section 2 (Auto-NAT)**: Object-based; auto-ordered by specificity
3. **Section 3 (Manual NAT, `after-auto`)**: Catch-all rules

### Auto-NAT (Object NAT)
Defined within network object. Source-only translation. Best for static PAT and simple dynamic PAT.

### Manual NAT (Twice NAT)
Global NAT config. Can translate both source AND destination. Best for complex scenarios and VPN identity NAT.

## Platform Support

| Platform | Max FTD | Notes |
|---|---|---|
| ASA 5500-X | 7.0.x | EOL; no 7.1+ |
| Firepower 1000 | 7.7+ | Active |
| Firepower 2100 | 7.4.x | Deprecated; no 7.6+ |
| Secure Firewall 1200 | 7.7+ | New ARM; introduced 7.6 |
| Secure Firewall 3100 | 7.7+ | Multi-instance from 7.4 |
| Firepower 4100 | 7.7+ | FXOS; clustering |
| Secure Firewall 4200 | 7.7+ | Multi-instance from 7.6 |
| Firepower 9300 | 7.7+ | FXOS; multi-module |
| FTDv | 7.7+ | VMware/KVM/cloud |
