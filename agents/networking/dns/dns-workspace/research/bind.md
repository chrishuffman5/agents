# ISC BIND — Deep Dive Research

**Sources:** ISC BIND Documentation (bind9.readthedocs.io), ISC Blog, ISC KB  
**Last updated:** April 2026  
**Applies to:** BIND 9.18 (ESV), BIND 9.20 (current stable), BIND 9.21 (development)

---

## Architecture Overview

ISC BIND (Berkeley Internet Name Domain) is the most widely deployed DNS software on the internet. The core daemon is `named`, configured via `named.conf`. BIND supports authoritative, recursive, and combined (authoritative+recursive) server roles.

### Core Components

| Component | Role |
|---|---|
| `named` | Main DNS daemon (authoritative + resolver) |
| `named.conf` | Primary configuration file |
| `named-checkconf` | Configuration syntax validator |
| `named-checkzone` | Zone file syntax validator |
| `rndc` | Remote Name Daemon Control — runtime management |
| `dnssec-keygen` | Manual DNSSEC key generation |
| `dnssec-signzone` | Manual zone signing |
| `nsupdate` | Dynamic DNS update client (uses DNS UPDATE protocol) |
| `dig` | DNS query tool (widely used for diagnostics) |

### Database Backend (9.20+)

BIND 9.20 replaced the legacy Red-Black-Tree database (RBTDB) with a **QP-trie (Quadratic Patricia Trie)** database by default:
- Authoritative performance improved 4-7% overall
- SIEVE LRU-based cache-expiration mechanism for improved recursive server performance near `max-cache-size`
- RBTDB will be removed entirely in 9.22 (2026 stable release)

---

## named.conf Structure

The configuration file is composed of **statements**, each terminated by a semicolon. Statements may contain nested blocks.

### Top-Level Statements

```
options { ... };        // Global server settings (once only)
logging { ... };        // Log channels and categories (once only)
acl <name> { ... };     // Named address match lists (multiple allowed)
key <name> { ... };     // TSIG key definitions (multiple)
zone <name> { ... };    // Zone definitions (multiple)
view <name> { ... };    // View definitions (multiple)
controls { ... };       // rndc control channel configuration
statistics-channels { ... };  // HTTP stats endpoint
server <ip> { ... };    // Per-server settings
```

### options Block (key settings)

```named
options {
    directory "/var/named";             // Working directory for zone files
    listen-on { any; };                 // IPv4 listen address
    listen-on-v6 { any; };             // IPv6 listen address
    recursion yes;                      // Enable/disable recursive resolution
    allow-recursion { 10.0.0.0/8; };   // Who can use recursion
    allow-query { any; };              // Who can query
    allow-transfer { none; };          // Zone transfer ACL (default deny)
    forwarders { 8.8.8.8; 8.8.4.4; }; // Upstream forwarders
    forward only;                       // "only" = no recursion if forwarder fails
    dnssec-validation auto;            // Enable DNSSEC validation (auto = use trust anchors)
    max-cache-size 256m;               // Cache memory limit
    minimal-responses yes;             // Reduce response size
    rate-limit { responses-per-second 10; }; // RRL
    version "not disclosed";           // Hide version string
};
```

### logging Block

```named
logging {
    channel default_log {
        file "/var/log/named/named.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-severity yes;
        print-category yes;
    };
    channel queries_log {
        file "/var/log/named/queries.log" versions 2 size 10m;
        severity info;
        print-time yes;
    };
    category default { default_log; };
    category queries { queries_log; };
    category resolver { default_log; };
    category security { default_log; };
    category rpz { default_log; };
    category dnssec { default_log; };
};
```

### acl Block

```named
acl "internal" {
    10.0.0.0/8;
    172.16.0.0/12;
    192.168.0.0/16;
    localhost;
    localnets;
};
```

### key Block (TSIG)

```named
key "transfer-key" {
    algorithm hmac-sha256;
    secret "base64-encoded-secret==";
};
```

### zone Block

```named
zone "example.com" IN {
    type primary;
    file "example.com.zone";
    allow-update { key "update-key"; };
    allow-transfer { key "transfer-key"; };
    also-notify { 192.168.1.2; };
    dnssec-policy default;            // Enable KASP (BIND 9.16+)
    inline-signing yes;               // Inline DNSSEC signing (default in 9.20)
    notify yes;
};
```

