# Fortinet SD-WAN Best Practices Reference

## SD-WAN Rule Design

### Rule Ordering Strategy

SD-WAN rules are processed top-down, first-match. Order rules from most specific to least specific:

```
Rule 1: VOICE (best-quality, latency metric, specific destination)
Rule 2: VIDEO (best-quality, jitter metric, specific apps)
Rule 3: CRITICAL-SAAS (lowest-cost, ISDB: O365, Salesforce)
Rule 4: GENERAL-INTERNET (lowest-cost, all internet-service)
Rule 5: BULK-TRANSFER (maximize-bandwidth, backup/replication subnets)
Implicit: All other traffic uses default SD-WAN behavior
```

### Strategy Selection Guide

| Application Type | Recommended Strategy | link-cost-factor | Why |
|---|---|---|---|
| VoIP / UCaaS | best-quality | latency | Minimizes call quality issues |
| Video conferencing | best-quality | jitter | Reduces video artifacts |
| ERP / Database | minimum-SLA | N/A | Avoids session disruption from path switches |
| SaaS (O365, SFDC) | lowest-cost | N/A | Uses cheapest path that meets quality bar |
| Backup / Replication | maximize-bandwidth | N/A | Aggregate throughput across all paths |
| General internet | lowest-cost | N/A | Cost-optimized with basic quality floor |

### Health Check Design

**Probe target selection**:
- For internet SLA: Use well-known resolvers (8.8.8.8, 1.1.1.1) -- always available
- For private SLA: Use the actual application server or a representative host in the same network segment
- For SaaS SLA: Use the SaaS provider's probe endpoint if available

**Interval tuning**:
- Voice/video: 100-200ms interval for fast detection of quality changes
- Critical data: 500ms interval (balance between detection speed and overhead)
- General internet: 1000ms interval (sufficient for non-real-time traffic)
- Backup/bulk: 2000-5000ms interval (quality is less critical)

**Failtime / recoverytime**:
- Default 5/5 is appropriate for most use cases
- Reduce failtime to 3 for faster failure detection on critical paths
- Increase recoverytime to 10 for flappy links to prevent oscillation

**Warning/alert thresholds**:
- Set warning thresholds at 60-70% of the alert/SLA threshold
- Use warnings for proactive monitoring; alerts trigger SD-WAN failover
- Example: SLA latency threshold 150ms -> warning at 100ms

### ISDB Best Practices

Always use ISDB for SaaS application steering instead of manual IP prefix lists:
- ISDB is updated automatically by FortiGuard -- no maintenance burden
- SaaS providers frequently change IP ranges; manual lists become stale
- ISDB includes port and protocol information, not just IP prefixes
- Combine ISDB with application signatures for comprehensive steering

```
config system sdwan
  config service
    edit 10
      set name "O365-STEERING"
      set mode lowest-cost
      set internet-service enable
      set internet-service-name "Microsoft-Office365" "Microsoft-Teams"
      set health-check "INTERNET-SLA"
    next
  end
end
```

## ADVPN 2.0 Deployment Guide

### When to Deploy ADVPN 2.0

- Any hub-spoke topology where spoke-to-spoke traffic exists
- UCaaS / video conferencing between branch locations
- VDI traffic between branches and distributed desktop pools
- Applications requiring lowest-latency branch-to-branch paths

### ADVPN 2.0 Prerequisites (FortiOS 7.4+)

1. Hub FortiGate running FortiOS 7.4 or later (7.6 recommended for multi-shortcut)
2. All spoke FortiGates on FortiOS 7.4+ (feature requires matching versions)
3. Hub-spoke IPsec overlays already established and healthy
4. SD-WAN health checks configured for overlay members
5. SD-WAN rules referencing overlay zone members

### ADVPN 2.0 Configuration Checklist

**Hub**:
- Enable `auto-discovery-sender` on hub phase1 (sends shortcut advice)
- Enable `auto-discovery-forwarder` (forwards discovery info between spokes)
- Set `advpn-sla-failure-node` to reference the health check used for SLA evaluation
- Ensure hub has routes to all spoke subnets (typically via dynamic routing over overlay)

**Spoke**:
- Enable `auto-discovery-receiver` on spoke phase1
- Configure SD-WAN rules that apply to overlay zone (shortcuts inherit zone membership)
- Health checks must include overlay members

### ADVPN 2.0 7.6 Multi-Shortcut

FortiOS 7.6 allows multiple shortcuts per spoke-pair:
- One shortcut per underlay transport combination (e.g., MPLS-to-MPLS, INET-to-INET)
- SD-WAN maximize-bandwidth strategy distributes traffic across shortcuts
- Provides aggregate throughput between spokes across all available transports

## FortiSASE Integration Design

### Architecture Patterns

