# DNS Deep Dive: PowerDNS, Unbound, CoreDNS, and Azure DNS

## Overview

This document covers four DNS platforms that complement enterprise DNS infrastructure: PowerDNS (authoritative + recursive + load balancer), Unbound (recursive resolver), CoreDNS (cloud-native / Kubernetes), and Azure DNS (cloud-native managed service). Together these tools cover authoritative serving, recursive resolution, DoT/DoH encryption, Kubernetes service discovery, and hybrid cloud DNS.

---

## PowerDNS

PowerDNS is a suite of open-source DNS tools developed by PowerDNS.COM B.V. The suite consists of three distinct products with separate roles: Authoritative Server, Recursor, and DNSdist.

### Authoritative Server 5.0

Released August 2025, PowerDNS Authoritative Server 5.0 is a major version with significant new features.

#### Architecture

The Authoritative Server answers queries for zones it is authoritative for. It does not perform recursive lookups. Key architectural components:
- **Backends**: pluggable database backends store zone data
- **Receivers/distributors**: packet I/O threads that handle query distribution
- **Cache**: packet cache (per-answer) and query cache for performance

**Supported Backends:**
- **gmysql**: MySQL/MariaDB — most commonly used
- **gpgsql**: PostgreSQL
- **gsqlite3**: SQLite3 — for small/dev deployments
- **gldap**: LDAP directory — for ISP/hosting environments with directory-backed zones
- **bind**: RFC-compliant zone files (legacy compatibility)
- **pipe**: pipes queries to an external process; custom backends
- **remote**: JSON/REST/Unix socket backend for custom resolver integration

#### DNSSEC

Built-in DNSSEC with automated key management:
- **Auto-signing**: enable per-zone with `pdnsutil secure-zone example.com`
- **Key rollovers**: automated ZSK rollover; manual KSK rollover with DS publication
- **Supported algorithms**: ED25519, ED448, ECDSA P-256, ECDSA P-384, RSA
- **NSEC3**: opt-in support for zone enumeration defense
- Online signing: key material stored in database alongside zone data

```bash
# Secure a zone
pdnsutil secure-zone example.com
pdnsutil set-nsec3 example.com
pdnsutil show-zone example.com  # view DNSKEY records and DS hashes
```

#### REST API

Full CRUD API for zone and record management:
```bash
# Create a zone
curl -X POST http://localhost:8081/api/v1/servers/localhost/zones \
  -H "X-API-Key: secret" \
  -H "Content-Type: application/json" \
  -d '{"name":"example.com.","kind":"Native","nameservers":["ns1.example.com."]}'

# Add a record
curl -X PATCH http://localhost:8081/api/v1/servers/localhost/zones/example.com. \
  -H "X-API-Key: secret" \
  -H "Content-Type: application/json" \
  -d '{"rrsets":[{"name":"www.example.com.","type":"A","ttl":300,
       "changetype":"REPLACE","records":[{"content":"10.1.1.1","disabled":false}]}]}'
```

#### Lua Scripting

Lua scripting allows dynamic query/response handling via hooks: preresolve (intercept before backend), postresolve (modify before response), preaxfr, nodata, nxdomain, and more. Lua can be used to implement geo-based responses, A/B testing, or real-time block lists without a full backend rewrite.

#### Views (5.0 New Feature)

Views allow different responses based on client source:
```yaml
views:
  internal:
    networks: [10.0.0.0/8, 192.168.0.0/16]
    zones:
      - name: example.com
        backend: gmysql
        database: internal_db
  external:
    networks: [0.0.0.0/0]
    zones:
      - name: example.com
        backend: gmysql
        database: external_db
```
Use case: Split-horizon DNS — internal clients see internal IPs; external clients see public IPs.

---

### PowerDNS Recursor 5.4

The Recursor is a high-performance recursive resolver. As of Recursor 5.2+, YAML is the recommended configuration format.

#### YAML Configuration

```yaml
dnssec:
  validate: validate   # validate | log-fail | off

incoming:
  listen: ["0.0.0.0:53", "[::]:53"]
  allow_from: ["127.0.0.0/8", "192.168.0.0/16"]

forwarding:
  zones:
    - zone: internal.corp
      recurse: false
      forwarders: ["10.0.0.53"]

logging:
  loglevel: 4

rpz:
  - name: security-policy
    url: https://rpz.example.com/feed.zone
    defpol: Policy.Drop
    refresh: 300
```

#### DNSSEC Validation

The Recursor performs full DNSSEC validation:
- **Modes**: `off` (no validation), `process` (log failures), `log-fail` (log and continue), `validate` (strict — BOGUS = SERVFAIL)
- Trust anchors built-in (root zone KSK); updates via IANA root key sentinel
- Reports per-query DNSSEC status in logs and Lua hooks

