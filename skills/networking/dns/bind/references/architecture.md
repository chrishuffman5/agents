# BIND Architecture Reference

## named.conf Top-Level Statements

```
options { ... };           # Global server settings
logging { ... };           # Log channels and categories
acl <name> { ... };        # Named address match lists
key <name> { ... };        # TSIG key definitions
zone <name> { ... };       # Zone definitions
view <name> { ... };       # View definitions
controls { ... };          # rndc control channel
statistics-channels { ... }; # HTTP stats endpoint
server <ip> { ... };       # Per-server settings
```

## Options Block Key Settings

directory, listen-on, recursion, allow-recursion, allow-query, allow-transfer, forwarders, forward (only/first), dnssec-validation (auto), max-cache-size, minimal-responses, rate-limit, version

## Views (Split-Horizon)

```
view "internal" {
    match-clients { "internal"; };
    recursion yes;
    zone "example.com" { type primary; file "internal/example.com.zone"; };
};
view "external" {
    match-clients { any; };
    recursion no;
    zone "example.com" { type primary; file "external/example.com.zone"; };
};
```

Rules: all zones must be inside views once any view exists. First match wins. TSIG keys can be used in match-clients.

## Zone File Format

SOA record fields: Serial (YYYYMMDDnn), Refresh, Retry, Expire, Minimum (negative TTL).

`$ORIGIN` sets default domain. `$TTL` sets default TTL. Relative names are relative to origin.

## DNSSEC with KASP

Built-in policies: `default` (ECDSAP256SHA256 CSK, 1-year), `insecure` (removes signing).

Custom policy supports: KSK/ZSK separation, algorithm selection, NSEC3 params, signature lifetimes.

Inline signing (default in 9.20): unsigned zone file stays editable; signed zone in memory.

Key state tracked in `.state` files. KASP handles ZSK rollover automatically. KSK rollover: semi-automatic (admin must submit DS to parent and confirm with `rndc dnssec -checkds`).

Manual-mode (9.20): pauses at each key state transition; advance with `rndc dnssec -step`.

Zone templates (9.20): reusable zone configuration blocks.

## RPZ Configuration

```
response-policy {
    zone "rpz.example.com" policy NXDOMAIN;
} servfail-until-ready yes;
```

Actions: NXDOMAIN, NODATA, PASSTHRU, DROP, CNAME. Triggers: qname, client-ip, response-ip, nsdname, nsip.

Providers: Spamhaus, SURBL, Infoblox, self-managed lists.

## TSIG

```
key "transfer-key" { algorithm hmac-sha256; secret "base64=="; };
```

Generate: `tsig-keygen -a hmac-sha256 transfer-key`

GSS-TSIG for AD integration: `tkey-gssapi-keytab "/etc/named.keytab";`

## Catalog Zones

Primary maintains zone list as DNS records. Secondaries auto-provision zones. 9.20 adds `notify-defer` and stalled transfer restart.

## RRL (Rate Limiting)

```
rate-limit {
    responses-per-second 10;
    slip 2;    # 1-in-N truncated response instead of drop
    window 15;
};
```
