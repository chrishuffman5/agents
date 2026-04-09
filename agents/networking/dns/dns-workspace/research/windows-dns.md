# Windows DNS Server — Deep Dive Research

**Sources:** Microsoft Learn (learn.microsoft.com), TechCommunity, 4sysops  
**Last updated:** April 2026  
**Applies to:** Windows Server 2016, 2019, 2022, 2025

---

## Architecture Overview

Windows DNS Server is a server role built on the industry-standard DNS protocol (RFC 1034/1035). It integrates tightly with Active Directory Domain Services (AD DS) and supports a wide range of zone types, policies, and security extensions.

### Core Components

- **DNS Server service** (`dns.exe`) — authoritative and recursive resolver daemon
- **DNS Manager MMC** (`dnsmgmt.msc`) — GUI management console
- **DnsServer PowerShell module** — full configuration and automation surface
- **dnscmd.exe** — legacy CLI tool (still present in Server 2025, deprecated in favor of PowerShell)
- **DNS Client service** (`dnscache`) — client-side resolver with NRPT support

---

## Active Directory-Integrated Zones

### Replication via AD DS

When the DNS Server role runs on a Domain Controller, zones can be stored in Active Directory instead of flat files. AD-integrated zones offer:

- **Multi-master updates** — any DC running DNS can accept dynamic updates
- **Automatic replication** — no separate zone transfer topology needed; data replicates via AD replication
- **Secure dynamic updates** — only authenticated domain computers can register/update records
- **Encrypted storage** — zone data stored in AD DS objects, benefits from AD encryption/access controls
- **Signed copies in memory** — for AD-integrated zones with DNSSEC, the signed zone stays in memory for performance; only committed to disk for file-backed zones

### DNS Application Partitions (Replication Scopes)

Windows DNS uses DNS application directory partitions to control which DCs receive zone data:

| Partition | Scope | Notes |
|---|---|---|
| `ForestDnsZones` | All DCs in the forest running DNS | Used for `_msdcs.<forest root>` and cross-domain zones |
| `DomainDnsZones` | All DCs in the domain running DNS | Default for domain zones |
| Domain partition | All DCs in the domain | Legacy Windows 2000 compatibility |
| Custom partition | Admin-defined subset | Used for selective replication |

**PowerShell example:**
```powershell
# Create AD-integrated zone replicated to all DNS servers in the forest
Add-DnsServerPrimaryZone -Name "north.contoso.com" -ReplicationScope "Forest" -PassThru

# Create zone replicated only to domain DCs
Add-DnsServerPrimaryZone -Name "south.contoso.com" -ReplicationScope "Domain" -PassThru
```

### Replication Scope Values
- `Forest` → ForestDnsZones partition
- `Domain` → DomainDnsZones partition
- `Legacy` → Domain partition (Windows 2000 compat)
- `Custom` → Specified custom application partition

---

## Zone Types

### Primary Zone
- Authoritative read/write copy of zone data
- Can be file-based or AD-integrated
- File-based stored in `%SystemRoot%\System32\dns\<zonename>.dns`
- Dynamic updates: None, Unsecure-and-Secure, or Secure-only (AD zones support secure-only)

### Secondary Zone
- Read-only copy obtained from primary via zone transfer (AXFR/IXFR)
- File-based only (cannot be AD-integrated)
- Used for load distribution and redundancy
- Must be whitelisted on the primary for transfers

```powershell
Add-DnsServerSecondaryZone -Name "south.contoso.com" `
    -ZoneFile "south.contoso.com.dns" `
    -MasterServers 172.23.90.124
```

### Stub Zone
- Contains only SOA, NS, and glue A records for a zone
- Used for zone delegation discovery and inter-forest/domain resolution
- Can be AD-integrated (forest or domain scope)
- Automatically refreshes NS records from master server

```powershell
Add-DnsServerStubZone -Name "west.contoso.com" `
    -MasterServers "172.23.90.124" -PassThru `
    -ZoneFile "west.contoso.com.dns"
```

### Conditional Forwarder Zone
- Forwards queries for specific domain names to designated servers
- Used for resolving partner domains, Azure private DNS, on-premises hybrid connectivity
- Can be AD-integrated for distribution across DCs

```powershell
Add-DnsServerConditionalForwarderZone -Name "partner.com" `
    -MasterServers "10.1.1.53","10.1.2.53" `
    -ReplicationScope "Domain"
```

### Reverse Lookup Zones
- Map IP addresses back to hostnames (in-addr.arpa / ip6.arpa)
- Support PTR records for both IPv4 and IPv6
- Can be AD-integrated

