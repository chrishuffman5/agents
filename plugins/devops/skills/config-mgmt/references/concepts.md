# Configuration Management Concepts

## Desired State Configuration

All CM tools model infrastructure as a declared desired state:

1. **Define** the desired state (packages, files, services, users)
2. **Apply** the configuration to target systems
3. **Converge** — the tool brings the system into compliance
4. **Report** — the tool reports what changed and what is compliant

### Idempotency

Applying the same configuration multiple times produces the same result:
- **Package installed**: If already installed, no-op
- **File content**: If content matches, no-op
- **Service running**: If already running, no-op

### Drift Detection and Remediation

| Strategy | How | Tools |
|---|---|---|
| **Continuous enforcement** | Agent runs periodically, reverts drift | Chef (30 min), Puppet (30 min), Salt (schedule) |
| **On-demand** | Run playbook/apply manually | Ansible, Salt |
| **Detect only** | Report drift without remediating | InSpec, puppet agent --noop, ansible --check |

## Compliance as Code

### InSpec (Chef)

```ruby
control 'ssh-hardening' do
  impact 1.0
  title 'SSH should be hardened'
  describe sshd_config do
    its('PermitRootLogin') { should eq 'no' }
    its('PasswordAuthentication') { should eq 'no' }
    its('Protocol') { should eq '2' }
  end
end
```

### Puppet Compliance

```puppet
# Puppet enforces compliance continuously via agent
class ssh::hardening {
  sshd_config { 'PermitRootLogin':
    ensure => present,
    value  => 'no',
  }
}
```

### Ansible Compliance

```yaml
- name: Ensure SSH hardening
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^PermitRootLogin'
    line: 'PermitRootLogin no'
  notify: restart sshd
```

## Resource Abstraction

All CM tools abstract system resources:

| Resource | Chef | Puppet | Salt | Ansible |
|---|---|---|---|---|
| Package | `package` | `package` | `pkg.installed` | `apt`/`yum`/`dnf` |
| File | `file`/`template` | `file` | `file.managed` | `copy`/`template` |
| Service | `service` | `service` | `service.running` | `service`/`systemd` |
| User | `user` | `user` | `user.present` | `user` |
| Cron | `cron` | `cron` | `cron.present` | `cron` |
| Command | `execute` | `exec` | `cmd.run` | `command`/`shell` |

## Testing Patterns

| Level | Chef | Puppet | Salt | Ansible |
|---|---|---|---|---|
| Linting | Cookstyle | puppet-lint | salt-lint | ansible-lint |
| Unit | ChefSpec | rspec-puppet | Salt test | Molecule |
| Integration | Test Kitchen | Litmus | Kitchen-Salt | Molecule |
| Compliance | InSpec | puppet-compliance | Salt audit | ansible --check |
