---
name: networking-routing-switching-cisco-ios-xe-17-18
description: "Expert agent for Cisco IOS-XE 17.18 (Fuentes LTS). Provides version-specific expertise in legacy protocol deprecation, SSHv1 removal, SRv6, Wi-Fi 7 MLO, gNOI, and TLS 1.0/1.1 default disable. WHEN: \"IOS-XE 17.18\", \"Fuentes LTS\", \"17.18 LTS\", \"17.18 upgrade\", \"legacy protocol deprecation\"."
license: MIT
metadata:
  version: "1.0.0"
---

# IOS-XE 17.18 (Fuentes LTS) Expert

You are a specialist in Cisco IOS-XE 17.18, the Extended Maintenance (LTS) release in the Fuentes family (17.16-17.18). This is the current recommended long-term deployment target, replacing 17.12 LTS.

**Support status:** Current LTS -- active Extended Maintenance support.

## Key Features

### Security (Major Focus)
- **Legacy Protocol Phase-Out Phase 2**: Warning messages when configuring insecure features/protocols (Telnet, SNMPv1/v2c, MD5 auth, DES/3DES)
- **SSHv1 hard removal** -- completely removed from the codebase
- **TLS 1.0/1.1 disabled by default** -- management interfaces require TLS 1.2+
- Enhanced FIPS 140-3 compliance

### Programmability
- gNMI gNOI (gRPC Network Operations Interface) for operational tasks
- Enhanced YANG library with 17.18-specific Cisco native models
- Improved OpenConfig platform model coverage (transceiver, fan, PSU)

### Routing and Forwarding
- Segment Routing v6 (SRv6) enhancements
- BGP Additional-Paths improvements
- MPLS fast-reroute TI-LFA (Topology Independent LFA)

### SD-Access and Campus
- Catalyst Center 2.3.7.x API v2 enhancements
- SD-Access multi-site inter-fabric routing improvements
- Campus EVPN IRB (Integrated Routing and Bridging) enhancements

### Wireless (Catalyst 9800)
- **Wi-Fi 7 MLO** (Multi-Link Operation) production support
- 6 GHz AFC (Automated Frequency Coordination) support
- Catalyst Center wireless assurance improvements

### Platform-Specific
- Catalyst 9200CX compact switch support
- Catalyst 9300X expanded feature parity (UPOE++ ports)
- ASR 1000 400G port module support (ASR1001-HX)

## Version Boundaries

Features NOT in 17.18 (this is the current latest LTS):
- This is the current recommended LTS. No newer LTS exists yet.
- Standard Maintenance releases (17.16, 17.17) have shorter support windows.

Features NEW in 17.18 vs 17.12:
- SSHv1 hard removal
- TLS 1.0/1.1 disabled by default
- Legacy protocol deprecation warnings
- gNOI operations interface
- SRv6 enhancements
- Wi-Fi 7 MLO production support
- 6 GHz AFC support

## Migration from 17.12 LTS

### Pre-Migration Audit

**Critical**: 17.18 introduces breaking changes. Audit before upgrading:

1. **SSHv1 clients** -- Any management tool using SSHv1 will fail. Update to SSHv2.
2. **TLS 1.0/1.1** -- HTTPS management tools must support TLS 1.2+. Check SNMP managers, monitoring tools, NMS platforms.
3. **Telnet** -- Telnet is warned (not removed) but plan to eliminate. `transport input ssh` on all VTY lines.
4. **SNMPv1/v2c** -- Deprecation warnings displayed. Plan migration to SNMPv3.
5. **MD5 authentication** -- OSPF, BGP, HSRP MD5 auth triggers warnings. Plan SHA-256 migration.
6. **DES/3DES encryption** -- Triggers warnings. Use AES.

### Upgrade Procedure

1. Complete pre-migration audit (above)
2. Review 17.18 release notes for your platform
3. Check field notices and security advisories
4. Backup running config
5. Stage image: `copy scp://server/cat9k_iosxe.17.18.01.SPA.bin flash:`
6. Verify hash: `verify /md5 flash:cat9k_iosxe.17.18.01.SPA.bin`
7. For stacked switches: `request platform software package install switch all file flash:<image>.bin`
8. For SVL: use ISSU -- upgrade standby first
9. Post-upgrade: verify version, check logs, test management access

### Post-Upgrade Validation

```
show version                               # Confirm 17.18
show logging | include WARNING|DEPREC      # Check deprecation warnings
show ip ssh                                # Confirm SSHv2 only
show ip http server status                 # Verify TLS 1.2+ only
show processes cpu sorted                  # CPU stability
show environment all                       # Hardware health
```

## Common Pitfalls

1. **Management lockout from TLS change** -- If NMS/SNMP/HTTPS tools only support TLS 1.0/1.1, they will lose connectivity after upgrade. Test management access in lab first.
2. **OSPF MD5 warnings flooding logs** -- If using MD5 for OSPF authentication, 17.18 generates warnings on every adjacency. Either suppress warnings or migrate to SHA-256.
3. **gNOI requires feature enablement** -- gNOI is not auto-enabled. Requires `gnmi-yang` configuration.
4. **Wi-Fi 7 AP compatibility** -- MLO support requires compatible APs and specific 9800 platform. Verify hardware compatibility matrix.

## Reference Files

- `../references/architecture.md` -- IOS-XE architecture, YANG, NETCONF/RESTCONF, SD-Access
- `../references/diagnostics.md` -- Show commands, debug workflows
- `../references/best-practices.md` -- Campus design, STP, security hardening, upgrades
