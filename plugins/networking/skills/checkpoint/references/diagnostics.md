# Check Point Diagnostics Reference

## CLI Modes

### Clish (Structured CLI)
Default shell on Gaia OS. Provides structured commands for OS-level configuration and status. Prompt: `hostname>`

### Expert Mode (Bash)
Enter via `expert` command from clish. Full Linux bash shell for advanced commands (cpstat, fw, fwaccel, etc.). Prompt: `[Expert@hostname]#`

## cpstat -- Component Status

```bash
cpstat fw -f policy         # Policy name, version, interface list
cpstat fw -f sync           # ClusterXL sync statistics
cpstat fw -f all            # All firewall stats
cpstat os -f cpu            # CPU utilization per core
cpstat os -f memory         # Memory usage (real, virtual, swap)
cpstat os -f ifconfig       # Interface table with counters
cpstat blades               # All installed Software Blades status
cpstat ha                   # High availability status
cpstat vpn                  # VPN tunnel status summary
cpstat antimalware          # Anti-Virus blade status
cpstat ips                  # IPS blade status
```

### Usage Patterns
- `cpstat fw -f all` is the first command for general health assessment
- `cpstat os -f cpu` combined with `cpstat os -f memory` for resource bottleneck identification
- `cpstat blades` verifies all licensed blades are active

## fw Commands

```bash
fw ver                      # Firewall version and build
fw stat                     # Connection table statistics (total, peak, limit)
fw tab -t connections -s    # Connection table summary
fw getifs                   # Interface list with IP addresses
fw ctl pstat                # Firewall kernel stats (connections, memory, crypto)
fw ctl zdebug drop          # Real-time drop reason logging (essential for troubleshooting)
fw monitor -e "accept;"     # Packet capture (pre/post NAT, all inspection points)
fw log -l                   # Show recent firewall log entries
fw fetch <target>           # Fetch policy from management server
fw unloadlocal              # Unload local policy (emergency, allows all traffic)
```

### fw ctl zdebug drop
The most important troubleshooting command. Shows every packet dropped by the firewall kernel with the reason:
- Run from expert mode
- Output includes: source/destination IP, port, protocol, drop reason, rule number
- Combine with `grep` to filter for specific traffic
- Stop with Ctrl+C

### fw monitor
Built-in packet capture at multiple inspection points:
- `i` -- Pre-inbound (before any processing)
- `I` -- Post-inbound (after inbound processing)
- `o` -- Pre-outbound (before outbound processing)
- `O` -- Post-outbound (after all processing)
- Captures show pre-NAT and post-NAT packets at different stages
- Export to pcap: `fw monitor -e "accept;" -o capture.pcap`

## fwaccel -- SecureXL Acceleration

```bash
fwaccel stat                # SecureXL status and accelerated interfaces
fwaccel stats -s            # Detailed acceleration statistics
fwaccel stats -d            # Drop statistics
fwaccel on                  # Enable SecureXL
fwaccel off                 # Disable SecureXL (performance impact)
fwaccel templates           # Forwarding template table (accelerated connections)
fwaccel conns               # Show accelerated connection table
```

### Interpreting fwaccel stats
- **Accelerated packets**: Forwarded at line rate by SecureXL
- **PXL packets**: Partially accelerated (medium path)
- **F2F packets**: Firewall-to-firewall (slow path, full kernel processing)
- Healthy system: majority of packets accelerated; high F2F ratio indicates features preventing acceleration

## CoreXL

```bash
sim affinity -l             # CoreXL SND/FWK affinity table
sim affinity -s             # Summary of core allocation
fw ctl multik stat          # Multi-core statistics per firewall worker
fw ctl affinity -l -r       # CPU affinity and utilization per core
```

### Tuning
- SND cores: handle packet distribution to FWK cores
- FWK cores: run firewall inspection
- Default ratio is usually optimal; adjust only with clear bottleneck evidence
- More FWKs: inspection-heavy workloads (deep inspection, HTTPS)
- More SNDs: connection-heavy workloads (high session rate, low inspection)

## Cluster Commands

```bash
cphaprob stat               # Cluster member states (Active, Standby, Down)
cphaprob -a if              # CCP interface status (all interfaces)
cphaprob list               # List all registered critical processes
clusterXL_admin down        # Manual graceful failover (demote this member)
clusterXL_admin up          # Restore member to active candidacy
fw hastat                   # HA status summary
fw ctl pstat                # Includes HA sync statistics
cphaconf set_ccp broadcast  # Set CCP mode to broadcast (troubleshooting)
```

### Cluster Troubleshooting Workflow
1. `cphaprob stat` -- Verify member states
2. `cphaprob -a if` -- Check all CCP interfaces are "OK"
3. `cphaprob list` -- Verify no critical process is in "problem" state
4. `fw ctl pstat` -- Check sync status and delta queue
5. `cpstat fw -f sync` -- Detailed sync statistics

## VPN Troubleshooting

```bash
vpn tu                      # VPN tunnel utility (interactive debugging)
vpn tunnelutil              # Same as vpn tu
vpn shell                   # VPN shell for advanced debugging
cpstat vpn                  # VPN status summary
fw tab -t IKE_SA_table -s   # IKE SA table
fw tab -t IPSEC_SA_table -s # IPsec SA table
```

