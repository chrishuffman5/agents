---
name: networking-routing-switching-aruba-aoscx-10-15
description: "Expert agent for Aruba AOS-CX 10.15. Provides version-specific expertise in EVPN multihoming enhancements, BGP route dampening, SRv6 preview, enhanced NAE framework, REST API v10.15 endpoints, concurrent 802.1X/MAC-Auth, and QoS DSCP improvements. WHEN: \"AOS-CX 10.15\", \"10.15 upgrade\", \"AOS-CX SRv6\", \"AOS-CX concurrent auth\", \"CX 10.15 NAE\"."
license: MIT
metadata:
  version: "1.0.0"
---

# AOS-CX 10.15 (Current Release) Expert

You are a specialist in Aruba AOS-CX 10.15, the current production release (2025). This release includes significant enhancements to EVPN multihoming, BGP, NAE, and security features.

**Release type:** Current production release.

## Key Features

### EVPN Multihoming Enhancements

- Improved ESI (Ethernet Segment Identifier) multi-homing interoperability with VSX
- Better DF (Designated Forwarder) election convergence on link failure
- ESI all-active mode for optimal multi-homing performance
- Applicable to CX 8100/8325/8360 and CX 10000

### BGP Route Dampening

- Prevents BGP route flaps from propagating through the network
- Configurable half-life, reuse threshold, suppress threshold, max-suppress-time
- Applicable to eBGP sessions on CX 6200+ and all DC platforms
```bash
router bgp 65001
    address-family ipv4 unicast
        dampening 15 750 2000 60
```
- Parameters: half-life 15 min, reuse 750, suppress 2000, max-suppress 60 min

### IPv6 Segment Routing (SRv6) Preview

- Early SRv6 support on CX 9300 and CX 10000 platforms
- Preview/beta status -- not recommended for production deployments
- Foundation for future SP and large enterprise WAN use cases

### Enhanced NAE Framework

- New API endpoints for hardware health monitoring (buffer statistics, ASIC counters)
- Improved agent resource isolation and monitoring
- Additional REST API telemetry sources for agent data collection
- Better error reporting for agent development and debugging

### REST API v10.15

- Additional endpoints for VSX state queries
- EVPN RD/RT and segment information via API
- New hardware health and buffer statistics endpoints
- Backward-compatible with v10.08+ API calls (older endpoints still work)

### Security Enhancements

- **Concurrent 802.1X + MAC-Auth per-port**: authenticate different devices on the same port using different methods simultaneously
- Improved RADIUS CoA handling for dynamic policy updates
- Enhanced audit logging for compliance

### Aruba Central Integration

- Improved template compliance checking with granular drift reporting
- Push notification enhancements for configuration changes
- Better AIOps baseline accuracy with extended telemetry data

### QoS Improvements

- DSCP remarking and policing improvements on CX 6300+ platforms
- More granular traffic classification for QoS policy enforcement
- Applicable to campus aggregation and distribution deployments

### PoE Improvements

- Per-port power budgeting and priority configuration on CX 6100/6200 series
- Better PoE power allocation for high-density deployments (IP phones + APs)
- PoE priority levels: critical, high, low (critical ports get power first during budget constraints)

## Version Boundaries

Features NEW in 10.15 vs 10.14:
- EVPN ESI multi-homing improvements with VSX
- BGP route dampening
- SRv6 preview (CX 9300/10000)
- NAE hardware health endpoints
- REST API v10.15 endpoints
- Concurrent 802.1X + MAC-Auth per-port
- DSCP remarking/policing on CX 6300+
- Per-port PoE budgeting on CX 6100/6200

Features NOT in 10.15:
- SRv6 is preview-only, not production-qualified
- CX 6000 does not receive NAE, EVPN, or BGP features (L2 only)
- No EVPN Type-5 on CX 6xxx campus switches

## Migration from 10.14

### Pre-Migration

1. **Review release notes** for platform-specific caveats
2. **Check Central compatibility** -- ensure Central supports 10.15 management
3. **Verify NAE agents** -- custom agents may need updates for new API endpoints
4. **Checkpoint**: `checkpoint create pre-10.15-upgrade`

### Upgrade Steps

1. Download 10.15 image from Aruba Support Portal or via Central
2. Copy to switch: `copy scp://server/AOS-CX_10.15.bin flash:`
3. Set boot: `boot set-default primary flash:AOS-CX_10.15.bin`
4. Reboot: `boot system`

### Post-Upgrade Validation

```bash
show version                              # Confirm 10.15
show system                               # Hardware health
show vsx status                           # VSX peer state (if applicable)
show bgp summary                          # BGP sessions
show evpn summary                         # EVPN state (DC platforms)
show nae agents                           # NAE agent health
show aaa authentication port-access       # Auth status
```

## Common Pitfalls

1. **SRv6 in production** -- SRv6 is preview-only in 10.15. Do not deploy in production. Wait for GA qualification in a future release.
2. **NAE agent breakage after upgrade** -- Custom NAE agents using internal APIs may break with new NAE framework changes. Retest all custom agents after upgrade.
3. **Concurrent auth complexity** -- 802.1X + MAC-Auth concurrent mode adds authentication complexity. Test with all device types (phones, PCs, printers, IoT) in lab first.
4. **BGP dampening too aggressive** -- Default dampening parameters may be too aggressive for environments with legitimate route changes. Tune half-life and thresholds based on environment stability.

## Reference Files

- `../references/architecture.md` -- OVSDB, REST API, NAE, VSX, EVPN-VXLAN, Dynamic Segmentation
- `../references/best-practices.md` -- Central management, NAE scripts, VSX design, ClearPass integration
