# Cloudflare DNS — Deep Dive Research

**Sources:** Cloudflare Developers (developers.cloudflare.com), Cloudflare Blog, Cloudflare Docs  
**Last updated:** April 2026  
**Products:** Authoritative DNS, Foundation DNS, 1.1.1.1 Public Resolver, DNS Firewall, Secondary DNS

---

## Architecture Overview

Cloudflare operates one of the world's largest anycast networks, spanning 300+ cities globally. All DNS products (authoritative, recursive, and firewall) run on this same infrastructure, providing extremely low-latency DNS responses and inherent DDoS resistance.

### Anycast Network Properties

- 300+ Points of Presence (PoPs) worldwide
- BGP anycast routing — DNS queries reach the nearest PoP automatically
- No TTL-based failover needed — routing is at the network layer
- DDoS mitigation is inline at every PoP
- Cloudflare has documented handling 4+ Tbps DDoS attacks without impact to DNS

### Proxy Mode vs DNS-Only Mode

Each DNS record in Cloudflare has a proxy status:

**Proxied (orange cloud):**
- Traffic flows through Cloudflare's network
- Real origin IP is hidden; visitors see Cloudflare anycast IPs
- Enables WAF, CDN caching, DDoS protection, Workers, Rate Limiting
- Only available for A, AAAA, and CNAME records
- HTTP/HTTPS traffic only (ports 80, 443 and a limited set of alternative ports)
- DNS response returns Cloudflare IPs, not origin IPs

**DNS-only (grey cloud):**
- Cloudflare serves authoritative DNS but does not proxy traffic
- Real IP address is returned in DNS responses
- No WAF, caching, or DDoS proxy benefit
- Required for: MX, TXT, SRV, CAA, NS records, and traffic that isn't HTTP/HTTPS
- Still benefits from Cloudflare's anycast DNS infrastructure and DDoS protection at DNS layer

---

## Authoritative DNS

### Zone Setup Options

**Full Setup (primary):**
- Cloudflare is the primary authoritative DNS provider
- Transfer nameservers at registrar to Cloudflare nameservers (`*.ns.cloudflare.com`)
- All DNS changes made in Cloudflare Dashboard/API

**CNAME Setup (partial) — Business/Enterprise only:**
- Use Cloudflare's reverse proxy on individual subdomains
- Keep existing authoritative DNS provider
- Point specific CNAMEs to `<hostname>.cdn.cloudflare.net`

**Secondary Setup:**
- Cloudflare receives zone transfers from your primary provider (AXFR/IXFR)
- Cloudflare serves as secondary/slave nameserver
- Available on Enterprise plan

### Record Management

All standard DNS record types supported:
- A, AAAA, CNAME, MX, TXT, SRV, CAA, NS, PTR, NAPTR, CERT, DNSKEY, DS, HTTPS, SVCB, TLSA, URI

**Cloudflare-specific features:**
- Automatic CNAME flattening at zone apex (resolves CNAME chain and returns A records)
- Quick scan on zone creation auto-detects existing DNS records
- Email configuration helpers: SPF, DKIM, DMARC record wizards

### TTL Management

- Minimum TTL: 1 second (for proxied records)
- DNS-only records: minimum 60 seconds
- Proxied records always appear with TTL 300 regardless of configured TTL
- Auto TTL: Cloudflare selects appropriate TTL based on record type

---

## DNSSEC

### One-Click DNSSEC

Cloudflare provides simplified DNSSEC enabling:
1. Enable DNSSEC in Dashboard or via API
2. Cloudflare generates and manages KSK and ZSK automatically
3. Copy DS record displayed in Dashboard and add to registrar

For domains registered with Cloudflare Registrar: DS record is automatically published (no manual step).

### Standard DNSSEC Key Management

- Cloudflare manages key generation, signing, rotation, and re-signing
- ECDSA (P-256) algorithm used
- ZSK rotation: automatic, transparent
- KSK rotation: managed by Cloudflare, DS record update automated where possible

### Foundation DNS Per-Account DNSSEC

Foundation DNS introduces per-account (and per-zone) KSK/ZSK rotation:
- Previously: Cloudflare used globally shared DNSSEC keys across all accounts
- Now: each account (Enterprise) gets dedicated DNSSEC keys
- Addresses compliance requirements for organizations with strict key rotation policies
- Manageable via API and Dashboard

### Multi-Signer DNSSEC

For multi-provider DNS deployments, Cloudflare supports Multi-Signer DNSSEC (RFC 8901):
- Multiple DNS providers each sign the zone with their own keys
- Both providers' DNSKEY records are present in the zone
- Enables DNSSEC continuity during provider migrations
- Caution: leaving Pre-signed DNSSEC enabled after converting to full zone causes `REFUSED` responses

---

## Foundation DNS (Enterprise)

