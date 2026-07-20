# F5 BIG-IP Best Practices Reference

## Virtual Server Design

### Choosing the Right VS Type

**Standard Virtual Server** (default, recommended for most use cases):
- Full-proxy: terminates client connection, creates new connection to pool member
- Supports all LTM features: iRules (all events), SSL offload, compression, caching, persistence
- Use for: HTTP/HTTPS applications, any workload requiring L7 features

**Performance (Layer 4) / FastL4**:
- Passes TCP/UDP with minimal processing; does NOT terminate connection
- No SSL offload, no HTTP profile, limited iRule events (FLOW_INIT, CLIENT_ACCEPTED only)
- Very high packet-per-second throughput
- Use for: Non-HTTP TCP/UDP services, DNS forwarding, high-PPS workloads

**When NOT to use FastL4**: Any scenario requiring HTTP inspection, SSL termination, cookie persistence, header-based routing, WAF, or HTTP-specific iRules.

### Profile Selection

**TCP Profile**:
- Use `tcp-wan-optimized` on client-side (external) for WAN connections
- Use `tcp-lan-optimized` on server-side (internal) for LAN connections
- This combination provides TCP optimization for different network characteristics

**HTTP Profile**:
- Enable OneConnect (connection multiplexing) for standard deployments
- Set appropriate `max-header-size` for applications with large headers/cookies
- Enable `insert x-forwarded-for` to preserve client IP for backend logging
- Set `server-agent-name` to blank to remove BIG-IP identification

**SSL Profile Best Practices**:
- Minimum TLS 1.2 (TLS 1.3 recommended)
- Disable SSLv3, TLS 1.0, TLS 1.1
- Use strong cipher suites: ECDHE + AES-GCM preferred
- Enable OCSP stapling for certificate validation performance
- Enable TLS session resumption for handshake performance
- Use SNI for multi-domain virtual servers on a single VIP

### SNAT Configuration

| Scenario | SNAT Type | Notes |
|---|---|---|
| Servers default gateway is BIG-IP | None (no SNAT needed) | Server routes responses back through BIG-IP |
| Servers default gateway is NOT BIG-IP | Automap | BIG-IP uses self-IP as source toward servers |
| High connection rate (>64k/sec) | SNAT Pool | Multiple SNAT IPs prevent port exhaustion |
| DSR required | None | Server responds directly to client |

**Port exhaustion**: Each SNAT IP provides ~64,000 simultaneous connections (port range). If a single self-IP is used (automap) and connection rate exceeds this, connections fail. Solution: Create a SNAT pool with multiple IPs.

## iRules Best Practices

### Performance Guidelines

1. **Minimize event subscriptions**: Only listen for events you need
   - Bad: Subscribe to `HTTP_REQUEST`, `HTTP_RESPONSE`, `CLIENT_ACCEPTED` when only `HTTP_REQUEST` logic is needed
   - Good: Only subscribe to `HTTP_REQUEST`

2. **Use datagroups for lookups**: Datagroup lookup (`class match`) is O(log n); iRule `if/elseif` chains are O(n)
   ```tcl
   # Good: datagroup lookup
   if { [class match [HTTP::host] equals HOST_TO_POOL] } {
       pool [class lookup [HTTP::host] HOST_TO_POOL]
   }
   
   # Bad: long if/elseif chain
   if { [HTTP::host] eq "app1.example.com" } { pool POOL1 }
   elseif { [HTTP::host] eq "app2.example.com" } { pool POOL2 }
   # ... 50 more lines
   ```

3. **Avoid `regexp` in hot paths**: Regular expressions are CPU-expensive. Use `string match` (glob patterns) or `starts_with` / `ends_with` when possible.

4. **Cache computed values**: Store values in variables rather than calling the same command multiple times in one event.

5. **Use `switch` instead of `if/elseif`**: `switch` is more efficient for multi-way branching.

### Common iRule Patterns

**HTTP to HTTPS Redirect**:
```tcl
when HTTP_REQUEST {
    HTTP::redirect "https://[HTTP::host][HTTP::uri]"
}
```

**Host-Based Routing**:
```tcl
when HTTP_REQUEST {
    switch -glob [string tolower [HTTP::host]] {
        "api.*"    { pool POOL_API }
        "admin.*"  { pool POOL_ADMIN }
        default    { pool POOL_WEB }
    }
}
```

**Maintenance Page**:
```tcl
when LB_FAILED {
    HTTP::respond 200 content "<html><body><h1>Service Temporarily Unavailable</h1></body></html>" Content-Type "text/html"
}
```

**Rate Limiting (Simple)**:
```tcl
when HTTP_REQUEST {
    set key [IP::client_addr]
    set count [table incr $key]
    if { $count == 1 } { table timeout $key 60 }
    if { $count > 100 } {
        HTTP::respond 429 content "Rate limit exceeded"
        return
    }
}
```

## Monitor Selection Guide

### Decision Tree

