# Ansible Network Architecture Reference

## Ansible Network Execution Model

### How Ansible Connects to Network Devices

Unlike server automation (where Ansible SSHs in and runs Python on the target), network automation uses specialized connection plugins that run modules locally on the Ansible control node:

```
Ansible Control Node
  ├── Loads playbook and inventory
  ├── Determines connection plugin per host (network_cli, netconf, httpapi)
  ├── Establishes connection to device (SSH or HTTPS)
  ├── Sends commands/config and receives responses
  ├── Processes responses locally (parsing, state comparison)
  └── Reports results (changed/ok/failed)
```

Key difference from server automation: **no Python runs on the network device**. The control node does all processing.

### Connection Plugin Internals

**network_cli:**
1. Opens SSH connection to device
2. Detects device prompt (IOS: `Router#`, EOS: `hostname#`, etc.)
3. Sends CLI commands and captures output
4. Parses text output into structured data (using module-specific parsers)
5. Compares current state vs desired state
6. Sends configuration commands if changes needed
7. Captures and reports results

**netconf:**
1. Opens SSH connection to port 830 (NETCONF subsystem)
2. Exchanges NETCONF hello (capability negotiation)
3. Sends XML RPC operations (get-config, edit-config, commit)
4. Receives structured XML responses
5. Parses XML into Python data structures
6. No text parsing needed -- data is already structured

**httpapi:**
1. Opens HTTPS connection to device REST API
2. Authenticates (API key, username/password, token)
3. Sends HTTP requests (GET, POST, PUT, DELETE) with JSON/XML body
4. Receives structured JSON/XML responses
5. Maps response data to module output

## Collection Architecture

### Collection Structure
```
cisco.ios/
  ├── plugins/
  │   ├── modules/
  │   │   ├── ios_vlans.py           # VLAN resource module
  │   │   ├── ios_interfaces.py      # Interface resource module
  │   │   ├── ios_command.py          # Run CLI commands
  │   │   ├── ios_config.py           # Push config lines
  │   │   └── ios_facts.py            # Gather device facts
  │   ├── module_utils/
  │   │   ├── network/
  │   │   │   └── ios/
  │   │   │       ├── config/
  │   │   │       │   ├── vlans/      # VLAN config parser
  │   │   │       │   └── interfaces/ # Interface config parser
  │   │   │       └── facts/          # Facts parser
  │   │   └── argspec/                # Module argument specifications
  │   ├── cliconf/
  │   │   └── ios.py                  # CLI configuration plugin (prompt handling)
  │   └── terminal/
  │       └── ios.py                  # Terminal plugin (connection handling)
  ├── roles/                          # Bundled roles (optional)
  └── meta/
      └── runtime.yml                 # Collection metadata
```

### Resource Module Internals

Resource modules follow a standard architecture:

1. **Argspec**: Defines the module's accepted parameters (config schema)
2. **Facts gathering**: Module reads current device config (via CLI or API)
3. **Config parser**: Converts device output into normalized data structure
4. **State comparison**: Compares current state vs desired state (using the `state` parameter)
5. **Command generation**: Generates the CLI/API commands needed to achieve desired state
6. **Execution**: Sends commands to device (or returns them in check mode)

This architecture ensures idempotency: if current state matches desired state, no commands are generated.

### Multi-Platform Resource Module Consistency

All vendor resource modules follow the same interface pattern:
```yaml
# cisco.ios.ios_vlans
- cisco.ios.ios_vlans:
    config:
      - vlan_id: 10
        name: MGMT
    state: merged

# arista.eos.eos_vlans
- arista.eos.eos_vlans:
    config:
      - vlan_id: 10
        name: MGMT
    state: merged

# Same structure, same state options, same behavior
```

This consistency enables multi-vendor playbooks with minimal per-platform variation.

## Detailed Collection Reference

### cisco.ios (IOS / IOS-XE)

**Connection:** `network_cli` (SSH)

**Key resource modules:**
- `ios_vlans`: VLAN ID, name, state (active/suspend), shutdown
- `ios_interfaces`: Name, description, speed, duplex, MTU, enabled
- `ios_l2_interfaces`: Access VLAN, trunk allowed VLANs, native VLAN
- `ios_l3_interfaces`: IPv4/IPv6 addresses, secondary addresses
- `ios_ospfv2`: OSPF processes, areas, networks, passive interfaces
- `ios_ospfv3`: OSPFv3 for IPv6
- `ios_bgp_global`: BGP AS, router-id, neighbors, address families
- `ios_bgp_address_family`: Per-AF configuration (networks, redistribution)
- `ios_acls`: Standard and extended ACLs
- `ios_prefix_lists`: IP prefix lists
- `ios_route_maps`: Route maps with match/set clauses
- `ios_static_routes`: Static routes with next-hop, admin distance
- `ios_ntp_global`: NTP server configuration
- `ios_logging_global`: Logging configuration (syslog servers, buffer)
- `ios_snmp_server`: SNMP community, host, trap configuration
- `ios_hostname`: System hostname

