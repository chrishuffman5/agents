# BIND Diagnostics Reference

## rndc Commands

```bash
rndc reload                    # Reload config and all zones
rndc reload example.com        # Reload specific zone
rndc flush                     # Flush entire DNS cache
rndc flushname example.com     # Flush specific name
rndc stats                     # Dump stats to named_stats.txt
rndc dumpdb -all               # Dump cache database
rndc retransfer example.com    # Force zone transfer
rndc freeze example.com        # Pause dynamic updates
rndc thaw example.com          # Resume dynamic updates
rndc sign example.com          # Re-sign zone
rndc status                    # Check named status
rndc trace                     # Increase log verbosity
rndc notrace                   # Reset to default verbosity
rndc querylog on               # Enable query logging
rndc querylog off              # Disable query logging

# DNSSEC key management
rndc dnssec -checkds -key <keyid> published example.com
rndc dnssec -step example.com  # Advance manual-mode rollover
```

## Validation Tools

```bash
named-checkconf /etc/named.conf       # Validate configuration
named-checkconf -e                     # Print effective config with defaults (9.20)
named-checkconf -k                     # Check key-directory alignment (9.20)
named-checkzone example.com example.com.zone  # Validate zone file
```

## Query Logging

```
logging {
    channel querylog {
        file "/var/log/named/queries.log" versions 10 size 20m;
        print-time yes;
    };
    category queries { querylog; };
};
```

Enable/disable at runtime: `rndc querylog on/off`

## Statistics

### File-based Stats
`rndc stats` writes to `/var/named/data/named_stats.txt`
Contains query counts, cache stats, zone transfer stats.

### HTTP Statistics Channel
```
statistics-channels {
    inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
};
```
Access: `curl http://127.0.0.1:8053/json/v1`

### Prometheus Monitoring
Use `prometheus-bind-exporter` to scrape named statistics endpoint.
Metrics: resolver queries, cache hits/misses, DNSSEC validation.

## Diagnostic dig Commands

```bash
dig @localhost example.com A              # Query local server
dig @ns1.example.com example.com SOA     # Check SOA serial
dig @ns1.example.com example.com AXFR    # Attempt zone transfer
dig +dnssec example.com A                 # Query with DNSSEC
dig +trace example.com A                  # Full resolution trace
dig +short example.com A                  # Compact output
dig -x 192.0.2.10                         # Reverse lookup
dig @1.1.1.1 example.com A +nsid          # Query with NS ID
```

## Common Troubleshooting

### Zone Not Loading
1. `named-checkzone` to validate zone file syntax
2. Check `named.log` for error messages
3. Verify file permissions (named user must read zone files)
4. Check `$ORIGIN` and trailing dots in zone file

### DNSSEC Validation Failures
1. `dig +dnssec example.com A` -- check AD flag
2. `delv @localhost example.com A` -- detailed DNSSEC validation
3. Check DS record at parent matches KSK
4. Verify key state files exist and are current

### Zone Transfer Failures
1. Check `allow-transfer` ACL on primary
2. Verify TSIG key matches on both sides
3. Check firewall allows TCP/53 between servers
4. `rndc retransfer example.com` on secondary to force retry
