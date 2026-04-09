# pfSense Architecture Reference

## FreeBSD Base

pfSense builds on FreeBSD stable branch:

### Kernel and Network Stack
- **pf (packet filter)** -- BSD firewall engine; all firewall rules and NAT processed by pf
- **pfsync** -- Protocol for synchronizing pf state table between HA nodes
- **CARP** -- Common Address Redundancy Protocol for virtual IP failover
- **dummynet** -- Traffic shaping and bandwidth management (limiters)
- **ALTQ** -- Alternate Queuing for QoS (HFSC, PRIQ, CBQ, FAIRQ)
- **if_bridge** -- Layer 2 bridging
- **IPFW** -- Alternative firewall framework (not used by pfSense; pf is primary)

### Filesystem
- **ZFS** -- Recommended root filesystem (snapshots, checksums, compression)
- **UFS** -- Legacy option; simpler but lacks ZFS features
- Boot environments (ZFS) allow rollback after failed upgrade

### Configuration Storage
- All configuration in `/conf/config.xml` (XML)
- Config history maintained with automatic backups on every change
- Netgate Global Config Sync for cloud backup (pfSense Plus)
- Export/import via WebGUI for migration and disaster recovery

## pf (Packet Filter) Engine

### Rule Processing
- Rules defined per interface; evaluated top-down on the **ingress interface**
- **First-match wins** -- Processing stops at first matching rule
- Implicit default deny on WAN; implicit allow on LAN (removable)
- `quick` keyword (used in floating rules) forces immediate action without further evaluation

### State Table
- Stateful by default; every permitted connection creates a state entry
- Return traffic automatically permitted based on state (no explicit rule needed)
- State table entries track: source/destination IP/port, protocol, bytes, packets, creation time, timeout
- State timeouts are protocol-aware (TCP: tracks handshake/close; UDP: idle timeout)

### Rule Types
1. **Interface rules** -- Processed on specific interface ingress; most common
2. **Floating rules** -- Processed before interface rules; apply to multiple interfaces; support `quick` and direction (in/out/any)
3. **Anti-lockout rule** -- Built-in rule preventing admin lockout from WebGUI on LAN

### pf Anchors
- pfSense uses pf anchors internally for dynamic rules (VPN, captive portal, pfBlockerNG)
- Anchors are nested rule sets loaded/unloaded dynamically without reloading the main ruleset
- `pfctl -a '*' -sr` shows all anchor rules

## NAT Implementation

### Destination NAT (Port Forward)
- Implemented as pf `rdr` rules
- Evaluated before firewall rules; redirected packets then processed by interface rules
- Auto-generated associated filter rules (can be manually managed)
- Port ranges and 1:many mappings supported

### Source NAT (Outbound)
- Implemented as pf `nat` rules
- Four modes: Automatic (default), Hybrid, Manual, Disabled
- **Automatic**: pfSense generates rules for all configured internal subnets
- **Hybrid**: Auto rules + manual additions (recommended for customization without losing defaults)
- **Manual**: Full control; must create all outbound NAT rules explicitly

### 1:1 NAT
- Bidirectional static mapping; implemented as pf `binat` rules
- Maps entire IP; all ports translated
- Takes precedence over outbound NAT for matched traffic

### NAT Reflection
- Allows internal clients to access port-forwarded services using the external IP
- **NAT+proxy mode**: Uses a proxy (relayd) for reflection; most compatible
- **Pure NAT mode**: Uses pf rules; more efficient but has limitations with some configurations

## CARP High Availability

### Protocol Details
- CARP is a FreeBSD kernel protocol (not application-level)
- Each CARP VIP has a Virtual Host ID (VHID) -- must be unique per broadcast domain
- Members send CARP advertisements at configurable intervals
- **Skew value** determines priority: lower skew = higher priority = master
- Base advertisement interval: 1 second; effective interval = base + (skew / 256)

### pfsync State Synchronization
- Synchronizes the pf state table between HA nodes over a dedicated interface
- Uses IP protocol 240 (PFSYNC)
- Must use dedicated physical link or VLAN (not shared with production traffic)
- State entries replicated in real time; failover preserves active connections
- Configurable: sync all states or filter by interface

### Config Sync (XMLRPC)
- Primary node pushes configuration to secondary via XMLRPC over HTTPS
- Configurable sync scope: rules, aliases, NAT, DHCP, DNS, VPN, certificates, users
- Triggered on every config change on primary
- Secondary applies config and reloads affected services

### Failover Mechanics
- CARP advertisement timeout: 3x advertisement interval
- When master stops advertising, backup with lowest skew promotes to master
- Preemption: optional; disabled by default. If enabled, higher-priority node reclaims master on recovery.
- Demotion counters: processes can increment demotion counter to prevent premature master election during boot

### Design Requirements
- Minimum 3 IPs per interface: Node1 IP, Node2 IP, CARP VIP
- All services (DHCP, DNS, VPN) should reference CARP VIPs, not node IPs
- WAN gateway must be reachable from both nodes
- Both nodes must have identical pfSense version and package set