#### RPZ (Response Policy Zones)

RPZ enables DNS-based threat blocking:
- Supports RPZ feeds from threat intelligence providers (Spamhaus, SURBL, etc.)
- Actions: NXDOMAIN, DROP, PASSTHRU, NODATA, REDIRECT to walled garden
- Multiple RPZ feeds can be loaded simultaneously with priority ordering
- `includeSoA` option available for RPZ zone SOA propagation in responses (5.4 feature)

#### Serve-Stale / Serve-Expired

When upstream resolvers are unreachable:
- `serve-expired`: return expired cache entries rather than SERVFAIL
- Configurable max-stale age for serving expired records
- Useful for DNS resilience during upstream outages

---

### DNSdist 2.0

DNSdist is a DNS load balancer, firewall, and protocol frontend. Version 2.0 (2025) introduced YAML as a full configuration alternative to Lua.

#### Architecture

DNSdist sits in front of DNS servers (PowerDNS, BIND, Unbound) and provides:
- Load balancing across multiple backend resolvers
- DoH (DNS over HTTPS) and DoT (DNS over TLS) frontend termination
- Rate limiting and DDoS protection
- Query routing rules
- Metrics and monitoring

#### YAML Configuration (2.0)

```yaml
listen_addresses:
  - "0.0.0.0:53"
  - "0.0.0.0:853"   # DoT
  - "0.0.0.0:443"   # DoH

backends:
  - address: "192.168.1.10:53"
    name: "recursor1"
  - address: "192.168.1.11:53"
    name: "recursor2"

policy: "leastOutstanding"

tls:
  certificates:
    - cert: "/etc/ssl/dns.pem"
      key: "/etc/ssl/dns.key"

doh:
  paths: ["/dns-query"]
  http_version: "h2"
```

#### Rules Engine

```lua
-- Rate limit per client IP
addAction(MaxQPSIPRule(100), DropAction())

-- Block specific query types
addAction(QTypeRule(dnsdist.ANY), RCodeAction(dnsdist.REFUSED))

-- Route internal queries to internal resolver
addAction(SuffixMatchNodeRule(newSuffixMatchNode({"internal.corp."})), PoolAction("internal"))
```

#### DNSdist Defender

Security extension for advanced threat mitigation:
- DNS tunneling detection and blocking
- Pseudo-random subdomain (PRSD) attack mitigation
- DNS amplification / reflection prevention
- Exportable threat intelligence in CEF/syslog format

---

## Unbound 1.24

Unbound is an open-source recursive resolver developed by NLnet Labs. It is the default resolver in pfSense, OPNsense, and a recommended upstream for Pi-hole.

### Architecture

Unbound uses a multi-threaded architecture:
- Multiple worker threads handle queries in parallel
- Shared cache (or per-thread caches with optional sync)
- Each thread maintains its own iterator state machine for recursive lookups
- Infra cache: tracks per-server performance (RTT, lame servers)
- Key cache: DNSSEC key material cache

### Core Configuration

Key `unbound.conf` settings:
- `num-threads`: match CPU core count for optimal throughput
- `access-control`: restrict which clients can query (CIDR allow/deny)
- `hide-identity` / `hide-version`: privacy hardening
- `root-hints`: path to IANA root hints file
- `auto-trust-anchor-file`: DNSSEC root trust anchor (auto-updated via RFC 5011)
- `msg-cache-size` / `rrset-cache-size`: tune for workload (e.g., 128m / 256m)
- `prefetch: yes`: proactively refresh popular cache entries before TTL expiry
- `prefetch-key: yes`: prefetch DNSKEY records for DNSSEC performance
- `serve-expired: yes` + `serve-expired-ttl: 86400`: return stale records during upstream outages
- `qname-minimisation: yes`: send minimal query labels to authoritative servers (RFC 7816)

### DoT (DNS over TLS) Upstream

```ini
forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 8.8.8.8@853#dns.google
```

### DoH Server (incoming)

Unbound 1.17+ supports incoming DoH: set `interface: 0.0.0.0@443`, `https-port: 443`, `tls-service-key`/`pem`, and `http-endpoint: "/dns-query"`. Combine with DoT upstream (`forward-tls-upstream: yes`) for full encrypted DNS path.

### Local Zones and Overrides

Use `local-zone` and `local-data` for split-horizon, internal hostname resolution, and ad/tracking blocking. Forward internal domains via `forward-zone` blocks pointing to internal resolvers. Combine with `local-zone: "domain.com" refuse` for blocklists without requiring Pi-hole.

### Module Architecture

