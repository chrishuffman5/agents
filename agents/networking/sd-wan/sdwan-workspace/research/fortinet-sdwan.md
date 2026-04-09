# Fortinet SD-WAN — Deep Dive Reference

> Last updated: April 2026 | Covers FortiOS 7.6.x / FortiManager 7.6.x

---

## 1. Architecture Overview

Fortinet SD-WAN is built natively into FortiOS — the operating system running on FortiGate next-generation firewalls. There is no separate SD-WAN controller appliance; the FortiGate IS the SD-WAN edge. Centralized management is provided by FortiManager, and analytics by FortiAnalyzer.

### 1.1 Component Roles

| Component | Role |
|---|---|
| **FortiGate** | SD-WAN edge: policy enforcement, routing, VPN, security, QoS |
| **FortiManager** | Centralized orchestration: template-based config, SD-WAN policy push, software upgrades |
| **FortiAnalyzer** | Log aggregation, SD-WAN analytics, application visibility, SLA reporting |
| **FortiSASE** | Cloud-delivered security (SWG, CASB, ZTNA, FWaaS) integrated with SD-WAN |
| **FortiClient** | Unified endpoint agent: ZTNA, SSL-VPN, EDR, telemetry |

### 1.2 Design Patterns

- **Hub-and-Spoke**: Branch FortiGates (spokes) connect via IPsec overlays to hub FortiGate(s)
- **Full-Mesh**: Direct branch-to-branch tunnels (ADVPN enables dynamic mesh from hub-spoke base)
- **Dual-Hub**: Two hub sites for redundancy; traffic selects best hub per SD-WAN rules
- **Multi-Region**: Regional hubs in each geographic zone; spokes connect to regional hub

---

## 2. SD-WAN Configuration

### 2.1 SD-WAN Zones

SD-WAN zones group SD-WAN members (interfaces/overlays) logically. Policies reference zones, not individual interfaces, enabling flexible interface addition without policy rewrites.

```bash
config system sdwan
  config zone
    edit "UNDERLAY"
      set service-sla-tie-breaking cfg-order
    next
    edit "OVERLAY"
    next
  end
```

### 2.2 SD-WAN Members

Members are the physical or logical interfaces (WAN links or tunnel interfaces) that participate in SD-WAN load balancing and path selection.

```bash
config system sdwan
  config members
    edit 1
      set interface "wan1"
      set zone "UNDERLAY"
      set gateway 203.0.113.1
      set cost 10
      set priority 1
    next
    edit 2
      set interface "wan2"
      set zone "UNDERLAY"
      set gateway 198.51.100.1
      set cost 20
      set priority 1
    next
    edit 3
      set interface "HUB1_OVERLAY"
      set zone "OVERLAY"
      set cost 5
    next
  end
```

### 2.3 Health Checks (Performance SLAs)

Health checks probe remote targets (e.g., 8.8.8.8, SaaS endpoints) via ICMP, TCP-echo, UDP-echo, HTTP, HTTPS, DNS, or TWAMP. Metrics collected: latency, jitter, packet loss, MOS (for VoIP).

```bash
config system sdwan
  config health-check
    edit "INTERNET-SLA"
      set server "8.8.8.8" "1.1.1.1"
      set protocol ping
      set interval 500          # probe every 500ms
      set failtime 5            # 5 consecutive failures = down
      set recoverytime 5
      set threshold-warning-packetloss 10
      set threshold-warning-latency 100
      set threshold-warning-jitter 20
      set threshold-alert-packetloss 20
      set threshold-alert-latency 200
      set members 1 2
    next
    edit "VOICE-SLA"
      set server "10.0.0.1"
      set protocol ping
      set interval 100
      set members 3
      set link-cost-factor latency
      set latency-threshold 100
      set jitter-threshold 30
      set packetloss-threshold 1
    next
  end
```

Passive health checks (FortiOS 7.4.1+) can also derive SLA metrics from actual application traffic without active probing, reducing probe overhead.

---

## 3. SD-WAN Rules (Traffic Steering)

SD-WAN rules are processed top-down; the first matching rule governs path selection.

### 3.1 Rule Strategies

