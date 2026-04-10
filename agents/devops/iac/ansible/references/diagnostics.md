# Ansible Diagnostics

## Connection Failures

### SSH Connection Refused

```
fatal: [web1.example.com]: UNREACHABLE! => {
    "msg": "Failed to connect to the host via ssh: ssh: connect to host 10.0.1.10 port 22: Connection refused"
}
```

**Diagnosis:**
1. Is SSH running? `ssh web1.example.com` from the control node
2. Firewall blocking? `nc -zv 10.0.1.10 22`
3. Correct user? `ansible_user` in inventory
4. SSH key? `ansible_ssh_private_key_file` or SSH agent

**Resolution:**
- Fix SSH connectivity first: `ssh -vvv user@host` for detailed debug
- Check `ansible.cfg` for `remote_user`, `private_key_file`
- For bastion/jump hosts: configure `ansible_ssh_common_args: '-o ProxyJump=bastion'`

### WinRM Connection Failures

```
fatal: [win1.example.com]: UNREACHABLE! => {
    "msg": "winrm or psrp connection error"
}
```

**Diagnosis:**
1. WinRM enabled? On target: `winrm quickconfig`
2. HTTPS configured? `winrm get winrm/config/Listener`
3. Correct credentials? `ansible_user`, `ansible_password`
4. Firewall? Port 5986 (HTTPS) or 5985 (HTTP) open?

**Resolution:**
```yaml
# Inventory for Windows hosts
[windows:vars]
ansible_connection: winrm
ansible_winrm_transport: ntlm    # or kerberos, credssp
ansible_winrm_server_cert_validation: ignore    # Only for testing
ansible_port: 5986
```

### Permission Denied (Become)

```
fatal: [web1]: FAILED! => {
    "msg": "Missing sudo password"
}
```

**Resolution:**
- Add `ansible_become_password` (vault-encrypted) or configure passwordless sudo
- Check sudoers: user must have `NOPASSWD` or provide password
- For pipelining: ensure `!requiretty` in sudoers

## Module Errors

### Module Not Found

```
ERROR! couldn't resolve module/action 'community.general.ufw'. This often indicates a misspelling...
```

**Resolution:**
1. Install the collection: `ansible-galaxy collection install community.general`
2. Check `collections/requirements.yml` includes it
3. Verify FQCN spelling: `ansible-doc -l | grep ufw`

### Module Arguments

```
fatal: [web1]: FAILED! => {
    "msg": "Unsupported parameters for (ansible.builtin.apt) module: update_cashe. Supported parameters include: ..."
}
```

**Resolution:**
1. Check spelling (typo in the error: `update_cashe` vs `update_cache`)
2. Check module documentation: `ansible-doc ansible.builtin.apt`
3. Check ansible-core version — some parameters were added in later versions

### Jinja2 Template Errors

```
fatal: [web1]: FAILED! => {
    "msg": "AnsibleUndefinedVariable: 'app_port' is undefined"
}
```

**Diagnosis:**
1. Is the variable defined? Check all variable sources (defaults, vars, group_vars, host_vars, extra vars)
2. Scope issue? Variables set with `set_fact` or `register` are host-scoped
3. Typo? Variable names are case-sensitive

**Resolution:**
- Use `default` filter: `{{ app_port | default(8080) }}`
- Debug: `ansible -m debug -a "var=app_port" host`
- Check precedence: `ansible -m debug -a "var=hostvars[inventory_hostname]" host`

## Variable Resolution Issues

### Unexpected Variable Value

```bash
# Debug a specific variable across all variable sources
ansible -i inventory/production -m debug -a "var=hostvars[inventory_hostname].nginx_port" webservers

# Verbose mode shows variable sources
ansible-playbook site.yml -vvv
```

### Variable Precedence Debugging

```yaml
# Add a debug task to inspect resolved values
- name: Debug variable sources
  ansible.builtin.debug:
    msg: |
      nginx_port: {{ nginx_port }}
      Source check:
      - role default: {{ role_defaults.nginx_port | default('not set') }}
      - group_var: {{ group_vars_nginx_port | default('not set') }}
```

**Common traps:**
- `vars:` in a role's `vars/main.yml` overrides `group_vars` — use `defaults/main.yml` for user-overridable values
- `include_vars` loads at task execution time, not play parse time
- `set_fact` persists for the rest of the play for that host

## Performance Debugging

### Slow Playbook Runs

```bash
# Profile task execution times
ANSIBLE_CALLBACKS_ENABLED=timer,profile_tasks ansible-playbook site.yml
```

**Common causes:**
1. **Too few forks** — Default is 5. Increase in `ansible.cfg`: `forks = 50`
2. **Fact gathering** — Disable with `gather_facts: false` if not needed
3. **No pipelining** — Enable in `ansible.cfg`: `pipelining = True`
4. **No SSH multiplexing** — Enable ControlMaster in ssh_args
5. **Serial execution** — Using `serial: 1` when not needed (rolling updates)
6. **Large file transfers** — Use `synchronize` (rsync) instead of `copy` for large directories

### Check Mode (Dry Run)

```bash
# Dry run — shows what would change without making changes
ansible-playbook site.yml --check --diff

# Limit to specific hosts
ansible-playbook site.yml --check --diff --limit web1.example.com

# Step through tasks interactively
ansible-playbook site.yml --step
```

## Debugging Commands

```bash
# Test connectivity
ansible all -m ping -i inventory/production

# Gather and display facts
ansible web1 -m setup -i inventory/production
ansible web1 -m setup -a "filter=ansible_distribution*" -i inventory/production

# Run ad-hoc commands
ansible webservers -m command -a "uptime" -i inventory/production

# List hosts in a group
ansible webservers -i inventory/production --list-hosts

# Syntax check
ansible-playbook site.yml --syntax-check

# List tasks without executing
ansible-playbook site.yml --list-tasks

# List tags
ansible-playbook site.yml --list-tags

# Verbose output (up to -vvvv)
ansible-playbook site.yml -vvv
```

## ansible-lint

```bash
# Run linter
ansible-lint playbooks/ roles/

# Common rules that catch real issues:
# - no-changed-when: command/shell tasks without changed_when
# - no-handler: tasks that should use handlers instead of always-running
# - fqcn: not using fully qualified collection names
# - yaml[truthy]: using yes/no instead of true/false
# - name[missing]: tasks without names
```
