# DDI Fundamentals Reference

## What is DDI?

DDI stands for DNS, DHCP, and IPAM -- the three foundational network services that enable IP connectivity for every device on a network. Enterprise DDI platforms integrate these three services into a unified management plane with automation, audit trails, security intelligence, and API-driven workflows.

### The DDI Lifecycle

```
Device connects to network
    -> DHCP assigns IP address (lease)
    -> DNS record created automatically (A/PTR)
    -> IPAM database updated (IP, MAC, device type, location)
    -> Device accesses network resources via DNS resolution
    -> Lease expires or device disconnects
    -> DHCP releases IP
    -> DNS record cleaned up (scavenging)
    -> IPAM marks IP as available
```

Without DDI integration, each step requires manual coordination -- the primary source of IP conflicts, stale DNS records, and DHCP exhaustion.

---

## DNS Fundamentals

### Zone Types

| Type | Description |
|---|---|
| **Primary (Master)** | Authoritative copy of zone data; accepts dynamic updates |
| **Secondary (Slave)** | Read-only copy replicated from primary via AXFR/IXFR |
| **Stub** | Contains only NS records; delegates resolution |
| **Forward** | Forwards queries to specified resolvers |

### Record Types

| Record | Purpose | Example |
|---|---|---|
| A | IPv4 address mapping | `server01 IN A 10.1.1.50` |
| AAAA | IPv6 address mapping | `server01 IN AAAA 2001:db8::50` |
| PTR | Reverse lookup (IP to name) | `50.1.1.10.in-addr.arpa IN PTR server01.corp.example.com` |
| CNAME | Alias to another name | `www IN CNAME webserver01.corp.example.com` |
| MX | Mail exchange | `corp.example.com IN MX 10 mail.corp.example.com` |
| SRV | Service location | `_ldap._tcp.corp.example.com IN SRV 0 100 389 dc01` |
| TXT | Arbitrary text (SPF, DKIM, etc.) | `corp.example.com IN TXT "v=spf1 include:_spf.google.com ~all"` |
| NS | Name server delegation | `corp.example.com IN NS ns1.corp.example.com` |
| SOA | Start of authority | Zone metadata: serial, refresh, retry, expire, minimum TTL |

### DNSSEC

DNSSEC (DNS Security Extensions) adds cryptographic authentication to DNS responses:

- **ZSK (Zone Signing Key)** -- Signs individual DNS records within a zone. Rotated frequently (30-90 days).
- **KSK (Key Signing Key)** -- Signs the ZSK; published as DS record in parent zone. Rotated less frequently (1-2 years).
- **NSEC/NSEC3** -- Authenticated denial of existence (proves a record does not exist without exposing all zone contents). NSEC3 uses hashed names to prevent zone enumeration.
- **Chain of Trust** -- Root zone (signed) -> TLD (signed) -> domain zone (signed). Validators follow the chain to verify authenticity.

### Response Policy Zones (RPZ)

RPZ is a DNS firewall mechanism that intercepts and modifies DNS responses based on policy:

- **Threat intelligence feeds** -- Block known-malicious domains, C2 servers, phishing sites
- **Actions**: NXDOMAIN (block), NODATA, redirect to sinkhole, passthru (whitelist)
- **Sources**: Vendor-curated feeds (Infoblox, EfficientIP), open-source DNSBL, custom rules
- **Implementation**: RPZ zone loaded into recursive resolver; evaluated before normal resolution

### Split DNS (Views)

Split DNS serves different zone data to different clients based on source IP or interface:

- **Internal view** -- Full internal zone data (server01.corp.example.com -> 10.1.1.50)
- **External view** -- Limited public records only (www.example.com -> 203.0.113.10)
- Prevents internal hostname/IP exposure to the internet
- Both Infoblox and EfficientIP support views natively

---

## DHCP Fundamentals

### DHCP Process (DORA)

```
1. DISCOVER  -- Client broadcasts to find DHCP servers
2. OFFER     -- Server offers an IP address and options
3. REQUEST   -- Client requests the offered address
4. ACK       -- Server confirms the lease
```

### Key DHCP Concepts

