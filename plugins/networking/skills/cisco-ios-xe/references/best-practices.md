# IOS-XE Best Practices Reference

## Campus Design

### Traditional Three-Tier
- L3 distribution terminates VLANs; core is pure L3 routing
- Use Rapid PVST+ with distribution as STP root
- Deploy HSRP/VRRP at distribution for gateway redundancy
- Keep STP domain bounded per distribution block

### SD-Access Fabric
- Deployment stages: Discovery, Design, Policy, Provision, Assurance
- Border node types: Default (Internet), External (WAN/DC), Internal (fusion/other fabric)
- Requires Catalyst Center + DNA Advantage licensing

## Spanning Tree Configuration

```
spanning-tree mode rapid-pvst
spanning-tree vlan 1-1000 priority 4096          ! Primary root
spanning-tree portfast default                    ! Global PortFast
spanning-tree portfast bpduguard default          ! Global BPDU Guard
spanning-tree loopguard default                   ! Global Loop Guard
```

Root Guard on distribution uplinks: `spanning-tree guard root`

## FHRP Setup

```
interface Vlan100
  standby version 2
  standby 1 ip 10.100.0.1
  standby 1 priority 110
  standby 1 preempt delay minimum 30
  standby 1 authentication md5 key-string HSRP-KEY
  standby 1 track 1 decrement 20
```

Load-balance: Dist-1 active for even VLANs, Dist-2 for odd.

## Security Hardening

### Management Plane
```
no service finger
no service pad
no ip bootp server
no ip http server
ip http secure-server
line vty 0 15
  transport input ssh
  exec-timeout 10 0
  login local
  access-class MGMT-ACL in
ip ssh version 2
ip ssh dh-min-size 2048
```

### AAA
```
aaa new-model
aaa authentication login default group tacacs+ local
aaa authorization exec default group tacacs+ local if-authenticated
aaa accounting exec default start-stop group tacacs+
```

### Access Port Security
```
ip dhcp snooping
ip dhcp snooping vlan 100,200,300
ip arp inspection vlan 100,200,300

interface GigabitEthernet1/0/1
  switchport mode access
  switchport access vlan 100
  spanning-tree portfast
  spanning-tree bpduguard enable
  ip verify source
```

### Unused Ports
```
interface range GigabitEthernet1/0/25 - 48
  shutdown
  switchport mode access
  switchport access vlan 999
  description UNUSED-PORT
```

## Upgrade Procedures

### Pre-Upgrade Checklist
1. Review release notes and field notices
2. `show version` -- current version
3. `dir flash:` -- verify storage space
4. Backup config to TFTP/SCP
5. `show redundancy states` -- verify SSO state
6. `show switch` -- stack health (stacked switches)

### ISSU (Stacked Switches)
```
request platform software package install switch all file flash:<image>.bin
show install log detail
show install summary
install commit
```

### Post-Upgrade Verification
```
show version
show logging | include %SYS
show processes cpu sorted
show environment all
show interfaces summary
```
