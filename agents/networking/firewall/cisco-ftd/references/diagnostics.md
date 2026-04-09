# Cisco FTD Diagnostics Reference

## Two CLI Contexts

### FTD CLISH (Primary CLI)
Accessed via SSH or console. Purpose-built for FTD management.
```
> show version                  # FTD, LINA, Snort versions
> show interface                # Interface status
> show route                    # Routing table
> show managers                 # FMC registration status
> show cpu                      # CPU utilization
> show memory                   # Memory utilization
> show disk                     # Disk usage
> show snort status             # Snort process status
> show snort statistics         # Snort packet stats
> show snort counters           # Drop/allow counters per instance
> show high-availability info   # HA status
> show cluster info             # Cluster status
```

### LINA Diagnostic CLI (ASA Mode)
Access: `system support diagnostic-cli` from CLISH.
**Read-only diagnostics only** -- config changes overwritten on FMC deploy.

## Connection and State Table (LINA)
```
show conn                       # Active connections
show conn count                 # Connection count
show conn address <IP>          # Connections for specific IP
show conn long                  # Detailed with flags
show xlate                      # NAT translation table
show xlate count                # NAT translation count
```

**Connection flags**: A=awaiting ACK, B=half-open, U=UDP, f=FIN wait, R=reset

## ASP Drop Analysis (LINA)
Critical for diagnosing why packets are dropped:
```
show asp drop                   # All drop reasons with counts
show asp drop count             # Summary counts
clear asp drop                  # Reset counters (use carefully)
show asp table classify domain permit  # ASP permit rules
show asp table classify domain deny    # ASP deny rules
show asp table routing          # Datapath routing table
show asp table arp              # ASP ARP table
show asp table vpn-context      # VPN crypto contexts
```

**Common ASP drop reasons:**
| Drop Reason | Meaning |
|---|---|
| `acl-drop` | Dropped by ACL/ACP |
| `nat-no-xlate-to-pat-pool` | No PAT addresses available |
| `no-route` | No route to destination |
| `reverse-path-failed` | uRPF check failed |
| `tcp-not-syn` | Non-SYN for non-existent connection |
| `snort-drop` | Dropped by Snort IPS |
| `snort-resp-drop` | Dropped by Snort file/malware policy |
| `vpn-failed` | VPN processing failure |
| `flow-expired` | Connection timed out |

## Packet Capture (LINA)
```
# Create captures
capture CAPIN interface inside match ip host 10.1.1.1 any
capture CAPOUT interface outside match ip any host 203.0.113.1

# View capture
show capture CAPIN
show capture CAPIN detail               # Full decode
show capture CAPIN dump                 # Hex dump

# Export: https://<mgmt_ip>/capture/CAPIN/pcap

# ASP drop capture
capture ASP_CAP type asp-drop all
show capture ASP_CAP
```

## Packet Tracer (LINA)
Simulates packet through firewall showing every processing step:
```
packet-tracer input outside tcp 203.0.113.50 12345 10.1.1.10 443
packet-tracer input outside tcp 203.0.113.50 12345 203.0.113.10 443 detailed
packet-tracer input inside udp 10.1.1.100 5000 8.8.8.8 53
packet-tracer input inside icmp 10.1.1.100 8 0 8.8.8.8
```

**Output phases**: ROUTE-LOOKUP, ACCESS-LIST, IP-OPTIONS, NAT, VPN, CONN-SETTINGS, SNORT, ADJACENCY -> final ALLOW or DROP with reason.

## VPN Commands (LINA)
```
show vpn-sessiondb                  # All VPN sessions
show vpn-sessiondb anyconnect       # AnyConnect/Secure Client
show vpn-sessiondb l2l              # Site-to-site
show vpn-sessiondb detail anyconnect  # Detailed AnyConnect
show crypto ikev2 sa                # IKE SAs
show crypto ipsec sa                # IPsec SAs
debug crypto ikev2 protocol 5      # IKEv2 debug
debug crypto ipsec 5               # IPsec debug
show running-config crypto          # VPN crypto config
```

## FMC Registration (CLISH)
```
show managers                       # Registration status
configure manager add <FMC_IP> <reg_key> [nat_id]
configure manager delete            # De-register
configure manager local             # Switch to FDM
ping system <FMC_IP>               # Test FMC connectivity
```

## Snort Troubleshooting (CLISH)
```
show snort status                   # Snort instances running?
show snort statistics               # Passed/dropped/blocked
show asp drop | include snort       # Snort-related ASP drops
system support trace                # Interactive packet trace through Snort
```

## Expert Mode (Linux Shell)
```
expert
sudo su -
tail -f /ngfw/var/log/messages          # System log
tail -f /ngfw/var/log/sftunnel.log      # FMC-FTD tunnel
tail -f /ngfw/var/log/action_queue.log  # Deploy queue
```

## Interface and Routing (LINA)
```
show interface <name>               # Stats, errors, drops
show interface ip brief             # All interfaces with IPs
show route                          # Routing table
show route <ip>                     # Route for destination
show arp                            # ARP table
show threat-detection statistics    # Threat detection stats
```

## Health Monitoring
```
show disk                           # >90% triggers HA failover!
show cpu usage system               # Per-process CPU
show memory system detail           # Memory breakdown
show failover                       # HA failover status
show failover statistics            # Failover history
```

## Troubleshooting Workflow

1. **Verify FMC connectivity**: `show managers` + `ping system <FMC_IP>`
2. **Check traffic hitting firewall**: `show interface <name>` counters; `capture` on interface
3. **Trace the packet**: `packet-tracer input <iface> tcp <src> <sport> <dst> <dport> detailed`
4. **Check ASP drops**: `show asp drop` -- look for acl-drop, snort-drop, no-route
5. **Check connections**: `show conn address <IP>` + `show xlate`
6. **Check routes**: `show route <dst>` + `show asp table routing`
7. **Check VPN**: `show crypto ikev2 sa` + `show crypto ipsec sa`
8. **Check Snort**: `show snort status` + `show asp drop | include snort`

## FMC REST API

**Base URL**: `https://<FMC>/api/fmc_config/v1/domain/<UUID>/`
**Auth**: POST to `/api/fmc_platform/v1/auth/generatetoken` with Basic auth
**Token**: Valid 30 min; refreshable 3 times
**Rate limits**: 120 req/min (pre-7.6); 300 req/min (7.6+)
**API Explorer**: `https://<FMC>/api/api-explorer/`