### vpn tu Common Options
1. List all IKE SAs
2. List all IPsec SAs
3. Delete IKE SA by peer
4. Delete IPsec SA by peer
5. Delete all SAs for a peer

## mgmt_cli -- Management API CLI

```bash
# Authentication
mgmt_cli login                                    # Interactive login; returns sid
mgmt_cli login user admin password <pwd>           # Non-interactive login

# Object Management
mgmt_cli show hosts limit 50                       # List first 50 host objects
mgmt_cli show host name "web01"                    # Show specific host
mgmt_cli add host name "web01" ip-address "10.1.1.100"
mgmt_cli set host name "web01" ip-address "10.1.1.200"
mgmt_cli delete host name "web01"

# Network Objects
mgmt_cli show networks limit 50
mgmt_cli add network name "servers" subnet "10.1.1.0" mask-length 24

# Group Management
mgmt_cli add group name "web-servers" members.1 "web01" members.2 "web02"

# Access Rules
mgmt_cli show access-rulebase name "Network" limit 20
mgmt_cli add access-rule layer "Network" position top name "Allow-Web" \
  source "internal-net" destination "web-servers" service "HTTPS" action "Accept"
mgmt_cli set access-rule layer "Network" uid "<uid>" action "Drop"

# Session Management
mgmt_cli publish                                   # Commit changes
mgmt_cli discard                                   # Discard changes
mgmt_cli logout                                    # End session

# Policy Installation
mgmt_cli install-policy policy-package "Standard" targets "gw01"
mgmt_cli install-policy policy-package "Standard" targets.1 "gw01" targets.2 "gw02"

# Utility
mgmt_cli show-changes                              # Show unpublished changes
mgmt_cli show sessions                             # Show active admin sessions
```

## Web API (REST / HTTPS)

### Authentication
```
POST https://<mgmt-ip>/web_api/login
Body: {"user": "admin", "password": "..."}
Response: {"sid": "session-id-string", ...}
```
Use `X-chkp-sid: <sid>` header for all subsequent requests.

### Common Operations
```
POST /web_api/show-hosts           # List hosts
POST /web_api/add-host             # Create host
POST /web_api/set-host             # Modify host
POST /web_api/delete-host          # Delete host
POST /web_api/show-access-rulebase # Show rules
POST /web_api/add-access-rule      # Add rule
POST /web_api/publish              # Commit changes
POST /web_api/install-policy       # Push to gateways
POST /web_api/logout               # End session
```

### API Best Practices
- Always publish before install-policy
- Use `"version": "1.8"` in payload for API version pinning
- Batch operations with `payload` arrays for efficiency
- Use `task-id` for async operations (install-policy returns task-id)
- Swagger spec: `https://<mgmt-ip>/api/swagger.json`

## System-Level Diagnostics

```bash
# Process status
cpwd_admin list             # Check Point watchdog -- all process states
cpstop / cpstart            # Stop/start all Check Point services (disruptive)

# Disk and logs
df -h                       # Disk usage
ls -la /var/log/             # Log directory
fw logswitch                # Rotate current log file

# Network
ifconfig -a                 # All interfaces (Gaia OS level)
netstat -rn                 # Routing table
tcpdump -i <if> -nn         # Standard packet capture (OS level, not firewall level)

# Performance
top                         # Process CPU/memory (expert mode)
sar -u 1 5                  # CPU utilization over 5 seconds
free -m                     # Memory summary
```

## Troubleshooting Workflows

### Traffic Not Passing
1. `fw ctl zdebug drop` -- Check if firewall is dropping and why
2. `cpstat fw -f policy` -- Verify correct policy is installed
3. `fw monitor -e "accept;"` -- Verify packets arrive at firewall
4. Check NAT rules if destination is translated
5. `show route` (clish) -- Verify routing
6. `cphaprob stat` -- If clustered, verify correct member is active

### Performance Degradation
1. `cpstat os -f cpu` -- Identify CPU bottleneck
2. `cpstat os -f memory` -- Check memory pressure
3. `fwaccel stat` -- Verify SecureXL is enabled
4. `fwaccel stats -s` -- Check accelerated vs. F2F ratio
5. `sim affinity -l` -- Review CoreXL distribution
6. `fw tab -t connections -s` -- Check connection table utilization

### Cluster Issues
1. `cphaprob stat` -- Member states
2. `cphaprob -a if` -- CCP interface health
3. `cphaprob list` -- Critical process status
4. `cpstat fw -f sync` -- Sync delta queue (should not be growing)
5. Check dedicated sync interface for errors/drops

### VPN Tunnel Down
1. `cpstat vpn` -- Overall VPN status
2. `vpn tu` -- List IKE/IPsec SAs; check for established tunnels
3. `fw ctl zdebug drop` -- Check for IPsec-related drops
4. `fw log -l` -- Check for VPN-related log entries
5. Verify IKE Phase 1 (encryption, hash, DH group) and Phase 2 (PFS, lifetime) match peer
6. Check routing: traffic must hit the firewall to be encrypted
