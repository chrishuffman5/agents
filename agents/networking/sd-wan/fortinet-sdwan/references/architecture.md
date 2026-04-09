# Fortinet SD-WAN Architecture Reference

## FortiGate as SD-WAN Edge

Fortinet SD-WAN is built natively into FortiOS. The FortiGate is the SD-WAN edge, NGFW, and router in a single appliance. There is no separate SD-WAN controller.

### Component Roles

| Component | Role |
|---|---|
| **FortiGate** | SD-WAN edge: policy enforcement, routing, VPN, security, QoS |
| **FortiManager** | Centralized orchestration: template-based config, SD-WAN policy push, software upgrades |
| **FortiAnalyzer** | Log aggregation, SD-WAN analytics, application visibility, SLA reporting |
| **FortiSASE** | Cloud-delivered security (SWG, CASB, ZTNA, FWaaS) integrated with SD-WAN |
| **FortiClient** | Unified endpoint agent: ZTNA, VPN, EDR, telemetry |

### Architecture Implications

- **No controller dependency**: FortiGate operates autonomously for SD-WAN decisions. If FortiManager goes down, all SD-WAN steering continues locally.
- **Converged security**: NGFW inspection (AV, IPS, web filtering, sandboxing) runs on the same appliance as SD-WAN -- no additional security device needed.
- **FortiASIC acceleration**: NP7/SP5 hardware acceleration handles IPsec encryption, routing, and firewall at wire speed (limitations: proxy-mode and some ALG traffic cannot be offloaded).

## SD-WAN Configuration Structure

```
config system sdwan
  config zone           # Logical groupings of members
  config members        # WAN interfaces and tunnel interfaces
  config health-check   # Performance SLA probes
  config service        # SD-WAN rules (traffic steering)
  config neighbor       # BGP neighbors for overlay routing
end
```

### Zones

SD-WAN zones group members logically. Firewall policies reference zones instead of individual interfaces, enabling interface changes without policy rewrites.

Recommended zone design:
- **UNDERLAY**: Physical WAN interfaces (wan1, wan2, lte)
- **OVERLAY**: IPsec tunnel interfaces (hub overlays per transport)
- Optionally: separate zones per transport type (OVERLAY-MPLS, OVERLAY-INET)

Zone attribute `service-sla-tie-breaking` controls tie-break behavior:
- `cfg-order` (default): Use member order in configuration
- `fib-best-match`: Use routing table best match
- `input-device`: Use the interface the traffic arrived on

### Members

Members are physical or logical interfaces participating in SD-WAN:

Key attributes:
- **interface**: The WAN or tunnel interface name
- **zone**: Which SD-WAN zone the member belongs to
- **gateway**: Next-hop gateway for underlay interfaces
- **cost**: Relative cost (used by lowest-cost strategy); lower = preferred
- **priority**: Failover priority; lower number = higher priority
- **weight**: Distribution weight for maximize-bandwidth strategy
- **volume-ratio**: Alternative to weight for bandwidth-proportional distribution
- **status**: Enable/disable without removing from configuration

### Health Checks (Performance SLAs)

Health checks actively probe remote endpoints to measure path quality.

**Probe protocols**:
- ICMP (ping) -- simplest, lowest overhead
- TCP-echo -- tests TCP port reachability
- UDP-echo -- tests UDP path
- HTTP/HTTPS -- full application-layer probe (validates web server response)
- DNS -- probes DNS resolution
- TWAMP -- Two-Way Active Measurement Protocol (RFC 5357)

**Metrics collected**:
- **Latency**: Round-trip time (milliseconds)
- **Jitter**: Variation in latency between probes (milliseconds)
- **Packet loss**: Percentage of probes not returned
- **MOS**: Mean Opinion Score calculated from latency/jitter/loss (for VoIP quality)

**Timer parameters**:
- `interval`: Time between probes (default 500ms; range 20-3600000ms)
- `failtime`: Consecutive probe failures before marking member as SLA-failed
- `recoverytime`: Consecutive probe successes before marking member as SLA-recovered

**Passive health checks** (FortiOS 7.4.1+):
- Derive SLA metrics from actual application traffic passing through the FortiGate
- No active probing required -- reduces bandwidth overhead
- Useful for applications with known traffic patterns where probe overhead is undesirable
- Can complement active probes for more accurate application-level SLA measurement

### SD-WAN Rules (Services)

Rules define traffic matching criteria and steering strategy:

**Matching criteria**:
- Source/destination address objects
- Internet service (ISDB entries)
- Application IDs (FortiGuard AppDB)
- Users/groups
- Protocol, port numbers

**Steering strategies** (detailed):

**Manual**: Static interface selection. Traffic goes to the first available interface in `priority-members` list. No dynamic quality assessment. Use for traffic that must always use a specific path.

**Best Quality**: Continuously evaluates health check metrics. Selects the member with the best value for the specified `link-cost-factor` (latency, jitter, packet-loss, or MOS). Re-evaluates at every health check interval. Use for real-time applications.

**Lowest Cost**: Selects the member with the lowest `cost` attribute among those meeting SLA thresholds. Only switches away if current member violates SLA. Use for cost-sensitive traffic with quality minimums.

