# Ansible Network Best Practices Reference

## Inventory Design

### Static Inventory Structure
```
inventory/
├── production/
│   ├── hosts.yml            # Device inventory
│   ├── group_vars/
│   │   ├── all.yml          # Variables for all devices
│   │   ├── cisco_ios.yml    # Variables for IOS devices
│   │   ├── arista_eos.yml   # Variables for EOS devices
│   │   └── juniper_junos.yml
│   └── host_vars/
│       ├── core-rtr-01.yml  # Per-device variables
│       └── core-rtr-02.yml
├── staging/
│   ├── hosts.yml
│   └── group_vars/
└── lab/
    ├── hosts.yml
    └── group_vars/
```

### Inventory Grouping Strategy
```yaml
# inventory/production/hosts.yml
all:
  children:
    # Group by platform (required for connection/OS settings)
    cisco_ios:
      hosts:
        core-rtr-01:
          ansible_host: 10.0.0.1
        dist-sw-01:
          ansible_host: 10.0.0.10
    arista_eos:
      hosts:
        leaf-sw-01:
          ansible_host: 10.0.1.1

    # Group by role (for role-specific configuration)
    core_routers:
      hosts:
        core-rtr-01:
    distribution_switches:
      hosts:
        dist-sw-01:
    leaf_switches:
      hosts:
        leaf-sw-01:

    # Group by site (for site-specific variables)
    site_nyc:
      hosts:
        core-rtr-01:
        dist-sw-01:
    site_lax:
      hosts:
        leaf-sw-01:
```

### Dynamic Inventory from NetBox
```yaml
# inventory/netbox.yml
plugin: netbox.netbox.nb_inventory
api_endpoint: https://netbox.example.com
token: "{{ lookup('env', 'NETBOX_TOKEN') }}"
config_context: true
group_by:
  - device_roles
  - sites
  - platforms
query_filters:
  - status: active
  - has_primary_ip: true
compose:
  ansible_host: primary_ip4.address | ansible.utils.ipaddr('address')
```

Run: `ansible-inventory -i inventory/netbox.yml --list`

### Group Variables

**Platform variables (group_vars/cisco_ios.yml):**
```yaml
ansible_network_os: cisco.ios.ios
ansible_connection: network_cli
ansible_become: yes
ansible_become_method: enable
ansible_user: "{{ vault_network_user }}"
ansible_password: "{{ vault_network_password }}"
ansible_become_password: "{{ vault_enable_password }}"
```

**Site variables (group_vars/site_nyc.yml):**
```yaml
ntp_servers:
  - 10.0.0.100
  - 10.0.0.101
syslog_servers:
  - 10.0.0.200
dns_servers:
  - 10.0.0.50
  - 10.0.0.51
snmp_community: "{{ vault_snmp_community }}"
```

## Playbook Structure

### Recommended Layout
```
network-automation/
├── ansible.cfg
├── requirements.yml           # Collection dependencies
├── inventory/
│   ├── production/
│   └── lab/
├── playbooks/
│   ├── site.yml               # Master playbook (imports roles)
│   ├── backup.yml             # Config backup playbook
│   ├── compliance.yml         # Compliance check playbook
│   └── deploy_vlans.yml       # Specific deployment playbook
├── roles/
│   ├── base_config/           # NTP, syslog, SNMP, banners
│   ├── vlans/                 # VLAN configuration
│   ├── interfaces/            # Interface configuration
│   ├── routing/               # OSPF, BGP configuration
│   └── security/              # ACLs, line security
├── templates/
│   ├── ios_base.j2
│   └── ios_interface.j2
├── filter_plugins/            # Custom Jinja2 filters
├── library/                   # Custom modules (rare)
└── tests/
    └── molecule/              # Role testing
```

### Master Playbook Pattern
```yaml
# playbooks/site.yml
---
- name: Deploy base configuration
  hosts: all
  gather_facts: no
  roles:
    - role: base_config
      tags: [base]

- name: Deploy VLAN configuration
  hosts: switches
  gather_facts: no
  roles:
    - role: vlans
      tags: [vlans]

- name: Deploy routing configuration
  hosts: core_routers
  gather_facts: no
  roles:
    - role: routing
      tags: [routing]
```

### Role Structure
```
roles/vlans/
├── defaults/
│   └── main.yml          # Default variables (overridable)
├── tasks/
│   └── main.yml          # Role tasks
├── vars/
│   └── main.yml          # Role-internal variables (not overridable)
├── templates/
│   └── vlans.j2          # Role-specific templates
├── handlers/
│   └── main.yml          # Event-driven tasks (save config)
├── meta/
│   └── main.yml          # Role metadata (dependencies)
└── molecule/
    └── default/
        └── converge.yml  # Test playbook
```

## Ansible Vault

### Encrypting Secrets
```bash
# Create encrypted variable file
ansible-vault create group_vars/all/vault.yml

# Edit existing encrypted file
ansible-vault edit group_vars/all/vault.yml

# Encrypt a single string
ansible-vault encrypt_string 'SuperSecret123' --name 'vault_enable_password'
```

### Vault Variable Pattern
```yaml
# group_vars/all/vault.yml (encrypted)
vault_network_user: netadmin
vault_network_password: ComplexP@ssw0rd!
vault_enable_password: En@bleS3cret
vault_snmp_community: Pub1icComm

# group_vars/cisco_ios.yml (plaintext, references vault)
ansible_user: "{{ vault_network_user }}"
ansible_password: "{{ vault_network_password }}"
```

