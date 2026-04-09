# FortiOS Diagnostics Reference

## System Information
```
get system status                       # Firmware version, serial, license
get system performance status           # CPU, memory, sessions real-time
diagnose sys top                        # Live process list
diagnose sys top-mem                    # Memory usage by process
diagnose hardware sysinfo memory        # RAM details
```

## Session Inspection
```
diagnose sys session list               # All sessions (large output)
diagnose sys session filter src <IP>    # Set filter by source
diagnose sys session filter dst <IP>    # Set filter by destination
diagnose sys session filter dport <port>
diagnose sys session filter clear       # Clear all filters
diagnose sys session stat               # Session statistics
```

## Flow Debug (Packet Tracing)
```
# Set flow debug filter
diagnose debug flow filter addr <IP>
diagnose debug flow filter daddr <IP>
diagnose debug flow filter port <port>

# Enable console output and trace
diagnose debug flow show console enable
diagnose debug flow trace start <count>    # Trace N packets

# Stop tracing
diagnose debug flow trace stop
diagnose debug disable
diagnose debug flow filter clear
```

Flow debug output shows: policy match, NAT, routing decision, session creation, and forward/drop action for each packet.

## Packet Capture (Sniffer)
```
# Syntax: diagnose sniffer packet <iface> '<filter>' <verbosity> <count> <timestamp>
# Verbosity: 1=headers, 2=+hex, 3=+hex+ether, 4=+interface, 5=+hex+interface, 6=full
diagnose sniffer packet port1 'host 10.1.1.1' 4 100 l
diagnose sniffer packet any 'host 10.1.1.1 and port 443' 4 100 l
diagnose sniffer packet any 'udp port 500 or udp port 4500' 4 50 l
```

## Routing
```
get router info routing-table all       # Full routing table
get router info routing-table details <IP>  # Route for specific destination
diagnose ip route list                  # Kernel route table
diagnose netlink route list             # Low-level routes
get router info bgp summary            # BGP neighbor summary
get router info bgp neighbors          # BGP neighbor detail
get router info ospf neighbor          # OSPF neighbors
```

## Interface
```
get system interface physical           # Physical interface status
diagnose hardware deviceinfo nic <iface>  # NIC hardware details
diagnose netlink interface list         # Interface statistics
```

## VPN
```
diagnose vpn tunnel list               # Active IPsec tunnels
diagnose vpn ike gateway list          # IKE gateways
get vpn ipsec tunnel details           # Tunnel detail with counters

# IKE Debug
diagnose vpn ike log filter rem-addr4 <peer-IP>
diagnose debug application ike -1      # Enable IKE debug
diagnose debug console timestamp enable
diagnose debug enable

# Tunnel operations
execute vpn ipsec tunnel up <phase2-name>
execute vpn ipsec tunnel down <phase2-name>

# Traffic capture on VPN ports
diagnose sniffer packet any "udp port 500" 4
diagnose sniffer packet any "udp port 4500" 4
```

## High Availability
```
get system ha status                   # Simple HA state
diagnose sys ha status                 # Detailed HA cluster status
diagnose sys ha dump-by-vcluster       # Per-VDOM HA info
diagnose sys ha checksum show          # Config checksum comparison
```

## NP Hardware Offload
```
diagnose npu np7 session list          # NP7 offloaded sessions
diagnose npu np6 session list          # NP6 offloaded sessions
diagnose npu np7 port-list            # NP7 port mapping
```

## SD-WAN
```
diagnose sys sdwan health-check status # SLA health check results
diagnose sys sdwan member             # SD-WAN member details
diagnose sys sdwan service            # SD-WAN service rule matches
diagnose sys sdwan intf-sla-log <member-id>  # SLA history
```

## Configuration Management
```
show full-configuration               # Full running config
get <context>                          # Non-default settings only
show <context>                         # All settings including defaults

# Backup
execute backup config tftp <file> <server>
execute backup config scp <file> <server> <user>

# Restore
execute restore config tftp <file> <server>
execute factoryreset                   # Factory reset (destructive!)
```

## Troubleshooting Workflow

1. **Identify the traffic**: Source, destination, port, protocol
2. **Set session filter**: `diagnose sys session filter src <IP>` then `diagnose sys session list`
3. **Flow debug**: Set filter, enable flow trace -- shows policy match, NAT, routing
4. **Sniffer**: Capture on ingress and egress interfaces to verify packet presence
5. **Check offload**: `diagnose npu np7 session list` -- is session offloaded?
6. **Routing**: `get router info routing-table details <IP>` -- correct egress?
7. **HA**: `diagnose sys ha status` -- is this the active unit?
8. **VPN**: `diagnose vpn tunnel list` -- is tunnel up? Check selectors.
