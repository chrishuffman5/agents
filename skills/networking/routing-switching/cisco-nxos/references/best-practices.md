# NX-OS Best Practices Reference

## DC Fabric Design: Spine-Leaf

### Topology
- Spine: pure L3, no VLANs, no VXLAN encap; BGP Route Reflectors for EVPN
- Leaf: VTEP, L2 services toward servers, anycast gateway, BGP EVPN peer to spines
- Underlay: IS-IS preferred (scale, fast convergence) or OSPF

### IS-IS Underlay Pattern

```
feature isis
router isis UNDERLAY
  net 49.0001.0000.0000.0001.00
  is-type level-2
  address-family ipv4 unicast
    bfd

interface Ethernet1/1
  no switchport
  ip address 10.0.0.0/31
  ip router isis UNDERLAY
  isis network point-to-point
  bfd interval 300 min_rx 300 multiplier 3
```

### BGP Route Reflector on Spine

```
router bgp 65001
  template peer LEAF-TEMPLATE
    remote-as 65001
    update-source loopback0
    address-family l2vpn evpn
      send-community extended
      route-reflector-client
  neighbor 10.0.0.1
    inherit peer LEAF-TEMPLATE
```

## vPC Configuration

```
feature vpc
vpc domain 10
  peer-keepalive destination 192.168.1.2 source 192.168.1.1 vrf management
  peer-gateway
  layer3 peer-router
  auto-recovery reload-delay 300
  delay restore 150
  ip arp synchronize

interface port-channel 100
  switchport mode trunk
  spanning-tree port type network
  vpc peer-link
```

### vPC Best Practices

| Practice | Rationale |
|---|---|
| Dedicated management keepalive | Prevents false peer-failure detection |
| Enable `peer-gateway` | Allows routing through peer MAC |
| Enable `auto-recovery` | Restores vPC if peer unreachable after reload |
| Set `delay restore 150` | Prevents routing black-holes during reload |
| Match STP priorities | vPC peer-switch presents one STP identity |
| Keep peer-link >= 40G total | Avoids congestion during split-brain |
| Synchronize NTP | Consistent timestamps for troubleshooting |

## ECMP

```
router bgp 65001
  address-family ipv4 unicast
    maximum-paths 64
    maximum-paths ibgp 64
```

NX-OS uses 5-tuple hashing. VXLAN outer src UDP port varies per inner flow for entropy.

## Security Hardening

```
no feature telnet
feature ssh
ssh key rsa 2048

ip access-list MGMT-ACCESS
  permit tcp 10.0.0.0/24 any eq 22
  permit tcp 10.0.0.0/24 any eq 443
  deny ip any any log

interface mgmt0
  ip access-group MGMT-ACCESS in

aaa authentication login default group tacacs+ local
```

CoPP is enabled by default on Nexus 9000. Verify with `show policy-map system type control-plane`.

## Upgrade Procedures

### Pre-Upgrade
```
checkpoint PRE-UPGRADE
copy running-config scp://server/backups/hostname-pre.cfg
show incompatibility nxos bootflash:nxos64-cs.10.5.5.M.bin
show install all impact nxos bootflash:nxos64-cs.10.5.5.M.bin
```

### ISSU
```
install all nxos bootflash:nxos64-cs.10.5.5.M.bin
show install all status
```

### vPC Upgrade Sequence
1. Upgrade secondary vPC peer
2. Verify vPC re-establishes (`show vpc`)
3. Upgrade primary vPC peer
4. Post-upgrade verification on both peers

### Post-Upgrade Verification
```
show version
show module
show vpc
show bgp summary
show nve peers
show spanning-tree summary
```

## Monitoring Thresholds

| Metric | Command | Threshold |
|---|---|---|
| CPU | `show processes cpu sorted` | <70% sustained |
| Memory | `show system resources` | <80% used |
| BGP peers | `show bgp summary` | All Established |
| NVE peers | `show nve peers` | All Up |
| Interface errors | `show interface counters errors` | Zero or minimal |
| vPC consistency | `show vpc consistency-parameters global` | All Pass |
