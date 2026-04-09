# Cisco FTD and ASA CLI and Management Reference

## FTD CLI Architecture

### Two CLI Contexts

FTD has two distinct CLI environments that serve different purposes:

**1. FTD CLISH (Expert CLI / Native CLI)**

The primary FTD management CLI, accessed via SSH or console. This is NOT the ASA CLI. It is purpose-built for FTD management.

```
> show version
> show interface
> show route
> show managers
> configure manager add <FMC_IP> <reg_key>
> configure network ipv4 manual <ip> <mask> <gw> management0
> system support diagnostic-cli
```

CLISH commands start with verbs like `show`, `configure`, `debug`, `system`, `expert`. Tab completion is available. This is where most operational tasks are performed.

**2. LINA (ASA CLI via Diagnostic Mode)**

Access the underlying ASA engine:

```
> system support diagnostic-cli
Entering diagnostic CLI. Use 'exit' to return to Firepower CLI.
Type help or '?' for a list of available commands.

firepower#
```

In diagnostic-cli mode, you have full ASA CLI access. This is where ASA-style `show` commands, packet-tracer, captures, and LINA debugging occur.

**Important**: Configuration changes made in diagnostic-cli are typically overwritten on the next FMC policy deploy. Diagnostic-cli is for **read-only diagnostics and temporary troubleshooting**, not persistent configuration.

---

## FTD CLISH Command Reference

### System and Version

```bash
show version                          # FTD software version, LINA version, Snort version
show disk                             # Disk usage
show cpu                              # CPU utilization
show memory                           # Memory utilization
show processes                        # Running processes (lina, snort, sftunnel, etc.)
show cluster info                     # Cluster status (if clustered)
show high-availability info           # HA status (if HA pair)
```

### Network Configuration

```bash
show network                          # Management interface IP, gateway, DNS
show interface                        # Interface status (CLISH-level)
configure network ipv4 manual <ip> <mask> <gw> management0
configure dns servers <dns1> <dns2>
configure hostname <name>
configure timezone <zone>
```

### FMC Registration

```bash
show managers                         # Show FMC registration status
configure manager add <FMC_IP> <reg_key> [nat_id]   # Register to FMC
configure manager delete              # De-register from FMC
configure manager local               # Switch to local (FDM) management
```

### Snort Engine

```bash
show snort status                     # Snort process status
show snort statistics                 # Packet stats through Snort
show snort counters                   # Drop/allow counters per Snort instance
system support trace                  # Trace packet through Snort (requires sudo)
```

### Expert Mode (Linux Shell)

```bash
expert                                # Drop to Linux bash shell
sudo su -                            # Become root (careful)
tail -f /ngfw/var/log/messages        # System log
cat /ngfw/var/log/sftunnel.log        # sftunnel communication log
```

---

## LINA (ASA-mode) Diagnostic Commands

These commands run inside `system support diagnostic-cli`:

### Connection and State Table

```bash
show conn                             # Active connections
show conn count                       # Count of active connections
show conn address <IP>                # Connections for specific IP
show conn long                        # Detailed connection info with flags
show xlate                            # NAT translation table
show xlate count                      # Count of NAT translations
show conn state tcp                   # TCP connections with state flags
```

**Connection table flags** (important for troubleshooting):
- `A` — Awaiting inside ACK
- `B` — Half-open (waiting for SYN-ACK)
- `U` — UDP
- `E` — outside ACK waiting
- `o` — outbound data
- `i` — inbound data
- `I` — Inbound  
- `M` — SMTP data
- `D` — DNS
- `f` — FIN wait
- `R` — reset flag

### ASP (Accelerated Security Path) Drop Analysis

The ASP table shows **why packets are being dropped**. This is critical for diagnosing traffic issues.

```bash
show asp drop                         # All drop reasons with packet counts
show asp drop count                   # Summary counts only
clear asp drop                        # Reset counters (use carefully)
show asp table classify domain permit # View current ASP permit rules
show asp table classify domain deny   # View current ASP deny rules
show asp table routing                # ASP routing table (what's in hardware)
show asp table arp                    # ASP ARP table
show asp table vpn-context            # VPN crypto contexts
```

