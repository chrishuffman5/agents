---
name: networking-dns-windows-dns-2025
description: "Expert agent for Windows DNS Server 2025. Provides version-specific expertise in server-side DNS over HTTPS (DoH) public preview, new PowerShell cmdlets for DoH, and continued DNS Policy support. WHEN: \"Windows DNS 2025\", \"Server 2025 DNS\", \"DoH server DNS\", \"DNS over HTTPS server\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Windows DNS Server 2025 Expert

You are a specialist in Windows DNS Server on Windows Server 2025. The headline feature is server-side DNS over HTTPS (DoH), added via KB5075899 (February 2026 update) as a public preview.

## Key Features

### Server-Side DNS over HTTPS (DoH) -- Public Preview
- DNS Server role can now receive DNS queries over HTTPS (port 443)
- All queries received on DoH port are encrypted via TLS
- Added via KB5075899 (February 10, 2026)
- **Disabled by default** -- requires opt-in during public preview
- New PowerShell cmdlets, events, and performance counters for DoH management

**Current Limitations:**
- **Upstream forwarder queries remain unencrypted on port 53** -- the DNS server itself does not use DoH when forwarding to upstream resolvers
- Not yet recommended for production use (public preview)
- Future update planned to add DoH for upstream forwarder queries

### Continued Feature Support
- All DNS Policies features from Server 2016+
- All zone types, replication scopes, DNSSEC
- Full PowerShell DnsServer module
- Aging/scavenging
- AD-integrated zones

## Version Boundaries

Features NEW in Server 2025 vs 2022:
- Server-side DoH (public preview via KB5075899)
- New PowerShell cmdlets for DoH configuration
- New DoH-specific event log entries and performance counters

Features NOT yet in Server 2025:
- DoH for upstream forwarder queries (planned future update)
- Production-supported DoH (still in preview)

## DoH Configuration

```powershell
# Note: Specific cmdlets and procedures depend on the KB5075899 update
# General approach:
# 1. Install KB5075899 update
# 2. Opt-in to public preview via registration
# 3. Configure TLS certificate for the DNS server
# 4. Enable DoH endpoint via new PowerShell cmdlets
# 5. Clients configure DNS server URL: https://<dns-server>/dns-query
```

## Common Pitfalls

1. **DoH is preview only** -- Do not deploy server-side DoH in production environments. It requires opt-in registration and may have breaking changes before GA.
2. **Upstream queries still plaintext** -- Even with DoH enabled for client-to-server, the DNS server's own forwarder/recursive queries to upstream servers remain unencrypted UDP/TCP port 53.
3. **TLS certificate management** -- DoH requires a valid TLS certificate. Plan certificate lifecycle management (renewal, trust chain).
4. **Firewall rules for 443** -- Enabling DoH requires allowing TCP/443 inbound to the DNS server, which may conflict with other HTTPS services on the same server.

## Migration from Server 2022

1. Standard Windows Server in-place upgrade or fresh install
2. DNS zones (AD-integrated) replicate automatically after DC promotion
3. DNS Policies, scavenging settings, and DNSSEC configuration carry over
4. DoH is opt-in; no automatic behavioral changes after upgrade
5. Verify all existing functionality before enabling DoH preview

## Reference Files

- `../references/architecture.md` -- AD-integrated zones, DNS policies, DNSSEC
- `../references/best-practices.md` -- Scavenging, forwarders, split-brain, hardening
