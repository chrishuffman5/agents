# DNS Fundamentals

## DNS Resolution Flow

### Full Resolution Path

```
Client (stub resolver)
  └── Recursive Resolver (ISP, enterprise, 1.1.1.1, 8.8.8.8)
       └── Root Nameservers (. zone, 13 root server clusters)
            └── TLD Nameservers (.com, .net, .org, etc.)
                 └── Authoritative Nameservers (example.com)
                      └── Response returned to client
```

1. **Stub resolver** (client OS) checks local cache, hosts file, then queries configured recursive resolver
2. **Recursive resolver** checks its cache. On miss, performs iterative resolution:
   a. Queries a root nameserver for `.` -- gets referral to TLD nameserver
   b. Queries TLD nameserver for `.com` -- gets referral to domain's authoritative nameservers
   c. Queries authoritative nameserver for `example.com` -- gets the answer
3. Recursive resolver caches the answer for the TTL duration
4. Response returned to stub resolver, which caches locally

### Key Concepts

- **Recursive query**: Client expects a complete answer (recursive resolver does the work)
- **Iterative query**: Server returns the best answer it has (referral or answer); resolver follows referrals
- **Caching**: Every resolver in the chain caches results per TTL; reduces query load
- **Negative caching**: NXDOMAIN and NODATA responses are also cached (per SOA minimum TTL / RFC 2308)

## Record Types

### Address Records

| Type | Purpose | Example |
|---|---|---|
| A | IPv4 address | `www IN A 192.0.2.10` |
| AAAA | IPv6 address | `www IN AAAA 2001:db8::10` |

### Alias and Delegation

| Type | Purpose | Notes |
|---|---|---|
| CNAME | Canonical name (alias) | Cannot coexist with other records at same name; cannot be at zone apex (use Alias/ANAME) |
| NS | Nameserver delegation | Delegates a zone or subdomain to specified nameservers |
| SOA | Start of Authority | Required; defines zone parameters (serial, refresh, retry, expire, minimum TTL) |

### Mail

| Type | Purpose | Example |
|---|---|---|
| MX | Mail exchange | `@ IN MX 10 mail.example.com.` (priority + target) |
| TXT (SPF) | Sender Policy Framework | `"v=spf1 ip4:192.0.2.0/24 -all"` |
| TXT (DKIM) | DomainKeys Identified Mail | Public key for email signing verification |
| TXT (DMARC) | Domain-based Message Authentication | `"v=DMARC1; p=reject; rua=mailto:dmarc@example.com"` |

### Service and Security

| Type | Purpose | Example |
|---|---|---|
| SRV | Service locator | `_sip._tcp IN SRV 10 20 5060 sipserver.example.com.` |
| CAA | Certificate Authority Authorization | Restricts which CAs can issue certificates for the domain |
| TLSA | TLS Authentication (DANE) | Associates TLS certificate with DNS name |
| PTR | Reverse lookup (IP to name) | In `in-addr.arpa` or `ip6.arpa` zones |
| DS | Delegation Signer (DNSSEC) | Links parent zone to child zone trust chain |
| DNSKEY | Public key (DNSSEC) | KSK or ZSK for signature verification |
| RRSIG | Record signature (DNSSEC) | Digital signature for a DNS record set |
| NSEC/NSEC3 | Authenticated denial of existence | Proves a name does not exist (NSEC3 prevents zone walking) |

## Zone Transfers

### AXFR (Full Zone Transfer)
- Transfers entire zone data from primary to secondary
- TCP-based; secondary initiates the transfer
- Used for initial synchronization or when IXFR fails
- Protect with ACLs and TSIG authentication

### IXFR (Incremental Zone Transfer)
- Transfers only changes since a specified serial number
- More efficient than AXFR for large zones with small changes
- Falls back to AXFR if incremental data unavailable
- Requires serial number tracking (SOA serial)

### NOTIFY
- Primary server sends NOTIFY message to secondaries when zone changes
- Secondaries immediately check SOA serial and initiate transfer if needed
- Faster than waiting for SOA refresh interval

### TSIG Authentication
- Cryptographic authentication for zone transfers and dynamic updates
- HMAC-based (SHA-256 recommended); shared secret between primary and secondary
- Prevents unauthorized zone transfers and spoofed updates

## DNSSEC Chain of Trust

### Overview

DNSSEC adds cryptographic signatures to DNS records, creating a chain of trust from the root zone to individual domain records:

```
Root Zone (.)
  └── Signs .com TLD with root KSK --> DS record at root points to .com KSK
       └── .com TLD signs example.com NS with .com KSK
            └── DS record at .com points to example.com KSK
                 └── example.com signs its records with ZSK
                      └── KSK signs the DNSKEY RRset (ZSK + KSK)
```

### Key Types

**KSK (Key Signing Key):**
- Signs only the DNSKEY record set
- Long-lived (typically 1-2 years)
- Higher key strength (2048-bit RSA or 256-bit ECDSA)
- DS record derived from KSK is published in parent zone
- KSK rollover requires parent zone DS record update

**ZSK (Zone Signing Key):**
- Signs all other record sets in the zone
- Shorter-lived (typically 90 days)
- Can be smaller key for performance
- ZSK rollover is fully automated (prepublish method)

**CSK (Combined Signing Key):**
- Single key serving both KSK and ZSK roles
- Simplifies key management (used by BIND `default` policy, Cloudflare)
- Trade-off: rolling requires DS update at parent (like KSK)

### DS Record (Delegation Signer)

