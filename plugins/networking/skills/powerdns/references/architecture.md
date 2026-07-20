# PowerDNS Architecture Reference

## Suite Overview

PowerDNS consists of three separate products with distinct roles:

```
                                    ┌──────────────────────┐
                                    │   PowerDNS Auth 5.0  │
                                    │   (Authoritative)    │
                     ┌──────────►   │   gmysql/gpgsql/...  │
                     │              └──────────────────────┘
┌────────────────┐   │
│  DNSdist 2.0   │───┤
│  (Frontend)    │   │              ┌──────────────────────┐
│  DoH/DoT/LB   │   └──────────►   │  PowerDNS Recursor   │
└────────────────┘                  │  5.4 (Recursive)     │
                                    │  DNSSEC/RPZ/Lua      │
                                    └──────────────────────┘
```

- **Auth**: answers queries for hosted zones; never recurses
- **Recursor**: performs recursive resolution; never hosts zones
- **DNSdist**: frontend load balancer, protocol terminator, firewall

## Authoritative Server 5.0

### Backend Architecture

```
Query ──► Receiver/Distributor threads ──► Backend lookup ──► Cache ──► Response
                                              │
                     ┌────────────────────────┤
                     │                        │
                 ┌───┴───┐              ┌─────┴─────┐
                 │ gmysql│              │  gpgsql   │
                 │ MariaDB│             │ PostgreSQL│
                 └───────┘              └───────────┘
```

- **Receivers**: packet I/O threads handling query distribution
- **Distributors**: distribute queries to backend worker threads
- **Packet cache**: per-answer cache keyed on question section
- **Query cache**: backend query result cache

### Backend Details

**gmysql (MySQL/MariaDB)**:
- Most commonly used production backend
- Schema: `domains`, `records`, `domainmetadata`, `cryptokeys` tables
- Connection pooling via `gmysql-max-connections`
- Replication-aware: read from replica, write to primary

**gpgsql (PostgreSQL)**:
- Same schema concept as gmysql with PostgreSQL syntax
- Supports listen/notify for instant zone change propagation between PowerDNS instances

**gsqlite3 (SQLite3)**:
- Single-file database; no daemon required
- Suitable for development, testing, small deployments
- Not recommended for high-query-rate production

**gldap (LDAP)**:
- Maps DNS records to LDAP entries
- ISP/hosting environments with existing LDAP infrastructure

**bind (zone files)**:
- RFC-compliant zone file format
- Legacy compatibility for migration from BIND
- Supports `named.conf`-style zone declarations

**pipe (external process)**:
- Pipes queries to an external process via stdin/stdout
- Protocol: tab-separated question/answer pairs
- Use case: custom resolution logic in any language

**remote (JSON/REST/Unix socket)**:
- Sends queries to external HTTP/Unix socket service as JSON
- Use case: integration with external databases, APIs, or custom resolvers

### DNSSEC Implementation

- **Online signing**: zone data stored unsigned; signing happens at query time
- **Key storage**: key material stored in database (`cryptokeys` table)
- **pdnsutil** commands for key management:
  ```bash
  pdnsutil secure-zone example.com          # generate keys, enable signing
  pdnsutil set-nsec3 example.com            # switch to NSEC3
  pdnsutil unset-nsec3 example.com          # revert to NSEC
  pdnsutil show-zone example.com            # display DS records for parent
  pdnsutil add-zone-key example.com ksk 256 active ecdsa256  # add specific key
  pdnsutil remove-zone-key example.com <id> # remove key
  pdnsutil activate-zone-key example.com <id>  # activate key
  pdnsutil deactivate-zone-key example.com <id>  # deactivate key
  ```

- **Algorithm support**: ED25519 (recommended), ED448, ECDSA P-256, ECDSA P-384, RSA (2048+)
- **NSEC3**: opt-in enumeration defense; configurable iterations and salt
- **ZSK rollover**: automated timing
- **KSK rollover**: semi-automatic; admin publishes DS at parent

### REST API

Base URL: `http://<server>:8081/api/v1/servers/localhost/`

| Method | Endpoint | Action |
|---|---|---|
| GET | `/zones` | List all zones |
| POST | `/zones` | Create zone |
| GET | `/zones/{zone}` | Get zone details + records |
| PATCH | `/zones/{zone}` | Add/modify/delete records |
| DELETE | `/zones/{zone}` | Delete zone |
| PUT | `/zones/{zone}/notify` | Send NOTIFY to secondaries |
| PUT | `/zones/{zone}/axfr-retrieve` | Retrieve zone via AXFR |
| GET | `/zones/{zone}/cryptokeys` | List DNSSEC keys |

Authentication: `X-API-Key` header. Enable with `api=yes` and `api-key=<secret>` in `pdns.conf`.

### Lua Scripting Hooks

