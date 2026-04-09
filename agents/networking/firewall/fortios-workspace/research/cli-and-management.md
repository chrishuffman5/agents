# FortiOS CLI and Management Reference

## 1. FortiOS CLI Fundamentals

### CLI Access Methods
- Console port (serial, 9600/8N1)
- SSH (port 22 by default; configurable)
- Telnet (disabled by default; not recommended)
- FortiExplorer mobile app (USB or Bluetooth)
- GUI terminal widget (browser-based SSH)

### CLI Structure
FortiOS CLI uses a hierarchical config tree. Three top-level modes:

**Global/System Config (`config system`)**
```
config system global
    set hostname <name>
    set timezone <zone>
    set admin-port <port>
    set admintimeout <minutes>
end
```

**Firewall Config (`config firewall`)**
```
config firewall policy
config firewall address
config firewall addrgrp
config firewall service custom
config firewall service group
config firewall vip
config firewall ippool
config firewall profile-protocol-options
config firewall ssl-ssh-profile
```

**Router Config (`config router`)**
```
config router static
config router bgp
config router ospf
config router isis
config router rip
config router policy
config router route-map
config router prefix-list
config router access-list
```

### Core CLI Navigation Commands
| Command | Description |
|---------|-------------|
| `config <path>` | Enter configuration context |
| `edit <id/name>` | Edit or create an object by ID or name |
| `set <key> <value>` | Set a parameter |
| `unset <key>` | Reset parameter to default |
| `get` | Display current context config |
| `show` | Show full config including defaults |
| `show full-configuration` | Show entire running config |
| `next` | Move to next item in a table (within edit loop) |
| `end` | Save and exit current config block |
| `abort` | Exit without saving changes |
| `rename <old> to <new>` | Rename an object |
| `clone <name> to <newname>` | Clone an object |
| `purge` | Remove all entries in current table |

### Get vs Show
- `get`: shows non-default settings; brief and focused
- `show`: shows all settings including defaults; verbose
- `show full-configuration`: dumps entire config (useful for backup/review)
- `get system status`: firmware version, serial, license info
- `get system performance status`: CPU, memory, sessions in real time

### Diagnose Commands (runtime/troubleshooting)
```bash
# System information
diagnose sys top                          # Live process list (like top)
diagnose sys top-mem                      # Memory usage by process
diagnose hardware sysinfo memory          # RAM details

# Session inspection
diagnose sys session list                 # Show all sessions (large output)
diagnose sys session filter src <IP>      # Set filter
diagnose sys session filter dst <IP>
diagnose sys session filter dport <port>
diagnose sys session clear               # Clear filter
diagnose sys session stat                # Session statistics

# Routing
diagnose ip route list                   # Kernel route table
get router info routing-table all        # Full routing table
get router info bgp summary              # BGP neighbor summary
get router info bgp neighbors            # BGP neighbor detail
get router info ospf neighbor            # OSPF neighbors
diagnose netlink route list              # Low-level route list

# Policy/traffic
diagnose debug flow filter addr <IP>     # Set flow debug filter
diagnose debug flow show console enable  # Enable console output
diagnose debug flow trace start 10       # Trace 10 packets
diagnose debug flow trace stop
diagnose debug disable

# Interface and packet capture
diagnose sniffer packet <iface> '<filter>' <verbosity> <count>
# Example: diagnose sniffer packet port1 'host 1.2.3.4' 4 100 l

# Hardware/NP
diagnose npu np7 session list            # NP7 offloaded sessions
diagnose npu np6 session list            # NP6 offloaded sessions
diagnose hardware deviceinfo nic <iface> # NIC hardware details

# VPN
diagnose vpn tunnel list                 # IKE/IPsec tunnels
diagnose vpn ike gateway list            # IKE gateways
diagnose debug application ike -1        # IKE debug logging

# HA
diagnose sys ha status                   # HA cluster status
diagnose sys ha dump-by-vcluster         # Per-VDOM HA info
get system ha status                     # Simple HA state

# SD-WAN
diagnose sys sdwan health-check status   # SLA health check status
diagnose sys sdwan member               # SD-WAN member details
diagnose sys sdwan service              # SD-WAN service rules match
```

### Configuration Backup and Restore
```bash
# CLI backup (saves to management PC via TFTP or SCP)
execute backup config tftp <filename> <server-IP>
execute backup config scp <filename> <server-IP> <user>

# Restore
execute restore config tftp <filename> <server-IP>

# Factory reset (destructive!)
execute factoryreset
```

---

## 2. FortiManager

### Architecture Overview
FortiManager provides centralized management for FortiGate, FortiSwitch, FortiAP, and FortiProxy devices.

**Three-layer management model:**
1. **Global ADOM layer**: organization-wide policy definitions; pushed down to ADOMs
2. **ADOM layer**: manages devices, VDOMs, or groups; contains policy packages and device DB
3. **Device Manager layer**: per-device configuration and status