```
Is it an HTTP/HTTPS service?
  Yes -> HTTP(S) monitor with expected status code (200) and response string
  No  -> Is it a database?
    Yes -> Database-specific monitor (MSSQL, MySQL, PostgreSQL)
    No  -> Is it a custom TCP service?
      Yes -> TCP monitor (validates port open)
      No  -> Is it a health endpoint that requires custom logic?
        Yes -> External monitor (script-based)
        No  -> Gateway ICMP or TCP Half Open
```

### Monitor Configuration Best Practices

**HTTP Monitor**:
```bash
create ltm monitor http MONITOR_APP_HTTP {
    defaults-from http
    interval 10
    timeout 31        # 3x interval + 1
    send "GET /health HTTP/1.1\r\nHost: app.internal\r\nConnection: close\r\n\r\n"
    recv "healthy"    # Expected string in response body
}
```

- **interval**: 5-10 seconds for most workloads; 3-5 seconds for critical services
- **timeout**: Set to (interval x 3) + 1 as a standard formula
- **send string**: Include `Host` header for apps that require it; use `Connection: close`
- **recv string**: Match a specific string in the response body, not just status code

**Multiple Monitors**:
- Assign both TCP and HTTP monitors to a pool for defense in depth
- TCP confirms port availability; HTTP confirms application health
- Monitor `min` setting: set to `all` to require all monitors pass, or a number for "at least N"

## HA Deployment Best Practices

### Network Design
- **Dedicated HA VLAN**: Never share HA sync/failover with production traffic
- **Dedicated management**: Out-of-band management network separate from data traffic
- **Mirroring**: Enable connection mirroring for critical virtual servers (allows active connections to survive failover)
- **MAC masquerade**: Configure for faster failover (avoids gratuitous ARP delays)

### Configuration
- **Disable preemption**: Unless organizational policy requires specific device to be active
- **Network failover**: Configure network failover in addition to serial failover
- **HA group**: Use HA group with monitored objects (trunk health, pool availability) for intelligent failover decisions
- **Config sync**: Always sync immediately after configuration changes

### Failover Testing
- Schedule quarterly failover tests during maintenance windows
- Document expected failover behavior and timing
- Test both directions (A->B and B->A)
- Verify all virtual servers become available on the new active device
- Check persistence records survive failover (if mirroring is enabled)

### Upgrade Procedure (HA Pair)
1. Backup both devices (`tmsh save sys ucs`)
2. Upload new software image to both devices
3. Install and reboot standby device first
4. Verify standby is healthy on new version
5. Force failover to newly upgraded device
6. Install and reboot the now-standby (formerly active) device
7. Verify both devices healthy and in sync
8. Optional: fail back to original active device

## SSL/TLS Best Practices

### Cipher String
```bash
# Modern cipher string (TLS 1.2+)
modify ltm profile client-ssl clientssl ciphers "ECDHE+AES-GCM:ECDHE+AES:!RC4:!3DES:!MD5:!aNULL"
```

### Certificate Management
- Set calendar reminders for certificate renewal (90 days before expiration)
- Use OCSP stapling to improve client-side validation performance
- For multi-domain: Use SNI with separate SSL profiles per domain
- Automate certificate deployment via iControl REST API
- Store certificates in secure partition (not Common if multi-tenant)

### Re-Encryption (Backend SSL)
```bash
# Server-side SSL profile for backend TLS
create ltm profile server-ssl SERVERSSL_APP {
    defaults-from serverssl
    cert none           # No client cert to server (unless mTLS)
    server-name app.internal
}
```

## F5 Distributed Cloud (XC) Integration

### When to Consider XC

| Use Case | BIG-IP On-Prem | F5 XC | Both |
|---|---|---|---|
| Data center LB | Primary | No | -- |
| Multi-cloud LB | Possible | Better fit | Hybrid |
| WAF | ASM on BIG-IP | XC WAF | Layered defense |
| Bot defense | Limited (ASM bots) | ML-powered | Best combined |
| API security | Manual | Automatic discovery | XC for discovery |
| GSLB | GTM | XC DNS LB | Migration path |

### Hybrid Architecture
- BIG-IP LTM handles on-prem data center traffic
- F5 XC handles multi-cloud and edge traffic
- XC Customer Edge (CE) deployed alongside BIG-IP for connectivity
- Unified policy management across both platforms via XC console

## Terraform Best Practices

### Provider Configuration
```hcl
provider "bigip" {
  address  = "https://192.168.1.1"
  username = "admin"
  password = var.bigip_password
}
```

### Resource Patterns
- Use `bigip_ltm_pool`, `bigip_ltm_virtual_server`, `bigip_ltm_monitor` for declarative config
- Use AS3 declarations (`bigip_as3` resource) for complex multi-object configurations
- Store state in remote backend (S3, Azure Blob) for team collaboration
- Use `lifecycle { prevent_destroy = true }` on production virtual servers

### AS3 (Application Services 3)
AS3 provides declarative JSON-based configuration:
- Single API call deploys complete application (VS + pool + monitors + SSL + iRules)
- Idempotent -- same declaration always produces same result
- Supports partitions and tenant isolation
- Preferred for infrastructure-as-code workflows over imperative TMSH