```powershell
# IPv4 /24 reverse zone
Add-DnsServerPrimaryZone -NetworkID "10.1.0.0/24" -ReplicationScope "Forest"
```

---

## Zone Scopes

Introduced in Windows Server 2016 as part of DNS Policies. A zone scope is a unique instance of a DNS zone — the same zone can have multiple scopes, each with its own set of records.

- Each scope can contain different IP addresses for the same hostname
- Zone transfers operate at the zone scope level
- Used to implement split-brain DNS and geo-based traffic routing

```powershell
# Create zone scopes for geographic traffic management
Add-DnsServerZoneScope -ZoneName "contoso.com" -Name "NorthAmericaZoneScope"
Add-DnsServerZoneScope -ZoneName "contoso.com" -Name "EuropeZoneScope"

# Add different IPs for www in each scope
Add-DnsServerResourceRecord -ZoneName "contoso.com" -A -Name "www" `
    -IPv4Address "172.21.21.21" -ZoneScope "NorthAmericaZoneScope"
Add-DnsServerResourceRecord -ZoneName "contoso.com" -A -Name "www" `
    -IPv4Address "172.17.97.97" -ZoneScope "EuropeZoneScope"
```

---

## DNS Policies

DNS Policies (introduced in Windows Server 2016) allow administrators to configure DNS server behavior based on various criteria. **PowerShell is required** — there is no GUI for DNS policies.

Supported in: Windows Server 2016, 2019, 2022, 2025.

### Policy Objects

**Client Subnets** — Named IPv4/IPv6 subnet groups for matching query sources:
```powershell
Add-DnsServerClientSubnet -Name "NorthAmericaSubnet" -IPv4Subnet "172.21.33.0/24"
Add-DnsServerClientSubnet -Name "EuropeSubnet" -IPv4Subnet "172.17.44.0/24"
```

**Recursion Scopes** — Named groups controlling recursion behavior and forwarder selection:
```powershell
# Disable default recursion
Set-DnsServerRecursionScope -Name . -EnableRecursion $False
# Create internal recursion scope
Add-DnsServerRecursionScope -Name "InternalClients" -EnableRecursion $True
```

### Policy Types and Levels

| Policy Type | Level | Actions |
|---|---|---|
| Query Resolution | Server | Deny, Ignore |
| Query Resolution | Zone | Allow, Deny, Ignore |
| Zone Transfer | Server | Deny, Ignore |
| Zone Transfer | Zone | Deny, Ignore |
| Recursion | Server only | Allow with recursion scope |

### Policy Match Criteria

Policies match on any combination of:
- Client Subnet (by named subnet object)
- Transport Protocol (TCP/UDP)
- Internet Protocol (IPv4/IPv6)
- Server Interface IP address
- FQDN (supports wildcards: `EQ,*.contoso.com`)
- Query Type (A, MX, TXT, SRV, etc.)
- Time of Day (`EQ,10:00-12:00,22:00-23:00`)

### Use Cases

**Geo-Location Traffic Management:**
```powershell
Add-DnsServerQueryResolutionPolicy -Name "NorthAmericaPolicy" -Action ALLOW `
    -ClientSubnet "eq,NorthAmericaSubnet" `
    -ZoneScope "NorthAmericaZoneScope,1" -ZoneName "contoso.com"
Add-DnsServerQueryResolutionPolicy -Name "EuropePolicy" -Action ALLOW `
    -ClientSubnet "eq,EuropeSubnet" `
    -ZoneScope "EuropeZoneScope,1" -ZoneName "contoso.com"
```

**Block malicious domains (DNS sinkholing):**
```powershell
Add-DnsServerQueryResolutionPolicy -Name "BlackholePolicy" `
    -Action IGNORE -FQDN "EQ,*.malicious.com"
```

**Split-brain recursion (internal clients get recursion, external don't):**
```powershell
Add-DnsServerQueryResolutionPolicy -Name "SplitBrainPolicy" -Action ALLOW `
    -ApplyOnRecursion -RecursionScope "InternalClients" `
    -ServerInterfaceIP "EQ,10.0.0.34"
```

**Zone Transfer Policy (restrict by subnet):**
```powershell
Add-DnsServerClientSubnet -Name "AllowedSubnet" -IPv4Subnet 172.21.33.0/24
Add-DnsServerZoneTransferPolicy -Name "NorthAmericaPolicy" `
    -Action IGNORE -ClientSubnet "ne,AllowedSubnet"
```

---

## DNSSEC

### Overview

DNSSEC adds cryptographic signatures to DNS records, protecting against cache poisoning and spoofing. Windows Server supports DNSSEC on primary zones (both file-backed and AD-integrated). For AD-integrated zones, private signing keys replicate via AD DS to all Key Master DNS servers.