| Strategy | Behavior |
|---|---|
| **Manual** | Explicitly specify preferred interface; no dynamic selection |
| **Best Quality** | Select interface with best metric (lowest latency/jitter/loss/MOS); re-evaluates continuously |
| **Lowest Cost** | Prefer lowest-cost interface meeting quality thresholds |
| **Maximize Bandwidth** | Distribute sessions across interfaces to maximize aggregate throughput (ECMP-style) |
| **Minimum SLA** | Stay on current link unless SLA violation; minimizes reroutes (stability-first) |

### 3.2 Rule Configuration Example

```bash
config system sdwan
  config service
    edit 1
      set name "VOICE-STEERING"
      set mode best-quality
      set link-cost-factor latency
      set latency-threshold 100
      set jitter-threshold 30
      set health-check "VOICE-SLA"
      set dst "VOICE-SERVERS"
      set priority-members 3 1   # prefer OVERLAY, fallback to wan1
    next
    edit 2
      set name "STREAMING-VIDEO"
      set mode maximize-bandwidth
      set health-check "INTERNET-SLA"
      set internet-service enable
      set internet-service-name "YouTube" "Netflix"
    next
    edit 3
      set name "DEFAULT-INTERNET"
      set mode lowest-cost
      set health-check "INTERNET-SLA"
      set members 1 2
    next
  end
```

---

## 4. Application Steering

### 4.1 ISDB (Internet Service Database)

The ISDB is a Fortinet-maintained database of internet services (SaaS apps, CDNs, cloud providers) identified by IP prefixes and port/protocol signatures. Updated automatically via FortiGuard.

- Includes services: Microsoft 365, Salesforce, AWS, Azure, GCP, Zoom, Webex, YouTube, Netflix, and thousands more
- SD-WAN rules reference ISDB entries by name — no manual IP prefix maintenance
- Can combine ISDB with custom application signatures for enterprise apps

```bash
set internet-service enable
set internet-service-name "Microsoft-Office365" "Microsoft-Teams"
```

### 4.2 Application Signatures (FortiGuard AppDB)

Deep Packet Inspection (DPI) engine classifies applications using:
- Layer 7 signatures (HTTP host/URI patterns, TLS SNI)
- Behavioral analysis
- Protocol decoders (SIP, H.323, DNS, etc.)

Application groups can be built and referenced in SD-WAN rules for application-specific steering:
```bash
set application 1234 5678   # application ID references
```

### 4.3 Per-Application SLA

Applications can be mapped to specific performance SLA objects, enabling automatic steering to the path that best satisfies per-app thresholds. This provides granular QoS without complex per-prefix policies.

---

## 5. ADVPN (Auto Discovery VPN)

ADVPN transforms a hub-spoke IPsec overlay into a dynamic partial or full mesh by building on-demand "shortcut" tunnels directly between spokes when spoke-to-spoke traffic is detected.

### 5.1 ADVPN (Classic — 7.2 and earlier)

- Hub-spoke IPsec overlay as base topology
- When spoke A sends traffic to spoke B, the hub receives the first packet and sends "shortcut advice" to both spokes
- Spokes negotiate a direct IPsec tunnel (shortcut) bypassing the hub
- Shortcut tunnels are maintained as long as there is active traffic; torn down after idle timeout

**Limitation of classic ADVPN**: Single shortcut path per spoke-pair; no awareness of multiple overlays or SD-WAN path quality for shortcut selection.

### 5.2 ADVPN 2.0 (FortiOS 7.4+ / Enhanced in 7.6)

ADVPN 2.0 is a ground-up redesign natively integrated with SD-WAN. It provides intelligent, distributed shortcut management.

**Three control-plane mechanisms:**
1. **Discovery**: Originating spoke discovers the remote spoke and learns its topology (available WAN interfaces, overlay colors) and health status
2. **Path Selection**: After discovery, originating spoke locally selects the optimal shortcut based on SD-WAN SLA metrics and SD-WAN rule strategies — no hub involvement in path decision
3. **Health Updates**: Periodic health updates over active shortcuts; path selection continuously re-evaluates and can switch shortcuts if quality degrades

