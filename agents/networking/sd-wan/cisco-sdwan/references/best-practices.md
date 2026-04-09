# Cisco Catalyst SD-WAN Best Practices Reference

## Template Design Strategy

### Feature Template Hierarchy

Design templates in layers for maximum reuse:

```
Global Feature Templates (shared across all device types)
  +-- SYSTEM-BASE (system-ip variable, NTP, DNS, syslog)
  +-- OMP-STANDARD (default OMP timers, graceful restart)
  +-- SECURITY-UTM (standard UTD profile)
  +-- AAA-STANDARD (TACACS+/RADIUS config)
  +-- SNMP-STANDARD (SNMP v3 config)

Per-Role Feature Templates
  +-- VPN0-MPLS (MPLS transport interface config)
  +-- VPN0-INET (Internet transport interface config)
  +-- VPN0-LTE (Cellular backup config)
  +-- VPN1-BRANCH-LAN (standard branch LAN config)
  +-- VPN1-DC-LAN (data center LAN config)
  +-- BGP-PE (BGP peering to MPLS PE)
  +-- OSPF-LAN (OSPF for LAN routing)

Per-Platform Feature Templates
  +-- C8300-INTERFACES (platform-specific interface naming)
  +-- C8200-INTERFACES (smaller platform variant)
```

### Device Template Best Practices

1. **One device template per role** -- BRANCH-C8300, DC-C8500, REGIONAL-HUB-C8500
2. **Use variables for site-specific values** -- system-ip, site-id, hostname, interface IPs, BGP ASN
3. **CSV import for bulk deployment** -- Export variable sheet, populate in spreadsheet, import for all sites
4. **Version-control templates** -- Export templates via API; store in Git
5. **Test in lab before production** -- Always push to a lab device first

### CLI Add-On Template Guidelines

Use CLI add-on templates only when feature templates do not support the required CLI:
- Platform-specific commands (hardware-dependent features)
- Niche features not yet covered by feature templates
- Temporary workarounds (with a plan to remove once feature template support arrives)

**Anti-pattern**: Using CLI add-on templates for features that have feature template support. This creates maintenance burden and prevents variable substitution.

### Configuration Groups (20.12+)

For new deployments on 20.12+, consider configuration groups instead of device templates:
- More modular: Feature profiles can be shared across multiple configuration groups
- Device tagging: Apply configuration groups to devices by tag rather than individual assignment
- Aligned with Catalyst Center concepts for campus-WAN consistency
- Gradual migration path from device templates

## Policy Design Patterns

### AAR Policy Design

**SLA Class Design**:
- Define 4-6 SLA classes covering application categories (voice, video, critical data, bulk, best-effort)
- Set realistic thresholds based on actual transport quality measurements (not theoretical)
- Use app-route multiplier to smooth short-term fluctuations (default 6 intervals)
- Reduce app-route polling-interval from 600s to 60-120s for faster detection of path degradation

**App-Route Policy Structure**:
```
Sequence 1: VOICE (strictest SLA, preferred-color mpls)
Sequence 2: VIDEO (moderate SLA, preferred-color mpls biz-internet)
Sequence 3: CRITICAL-DATA (data SLA, preferred-color mpls biz-internet)
Sequence 4: SAAS-APPS (internet SLA, no preferred color -- use best path)
Sequence 5: BULK-DATA (relaxed SLA, lowest-cost transport)
Default: Best-effort (no SLA enforcement)
```

### Centralized Control Policy Design

**Hub-and-Spoke Enforcement**:
```
control-policy HUB-SPOKE
  sequence 10
    match route
      site-list SPOKE-SITES
    action accept
      set tloc-list HUB-TLOCS
  default-action accept
```

**Service Chaining (Firewall Insertion)**:
```
control-policy SERVICE-CHAIN
  sequence 10
    match route
      vpn-list VPN-GUEST
    action accept
      set service FW vpn 1
```

### Data Policy Design

**DIA (Direct Internet Access)**:
```
data-policy DIA-POLICY
  vpn-list VPN-1
    sequence 10
      match
        destination-data-prefix-list SAAS-PREFIXES
      action accept
        nat use-vpn 0
    default-action accept
```

**QoS Marking**:
```
data-policy QOS-MARKING
  vpn-list VPN-1
    sequence 10
      match
        app-list VOICE-APPS
      action accept
        set dscp 46
    sequence 20
      match
        app-list VIDEO-APPS
      action accept
        set dscp 34
    default-action accept
```

### Policy Testing Workflow

1. Create policy in SD-WAN Manager
2. Preview the policy configuration (GUI: Preview button)
3. Apply to a test site-list first (single site or lab)
4. Validate using `show sdwan policy from-vsmart` on the WAN Edge
5. Monitor app-route statistics for expected behavior changes
6. Expand site-list to include production sites in phases

## Security Integration Best Practices

### UTD Deployment Guidelines