### DNSSEC Resource Records

| Record | Purpose |
|---|---|
| RRSIG | Digital signature for a DNS record set |
| DNSKEY | Public key used for signature verification (KSK or ZSK) |
| DS | Delegation Signer — links parent zone to child zone trust chain |
| NSEC | Authenticated denial of existence (allows zone walking) |
| NSEC3 | Denial of existence with hashed owner names (prevents zone walking) |
| NSEC3PARAM | Parameters for NSEC3 record generation |

### Key Types

**Key Signing Key (KSK):**
- Signs the DNSKEY RRset only
- Long-lived (default rollover: 755 days)
- Higher key length typical (2048-bit RSA or 256-bit ECDSA)
- For AD-integrated zones: replicate private key to all authoritative DCs (check "Replicate this private key")

**Zone Signing Key (ZSK):**
- Signs all other record sets in the zone
- Shorter-lived (default rollover: 90 days)
- Prepublish rollover method used (new key published before old expires)
- Typically smaller key (1024-bit RSA default, 256-bit ECDSA recommended)

### Supported Algorithms

| Algorithm | Compatible NSEC Methods |
|---|---|
| ECDSAP256/SHA-256 | NSEC, NSEC3 (recommended) |
| ECDSAP384/SHA-384 | NSEC, NSEC3 |
| RSA/SHA-256 | NSEC, NSEC3 |
| RSA/SHA-512 | NSEC, NSEC3 |
| RSA/SHA-1 | NSEC only (legacy, avoid) |
| RSA/SHA-1 (NSEC3) | NSEC3 only (legacy, avoid) |

### Key Master

The Key Master is the authoritative server responsible for generating and distributing signing keys. For AD-integrated zones, the Key Master signs the zone and distributes private keys via AD replication.

### Trust Anchors

- DNSKEY and DS records are trust anchors (trust points)
- On domain controllers: stored in the forest directory partition, replicated to all DCs
- On standalone DNS: stored in `TrustAnchors.dns`

```powershell
Get-DnsServerTrustAnchor -ZoneName "contoso.com"
Get-DnsServerTrustPoint
```

### Zone Signing — PowerShell

```powershell
# Sign with defaults
Invoke-DnsServerZoneSign -ZoneName "contoso.com" -ComputerName "DC01" `
    -SignWithDefault -PassThru -Verbose -Force

# Configure NSEC3 parameters
Set-DnsServerDnsSecZoneSetting -ZoneName "contoso.com" `
    -NSec3RandomSaltLength 8 -NSec3Iterations 50

# View DNSSEC settings
Get-DnsServerDnsSecZoneSetting -ZoneName "contoso.com"

# Unsign a zone
Invoke-DnsServerZoneUnSign -ZoneName "contoso.com" -PassThru -Force
```

### Key Rollover

- **KSK rollover:** double-signature method (both old and new KSK active during transition); DS record in parent must be updated manually
- **ZSK rollover:** prepublish method (new ZSK published, then made active, then old retired); fully automatic
- Key rollover settings configurable at signing time; changes to KSK settings take effect at next rollover
- DS record generation algorithm default: SHA-1 and SHA-256

---

## Version Differences

### Windows Server 2016
- **DNS Policies** introduced (query resolution, zone transfer, recursion)
- **Zone Scopes** for split-brain and geo-routing
- **Client Subnets** and recursion scopes
- **DNS over TCP** enforcement policies
- Rate Limiting (RRL) via `Set-DnsServerResponseRateLimiting`

### Windows Server 2019
- Minor stability improvements to DNS policies
- Enhanced DNS debug logging
- Improved DNSSEC performance
- No major new DNS features vs. 2016

### Windows Server 2022
- **DNS over HTTPS (DoH) client-side** — Windows clients can use DoH resolvers (configured via NRPT or system settings)
- Improved DNSSEC key storage provider support
- Enhanced integration with Azure Arc and hybrid DNS

### Windows Server 2025
- **Server-side DNS over HTTPS (DoH)** — added via KB5075899 (February 10, 2026 update, public preview)
  - DoH on port 443 by default
  - All queries received and responses sent on the DoH port are encrypted via TLS
  - **Limitation:** upstream forwarder queries remain unencrypted on port 53 (future update planned)
  - Disabled by default; requires opt-in during public preview via registration form
  - New PowerShell cmdlets, events, and performance counters for DoH management
  - Not yet recommended for production use
- Continued support for all 2016/2019/2022 features

---

## Management

### DNS Manager MMC (`dnsmgmt.msc`)

