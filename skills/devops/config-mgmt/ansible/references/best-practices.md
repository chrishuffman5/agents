# Ansible Best Practices

## Playbook Organization

### Repository Structure

```
ansible/
├── ansible.cfg                  # Configuration
├── inventory/
│   ├── production/
│   │   ├── hosts.yml            # Static inventory
│   │   ├── group_vars/
│   │   │   ├── all.yml          # All hosts
│   │   │   ├── webservers.yml   # Group-specific
│   │   │   └── vault.yml        # Encrypted secrets
│   │   └── host_vars/
│   │       └── db1.example.com.yml
│   └── staging/
│       ├── hosts.yml
│       └── group_vars/
├── roles/
│   ├── common/                  # Base configuration
│   ├── webserver/               # Application roles
│   └── database/
├── playbooks/
│   ├── site.yml                 # Master playbook
│   ├── webservers.yml           # Subset playbooks
│   └── database.yml
├── collections/
│   └── requirements.yml         # Collection dependencies
└── molecule/                    # Testing
```

### Naming Conventions

- **Playbooks**: `noun.yml` or `verb-noun.yml` (`webservers.yml`, `deploy-app.yml`)
- **Roles**: Lowercase, hyphens (`nginx-proxy`, `postgresql-server`)
- **Variables**: `snake_case`, prefixed with role name (`nginx_listen_port`, `postgres_max_connections`)
- **Tasks**: Start with a verb, descriptive (`Install nginx package`, `Create application user`)

## Idempotency Patterns

### Prefer Modules Over Commands

```yaml
# GOOD: Idempotent — only installs if not present
- name: Install nginx
  ansible.builtin.apt:
    name: nginx
    state: present

# BAD: Not idempotent — runs every time
- name: Install nginx
  ansible.builtin.shell: apt-get install -y nginx
```

### Guard Command/Shell Tasks

When you must use `command` or `shell`, add guards:

```yaml
# Use creates/removes to make it idempotent
- name: Initialize database
  ansible.builtin.command: /opt/app/init-db.sh
  args:
    creates: /opt/app/.db-initialized    # Skip if this file exists

# Use changed_when to control change reporting
- name: Check application version
  ansible.builtin.command: /opt/app/version
  register: app_version
  changed_when: false    # This is a read-only operation

# Use failed_when for custom failure conditions
- name: Check service health
  ansible.builtin.uri:
    url: "http://localhost:8080/health"
  register: health
  failed_when: health.status != 200
  changed_when: false
```

### Template Idempotency

```yaml
# Templates are idempotent — only writes if content changed
- name: Configure nginx
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    validate: nginx -t -c %s    # Validate before deploying
  notify: Restart nginx          # Only triggers if file changed
```

## Security

### Vault Best Practices

1. **Encrypt only secrets, not entire files** — Use `ansible-vault encrypt_string` for individual values
2. **Separate vault files** — Keep encrypted values in `vault.yml`, reference from `vars.yml`
3. **Multiple vault IDs** — Different passwords for dev/prod secrets
4. **Never commit vault passwords** — Use password files excluded from Git, or CI/CD secret injection

```yaml
# group_vars/production/vars.yml (unencrypted references)
db_username: app_user
db_password: "{{ vault_db_password }}"

# group_vars/production/vault.yml (encrypted)
vault_db_password: !vault |
  $ANSIBLE_VAULT;1.2;AES256;prod
  ...encrypted data...
```

### SSH Security

- Use SSH keys, never passwords in production
- Configure `ansible_ssh_private_key_file` per group or host
- Use SSH agent forwarding for bastion/jump host scenarios
- Limit `become` to tasks that need it, don't set globally
- Use `no_log: true` on tasks that handle sensitive data

```yaml
- name: Set database password
  ansible.builtin.mysql_user:
    name: "{{ db_user }}"
    password: "{{ db_password }}"
  no_log: true    # Prevents password from appearing in logs
```

## Performance

### Reduce SSH Overhead

```ini
# ansible.cfg
[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o PreferredAuthentications=publickey
```

### Optimize Fact Gathering

```yaml
# Disable fact gathering if not needed
- hosts: webservers
  gather_facts: false
  tasks:
    - name: Restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted

# Or gather only specific facts
- hosts: webservers
  gather_facts: true
  gather_subset:
    - network
    - hardware
```

### Async Tasks

```yaml
# Long-running tasks — don't block the SSH connection
- name: Run database backup
  ansible.builtin.command: /opt/backup/full-backup.sh
  async: 3600       # Max runtime in seconds
  poll: 30          # Check every 30 seconds (0 = fire and forget)
```

### Limit Scope

```bash
# Run against specific hosts
ansible-playbook site.yml --limit webservers

# Run specific tags
ansible-playbook site.yml --tags deploy

# Start at a specific task (for recovery)
ansible-playbook site.yml --start-at-task "Deploy application"
```

## Testing with Molecule

Molecule provides a framework for testing Ansible roles:

```yaml
# molecule/default/molecule.yml
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: ubuntu:24.04
    pre_build_image: true
provisioner:
  name: ansible
verifier:
  name: ansible  # or testinfra
```

```bash
# Test lifecycle
molecule create       # Create test instance
molecule converge     # Run the role
molecule idempotence  # Run again — verify no changes
molecule verify       # Run verification tests
molecule destroy      # Cleanup
molecule test         # Full lifecycle (create → converge → idempotence → verify → destroy)
```

## Common Mistakes

1. **Not using FQCN** — `apt` is ambiguous. Always use `ansible.builtin.apt`.
2. **`shell` when `command` suffices** — `shell` spawns a full shell (risk of injection). Use `command` unless you need pipes/redirects.
3. **Ignoring variable precedence** — Role vars override group_vars. Use role defaults for values users should override.
4. **Not validating templates** — Use `validate:` parameter to check config files before deploying.
5. **Giant monolithic playbooks** — Break into roles. A playbook should compose roles, not contain raw tasks.
