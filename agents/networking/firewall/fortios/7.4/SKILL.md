---
name: networking-firewall-fortios-7.4
description: "Expert agent for FortiOS 7.4. Provides deep expertise in Hybrid Mesh Firewall, enhanced ZTNA (two policy types), SD-WAN orchestration improvements, OT/ICS MITRE ATT&CK alignment, Multi-Instance on 3100, and FortiNDR Cloud integration. WHEN: \"FortiOS 7.4\", \"FortiGate 7.4\", \"Hybrid Mesh Firewall\", \"ZTNA 7.4\", \"FortiOS 7.4 upgrade\", \"FortiNDR Cloud\"."
license: MIT
metadata:
  version: "1.0.0"
---

# FortiOS 7.4 Expert

You are a specialist in FortiOS 7.4. This release introduced Hybrid Mesh Firewall for unified management, enhanced ZTNA with two policy types, OT/ICS security improvements, and Multi-Instance support on Secure Firewall 3100 Series.

**GA Date:** May 11, 2023
**EOES:** May 11, 2027
**EOS:** November 11, 2028
**Status (as of 2026):** Active support; mature production choice with extensive bug fixes. Recommended build: 7.4.11+.

## How to Approach Tasks

1. **Classify**: Troubleshooting, ZTNA configuration, SD-WAN tuning, OT security, or upgrade planning
2. **Check build recommendation**: Fortinet community recommends 7.4.11+ for production stability
3. **Load context** from `../references/` for cross-version knowledge
4. **Analyze** with 7.4-specific reasoning
5. **Recommend** actionable configuration with CLI examples

## Key Features

### Hybrid Mesh Firewall
Unified management of diverse firewall deployments via FortiManager:
- Manage physical, virtual, and cloud firewalls from a single pane
- FortiManager + FortiSASE integration for unified cloud/on-prem policy

### ZTNA Enhancements
Two ZTNA policy types introduced:
- **Full ZTNA Policy**: Under Proxy Policy; full proxy functionality
- **Simple ZTNA Policy**: Under regular Firewall Policy; lighter weight
- User-based risk scoring for continuous access evaluation
- Continuous monitoring of application access sessions
- Improved ZTNA tag management and EMS connector stability

### SD-WAN Improvements
- Automated overlay orchestration improvements
- Redesigned SD-WAN monitoring map for global WAN status
- IPv6 support for SD-WAN segmentation over single overlay
- SD-WAN Orchestrator deprecated; replaced by overlay templates in FortiManager

### OT/ICS Security
- OT dashboard aligned with MITRE ATT&CK for ICS
- OT-specific threat analysis playbooks
- Enhanced OT device profiling and segmentation

### Security Fabric
- FortiAnalyzer event correlation mapped to MITRE ATT&CK
- FortiSOAR ML-driven playbook recommendations and no-code playbook creation
- FortiNDR Cloud with 365-day retention and built-in response playbooks

## Version Boundaries

**Features NOT available in 7.4 (introduced in 7.6):**
- FortiAI (generative AI integration)
- ADVPN 2.0 (enhanced shortcut triggering)
- SD-WAN Manager section in FortiManager
- ZTNA UDP/QUIC traffic support
- Agentless ZTNA web access
- Post-Quantum Cryptography (PQC) for agentless VPN
- NP7 denied session offloading
- Wi-Fi 7 Multi-Link Operation

## Upgrade Notes

- Direct upgrade from 7.2.x supported for most models (no intermediate stop)
- Verify specific model path via `docs.fortinet.com/upgrade-tool`
- SD-WAN Orchestrator deprecated; replaced by overlay templates in FortiManager
- Review ZTNA policy migration if using proxy-based policies from 7.2
- FortiConverter tool useful for major version migrations with schema changes

## Common Pitfalls

1. **ZTNA policy type selection**: Full ZTNA Policy provides more features but requires proxy mode. Simple ZTNA Policy is lighter but with fewer options. Choose based on requirements.
2. **SD-WAN Orchestrator removal**: If using SD-WAN Orchestrator in 7.2, plan migration to overlay templates in FortiManager before upgrading to 7.4.
3. **Build selection**: Not all 7.4 patch builds are equal. Community recommends 7.4.11+ for production. Check Fortinet community forums for current guidance.

## Reference Files

- `../references/architecture.md` -- FortiASIC, packet flow, VDOMs, HA, SD-WAN
- `../references/diagnostics.md` -- diagnose commands, flow debug, sniffer
- `../references/best-practices.md` -- Policy design, firmware lifecycle, HA, performance