Foundation DNS is Cloudflare's premium authoritative DNS offering, included in enterprise contracts.

### Three Anycast Groups (April 2025+)

Standard Cloudflare DNS uses one anycast group. Foundation DNS uses:
- **Three separate anycast groups** for nameserver IPs
- Each group advertises from geographically distinct data centers
- Guarantee: at least one nameserver IP advertises from a different data center than all others
- Verification via NSID queries (NS ID prefix reveals serving data center code)

**Nameserver distribution across TLDs:**
- Nameservers span multiple TLDs (.com, .net, .org, and others)
- Protects against large-scale DNS outages affecting a single TLD registry
- Multiple branches of the global DNS tree structure

Previously: standard DNS provided six IPs (two nameservers × three anycast IPs each), all advertising from identical locations.

### Dedicated Nameservers

- Foundation DNS customers receive dedicated nameservers not shared with other customers
- Reduces blast radius if another Cloudflare customer experiences DDoS targeting their nameserver IPs
- Enables predictable performance characteristics

### Per-Account/Zone Key Management

- Individual KSK and ZSK rotation schedules per account or zone
- Configurable via API and dashboard
- Meets enterprise compliance requirements (e.g., PCI DSS, FedRAMP key rotation requirements)

### Advanced Analytics (GraphQL)

New GraphQL dataset replaces legacy DNS Analytics API:
- Query window: 31 days (vs. a few days previously)
- New dimensions: `sourceIP` for resolver tracking, `responseCode`, `queryType`
- Percentile metrics: `processingTimeUsP90`, `processingTimeUsMean`
- Example: query mean and P90 processing time grouped by source IP over 31-day window

```graphql
{
  viewer {
    zones(filter: { zoneTag: $zoneTag }) {
      dnsAnalyticsAdaptiveGroups(
        limit: 100
        filter: { datetime_geq: $start, datetime_leq: $end }
        orderBy: [count_DESC]
      ) {
        count
        dimensions {
          queryName
          responseCode
          clientSourceIP
        }
      }
    }
  }
}
```

### Zone-Level Settings

Foundation DNS exposes previously API-inaccessible settings:
- Advanced nameserver enablement per zone
- Secondary DNS overrides
- Multi-provider DNS support
- Two-week software soak period for Foundation DNS nameservers (stability before upgrades reach production)

### Pricing

- 10,000 DNS-only domains and 1 million DNS records included by default
- Unmetered DDoS mitigation — no overage fees for DDoS attacks

---

## 1.1.1.1 Public Resolver

### Overview

Cloudflare's public recursive DNS resolver, operated in partnership with APNIC. Available free to anyone.

**IP addresses:**

| Service | IPv4 | IPv6 |
|---|---|---|
| Standard | 1.1.1.1, 1.0.0.1 | 2606:4700:4700::1111, 2606:4700:4700::1001 |
| 1.1.1.1 for Families (malware) | 1.1.1.2, 1.0.0.2 | 2606:4700:4700::1112, 2606:4700:4700::1002 |
| 1.1.1.1 for Families (malware+adult) | 1.1.1.3, 1.0.0.3 | 2606:4700:4700::1113, 2606:4700:4700::1003 |

### Encrypted DNS Protocols

**DNS over HTTPS (DoH):**
- URL: `https://cloudflare-dns.com/dns-query`
- Also: `https://1.1.1.1/dns-query`, `https://1.0.0.1/dns-query`
- Supports GET and POST methods
- JSON API: `https://cloudflare-dns.com/dns-query?name=example.com&type=AAAA`

**DNS over TLS (DoT):**
- Host: `1dot1dot1dot1.cloudflare-dns.com`
- Port: 853
- Server Name Indication (SNI): `cloudflare-dns.com`
- Also: TLS to `1.1.1.1:853`

**DNS over QUIC (DoQ):**
- Available via `1.1.1.1` on QUIC port 853
- Uses QUIC transport (UDP-based, 0-RTT connection establishment)
- Reduces latency compared to DoT (no TCP handshake)

**DNS over Tor:**
- Hidden service: `dns4torpnlfs2ifuz2s2yf3fc7rdmsbhm6rw75euj35pac6ap25zgqad.onion`

### Privacy Commitments

- No selling or sharing of personal data with third parties
- No advertising use of DNS query data
- Cloudflare commits to wiping all logs within 24 hours
- KPMG audits privacy practices annually
- Adherence to APNIC privacy policy

### 1.1.1.1 for Families

**1.1.1.2 / 1.0.0.2** — Block malware and phishing domains  
**1.1.1.3 / 1.0.0.3** — Block malware, phishing, AND adult content

Does not require account setup — simply configure as DNS resolver.

### Performance