**Common ASP drop reasons**:
| Drop Reason | Meaning |
|---|---|
| `acl-drop` | Dropped by ACL/ACP rule |
| `inspect-dns-pak-too-long` | DNS packet exceeds size limit |
| `nat-no-xlate-to-pat-pool` | No PAT pool addresses available |
| `no-route` | No route to destination |
| `reverse-path-failed` | RPF check failed (uRPF configured) |
| `tcp-not-syn` | Non-SYN TCP packet for non-existent connection |
| `flow-expired` | Connection timed out |
| `snort-drop` | Dropped by Snort IPS |
| `snort-resp-drop` | Dropped by Snort file/malware policy |
| `vpn-failed` | VPN processing failure |
| `mp-svc-no-session` | AnyConnect session not found |
| `inspect-icmp-seq-num-not-matched` | ICMP sequence mismatch |

### Packet Capture

```bash
# Create a capture on an interface
capture CAPIN interface inside match ip host 10.1.1.1 any
capture CAPOUT interface outside match ip any host 203.0.113.1

# View capture
show capture CAPIN
show capture CAPIN detail               # Full packet decode
show capture CAPIN dump                 # Hex dump

# Export via HTTP (LINA web server)
# Navigate to: https://<mgmt_ip>/capture/CAPIN/pcap

# ASP drop capture (capture dropped packets)
capture ASP_CAP type asp-drop all
show capture ASP_CAP
```

### Packet Tracer

`packet-tracer` simulates a packet through the firewall and shows each processing step. Essential for policy validation and troubleshooting.

```bash
packet-tracer input outside tcp 203.0.113.50 12345 10.1.1.10 443

# With NAT:
packet-tracer input outside tcp 203.0.113.50 12345 203.0.113.10 443 detailed

# UDP:
packet-tracer input inside udp 10.1.1.100 5000 8.8.8.8 53

# ICMP:
packet-tracer input inside icmp 10.1.1.100 8 0 8.8.8.8
```

**Output phases**:
- `Phase 1: ROUTE-LOOKUP` — Routing decision
- `Phase 2: ACCESS-LIST` — ACL/ACP evaluation
- `Phase 3: IP-OPTIONS` — IP options check
- `Phase 4: NAT` — NAT translation
- `Phase 5: VPN` — VPN processing
- `Phase 6: IP-OPTIONS` — Post-NAT options
- `Phase 7: ACCESS-LIST` — Post-NAT ACL check
- `Phase 8: CONN-SETTINGS` — Connection settings
- `Phase 9: SNORT` — Snort verdict (if applicable)
- `Phase 10: ROUTE-LOOKUP` — Egress route
- `Phase 11: ADJACENCY` — ARP/MAC resolution
- Final: `ALLOW` or `DROP` with reason

### Interface and Route Commands

```bash
show interface <ifname>               # Interface stats (errors, drops, throughput)
show interface ip brief               # All interfaces with IP summary
show route                            # Routing table
show route <ip>                       # Route for specific destination
show ip                               # Interface IP summary
show arp                              # ARP table
show mac-address-table                # MAC address table (transparent mode)
```

### VPN Commands

```bash
show vpn-sessiondb                    # All active VPN sessions
show vpn-sessiondb anyconnect         # AnyConnect sessions
show vpn-sessiondb l2l                # Site-to-site VPN sessions
show vpn-sessiondb detail anyconnect  # Detailed AnyConnect session info
show crypto isakmp sa                 # IKEv1 SA status
show crypto ikev2 sa                  # IKEv2 SA status
show crypto ipsec sa                  # IPsec SA status
debug crypto ikev2 protocol 5        # IKEv2 protocol debugging
debug crypto ipsec 5                  # IPsec debugging
show running-config crypto            # VPN crypto configuration
```

### Threat Detection

```bash
show threat-detection statistics      # Threat detection stats (scanning, DoS)
show threat-detection scanning-threat # Active scanning threat entries
show threat-detection rate            # Per-host rate stats
```

