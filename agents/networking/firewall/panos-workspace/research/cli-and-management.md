# PAN-OS CLI and Management: Deep Technical Reference

## CLI Architecture

PAN-OS presents a hierarchical CLI with two primary modes. Internally, both modes interact with the same configuration data model — an XML tree that represents all device configuration and operational state.

---

## CLI Modes

### Operational Mode
- **Prompt**: `>`
- Default mode upon login.
- Used to: view firewall state, monitor traffic, execute operational commands, restart processes, load/save configurations.
- Commands are not persistent — they do not modify the running configuration.
- Key operational commands:

```
show system info                     # Platform details, SW version, serial
show system resources                # CPU, memory utilization
show interface all                   # Interface status summary
show routing route                   # Active routing table
show session all                     # Active session table
show session id <id>                 # Detailed session info
show counter global                  # Global packet/drop counters
show jobs all                        # Background jobs (commits, installs)
show log traffic                     # Recent traffic log entries
show log threat                      # Recent threat log entries
show arp all                         # ARP table
show high-availability state         # HA status and synchronization state
show high-availability all           # Full HA detail
test security-policy-match ...       # Simulate policy lookup
test routing fib-lookup ...          # FIB routing lookup
request system software check        # Check available PAN-OS updates
request system software download version <ver>
request system software install version <ver>
request system restart               # Full system restart
request system shutdown              # Graceful shutdown
debug dataplane packet-diag ...      # Dataplane packet capture and debug
```

### Configuration Mode
- **Enter**: `configure` (from operational mode)
- **Prompt**: `#`
- Used to: view and modify candidate configuration.
- All changes affect the **candidate config** only — nothing goes live until `commit`.
- **Exit**: `exit` or `quit` returns to operational mode.
- Key configuration commands:

```
show                                 # Display current location in config hierarchy
show devices                         # Show managed devices (Panorama)
set <path> <value>                   # Set a configuration value
edit <path>                          # Change context to config node
delete <path>                        # Remove a configuration element
rename <path> to <name>              # Rename an object
move <path> top|bottom|before|after  # Reorder rules
copy <path> to <dest>                # Copy config element
commit                               # Apply candidate config to running config
commit force                         # Force commit (bypasses diff check)
validate full                        # Validate without committing
load config from <filename>          # Load a saved config
save config to <filename>            # Save candidate to file
diff                                 # Show diff between candidate and running
revert config                        # Revert candidate to match running
```

---

## Commit Model: Candidate → Running Configuration

This is one of the most important operational concepts in PAN-OS:

### Candidate Configuration
- A working copy of the configuration that can be modified without affecting live traffic.
- All GUI changes, CLI `set`/`edit`/`delete` commands, and API calls write to the candidate config.
- Multiple admins can simultaneously edit the candidate config (unless a commit lock is held).
- **`diff`**: shows changes between candidate and running config — always review before committing.
- **`validate full`**: validates the candidate config for syntax and semantic correctness without committing.

### Running Configuration
- The active configuration enforced by the dataplane.
- Updated only when a `commit` is executed.
- Stored as `/opt/pancfg/mgmt/saved-configs/running-config.xml`.

### Commit Options
- **Full commit**: `commit` — applies all pending changes.
- **Partial commit**: `commit partial admin-name <admin>` — commits only the changes made by a specific administrator. Introduced in PAN-OS 10.2.
- **Commit force**: bypasses the comparison optimization; use when standard commit hangs.
- **Commit and quit**: commits and returns to operational mode.

### Configuration Locks
Prevent conflicting changes during multi-admin operations:
- **Config Lock**: prevents any other admin from changing the candidate config. Held by one admin at a time.
- **Commit Lock**: prevents any other admin from issuing a commit. Ensures in-progress work isn't committed prematurely.
- Locks are released on logout or manually: `request config-lock remove admin <admin>`
- Superusers can force-remove locks: `request config-lock remove admin <admin>`

### Saved Configurations
- Named snapshots of config: `save config to <name>`
- Load a snapshot: `load config from <name>`
- After loading, the loaded config becomes the new candidate — still requires commit to activate.
- Auto-saved configs: PAN-OS auto-saves before each commit; accessible via `show config saved`.