- Full zone management (create, delete, modify zones and records)
- Zone signing wizard for DNSSEC
- Server properties: forwarders, root hints, advanced settings, debug logging
- Signed zones shown with lock icon
- Trust Points container visible in console tree

### PowerShell DnsServer Module

Key cmdlets (not exhaustive):

```powershell
# Zone management
Add-DnsServerPrimaryZone          # Create primary zone
Add-DnsServerSecondaryZone        # Create secondary zone
Add-DnsServerStubZone             # Create stub zone
Add-DnsServerConditionalForwarderZone  # Create forwarder zone
Set-DnsServerPrimaryZone          # Modify zone settings
Remove-DnsServerZone              # Delete zone

# Resource records
Add-DnsServerResourceRecord       # Add any record type
Get-DnsServerResourceRecord       # Query records
Remove-DnsServerResourceRecord    # Delete records
Set-DnsServerResourceRecord       # Update records

# Forwarders
Set-DnsServerForwarder            # Configure global forwarders
Get-DnsServerForwarder

# Replication scope / zone transfer
Set-DnsServerPrimaryZone -SecureSecondaries "TransferToZoneNameServer"

# DNSSEC
Invoke-DnsServerZoneSign          # Sign a zone
Invoke-DnsServerZoneUnSign        # Unsign a zone
Set-DnsServerDnsSecZoneSetting    # Configure DNSSEC parameters
Get-DnsServerDnsSecZoneSetting    # View DNSSEC settings
Get-DnsServerSigningKey           # View signing keys
Get-DnsServerTrustAnchor          # View trust anchors
Get-DnsServerTrustPoint

# Scavenging
Set-DnsServerScavenging           # Configure server-level scavenging
Set-DnsServerZoneAging            # Configure zone-level aging
Start-DnsServerScavenging         # Trigger manual scavenging

# Policies
Add-DnsServerClientSubnet
Add-DnsServerZoneScope
Add-DnsServerQueryResolutionPolicy
Add-DnsServerRecursionScope
Add-DnsServerZoneTransferPolicy

# Statistics and diagnostics
Get-DnsServerStatistics
Get-DnsServerDiagnostics
Set-DnsServerDiagnostics          # Enable debug logging
```

### dnscmd (Legacy CLI)

Still present through Server 2025 but deprecated:
```
dnscmd /enumzones
dnscmd /zoneadd <zonename> /primary /file <filename>
dnscmd /config <zonename> /aging 1
dnscmd /ageallrecords <zonename>   # Age all records for scavenging
dnscmd /startscavenging
dnscmd /statistics
```

---

## Aging and Scavenging

Aging and scavenging removes stale dynamically-registered records that were never properly deleted.

### Key Terminology

| Term | Default | Description |
|---|---|---|
| No-refresh interval | 7 days | Period after registration where refreshes are suppressed (reduces AD writes) |
| Refresh interval | 7 days | Window in which record must be refreshed or it becomes eligible for scavenging |
| Scavenging period | 7 days | How often automatic scavenging runs |

**Total record lifetime before scavenging = No-refresh + Refresh = 14 days (default)**

### Prerequisites

- Scavenging must be enabled at **both** the server level AND the zone level
- Only dynamically registered records (non-zero timestamp) are eligible by default
- Manually added records have timestamp = 0 (exempt unless manually changed)

### Configuration

```powershell
# Enable server-level scavenging (every 7 days)
Set-DnsServerScavenging -ScavengingState $True -ScavengingInterval 7.00:00:00

# Enable zone-level aging
Set-DnsServerZoneAging -ZoneName "contoso.com" -Aging $True `
    -NoRefreshInterval 7.00:00:00 -RefreshInterval 7.00:00:00

# Trigger manual scavenging
Start-DnsServerScavenging -Force