---

## FMC GUI Workflow

### Policy Management Workflow

1. **Devices** → Device Management → Verify device registered and health status green
2. **Policies** → Access Control → Edit policy → Add/modify rules
3. **Policies** → NAT → Edit NAT policy
4. **Policies** → Intrusion → Edit intrusion policy (Snort 3 rules)
5. **Policies** → SSL → Edit SSL policy (decryption rules)
6. **Policies** → Identity → Edit identity policy
7. **Devices** → Device Management → Select device → **Deploy** (lightning bolt)
8. Monitor deployment status in Deploy dialog

### Key FMC Navigation Areas

- **Overview** → Dashboards → Summary Dashboard (connection, threat, URL stats)
- **Analysis** → Connections → Events (real-time connection event search)
- **Analysis** → Intrusions → Events (IPS alerts)
- **Analysis** → Files → Malware Events (AMP detections)
- **Objects** → Object Management → Networks, Ports, URLs, Security Groups (manage reusable objects)
- **Devices** → Platform Settings → Syslog, SNMP, NTP, DNS settings
- **System** → Updates → Rule and Software Updates

---

## REST API

### FMC REST API

**Base URL**: `https://<FMC_IP>/api/fmc_config/v1/domain/<Domain_UUID>/`

**Authentication**:
```bash
# Get auth token
POST https://<FMC_IP>/api/fmc_platform/v1/auth/generatetoken
# Headers: Authorization: Basic <base64(username:password)>
# Response headers: X-auth-access-token, X-auth-refresh-token, DOMAIN_UUID

# Use token in subsequent requests:
# Header: X-auth-access-token: <token>
```

**Token details**:
- Valid for 30 minutes
- Refreshable up to 3 times (use `POST /auth/refreshtoken` with both token headers)
- Max 5 concurrent sessions per user

**Rate limits**:
- Pre-7.6: 120 requests/minute
- 7.6+: 300 requests/minute

**Key endpoints**:
```
GET  /domain/{did}/devices/devicerecords          # List devices
GET  /domain/{did}/policy/accesspolicies          # List ACP policies  
POST /domain/{did}/policy/accesspolicies          # Create ACP policy
GET  /domain/{did}/policy/accesspolicies/{id}/accessrules  # List rules
POST /domain/{did}/policy/accesspolicies/{id}/accessrules  # Create rule
GET  /domain/{did}/object/networks                # List network objects
POST /domain/{did}/object/networks                # Create network object
POST /domain/{did}/deployment/deploymentrequests  # Deploy policy to device
GET  /domain/{did}/deployment/deployabledevices   # List devices with pending changes
```

**API Explorer**: Available at `https://<FMC_IP>/api/api-explorer/` — interactive Swagger-UI for exploring all endpoints.

### FTD REST API (On-box)

**Base URL**: `https://<FTD_IP>/api/fdm/latest/` (latest) or `/api/fdm/v1/`

**Authentication (OAuth)**:
```bash
POST /fdm/latest/fdm/token
{
  "grant_type": "password",
  "username": "admin",
  "password": "<password>"
}
# Returns: access_token (bearer token)
```

**Key FTD REST API endpoints** (FDM-managed devices):
```
GET  /object/networks            # Network objects
GET  /policy/accesspolicies      # Access policies
GET  /devices/default            # Device info
POST /operational/deploy         # Deploy pending changes
```

**Limitation**: FTD REST API applies to **FDM-managed** devices only. FMC-managed devices use FMC REST API exclusively.

---

## Ansible Automation (cisco.fmcansible)

### Collection: cisco.fmcansible

- Official Ansible collection from Cisco DevNet
- Automates FMC configuration via FMC REST API
- Supports both on-premises FMC and cdFMC (Bearer token auth for cdFMC)

**Installation**:
```bash
ansible-galaxy collection install cisco.fmcansible
```

**Key modules**:
- `fmc_configuration` — Generic module to configure any FMC API endpoint
- `fmc_facts` — Gather facts from FMC (devices, policies, objects)