Measured as the fastest public DNS resolver globally (faster than 8.8.8.8, 9.9.9.9) in multiple independent benchmarks. Cloudflare's extensive points of presence ensure low-latency resolution from most locations worldwide.

**Notable incident:** July 14, 2025 — Cloudflare suffered a ~62-minute global outage of the 1.1.1.1 resolver (post-mortem documented). This highlighted the importance of configuring fallback resolvers.

### Resolver Policies (Cloudflare One)

For enterprise customers using Cloudflare One (Zero Trust), resolver policies enable:
- Per-DNS-query policy enforcement
- Integration with Gateway for filtering
- Logging of DNS queries per user/device
- Custom blocking rules beyond the 1.1.1.1 Families categories

---

## DNS Firewall (Enterprise)

Cloudflare DNS Firewall protects **authoritative nameservers** by sitting in front of them as a caching proxy.

**This is distinct from Gateway/Resolver DNS filtering** (which protects outbound DNS from users).

### How it Works

- DNS queries to your authoritative nameservers are proxied through Cloudflare's network
- No changes to your authoritative nameserver software required
- Cloudflare's anycast network absorbs DDoS attacks targeting DNS
- Cached responses reduce query load on origin nameservers

### Features

- **DDoS mitigation** — Unmetered DDoS protection for authoritative nameservers
- **Rate limiting** — Per-IP and aggregate rate limiting
- **Caching** — Configurable cache TTL overrides
- **Stale records** — Serve stale cached records if origin is unreachable
- **Minimum TTL** — Override low TTLs to reduce origin load
- **Analytics** — Query analytics via dashboard and API

### Configuration

No nameserver change needed — configure upstream DNS servers in Cloudflare DNS Firewall and update your NS records to point to Cloudflare's proxy anycast IPs.

---

## Secondary DNS

Cloudflare can act as a secondary DNS provider, receiving zone data from your primary authoritative nameserver.

**Enterprise plan only.**

### Zone Transfer Protocols

- **AXFR (Full Zone Transfer)** — TCP; transfers entire zone on first sync or when IXFR fails
- **IXFR (Incremental Zone Transfer)** — TCP; transfers only changed records since last serial

Cloudflare prefers IXFR after initial AXFR. Internal propagation to Cloudflare edge: typically < 5 seconds end-to-end.

Performance metrics from Cloudflare's published architecture:
- Zone transfer completion: ~800ms at 99th percentile
- Zone building: ~10ms at 99th percentile
- Quicksilver edge propagation: < 1 second at 95th percentile

### TSIG Authentication

TSIG (RFC 2845) is optional but strongly recommended for authenticating zone transfers:
- Prevents unauthorized zone transfers
- Protects against spoofed NOTIFY messages

```bash
# Configure via Cloudflare API (example)
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/secondary_dns/tsigs" \
    -H "Authorization: Bearer <api_token>" \
    -H "Content-Type: application/json" \
    --data '{"name":"my-tsig","algo":"hmac-sha256","secret":"base64-secret=="}'
```

### Setup Process

1. Configure primary nameserver to allow AXFR/IXFR to Cloudflare's transfer IPs
2. Configure TSIG key on both primary and Cloudflare (optional but recommended)
3. Create secondary zone in Cloudflare Dashboard or API
4. Specify peer server (primary nameserver IP)
5. Trigger initial zone transfer
6. Add Cloudflare nameservers as additional NS records at registrar

### Multi-Provider DNS

Secondary DNS enables true multi-provider DNS:
- Your primary provider and Cloudflare both serve the zone
- Higher availability — zone served even if primary provider has outage
- Both sets of nameservers appear in the zone's NS records

**Secondary DNS Override setting:**
When records are transferred that include CNAME records pointing to internal hostnames, use Secondary DNS Override to control proxy status on transferred records.

---

## API Reference

### v4 REST API

Base URL: `https://api.cloudflare.com/client/v4/`

Authentication: Bearer token (`Authorization: Bearer <token>`) or API Key.

**Zone management:**
```bash
# List zones
curl -H "Authorization: Bearer $TOKEN" \
    "https://api.cloudflare.com/client/v4/zones"

# Create DNS record
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"A","name":"www","content":"1.2.3.4","ttl":3600,"proxied":true}'

# Update DNS record
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"content":"1.2.3.5"}'

# Delete DNS record
curl -X DELETE "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}" \
    -H "Authorization: Bearer $TOKEN"

# Enable DNSSEC
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/{zone_id}/dnssec" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"status":"active"}'

# Get DNSSEC details (DS record)
curl -H "Authorization: Bearer $TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/{zone_id}/dnssec"

# DNS Analytics
curl -H "Authorization: Bearer $TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_analytics/report?metrics=queryCount&dimensions=responseCode"
```

### Terraform (cloudflare provider)