**Pattern 1: FortiSASE as Internet Breakout**
- Branch FortiGate steers internet-bound traffic to FortiSASE PoP
- FortiSASE provides SWG, CASB, FWaaS inspection
- Private app traffic goes through SD-WAN overlay to hub/DC
- Best for: Organizations needing consistent cloud security policy

**Pattern 2: FortiSASE as SD-WAN Hub**
- FortiSASE PoP acts as IPsec hub for spoke FortiGates
- All traffic (internet and private) flows through FortiSASE
- Thin-edge branch model: minimal FortiGate config
- Best for: MSP/MSSP, small branches with limited security expertise

### FortiSASE Configuration

1. Establish IPsec tunnel from FortiGate to nearest FortiSASE PoP
2. Add FortiSASE tunnel as SD-WAN member in OVERLAY zone
3. Create SD-WAN rule to steer internet traffic to FortiSASE member
4. Configure FortiSASE security policies in FortiSASE console
5. Optionally: manage both FortiGate and FortiSASE policies from FortiManager

### FortiSASE Services

| Service | Description |
|---|---|
| SWG | URL filtering, SSL inspection, web content policies |
| CASB | Cloud application control, DLP for SaaS |
| FWaaS | Network firewall in the cloud |
| ZTNA | Zero Trust access to private apps (cloud or on-prem) |
| DNS Security | Malicious domain blocking, DNS-over-HTTPS |

## ZTNA Design Patterns

### ZTNA with SD-WAN

FortiGate ZTNA access proxy combined with SD-WAN steering:

1. FortiClient on user endpoint establishes ZTNA connection
2. FortiGate verifies user identity (LDAP/SAML) and device posture (FortiClient EMS tags)
3. Authorized traffic proxied through FortiGate to application
4. SD-WAN steers the backend application traffic to optimal path

**Use cases**:
- Replace traditional VPN with per-application zero-trust access
- Enforce device compliance before granting access
- Combine with SD-WAN for optimal application delivery

### ZTNA Configuration
```
config firewall access-proxy
  edit "APP-PROXY"
    set vip "ZTNA-VIP"
    set client-cert enable
    set auth-portal enable
  next
end
```

## Operational Monitoring

### SD-WAN Logging

Enable SD-WAN performance SLA logging for analytics:
```
config log setting
  set sdwan-log enable
end
```

### Key Diagnostic Commands

```
# Member status and health
diagnose sys sdwan health-check
diagnose sys sdwan member

# Rule matching and path selection
diagnose sys sdwan service

# Detailed health check for specific probe
diagnose sys sdwan health-check status "INTERNET-SLA"

# ADVPN shortcut status
diagnose vpn ike gateway list
diagnose vpn tunnel list
```

### Monitoring Checklist

**Daily**:
- [ ] All SD-WAN members healthy (GUI: Network > SD-WAN > SD-WAN Monitor)
- [ ] All health checks passing (no sustained SLA failures)
- [ ] No unexpected ADVPN shortcut failures

**Weekly**:
- [ ] Review FortiAnalyzer SD-WAN SLA compliance reports
- [ ] Check for FortiGuard ISDB updates applied
- [ ] Review bandwidth utilization per transport (capacity trending)

**Monthly**:
- [ ] Review SD-WAN rule hit counts -- remove unused rules
- [ ] Validate health check thresholds against current transport quality
- [ ] Review ADVPN shortcut utilization -- are shortcuts being used effectively?
- [ ] Check FortiOS and FortiManager version alignment

## Scaling Guidelines

| Component | Guideline |
|---|---|
| SD-WAN members per FortiGate | Up to 255 (platform-dependent) |
| SD-WAN rules | Up to 512 (practical limit ~50-100 for maintainability) |
| Health checks | Up to 4 per SD-WAN rule reference; avoid redundant probes |
| ADVPN shortcuts per spoke | Platform-dependent; monitor IKE SA table size |
| FortiManager managed devices | Thousands (ADOM-based partitioning recommended) |

## Common Design Anti-Patterns

1. **Single health check for all rules** -- Different applications have different SLA requirements. Use dedicated health checks per application class with appropriate targets and intervals.

2. **Maximize-bandwidth for voice** -- Voice requires consistent single-path delivery, not load balancing. Use best-quality with latency metric for voice.

3. **ADVPN without SD-WAN rules for overlay** -- ADVPN 2.0 shortcuts participate in SD-WAN steering only if SD-WAN rules reference the overlay zone. Without rules, shortcuts form but traffic may not use them.

4. **Overly aggressive health check intervals** -- 100ms intervals across 50 members generates significant probe traffic. Size probe intervals proportionally to application sensitivity.

5. **Ignoring asymmetric routing** -- When using multiple overlays per transport, ensure SD-WAN zone and member configuration is consistent on both hub and spoke to prevent asymmetric path selection.