The DS record is the trust anchor linking parent to child:
- Published in the parent zone (e.g., .com publishes DS for example.com)
- Contains a hash of the child zone's KSK
- Validators use DS to verify the child's DNSKEY, then use DNSKEY to verify RRSIG signatures
- DS record must be updated at registrar/parent when KSK is rolled

### Validation Process

1. Resolver has trust anchor for root zone (built-in)
2. Queries root for `.com` NS -- gets RRSIG, validates with root DNSKEY
3. Follows DS record for `.com` -- validates `.com` DNSKEY
4. Queries `.com` for `example.com` NS -- validates with `.com` DNSKEY
5. Follows DS record for `example.com` -- validates `example.com` DNSKEY
6. Queries `example.com` for `www.example.com` A -- validates RRSIG with ZSK

### Algorithm Recommendations

| Algorithm | Code | Recommendation |
|---|---|---|
| ECDSAP256SHA256 | 13 | Recommended (compact signatures, fast) |
| ECDSAP384SHA384 | 14 | High-security environments |
| ED25519 | 15 | Modern, very compact |
| RSASHA256 | 8 | Widely compatible, larger signatures |
| RSASHA1 | 5/7 | Deprecated -- avoid |

### NSEC vs NSEC3

- **NSEC**: Proves non-existence by listing the next existing name. Allows zone enumeration (walking).
- **NSEC3**: Uses hashed owner names to prove non-existence. Prevents zone walking. RFC 9276 recommends iterations=0, salt-length=0.

## Encrypted DNS Protocols

### DNS over HTTPS (DoH)
- DNS queries/responses over HTTPS (port 443)
- Blends with regular HTTPS traffic; difficult to block/filter
- Standard: RFC 8484
- Used by browsers (Firefox, Chrome) and OS resolvers

### DNS over TLS (DoT)
- DNS queries/responses over TLS (port 853)
- Dedicated port makes it visible to network monitoring
- Standard: RFC 7858
- Easier to detect and manage than DoH

### DNS over QUIC (DoQ)
- DNS over QUIC transport (port 853)
- 0-RTT connection establishment; lower latency than DoT
- Standard: RFC 9250
- Emerging; supported by Cloudflare 1.1.1.1

### Comparison

| Feature | DoH | DoT | DoQ |
|---|---|---|---|
| Port | 443 | 853 | 853 (UDP) |
| Visibility | Blends with HTTPS | Dedicated port | Dedicated port |
| Blockable | Hard to block | Easy to block | Easy to block |
| Performance | Good | Good | Best (0-RTT) |
| Browser support | Wide | Limited | Emerging |

## Caching and TTL

### TTL (Time To Live)

- Defines how long a record can be cached (in seconds)
- Set per record or per zone ($TTL directive)
- Lower TTL = faster propagation of changes but more queries to authoritative
- Higher TTL = fewer queries but slower change propagation

### TTL Guidelines

| Scenario | Recommended TTL | Notes |
|---|---|---|
| Stable records (MX, NS) | 86400 (24h) | Rarely change |
| Standard A/AAAA records | 3600 (1h) | Balance of freshness and efficiency |
| Pre-migration | 300 (5m) | Lower TTL before changes; raise after |
| Dynamic / failover | 60 (1m) | Quick failover response |
| CDN/proxy records | Auto or 300 | CDN controls effective caching |

### Negative Caching (RFC 2308)

NXDOMAIN and NODATA responses are cached for the SOA minimum field duration. Typical: 300s (5 minutes). Too-high negative TTL delays recovery when records are added.

## Split-Horizon DNS

Split-horizon (split-brain) DNS returns different answers based on the source of the query:

### Implementation Approaches

1. **Separate servers**: Internal DNS servers for internal clients; external DNS for public
2. **Views (BIND)**: Single server with `view "internal"` and `view "external"` matching on client ACL
3. **DNS Policies + Zone Scopes (Windows)**: Single server with zone scopes returning different records per client subnet
4. **Separate zones (Cloud)**: Private hosted zone (Route 53) + public hosted zone

### Design Rules

- Internal view should resolve both internal AND external names
- External view should only resolve public names
- Consistency: records accessed from both sides must resolve correctly in both views
- Management: changes must be applied to the correct view/scope

## DNS Security Patterns

### RPZ (Response Policy Zones)

RPZ intercepts DNS responses and substitutes custom answers:
- **NXDOMAIN**: Return "domain doesn't exist" for blocked domains
- **CNAME redirect**: Redirect to a sinkhole/warning page
- **DROP**: Silently drop the query
- **PASSTHRU**: Explicitly allow through despite other RPZ policies

Trigger types: qname (query name), client-ip, response-ip, nsdname, nsip

Providers: Spamhaus, SURBL, Infoblox threat feeds, custom internal lists

### DNS Sinkholing

Redirect known-malicious domains to a controlled sinkhole server:
- Sinkhole logs connection attempts for incident response
- Prevents malware C2 communication
- Implemented via RPZ CNAME redirect or DNS policy

### DNS Firewall (Cloud)

Cloud DNS firewalls filter outbound DNS queries:
- Route 53 DNS Firewall: per-VPC, managed + custom domain lists, ALLOW/ALERT/BLOCK
- Cloudflare Gateway: per-user/device policy, integrates with Zero Trust
- Primary defense against DNS-based data exfiltration

### Rate Limiting (RRL)

Limits DNS response rate per source IP to mitigate amplification attacks:
- `responses-per-second`: cap per source IP
- `slip`: fraction of responses sent as truncated (TC bit) instead of dropped
- Prevents authoritative servers from being used as DDoS amplifiers