**Example — Create network object**:
```yaml
- name: Create network object
  cisco.fmcansible.fmc_configuration:
    operation: createNetworkObject
    data:
      name: INTERNAL_NET
      value: 10.1.1.0/24
      type: Network
    register_as: net_obj
```

**Example — Deploy policy**:
```yaml
- name: Deploy pending changes
  cisco.fmcansible.fmc_configuration:
    operation: createDeploymentRequest
    data:
      type: DeploymentRequest
      version: "{{ device_version }}"
      forceDeploy: false
      deviceList:
        - "{{ device_id }}"
```

**Authentication variables**:
```yaml
vars:
  ansible_network_os: cisco.fmcansible.fmc
  ansible_host: "{{ fmc_ip }}"
  ansible_user: admin
  ansible_password: "{{ vault_password }}"
  ansible_httpapi_validate_certs: false
  ansible_httpapi_use_ssl: true
```

---

## Terraform Provider

### CiscoDevNet Terraform Provider for FMC

**Repository**: `github.com/CiscoDevNet/terraform-provider-fmc`

**Installation** (Terraform registry):
```hcl
terraform {
  required_providers {
    fmc = {
      source  = "CiscoDevNet/fmc"
      version = "~> 1.0"
    }
  }
}

provider "fmc" {
  fmc_host            = "10.1.1.100"
  fmc_username        = "admin"
  fmc_password        = var.fmc_password
  fmc_insecure_skip_verify = false
}
```

**Key resources**:
```hcl
resource "fmc_network_objects" "internal" {
  name        = "INTERNAL_NET"
  value       = "10.1.1.0/24"
  description = "Internal network"
}

resource "fmc_access_policies" "main" {
  name           = "Main_ACP"
  default_action = "BLOCK"
}

resource "fmc_access_rules" "allow_http" {
  acp       = fmc_access_policies.main.id
  name      = "Allow_HTTP"
  action    = "ALLOW"
  source_networks {
    source_network {
      id   = fmc_network_objects.internal.id
      type = "Network"
    }
  }
  destination_ports {
    destination_port {
      protocol = "TCP"
      port     = "80"
    }
  }
}
```

---

## CDO (Cisco Security Cloud Control) Management

Formerly **Cisco Defense Orchestrator (CDO)** — renamed in 2024.

**Capabilities**:
- Cloud-based multi-device management portal
- Manages FTD devices (FDM-managed or cdFMC-registered)
- Manages ASA devices directly
- Bulk policy changes across multiple devices
- Change management with ticketing integration
- Device templates for bulk provisioning (7.6+)

**Access**: `app.security.cisco.com`

**FTD integration modes**:
1. **FDM-managed via CDO**: FTD managed by FDM; CDO provides cloud access/orchestration
2. **cdFMC via CDO**: FTD registered to cloud-delivered FMC (hosted in CDO)

**Diagnostic CLI via CDO**:
CDO provides browser-based CLI access to FTD devices — can run `system support diagnostic-cli` equivalents from CDO web UI without direct SSH access.

---

## Common Troubleshooting Commands Reference

### Quick Diagnostic Workflow

**Step 1: Verify connectivity to FMC**
```bash
# On FTD CLISH:
show managers
ping system <FMC_IP>
```

**Step 2: Check if traffic is hitting the firewall**
```bash
# In diagnostic-cli:
show interface <ifname>               # Check input/output packet counters
capture TEST interface outside match ip host <src> any
```

**Step 3: Trace the packet**
```bash
packet-tracer input outside tcp <src_ip> 12345 <dst_ip> 443 detailed
```

**Step 4: Check ASP drops**
```bash
show asp drop
# Look for relevant interface or counter spike
# Use: capture ASP_CAP type asp-drop acl-drop
```

**Step 5: Check connection table**
```bash
show conn address <IP>
show xlate                            # Verify NAT is translating correctly
```

**Step 6: Check routes**
```bash
show route <destination_ip>
show asp table routing                # What's in the datapath routing table
```

