# Juniper Junos Diagnostics Reference

## Routing Show Commands

```
show route                                # Full routing table (inet.0)
show route table inet.0                   # Explicit IPv4 unicast table
show route table inet6.0                  # IPv6 unicast table
show route table mpls.0                   # MPLS label table
show route 10.0.1.0/24 detail             # Detailed route entry
show route forwarding-table               # PFE forwarding table
show route summary                        # Route count per protocol

show bgp summary                          # BGP peer summary
show bgp neighbor 10.0.0.1               # Detailed BGP neighbor info
show bgp neighbor 10.0.0.1 received-routes  # Routes received from peer
show bgp neighbor 10.0.0.1 advertised-routes  # Routes advertised to peer
show route receive-protocol bgp 10.0.0.1  # BGP received routes in RIB

show ospf neighbor                        # OSPF neighbor table
show ospf database                        # Full OSPF LSDB
show ospf interface                       # OSPF-enabled interfaces
show ospf statistics                      # SPF calculation statistics
show ospf route                           # OSPF calculated routes

show isis adjacency                       # IS-IS adjacency table
show isis database                        # IS-IS LSDB
show isis interface                       # IS-IS enabled interfaces
show isis route                           # IS-IS calculated routes
show isis spf log                         # SPF computation history
```

## MPLS / VPN Show Commands

```
show mpls lsp                             # MPLS LSP summary
show mpls lsp name <lsp> detail           # Detailed LSP path info
show mpls lsp ingress                     # Ingress LSPs
show mpls lsp transit                     # Transit LSPs
show ldp session                          # LDP session table
show ldp neighbor                         # LDP neighbor discovery
show rsvp session                         # RSVP-TE sessions
show rsvp interface                       # RSVP-enabled interfaces

show route instance                       # All routing instances (VRFs)
show route instance <name> detail         # VRF details (RD, RT)
show route table <instance>.inet.0        # VRF routing table
show bgp summary instance <name>          # BGP within VRF
```

## EVPN-VXLAN Show Commands

```
show evpn database                        # EVPN MAC/IP database
show evpn instance                        # EVPN instance summary
show evpn ip-prefix-database              # Type-5 IP prefix routes
show ethernet-switching table             # L2 MAC address table
show ethernet-switching vxlan-tunnel-end-point remote  # Remote VTEPs
show interfaces vtep                      # VTEP interface status
```

## Interface Show Commands

```
show interfaces terse                     # All interfaces: status, addresses
show interfaces ge-0/0/0                  # Detailed interface counters
show interfaces ge-0/0/0 extensive        # Full counters including errors
show interfaces descriptions              # All interface descriptions
show interfaces diagnostics optics ge-0/0/0  # Transceiver optics (power, temp)
show lldp neighbors                       # LLDP neighbor discovery
show chassis mac-addresses                # System MAC addresses
```

## Commit and Configuration History

```
show system commit                        # Commit history (who, when, from where)
show configuration | compare rollback 1   # Diff active vs previous commit
show configuration | compare rollback 2   # Diff vs two commits ago
show configuration | display set          # Show config in set format
show configuration | display xml          # Show config in XML (NETCONF format)
show configuration | display json         # Show config in JSON
file show /config/juniper.conf            # Raw active config file
file show /var/db/config/juniper.conf.1   # Rollback 1 raw file
```

## System and Hardware

```
show version                              # Junos version, hostname, model, serial
show system uptime                        # System uptime and boot time
show chassis hardware                     # Hardware inventory (modules, serial numbers)
show chassis environment                  # Temperature, fans, power
show chassis alarms                       # Active chassis alarms
show chassis routing-engine               # RE CPU, memory, temperature
show chassis fpc                          # FPC (line card) status
show chassis fpc pic-status               # PIC status per FPC slot
show system processes extensive           # Running processes and CPU
show system storage                       # Disk usage
show system memory                        # Memory utilization
```

## Security (SRX-Specific)

```
show security flow session                # Active security sessions
show security policies                    # Security policy summary
show security zones                       # Security zone summary
show security nat source rule all         # Source NAT rules
show security ipsec sa                    # IPsec SA summary
show security alarms                      # Security alarms
```

## Log Analysis

```
show log messages                         # General system log
show log messages | match "error|warning" # Filter for errors/warnings
show log chassisd | last 50               # Last 50 chassis daemon messages
show log rpd | match "BGP"                # RPD log filtered for BGP events
show log interactive-commands             # CLI command audit log

# Real-time monitoring
monitor start messages                    # Tail system log
monitor start <logfile>                   # Tail specific log
monitor stop                              # Stop all monitors
```

## Network Testing

```
ping 10.0.0.1 count 5                    # ICMP ping
ping 10.0.0.1 source 10.0.0.2            # Ping from specific source
ping 10.0.0.1 routing-instance CUST-A    # Ping within VRF
traceroute 10.0.0.1                       # Traceroute
traceroute 10.0.0.1 source 10.0.0.2      # Traceroute from source
traceroute mpls ldp 10.0.0.1/32          # MPLS LSP traceroute
```

## NETCONF Debugging

```
show system connections | match 830       # Active NETCONF sessions
show system processes | match mgd         # Management daemon status

# Enable NETCONF tracing
set system services netconf traceoptions file netconf-trace
set system services netconf traceoptions flag all
show log netconf-trace                    # View NETCONF trace
```

## Operational Debugging (Use Sparingly)

```
# BGP debugging
monitor traffic interface ge-0/0/0 detail  # Packet capture on interface
set protocols bgp traceoptions file bgp-trace
set protocols bgp traceoptions flag update detail

# OSPF debugging
set protocols ospf traceoptions file ospf-trace
set protocols ospf traceoptions flag spf
set protocols ospf traceoptions flag hello detail

# IS-IS debugging
set protocols isis traceoptions file isis-trace
set protocols isis traceoptions flag spf
set protocols isis traceoptions flag adjacency

# Deactivate tracing when done
deactivate protocols bgp traceoptions
commit
```

Note: Junos uses `traceoptions` configured within the protocol hierarchy, not runtime debug commands. Tracing requires a `commit` to activate and `deactivate` + `commit` to stop. Always specify a trace file to avoid flooding the console.

## Request Commands

```
request system software add /var/tmp/<image>.tgz  # Install Junos image
request system reboot                     # Reboot system
request system snapshot                   # Snapshot to alternate media
request system configuration rescue save  # Save rescue configuration
request system zeroize                    # Factory reset (destructive)
clear bgp neighbor 10.0.0.1              # Reset BGP session
clear ospf neighbor all                   # Clear OSPF adjacencies
clear isis adjacency                      # Clear IS-IS adjacencies
```
