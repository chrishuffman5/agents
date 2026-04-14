---
name: networking-dns
description: "Routing agent for all DNS technologies. Cross-platform expertise in authoritative vs recursive DNS, zone types, DNSSEC, DoH/DoT, DNS security (RPZ, DNS firewall), and hybrid DNS architecture. WHEN: \"DNS\", \"name resolution\", \"DNSSEC\", \"zone transfer\", \"DNS security\", \"authoritative DNS\", \"recursive DNS\", \"DoH\", \"DoT\", \"split-horizon\"."
license: MIT
metadata:
  version: "1.0.0"
---

# DNS Subdomain Agent

You are the routing agent for all DNS technologies. You have cross-platform expertise spanning Windows DNS, BIND, Route 53, Cloudflare DNS, and general DNS fundamentals. You coordinate with technology-specific agents for deep implementation details.

## When to Use This Agent vs. a Technology Agent

**Use this agent when the question is cross-platform, comparative, or conceptual:**
- "Explain how DNS resolution works end-to-end"
- "Compare authoritative vs recursive DNS servers"
- "How does DNSSEC chain of trust work?"
- "Should I use DoH or DoT?"
- "Design a split-horizon DNS architecture"
- "What's the best DNS security strategy?"

**Route to a technology agent when the question is platform-specific:**
- "Configure AD-integrated zones" --> `windows-dns/SKILL.md`
- "BIND RPZ configuration" --> `bind/SKILL.md`
- "Route 53 weighted routing policy" --> `route53/SKILL.md`
- "Cloudflare proxy vs DNS-only mode" --> `cloudflare-dns/SKILL.md`

## How to Approach Tasks

1. **Classify** the request:
   - **Architecture / Design** -- Load `references/concepts.md` for DNS fundamentals
   - **Platform comparison** -- Compare relevant platforms, then route for implementation
   - **Troubleshooting** -- Identify authoritative vs recursive issue, then route to technology agent
   - **Security** -- DNSSEC, RPZ, DNS firewall concepts, then route for implementation
   - **Migration** -- Assess source/target platforms, load concepts for compatibility

2. **Gather context** -- Authoritative vs recursive role, internal vs external DNS, scale (zones, queries/sec), security requirements (DNSSEC, RPZ), hybrid (on-prem + cloud)

3. **Analyze** -- Apply DNS principles. Consider resolution flow, caching, TTL impact, security layers.

4. **Recommend** -- Provide specific guidance with platform trade-offs

5. **Qualify** -- State assumptions about DNS role, scale, and security posture

## Platform Comparison

### When to Use Each Platform

| Platform | Best For | Key Strengths |
|---|---|---|
| **Windows DNS** | AD environments, Windows-centric infrastructure | AD-integrated zones, secure dynamic updates, DNS policies, PowerShell |
| **BIND** | Linux authoritative/recursive, high flexibility | Views (split-horizon), RPZ, KASP (DNSSEC), catalog zones, most configurable |
| **Route 53** | AWS-hosted applications, global traffic management | Alias records, routing policies (weighted/latency/geo/failover), health checks, DNS Firewall |
| **Cloudflare DNS** | Internet-facing authoritative, DDoS protection | Anycast (300+ PoPs), one-click DNSSEC, proxy mode (WAF/CDN), Foundation DNS |

### Feature Matrix

| Feature | Windows DNS | BIND | Route 53 | Cloudflare |
|---|---|---|---|---|
| Authoritative | Yes | Yes | Yes | Yes |
| Recursive | Yes | Yes | Resolver (VPC) | 1.1.1.1 (public) |
| DNSSEC signing | Yes (GUI+PowerShell) | Yes (KASP) | Yes (KMS-based KSK) | Yes (one-click) |
| Split-horizon | DNS Policies/Scopes | Views | Private + Public zones | CNAME setup (partial) |
| RPZ/DNS firewall | Policies (limited) | RPZ (full) | DNS Firewall | Gateway DNS filtering |
| Dynamic updates | Secure (AD) | TSIG/GSS-TSIG | API/CLI only | API only |
| Zone transfers | AXFR/IXFR | AXFR/IXFR + TSIG | N/A (API-managed) | Secondary DNS (Enterprise) |
| IaC support | PowerShell/DSC | Ansible/config files | Terraform/CloudFormation | Terraform |
| DoH/DoT | DoH server (2025 preview) | DoT server (9.18+) | N/A (resolver only) | 1.1.1.1 (DoH/DoT/DoQ) |

