# Arista EOS Diagnostics Reference

## Interfaces

```
show interfaces status                     # Summary: speed, duplex, link state
show interfaces Ethernet1                  # Detailed counters and errors
show interfaces counters                   # Tx/Rx packet/byte/error counts
show interfaces counters rates             # Per-interface bandwidth utilization
show ip interface brief                    # IP address + link state
show lldp neighbors detail                 # LLDP neighbor discovery
show port-channel summary                  # LAG summary (LACP state)
show port-channel detail                   # Detailed LACP negotiation
```

## Routing

```
show ip route                              # Full IPv4 routing table
show ip route bgp                          # BGP-learned routes
show ip route ospf                         # OSPF-learned routes
show ip route vrf TENANT                   # VRF-specific routes
show ip route summary                      # Route count per protocol
show ip bgp summary                        # BGP peer summary
show bgp summary                           # All-AF BGP summary
show bgp neighbors 10.0.0.1               # Detailed peer info
show bgp neighbors 10.0.0.1 advertised-routes
show bgp neighbors 10.0.0.1 received-routes
show ip ospf neighbor                      # OSPF neighbors
show ip ospf database                      # OSPF LSDB
show ip arp                                # ARP table
```

## VXLAN and EVPN

```
show vxlan config-sanity                   # Config consistency check
show vxlan config-sanity detail            # Includes MLAG peer comparison
show interfaces Vxlan1                     # VXLAN interface state
show vxlan address-table                   # VTEP MAC/IP table
show vxlan address-table evpn              # EVPN-learned remote MACs
show vxlan flood vtep                      # Head-end replication VTEPs
show vxlan vni                             # VNI-to-VLAN mapping
show bgp evpn summary                      # EVPN peer summary
show bgp evpn route-type mac-ip            # Type-2 routes
show bgp evpn route-type imet              # Type-3 routes
show bgp evpn route-type ip-prefix         # Type-5 routes
show bgp evpn route-type ethernet-segment  # Type-4 ESI routes
show arp suppression-cache                 # EVPN ARP suppression
```

## MLAG

```
show mlag                                  # Domain state, peer health
show mlag detail                           # Full config and state
show mlag interfaces                       # All MLAG interface IDs
show mlag config-sanity                    # Config consistency check
show mlag peers                            # Peer-link and keepalive state
```

## Security

```
show ip access-lists                       # All ACLs with hit counters
show mac address-table                     # L2 MAC table
show mac address-table dynamic             # Dynamic MACs only
show mac security                          # MACsec session state
show tacacs                                # TACACS+ server state
show sflow                                 # sFlow config and stats
```

## System

```
show version                               # EOS version, model, uptime
show running-config                        # Active configuration
show diff running-config startup-config    # Unsaved changes
show processes top                         # CPU/memory per process
show environment all                       # Temperature, fans, power
show management api http-commands          # eAPI service status
show management api gnmi                   # gNMI server status
```

## eAPI Diagnostic Query

```bash
curl -s -k -u admin:password \
  -H "Content-Type: application/json" \
  -X POST https://192.0.2.1/command-api \
  -d '{"jsonrpc":"2.0","method":"runCmds","params":{"version":1,"cmds":["show mlag","show bgp evpn summary","show vxlan config-sanity"],"format":"json"},"id":"1"}'
```

## On-Box Troubleshooting

```
switch# bash
[admin@switch ~]$ tcpdump -i et1 -n        # Packet capture on interface
[admin@switch ~]$ ip route show vrf TENANT  # Linux routing table for VRF
[admin@switch ~]$ ip link show              # Linux interface state
```