**Step 7: Check VPN (if applicable)**
```bash
show crypto ikev2 sa
show crypto ipsec sa
show vpn-sessiondb l2l
```

### Snort-Specific Troubleshooting (CLISH)

```bash
show snort status                     # Are all Snort instances running?
show snort statistics                 # Passed, dropped, blocked counters
```

**Check for Snort drops in ASP**:
```bash
show asp drop | include snort         # Filter ASP drops for Snort-related reasons
```

**Snort fast-path and traffic flow**:
```bash
system support trace                  # Interactive packet trace through Snort (Snort verdict)
```

### FTD Health Monitoring

```bash
show disk                             # Check disk (>90% triggers HA failover!)
show cpu usage system                 # CPU per process
show memory system detail             # Memory breakdown
show cluster info                     # Cluster health (if applicable)
show failover                         # HA failover status
show failover statistics              # Failover event history
```

### Log Files (Expert/Root Access)

```bash
expert
sudo tail -f /ngfw/var/log/messages           # System messages
sudo tail -f /ngfw/var/log/sftunnel.log        # FMC-FTD tunnel
sudo tail -f /ngfw/var/log/action_queue.log    # Policy deploy queue
sudo cat /ngfw/etc/ngfw.conf                   # FTD configuration metadata
```

---

## Sources

- [FTD CLI Reference — Cisco](https://www.cisco.com/c/en/us/td/docs/security/firepower/command_ref/b_Command_Reference_for_Firepower_Threat_Defense/using_the_FTD_CLI.html)
- [FTD Captures and Packet Tracer — Cisco](https://www.cisco.com/c/en/us/support/docs/security/firepower-ngfw/212474-working-with-firepower-threat-defense-f.html)
- [show asp drop Command Usage — Cisco](https://www.cisco.com/c/en/us/td/docs/security/asa/asa-cli-reference/show_asp_drop_command_usage/show-asp-drop-command-usage.html)
- [FTD Routing Troubleshooting — Cisco](https://www.cisco.com/c/en/us/support/docs/security/firepower-ngfw/217802-troubleshoot-firepower-threat-defense-ro.html)
- [Traffic Drops Due to LINA Inspection — Cisco](https://www.cisco.com/c/en/us/support/docs/security/secure-firewall-threat-defense/222904-troubleshoot-traffic-drops-due-to-lina-p.html)
- [FMC REST API Authentication — Cisco](https://www.cisco.com/c/en/us/support/docs/security/firepower-management-center/215918-how-to-generate-authentication-token-for.html)
- [FTD REST API Guide — Cisco](https://www.cisco.com/c/en/us/td/docs/security/firepower/ftd-api/guide/ftd-rest-api.html)
- [FMC REST API Token Auth — Cisco Learning](https://ciscolearning.github.io/cisco-learning-codelabs/posts/fmc-rest-token-authentication/)
- [FMC Ansible Collection — Cisco DevNet](https://developer.cisco.com/docs/fmc-ansible/getting-started/)
- [FMC Ansible Introduction — Cisco DevNet](https://developer.cisco.com/docs/fmc-ansible/introduction/)
- [Terraform Provider for FMC — GitHub](https://github.com/CiscoDevNet/terraform-provider-fmc)
- [CDO Managing FDM Devices — Cisco](https://www.cisco.com/c/en/us/td/docs/security/cdo/managing-ftd-with-cdo/managing-ftd-with-cisco-defense-orchestrator/managing-ftd-with-cdo.html)
- [Diagnostic CLI from CDO Web Interface](https://docs.defenseorchestrator.com/cdfmc/t_using_the_cli_from_the_web_interface.html)
- [FTD FMC REST API Rate Limit — Cisco Community](https://community.cisco.com/t5/network-security/rest-api-rate-limit/td-p/3383195)
- [fireREST Python Library — PyPI](https://pypi.org/project/fireREST/)
- [FMC REST API CodeLab — GitHub](https://github.com/CiscoDevNet/fmc-rest-api)
