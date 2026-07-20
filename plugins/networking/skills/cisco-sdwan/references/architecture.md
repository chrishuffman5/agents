# Cisco Catalyst SD-WAN Architecture Reference

## Controller Infrastructure

### SD-WAN Manager (vManage)

**Role**: Management and orchestration plane.

- Single-pane-of-glass NMS; GUI, REST API (NETCONF southbound), dashboard analytics
- Manages device onboarding, feature/device templates, policy distribution, software upgrades, certificate provisioning
- Single instance or cluster (minimum 3 nodes) for HA and scale
- Cluster uses internal Elasticsearch + Cassandra data layer
- Communicates to controllers and edge routers via DTLS/TLS on port 12446 (NETCONF)
- Release 20.18 added global search across devices, templates, policies, logs; guided Day-0 task flow

**Cluster Sizing**:
- 3-node cluster: Up to 2,000 devices
- 6-node cluster: Up to 6,000 devices
- Each node requires minimum 32 vCPU, 64 GB RAM, 500 GB SSD for production

### SD-WAN Controller (vSmart)

**Role**: Control-plane intelligence and OMP route reflector.

- Maintains TLS sessions to all WAN Edge devices
- Distributes routes (vRoutes), TLOCs, encryption keys, and policy
- Applies centralized control policy before advertising routes
- Failure does NOT break existing data-plane tunnels (BFD stays up)
- No new route/policy changes until recovery
- Scale: 1 vSmart per ~2,000 WAN Edge devices; up to 6 instances in large deployments
- Sizing: 8 vCPU, 16 GB RAM minimum per instance

### SD-WAN Validator (vBond)

**Role**: Initial device authentication and NAT traversal.

- First point of contact for any new WAN Edge device
- Authenticates against serial number whitelist maintained in SD-WAN Manager
- Facilitates NAT traversal (STUN-like behavior)
- Advertises vSmart and vManage addresses to authenticating edge devices
- Must have a public IP (or 1:1 NAT); deployed in DMZ
- Port 12346 UDP (DTLS)
- Lightweight: 2 vCPU, 4 GB RAM

## OMP (Overlay Management Protocol) Internals

### Protocol Mechanics
- TCP-based, runs inside DTLS/TLS sessions between WAN Edge and vSmart
- Designed similarly to BGP: uses keepalives, update messages, graceful restart
- Each WAN Edge establishes OMP session to all configured vSmart controllers
- vSmart acts as route reflector, not in the data path

### Route Types

| Route Type | Description | Key Attributes |
|---|---|---|
| vRoutes | Overlay prefixes (IPv4/IPv6) | Prefix, VPN-ID, originator, preference, site-id, tag |
| TLOC routes | Transport Locator endpoints | System-IP, color, encap, BFD status, preference |
| Service routes | Service chaining advertisements | Service type (FW, IDS), VPN-ID, IP |

### TLOC Mechanics

A TLOC is a 3-tuple: `(System-IP, Color, Encapsulation)`

**System-IP**: A loopback-like identifier unique to each WAN Edge. Never changes across reboots or moves. Used for OMP peering and tunnel identification.

**Color**: A logical label for a transport circuit. Standard colors:
- `mpls` -- Private MPLS circuit
- `biz-internet` -- Business-grade broadband
- `public-internet` -- Consumer broadband
- `private1` through `private6` -- Custom private labels
- `lte` -- Cellular WAN
- `3g` -- Legacy cellular

Color determines tunnel formation behavior:
- **Public colors** (public-internet, biz-internet): Attempt NAT traversal; use STUN via vBond
- **Private colors** (mpls, private1-6): Assume direct reachability; no NAT traversal
- **Restrict flag**: When set, TLOC only forms tunnels with TLOCs of the same color

**Encapsulation**: `ipsec` (standard) or `gre` (legacy, less common).

### OMP Route Advertisement Flow
```
WAN Edge originates vRoutes/TLOCs
    |
    v
OMP update sent to vSmart via DTLS/TLS
    |
    v
vSmart applies centralized control policy (filter, modify, reject)
    |
    v
vSmart advertises accepted routes to all other OMP peers
    |
    v
Remote WAN Edges receive routes, build IPsec tunnels to learned TLOCs
```

### OMP Graceful Restart
- Default timer: 12 hours (43,200 seconds)
- During vSmart unavailability, WAN Edge preserves cached OMP routes
- Data plane continues forwarding based on cached state
- If timer expires before vSmart recovery, WAN Edge purges all OMP routes
- Configurable: `omp graceful-restart-timer <seconds>`

## Data Plane Architecture

### IPsec Tunnel Formation

1. WAN Edge learns remote TLOCs via OMP from vSmart
2. For each (local-TLOC, remote-TLOC) pair, initiates IKE negotiation
3. Keys distributed by SD-WAN Manager (no manual PSK or certificate management)
4. IPsec ESP tunnel mode established; AES-256-GCM default cipher
5. BFD probes begin immediately inside the tunnel

**Tunnel scale considerations**:
- Full mesh: n*(n-1)/2 tunnels (100 sites = ~5,000 tunnels)
- Each tunnel consumes BFD probe bandwidth and CPU
- Use centralized control policy to restrict topology (hub-spoke, regional mesh) at scale

### BFD Path Quality Measurement

BFD probes inside each IPsec tunnel collect three metrics:
1. **Latency**: RTT of BFD hello packets (milliseconds)
2. **Jitter**: Variation in latency between consecutive probes (milliseconds)
3. **Packet Loss**: Percentage of BFD hellos not returned (percent)

**BFD Timers**:
```
hello-interval: 1000 ms (default)
multiplier: 7 (tunnel declared down after 7 missed hellos = 7s)
app-route polling-interval: 600 seconds (aggregate BFD stats for AAR)
app-route multiplier: 6 (use last 6 polling intervals)
```

**Tuning guidance**:
- Reduce hello-interval to 100ms for sub-second failover on critical tunnels
- Increase multiplier to reduce false positives on lossy transports
- Reduce app-route polling-interval to 60s for faster AAR response (increases CPU)

### VPN Segmentation

Cisco SD-WAN uses VPN IDs for network segmentation (analogous to VRFs):
- **VPN 0**: Transport VPN (WAN interfaces, control connections)
- **VPN 512**: Management VPN (out-of-band management)
- **VPN 1+**: Service VPNs (user traffic, applications)

Each VPN maintains a separate routing table. Traffic between VPNs requires explicit route leaking or centralized data policy.

## Catalyst Center Integration

Catalyst Center (formerly DNA Center) integrates with SD-WAN Manager:
- Unified intent-based policy across LAN (Catalyst switching) and WAN (SD-WAN)
- SD-Access fabric sites extend to WAN edges; consistent SGT from campus to branch
- Network Hierarchy (site/area/building/floor) synced between products
- Assurance data from both platforms in unified dashboard
- QoS policy pushed consistently end-to-end

## Version Compatibility Matrix

| Controller Release | IOS-XE Release | Track | Notes |
|---|---|---|---|
| 20.12.x | 17.12.x | LTS | Stable; recommended for production LTS |
| 20.13.x | 17.13.x | Standard | |
| 20.14.x | 17.14.x | Standard | |
| 20.15.x | 17.15.x | LTS | SLA threshold improvements; EAAR enhancements |
| 20.16.x | 17.16.x | Standard | |
| 20.17.x | 17.17.x | Standard | |
| 20.18.x | 17.18.x | Current | Global search; NWPI security alert tracing |

**Version alignment rule**: Controller major.minor must match IOS-XE release (20.18 pairs with 17.18). Controller can be one version ahead of edge routers during upgrades.