## Package System

### Architecture
- Packages installed via WebGUI Package Manager
- Built and distributed via poudriere (FreeBSD package build system)
- Packages integrate into WebGUI with dedicated configuration pages
- Package configuration stored in `/conf/config.xml` alongside base config

### Key Packages

#### pfBlockerNG
- **DNSBL**: Integrates with Unbound DNS Resolver; intercepts DNS queries matching blocklists; returns NXDOMAIN or redirect to block page
- **IP blocking**: Creates pf firewall aliases from IP feed URLs; auto-updates on schedule
- **GeoIP**: MaxMind database integration; block/allow by country
- **Feed management**: Multiple feed categories (ads, malware, tracking, adult); per-feed enable/disable
- Python-based v3 (pfBlockerNG-devel) with significant performance improvements

#### Suricata IDS/IPS
- **Inline mode (IPS)**: Blocks matching traffic using `divert` sockets
- **IDS mode**: Alerts only; no blocking
- **Rule sources**: Emerging Threats Open/Pro, Snort Community, custom
- **EVE JSON logging**: Structured output for SIEM (ELK, Splunk)
- Per-interface deployment; multiple instances supported
- SID management for rule enable/disable/suppress

#### HAProxy
- L7 reverse proxy and load balancer
- **Frontends**: Listener configuration (bind address, port, SSL)
- **Backends**: Server pools with health checks, load balancing algorithms
- **ACLs**: Host-based, path-based, header-based routing
- SSL termination with Let's Encrypt (via ACME package)
- Sticky sessions and connection persistence

#### Squid / SquidGuard
- HTTP/HTTPS caching proxy
- **SSL Bump**: HTTPS interception for content filtering (requires CA certificate distribution)
- **SquidGuard**: URL categorization and web filtering
- WCCP support for transparent proxy without client configuration
- **Limitation**: SSL Bump breaks certificate pinning; exempt known-pinned sites

## Traffic Shaping

### ALTQ (BSD-Native QoS)
Queuing disciplines available:
- **HFSC (Hierarchical Fair Service Curve)** -- Most flexible; supports bandwidth guarantees and delay bounds
- **PRIQ (Priority Queuing)** -- Simple priority-based; higher priority queues served first
- **CBQ (Class-Based Queuing)** -- Bandwidth allocation with borrowing between classes
- **FAIRQ (Fair Queuing)** -- Equal distribution across flows

Configuration: Create queues on interfaces, then assign traffic to queues via firewall rules.

**Limitation**: ALTQ does not work with multi-queue NICs (most modern 10G+ NICs), LAGG interfaces, or PPPoE. Check NIC compatibility before configuring.

### Limiters (dummynet)
- **Per-connection limits**: Cap bandwidth per individual connection
- **Per-IP limits**: Cap aggregate bandwidth per source or destination IP
- **Mask options**: Source, destination, or both; bits for subnet aggregation
- Applied via firewall rule Advanced Options (In/Out pipes)
- Works with all NIC types; no ALTQ limitations
- Use cases: guest network throttling, fair bandwidth sharing, upload/download caps

## Netgate Hardware

### Hardware Architecture
All Netgate appliances are x86_64 or ARM-based:

- **ARM platforms (1100, 2100)**: Low-power, fanless; suitable for SOHO/branch
- **Intel Atom/Core (4100, 6100)**: Mid-range; 2.5G/10G ports
- **Intel Xeon (7100, 8200)**: Enterprise; multi-core; SFP+ connectivity
- **Server-class (1537, 1541)**: DC edge; dual PSU; 25 GbE

### Platform Optimization
- pfSense Plus optimized for Netgate hardware: driver tuning, thermal management, boot sequence
- Hardware crypto acceleration (AES-NI) utilized for VPN throughput
- Netgate Global Support subscription available for commercial support

## VPN Architecture

### OpenVPN
- Based on OpenSSL; TLS for control channel, symmetric cipher for data channel
- Supports TAP (L2) and TUN (L3) modes
- Full PKI management via pfSense Certificate Manager
- Multiple server instances on different ports/protocols
- Client Export package generates platform-specific configuration bundles

### WireGuard
- Kernel module (pfSense Plus); modern cryptography
- Stateless protocol; peers exchange handshake, then forward packets
- No TLS overhead; lower CPU usage than OpenVPN
- Each peer has a public/private key pair; pre-shared key optional for additional security

### IPsec (strongSwan)
- IKEv1 and IKEv2 support
- **Phase 1 (IKE SA)**: Authentication, key exchange, encryption algorithm negotiation
- **Phase 2 (IPsec SA)**: Traffic selectors, ESP/AH, PFS group
- **VTI (Virtual Tunnel Interface)**: Route-based IPsec; simplifies routing and failover
- Mobile client support for native OS VPN clients (iOS, Android, Windows)
