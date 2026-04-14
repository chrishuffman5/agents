# Network Automation Fundamentals Reference

## Infrastructure as Code (IaC) Principles

### Core Tenets

**1. Declarative Intent**
Define *what* the network should look like, not *how* to get there:
- Declarative: "Interface GigabitEthernet0/1 should have VLAN 10 as access VLAN"
- Imperative: "Run `interface GigabitEthernet0/1`, then `switchport mode access`, then `switchport access vlan 10`"

Declarative approaches are preferred because:
- The tool determines the commands needed based on current vs desired state
- Idempotent by design (running twice produces the same result)
- Easier to reason about (what, not how)
- Ansible resource modules and Terraform resources are declarative
- Raw CLI commands (`cli_command`, `ios_command`) are imperative

**2. Version Control**
All network configuration artifacts stored in Git:
- Ansible playbooks, roles, variables, inventory
- Terraform configurations, modules, variable files
- Jinja2 templates for config generation
- NetBox data exports (optional; NetBox itself is the source of truth)
- CI/CD pipeline definitions

Benefits: audit trail, peer review, rollback, branching for experiments, blame/history for debugging

**3. Reproducibility**
Same inputs produce the same network state:
- Environment-specific values stored as variables (not hardcoded)
- Templates parameterized by site, device role, device type
- Randomness eliminated (deterministic operations)
- Dependencies explicitly declared (Ansible roles, Terraform modules)

**4. Testability**
Changes validated before deployment:
- Syntax validation (YAML lint, HCL validate, Jinja2 compile)
- Dry-run (Ansible `--check`, Terraform `plan`)
- Unit tests (validate template output, variable schemas)
- Integration tests (deploy to lab, verify connectivity)
- Compliance tests (check against security policy, naming conventions)

**5. Auditability**
Complete history of all network changes:
- Git commits with author, timestamp, message
- CI/CD pipeline logs (what ran, what changed, what was validated)
- Ansible/Terraform execution logs
- Approval records (PR reviews, change management tickets)

## Declarative vs Imperative

### Declarative Approach

Tools: Ansible resource modules, Terraform, Nornir with state comparison

```yaml
# Declarative: "Ensure these VLANs exist"
- name: Configure VLANs
  cisco.ios.ios_vlans:
    config:
      - vlan_id: 10
        name: MGMT
        state: active
      - vlan_id: 20
        name: USERS
        state: active
    state: merged
```

Characteristics:
- Describe desired end state
- Tool determines what changes are needed (if any)
- Idempotent: safe to run repeatedly
- Tool handles ordering and dependency resolution
- Limited by what the tool/module supports

### Imperative Approach

Tools: Ansible `cli_command` / `ios_command`, raw SSH scripts, expect scripts

```yaml
# Imperative: "Run these commands"
- name: Add VLAN 10
  cisco.ios.ios_command:
    commands:
      - configure terminal
      - vlan 10
      - name MGMT
      - state active
      - exit
```

Characteristics:
- Describe step-by-step commands
- Engineer must handle idempotency (check if VLAN exists before adding)
- Engineer must handle ordering and error recovery
- Maximum flexibility (any command can be sent)
- Higher risk of unintended side effects

### When to Use Each

| Use Declarative | Use Imperative |
|---|---|
| Standard configuration (VLANs, interfaces, routing) | One-time data collection (`show` commands) |
| Repeatable, scheduled configuration enforcement | Emergency troubleshooting commands |
| CI/CD pipeline deployments | Platform-specific commands not covered by modules |
| Multi-vendor environments (same playbook structure) | Interactive debugging sessions |

## GitOps for Network

### What is GitOps for Network?

GitOps applies software development practices to network operations:
- Git repository is the single source of truth for desired network state
- All changes go through Git (branch, commit, PR, merge)
- CI/CD pipeline validates and deploys changes automatically
- Actual network state is continuously reconciled with Git state

### GitOps Workflow (Detailed)

**Phase 1: Change Initiation**
```
1. Engineer creates feature branch from main
2. Makes changes:
   - Modify host_vars/device.yml (Ansible)
   - Update main.tf (Terraform)
   - Edit templates/interface.j2 (Jinja2)
3. Commits with descriptive message
4. Pushes branch, opens Pull Request
```

**Phase 2: Automated Validation (CI)**
```
5. CI pipeline triggers on PR:
   a. Linting:
      - yamllint (YAML syntax)
      - ansible-lint (Ansible best practices)
      - terraform validate (HCL syntax)
      - jinja2-lint (template syntax)
   b. Dry-run:
      - ansible-playbook --check --diff (shows what would change)
      - terraform plan (shows resource changes)
   c. Policy checks:
      - Custom scripts verify naming conventions
      - Batfish analyzes reachability and routing
      - OPA (Open Policy Agent) evaluates compliance rules
   d. Unit tests:
      - Molecule for Ansible role testing
      - Terraform test for module testing
      - pytest for custom filter plugins
```