**Maximize Bandwidth**: Distributes sessions across multiple members proportionally to their `weight` or `volume-ratio`. ECMP-style load sharing. Use for bulk data transfers or aggregate throughput optimization.

**Minimum SLA**: Stays on the current member as long as it meets SLA thresholds. Only switches when the current member fails SLA. Minimizes reroutes for stability-sensitive applications. Use for applications sensitive to path changes (long-lived sessions).

## ADVPN Architecture

### Classic ADVPN (FortiOS 7.2 and earlier)

Classic ADVPN uses NHRP-like signaling piggybacked on IKE:

```
1. Spoke A sends traffic destined for Spoke B
2. Traffic flows through hub (normal hub-spoke path)
3. Hub detects spoke-to-spoke traffic flow
4. Hub sends "shortcut advice" (NHRP redirect) to both spokes
5. Spoke A and Spoke B negotiate direct IPsec tunnel (shortcut)
6. Subsequent traffic flows directly via shortcut
7. Shortcut torn down after idle timeout (no traffic)
```

**Limitations**:
- Single shortcut path per spoke-pair (no multi-path)
- Shortcut selection not SD-WAN-aware (no quality-based shortcut choice)
- Hub must process initial traffic before shortcut forms
- Shortcut lifecycle not tied to SD-WAN health checks

### ADVPN 2.0 (FortiOS 7.4+ / Enhanced 7.6)

ADVPN 2.0 is a complete redesign with native SD-WAN integration:

**Architecture**:
- Hub serves as discovery broker but does NOT make path decisions for spokes
- Spokes make autonomous path selection using local SD-WAN rules and health checks
- Shortcuts are SD-WAN members and participate in SD-WAN steering decisions

**Three control-plane mechanisms**:

1. **Discovery**: Originating spoke queries hub for remote spoke topology:
   - Available WAN interfaces (how many underlays the remote spoke has)
   - Overlay colors (which transport each interface uses)
   - Current health status per overlay
   
2. **Path Selection**: After discovery, originating spoke locally selects optimal shortcut:
   - Applies local SD-WAN rules (same rules used for hub-spoke traffic)
   - Evaluates discovered paths against SD-WAN health check thresholds
   - No hub involvement in the path decision

3. **Health Updates**: Active health monitoring over established shortcuts:
   - Periodic probe exchanges between spokes
   - Path selection continuously re-evaluates shortcut quality
   - Can switch to alternate shortcut or fall back to hub path if quality degrades

**FortiOS 7.6 Enhancements**:
- Multiple shortcuts per spoke-pair (one per underlay combination)
- SD-WAN maximize-bandwidth distributes traffic across multiple shortcuts
- Dynamic shortcut lifecycle: shortcuts created/removed aligned with health check state
- Improved convergence time for shortcut establishment

**Hub Configuration (ADVPN 2.0)**:
```
config vpn ipsec phase1-interface
  edit "HUB_OVERLAY"
    set type dynamic
    set auto-discovery-sender enable
    set auto-discovery-forwarder enable
    set advpn-sla-failure-node "VOICE-SLA"
  next
end
```

## Overlay Creation (IPsec)

### Hub-Spoke IPsec Overlay

Standard overlay uses IKEv2 dialup IPsec:

```
# Hub phase1
config vpn ipsec phase1-interface
  edit "OVERLAY_HUB"
    set type dynamic
    set interface "wan1"
    set ike-version 2
    set proposal aes256gcm-prfsha384
    set dpd on-idle
    set auto-discovery-sender enable
    set add-route disable
    set network-overlay enable
    set net-device enable
  next
end

# Hub phase2
config vpn ipsec phase2-interface
  edit "OVERLAY_HUB_P2"
    set phase1name "OVERLAY_HUB"
    set proposal aes256gcm
    set auto-negotiate enable
  next
end
```

### Overlay per Transport Design

Best practice: one overlay per physical WAN transport type:
```
MPLS_OVERLAY    -> wan1 (MPLS circuit)
INET1_OVERLAY   -> wan2 (Broadband)
INET2_OVERLAY   -> wan3 (LTE backup)
```

Each overlay becomes an SD-WAN member in the OVERLAY zone. SD-WAN rules select the appropriate overlay based on application SLA requirements.

## Link Quality Monitoring

### FortiManager SD-WAN Monitor

FortiManager provides organization-wide SD-WAN visibility:
- Per-member latency, jitter, packet loss, MOS trending (24h/7d/30d)
- SLA compliance heatmap across all managed sites
- Application performance correlated with WAN health events
- Per-site performance comparison

### FortiAnalyzer SD-WAN Reports

Enable SD-WAN performance SLA logs for FortiAnalyzer ingestion:
```
config log setting
  set sdwan-log enable
end
```

FortiAnalyzer reports:
- Application SLA compliance over time
- Top sites with SLA violations
- WAN utilization by application
- Bandwidth trending per transport

### FortiGate GUI SD-WAN Monitor

Network > SD-WAN > SD-WAN Monitor:
- Real-time per-member bandwidth utilization
- Health check probe results (latency/jitter/loss) per member
- Session distribution across members