### Running with Vault
```bash
# Prompt for vault password
ansible-playbook site.yml --ask-vault-pass

# Use vault password file (for CI/CD)
ansible-playbook site.yml --vault-password-file /secrets/vault-pass.txt

# Environment variable (CI/CD)
export ANSIBLE_VAULT_PASSWORD_FILE=/secrets/vault-pass.txt
```

## Error Handling

### Block/Rescue Pattern
```yaml
- name: Deploy VLAN changes with rollback
  block:
    - name: Backup config before change
      cisco.ios.ios_config:
        backup: yes
      register: backup_result

    - name: Apply VLAN changes
      cisco.ios.ios_vlans:
        config: "{{ vlan_config }}"
        state: merged

    - name: Verify connectivity
      cisco.ios.ios_ping:
        dest: "{{ gateway_ip }}"
        count: 5
      register: ping_result
      failed_when: ping_result.packet_loss | int > 20

  rescue:
    - name: Restore config from backup
      cisco.ios.ios_config:
        src: "{{ backup_result.backup_path }}"

    - name: Alert on failure
      debug:
        msg: "VLAN deployment failed on {{ inventory_hostname }}. Config restored."

  always:
    - name: Save running config
      cisco.ios.ios_config:
        save_when: modified
```

### Retry Logic
```yaml
- name: Wait for device to come back after reboot
  ansible.netcommon.cli_command:
    command: show version
  register: result
  retries: 10
  delay: 30
  until: result is not failed
```

### Assert for Validation
```yaml
- name: Gather VLAN facts
  cisco.ios.ios_vlans:
    state: gathered
  register: vlan_facts

- name: Verify VLAN 10 exists
  assert:
    that:
      - vlan_facts.gathered | selectattr('vlan_id', 'equalto', 10) | list | length > 0
    fail_msg: "VLAN 10 was not created successfully"
    success_msg: "VLAN 10 verified"
```

## Idempotency Patterns

### Always Prefer Resource Modules
```yaml
# GOOD: Idempotent
- cisco.ios.ios_vlans:
    config:
      - vlan_id: 10
        name: MGMT
    state: merged

# BAD: Not idempotent (will report "changed" every run)
- cisco.ios.ios_config:
    lines:
      - vlan 10
      - name MGMT
```

### When You Must Use ios_config
If no resource module exists for the config section, use `ios_config` with `match` and `parents`:
```yaml
- name: Configure TACACS (no resource module)
  cisco.ios.ios_config:
    parents:
      - "aaa group server tacacs+ TACACS_GROUP"
    lines:
      - "server-private 10.0.0.100 key {{ vault_tacacs_key }}"
    match: exact
```

The `match: exact` parameter ensures idempotency by comparing the exact line content.

## CI/CD Integration

### Pre-Deployment Validation
```bash
# Lint playbook
ansible-lint playbooks/site.yml

# Syntax check
ansible-playbook playbooks/site.yml --syntax-check

# Dry-run (check mode)
ansible-playbook playbooks/site.yml --check --diff -i inventory/production/

# The --diff flag shows exactly what would change per device
```

### GitHub Actions Example
```yaml
name: Network Deployment
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: self-hosted  # Use self-hosted runner with network access
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: pip install ansible ansible-lint
      - name: Install collections
        run: ansible-galaxy collection install -r requirements.yml
      - name: Lint
        run: ansible-lint playbooks/
      - name: Dry-run
        run: ansible-playbook playbooks/site.yml --check --diff
        env:
          ANSIBLE_VAULT_PASSWORD_FILE: ${{ secrets.VAULT_PASS_FILE }}

  deploy:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: ansible-playbook playbooks/site.yml
        env:
          ANSIBLE_VAULT_PASSWORD_FILE: ${{ secrets.VAULT_PASS_FILE }}
```

### Requirements File
```yaml
# requirements.yml
collections:
  - name: cisco.ios
    version: ">=7.0.0"
  - name: cisco.nxos
    version: ">=6.0.0"
  - name: arista.eos
    version: ">=9.0.0"
  - name: ansible.netcommon
    version: ">=6.0.0"
  - name: ansible.utils
    version: ">=4.0.0"
  - name: netbox.netbox
    version: ">=3.18.0"
```

Pin collection versions to prevent unexpected breaking changes in CI/CD pipelines.

## Performance Optimization

### Parallelism
```ini
# ansible.cfg
[defaults]
forks = 20          # Number of parallel device connections (default: 5)
timeout = 30        # SSH connection timeout
```

### Fact Caching
```ini
# ansible.cfg
[defaults]
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts_cache
fact_caching_timeout = 3600  # Cache facts for 1 hour
```

### Reducing Connection Overhead
```yaml
# Use persistent connections to avoid SSH reconnection per task
[persistent_connection]
connect_timeout = 30
command_timeout = 30
```

### Limiting Scope
```bash
# Run only on specific hosts
ansible-playbook site.yml --limit core-rtr-01

# Run only specific tags
ansible-playbook site.yml --tags vlans

# Combine for targeted deployment
ansible-playbook site.yml --limit site_nyc --tags routing
```