| Concept | Description |
|---|---|
| **Scope/Range** | Pool of IP addresses available for lease assignment |
| **Lease time** | Duration of IP assignment; client must renew before expiry |
| **Reservation** | Fixed MAC-to-IP mapping; ensures device always gets same IP |
| **Relay agent** | Router forwards DHCP broadcasts across subnets (ip helper-address) |
| **Options** | Metadata delivered with lease: gateway (opt 3), DNS server (opt 6), domain name (opt 15), NTP (opt 42) |
| **Failover** | Two DHCP servers share a scope for HA; active/standby or load-balanced |

### DHCP Fingerprinting

DHCP fingerprinting identifies device type from the DHCP option set requested by the client:

- Each OS/device type requests a unique combination of DHCP options (parameter request list, option 55)
- Fingerprint database maps option patterns to device classes: Windows 11, iPhone, Cisco IP Phone, HP printer, etc.
- **Use cases**:
  - Network Access Control (NAC): assign VLAN by device type
  - Asset inventory: discover unknown devices
  - Security: detect rogue or unauthorized device types
  - Compliance: verify only approved devices connect

### DHCPv6

DHCPv6 differs from DHCPv4 in significant ways:

- **Stateful DHCPv6** -- Server assigns IPv6 addresses (similar to DHCPv4)
- **Stateless DHCPv6** -- Addresses assigned via SLAAC; DHCPv6 provides options only (DNS, NTP)
- **Prefix Delegation (PD)** -- DHCPv6 assigns entire prefixes (e.g., /48) to downstream routers
- **DUID** -- Device Unique Identifier replaces MAC for client identification
- **Relay** -- Uses link-local multicast (ff02::1:2) instead of broadcast

---

## IPAM Fundamentals

### IP Address Lifecycle

```
PLANNED    -- Subnet allocated in design phase
RESERVED   -- IP reserved for specific device (not yet assigned)
ASSIGNED   -- IP actively in use (DHCP lease or static)
DISCOVERED -- IP found via network discovery (not in IPAM records)
CONFLICT   -- Duplicate IP detected on network
ABANDONED  -- IP marked for reclamation (lease expired, device removed)
AVAILABLE  -- IP free for new assignment
```

### Hierarchical IP Space

Enterprise IP addressing follows a hierarchical model for scalability and summarization:

```
Organization (10.0.0.0/8)
  -> Region: Americas (10.0.0.0/10)
    -> Site: NYC (10.0.0.0/16)
      -> Building: NYC-HQ (10.0.0.0/20)
        -> VLAN: Server (10.0.0.0/24)
        -> VLAN: User (10.0.1.0/24)
        -> VLAN: Voice (10.0.2.0/24)
        -> VLAN: Management (10.0.3.0/24)
```

### Subnet Sizing Guide

| Use Case | Recommended Size | Hosts |
|---|---|---|
| Point-to-point link | /31 (RFC 3021) | 2 |
| Loopback block | /32 per device | 1 |
| Small DMZ | /28 | 14 |
| Server VLAN | /24 | 254 |
| User VLAN | /23 or /24 | 510 or 254 |
| Wireless VLAN | /22 or /23 | 1022 or 510 |
| Data center leaf subnet | /25 per rack | 126 |

### RFC Address Spaces

| RFC | Block | Purpose |
|---|---|---|
| RFC 1918 | 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 | Private enterprise addressing |
| RFC 6598 | 100.64.0.0/10 | Carrier-Grade NAT (CGN) / shared address space |
| RFC 5737 | 192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24 | Documentation examples |
| RFC 6890 | Various | Special-purpose address registry |

---

## Grid / HA Architecture Patterns

### Centralized Grid (Infoblox Model)

```
Grid Master (GM)
  -> Replicates config to all Grid Members
  -> Hosts management GUI and API (WAPI)
  -> Grid Master Candidate (GMC) for HA

Grid Member (DNS)     Grid Member (DHCP)     Grid Member (DNS+DHCP)
  -> Serves DNS         -> Serves DHCP          -> Both services
  -> Local queries      -> Local leases          -> Combined node
  -> Reports to GM      -> Reports to GM         -> Reports to GM

Reporting Member
  -> Analytics, compliance reports
  -> Offloads reporting from service members
```