**FortiOS 7.6 Enhancements:**
- Multiple shortcuts per spoke-pair for load balancing (SD-WAN maximizes aggregate bandwidth across shortcuts)
- Traffic load balanced over multiple shortcuts to use all available WAN bandwidth
- Dynamic shortcut lifecycle aligned with SD-WAN health check state

```bash
# Hub ADVPN 2.0 configuration
config vpn ipsec phase1-interface
  edit "HUB_OVERLAY"
    set type dynamic
    set auto-discovery-sender enable
    set auto-discovery-forwarder enable
    set advpn-sla-failure-node "VOICE-SLA"
  next
end
```

---

## 6. Overlay Creation (IPsec)

### 6.1 Hub-Spoke IPsec Overlay

Typical SD-WAN overlays use IKEv2 dialup IPsec with certificate or PSK authentication:

```bash
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

### 6.2 Overlay per Transport

Best practice: One overlay per physical WAN transport type (MPLS overlay, INET overlay, LTE overlay). SD-WAN rules select overlay based on application requirements.

```bash
# Overlays by transport color
MPLS_OVERLAY    → wan1 (MPLS circuit)
INET1_OVERLAY   → wan2 (Broadband)
INET2_OVERLAY   → wan3 (LTE backup)
```

---

## 7. Link Quality Monitoring

### 7.1 SLA Monitoring Dashboard

FortiManager SD-WAN Monitor provides:
- Per-member latency, jitter, packet loss, MOS trending (24h/7d/30d)
- SLA compliance heatmap across all sites
- Correlation of application performance with WAN health events

### 7.2 Logging for Analytics

Enable SD-WAN performance SLA logs for FortiAnalyzer ingestion:
```bash
config log setting
  set sdwan-log enable
end
```

FortiAnalyzer SD-WAN reports:
- Application SLA compliance over time
- Top sites with SLA violations
- WAN utilization by application
- Bandwidth trending per transport

---

## 8. FortiSASE Integration

FortiSASE is Fortinet's cloud-delivered SASE platform; integrates directly with on-premises FortiGate SD-WAN.

### 8.1 Architecture

- **Thin-edge FortiGate** (branch): SD-WAN edge with IPsec tunnels to FortiSASE PoPs
- **FortiSASE PoP**: Cloud-hosted security (Secure Web Gateway, CASB, FWaaS, ZTNA, DNS Security)
- **Traffic steering**: SD-WAN rules divert internet-bound traffic to nearest/best FortiSASE PoP
- **FortiManager integration**: Single-pane management for both FortiGate and FortiSASE policy

### 8.2 FortiSASE Services

| Service | Description |
|---|---|
| SWG (Secure Web Gateway) | URL filtering, SSL inspection, web content policies |
| CASB | Cloud app control, DLP for SaaS |
| FWaaS | Network firewall in the cloud |
| ZTNA | Zero Trust access to private apps (cloud or on-prem) |
| DNS Security | Malicious domain blocking, DNS-over-HTTPS |
| IPSEC Hub | FortiGate branches terminate to FortiSASE as overlay hub |

---

## 9. ZTNA Proxy with SD-WAN

FortiGate provides ZTNA (Zero Trust Network Access) proxy, which verifies device and user trust before granting access to specific applications.

- ZTNA access proxy terminates client connections; checks FortiClient posture, user identity (LDAP/SAML/Radius)
- Works in combination with SD-WAN for traffic path selection
- FortiClient unified agent handles both SD-WAN overlay establishment (IPsec/SSL VPN) and ZTNA posture enforcement

```bash
config firewall access-proxy
  edit "APP-PROXY"
    set vip "ZTNA-VIP"
    set client-cert enable
    set auth-portal enable
  next
end
```

---

## 10. FortiClient Unified Agent

FortiClient provides unified endpoint capabilities:
- **ZTNA**: Zero Trust access to applications (replaces traditional VPN for app-specific access)
- **SSL-VPN / IPsec VPN**: Full tunnel remote access
- **SD-WAN Agent**: (thin branch — FortiClient as micro-branch)
- **EDR**: Endpoint Detection & Response, AV
- **Telemetry**: Posture assessment reported to FortiGate/FortiAnalyzer via EMS (FortiClient EMS)
- **Web Filter**: Local URL filtering enforced on endpoint

---

## 11. Troubleshooting

### 11.1 SD-WAN Diagnostic Commands

```bash
# Show SD-WAN member status and health check results
diagnose sys sdwan health-check

