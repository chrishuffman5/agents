# PAN-OS Operational Best Practices: Deep Technical Reference

## Security Policy Design

### Zone-Based Policy Principles

Zone design is the foundation of sound security architecture. Poorly designed zones lead to policy sprawl, overly permissive rules, and inability to enforce least privilege.

**Zone design principles:**
- Create zones that reflect the security level and trust relationship of devices within them.
- Never mix trust levels in a single zone (e.g., servers and workstations should be in different zones if they have different risk profiles).
- Segment by function: untrust (internet), trust (internal LAN), DMZ (servers accessible from internet), management (OOB management interfaces), guest, partner, VoIP, IoT/OT.
- Each zone should map to a clear policy intent: "anything in the DMZ zone may receive inbound connections from untrust, but only from trust to DMZ for admin access."
- Use Zone Protection Profiles on perimeter zones (untrust) to defend against reconnaissance, floods, and spoofed packets.

**Zone Protection Profile — key settings:**
- Reconnaissance protection: port scan and host sweep detection with block actions.
- Flood protection: SYN, UDP, ICMP, and other (ICMPv6, etc.) flood thresholds with SYN cookies enforcement.
- Packet-based attack protection: IP spoofing, fragmentation attacks, TCP/IP header anomalies.

---

### Application-Based Policy Rules

**Replace port-based rules with application-based rules:**
- Never write rules using `application: any` and `service: tcp/443` — this allows ALL SSL/TLS applications, not just web browsing.
- Use specific App-IDs: `web-browsing`, `ssl`, `facebook-base`, `office365-base`, etc.
- Use `service: application-default` to restrict traffic to the ports the application is designed to use — this prevents tunneling attacks (e.g., running SSH over port 80 to evade port-based rules).

**Application groups and filters:**
- Use application groups to consolidate multiple App-IDs into named groups for policy reuse.
- Use application filters (dynamic groups based on App-ID attributes like category, sub-category, risk level) for maintainable policies that automatically include new App-IDs matching the filter.
- Example: a filter for `category: collaboration AND risk >= 3` automatically includes any new collaboration App-ID Palo Alto adds that has risk level 3 or higher.

**Specifying service:**
- `application-default`: traffic must use the application's documented default ports. Best practice for most rules.
- `any`: allow the application on any port. Use only when necessary (e.g., custom-deployed services on non-standard ports).
- Specific service objects: use only when you have a documented, specific port requirement.

---

### Rule Ordering and Shadowing Prevention

Rules are evaluated top-down, first-match. Incorrect ordering causes shadowed rules that are never evaluated.

**Correct ordering principles:**
1. **Deny rules for specific threats first**: block known-bad sources, botnets, dynamic block lists.
2. **More specific rules above general rules**: a rule for `source: finance-subnet` should appear above `source: all-internal-subnets`.
3. **Allow rules before deny rules** for the same traffic pattern.
4. **Cleanup rule at the bottom**: an explicit deny-all rule with logging enabled to capture all unmatched traffic for audit.

**Detecting shadowed rules:**
- CLI: `test security-policy-match from <zone> to <zone> source <ip> destination <ip> protocol <proto> destination-port <port>` — shows which rule matches the simulated traffic.
- Panorama Security Policy Optimizer: identifies unused rules, rules with unused App-IDs, and rules that could be tightened.
- Security policy rule hit counts: `show running security-policy` or GUI Statistics column — rules with zero hits are candidates for removal or investigation.
- **Rule shadowing detection**: Panorama's Policy Optimizer highlights rules where all traffic matching a rule also matches an earlier rule (the later rule is effectively shadowed).

**Rule naming conventions:**
- Use descriptive, consistent naming: `[purpose]-[source-zone]-[dest-zone]-[application]` (e.g., `allow-trust-dmz-webapps`).
- Include ticket numbers or dates in rule descriptions for audit trail.
- Use the Description field for business justification.
- Tag rules with relevant metadata (owner, environment, review date) using Tags.

---

### Security Profile Attachment

**Every allow rule should have security profiles attached** (Defense in Depth principle):
- Outbound internet rules: Antivirus + Anti-Spyware + Vulnerability + URL Filtering + WildFire Analysis.
- Intrazone server rules: Vulnerability + Anti-Spyware (at minimum).
- Inbound rules to DMZ servers: Vulnerability + Anti-Spyware.
- Profile Groups: create a "strict-outbound", "strict-inbound", and "internal-server" profile group for consistent, maintainable assignment.

**Never leave rules with `profile: none`** for rules that allow significant traffic — this disables threat inspection for matching sessions.

---

## NAT Design

### Source NAT Best Practices

