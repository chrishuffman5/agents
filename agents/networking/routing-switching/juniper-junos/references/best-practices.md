# Juniper Junos Best Practices Reference

## Configuration Hierarchy Best Practices

### Use Hierarchy, Not Flat Set Commands

Junos configuration is a tree. Organize logically:
```
# Good: hierarchical grouping
edit interfaces ge-0/0/0
  set description "Uplink to core"
  set unit 0 family inet address 10.1.1.1/30
  set unit 0 family mpls
top

# Avoid: flat set commands for related config
set interfaces ge-0/0/0 description "Uplink to core"
set interfaces ge-0/0/0 unit 0 family inet address 10.1.1.1/30
set interfaces ge-0/0/0 unit 0 family mpls
```

### Apply Groups for Reusable Config

```
set groups LOOPBACK interfaces lo0 unit 0 family inet
set groups NTP system ntp server 10.0.0.100
set groups NTP system ntp server 10.0.0.101

apply-groups [LOOPBACK NTP]
```

Apply-groups reduce duplication. Changes to a group propagate to all devices using it.

### Configuration Comments

```
set interfaces ge-0/0/0 description "Uplink to core-sw01 ge-0/0/1"
annotate interfaces ge-0/0/0 "Ticket: NET-1234 - Provisioned 2024-01-15"
```

## Commit Safety

### Always Use `commit confirmed` for Remote Changes

```
commit confirmed 5                # 5-minute auto-rollback
# verify access is maintained
commit                            # confirm -- cancels auto-rollback
```

Rule: any change that could affect reachability (routing, interfaces, firewall filters, management access) should use `commit confirmed`.

### Commit Comment for Audit Trail

```
commit comment "NET-1234: Added BGP peer 10.0.0.2 for Transit-B"
```

Visible in `show system commit` for change tracking.

### Pre-Commit Validation

```
show | compare                    # review all pending changes
commit check                     # validate syntax and semantics
commit confirmed 5               # activate with safety net
```

### Rescue Configuration

```
request system configuration rescue save   # save current config as rescue
request system configuration rescue delete # remove rescue config

# Recovery: boot into rescue config from CLI or console
```

Save rescue config after every stable, validated state change.

## Routing Best Practices

### BGP

- Always set explicit `local-address` for iBGP sessions (use loopback)
- Use route reflectors to avoid full mesh in iBGP (>5 peers)
- Apply import/export policies to every BGP group -- Junos requires explicit policy for route advertisement
- Enable BFD for fast failure detection: `set protocols bgp group <name> bfd-liveness-detection minimum-interval 300`
- Use authentication: `set protocols bgp group <name> authentication-key <secret>`
- Set prefix limits to protect against route leaks: `set protocols bgp group EXTERNAL family inet unicast prefix-limit maximum 10000 teardown 80 idle-timeout 30`

### IS-IS (Data Center Underlay)

- Use level 2 only for flat DC fabrics (no area hierarchy needed)
- Enable `wide-metrics-only` -- classic metrics limited to 63, insufficient for modern designs
- Use point-to-point network type on all fabric links: `set protocols isis interface ge-0/0/0.0 point-to-point`
- Set appropriate metric: `set protocols isis interface ge-0/0/0.0 level 2 metric 10`
- Passive on loopback: `set protocols isis interface lo0.0 passive`

### OSPF

- Use point-to-point on all point-to-point links to avoid DR/BDR election overhead
- Stub/NSSA areas to limit LSA flooding at network edges
- Reference bandwidth tuning for modern link speeds: `set protocols ospf reference-bandwidth 100g`

## MPLS Best Practices

- Enable MPLS explicitly on every MPLS interface: `set protocols mpls interface ge-0/0/0.0`
- Use RSVP-TE with FRR (facility backup) for sub-50ms convergence
- For Segment Routing deployments, allocate a consistent SRGB across all devices
- Enable penultimate hop popping (default) for optimal forwarding

## EVPN-VXLAN Fabric Design

### Underlay Design

- Use eBGP (ASN-per-leaf or ASN-per-rack) or IS-IS for underlay routing
- Point-to-point /31 links between leaf and spine
- MTU 9216 on all fabric links (VXLAN adds 50+ bytes overhead)
- BFD on all underlay BGP/IS-IS sessions for fast failure detection

### Overlay Design

- Use iBGP with route reflectors (spines as RR) for EVPN overlay
- ERB model (distributed L3 gateway) for optimal east-west traffic
- Anycast gateway: same IRB IP/MAC on all leaves for seamless VM mobility
- Use VLAN-aware mode for operational simplicity (Apstra default)

### Apstra Fabric Design