---

## Zone File Format

Standard RFC 1035 zone file format. Relative names are relative to the zone origin (`$ORIGIN`).

```zone
$ORIGIN example.com.
$TTL 3600

; SOA record — required, defines zone parameters
@   IN  SOA  ns1.example.com. hostmaster.example.com. (
                2024010101  ; Serial (YYYYMMDDnn)
                3600        ; Refresh (1 hour)
                900         ; Retry (15 minutes)
                604800      ; Expire (7 days)
                300 )       ; Minimum/Negative TTL (5 minutes)

; NS records — authoritative nameservers
@   IN  NS   ns1.example.com.
@   IN  NS   ns2.example.com.

; A records
ns1     IN  A    192.0.2.1
ns2     IN  A    192.0.2.2
@       IN  A    192.0.2.10
www     IN  A    192.0.2.10

; AAAA record
www     IN  AAAA 2001:db8::10

; CNAME record (cannot coexist with other records at same name)
ftp     IN  CNAME www.example.com.

; MX records
@   IN  MX  10 mail1.example.com.
@   IN  MX  20 mail2.example.com.

; TXT records
@   IN  TXT "v=spf1 ip4:192.0.2.0/24 -all"
_dmarc  IN  TXT "v=DMARC1; p=reject; rua=mailto:dmarc@example.com"

; SRV records: _service._protocol.name TTL class SRV priority weight port target
_sip._tcp   IN  SRV  10 20 5060 sipserver.example.com.

; PTR record (typically in reverse zone file)
; In 1.0.192.in-addr.arpa zone:
; 10  IN  PTR  www.example.com.
```

### SOA Field Details

| Field | Description | Typical Value |
|---|---|---|
| Serial | Zone version number; increment on every change | YYYYMMDDnn |
| Refresh | How often secondaries check for updates | 3600 (1h) to 86400 (1d) |
| Retry | How often to retry failed refresh | 900 (15m) |
| Expire | How long secondary serves zone without successful refresh | 604800 (7d) |
| Minimum | Used as negative caching TTL (RFC 2308) | 300-3600 |

---

## Views (Split-Horizon DNS)

Views allow a single BIND instance to serve different answers to different clients. Common use: internal clients get private IPs, external clients get public IPs.

```named
view "internal" {
    match-clients { "internal"; };  // ACL defined above
    recursion yes;

    zone "example.com" IN {
        type primary;
        file "internal/example.com.zone";
    };

    // Include forward zones, root hints, etc.
    include "named.internal.conf";
};

view "external" {
    match-clients { any; };
    recursion no;

    zone "example.com" IN {
        type primary;
        file "external/example.com.zone";
    };

    zone "." IN {
        type hint;
        file "named.root";
    };
};
```

**Rules for views:**
- Once any view is defined, ALL zones must be inside a view
- Views are matched in order; first match wins
- `match-clients` uses ACL syntax
- TSIG keys can be used in match-clients for view selection
- Key statements defined inside views are view-scoped (BIND 9.20 fix: key-in-view handling corrected)

---

## TSIG (Transaction Signatures)

TSIG (RFC 2845) provides cryptographic authentication for DNS messages — used for zone transfers, dynamic updates, and rndc control.

### Key Generation

```bash
# Generate TSIG key using dnssec-keygen
dnssec-keygen -a HMAC-SHA256 -b 256 -n HOST transfer-key

# Or use tsig-keygen (simpler, BIND 9.9+)
tsig-keygen -a hmac-sha256 transfer-key
```

### Configuration (Primary)

```named
key "transfer-key" {
    algorithm hmac-sha256;
    secret "generated-base64-secret==";
};

zone "example.com" {
    type primary;
    allow-transfer { key "transfer-key"; };
};
```

### Configuration (Secondary)

```named
key "transfer-key" {
    algorithm hmac-sha256;
    secret "generated-base64-secret==";
};

server 192.0.2.1 {
    keys { "transfer-key"; };
};

zone "example.com" {
    type secondary;
    primaries { 192.0.2.1; };
};
```

### GSS-TSIG (Kerberos)

For Windows AD integration:
```named
tkey-gssapi-keytab "/etc/named.keytab";
```
Simpler and more reliable than using `tkey-gssapi-credential` with environment variables.