| Hook | Timing | Use Case |
|---|---|---|
| preresolve | Before backend lookup | Intercept/redirect queries |
| postresolve | After backend, before response | Modify answers |
| preaxfr | Before AXFR transfer | Filter zone transfer content |
| nodata | When backend returns no records | Synthesize responses |
| nxdomain | When zone/name not found | Custom NXDOMAIN handling |

### Views (5.0)

Split-horizon DNS based on client source network:
- Each view defines network CIDR ranges and zone-to-backend mappings
- Views are evaluated in order; first match wins
- Different backends (or different databases within same backend type) per view
- Use case: internal clients see private IPs; external clients see public IPs

## Recursor 5.4

### Architecture

```
Query ──► Receiver threads ──► MTasker (cooperative threads) ──► Iterator
                                        │                            │
                                   ┌────┴────┐                  ┌───┴────┐
                                   │  Cache  │                  │  RPZ   │
                                   │(answers)│                  │ Engine │
                                   └─────────┘                  └────────┘
```

- **MTasker**: cooperative multi-threaded query processing
- **Iterator**: recursive resolution state machine
- **Cache**: response cache with DNSSEC-aware entries
- **RPZ engine**: policy evaluation against loaded RPZ feeds

### YAML Configuration (5.2+ Recommended)

Key sections:
```yaml
incoming:
  listen: ["0.0.0.0:53"]
  allow_from: ["127.0.0.0/8", "10.0.0.0/8"]

outgoing:
  source_address: ["0.0.0.0"]

dnssec:
  validate: validate

forwarding:
  zones:
    - zone: "."
      forwarders: ["8.8.8.8", "1.1.1.1"]
    - zone: internal.corp
      recurse: false
      forwarders: ["10.0.0.53"]

cache:
  max_cache_entries: 1000000
  max_negative_ttl: 3600
  serve_expired: true
  serve_expired_ttl: 86400

rpz:
  - name: threat-feed
    url: https://rpz.provider.com/feed.zone
    defpol: Policy.NXDOMAIN
    refresh: 300

logging:
  loglevel: 4
```

### DNSSEC Validation

- Built-in root zone trust anchors (IANA root KSK)
- Automatic trust anchor updates via RFC 5011 sentinel
- Validation modes: off, process, log-fail, validate
- Per-query DNSSEC status logged and available in Lua hooks
- Negative trust anchors: override validation for specific domains with known DNSSEC issues

### RPZ Implementation

- Multiple RPZ feeds loaded simultaneously with priority ordering
- Feed sources: AXFR/IXFR from primary, HTTP/HTTPS download, local file
- Actions per match: NXDOMAIN, NODATA, DROP, PASSTHRU, CNAME redirect
- Triggers: qname, client-ip, response-ip, nsdname, nsip
- `servfail-until-ready`: block unprotected queries until RPZ zones loaded

### Lua Scripting

```lua
function preresolve(dq)
    if dq.qname:equal(newDN("blocked.example.com")) then
        dq:addAnswer(pdns.A, "0.0.0.0")
        return true
    end
    return false
end
```

Hooks: `preresolve`, `postresolve`, `nxdomain`, `nodata`, `preoutquery`, `ipfilter`.

## DNSdist 2.0

### Load Balancing Policies

| Policy | Description |
|---|---|
| leastOutstanding | Route to backend with fewest pending queries |
| wrandom | Weighted random distribution |
| roundrobin | Sequential rotation |
| firstAvailable | First healthy backend |
| chashed | Consistent hashing (query name based) |

### DoH / DoT / DoQ Frontend

- **DoT (DNS over TLS)**: port 853; standard TLS termination
- **DoH (DNS over HTTPS)**: port 443; HTTP/2 with `/dns-query` endpoint
- **DoQ (DNS over QUIC)**: port 853 (QUIC); 0-RTT for lowest latency (2.0)

### Health Checks

- TCP connect checks to backend port
- DNS query-based checks (send query, expect answer)
- Lazy health checking: only check when backend starts failing
- Auto-recovery when health checks pass again

### Rules Engine Architecture

Rules evaluated in order. First matching rule's action is applied.

Selectors: `QTypeRule`, `QNameRule`, `SuffixMatchNodeRule`, `NetmaskGroupRule`, `MaxQPSIPRule`, `RegexRule`, `TagRule`.

Actions: `PoolAction`, `DropAction`, `RCodeAction`, `SpoofAction`, `DelayAction`, `LogAction`, `TeeAction`.

### DNSdist Defender

- DNS tunneling detection via entropy analysis and query pattern matching
- PRSD (Pseudo-Random Subdomain) attack mitigation
- Amplification prevention: block large responses to spoofed sources
- Integration with external SIEM via CEF/syslog export

### Metrics and Monitoring

- Built-in web dashboard: `webserver("0.0.0.0:8083", "password")`
- Prometheus metrics endpoint
- Carbon/Graphite export
- Per-backend query statistics, latency percentiles, error rates