---

## Key Operational Troubleshooting Commands

```bash
# Session debugging
show session all filter source 10.1.1.1
show session all filter application ssl
show session all filter state ACTIVE
show session info                            # Session table statistics

# Packet captures (tcpdump-level)
debug dataplane packet-diag set filter match source 10.1.1.1
debug dataplane packet-diag set filter match destination 8.8.8.8
debug dataplane packet-diag set capture stage firewall file /tmp/pcap.pcap
debug dataplane packet-diag clear filter
debug dataplane packet-diag show capture

# App-ID and policy testing
test application-id application facebook-base flow
test security-policy-match from trust to untrust source 10.1.1.1 destination 8.8.8.8 protocol 6 destination-port 443

# HA management
request high-availability state suspend          # Manually fail over
request high-availability state functional       # Bring back into HA
request high-availability sync-to-remote running-config

# Content updates
request content upgrade check
request content upgrade install version latest
request anti-virus upgrade check
request anti-virus upgrade install version latest
request wildfire upgrade check
```

---

## Panorama: Centralized Management

Panorama is the Palo Alto Networks centralized management platform for NGFWs and log collection.

### Deployment Modes
1. **Panorama Mode**: Single appliance that handles both management and log collection. Default mode for M-Series appliances and virtual Panorama.
2. **Management Only**: Panorama handles only device configuration and policy management; log collection offloaded to dedicated Log Collectors.
3. **Log Collector Mode**: Dedicated log collection; managed by a separate Panorama instance. M-Series appliances can be converted to dedicated Log Collectors.

### Device Groups
- **Device Groups** contain firewalls and define the scope of policy management.
- Hierarchical structure: Shared (global) > Device Group Parent > Device Group Child.
- Policies in device groups are layered:
  - **Pre-rules**: evaluated before device-local rules.
  - **Post-rules**: evaluated after device-local rules.
  - **Default rules**: at the bottom of the combined rulebase.
- Objects (address objects, service objects, application groups) created in a device group are available to rules in that device group and all child device groups.
- **Shared objects**: available to all device groups across all managed devices.
- Devices can belong to only one device group at each level of the hierarchy.

