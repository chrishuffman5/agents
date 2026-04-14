# IOS-XE Diagnostics Reference

## Routing Show Commands

```
show ip route                              # Full routing table
show ip route vrf TENANT-A                 # VRF routing table
show ip route summary                      # Route count per protocol
show ip route bgp                          # BGP routes only
show ip route ospf                         # OSPF routes only
show ip cef 10.0.1.1                       # CEF adjacency lookup
show ip cef detail                         # Full CEF FIB table

show bgp summary                           # BGP peer summary (17.x preferred)
show bgp ipv4 unicast neighbors 10.0.0.1   # Detailed neighbor info
show bgp l2vpn evpn summary               # EVPN BGP summary
show bgp l2vpn evpn route-type 2          # Type-2 MAC/IP routes

show ip ospf neighbor                      # OSPF neighbor table
show ip ospf database                      # Full LSDB
show ip ospf interface brief               # OSPF-enabled interfaces
show ip ospf statistics                    # SPF calculation stats
```

## Interface Show Commands

```
show interfaces status                     # All ports: speed/duplex/VLAN
show ip interface brief                    # IP address + line/protocol
show interfaces trunk                      # Trunk ports and allowed VLANs
show interfaces GigabitEthernet1/0/1       # Detailed counters/errors
show interfaces counters errors            # Error counters all interfaces
show interfaces summary                    # Compact traffic summary
```

## Layer 2 Show Commands

```
show vlan brief                            # VLAN summary
show spanning-tree vlan 100                # STP state for VLAN
show spanning-tree summary                 # Per-VLAN STP state summary
show spanning-tree inconsistentports       # Root/BPDU guard violations
show mac address-table dynamic             # Dynamically learned MACs
show mac address-table count               # MAC table utilization
show cdp neighbors detail                  # CDP neighbor discovery
show lldp neighbors detail                 # LLDP neighbor discovery
```

## Security Show Commands

```
show access-lists                          # All ACLs with hit counts
show port-security                         # Port security summary
show ip dhcp snooping binding              # DHCP snooping bindings
show ip arp inspection statistics          # DAI statistics
show policy-map control-plane              # CoPP policy status
```

## Platform and Hardware

```
show version                               # Software version, uptime, serial
show platform                              # Platform-specific hardware state
show platform resources                    # CPU, memory, TCAM utilization
show platform tcam utilization             # TCAM usage per feature
show sdm prefer                            # SDM template (TCAM allocation)
show processes cpu sorted                  # Top CPU consumers
show processes cpu history                 # CPU history graph
show environment all                       # Temperature, fans, power
show switch                                # StackWise member status
show redundancy states                     # Redundancy/SSO state
```

## FHRP Show Commands

```
show standby                               # HSRP state (all interfaces)
show standby brief                         # HSRP summary table
show vrrp brief                            # VRRP summary
```

## VXLAN/NVE (Campus EVPN)

```
show nve peers                             # NVE VXLAN peers
show nve interface nve1                    # NVE interface state
show bgp l2vpn evpn summary               # EVPN BGP summary
```

## Programmability Verification

```
show netconf-yang sessions                 # Active NETCONF sessions
show netconf-yang statistics               # NETCONF request/response stats
show platform software yang-management process  # YANG process state
show telemetry ietf subscription all       # Active telemetry subscriptions
```

## Debug (Use Sparingly in Production)

```
debug spanning-tree events                 # STP topology changes
debug ip ospf adj                          # OSPF adjacency formation
debug ip bgp updates                       # BGP update processing
```

Always set `debug condition` filters before enabling debug on production devices.

## NETCONF Example: Get Interface Config

```xml
<rpc message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <get-config>
    <source><running/></source>
    <filter type="subtree">
      <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
        <interface><GigabitEthernet/></interface>
      </native>
    </filter>
  </get-config>
</rpc>
```

## RESTCONF Example: Get BGP Summary

```bash
curl -s -u admin:password \
  -H "Accept: application/yang-data+json" \
  "https://192.168.1.1/restconf/data/Cisco-IOS-XE-bgp-oper:bgp-state-data/neighbors"
```