Unbound uses a modular pipeline — each query passes through a chain of modules:
1. **validator**: DNSSEC validation
2. **iterator**: recursive resolution logic
3. **respip**: response IP policy (EDNS client subnet manipulation, policy filtering)
4. **cachedb**: external cache database (Redis) for shared cache across Unbound instances
5. **python**: Python module for custom query/response manipulation
6. **dynlib**: C dynamic library module for high-performance custom logic

### pfSense and OPNsense Integration

- OPNsense has used Unbound as the default DNS resolver since version 17.7
- GUI-based configuration for most settings; advanced settings via custom configuration tabs
- **DNSBL integration**: OPNsense supports DNSBL (block lists) via Unbound with automatic updating
- **Pi-hole as upstream**: configure Pi-hole to use Unbound as its upstream resolver for full DNSSEC validation while maintaining Pi-hole's ad-blocking lists
- DoT configuration for encrypted upstream supported natively in OPNsense GUI

---

## CoreDNS 1.13

CoreDNS is a cloud-native DNS server written in Go, serving as the default DNS service for Kubernetes (since 1.13).

### Architecture

CoreDNS uses a plugin-chain architecture:
- **Corefile**: configuration file; each `server block` binds to an address:port and chains plugins
- **Plugins**: independent Go packages that implement DNS functionality; chained in order
- **Plugin chain**: each query traverses the plugin chain; first plugin to handle the query responds

### Corefile Structure

```
# Default Kubernetes Corefile
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}
```

### Core Plugins

Key built-in plugins: `kubernetes` (cluster.local service/pod resolution), `forward` (upstream forwarding), `cache` (TTL-based response caching), `loop` (loop detection), `loadbalance` (round-robin A/AAAA), `health`/`ready` (probe endpoints), `prometheus` (metrics on :9153), `errors`/`log` (observability), `rewrite` (name/type rewriting), `hosts` (local zone from hosts file), `dnssec` (inline signing), `transfer` (AXFR support), `etcd` (SkyDNS v1 compatibility), `grpc` (gRPC DNS backend).

### Kubernetes Integration

CoreDNS resolves Kubernetes DNS records per the Kubernetes DNS specification:
- `<service>.<namespace>.svc.cluster.local` → ClusterIP
- `<pod-ip-dashes>.<namespace>.pod.cluster.local` → pod IP (if `pods insecure` or `pods verified`)
- `_<port>._<proto>.<service>.<namespace>.svc.cluster.local` → SRV records for named ports
- Headless services resolve to all pod IPs (multiple A records)
- ExternalName services return CNAME

**Customization via ConfigMap:** Edit the `coredns` ConfigMap in the `kube-system` namespace to add conditional forwarding (e.g., `forward corp.internal 10.0.0.10`) or custom zone overrides. The `reload` plugin watches for ConfigMap changes and hot-reloads without restart.

### NodeLocal DNSCache

NodeLocal DNSCache improves DNS performance in large Kubernetes clusters:
- Runs CoreDNS as a DaemonSet on every node
- Each node has a local cache; pods query the local cache (link-local IP 169.254.20.10)
- Eliminates iptables DNAT and conntrack for DNS queries (a common scalability bottleneck)
- Cache misses forwarded to kube-dns ClusterIP
- Reduces p99 latency for DNS-heavy workloads (microservices, service meshes)

### CoreDNS 1.13 Features

- **DoH3 (DNS over HTTP/3)**: initial experimental support for DoH over QUIC/HTTP3 transport
- **Regex length limit**: security hardening — limits regex pattern length in `rewrite` plugin to prevent resource exhaustion
- **QUIC listener initialization**: safer initialization to prevent race conditions
- **Kubernetes API rate limiting**: improved rate limiting with enhanced metrics tracking plugin chain processing
- **Reduced SOA warnings**: reduced misleading SOA-related warning log entries
- **Data race fix in `uniq` plugin**: stability improvement for response deduplication

### Custom Go Plugins

CoreDNS is extensible via custom Go plugins compiled into the CoreDNS binary at build time. Implement the `plugin.Handler` interface with a `ServeDNS(ctx, w, r)` method, chain to `plugin.NextOrFailure()` for pass-through, and register via `plugin.Register()`. Custom plugins are distributed as Go modules and compiled using the CoreDNS `go build` system with a custom `plugin.cfg` file.

---

## Azure DNS

### Public Zones

Azure DNS hosts public authoritative DNS zones:
- Zones hosted on Azure's anycast name server infrastructure (four NS records per zone: ns1-0x.azure-dns.com through ns4-0x.azure-dns.net)
- Globally distributed — low-latency responses worldwide
- Supports: A, AAAA, CNAME, MX, NS, PTR, SOA, SRV, TXT, CAA record types
- **No FQDN required**: zones can be delegated from any domain registrar