**Phase 3: Human Review**
```
6. Peer review:
   - Network engineer reviews PR diff
   - Reviews CI results (plan output, lint results)
   - Checks against change management process
   - Approves or requests changes
7. Change approval:
   - For production: require 2+ approvals
   - For lab/dev: 1 approval may suffice
```

**Phase 4: Deployment (CD)**
```
8. Merge to main triggers CD pipeline:
   a. Deploy:
      - ansible-playbook (no --check, actual deployment)
      - terraform apply -auto-approve (from approved plan)
   b. Post-deployment validation:
      - Connectivity tests (ping, traceroute)
      - Config diff (verify applied vs intended)
      - Application health checks
      - Monitoring system alerts
   c. Notification:
      - Slack/Teams message with deployment result
      - Ticket update (ServiceNow, Jira)
9. If validation fails:
   a. Rollback (revert Git commit, re-run pipeline)
   b. Alert on-call engineer
   c. Incident created
```

### Branch Strategy for Network

Recommended Git branching model:
- **main**: Production-ready configuration. Only merged via PR after CI validation.
- **develop**: Integration branch for testing multiple changes together (optional).
- **feature/TICKET-123-add-vlan-50**: Feature branches for individual changes.
- **hotfix/TICKET-456-fix-ospf-area**: Emergency fixes (still go through CI, but expedited review).

### CI/CD Pipeline Tools

| Tool | Strengths | Network Use |
|---|---|---|
| GitHub Actions | GitHub-native, YAML workflows, marketplace actions | Ansible/Terraform CI, PR validation |
| GitLab CI | GitLab-native, powerful pipeline DSL, built-in registry | Ansible/Terraform CI, GitOps |
| Jenkins | Mature, extensible, on-premises option | Complex pipelines, legacy integration |
| Azure DevOps | Azure-native, integrated boards/repos/pipelines | Microsoft-shop network teams |

## Source of Truth Pattern

### What is a Source of Truth?

A single authoritative data store that answers: "What should the network look like?"

For network automation, this typically means:
- **NetBox**: Devices, interfaces, IP addresses, VLANs, sites, racks, cables, circuits
- **Git**: Configuration templates, policies, automation code
- **CMDB (ServiceNow, etc.)**: Business context (service owners, SLAs, change records)

### NetBox as Network Source of Truth

NetBox is the most common network-specific source of truth:

**What NetBox stores:**
- Site hierarchy (regions, sites, locations, racks)
- Device inventory (manufacturer, model, serial, firmware, status)
- Interface inventory (physical/virtual, type, speed, MAC, connected cable)
- IP address management (prefixes, IP addresses, VRFs, VLANs, ASNs)
- Circuit inventory (providers, circuits, terminations)
- Custom fields for organization-specific data

**How NetBox feeds automation:**

```
NetBox (inventory, addressing)
  │
  ├──> Ansible (nb_inventory plugin)
  │    - Generates dynamic inventory grouped by site, role, platform
  │    - Device variables include IPs, VLANs, interfaces from NetBox
  │    - Playbooks use NetBox data to generate device configs
  │
  ├──> Terraform (http data source + jsondecode)
  │    - Query NetBox API for device data
  │    - Use for_each to create resources from NetBox data
  │    - NetBox is authoritative; Terraform provisions
  │
  └──> Custom scripts (pynetbox)
       - Bulk data population
       - Reconciliation between NetBox and actual device state
       - Reporting and compliance checks
```

### Source of Truth Anti-Patterns

1. **Multiple sources of truth**: If device inventory is in NetBox AND a spreadsheet AND a wiki, which is correct? Choose one authoritative source per data domain.

2. **Stale data**: Source of truth is only valuable if accurate. Build automation to update NetBox from device state (reconciliation), not just read from it.

3. **Manual population**: Manually entering data into NetBox does not scale. Use scripts and automation to populate and maintain data.

4. **No ownership**: Every data field should have an owner responsible for accuracy. Unowned data decays.

## Configuration Drift

### What is Config Drift?

Configuration drift is the divergence between desired state (source of truth / Git) and actual state (device running config):

```
Desired State (Git/NetBox)     Actual State (Device)
├── VLAN 10: MGMT              ├── VLAN 10: MGMT
├── VLAN 20: USERS             ├── VLAN 20: USERS
├── VLAN 30: VOICE             ├── VLAN 30: VOICE
└── NTP: 10.0.0.1              ├── VLAN 99: TEMP_TEST    ← DRIFT (added manually)
                                └── NTP: 10.0.0.2         ← DRIFT (changed manually)
```

### Drift Detection Methods

**1. Config Backup and Diff**
```yaml
# Ansible: backup and compare
- name: Backup running config
  cisco.ios.ios_config:
    backup: yes
    backup_options:
      filename: "{{ inventory_hostname }}_{{ ansible_date_time.date }}.cfg"
      dir_path: /backups/

# Compare with previous backup using diff tool
# Alert if differences detected
```

