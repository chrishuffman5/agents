# Ansible Architecture

## Plugin System

Ansible's functionality is implemented through plugins. Every action Ansible takes goes through a plugin.

### Plugin Types

| Type | Purpose | Examples |
|---|---|---|
| **Connection** | How Ansible connects to managed nodes | `ssh`, `winrm`, `local`, `docker`, `network_cli`, `httpapi` |
| **Become** | Privilege escalation | `sudo`, `su`, `runas`, `enable`, `doas` |
| **Callback** | Hook into execution events | `default`, `json`, `yaml`, `junit`, `timer`, `profile_tasks` |
| **Lookup** | Retrieve data from external sources | `file`, `env`, `template`, `password`, `aws_ssm`, `hashi_vault` |
| **Filter** | Transform data in Jinja2 expressions | `default`, `regex_replace`, `json_query`, `to_yaml`, `combine` |
| **Inventory** | Dynamic inventory sources | `aws_ec2`, `azure_rm`, `vmware_vm_inventory`, `constructed` |
| **Module** | Execute actions on managed nodes | 2800+ modules across all collections |
| **Strategy** | Control execution order | `linear` (default), `free`, `debug` |
| **Vars** | Load variables from sources | `host_group_vars`, `include_vars` |

### Connection Plugins

| Plugin | Transport | Target OS | Use Case |
|---|---|---|---|
| `ssh` (default) | OpenSSH | Linux/Unix | Standard server automation |
| `paramiko` | Python SSH | Linux/Unix | When OpenSSH is unavailable |
| `winrm` | WinRM (HTTPS) | Windows | Windows server automation |
| `psrp` | PowerShell Remoting | Windows | Faster Windows automation |
| `local` | None (local exec) | Control node | Running tasks on the Ansible controller |
| `docker` | Docker API | Containers | Managing Docker containers |
| `network_cli` | SSH (CLI) | Network devices | Cisco, Juniper, Arista CLI |
| `httpapi` | REST/HTTPS | Network/API | Firewall APIs, REST-based devices |

## Execution Internals

### Task Execution Flow

1. **Variable resolution** — Merge all variable sources according to precedence
2. **Conditional evaluation** — Evaluate `when:` clauses (skip if false)
3. **Loop expansion** — If `loop:` present, iterate and execute once per item
4. **Module generation** — Bundle module code + arguments into a Python script
5. **Transfer** — SCP/SFTP the module script to the managed node's temp directory
6. **Execution** — Run the module via the connection plugin (SSH command, WinRM invoke)
7. **Result parsing** — Module returns JSON to stdout; Ansible parses it
8. **Handler notification** — If `notify:` present and task changed, queue the handler
9. **Cleanup** — Remove temp files from the managed node

### Strategy Plugins

| Strategy | Behavior |
|---|---|
| `linear` (default) | All hosts execute task 1, then all execute task 2, etc. Synchronization point between tasks. |
| `free` | Each host executes all tasks as fast as possible, no synchronization. Faster but harder to debug. |
| `debug` | Interactive debugger — step through tasks, inspect variables. |

### Performance Tuning

```ini
# ansible.cfg
[defaults]
forks = 50                    # Parallel host execution (default: 5)
gathering = smart             # Cache facts (smart|implicit|explicit)
fact_caching = jsonfile       # Persist facts between runs
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600   # Seconds

[ssh_connection]
pipelining = True             # Reduce SSH operations (requires !requiretty in sudoers)
ssh_args = -o ControlMaster=auto -o ControlPersist=60s  # Reuse SSH connections
```

## Collection Architecture

Collections are the distribution format for Ansible content (modules, roles, plugins, playbooks).

### Collection Structure

```
namespace/
  collection_name/
    galaxy.yml           # Metadata
    plugins/
      modules/           # Module plugins
      inventory/         # Inventory plugins
      lookup/            # Lookup plugins
      filter/            # Filter plugins
      connection/        # Connection plugins
      callback/          # Callback plugins
    roles/               # Bundled roles
    playbooks/           # Bundled playbooks
    docs/                # Documentation
    tests/               # Integration tests
```

### Collection Namespacing

All modules should be referenced by their Fully Qualified Collection Name (FQCN):

```yaml
# Modern (FQCN) — always use this
- name: Install nginx
  ansible.builtin.apt:
    name: nginx
    state: present

# Legacy (short name) — deprecated, ambiguous
- name: Install nginx
  apt:
    name: nginx
    state: present
```

### Key Collections

| Collection | Content |
|---|---|
| `ansible.builtin` | Core modules (file, copy, template, apt, yum, service, user) |
| `ansible.posix` | POSIX modules (acl, seboolean, synchronize, at) |
| `ansible.windows` | Windows modules (win_copy, win_service, win_regedit) |
| `community.general` | Community modules (broad scope) |
| `amazon.aws` | AWS modules (ec2, s3, rds, iam, vpc) |
| `azure.azcollection` | Azure modules (VM, storage, networking) |
| `google.cloud` | GCP modules |
| `cisco.ios` / `nxos` | Cisco network modules |
| `junipernetworks.junos` | Juniper network modules |
| `paloaltonetworks.panos` | Palo Alto firewall modules |

## AWX / Automation Controller Architecture

AWX (upstream) / Automation Controller (Red Hat product) provides a web-based management layer:

### Components

| Component | Purpose |
|---|---|
| **Web UI** | Dashboard, job management, inventory browser |
| **REST API** | Programmatic access to all features |
| **Task Engine** | Celery workers that execute playbooks |
| **Database** | PostgreSQL — stores job history, credentials, inventories |
| **Message Queue** | Redis — task queue for workers |
| **Receptor** | Mesh networking for remote execution nodes |

### Key Concepts

- **Job Template** — Playbook + inventory + credentials + variables = executable unit
- **Workflow** — Chain of job templates with conditional branching (success/failure/always)
- **Credential** — Encrypted secrets (machine, cloud, SCM, vault) stored in the database
- **Project** — SCM repository containing playbooks (Git, SVN)
- **Inventory** — Hosts and groups (static, dynamic, smart, constructed)
- **Schedule** — Cron-like scheduling for job templates and workflows
- **RBAC** — Role-based access control for all resources