### TSIG Security Notes (9.20+)

- BIND 9.20 no longer accepts DNAME records or extraneous NS records in AUTHORITY section unless received via spoofing-resistant transport: TCP, UDP with DNS cookies, TSIG, or SIG(0)
- TSIG counts as spoofing-resistant transport

---

## DNSSEC

### KASP — Key and Signing Policy (Recommended)

KASP (`dnssec-policy`) is the recommended, fully automated method for DNSSEC signing (introduced in BIND 9.16).

**Built-in policies:**
- `default` — single ECDSAP256SHA256 CSK (Combined Signing Key), 1-year lifetime
- `insecure` — removes DNSSEC signing from a previously signed zone

**Zone template (9.20 feature):**
```named
// Define reusable template
template "signed-zone-template" {
    dnssec-policy default;
    inline-signing yes;
    also-notify { 192.168.1.100; };
};

zone "example.com" {
    type primary;
    file "example.com.zone";
    use-template "signed-zone-template";
};
```

**Custom policy:**
```named
dnssec-policy "my-policy" {
    signatures-refresh P5D;           // Re-sign every 5 days
    signatures-validity P14D;         // Signatures valid for 14 days
    signatures-validity-dnskey P14D;

    keys {
        ksk lifetime P1Y algorithm ecdsap256sha256;
        zsk lifetime P90D algorithm ecdsap256sha256;
    };

    nsec3param iterations 0 optout no salt-length 0;  // RFC 9276 recommended
    dnskey-ttl 3600;
    zone-propagation-delay PT5M;
    publish-safety PT1H;
    retire-safety PT1H;

    parent-ds-ttl P1D;
    parent-propagation-delay PT1H;
};
```

**Manual-mode (BIND 9.20 new feature):**
```named
dnssec-policy "manual-rollover" {
    manual-mode yes;     // Pause at each key state transition
    // Use: rndc dnssec -step <zone> to advance
};
```

### Inline Signing

In BIND 9.20, inline signing is **the default** when `dnssec-policy` is specified. The unsigned zone file remains unmodified; a separate signed zone exists in memory/secondary files.

- Unsigned zone: `example.com.zone` (editable by admins)
- Signed zone: `example.com.zone.signed` (generated automatically)

### Key State Files

KASP tracks key state in `.state` files:
```
Kexample.com.+013+12345.key
Kexample.com.+013+12345.private
Kexample.com.+013+12345.state   # KASP state tracking
```

### Algorithm Recommendations

| Algorithm | Code | Recommendation |
|---|---|---|
| ECDSAP256SHA256 | 13 | Recommended (compact, fast) |
| ECDSAP384SHA384 | 14 | High-security environments |
| ED25519 | 15 | Very compact, modern |
| RSASHA256 | 8 | Widely compatible, larger |
| RSASHA1 | 5 | Deprecated — generates warnings in 9.20 |
| RSASHA1-NSEC3SHA1 | 7 | Deprecated — generates warnings in 9.20 |

DS digest type SHA1 also generates deprecation warnings in BIND 9.20.

### Manual Key Management (Legacy)

For environments not using KASP:

```bash
# Generate KSK
dnssec-keygen -a ECDSAP256SHA256 -f KSK -n ZONE example.com

# Generate ZSK
dnssec-keygen -a ECDSAP256SHA256 -n ZONE example.com

# Sign zone file
dnssec-signzone -A -3 $(head -c 1000 /dev/random | sha1sum | cut -b 1-16) \
    -N INCREMENT -o example.com -t example.com.zone

# Output: example.com.zone.signed
```

### DS Record Publication

When signing a new zone or rolling KSK, the DS record must be submitted to the parent zone. Get DS record hash:
```bash
dnssec-dsfromkey Kexample.com.+013+12345.key
```

### Key Rollover Workflow (KASP)

For ZSK: fully automatic (prepublish method).  
For KSK and CSK: semi-automatic — BIND manages timing, but admin must:
1. Watch logs for "KSK rollover waiting for DS update" message
2. Submit new DS record to parent registrar/zone
3. Confirm with: `rndc dnssec -checkds -key <keyid> published example.com`

BIND will then proceed with the rollover automatically.

---

## BIND 9.18 vs 9.20 Differences