Managed via Azure Portal, Azure CLI (`az network dns`), Terraform (`azurerm_dns_zone`), or ARM/Bicep templates. DNS queries to Azure DNS use anycast infrastructure — no server to manage.

### DNSSEC (Public Zones)

Azure DNS supports DNSSEC on public zones (DNSSEC for private zones is not supported):
- Sign zone via Portal or CLI: `az network dns dnssec-config create -g MyRG -z example.com`
- DS records must be published at the parent registrar
- Supported algorithms: ECDSAP256SHA256, ECDSAP384SHA384, ED25519
- Azure manages key rollovers automatically

### Alias Records

Alias records are Azure-specific DNS records that point to Azure resources:
- **Supported targets**: Azure Public IP, Azure Traffic Manager profile, Azure CDN, Azure Front Door
- Unlike CNAME, alias records can coexist at the zone apex (replace the CNAME restriction at root)
- Auto-updating: if the target resource's IP changes, the alias record updates automatically — no manual DNS update needed
- Supported record types for alias: A, AAAA, CNAME

### Private Zones

Azure Private DNS provides DNS resolution within VNets:
- Not publicly resolvable — only accessible from linked VNets
- **VNet links**: link a private zone to a VNet (with optional auto-registration for VMs)
- Auto-registration: VMs in the linked VNet get DNS records (VM-name.zone) created automatically
- Supports same record types as public zones (no DNSSEC for private zones)
- Use case: resolving private endpoints, internal service names

### Azure DNS Private Resolver

Azure DNS Private Resolver is a fully managed, highly available DNS proxy that enables hybrid DNS resolution:

**Architecture:**
- Deployed inside a VNet
- Requires dedicated subnets for inbound and outbound endpoints

**Inbound Endpoint:**
- Assigns a private IP within your VNet
- On-premises DNS servers forward queries to this IP
- The inbound endpoint resolves using Azure Private DNS zones linked to the VNet
- Use case: on-premises → Azure private zone resolution (e.g., resolving Azure SQL private endpoints from on-prem)

**Outbound Endpoint:**
- Used for conditional forwarding from Azure to external/on-premises DNS
- Associated with a DNS Forwarding Ruleset
- Use case: Azure VMs → on-premises corporate domain resolution

**DNS Forwarding Ruleset:**
- Up to 1,000 forwarding rules per ruleset
- Each rule: `domain → forwarder IP(s)`
- Ruleset linked to VNets and/or outbound endpoints
- Example rule: `corp.internal. → 10.0.0.10, 10.0.0.11` (on-premises DNS)

**Hybrid DNS flow (on-prem → Azure):** On-prem DNS conditionally forwards `*.privatelink.database.windows.net` to the Inbound Endpoint IP → resolved via linked Private DNS zone → returns private endpoint IP. **Hybrid DNS flow (Azure → on-prem):** Azure VMs resolve via 168.63.129.16 → Outbound Endpoint ruleset matches `corp.internal` → forwarded to on-premises DNS server.

### Traffic Manager

Azure Traffic Manager is a DNS-based load balancer / traffic routing service:
- **Routing methods**: Priority, Weighted, Performance (closest endpoint), Geographic, Subnet, Multivalue
- Works by returning different CNAME/A records based on routing policy and endpoint health
- Health probes: HTTP/HTTPS/TCP checks per endpoint
- Nesting: Traffic Manager profiles can be nested for complex routing

### Azure Firewall DNS Proxy

Azure Firewall can act as a DNS proxy for VNet resources:
- Configure VNet DNS servers to point to Azure Firewall private IP
- Azure Firewall forwards queries to custom DNS servers or Azure DNS
- Enables DNS logging through Azure Firewall (see which FQDNs are being resolved)
- Required for FQDN-based network rules and application rules in Azure Firewall
- DNS proxy mode: Azure Firewall → custom DNS → Azure DNS (chain)

---

## Summary: DNS Platform Selection Guide

| Use Case | Recommended Platform |
|----------|---------------------|
| Authoritative DNS with database backend | PowerDNS Authoritative |
| High-performance recursive resolution + DNSSEC | Unbound |
| DNS load balancer + DoH/DoT frontend | DNSdist |
| Kubernetes service discovery | CoreDNS |
| Cloud-hosted authoritative DNS | Azure DNS (public zones) |
| Private endpoint resolution in Azure | Azure DNS Private Zones |
| Hybrid on-prem ↔ Azure DNS | Azure DNS Private Resolver |
| DNS-based threat blocking | PowerDNS Recursor + RPZ |
| Home/edge security + ad-blocking | Pi-hole + Unbound + DoT |
