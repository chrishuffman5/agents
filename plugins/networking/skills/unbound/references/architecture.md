# Unbound Architecture Reference

## Recursive Resolution Architecture

```
┌─────────────────────────────────────────────┐
│                 Client Query                │
├─────────────────────────────────────────────┤
│  Worker Thread (num-threads)                │
│  ┌─────────────────────────────────────┐    │
│  │  Module Pipeline                    │    │
│  │  ┌──────────┐  ┌──────────┐        │    │
│  │  │validator │──►│iterator  │        │    │
│  │  │(DNSSEC)  │  │(recursion)│       │    │
│  │  └──────────┘  └──────────┘        │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌──────────┐ ┌────────┐ ┌──────────┐      │
│  │msg cache │ │rrset   │ │infra     │      │
│  │(answers) │ │cache   │ │cache     │      │
│  │          │ │(records)│ │(server   │      │
│  │          │ │         │ │ perf)    │      │
│  └──────────┘ └────────┘ └──────────┘      │
└─────────────────────────────────────────────┘
```

### Threading Model

- **Worker threads**: handle queries in parallel; each has independent iterator state
- **Shared caches**: msg-cache, rrset-cache, infra-cache, key-cache shared across threads
- **Slabs**: cache partitions (power of 2 near num-threads) reduce lock contention
- **so-reuseport**: distributes incoming sockets across threads for even load

### Cache Hierarchy

| Cache | Contents | Sizing |
|---|---|---|
| msg-cache | Complete DNS responses keyed by question | `msg-cache-size` |
| rrset-cache | Individual RRsets (A, AAAA, CNAME, etc.) | `rrset-cache-size` (2x msg) |
| infra-cache | Per-server RTT, lame detection, EDNS | `infra-cache-numhosts` |
| key-cache | DNSSEC DNSKEY RRsets for validated zones | `key-cache-size` |

### Iterator State Machine

The iterator performs recursive resolution:
1. Query root servers for TLD NS
2. Query TLD servers for domain NS
3. Query authoritative server for final answer
4. Cache all intermediate results (NS, glue records)
5. Handle CNAME chains, DNAME redirects, and referrals

Optimizations:
- **Prefetch**: re-resolves popular entries before TTL expiry (`prefetch: yes`)
- **Qname minimisation**: sends minimal labels to each server (RFC 7816)
- **Aggressive NSEC**: uses cached NSEC records to answer negative queries without upstream query

## Module Pipeline

### Default Pipeline

`module-config: "validator iterator"` -- DNSSEC validation + recursive resolution.

### Extended Pipelines

```ini
# With external Redis cache
module-config: "validator cachedb iterator"

# With Python scripting
module-config: "validator python iterator"

# With response IP policy
module-config: "respip validator iterator"
```

### validator Module

- Verifies DNSSEC signatures (RRSIG) against DNSKEY records
- Builds chain of trust from root KSK to target zone
- Trust anchor: root zone KSK managed via RFC 5011 automatic updates
- Results: SECURE (valid chain), INSECURE (no DNSSEC for zone), BOGUS (validation failed), INDETERMINATE

### iterator Module

- Implements recursive resolution state machine
- Maintains infra-cache for server selection (lowest RTT, lame detection)
- Handles CNAME/DNAME resolution chains
- Supports stub zones and forward zones for partial recursion

### cachedb Module

External cache backend for cache sharing across Unbound instances:
```ini
cachedb:
    backend: "redis"
    redis-server-host: 127.0.0.1
    redis-server-port: 6379
    redis-timeout: 100
```

Use case: multiple Unbound instances behind a load balancer sharing a single Redis cache for consistent cache hits.

### python Module

Custom query/response manipulation in Python:
```python
def init(id, cfg):
    return True

def deinit(id):
    return True

def inform_super(id, qstate, superqstate, qdata):
    return True

def operate(id, event, qstate, qdata):
    if event == MODULE_EVENT_NEW:
        qstate.ext_state[id] = MODULE_WAIT_MODULE
        return True
    if event == MODULE_EVENT_MODDONE:
        # Modify response here
        qstate.ext_state[id] = MODULE_FINISHED
        return True
    return True
```

### respip Module

Response IP policy for filtering based on answer content:
- Block responses containing specific IP ranges
- Redirect responses to different IPs
- Apply EDNS Client Subnet policies
- Use case: block responses pointing to known-malicious IPs