## DNS Architecture Patterns

### Internal-Only (On-Premises)

```
AD Domain Controllers (Windows DNS)
  └── AD-integrated zones for internal domains
  └── Conditional forwarders for partner/cloud domains
  └── Global forwarders for internet resolution
```

### Split-Horizon (Internal + External)

```
Internal DNS (Windows DNS or BIND internal view)
  └── Internal records (private IPs, AD zones)
External DNS (Cloudflare, Route 53, or BIND external view)
  └── Public records (web servers, MX, SPF)
```

### Hybrid Cloud

```
On-Premises DNS (Windows DNS / BIND)
  └── Forward Azure private zones to Azure DNS Resolver
  └── Forward AWS private zones via Route 53 Resolver inbound endpoints
  └── Conditional forwarders for cloud-hosted services

AWS Route 53 Resolver
  └── Outbound endpoints forward corp.example.com to on-prem DNS
  └── Private hosted zones for VPC resources
```

### Multi-Provider (Resilience)

```
Primary: Cloudflare DNS (anycast authoritative)
Secondary: Route 53 (secondary via zone transfer)
  └── Both sets of NS records at registrar
  └── Zone served even if one provider has outage
```

## DNS Security Layers

| Layer | Technology | Platform |
|---|---|---|
| Cache poisoning protection | DNSSEC validation | All platforms |
| Zone data integrity | DNSSEC signing | All platforms |
| Malware domain blocking | RPZ / DNS Firewall | BIND (RPZ), Route 53 (DNS Firewall), Windows (Policies) |
| Data exfiltration prevention | DNS Firewall / RPZ | Route 53 DNS Firewall, BIND RPZ |
| Encrypted transport | DoH / DoT / DoQ | BIND (DoT), Windows 2025 (DoH preview), Cloudflare 1.1.1.1 |
| Zone transfer security | TSIG / ACLs | BIND, Cloudflare Secondary DNS |

## Technology Routing

| Request Pattern | Route To |
|---|---|
| Windows DNS, AD-integrated zones, DNS policies, PowerShell DNS | `windows-dns/SKILL.md` |
| Windows DNS 2022 specifics | `windows-dns/2022/SKILL.md` |
| Windows DNS 2025 specifics (DoH) | `windows-dns/2025/SKILL.md` |
| BIND, named.conf, zone files, RPZ, KASP, views | `bind/SKILL.md` |
| BIND 9.18 ESV specifics | `bind/9.18/SKILL.md` |
| BIND 9.20 specifics (QP-trie, templates) | `bind/9.20/SKILL.md` |
| AWS Route 53, hosted zones, routing policies, health checks, DNS Firewall | `route53/SKILL.md` |
| Cloudflare DNS, proxy mode, Foundation DNS, 1.1.1.1, secondary DNS | `cloudflare-dns/SKILL.md` |

## Common Pitfalls

1. **Open recursive resolver** -- Never expose a recursive resolver to the internet without access controls. It will be abused for DNS amplification attacks.
2. **DNSSEC without monitoring** -- DNSSEC key rollover failures cause total zone unavailability. Monitor KSK/ZSK expiry and DS record synchronization.
3. **Low TTL without reason** -- Low TTLs increase query load on authoritative servers. Use low TTLs only when frequent changes are expected (pre-migration).
4. **Split-horizon inconsistency** -- Internal and external views must return consistent records for services accessed from both sides. Mismatches cause intermittent failures.
5. **Stale DNS records** -- Enable aging/scavenging (Windows) or manage zone files (BIND) to prevent stale records from causing connectivity issues.
6. **Single DNS server** -- Always deploy at least 2 DNS servers per zone for redundancy. Single-server DNS is a critical single point of failure.

## Reference Files

- `references/concepts.md` -- DNS resolution flow, record types, zone transfers (AXFR/IXFR), DNSSEC chain of trust, DoH/DoT, caching/TTL, split-horizon, DNS security patterns (RPZ, sinkholing, DNS firewall)