- Replication is database-level (not zone transfer); ensures exact configuration parity
- Delta replication for incremental changes; full sync on member join
- All configuration changes made on GM; replicated automatically

### Primary/Secondary (EfficientIP Model)

```
Primary Appliance
  -> Master configuration database
  -> SOLIDserver management console
  -> REST API endpoint

Secondary Appliance
  -> Replicated database
  -> Automatic failover
  -> Read-only management (promotes on primary failure)
```

- Simpler topology than Grid; suitable for smaller deployments
- Can scale to multiple appliance pairs per region

### SaaS / Hybrid

Both Infoblox (BloxOne DDI) and EfficientIP (Cloud DDI) offer SaaS-delivered DDI:

- **On-premises data connectors** proxy DNS/DHCP traffic to cloud-hosted service
- **Hybrid management** -- Mix of cloud-managed and on-premises appliances
- **Universal DDI** (Infoblox 2025+) -- Single management portal for both NIOS Grid and BloxOne DDI

---

## DDI Integration Patterns

### ITSM Integration

DDI platforms integrate with IT Service Management tools for IP provisioning workflows:

- **ServiceNow** -- IP allocation triggered by ServiceNow tickets; automated fulfillment
- **BMC Remedy** -- CMDB synchronization with IPAM records
- **Custom workflows** -- Webhook/API triggers on IP allocation events

### Infrastructure as Code

| Tool | Infoblox | EfficientIP |
|---|---|---|
| **Terraform** | `infoblox/infoblox` provider | `efficientip/solidserver` provider |
| **Ansible** | `infoblox.nios_modules` collection | `EfficientIP.solidserver` collection |
| **Python** | `infoblox-client` library + WAPI | REST API client |

### CMDB Synchronization

DDI platforms serve as authoritative source for IP-to-device mapping:

- Export IP records to CMDB (ServiceNow, Device42, Netbox)
- Import server records from CMDB to pre-populate IPAM
- Bi-directional sync ensures consistency between DDI and CMDB

---

## DDI Security

### DNS as Attack Vector

| Threat | Description | Mitigation |
|---|---|---|
| **DNS tunneling** | Data exfiltration through DNS queries | Statistical analysis of query patterns |
| **DGA domains** | Algorithmically generated C2 domains | ML-based detection (both vendors) |
| **Cache poisoning** | Inject false records into resolver cache | DNSSEC validation, transaction ID randomization |
| **DNS DDoS** | Volumetric attack against DNS infrastructure | Rate limiting, DNS Guardian (EfficientIP), RPZ (Infoblox) |
| **DNS amplification** | Abuse open resolvers for reflected DDoS | Restrict recursive queries to authorized clients |
| **Phantom domains** | Slow resolver with non-responsive delegations | Aggressive NSEC caching, resolver tuning |

### DHCP Security

| Threat | Description | Mitigation |
|---|---|---|
| **Rogue DHCP** | Unauthorized DHCP server on network | DHCP snooping on switches, 802.1X |
| **DHCP starvation** | Exhaust all IPs in scope | Port security, DHCP rate limiting |
| **MAC spoofing** | Impersonate authorized device | 802.1X + RADIUS, DHCP fingerprint validation |

---

## Capacity Planning

### DNS Sizing

- **Queries per second (QPS)** -- Enterprise recursive: 1,000-50,000 QPS per site typical
- **Cache hit ratio** -- 80-90% for well-tuned resolvers; size for cache-miss QPS
- **Zone count** -- Large enterprises: 100-1,000+ zones (internal + reverse)
- **Record count** -- 10,000-500,000+ records across all zones

### DHCP Sizing

- **Leases per server** -- Modern DDI appliances: 100,000-1,000,000+ concurrent leases
- **Scope count** -- One per VLAN/subnet; plan for growth
- **Transactions per second** -- Size for peak (morning login surge, BYOD events)

### IPAM Sizing

- **Managed IPs** -- Track total managed address space (IPv4 + IPv6)
- **Utilization threshold** -- Alert at 80% subnet utilization; plan expansion at 70%
- **History retention** -- 90-365 days of lease/allocation history for compliance