### Templates and Template Stacks
- **Templates** define network-level and device-level configuration: interfaces, zones, virtual routers, IKE/IPsec, DNS, NTP, SNMP, syslog server profiles, management profiles.
- Templates do NOT contain security policy (that's device groups).
- **Template Stacks**: collections of 1–8 templates applied to a firewall in priority order. Higher-priority templates override lower-priority templates for the same setting.
  - Stack order: Template 1 (highest) → Template 2 → ... → Template 8 (lowest).
  - A firewall can only be assigned to one template stack.
- **Best practice**: create a "global-base" template for settings common to all firewalls (NTP, DNS, syslog, management profiles) and a per-region or per-site template for location-specific settings (interfaces, zones, routing). Layer them in a stack.
- **Template variables**: allow a single template to be reused with per-device variable substitution (e.g., `$mgmt-ip-address`, `$loopback-ip`). Defined in the template stack and overridden per device.

### Log Collectors and Collector Groups
- Log Collectors receive, store, and forward logs from managed firewalls.
- Multiple Log Collectors can be grouped into a **Collector Group** for distributed storage and redundancy.
- Log Collectors process and index logs for Panorama queries and reports.
- M-200, M-500, M-600, M-700 appliances can run as Log Collectors.
- Log storage: typically RAID disk arrays in M-Series; virtual Panorama uses attached datastores.

### Panorama Commit Operations
- **Commit to Panorama**: saves changes to the Panorama candidate config and applies them to Panorama's running config (does NOT push to devices).
- **Push to Devices**: pushes the device group policy and template config from Panorama to managed firewalls.
- **Commit and Push**: combines both operations.
- Selective push: can push only to specific device groups, templates, or individual devices.
- **Commit All**: pushes to all managed devices — use with caution in large deployments.

---

## XML API

The PAN-OS XML API is the foundational programmatic interface — all GUI operations ultimately translate to XML API calls.

### Endpoint and Authentication
```
Base URL: https://<firewall-or-panorama>/api/
Authentication: ?key=<api-key>
Generate API key: GET /api/?type=keygen&user=<user>&password=<pass>
```

### Request Types
- `type=op` — Operational commands (equivalent to CLI operational mode).
  ```
  /api/?type=op&cmd=<show><system><info></info></system></show>
  ```
- `type=config` — Configuration operations (get, set, edit, delete, rename, move).
  ```
  /api/?type=config&action=get&xpath=/config/devices/entry[@name='localhost.localdomain']
  /api/?type=config&action=set&xpath=...&element=<entry name="test">...</entry>
  ```
- `type=commit` — Commit the candidate configuration.
  ```
  /api/?type=commit&cmd=<commit></commit>
  ```
- `type=import` — Upload files (certificates, content updates, configs).
- `type=export` — Export configs, logs, pcaps.
- `type=log` — Retrieve log entries with optional filters.
- `type=report` — Run predefined or custom reports.

### XPath Notation
XML API uses XPath to navigate the configuration tree:
```
/config/devices/entry[@name='localhost.localdomain']/vsys/entry[@name='vsys1']/rulebase/security/rules/entry[@name='allow-web']
```
For Panorama, device group policy:
```
/config/devices/entry[@name='localhost.localdomain']/device-group/entry[@name='<dg>']/pre-rulebase/security/rules
```

---

## REST API

Introduced as a more developer-friendly alternative to the XML API:
- Uses standard HTTP verbs (GET, POST, PUT, DELETE).
- Follows REST conventions with JSON or XML payloads.
- Available from PAN-OS 9.0 onward.
- Swagger/OpenAPI documentation available on-device: `https://<firewall>/restapi-doc/`
- Less mature than the XML API for some complex operations; XML API still preferred for automation at scale.
- Authentication: API key in header `X-PAN-KEY: <key>` or query parameter.

---

## Terraform Provider

- Official provider: `PaloAltoNetworks/panos` on the Terraform Registry.
- Manages firewall and Panorama resources as infrastructure-as-code.
- Supports: security policies, NAT rules, address objects, security profiles, interfaces, zones, VPN configs, and more.
- Uses the XML API under the hood via the `pan-go` SDK.
- Best practice: use the provider for managing policy and object configuration in a GitOps workflow; combine with Panorama templates for network config.
- **Important**: Terraform state must be carefully managed — drift between Terraform state and live firewall config can cause unexpected changes on apply.
- Validated Terraform modules available for VM-Series on AWS, Azure, GCP, and OCI.

---

## Ansible Collection

- Official collection: `paloaltonetworks.panos` on Ansible Galaxy.
- Certified by Red Hat Ansible Automation Platform since version 2.12.2.
- Modules for: security rules, NAT rules, objects, interfaces, zones, security profiles, operational tasks (commit, restart, content updates).
- Uses `pan-os-python` SDK under the hood.
- Example usage:
  ```yaml
  - name: Create security rule
    paloaltonetworks.panos.panos_security_rule:
      provider: "{{ provider }}"
      rule_name: "allow-web"
      source_zone: ["trust"]
      destination_zone: ["untrust"]
      application: ["web-browsing", "ssl"]
      action: "allow"
  ```
- **Connection**: modules connect to the firewall or Panorama management IP via HTTPS.

---

## Skillet Framework

Skillets are reusable configuration templates and automation building blocks for PAN-OS:

- Defined in YAML with embedded XML snippets.
- Used with the **Panhandler** tool (web UI) or **SLI (Skillet Library Interface)** CLI.
- **IronSkillet** is the most important skillet collection — Palo Alto's official Day 1 best-practice baseline configuration for NGFWs and Panorama.
- Skillets support:
  - Variable substitution (like Terraform variables).
  - Conditional logic (apply snippet only if condition is true).
  - Validation checks (verify config meets a standard).
  - Operational commands (not just configuration).
- Available on GitHub: `https://github.com/PaloAltoNetworks/iron-skillet`
- The **Best Practice Assessment (BPA)** tool is delivered as a skillet within the Expedition migration tool.
- Use cases: rapid deployment of security baselines, compliance validation, migration assistance.