## DNSSEC Implementation

### Trust Anchor Management

```ini
auto-trust-anchor-file: "/var/lib/unbound/root.key"
```

- Initial trust anchor: IANA root zone KSK (RFC 7958)
- Auto-update via RFC 5011 (DNS trust anchor sentinel)
- `unbound-anchor` utility: bootstrap trust anchor download
- Key rollover: tracked via hold-down timer (30 days per RFC 5011)

### Validation Process

1. Receive answer from authoritative server
2. Retrieve DNSKEY for the zone (if not cached)
3. Verify RRSIG signature covers the answer RRset
4. Walk the chain of trust: root DS -> root DNSKEY -> TLD DS -> TLD DNSKEY -> zone DS -> zone DNSKEY
5. Mark result: SECURE, INSECURE, BOGUS, or INDETERMINATE

### Negative Trust Anchors

Override DNSSEC validation for specific domains:
```ini
domain-insecure: "broken-dnssec.example.com"
```

Use case: known domains with broken DNSSEC that must still resolve.

## Encrypted DNS

### DNS over TLS (DoT) -- Upstream

```ini
forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 9.9.9.9@853#dns.quad9.net
```

- `@853`: TLS port
- `#hostname`: TLS SNI and certificate verification hostname
- Encrypts queries between Unbound and upstream resolver
- Does NOT encrypt client -> Unbound path (use DoH server for that)

### DNS over HTTPS (DoH) -- Incoming Server

```ini
server:
    interface: 0.0.0.0@443
    https-port: 443
    tls-service-key: "/etc/unbound/server.key"
    tls-service-pem: "/etc/unbound/server.pem"
    http-endpoint: "/dns-query"
    http-notls-downstream: no              # require TLS (default)
```

Available since Unbound 1.17. Provides encrypted DNS for clients. Combine with DoT upstream for full encrypted path.

### DNS over TLS (DoT) -- Incoming Server

```ini
server:
    interface: 0.0.0.0@853
    tls-port: 853
    tls-service-key: "/etc/unbound/server.key"
    tls-service-pem: "/etc/unbound/server.pem"
```

## Deployment Patterns

### Standalone Recursive Resolver

Full recursion from root servers. No forwarding. Best for: DNSSEC validation, privacy (no third-party upstream dependency).

### Forwarder to Trusted Upstream

Forward all queries to trusted upstream (ISP, Cloudflare, Google, Quad9) via DoT. Best for: simple deployments, DoT encryption, organizations that trust upstream provider.

### Pi-hole + Unbound Stack

Pi-hole (port 53) -> Unbound (port 5335, full recursion). Pi-hole handles ad/tracker blocking. Unbound handles DNSSEC and recursive resolution. No external forwarding needed.

### OPNsense / pfSense Appliance

Unbound as system resolver with GUI management. DHCP lease registration. Local overrides via GUI. DoT upstream via GUI configuration. DNSBL plugin for DNS-based blocking.

### Clustered with Redis Cache

Multiple Unbound instances behind load balancer sharing Redis cache via cachedb module. Best for: ISP-scale, high availability, consistent cache performance.

## Performance Tuning Reference

### Key Parameters

| Parameter | Default | Description |
|---|---|---|
| `num-threads` | 1 | Worker threads (set to CPU count) |
| `msg-cache-size` | 4m | Message cache size |
| `rrset-cache-size` | 4m | RRset cache size (set to 2x msg) |
| `outgoing-range` | 4096 | Max concurrent outgoing queries |
| `num-queries-per-thread` | 1024 | Max queries per thread |
| `so-reuseport` | no | Distribute sockets across threads |
| `prefetch` | no | Refresh popular entries before expiry |
| `serve-expired` | no | Return stale records on upstream failure |
| `cache-min-ttl` | 0 | Minimum TTL floor for cached records |
| `cache-max-ttl` | 86400 | Maximum TTL cap for cached records |
| `aggressive-nsec` | yes | Use NSEC for synthesized negative answers |

### Monitoring

- `unbound-control stats_noreset` -- query statistics without clearing counters
- `unbound-control dump_cache` -- dump cache contents
- `unbound-control lookup <name>` -- lookup specific name in cache
- `unbound-control list_forwards` -- list configured forward zones
- `unbound-control list_stubs` -- list configured stub zones