- **Resource pools**: pre-allocate ASN, IP, VNI pools before blueprint creation
- **Property sets**: define reusable configuration blocks (NTP, DNS, syslog) as property sets
- **Anomaly monitoring**: configure Apstra probes for BGP, EVPN, interface, and hardware monitoring
- **Change management**: use blueprint diff views for all config changes before deploying
- **Multi-vendor**: test interoperability probes when mixing Junos with EOS/NX-OS/SONiC

## Mist Integration Best Practices

### Zero-Touch Provisioning

- Pre-register switch serial numbers in Mist organization before powering on
- Configure DHCP option 43 or DNS SRV record for Mist cloud redirect
- Use site-level templates for consistent configuration across all switches in a site

### Wired Assurance

- Enable LLDP on all access ports for device profiling
- Configure SLE (Service Level Expectation) baselines per site
- Use Marvis Actions for automated remediation (port bounce, VLAN correction)
- Dynamic port profiles: define profiles for IP phones, APs, printers, and let Mist auto-assign

## Security Hardening

### Management Access

```
set system services ssh protocol-version v2
set system services ssh root-login deny
set system services ssh max-sessions-per-connection 5
set system login retry-options tries-before-disconnect 3
delete system services telnet
```

### Firewall Filters for RE Protection (Loopback Filter)

```
set firewall family inet filter PROTECT-RE term ALLOW-SSH from source-prefix-list MGMT-NETS
set firewall family inet filter PROTECT-RE term ALLOW-SSH from protocol tcp
set firewall family inet filter PROTECT-RE term ALLOW-SSH from destination-port ssh
set firewall family inet filter PROTECT-RE term ALLOW-SSH then accept

set firewall family inet filter PROTECT-RE term ALLOW-BGP from protocol tcp
set firewall family inet filter PROTECT-RE term ALLOW-BGP from destination-port bgp
set firewall family inet filter PROTECT-RE term ALLOW-BGP then accept

set firewall family inet filter PROTECT-RE term ALLOW-OSPF from protocol ospf
set firewall family inet filter PROTECT-RE term ALLOW-OSPF then accept

set firewall family inet filter PROTECT-RE term ALLOW-ICMP from protocol icmp
set firewall family inet filter PROTECT-RE term ALLOW-ICMP then accept

set firewall family inet filter PROTECT-RE term DEFAULT-DENY then discard

set interfaces lo0 unit 0 family inet filter input PROTECT-RE
```

### SNMP

```
set snmp v3 usm local-engine user MONITOR authentication-sha authentication-key <key>
set snmp v3 usm local-engine user MONITOR privacy-aes128 privacy-key <key>
set snmp v3 vacm access group MONITOR-GROUP default-context-prefix read-view ALL
```

Always use SNMPv3 with authentication and encryption. Avoid v1/v2c in production.

### AAA with TACACS+

```
set system authentication-order [tacplus password]
set system tacplus-server 10.0.0.50 secret <secret>
set system tacplus-server 10.0.0.50 timeout 5
set system login user LOCAL-ADMIN class super-user authentication encrypted-password "<hash>"
```

### Syslog

```
set system syslog host 10.0.0.100 any notice
set system syslog host 10.0.0.100 authorization info
set system syslog host 10.0.0.100 interactive-commands any
set system syslog file messages any notice
set system syslog file interactive-commands interactive-commands any
```

## Upgrade Procedures

### Pre-Upgrade Checklist

1. `show version` -- current version and model
2. `show chassis hardware` -- inventory for compatibility check
3. `show system storage` -- verify sufficient disk space
4. `request system configuration rescue save` -- save rescue config
5. `show system snapshot media internal` -- current snapshot state
6. Review release notes for target version

### Upgrade Steps

```
# Copy image
file copy scp://user@server/path/junos-image.tgz /var/tmp/

# Validate package
request system software validate /var/tmp/junos-image.tgz

# Install (requires reboot)
request system software add /var/tmp/junos-image.tgz

# Reboot
request system reboot
```

### Post-Upgrade Validation

```
show version                              # Confirm target version
show chassis alarms                       # No unexpected alarms
show bgp summary                          # BGP sessions established
show ospf neighbor                        # OSPF adjacencies up
show isis adjacency                       # IS-IS adjacencies up
show interfaces terse | match down        # No unexpected interface downs
show system processes extensive           # No crashed processes
```

### Dual RE Upgrade

```
# Upgrade backup RE first
request system software add /var/tmp/junos-image.tgz re1

# Reboot backup RE
request system reboot slice alternate media internal

# After backup RE boots on new version, switchover
request chassis routing-engine master switch

# Upgrade original RE
request system software add /var/tmp/junos-image.tgz re0
request system reboot slice alternate media internal
```
