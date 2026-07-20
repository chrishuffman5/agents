# F5 BIG-IP Diagnostics Reference

## System Health

### System Performance
```bash
# Overall system performance
tmsh show sys performance all-stats

# TMM CPU utilization
tmsh show sys tmm-info

# Memory utilization
tmsh show sys memory

# Connection table statistics
tmsh show sys connection

# Current connection count
tmsh show sys performance connections

# System uptime and version
tmsh show sys version
tmsh show sys uptime
```

### Platform Health
```bash
# Hardware health (fans, power supplies, temperature)
tmsh show sys hardware

# Disk usage
tmsh show sys disk

# Interface status
tmsh show net interface all

# VLAN status
tmsh show net vlan

# Self-IP addresses
tmsh show net self
```

## LTM Diagnostics

### Virtual Server Status
```bash
# Show all virtual servers with status
tmsh show ltm virtual

# Detailed virtual server information
tmsh show ltm virtual VS_APP_HTTPS

# Virtual server statistics (connections, bytes, packets)
tmsh show ltm virtual VS_APP_HTTPS stats

# All virtual servers with availability status
tmsh list ltm virtual all-properties | grep -A5 "ltm virtual"
```

**Virtual Server Status Colors:**
- **Green (Available)**: VS and at least one pool member are up
- **Yellow (Unknown)**: VS is enabled but pool status is unknown
- **Red (Offline)**: VS is disabled or all pool members are down
- **Blue (Disabled)**: VS is administratively disabled

### Pool and Member Status
```bash
# Show pool status and member list
tmsh show ltm pool POOL_APP

# Show pool member details and statistics
tmsh show ltm pool POOL_APP members

# Show all pools with status
tmsh show ltm pool

# Show node status (across all pools)
tmsh show ltm node

# Detailed node statistics
tmsh show ltm node 192.168.10.11
```

**Pool Member States:**
- **enabled + available**: Accepting traffic, health check passing
- **enabled + offline**: Health check failing; not receiving traffic
- **disabled + available**: Administratively disabled but health check passing; existing connections drain
- **disabled + offline**: Disabled and health check failing
- **forced-offline**: All connections immediately terminated

### Health Monitor Diagnostics
```bash
# Show monitor status for a pool
tmsh show ltm pool POOL_APP members field-fmt

# Show all monitor instances
tmsh show ltm monitor-instance

# Show monitor instance for specific pool member
tmsh show ltm monitor-instance | grep -A5 "POOL_APP"

# Check if monitor is reaching the server
# (Use tcpdump to see health check traffic)
tcpdump -nni internal host 192.168.10.11 and port 8080
```

### Persistence Table
```bash
# Show persistence records for a virtual server
tmsh show ltm persistence persist-records virtual VS_APP_HTTPS

# Show all persistence records
tmsh show ltm persistence persist-records

# Delete specific persistence record
tmsh delete ltm persistence persist-records virtual VS_APP_HTTPS
```

## Connection Table Analysis

### Connection Commands
```bash
# Show all active connections
tmsh show sys connection

# Show connections to specific virtual server (by VIP)
tmsh show sys connection cs-server-addr 10.10.0.100

# Show connections to specific pool member
tmsh show sys connection ss-server-addr 192.168.10.11

# Show connection count per virtual server
tmsh show ltm virtual stats | grep -E "name|clientside.cur"

# Show connection table summary
tmsh show sys connection count
```

### Connection Table Fields
```
cs-client-addr    = client source IP
cs-client-port    = client source port
cs-server-addr    = VIP (virtual server) IP
cs-server-port    = VIP port
ss-client-addr    = SNAT IP (BIG-IP's source toward server)
ss-client-port    = SNAT port
ss-server-addr    = pool member IP
ss-server-port    = pool member port
```

## SSL/TLS Diagnostics

### SSL Statistics
```bash
# SSL handshake statistics
tmsh show sys performance ssl

# SSL profile statistics
tmsh show ltm profile client-ssl clientssl stats

# Current SSL connections
tmsh show ltm profile client-ssl clientssl | grep "current"

# SSL cipher usage
tmsh show ltm profile client-ssl clientssl ciphers
```

### Certificate Diagnostics
```bash
# List all installed certificates
tmsh list sys crypto cert

# Show certificate details (expiration, subject)
tmsh show sys crypto cert CERT_NAME

# Check certificate chain
openssl s_client -connect 10.10.0.100:443 -servername app.example.com
```

## Network Capture (tcpdump)