```hcl
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Zone data source
data "cloudflare_zone" "example" {
  name = "example.com"
}

# DNS record (proxied)
resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zone.example.id
  name    = "www"
  value   = "1.2.3.4"
  type    = "A"
  proxied = true
}

# DNS record (DNS-only)
resource "cloudflare_record" "mail" {
  zone_id  = data.cloudflare_zone.example.id
  name     = "mail"
  value    = "1.2.3.5"
  type     = "A"
  proxied  = false
  ttl      = 3600
}

# MX record
resource "cloudflare_record" "mx" {
  zone_id  = data.cloudflare_zone.example.id
  name     = "@"
  value    = "mail.example.com"
  type     = "MX"
  priority = 10
  proxied  = false
}

# TXT record (SPF)
resource "cloudflare_record" "spf" {
  zone_id = data.cloudflare_zone.example.id
  name    = "@"
  value   = "v=spf1 include:_spf.google.com -all"
  type    = "TXT"
  proxied = false
  ttl     = 3600
}

# DNSSEC
resource "cloudflare_zone_dnssec" "example" {
  zone_id = data.cloudflare_zone.example.id
}

# Zone settings
resource "cloudflare_zone_settings_override" "example" {
  zone_id = data.cloudflare_zone.example.id
  settings {
    ssl = "full"
    min_ttl = 60
  }
}
```

### cloudflare-go SDK

```go
import (
    "github.com/cloudflare/cloudflare-go"
)

api, err := cloudflare.NewWithAPIToken(os.Getenv("CLOUDFLARE_API_TOKEN"))

// Create a DNS record
record := cloudflare.CreateDNSRecordParams{
    Type:    "A",
    Name:    "www",
    Content: "1.2.3.4",
    Proxied: cloudflare.BoolPtr(true),
    TTL:     1,
}
resp, err := api.CreateDNSRecord(ctx, cloudflare.ZoneIdentifier(zoneID), record)
```

---

## Best Practices

### Zone Management

- Use Terraform or the Cloudflare API for infrastructure-as-code DNS management
- Enable DNSSEC for all zones — one-click in dashboard, DS record auto-published for Cloudflare Registrar domains
- Use proxied mode (orange cloud) for web-facing A/AAAA/CNAME records to hide origin IP and enable WAF/DDoS protection
- Keep MX, TXT, SRV records as DNS-only (grey cloud) — these cannot be proxied

### Security

- Enable DNSSEC to protect against cache poisoning
- Proxy mode hides origin IP from DNS responses — an essential defense against direct-to-origin DDoS
- For authoritative-only servers (not proxied), use DNS Firewall to get DDoS protection without proxy
- Use per-zone API tokens with minimal permissions rather than global API keys

### Secondary DNS

- Use TSIG for all zone transfers — protects against unauthorized zone data disclosure
- Configure IP-based ACLs on primary in addition to TSIG (defense in depth)
- Test failover: temporarily disable primary and verify Cloudflare continues serving zone
- Monitor zone transfer status via Cloudflare API to detect sync failures

### Foundation DNS

- For enterprise: enable Foundation DNS to get dedicated nameservers and 3-group anycast
- Use GraphQL analytics to identify resolver patterns and potential abuse
- Configure per-account DNSSEC key rotation to meet compliance requirements

### Troubleshooting

- Use `dig @ns1.cloudflare.com <name>` to query Cloudflare authoritative directly
- Use `dig @1.1.1.1 <name>` to test via resolver
- Check zone transfer status via API: `GET /zones/{zone_id}/secondary_dns/incoming`
- DNSSEC issues: verify DS record matches what `GET /zones/{zone_id}/dnssec` returns
- Use NSID queries to identify which Cloudflare PoP is responding: `dig +nsid example.com @1.1.1.1`

---

## References

- [Cloudflare DNS Documentation](https://developers.cloudflare.com/dns/)
- [Foundation DNS](https://developers.cloudflare.com/dns/foundation-dns/)
- [Improving Authoritative DNS with Foundation DNS — Cloudflare Blog](https://blog.cloudflare.com/foundation-dns-launch/)
- [Announcing Foundation DNS — Cloudflare Blog](https://blog.cloudflare.com/foundation-dns/)
- [Secondary DNS Deep Dive — Cloudflare Blog](https://blog.cloudflare.com/secondary-dns-deep-dive/)
- [1.1.1.1 Public DNS Resolver](https://developers.cloudflare.com/1.1.1.1/)
- [1.1.1.1 for Families — Cloudflare Blog](https://blog.cloudflare.com/introducing-1-1-1-1-for-families/)
- [Incoming Zone Transfers Setup](https://developers.cloudflare.com/dns/zone-setups/zone-transfers/cloudflare-as-secondary/setup/)
- [Cloudflare DNS Full Documentation (LLMs text)](https://developers.cloudflare.com/dns/llms-full.txt)
