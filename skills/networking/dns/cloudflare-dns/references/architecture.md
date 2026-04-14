# Cloudflare DNS Architecture Reference

## Anycast Network

300+ PoPs worldwide. BGP anycast routing to nearest PoP. Inline DDoS mitigation at every PoP. 4+ Tbps documented DDoS handling without DNS impact.

## Proxy Mode vs DNS-Only

**Proxied (orange cloud)**: traffic through Cloudflare; origin IP hidden; WAF/CDN/DDoS; HTTP/HTTPS only; A/AAAA/CNAME only.

**DNS-only (grey cloud)**: authoritative DNS only; real IP returned; required for MX/TXT/SRV/CAA/NS.

## Zone Setups

Full: change NS to Cloudflare at registrar (all plans).
CNAME (partial): keep existing DNS; point CNAMEs to cdn.cloudflare.net (Business/Enterprise).
Secondary: receive zone transfers from primary (Enterprise).

## Record Features

CNAME flattening at zone apex (automatic). Quick scan auto-detects existing records. Email config helpers (SPF, DKIM, DMARC). Minimum TTL: 1s (proxied), 60s (DNS-only).

## DNSSEC

One-click enable. Cloudflare manages KSK/ZSK (ECDSA P-256). ZSK rotation automatic. DS record auto-published for Cloudflare Registrar domains.

Multi-Signer DNSSEC (RFC 8901): both providers sign with own keys; both DNSKEY records in zone.

Foundation DNS: per-account/zone key rotation for compliance.

## Foundation DNS (Enterprise)

Three separate anycast groups. Dedicated (not shared) nameservers. Nameservers span multiple TLDs. Per-account DNSSEC rotation. Advanced GraphQL analytics (31-day window, sourceIP, percentiles). Two-week software soak period.

## 1.1.1.1 Public Resolver

Standard: 1.1.1.1/1.0.0.1. Families: 1.1.1.2 (malware), 1.1.1.3 (malware+adult).

DoH: `https://cloudflare-dns.com/dns-query`. DoT: port 853. DoQ: QUIC port 853. Tor hidden service available.

Privacy: no data selling, 24-hour log wipe, KPMG audit.

## DNS Firewall (Enterprise)

Proxies DNS queries to protect authoritative nameservers. DDoS mitigation, rate limiting, caching, stale serving. No software changes needed.

## Secondary DNS (Enterprise)

AXFR/IXFR from primary. TSIG recommended. Edge propagation <5s. Zone transfer ~800ms P99. Enables multi-provider DNS.

## API (v4 REST)

Base: `https://api.cloudflare.com/client/v4/`. Auth: Bearer token. Resources: zones, dns_records, dnssec, secondary_dns.

## Terraform (cloudflare provider)

Resources: `cloudflare_record`, `cloudflare_zone_dnssec`, `cloudflare_zone_settings_override`.

## Troubleshooting

```bash
dig @ns1.cloudflare.com example.com     # Query Cloudflare authoritative
dig @1.1.1.1 example.com                # Query via resolver
dig +nsid example.com @1.1.1.1          # Identify serving PoP
```

DNSSEC: verify DS matches `GET /zones/{zone_id}/dnssec`. Zone transfer status: `GET /zones/{zone_id}/secondary_dns/incoming`.