### ADOMs (Administrative Domains)
- ADOMs partition management by customer, region, or organizational unit
- Each ADOM has its own: device list, policy packages, object database, administrators
- ADOM types: FortiGate, FortiCarrier, FortiProxy, FortiSwitch, FortiAP
- Default ADOM: `root` (cannot be deleted)
- ADOM versioning must match or be compatible with managed FortiOS version
- Recommended: one ADOM per FortiOS major version track (e.g., separate ADOM for 7.4 and 7.6 devices)

**ADOM Best Practices:**
- One policy package per managed device (avoid sharing across devices unless truly identical)
- Review Install Preview before any policy install
- Use ADOM revision history for change tracking and rollback
- Keep unused objects cleaned up periodically

### Policy Packages
- Containers for firewall policies, objects, and security profiles
- Can be organized in folders
- Installed to one or more devices/VDOMs
- Supports: policy reorder, clone, import/export between ADOMs
- Installation workflow: Edit in FortiManager → Generate Install Preview → Install to Device

### Device Database (Device DB)
- Stores per-device configuration managed by FortiManager
- Editable directly (if not locked by policy package)
- Covers: system settings, interfaces, routing, HA, VPN, SD-WAN
- Two editing modes:
  - **Normal mode**: FortiManager is authoritative; changes pushed to device
  - **Backup mode**: FortiGate is authoritative; FortiManager tracks but doesn't push

### Scripts and CLI Templates
- **Scripts**: Run CLI commands directly on devices; supports Jinja2 templating for dynamic values
- **CLI Templates**: Reusable templates applied to device groups; supports pre-run and post-run execution relative to policy install
- **Meta Variables**: ADOM-level variables (e.g., `$(hostname)`, `$(wan_ip)`) substituted at install time
- **Jinja2 Templates**: Logical flow (if/else, loops) in CLI templates for dynamic configuration generation

### SD-WAN Overlay Templates (7.4+)
- Replace the deprecated SD-WAN Orchestrator
- Define hub-spoke overlay topology (up to 4 hubs in 7.6)
- Configure BGP over overlay, ADVPN, and VRF segmentation
- Applied to device groups; generates per-device config on install
- FortiAI integration in 7.6 for intelligent overlay config assistance

### FortiManager CLI
```bash
# Connect via SSH to FortiManager
# FortiManager has its own CLI distinct from FortiOS

# Device management
execute device-manager get <device>
diagnose dvm device list

# Script execution
diagnose debug application fmpolicyd -1
diagnose test application fmpolicyd <num>

# Database
diagnose dvm adom list
diagnose dvm device upgrade-status <device>
```

### FortiManager API
- REST API available on `https://<fmg-ip>/jsonrpc`
- Authentication: username/password or API token
- Methods: `add`, `get`, `set`, `delete`, `exec`, `move`, `clone`
- Workflow for policy management:
  1. Lock ADOM workspace
  2. Make changes via API
  3. Commit workspace
  4. Install policy package

---

## 3. FortiAnalyzer

### Log Management Architecture
- Centralized log storage and indexing for Fortinet devices
- Supports: FortiGate, FortiProxy, FortiSwitch, FortiAP, FortiClient, FortiMail
- Log types: traffic, security (IPS, AV, webfilter, app control), event, VPN, DNS

### Log Storage and Querying
- Logs stored in local disk or RAID array
- FortiView: real-time and historical traffic dashboards
- Log View: raw log search with filters; supports regex
- Reports: scheduled reports with templates (PDF, HTML, CSV)

### FortiSOC
- Security Operations Center module within FortiAnalyzer
- **Incidents & Events**: correlation engine; maps events to MITRE ATT&CK
- **Playbooks**: automated response actions triggered by events
- Playbook actions include: quarantine endpoint, block IP, create ticket, send email
- **FortiSOAR integration**: deep SOAR capabilities via connected FortiSOAR instance

### FortiAnalyzer Key CLI Commands
```bash
# Check log receive rate
diagnose fortilogd lograte

# Storage status
diagnose fortilogd disk

# Event correlation status
diagnose test application logd 1

# Playbook status
diagnose automation-stitch list
```

### FortiAnalyzer API
- JSON-RPC API similar to FortiManager
- Used to query logs, manage devices, trigger reports
- Authentication: API token preferred

---

## 4. REST API

### Overview
FortiOS exposes a comprehensive REST API for programmatic management.

**Base URL:** `https://<fortigate-ip>/api/v2/`

**API Categories:**
- `cmdb` (Configuration Management DB): read/write config objects
- `monitor`: real-time status data (sessions, routing, VPN status)
- `log`: log queries

### API Token Authentication
1. Create API user: **System > Administrators > Create New > REST API Admin**
2. Assign access profile and trusted hosts (IP restriction)
3. Generate token: GUI provides token at creation time (shown once)
4. Use in requests:

```bash
# Token in header (preferred)
curl -k -H "Authorization: Bearer <token>" \
  "https://192.168.1.1/api/v2/cmdb/firewall/policy/"

# Token as URL parameter (legacy)
curl -k "https://192.168.1.1/api/v2/cmdb/firewall/policy/?access_token=<token>"
```

### Common API Examples
```bash
# Get all firewall policies
GET /api/v2/cmdb/firewall/policy/

# Get specific policy by ID
GET /api/v2/cmdb/firewall/policy/1

# Create policy (POST with JSON body)
POST /api/v2/cmdb/firewall/policy/

# Update policy (PUT)
PUT /api/v2/cmdb/firewall/policy/1

# Delete policy
DELETE /api/v2/cmdb/firewall/policy/1

# Get routing table (monitor)
GET /api/v2/monitor/router/ipv4/

# Get SD-WAN health check status
GET /api/v2/monitor/system/link-monitor/

# Get active sessions
GET /api/v2/monitor/firewall/session/
```

---

## 5. Ansible — fortinet.fortios Collection

### Installation
```bash
ansible-galaxy collection install fortinet.fortios
```

### Authentication Methods
- **Username/password** via `ansible_httpapi_pass`
- **API token** via `ansible_httpapi_session_key` (preferred):
  ```yaml
  ansible_httpapi_session_key:
    access_token: "YOUR_TOKEN_HERE"
  ```

### Inventory Example
```yaml
# inventory.yml
fortigates:
  hosts:
    fortigate01:
      ansible_host: 192.168.1.1
      ansible_user: admin
      ansible_password: "{{ vault_fg_password }}"
      ansible_connection: httpapi
      ansible_httpapi_use_ssl: true
      ansible_httpapi_validate_certs: false
      ansible_network_os: fortinet.fortios.fortios
      vdom: root
```

### Example Playbook
```yaml
- name: Configure FortiGate firewall policy
  hosts: fortigates
  collections:
    - fortinet.fortios
  tasks:
    - name: Ensure address object exists
      fortios_firewall_address:
        vdom: root
        state: present
        firewall_address:
          name: "web-server"
          type: ipmask
          subnet: "10.1.1.10/32"

    - name: Create firewall policy
      fortios_firewall_policy:
        vdom: root
        state: present
        firewall_policy:
          policyid: 100
          name: "allow-web"
          srcintf:
            - name: "port1"
          dstintf:
            - name: "port2"
          srcaddr:
            - name: "all"
          dstaddr:
            - name: "web-server"
          action: accept
          schedule: "always"
          service:
            - name: "HTTP"
            - name: "HTTPS"
          logtraffic: all
```

### Key Modules
- `fortios_firewall_policy` — Firewall policies
- `fortios_firewall_address` — Address objects
- `fortios_firewall_service_custom` — Custom services
- `fortios_system_interface` — Interface configuration
- `fortios_router_static` — Static routes
- `fortios_router_bgp` — BGP configuration
- `fortios_vpn_ipsec_phase1_interface` — IPsec Phase1
- `fortios_vpn_ipsec_phase2_interface` — IPsec Phase2
- `fortios_system_vdom` — VDOM management
- `fortios_firewall_ssl_ssh_profile` — SSL inspection profiles

---

## 6. Terraform — fortinetdev/fortios Provider

### Provider Configuration
```hcl
terraform {
  required_providers {
    fortios = {
      source  = "fortinetdev/fortios"
      version = "~> 1.18"
    }
  }
}

provider "fortios" {
  hostname = "192.168.1.1"
  token    = var.fortios_token
  insecure = true   # Set false in production with valid cert
  vdom     = "root"
}
```

### Environment Variables (alternative to provider block)
```bash
export FORTIOS_ACCESS_HOSTNAME="192.168.1.1"
export FORTIOS_ACCESS_TOKEN="your-api-token"
export FORTIOS_INSECURE="true"
```

### Example Resources
```hcl
resource "fortios_firewall_address" "web_server" {
  name    = "web-server"
  type    = "ipmask"
  subnet  = "10.1.1.10 255.255.255.255"
}

resource "fortios_firewall_policy" "allow_web" {
  policyid = 100
  name     = "allow-web"
  srcintf {
    name = "port1"
  }
  dstintf {
    name = "port2"
  }
  srcaddr {
    name = "all"
  }
  dstaddr {
    name = fortios_firewall_address.web_server.name
  }
  action   = "accept"
  schedule = "always"
  service {
    name = "HTTP"
  }
  logtraffic = "all"
}
```

---

## 7. FortiExplorer (Mobile Management)

FortiExplorer is Fortinet's mobile management app (iOS/Android):
- Connect via USB to FortiGate (local, no network required)
- Connect via Bluetooth (on supported models)
- Initial setup wizard: interfaces, admin password, licensing
- Quick status view: CPU, memory, interfaces, HA status
- Limited configuration; intended for initial setup and on-site diagnostics
- Upgrade firmware directly from mobile device
- Compatible with most FortiGate desktop/rack models
