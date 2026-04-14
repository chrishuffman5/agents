# FortiOS Best Practices Reference

## Policy Design

### Deny-by-Default
- Last rule is implicit deny; add explicit deny with logging for audit
- Start with least-privilege: define what IS allowed

### Policy Organization
- Top-to-bottom, first-match; specific rules above general rules
- Group related policies with tags or naming conventions
- Use address groups and service groups to reduce rule count
- Separate inbound and outbound policies clearly
- Use named policies for readability

### Address/Service Objects
- Never use raw IPs in policies; always create named objects
- FQDN objects for cloud services (dynamic DNS resolution)
- ISDB objects for well-known cloud services (M365, AWS) -- more accurate than manual IP lists
- Application-list for L7 identification rather than port-based rules

### UTM Profile Design
- Purpose-specific profiles: `utm-outbound-web`, `utm-inbound-dmz`, `utm-internal-strict`
- Apply only what is needed per policy
- Profile-based NGFW: keeps profiles reusable across policies
- Policy-based NGFW: use when application/URL category is the match criterion

### SSL Inspection
- Deploy deep inspection for untrusted internet-bound traffic
- Certificate inspection for trusted internal server traffic
- Build exemption list for certificate-pinned applications
- Push FortiGate CA cert via GPO/MDM before enabling deep inspection
- Flow-based SSL: must use "Inspect All Ports" option

## Firmware Lifecycle

### Version Selection
- **New deployments**: FortiOS 7.6 (longest support window, current recommended)
- **Stability-first**: 7.4 (mature with extensive bug fixes)
- **Avoid**: 7.2 (past EOES), 7.0 (near/past EOS)
- Check Fortinet community for recommended patch builds

### Upgrade Path
- Always use Fortinet Upgrade Path Tool: `https://docs.fortinet.com/upgrade-tool`
- Never skip intermediate builds on major version jumps
- Common paths: 7.4.x -> 7.6.x (direct); 7.2.x -> 7.4.x -> 7.6.x; 7.0.x -> 7.2.x -> 7.4.x -> 7.6.x

### Pre-Upgrade Checklist
1. Verify upgrade path via tool
2. Back up full config (encrypted)
3. Note firmware, HA state, active sessions
4. Review release notes for deprecated features
5. For HA: upgrade secondary first, then primary
6. Verify FortiGuard license validity post-upgrade

## HA Design

### FGCP Recommendations
- Dedicated physical heartbeat links (not shared with production)
- Two heartbeat links on different physical cards for redundancy
- Active-Passive for most deployments (simpler, no asymmetric routing)
- Active-Active only when UTM throughput is CPU-constrained
- Match hardware models and firmware exactly
- Set meaningful priorities (`set priority 200` vs default 128)
- Configure monitored interfaces for uplink failure detection
- Management IP on dedicated interface for independent access
- Enable `session-pickup` for UDP/ICMP if stateful failover required

### FGSP Design
- Use with ECMP routing or external load balancers
- Each unit has own addresses (no virtual MAC/IP)
- Synchronize TCP always; add UDP/ICMP only if required
- FGSP pairs can be FGCP clusters (nested HA)

## Logging

### What to Log
- All allowed traffic with UTM profiles (UTM events)
- All denied traffic for visibility (explicit deny rule with logging)
- IPS events at minimum high/critical severity
- Authentication events (VPN, admin logins)
- Avoid logging every allowed policy without UTM (volume without value)

### Destinations
- **FortiAnalyzer**: Enterprise standard; indexing, FortiSOC, playbooks
- **FortiCloud**: SMB/branch; cloud-hosted log storage
- **Local disk**: Short-term review (appliances with SSD)
- **Syslog**: Third-party SIEM integration
- Encrypt log transmission (TLS between FortiGate and FortiAnalyzer)

### Optimization
- Use `logtraffic-start enable` sparingly (doubles log entries)
- Set retention per log type based on compliance
- Monitor log rate: `diagnose fortilogd lograte`

## FortiManager Design

### ADOM Segmentation
- By customer/tenant (MSP)
- By FortiOS version (separate 7.4 and 7.6 ADOMs)
- By geography/team
- By criticality (prod vs non-prod)

### Policy Packages
- One package per FortiGate/VDOM unless truly identical
- Use Global ADOM for cross-ADOM policies
- Review Install Preview before every install
- Enable ADOM revision history

## Performance Tuning

### NP Offloading
- Use NP-capable interfaces for high-volume traffic
- Set `intra-switch-policy = explicit` for software switches
- Disable unnecessary session helpers/ALGs
- Remove PPPoE from high-throughput paths
- Check: `diagnose npu np7 session list | grep offloaded`

### Session Helper Management
Disable unused helpers to enable NP offloading:
- `sip`: Disable if using SBC
- `ftp`: Disable if passive FTP sufficient
- `dns`: Safe to disable if not using NAT DNS hairpinning
- `h323`: Disable if not using legacy video systems

### CPU/Memory
- Monitor: `diagnose sys top` for high-CPU processes
- Ensure 30%+ free RAM headroom
- `scanunitd`: AV scanning spikes
- `ipsengine`: IPS/flow inspection load

## Security Hardening

### Admin Access
```
config system admin > edit admin > set trusthost1 <mgmt-subnet>
config system global > set admin-port 8443 > set admin-ssh-port 2222
config system password-policy > set minimum-length 12
config system admin > set two-factor fortitoken
```

### Local-in Policies
Restrict management access to specific source IPs and services (HTTPS, SSH only).

### General Checklist
- Disable unused admin protocols (Telnet, HTTP, SNMPv1/v2)
- Use SNMPv3 with authentication and encryption
- Enable logging for admin logins and config changes
- Set `admin-lockout-threshold 5`, `admin-lockout-duration 300`
- Review and remove unused VPN configs, admin accounts, interfaces
- Enable FortiGuard Security Rating and address findings

## Common Misconfigurations

### Policy
- Overly permissive (`srcaddr=all, dstaddr=all, service=ALL` with no UTM)
- Shadow policies (general rule before specific rule)
- Missing NAT on outbound traffic

### SSL Inspection
- Missing CA cert deployment (browser warnings)
- No exemptions for certificate-pinned apps
- Flow-based without inspect-all-ports (misses non-443 SSL traffic)

### HA
- Heartbeat on production traffic switch (single point of failure)
- No monitored interfaces (won't failover on uplink failure)
- Mismatched firmware in cluster

### SD-WAN
- Unreachable health check targets (links falsely down)
- No SLA targets in best-quality rules (no failover threshold)
- Forgetting SD-WAN zone in firewall policy

### VPN
- Phase2 selector mismatch
- PFS mismatch between Phase1 and Phase2
- Route-based VPN missing static route to tunnel interface
