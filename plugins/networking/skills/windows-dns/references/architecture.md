# Windows DNS Architecture Reference

## AD-Integrated Zones

Zones stored in AD (on Domain Controllers) provide multi-master updates, automatic replication, secure dynamic updates, and encrypted storage.

### Replication Scopes
- `ForestDnsZones`: All DCs in forest running DNS
- `DomainDnsZones`: All DCs in domain running DNS (default)
- Domain partition: Legacy Windows 2000 compat
- Custom partition: Admin-defined subset

### Zone Types
- Primary: read/write (file or AD-integrated)
- Secondary: read-only via AXFR/IXFR (file only)
- Stub: SOA + NS + glue records only
- Conditional Forwarder: forwards specific domain queries
- Reverse Lookup: PTR records (in-addr.arpa / ip6.arpa)

## DNS Policies (Server 2016+)

PowerShell-only feature for behavior customization:

### Policy Objects
- **Client Subnets**: named IPv4/IPv6 subnet groups
- **Zone Scopes**: separate instances of a zone with different records
- **Recursion Scopes**: control recursion per client group

### Match Criteria
Client Subnet, Transport Protocol, Internet Protocol, Server Interface IP, FQDN (wildcards), Query Type, Time of Day

### Use Cases
- Geo-location routing (different IPs per client subnet)
- Split-brain DNS (internal vs external responses)
- DNS sinkholing (IGNORE action for malicious domains)
- Recursion control (internal clients get recursion, external don't)
- Zone transfer restrictions (per subnet)

## DNSSEC

### Key Types
- **KSK**: Signs DNSKEY RRset; long-lived (755 days default); DS record in parent
- **ZSK**: Signs all other records; shorter-lived (90 days); prepublish rollover

### Supported Algorithms
ECDSAP256/SHA-256 (recommended), ECDSAP384/SHA-384, RSA/SHA-256, RSA/SHA-512

### Key Master
Authoritative server responsible for key generation and distribution. For AD-integrated zones, signs zone and distributes private keys via AD replication.

### Trust Anchors
DNSKEY and DS records stored in forest directory partition (DCs) or TrustAnchors.dns (standalone). View: `Get-DnsServerTrustAnchor -ZoneName "example.com"`

### Signing and Rollover
```powershell
Invoke-DnsServerZoneSign -ZoneName "example.com" -SignWithDefault -Force
Set-DnsServerDnsSecZoneSetting -ZoneName "example.com" -NSec3RandomSaltLength 8 -NSec3Iterations 50
```
KSK rollover: double-signature method, DS update manual
ZSK rollover: prepublish, fully automatic

## Aging and Scavenging

- No-refresh interval (7 days): suppresses refresh writes
- Refresh interval (7 days): window for record refresh
- Total lifetime: 14 days (no-refresh + refresh)
- Must be enabled at server AND zone level
- Only dynamic records (non-zero timestamp) eligible
- `dnscmd /ageallrecords` makes all records eligible (use cautiously)
- Best practice: scavenging period = DHCP lease duration + 1 day