- Use **Dynamic IP and Port (DIPP/PAT)** for general outbound internet access — conserves public IP addresses.
- Use **Dynamic IP** (no port translation) when the destination requires a fixed source IP but the specific port doesn't matter.
- Use **Static NAT** for servers that need consistent external IP addresses (bilateral NAT — translates both inbound and outbound for the same server).
- Create dedicated source NAT IP pools for different zones or security domains — avoids mixing traffic from different security levels behind the same public IP.

### Destination NAT Best Practices

- **Publish server IPs explicitly**: use specific destination NAT rules for each server service, never wildcard destination NAT.
- **Combine with security policy**: destination NAT alone is not security — ensure a security policy rule explicitly permits only the intended traffic (specific app + port) to the translated destination.
- **No-NAT rules first**: place no-NAT rules above NAT rules for traffic that should not be translated (e.g., inter-site VPN traffic, management plane traffic).
- **U-Turn NAT for split DNS avoidance**: when internal users need to reach internal servers using public DNS names (and public IPs), configure U-Turn NAT rather than maintaining split-horizon DNS. The hairpin rule requires both destination NAT (translate public IP to server private IP) and source NAT (translate client IP to firewall interface IP so return traffic routes through the firewall).

### IP Address Management for NAT
- Monitor DIPP pool utilization: `show running nat-policy` and NAT pool utilization counters.
- Default DIPP oversubscription: one translated IP can support ~64,000 PAT translations simultaneously.
- For high-session-count environments, provision multiple public IPs in the DIPP pool.

---

## HA Deployment Best Practices

### Platform and Link Requirements
- HA peers must be identical hardware models running the same PAN-OS version.
- HA1 (control) and HA2 (data/session sync) links must be dedicated and not shared with data traffic.
- For critical deployments, use dedicated HA1 and HA2 physical interfaces — not the management interface sharing bandwidth.
- HA1 backup link: configure a backup HA1 path to prevent split-brain scenarios if the primary HA1 link fails.
- HA2 keepalive: enable HA2 keepalive monitoring. Default threshold: 10000ms. If HA2 fails, the firewall can be configured to fail over or log-only depending on whether session continuity is critical.

### Active/Passive Configuration Guidance
- **Disable preemption** in most production environments. Preemption causes unnecessary failovers when the primary device recovers — it re-preempts active status, potentially dropping active sessions. Only enable preemption if policy explicitly requires the primary to always be active.
- **Device priority**: primary firewall should have a lower device priority number (higher priority). Default is 100 — set primary to 10 or 20.
- **Heartbeat interval and hold time**: default heartbeat is 1000ms with a 3-second hold time. Reduce carefully in environments where low-latency failover is critical — too aggressive can cause false failovers on momentary network hiccups.

### Path Monitoring
- Configure path monitoring to logical destinations (default gateways, key internal servers) in addition to link monitoring.
- Path monitoring uses ICMP — ensure the monitored IP responds to ICMP from the firewall.
- Failure condition: set to "any" (failover if any monitored path fails) or "all" (only failover if all monitored paths fail). "Any" is more sensitive but may cause unnecessary failovers.

### HA Upgrade Sequence (Critical)
1. Verify both peers are synchronized: `show high-availability state`.
2. Disable preemption (if enabled) on both peers.
3. For active/passive — on the **passive** peer: download and install the new PAN-OS version; reboot.
4. After passive peer is back up and synchronized, manually fail over (suspend the active peer): `request high-availability state suspend`.
5. The passive peer becomes active. Verify traffic is flowing.
6. Upgrade the (now passive) original active peer; reboot.
7. After both peers are on the new version and synchronized, re-enable preemption if desired.
8. Never upgrade both peers simultaneously — this causes a complete traffic outage.

---

## Panorama Best Practices

### Architecture and Sizing
- Run Panorama in Management Only + dedicated Log Collector mode for large deployments (>50 firewalls or high log volume).
- Size Log Collector storage based on log retention requirements: calculate average logs/second × average log size × retention days × 1.5 (headroom factor).
- Distribute Log Collectors by geography or by firewall grouping to reduce WAN bandwidth for log forwarding.
- Use Collector Groups for log redundancy — logs are distributed across Log Collectors in the group.

### Device Group and Template Design
- Use a **flat device group hierarchy** unless you truly have shared policy requirements that justify nesting. Over-hierarchizing creates complexity without benefit.
- Design device groups around **administrative ownership and policy differences**, not just geography.
- Template naming convention: use `GL-` prefix for global templates, `RG-` for regional, `SI-` for site-specific.
- Always use **template variables** for any value that differs per firewall (interface IPs, loopback IPs, BGP peer IPs, syslog server IPs). This enables template reuse across hundreds of devices.
- Lock down what local admins can override: use Panorama to define which settings are under central control vs. locally manageable.

### Panorama Commit Discipline
- Always commit to Panorama first, then push to devices — never skip the Panorama commit step.
- Review diffs before committing: `Panorama > Commit > Preview Changes`.
- Push to a subset of devices first (canary deployment) when making significant policy changes.
- Use **Commit Scheduling** for maintenance window pushes.
- Leverage the **Config Lock** and **Commit Lock** features when multiple administrators are making concurrent changes.