# Age all records in a zone (legacy dnscmd)
dnscmd /ageallrecords contoso.com
```

### Best Practices for Scavenging

- Set scavenging period = DHCP lease duration + 1 day
- Enable on the primary zone AND the server
- Do not enable on zones with static records unless you understand the impact
- Use `dnscmd /ageallrecords` when converting standard zones to AD-integrated to make existing records eligible
- Use `Set-DnsServerScavenging -ScavengingInterval` to align with environment refresh patterns
- In AD environments, only configure one server per zone as the scavenging server using `ScavengingServers` parameter

---

## Troubleshooting: Event IDs

### DNS Server Events (Source: DNS-Server-Service / Event Log: DNS Server)

| Event ID | Description |
|---|---|
| 4000 | DNS server could not open Active Directory — zone data unavailable |
| 4001 | DNS server was unable to open zone in the registry |
| 4004 | DNS server was unable to complete directory service enumeration of zone |
| 4007 | DNS server could not find Active Directory — disabling AD zones |
| 4010 | Zone was shut down due to directory service error |
| 4013 | DNS server is waiting for AD DS to signal initialization is complete |
| 4015 | DNS server critical error — the DNS server has encountered a critical error from Active Directory |
| 4016 | DNS server timed out waiting for notification of Active Directory initialization |
| 4019 | DNS server has reset the default zones |

### DNS Client Events (Source: Microsoft-Windows-DNS-Client)

| Event ID | Description |
|---|---|
| 1014 | Name resolution for the name `<hostname>` timed out after none of the configured DNS servers responded |
| 1015 | DNS client was unable to locate `<domain>` because DNS server was not available |

### DNS Debug Logging

Enable detailed per-query logging via DNS Manager (Server Properties → Debug Logging tab) or PowerShell:
```powershell
# Enable debug logging to a file
Set-DnsServerDiagnostics -All $True -LogFilePath "C:\DNS_Debug.log" `
    -MaxMBFileSize 500 -UseSystemEventLog $False

# Enable specific categories only
Set-DnsServerDiagnostics -Queries $True -Answers $True `
    -SendPackets $True -ReceivePackets $True
```

Debug log is written to `%SystemRoot%\System32\dns\dns.log` by default.

---

## Best Practices

### Forwarder Design

- Use conditional forwarders for specific namespaces (partner domains, Azure, AWS)
- Use global forwarders for internet resolution; prefer ISP or enterprise DNS resolvers
- Set forwarder timeout appropriately (default 3 seconds)
- Enable "Use root hints if no forwarders are available" as a fallback
- In hybrid environments: forward Azure private DNS zones to Azure DNS resolver endpoints

```powershell
Set-DnsServerForwarder -IPAddress "8.8.8.8","8.8.4.4" -UseRootHint $True
```

### Split-Brain DNS

Two implementation approaches:
1. **Two-zone model** — separate zones on separate servers (internal vs. external DNS infrastructure)
2. **DNS Policies + Zone Scopes** — single server serving different responses based on client subnet (preferred for Server 2016+)

```powershell
# Check if query comes from internal subnet; serve internal IP
Add-DnsServerQueryResolutionPolicy -Name "InternalPolicy" -Action ALLOW `
    -ClientSubnet "eq,InternalSubnet" -ZoneScope "InternalScope,1" `
    -ZoneName "contoso.com" -ProcessingOrder 1

# Default: serve external IP
Add-DnsServerQueryResolutionPolicy -Name "ExternalPolicy" -Action ALLOW `
    -ZoneScope "ExternalScope,1" -ZoneName "contoso.com" -ProcessingOrder 2
```

### Secure Dynamic Updates

- Always configure AD-integrated zones for "Secure only" dynamic updates
- Prevents unauthenticated computers from registering arbitrary records
- Requires domain membership for registration
- Use DHCP server credentials for DHCP-registered records

### DNSSEC Best Practices

- Use ECDSAP256/SHA-256 for new zone signings (modern, compact signatures)
- Enable NSEC3 (prevents zone walking)
- Distribute trust anchors to all validating resolvers in the forest
- Monitor key rollover events and ensure DS records are updated at parent zones after KSK rollovers
- Consider using hardware KSP (TPM or smart card) for KSK storage on high-security environments

### General Best Practices

- Place at least two DNS servers per domain (typically two AD DCs per site)
- Configure site-local DNS servers as primary for clients (reduces cross-site DNS traffic)
- Use AD-integrated zones rather than standard primary wherever possible
- Enable DNS debug logging in lab/test environments; monitor Event IDs 4000-4019 in production
- Regularly audit stale records using aging/scavenging
- Use DNS Manager or PowerShell consistently — mixing dnscmd and PowerShell in scripts can cause confusion

---

## References

- [DNS Overview — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/networking/dns/dns-overview)
- [Manage DNS Zones — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/networking/dns/manage-dns-zones)
- [DNS Policies Overview — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/networking/dns/deploy/dns-policies-overview)
- [DNSSEC Overview — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/networking/dns/dnssec-overview)
- [Sign DNS Zones with DNSSEC — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/networking/dns/sign-dnssec-zone)
- [DNS Aging and Scavenging — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/networking/dns/aging-scavenging)
- [DoH Public Preview for Windows DNS Server — TechCommunity](https://techcommunity.microsoft.com/blog/networkingblog/secure-dns-with-doh-public-preview-for-windows-dns-server/4493935)
- [AD-Integrated DNS Zones — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/active-directory-integrated-dns-zones)