### Basic Captures
```bash
# Capture on specific interface
tcpdump -nni external host 10.10.0.100

# Capture on both sides of the proxy (client-side and server-side)
tcpdump -nni 0.0:nnnp host 10.10.0.100 or host 192.168.10.11

# Capture with SSL key logging (for Wireshark decryption)
# WARNING: Performance impact; use only in maintenance
ssldump -Adn -i external host 10.10.0.100

# Write capture to file for analysis
tcpdump -nni 0.0:nnnp -s0 -w /var/tmp/capture.pcap host 10.10.0.100

# Capture only SYN packets (connection establishment)
tcpdump -nni external "tcp[tcpflags] & tcp-syn != 0" and host 10.10.0.100
```

### BIG-IP-Specific tcpdump Notes
- `0.0` = all interfaces (client and server side)
- `0.0:nnn` = all interfaces, no TMM internal traffic
- `0.0:nnnp` = all interfaces, no TMM internal, with peer info
- Use `-s0` to capture full packets (default truncates)
- Captures stored in `/var/tmp/` (limited space)

## iRule Diagnostics

### iRule Statistics
```bash
# Show iRule execution statistics
tmsh show ltm rule IRULE_NAME stats

# Key counters:
# - Total executions per event
# - Average and max execution time (cycles)
# - Aborts (iRule errors)
```

### iRule Debugging
```tcl
# Add logging to iRule for debugging
when HTTP_REQUEST {
    log local0. "Client: [IP::client_addr] URI: [HTTP::uri] Host: [HTTP::host]"
}

# Check /var/log/ltm for iRule log output
# tail -f /var/log/ltm | grep "irule"
```

## iHealth

F5 iHealth is a diagnostic analysis service:
1. Generate a QKView on the BIG-IP: `tmsh run sys diagnostics qkview`
2. Upload QKView to `ihealth.f5.com`
3. iHealth analyzes configuration, logs, and performance data
4. Reports known issues, CVEs, configuration recommendations

**When to use**: Before and after upgrades, periodic health assessments, troubleshooting complex issues.

## HA Diagnostics

### Failover Status
```bash
# Show device group status
tmsh show cm device-group

# Show device trust status
tmsh show cm device

# Show traffic group status (which device is active)
tmsh show cm traffic-group

# Show sync status
tmsh show cm sync-status

# Show failover status
tmsh show sys failover
```

### Failover Troubleshooting
```bash
# Show HA heartbeat status
tmsh show sys ha-status

# Show network failover configuration
tmsh list sys ha-mirror

# Show failover history
tmsh show sys failover history

# Check for config sync conflicts
tmsh show cm sync-status detail
```

## Common Troubleshooting Scenarios

### Pool Member Offline (Health Check Failing)

| Step | Command | What to Check |
|---|---|---|
| 1 | `tmsh show ltm pool POOL members` | Member status and monitor state |
| 2 | `tmsh show ltm monitor-instance` | Monitor results for the member |
| 3 | `tcpdump -nni internal host <member-ip>` | Are health probes reaching server? |
| 4 | `curl -v http://<member-ip>:<port>/health` | Manual check from BIG-IP shell |
| 5 | Check firewall rules | Is BIG-IP self-IP allowed to probe? |

### Client Cannot Reach Virtual Server

| Step | Command | What to Check |
|---|---|---|
| 1 | `tmsh show ltm virtual VS_NAME` | Is VS available (green)? |
| 2 | `tmsh show ltm pool POOL_NAME` | Are pool members available? |
| 3 | `tmsh show sys connection cs-server-addr <VIP>` | Any active connections? |
| 4 | `tcpdump -nni external host <VIP>` | Are packets arriving at BIG-IP? |
| 5 | `tmsh show net arp` | Is ARP resolving for VIP? |
| 6 | Check SNAT and routing | Can BIG-IP route to pool members? |

### SSL Handshake Failure

| Step | Command | What to Check |
|---|---|---|
| 1 | `tmsh show ltm profile client-ssl` | Correct cert/key bound? |
| 2 | `openssl s_client -connect <VIP>:443` | Cert chain valid? |
| 3 | Check cipher compatibility | Client supports configured ciphers? |
| 4 | `tmsh show sys crypto cert` | Certificate not expired? |
| 5 | `tail /var/log/ltm` | SSL-specific error messages? |

### Performance Degradation

| Step | Command | What to Check |
|---|---|---|
| 1 | `tmsh show sys performance all-stats` | CPU, memory, throughput |
| 2 | `tmsh show sys tmm-info` | TMM CPU utilization per core |
| 3 | `tmsh show ltm rule <name> stats` | iRule performance impact |
| 4 | `tmsh show sys connection count` | Connection table size |
| 5 | `tmsh show net interface stats` | Interface errors, drops |

## Log Locations

| Log File | Contents |
|---|---|
| `/var/log/ltm` | LTM events, iRule logs, pool status changes |
| `/var/log/apm` | APM access policy events |
| `/var/log/asm` | ASM/WAF security events |
| `/var/log/audit` | Configuration changes, admin logins |
| `/var/log/gtm` | GTM/DNS events |
| `/var/log/daemon.log` | System daemon events |