# Show all SD-WAN member states
diagnose sys sdwan member

# Show SD-WAN routing/path selection
diagnose sys sdwan service

# Show active sessions with SD-WAN interface
diagnose sys sdwan session-id

# Real-time packet sniffer on WAN interface
diagnose sniffer packet wan1 "host 8.8.8.8" 4 0 l

# ADVPN shortcut status
diagnose vpn ike gateway list
diagnose vpn tunnel list
```

### 11.2 Health Check Status

```bash
# Detailed health check metrics
diagnose sys sdwan health-check status "INTERNET-SLA"

# Performance SLA member status
get router info sdwan service 1
```

### 11.3 SD-WAN Monitor (GUI)

FortiGate GUI → Network → SD-WAN → SD-WAN Monitor:
- Real-time per-member bandwidth utilization
- Health check probe results (latency/jitter/loss) per member
- Session distribution across members

### 11.4 FortiManager SD-WAN Dashboard

FortiManager → Device Manager → Monitors → SD-WAN Monitor:
- Organization-wide visibility (all managed FortiGates)
- SLA compliance trends
- Per-site performance comparison

### 11.5 Common Issue Resolution

| Symptom | Command / Check |
|---|---|
| Interface not selected for traffic | `diag sys sdwan service` — check rule match; verify health check passes |
| Health check failing | `diag sys sdwan health-check status` — check probe responses, firewall policy allows probes |
| ADVPN shortcut not forming | `diag vpn ike gateway list` — check IKE negotiation; verify ADVPN settings on hub |
| Asymmetric routing | Check SD-WAN zone/member order; review implicit rules |
| High latency on overlay | `diag sys sdwan health-check` — check underlay quality; ADVPN shortcut vs hub path? |

---

## 12. Key Configuration Reference

### 12.1 FortiOS CLI Structure for SD-WAN

```
config system sdwan
  config zone           # SD-WAN zones
  config members        # WAN interfaces participating in SD-WAN
  config health-check   # Performance SLA probes
  config service        # SD-WAN rules (traffic steering)
  config neighbor       # BGP neighbors for overlay routing
end
```

### 12.2 Recommended Design Practices

- Always create dedicated SD-WAN zones (UNDERLAY, OVERLAY, separate per transport type)
- Health check intervals: 500ms for critical apps; 1000ms default for internet
- Use ISDB for SaaS app steering — avoids IP prefix maintenance
- Deploy ADVPN 2.0 for any hub-spoke topology needing spoke-to-spoke optimization
- Reference FortiSASE PoPs as SD-WAN overlay members for cloud security steering
- Enable passive health checks for applications with known SLA profiles to reduce probe traffic

---

## References

- [ADVPN 2.0 FortiOS 7.6.0](https://docs.fortinet.com/document/fortigate/7.6.0/sd-wan-sd-branch-architecture-for-mssps/971487/advpn-2-0)
- [ADVPN 2.0 Enhancements 7.6](https://docs.fortinet.com/document/fortigate/7.6.0/new-features/905667/advpn-2-0-enhancements)
- [SD-WAN Performance SLA (latest)](https://docs.fortinet.com/document/fortigate/latest/administration-guide/584396/sd-wan-performance-sla)
- [Basic SD-WAN/ADVPN Design 7.6](https://docs.fortinet.com/document/fortigate/7.6.0/sd-wan-sd-branch-architecture-for-mssps/151899/basic-sd-wan-advpn-design)
- [Example SD-WAN with ADVPN 2.0 7.6.6](https://docs.fortinet.com/document/fortigate/7.6.6/administration-guide/256210/example-sd-wan-configurations-using-advpn-2-0)
- [Passive WAN Health Monitoring](https://docs.fortinet.com/document/fortigate/7.2.0/sd-wan-architecture-for-enterprise/664512/passive-wan-health-monitoring-of-performance-slas)