### 9.18 (ESV — Extended Support Version)

- DNSSEC validation and inline signing stable
- DoT (DNS over TLS) server-side support introduced
- KASP available but inline-signing not default
- RBTDB still default database
- `auto-dnssec` still available (deprecated but functional)

### 9.20 (Current Stable)

- **QP-trie database** replaces RBTDB as default (RBTDB removed in 9.22)
- **Inline signing is the default** when `dnssec-policy` is configured
- `auto-dnssec`, `trusted-keys`, `managed-keys`, `glue-cache`, `sortlist`, `delegation-only` zone type all **removed**
- DNSRPS (DNS Response Policy Service) removed
- **Deprecation warnings** for RSASHA1, RSASHA1-NSEC3SHA1, DS digest SHA1
- **manual-mode** option in `dnssec-policy`
- **Zone templates** (`template` blocks)
- **DSYNC record** type support (generalizes NOTIFY for parent-child delegation management)
- `named-checkconf -e` prints effective server configuration including all defaults
- `named-checkconf -k` checks `key-directory` alignment with `dnssec-policy`
- DoH and DoT transport support (Artem Boldariev implementation)
- **PROXYv2 protocol support** for upstream communication
- Catalog zones: `notify-defer` option, stalled zone transfer detection and restart
- `servfail-until-ready` for RPZ zones — responds SERVFAIL until all RPZ zones loaded
- SIEVE LRU-based cache expiration
- Meson build system replaces autotools
- TKEY Mode 2 deprecated
- Weak algorithm names no longer accepted in `allow-transfer`, `server`, etc.

---

## RPZ — Response Policy Zones

RPZ allows BIND to intercept DNS responses and substitute custom answers, used for DNS-based threat blocking and content filtering.

### Configuration

```named
options {
    response-policy {
        zone "rpz.example.com" policy NXDOMAIN;
        zone "rpz-redirect.example.com" policy CNAME rpz-redirect.;
        zone "rpz-drop.example.com" policy DROP;
        zone "rpz-passthru.example.com" policy PASSTHRU;
    };
};

zone "rpz.example.com" {
    type primary;
    file "rpz.example.com.zone";
    allow-query { localhost; };
};
```

### RPZ Policy Actions