Tools: Ansible config backup, Oxidized, RANCID, Unimus

**2. Ansible Check Mode**
```bash
# Shows what Ansible would change (drift = changes needed)
ansible-playbook site.yml --check --diff

# Output shows:
# CHANGED: ios_vlans would add VLAN 30 (missing from device)
# This means device has drifted from desired state
```

**3. Terraform Plan**
```bash
# Shows drift for Terraform-managed resources
terraform plan

# Output shows:
# ~ resource "aci_tenant" "prod" {
#     ~ description = "Production" -> "Prod Tenant"  # drift detected
#   }
```

**4. Batfish (Offline Analysis)**
Batfish parses device configs offline and analyzes:
- Reachability (can host A reach host B?)
- Routing correctness (does traffic follow expected path?)
- ACL analysis (does traffic match expected ACL rules?)
- Useful for pre-deployment validation and drift detection without touching devices

### Drift Remediation Strategies

| Strategy | Risk | Use When |
|---|---|---|
| Auto-remediate (re-run automation) | Medium: may overwrite valid emergency changes | Low-risk configs (NTP, SNMP, banners) |
| Alert and review | Low: human reviews before action | Production critical infrastructure |
| Scheduled enforcement | Medium: drift corrected on schedule | Standard configs with change windows |
| Ignore and document | N/A: accept the drift | Known exceptions (temporary lab configs) |

## Idempotency in Network Automation

### Why Idempotency Matters

Network automation scripts run repeatedly (scheduled, retriggered, CI/CD retries). Non-idempotent operations cause:
- Duplicate configurations (multiple identical routes, ACL entries)
- Errors on second run ("VLAN already exists")
- Unpredictable state (each run modifies further)

### Achieving Idempotency

**Ansible Resource Modules (Built-in Idempotency):**
```yaml
# Idempotent: "ensure VLAN 10 exists with name MGMT"
- cisco.ios.ios_vlans:
    config:
      - vlan_id: 10
        name: MGMT
    state: merged
# First run: creates VLAN 10
# Second run: no changes (already exists with correct name)
# Third run: no changes
```

**Terraform Resources (Built-in Idempotency):**
```hcl
# Idempotent: "ensure tenant PROD exists"
resource "aci_tenant" "prod" {
  name = "PROD"
}
# First apply: creates tenant
# Second apply: no changes (already exists)
```

**Making Imperative Commands Idempotent:**
```yaml
# Non-idempotent (will fail on second run):
- cisco.ios.ios_command:
    commands: "vlan 10"

# Made idempotent with conditional:
- cisco.ios.ios_command:
    commands: "show vlan id 10"
  register: vlan_check
  failed_when: false

- cisco.ios.ios_config:
    lines:
      - vlan 10
      - name MGMT
  when: "'not found' in vlan_check.stdout[0]"
```

### Idempotency Checklist
- [ ] Use resource modules (Ansible) or resources (Terraform) instead of raw commands
- [ ] Test playbooks/plans by running twice: second run should show zero changes
- [ ] For custom scripts: implement "check before change" logic
- [ ] Document non-idempotent operations (one-time scripts, migrations) and mark them clearly
- [ ] In CI/CD: if pipeline reruns, deployment should be safe (no duplicate configs)

## Network Automation Maturity Model

### Level 1: Manual with Tools
- CLI-based changes with documentation
- Spreadsheet-based inventory
- No version control for configs
- Reactive troubleshooting

### Level 2: Script-Based Automation
- Python/Bash scripts for common tasks (backup, bulk changes)
- Basic config backup (RANCID, Oxidized)
- Scripts stored in Git (but not CI/CD)
- Manual execution of scripts

### Level 3: Framework-Based Automation
- Ansible/Terraform for configuration management
- NetBox or CMDB as inventory source
- Jinja2 templates for config generation
- Scheduled automation (cron-based playbook runs)
- Some CI validation (linting, syntax checks)

### Level 4: GitOps / CI-CD
- All changes via Git (no manual CLI)
- CI/CD pipeline for validation and deployment
- Automated drift detection and remediation
- Source of truth fully maintained
- Peer review for all production changes
- Automated testing (Batfish, pyATS, Molecule)

### Level 5: Self-Healing Network
- Closed-loop automation (detect issue -> remediate automatically)
- ML-based anomaly detection
- Intent-based networking (declare business intent, automation configures network)
- Continuous compliance enforcement
- Event-driven automation (triggered by monitoring alerts)

### Adoption Path
Most organizations are at Level 1-2. The recommended path:
1. Start with Level 2: automate config backups and read-only data collection
2. Move to Level 3: adopt Ansible for standardized changes, deploy NetBox for inventory
3. Progress to Level 4: implement CI/CD pipeline, enforce Git-based change process
4. Level 5 is aspirational: achieve selectively for specific operational domains
