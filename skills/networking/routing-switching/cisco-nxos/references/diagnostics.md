# NX-OS Diagnostics Reference

## Routing

```
show ip route                              # Full routing table
show ip route vrf TENANT-A                 # VRF routing table
show ip route summary                      # Route count per protocol
show ip cef                                # CEF FIB table

show bgp summary                           # BGP peer summary
show bgp ipv4 unicast neighbors            # BGP neighbor details
show bgp l2vpn evpn summary               # EVPN BGP summary
show bgp l2vpn evpn                        # Full EVPN table
show bgp l2vpn evpn route-type 2           # MAC/IP routes
show bgp l2vpn evpn route-type 5           # IP prefix routes

show ip ospf neighbors                     # OSPF neighbor table
show ip ospf database                      # Full LSDB
show ip ospf interface brief               # OSPF interfaces
```

## VXLAN / NVE

```
show nve peers                             # NVE peer list and state
show nve peers detail                      # Detailed peer info
show nve interface nve1                    # NVE interface state
show nve interface nve1 detail             # NVE detailed config
show nve vni                               # VNI-to-VLAN mapping
show nve vni 10100 detail                  # Specific VNI details
```

## EVPN

```
show evpn evi                              # EVPN instances
show evpn evi vni 10100 detail             # Specific EVI
show evpn mac evi 10100                    # MAC table for EVI
show evpn mac ip evi 10100                 # MAC+IP bindings
show mac address-table vni 10100           # MAC table by VNI
show ip arp suppression-cache detail       # ARP suppression cache
```

## vPC

```
show vpc                                   # Overall vPC status
show vpc brief                             # Compact vPC summary
show vpc consistency-parameters global     # Config consistency check
show vpc consistency-parameters interface po10  # Per-interface consistency
show vpc peer-keepalive                    # Keepalive state
show vpc role                              # Primary/secondary role
show vpc orphan-ports                      # Ports only on one peer
```

## Layer 2

```
show vlan brief                            # VLAN summary
show spanning-tree vlan 100                # STP state for VLAN
show spanning-tree summary                 # STP summary
show spanning-tree inconsistentports       # STP violations
show mac address-table dynamic             # Dynamic MACs
show mac address-table count               # MAC table utilization
show port-channel summary                  # Port-channel/LACP summary
show lacp neighbor                         # LACP partner info
```

## Interfaces

```
show interface brief                       # Compact interface summary
show interface Ethernet1/1                 # Detailed counters
show interface counters errors             # Error counters
show interface status                      # Speed/duplex/status
show interface trunk                       # Trunk ports and VLANs
show ip interface brief                    # IP address summary
```

## Platform and Hardware

```
show version                               # Software version, uptime
show module                                # Line card status
show system resources                      # CPU, memory, disk
show processes cpu sorted                  # Top CPU consumers
show environment                           # Power, fans, temperature
show hardware capacity                     # Hardware resource utilization
show hardware access-list resource utilization  # TCAM usage
```

## Checkpoint and Rollback

```
checkpoint BEFORE-CHANGE                   # Create checkpoint
show checkpoint summary                    # List checkpoints
show diff rollback-patch checkpoint BEFORE-CHANGE running-config  # Preview changes
rollback running-config checkpoint BEFORE-CHANGE atomic           # Rollback (all-or-nothing)
```

## NX-API Examples

```bash
# NX-API CLI: show version
curl -s -X POST -H "Content-Type: application/json" -u admin:pass \
  https://10.0.0.1/ins \
  -d '{"ins_api":{"version":"1.0","type":"cli_show","chunk":"0","sid":"1","input":"show version","output_format":"json"}}'

# NX-API REST: Get VLANs
curl -s -u admin:pass "https://10.0.0.1/api/mo/sys/bd.json?rsp-subtree=children"

# NX-API REST: Get BGP peers
curl -s -u admin:pass "https://10.0.0.1/api/mo/sys/bgp/inst/dom-default/peer.json"
```