| Action | Effect |
|---|---|
| `NXDOMAIN` | Return NXDOMAIN (domain doesn't exist) |
| `NODATA` | Return NODATA (no records of queried type) |
| `PASSTHRU` | Allow through, bypassing other RPZ policies |
| `DROP` | Drop query, no response sent |
| `CNAME <target>` | Redirect to specified target (for sinkholing) |
| `redirect` | Redirect to specified IP (wildcard A record in RPZ zone) |

### RPZ Trigger Types

RPZ zones can trigger on:
- **qname** — query name (most common): `blocked.domain.com`
- **client-ip** — client IP address: `32.1.2.3.4.rpz-client-ip`
- **response-ip** — IP in response: `32.1.2.3.4.rpz-ip`
- **nsdname** — authoritative NS name: `ns.bad-domain.com.rpz-nsdname`
- **nsip** — authoritative NS IP: `32.1.2.3.4.rpz-nsip`

### RPZ Providers

- **Spamhaus** RPZ feeds (malware, DGA domains)
- **SURBL** (spam/phishing domains)
- **Infoblox Threat Intelligence** RPZ feeds
- Self-managed internal block lists

### servfail-until-ready (9.20)

Prevents BIND from serving queries before all protective RPZ zones have loaded:
```named
response-policy {
    zone "rpz.example.com" policy NXDOMAIN;
} servfail-until-ready yes;
```

---

## Performance and Operations

### Rate Limiting (RRL)

```named
options {
    rate-limit {
        responses-per-second 10;
        referrals-per-second 5;
        nodata-per-second 5;
        nxdomains-per-second 5;
        errors-per-second 5;
        all-per-second 20;
        slip 2;                // 1-in-N chance of truncated response instead of drop
        window 15;
        log-only no;           // Set to yes for testing without enforcement
    };
};
```

### rndc Commands

```bash
# Reload configuration and zones
rndc reload

# Reload specific zone
rndc reload example.com

# Flush DNS cache (all)
rndc flush

# Flush cache for specific name
rndc flushname example.com

# Dump stats to named_stats.txt
rndc stats

# View current query dump  
rndc dumpdb -all

# Force zone transfer
rndc retransfer example.com

# Pause/resume zone
rndc freeze example.com
rndc thaw example.com

# DNSSEC key management
rndc dnssec -checkds -key <keyid> published example.com
rndc dnssec -step example.com    # Advance manual-mode key rollover

# Sign/reload a zone
rndc sign example.com

# Check named status
rndc status

# Change log verbosity at runtime
rndc trace         # Increase verbosity
rndc notrace       # Reset to default verbosity
```

### Query Logging (Selective)

```named
logging {
    channel querylog {
        file "/var/log/named/queries.log" versions 10 size 20m;
        print-time yes;
    };
    category queries { querylog; };
};
```

Enable/disable at runtime:
```bash
rndc querylog on
rndc querylog off
```

### Monitoring

**named statistics file** (triggered by `rndc stats`):
- Written to `/var/named/data/named_stats.txt` by default
- Contains query counts, cache stats, zone transfer stats

**Statistics channels (HTTP):**
```named
statistics-channels {
    inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
};
```
Access: `curl http://127.0.0.1:8053/json/v1`

**Prometheus monitoring:**
- Use `prometheus-bind-exporter` (unofficial but widely adopted)
- Scrapes named statistics endpoint
- Metrics: resolver queries, cache hits/misses, DNSSEC validation results

---

## Catalog Zones

Catalog zones allow a primary server to automatically provision zones on secondary servers by maintaining a list of zones as DNS records.

```named
zone "catalog.example.com" {
    type primary;
    file "catalog.example.com.zone";
};

// On secondary:
zone "catalog.example.com" {
    type secondary;
    primaries { 192.0.2.1; };
    in-view internal;
};

options {
    catalog-zones {
        zone "catalog.example.com"
            default-primaries { 192.0.2.1; };
    };
};
```

**9.20 improvements:**
- `notify-defer` option for batching NOTIFY messages (avoids flooding on mass zone changes)
- Stalled zone transfer detection and automatic restart

---

## Best Practices

### Chroot Deployment

```bash
# Typical chroot structure on Linux
/var/named/chroot/
├── etc/named.conf
├── etc/named.root.hints
├── var/named/           # Zone files
└── var/log/named/       # Log files
```

Reduces attack surface if named is compromised.

### Views for Internal/External

- Define separate `internal` and `external` views
- Internal: recursion enabled, private records visible, ACL = RFC1918 ranges
- External: recursion disabled, public records only, ACL = `any`
- Use TSIG keys to allow trusted external resolvers to get internal view

### RPZ for DNS Security

- Subscribe to commercial RPZ threat feeds (Spamhaus, etc.)
- Maintain internal block list for unauthorized domains
- Monitor RPZ hit rates via logging category `rpz`
- Use `PASSTHRU` for explicitly allowlisted domains that may appear in block feeds
- Set `servfail-until-ready yes` to avoid serving unprotected queries during startup

### General Best Practices

- Always validate zone files before reload: `named-checkzone example.com example.com.zone`
- Validate config before reload: `named-checkconf /etc/named.conf`
- Use `named-checkconf -e` to see effective configuration including defaults
- Restrict zone transfers to specific IPs or TSIG keys (`allow-transfer`)
- Disable recursion on authoritative-only servers
- Use `minimal-responses yes` to reduce amplification risk
- Keep BIND updated — 9.20 ESV gets security patches
- Consider running separate recursive and authoritative instances

---

## References

- [BIND 9 Documentation (readthedocs)](https://bind9.readthedocs.io/en/stable/)
- [2025 BIND 9 Development Report — ISC](https://www.isc.org/blogs/2025-bind-report/)
- [BIND 9 Release Notes 9.20 — ISC](https://downloads.isc.org/isc/bind9/9.20.21/doc/arm/html/notes.html)
- [DNSSEC Key and Signing Policy — ISC KB](https://kb.isc.org/docs/dnssec-key-and-signing-policy)
- [Understanding Views in BIND 9 — ISC KB](https://kb.isc.org/docs/aa-00851)
- [ISC BIND RPZ Tutorial](https://www.isc.org/docs/BIND_RPZ.pdf)
- [BIND 9 GitHub](https://gitlab.isc.org/isc-projects/bind9)
