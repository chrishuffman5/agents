# PAN-OS Best Practices Reference

## Security Policy Design

### Zone Design
- Create zones by trust level and function: untrust, trust, DMZ, management, guest, IoT/OT
- Never mix trust levels in a single zone
- Apply Zone Protection Profiles on perimeter zones (untrust): reconnaissance detection, flood protection, packet-based attack protection with SYN cookies

### Application-Based Policy
- Use specific App-IDs, never `application: any` with `service: tcp/443`
- Use `service: application-default` to restrict apps to their documented ports
- Application groups: consolidate related App-IDs for reuse
- Application filters: dynamic groups by category/risk that auto-include new App-IDs

### Rule Ordering
1. Deny rules for specific threats first (EDLs, block lists)
2. More specific rules above general rules
3. Allow rules before deny rules for same traffic
4. Cleanup deny-all with logging at the bottom

### Security Profile Attachment
Every allow rule should have profiles. Use Profile Groups:
- **Outbound**: AV + Anti-Spyware (DNS sinkhole) + Vuln Protection (strict) + URL Filtering + WildFire Analysis + File Blocking
- **Inbound DMZ**: AV + Anti-Spyware + Vuln Protection (strict)
- **Internal servers**: Vuln Protection + Anti-Spyware

Start with strict profiles, then add exceptions for false-positive threat IDs.

### Rule Shadowing Detection
- `test security-policy-match` to verify which rule matches
- Panorama Policy Optimizer: identifies unused rules, unused App-IDs, shadow rules
- Rule hit counts: `show running security-policy` -- zero-hit rules need review

## NAT Design

### Source NAT
- DIPP/PAT for general outbound internet
- Dedicated NAT pools per security domain
- Monitor DIPP pool utilization (~64K PAT translations per IP)

### Destination NAT
- Explicit rules per server service; no wildcard DNAT
- Combine with security policy allowing only intended application + port
- No-NAT rules above NAT rules for VPN/management traffic

### U-Turn NAT
For internal users accessing internal servers via public IP: requires DNAT + SNAT in the same rule set.

## HA Deployment

### Active/Passive
- Disable preemption in production
- Primary device priority: lower number (e.g., 10 or 20)
- Dedicated physical HA1 and HA2 links (not management interface)
- Configure HA1 backup link for split-brain prevention
- Enable HA2 keepalive monitoring

### Path Monitoring
- Monitor logical destinations (default gateway, key servers) via ICMP
- Failure condition: "any" is more sensitive; "all" requires total failure

### HA Upgrade Sequence
1. Verify sync: `show high-availability state`
2. Disable preemption on both peers
3. Upgrade passive peer; reboot
4. After passive is back and synced, suspend active: `request high-availability state suspend`
5. Passive becomes active; verify traffic
6. Upgrade original active (now passive); reboot
7. Re-enable preemption if desired
8. **Never upgrade both peers simultaneously**

## Panorama Best Practices

### Architecture
- Management Only + dedicated Log Collectors for >50 firewalls or high log volume
- Size Log Collector storage: avg logs/sec x avg log size x retention days x 1.5
- Distribute Log Collectors by geography

### Device Groups and Templates
- Flat device group hierarchy unless shared policy truly justifies nesting
- Design device groups by administrative ownership and policy differences
- Template naming: GL- (global), RG- (regional), SI- (site-specific)
- Always use template variables for per-device values (interface IPs, BGP peers, syslog servers)

### Commit Discipline
- Always commit to Panorama first, then push to devices
- Preview changes before committing
- Push to a subset of devices first (canary deployment) for significant changes
- Use config locks and commit locks for multi-admin environments

## Software Upgrade Procedures

### Pre-Upgrade Checklist
1. Review release notes -- especially "Known Issues" and "Changes to Default Behavior"
2. Review App-ID impact report for new content
3. Back up running config: Device > Setup > Operations > Export
4. Verify licenses are valid
5. Check disk space: `show system disk-space`
6. Check Panorama version compatibility (Panorama >= firewall version)
7. Validate upgrade path via official matrix

### Upgrade Order
1. Panorama first
2. Log Collectors
3. WF-500 appliances
4. Firewalls (use HA upgrade procedure)

### Content Updates
- Install Applications and Threats first, then AV, then WildFire
- Test content updates in staging before production
- Use Panorama content update scheduling for wave deployments

## IronSkillet

Open-source Day-One best practice configuration from Palo Alto Networks:
- Strict security profiles (AV, Anti-Spyware with DNS sinkhole, Vuln Protection strict, URL Filtering, WildFire Analysis, File Blocking)
- Profile groups: outbound, inbound, internal
- Log forwarding profiles, interface management profiles, zone protection profiles
- Device hardening: NTP, DNS, password complexity, session timeouts

### Applying IronSkillet
1. Clone: `git clone https://github.com/PaloAltoNetworks/iron-skillet`
2. Edit variables file for your environment
3. Push via Panhandler (web UI) or SLI CLI
4. Review and commit

## BPA (Best Practice Assessment)
- Available through Expedition migration/optimization tool
- Evaluates: device config, security policy, threat prevention, decryption, User-ID/App-ID adoption
- Scores compared against industry averages
- Aligned with Palo Alto Best Practices documentation and CIS Benchmark for PAN-OS

## Log Management

- Traffic logs: log session end only (not start) to reduce volume by 50%
- Use log forwarding profiles: threats to Panorama + SIEM; traffic selectively
- Custom log format for SIEM to include only needed fields
- TCP syslog for high-volume environments (more reliable than UDP)