1. **Enable UTD on all WAN Edge devices** -- Not just DIA sites; inspect all traffic
2. **Use security templates** -- Do not configure UTD via CLI add-on; use feature templates
3. **Signature updates**: Configure automatic Talos signature updates (daily minimum)
4. **SSL decryption**: Enable for DIA traffic if compliance requires deep inspection
5. **DNS security**: Enable DNS sinkholing for malware C2 domain blocking

### SASE Integration (Cisco Umbrella)

When to use Umbrella SIG instead of on-box UTD:
- Thin branches with low-power WAN Edge devices (C8200 series)
- Consistent security policy across branch AND remote users
- Advanced cloud security features (CASB, DLP) needed
- Scalability: Umbrella scales independently of WAN Edge CPU

Configuration approach:
1. Create Umbrella SIG tunnel in SD-WAN Manager
2. Define data policy to steer internet-bound traffic to Umbrella
3. Configure Umbrella policy in Umbrella dashboard
4. Monitor Umbrella SIG tunnel health via BFD

## Multi-Cloud Architecture

### Cloud OnRamp for SaaS

**Configuration**:
1. Enable Cloud OnRamp for SaaS in SD-WAN Manager
2. Select SaaS applications to monitor (O365, Salesforce, Webex, etc.)
3. Define probe parameters (probe frequency, timeout)
4. SD-WAN Manager calculates vQoE (virtual Quality of Experience) score per transport per app
5. Steering decisions based on vQoE score (best transport auto-selected)

**Best practices**:
- Enable at DIA sites for SaaS-heavy branches
- Use both DIA and centralized (via hub) paths so the system can compare
- Monitor vQoE trends to identify ISP quality issues
- Align with AAR policy -- Cloud OnRamp and AAR should not conflict

### Cloud OnRamp for IaaS

**AWS**:
1. Connect SD-WAN Manager to AWS account (IAM role)
2. Deploy C8000V instances in target VPCs
3. Create Transit Gateway (TGW) for inter-VPC routing
4. SD-WAN Manager automates tunnel establishment from branch to cloud

**Azure**:
1. Connect SD-WAN Manager to Azure subscription
2. Deploy C8000V in Azure VNet or use Azure Virtual WAN hub
3. Automated tunnel establishment from branch WAN Edge to Azure C8000V

**Best practices**:
- Deploy C8000V in at least 2 availability zones for HA
- Size C8000V instance based on expected throughput (D-series for production)
- Use application-aware routing to steer cloud-bound traffic optimally
- Monitor cloud instance health via SD-WAN Manager dashboard

## Upgrade Procedures

### Controller Upgrade Sequence

```
1. Backup: Export all configurations from SD-WAN Manager
2. Upgrade SD-WAN Manager cluster (one node at a time)
   a. Upgrade first node
   b. Verify cluster health (all services running)
   c. Upgrade second node
   d. Verify cluster health
   e. Upgrade third node
   f. Verify cluster health
3. Upgrade vSmart controllers (one at a time)
   a. OMP graceful restart protects data plane during upgrade
4. Upgrade vBond orchestrators
5. Upgrade WAN Edge devices (in waves)
   a. Start with non-critical sites
   b. Verify tunnel status and app-route statistics
   c. Roll out to remaining sites in batches
```

### WAN Edge Upgrade Best Practices

- Use SD-WAN Manager for centralized software upgrade (Configuration > Software Upgrade)
- Schedule upgrades during maintenance windows
- Upgrade in batches of 10-20% of devices at a time
- Monitor BFD sessions and control connections during upgrade
- Each WAN Edge reboots during upgrade (~5-10 minutes downtime)
- Verify post-upgrade: `show sdwan system status`, `show sdwan control connections`, `show sdwan bfd sessions`

### Rollback Plan

- SD-WAN Manager supports one-click rollback to previous software version
- Keep previous software image on the device (dual-bank flash)
- Test rollback procedure in lab before production upgrade window
- Document the rollback trigger criteria (e.g., >5% tunnel failures post-upgrade)

## Scaling Guidelines

| Component | Recommended Limit | Notes |
|---|---|---|
| WAN Edge per vSmart | ~2,000 | Deploy additional vSmart for scale |
| vSmart instances | Up to 6 | Distributed across availability zones |
| vManage cluster nodes | 3 or 6 | Odd numbers avoid split-brain |
| Tunnels per WAN Edge | ~1,000 | Platform-dependent; C8500 handles more |
| VPNs per WAN Edge | Up to 64 | Per device limit; typical: 4-8 |
| Centralized policies | Test at scale | Large site-lists can increase push time |

## Operational Monitoring Checklist

### Daily
- [ ] All control connections up (SD-WAN Manager dashboard)
- [ ] All BFD sessions up (no unexpected tunnel downs)
- [ ] No critical events in SD-WAN Manager events log

### Weekly
- [ ] Review app-route SLA compliance trends
- [ ] Check for devices out-of-sync with templates
- [ ] Review UTD security alerts (IPS, URL filtering)
- [ ] Check software and signature update status

### Monthly
- [ ] Capacity trending (bandwidth utilization per transport)
- [ ] Review and prune unused policies/templates
- [ ] Export configuration backups
- [ ] Review SD-WAN Manager cluster health metrics