**Utility modules:**
- `ios_command`: Execute show/operational commands
- `ios_config`: Push raw config lines (less preferred than resource modules)
- `ios_facts`: Gather device facts and network resources
- `ios_ping`: Execute ping from device

### cisco.nxos (NX-OS)

**Connection:** `network_cli` (SSH) or `httpapi` (NX-API)

NX-OS supports both connection types. httpapi (NX-API) is preferred for:
- Structured JSON output (no text parsing)
- Better performance for bulk operations
- Parallel API calls

NX-API must be enabled on the switch:
```
feature nxapi
```

**Key resource modules:** Mirror ios modules with `nxos_` prefix. Additionally:
- `nxos_vrf`: VRF configuration
- `nxos_vrf_interfaces`: VRF-to-interface assignment
- `nxos_vpc`: Virtual Port Channel configuration
- `nxos_feature`: Enable/disable NX-OS features

### arista.eos (Arista EOS)

**Connection:** `httpapi` (eAPI, preferred) or `network_cli` (SSH)

eAPI returns native JSON, making it the preferred connection:
```yaml
ansible_connection: httpapi
ansible_network_os: arista.eos.eos
ansible_httpapi_use_ssl: true
ansible_httpapi_validate_certs: false
```

eAPI must be enabled:
```
management api http-commands
   no shutdown
```

**Key resource modules:** Mirror standard resource module interface with `eos_` prefix.

### junipernetworks.junos (Junos)

**Connection:** `netconf` (exclusively for configuration modules)

Junos is unique in that nearly all automation uses NETCONF:
```yaml
ansible_connection: netconf
ansible_network_os: junipernetworks.junos.junos
```

NETCONF must be enabled:
```
set system services netconf ssh
```

**Key modules:**
- `junos_config`: Load configuration in set/text/XML format with commit model
- `junos_command`: Run operational commands
- `junos_facts`: Gather facts
- `junos_interfaces`, `junos_vlans`, etc.: Standard resource modules

**Junos commit model:**
Junos uses a candidate/commit configuration model:
- `junos_config` with `update: merge` modifies candidate config
- `commit: true` applies candidate to running config
- `rollback: 1` reverts to previous committed config
- This is inherently safer than IOS's immediate-apply model

## Jinja2 Template Architecture

### Template Pipeline

```
Data Model (YAML variables)
  + Template (Jinja2 .j2 file)
  = Generated Configuration (device-ready text)
```

### Advanced Jinja2 Patterns

**Conditional sections:**
```jinja2
{% if ospf is defined %}
router ospf {{ ospf.process_id }}
 router-id {{ ospf.router_id }}
 {% for network in ospf.networks %}
 network {{ network.prefix }} {{ network.wildcard }} area {{ network.area }}
 {% endfor %}
{% endif %}
```

**Nested loops:**
```jinja2
{% for vrf in vrfs %}
ip vrf {{ vrf.name }}
 rd {{ vrf.rd }}
 {% for rt in vrf.route_targets %}
 route-target {{ rt.direction }} {{ rt.value }}
 {% endfor %}
!
{% endfor %}
```

**Filters for network operations:**
```jinja2
{{ '10.0.0.0/24' | ansible.utils.ipaddr('network') }}     {# 10.0.0.0 #}
{{ '10.0.0.0/24' | ansible.utils.ipaddr('netmask') }}      {# 255.255.255.0 #}
{{ '10.0.0.5/24' | ansible.utils.ipaddr('host') }}          {# 10.0.0.5 #}
{{ prefix | ansible.utils.ipsubnet(28, 0) }}                 {# First /28 subnet #}
```

**ansible.utils.ipaddr filter family** is essential for network automation:
- Convert between prefix notation and netmask
- Calculate subnets, hosts, broadcast addresses
- Validate IP addresses and prefixes

### Template Testing
```yaml
# Generate config without connecting to device
- name: Test template output
  cisco.ios.ios_vlans:
    config: "{{ vlan_data }}"
    state: rendered
  register: rendered_config

- name: Show what would be configured
  debug:
    var: rendered_config.rendered
```

## Config Backup Architecture

### Backup Strategies

**Per-run backup (Ansible ios_config):**
```yaml
- cisco.ios.ios_config:
    backup: yes
    backup_options:
      filename: "{{ inventory_hostname }}_{{ '%Y%m%d_%H%M' | strftime }}.cfg"
      dir_path: "/backups/"
```

**Dedicated backup tools:**
- **Oxidized**: Ruby-based; connects to devices on schedule, stores configs in Git
- **RANCID**: Perl-based; legacy but widely deployed; stores configs in CVS/SVN/Git
- **Unimus**: Commercial; web GUI with config diff, compliance, search

**NetBox integration:**
- Store config snapshots as NetBox config contexts
- Compare device running config vs NetBox stored config for drift detection

### Backup Best Practices
- Run backups before and after every change (pre/post snapshots)
- Store backups in Git for version history and diff capability
- Automate daily backups via cron or CI/CD scheduled pipeline
- Alert on backup failures (device unreachable, auth failure)
- Retain backups for compliance period (90 days, 1 year, per policy)
