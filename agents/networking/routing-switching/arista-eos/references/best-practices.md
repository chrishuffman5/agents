# Arista EOS Best Practices Reference

## Spine-Leaf Fabric Design

### Standard 2-Tier
- Spine: pure L3 IP fabric, no VLANs; BGP Route Reflectors (or eBGP pass-through)
- Leaf: VTEP, server-facing L2, anycast gateway SVIs
- MLAG pairs share VTEP IP for active-active redundancy
- Oversubscription: 3:1 typical; 1:1 for GPU/HPC

### eBGP Underlay (Recommended)
- Unique ASN per leaf pair (65101, 65102, etc.); shared spine ASN (65100)
- Point-to-point /31 links between leaf and spine
- `maximum-paths 4 ecmp 4` for multi-path load balancing
- BFD on all BGP sessions for sub-second failover

### eBGP Overlay (EVPN)
- Loopback-to-loopback eBGP multihop for EVPN
- `ebgp-multihop 3` to account for MLAG peer-link path
- `send-community extended` required for Route Target

## VNI Allocation Convention

```
VLAN 100 --> VNI 10100 (L2 VNI)
VLAN 200 --> VNI 10200 (L2 VNI)
VRF TENANT-A --> VNI 50001 (L3 VNI)
VRF TENANT-B --> VNI 50002 (L3 VNI)
```

## MTU

| Link Type | MTU |
|---|---|
| Leaf-spine uplinks | 9214 |
| MLAG peer-link | 9214 |
| Server-facing | 9000 or 1500 (match server NIC) |
| Management | 1500 |

## BFD

```
router bgp 65101
   neighbor SPINE bfd
router bfd
   interval 100 min-rx 100 multiplier 3        # 300ms detection
   multihop interval 300 min-rx 300 multiplier 3
```

## MLAG Configuration

```
mlag configuration
   domain-id DC1-LEAFPAIR1
   local-interface Vlan4094
   peer-address 10.255.252.1
   peer-link Port-Channel1
   peer-address heartbeat 192.168.1.2 vrf default
   reload-delay mlag 300
   reload-delay non-mlag 330
```

### MLAG Checklist
- Domain-id identical on both peers
- Peer-link is port-channel (not single link)
- Loopback1 (VTEP) identical on both peers
- reload-delay configured
- Peer-keepalive via management network
- `show mlag config-sanity` passes

## Management Network

```
vrf instance management
interface Management1
   vrf management
   ip address 192.168.0.11/24
ip route vrf management 0.0.0.0/0 192.168.0.1

management ssh
   vrf management
management api http-commands
   protocol https
   no shutdown
   vrf management
      no shutdown
```

### Hardening
- Disable Telnet: `management telnet` + `shutdown`
- SSH modern ciphers: `cipher aes128-ctr aes256-ctr`
- Restrict SNMP to SNMPv3
- NTP via management VRF

## AVD Deployment

1. Define fabric intent in YAML (topology, ASNs, VRFs, VLANs)
2. `eos_designs` generates per-device data model
3. `eos_cli_config_gen` renders EOS CLI configs
4. `cv_deploy` pushes to CVaaS (or `eos_config_deploy_eapi` direct)
5. `eos_validate_state` post-deployment validation

Key AVD settings:
```yaml
p2p_uplinks_mtu: 9214
bgp_peer_groups:
  evpn_overlay_peers:
    bfd: true
    ebgp_multihop: 3
bfd_multihop:
  interval: 300
  min_rx: 300
  multiplier: 3
spanning_tree_mode: mstp
spanning_tree_priority: 4096
```

## CloudVision Upgrade Workflow

1. Upload EOS image to CVP image repository
2. Create Image Bundle (image + extensions)
3. Assign to container or device
4. Create Change Control (series execution for MLAG pairs)
5. CVP upgrades first MLAG peer, traffic fails to second
6. After first peer up, CVP upgrades second peer
7. Validate: `show version`, `show mlag detail`, `show bgp evpn summary`

## Design Checklist

- MTU 9214 on all fabric and peer-link interfaces
- BFD on all BGP sessions
- OOB management VRF configured
- NTP synchronized
- TACACS+/RADIUS configured
- sFlow or streaming telemetry enabled
- `no bgp default ipv4-unicast`
- `send-community extended` on EVPN peers
- `maximum-paths` set for ECMP
- RT import/export consistent across VTEPs
- `redistribute learned` under each vlan in BGP