---

## Log Management Best Practices

### Log Volume Planning
- Traffic logs are highest volume — consider logging only session end (not session start) to reduce volume by 50%.
- Use log forwarding profiles to send critical logs (threats, URL, WildFire) to both Panorama and an external SIEM.
- Set appropriate log retention periods per log type: threat logs (90+ days), traffic logs (30 days), URL logs (60 days) — adjust based on compliance requirements.

### SIEM Integration
- Forward logs via syslog (BSD or IETF format) to SIEM.
- Use the **Custom Log Format** option to include only required fields and reduce SIEM storage costs.
- For high-volume environments: forward via syslog over TCP (more reliable than UDP for high-throughput scenarios).

---

## Software Upgrade Procedures

### Pre-Upgrade Checklist
1. Review the target version's release notes, especially **"Known Issues"** and **"Changes to Default Behavior"**.
2. Review the **App-ID impact report** for the new content update bundled with the new PAN-OS version.
3. Back up the current running configuration: `Device > Setup > Operations > Export named configuration snapshot`.
4. Verify all licenses are valid and not expired.
5. Run `show system disk-space` — ensure sufficient disk for the upgrade.
6. Check Panorama/Log Collector version compatibility (Panorama must be same or newer than managed firewalls).
7. Validate the upgrade path: some versions require an intermediate upgrade. Check the official upgrade path matrix.

### Upgrade Order in Complex Deployments
1. **Panorama** (management server) — upgrade first.
2. **Log Collectors** — upgrade before managed firewalls.
3. **WF-500 appliances** — upgrade before firewalls that forward files to them.
4. **Firewalls** — upgrade last; use HA pair upgrade procedure to minimize downtime.

### Content Update Best Practices
- Install **Applications and Threats** content first, then Antivirus, then WildFire separately.
- Test content updates in a staging environment or on a non-production firewall before broad rollout.
- Use Panorama's content update scheduling to deploy updates to device groups in waves.

---

## Best Practice Assessment (BPA) Tool

### What BPA Evaluates
The BPA tool analyzes firewall and Panorama configurations against Palo Alto Networks' published best practices and provides a scored report by category:

- **Device configuration**: management access controls, DNS, NTP, HA settings, logging.
- **Security policy**: rule quality (application-based, security profiles attached, no overly permissive rules).
- **Threat prevention**: profile completeness, WildFire enablement, DNS Security.
- **Decryption**: SSL inspection coverage.
- **User-ID and App-ID adoption rates**.

### Running BPA
- Available through the **Expedition** migration/optimization tool (free download from Palo Alto Networks).
- Expedition can import a firewall config and generate a BPA report.
- The report shows pass/fail by check with remediation guidance.
- BPA scores are compared against industry averages in your vertical (aggregated, anonymized telemetry).
- BPA checks are aligned with the **Palo Alto Networks Best Practices** documentation and **CIS Benchmark** for PAN-OS.

---

## IronSkillet: Day-One Baseline Configuration

IronSkillet is an open-source project (GitHub: `PaloAltoNetworks/iron-skillet`) providing pre-built, best-practice configuration templates for PAN-OS firewalls and Panorama.

### What IronSkillet Configures
- **Security profiles**: strict antivirus, anti-spyware (with DNS sinkholing enabled), vulnerability protection (strict), URL filtering, WildFire analysis — all aligned with Palo Alto best practices.
- **Security profile groups**: outbound, inbound, and internal profile groups for policy attachment.
- **Log forwarding profiles**: standardized log forwarding to Panorama and syslog.
- **Interface management profiles**: restrict management access protocols (disable telnet, HTTP; enable SSH, HTTPS).
- **Zone protection profiles**: for perimeter (untrust) zones.
- **Security policy baseline**: default allow/deny rules with security profiles attached.
- **Device hardening**: NTP, DNS, password complexity, session timeouts, management access restrictions.

### How to Apply IronSkillet
1. Clone the repository: `git clone https://github.com/PaloAltoNetworks/iron-skillet`.
2. Edit the `variables` file for your environment (device name, DNS servers, syslog server IP, sinkhole IP, etc.).
3. Use Panhandler (web UI) or the SLI CLI tool to push the configuration to the firewall/Panorama via XML API.
4. Review and commit via the GUI/CLI.
5. IronSkillet is also the foundation for Panorama template configurations — use the Panorama variant of IronSkillet for centrally managed deployments.

### IronSkillet and Panorama
- A separate Panorama-focused IronSkillet configuration is available.
- Configures shared objects, device group security profiles, and template settings for Panorama-managed deployments.
- Designed to be imported as a Panorama template stack and device group hierarchy.
