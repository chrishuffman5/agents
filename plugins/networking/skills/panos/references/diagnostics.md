# PAN-OS Diagnostics Reference

## CLI Modes

### Operational Mode (prompt: `>`)
Default mode. View state, monitor, execute operational commands. Not persistent.

### Configuration Mode (prompt: `#`)
Enter via `configure`. Modify candidate config. Changes go live only on `commit`.

## System Information
```
show system info                     # Platform, SW version, serial
show system resources                # CPU, memory utilization
show system disk-space               # Disk usage
show jobs all                        # Background jobs (commits, installs)
```

## Interface and Routing
```
show interface all                   # Interface status summary
show interface <name>                # Specific interface detail
show routing route                   # Active routing table
show arp all                         # ARP table
test routing fib-lookup virtual-router <vr> ip <dest>  # FIB lookup
```

## Session Inspection
```
show session all                     # All active sessions
show session all filter source <IP>  # Filter by source
show session all filter application <app>  # Filter by application
show session all filter state ACTIVE # Active sessions only
show session id <id>                 # Detailed session info
show session info                    # Session table statistics
clear session all                    # Clear all sessions (disruptive!)
clear session id <id>                # Clear specific session
```

## Counter Analysis
```
show counter global                  # Global packet/drop counters
show counter global filter severity drop  # Only drop counters
show counter global filter delta yes      # Show only changing counters
```

## Packet Captures
```
# Set capture filter
debug dataplane packet-diag set filter match source <IP>
debug dataplane packet-diag set filter match destination <IP>
debug dataplane packet-diag set filter match protocol <num>
debug dataplane packet-diag set filter match destination-port <port>

# Set capture stages (firewall, transmit, receive, drop)
debug dataplane packet-diag set capture stage firewall file pcap1.pcap
debug dataplane packet-diag set capture stage drop file drop1.pcap

# Start/stop/show capture
debug dataplane packet-diag set filter on
debug dataplane packet-diag show capture
debug dataplane packet-diag set filter off

# Clear filter
debug dataplane packet-diag clear filter
debug dataplane packet-diag clear capture
```

## Policy and Application Testing
```
# Simulate security policy match
test security-policy-match from <src-zone> to <dst-zone> source <src-ip> destination <dst-ip> protocol <num> destination-port <port> application <app>

# Test NAT rule match
test nat-policy-match from <src-zone> to <dst-zone> source <src-ip> destination <dst-ip> protocol <num> destination-port <port>

# Test application identification
test application-id application <app-name> flow
```

## Log Inspection
```
show log traffic                     # Recent traffic logs
show log threat                      # Recent threat logs
show log url                         # Recent URL filtering logs
show log system                      # System logs
show log config                      # Configuration change logs
```

## High Availability
```
show high-availability state         # HA status
show high-availability all           # Full HA detail
show high-availability state-synchronization  # Sync status

# Manual failover operations
request high-availability state suspend          # Manually fail over
request high-availability state functional       # Return to HA
request high-availability sync-to-remote running-config  # Force config sync
```

## Content and Software Updates
```
request content upgrade check                # Check for content updates
request content upgrade download latest      # Download latest content
request content upgrade install version latest  # Install latest content
request anti-virus upgrade check             # Check AV updates
request anti-virus upgrade install version latest
request wildfire upgrade check               # Check WildFire updates
request system software check               # Check PAN-OS updates
request system software download version <ver>
request system software install version <ver>
```

## VPN Troubleshooting
```
show vpn ike-sa                      # IKE SA table
show vpn ipsec-sa                    # IPsec SA table
show vpn flow                        # Traffic statistics
test vpn ike-sa gateway <gw-name>    # Test IKE SA
test vpn ipsec-sa tunnel <name>      # Test IPsec SA
debug ike global on debug            # Enable IKE debug logging
```

## Configuration Management
```
diff                                 # Show candidate vs running diff
validate full                        # Validate without committing
commit                               # Apply candidate config
commit force                         # Force commit
commit partial admin-name <admin>    # Partial commit (10.2+)
load config from <filename>          # Load saved config
save config to <filename>            # Save candidate
revert config                        # Revert candidate to running
show config saved                    # List saved configs
```

## Troubleshooting Workflow

1. **Identify the traffic**: Source IP, destination IP, port, protocol, application
2. **Check session table**: `show session all filter source <IP>` -- is a session being created?
3. **Test policy match**: `test security-policy-match` -- which rule is matching?
4. **Check counters**: `show counter global filter delta yes` -- any drop counters increasing?
5. **Capture packets**: Set filter and capture at firewall and drop stages
6. **Check logs**: `show log traffic` and `show log threat` for the specific flow
7. **Verify routing**: `test routing fib-lookup` for routing issues
8. **Check HA**: `show high-availability state` for HA-related issues
