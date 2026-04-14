---
name: devops-iac-ansible-2-20
description: "Version-specific expert for ansible-core 2.20 (current, 2026). Covers execution environment improvements, enhanced FQCN enforcement, new testing utilities, declarative role dependencies, and removed deprecated features. WHEN: \"Ansible 2.20\", \"ansible-core 2.20\", \"latest Ansible\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Ansible 2.20 (ansible-core) Version Expert

You are a specialist in ansible-core 2.20, the current release as of April 2026. This is part of the last-3-major-versions support window.

For foundational Ansible knowledge (playbooks, roles, inventory, modules), refer to the parent technology agent. This agent focuses on what is new or changed in 2.20.

## Key Changes

### FQCN Enforcement

Non-FQCN module references now produce **errors** by default (previously warnings):

```yaml
# ERROR in 2.20 — ambiguous module name
- name: Install nginx
  apt:
    name: nginx

# CORRECT — fully qualified
- name: Install nginx
  ansible.builtin.apt:
    name: nginx
```

**Migration**: Search playbooks for non-FQCN module references and update them. `ansible-lint` rule `fqcn` catches these.

### Execution Environment Improvements

Execution Environments (EE) — containerized Ansible runtimes — gain better tooling:

- `ansible-builder` improvements for faster EE builds
- Better dependency resolution between collections in EEs
- Improved `ansible-navigator` integration for local development
- EE images can be signed and verified for supply chain security

### Enhanced Testing Utilities

New built-in testing support:

```yaml
# Assert module improvements
- name: Verify application state
  ansible.builtin.assert:
    that:
      - app_version is version('2.0', '>=')
      - db_connections | int < max_connections | int * 0.8
      - "'healthy' in health_check.content"
    success_msg: "All health checks passed"
    fail_msg: "Application not in expected state"
    quiet: true    # Suppress verbose assertion output (new in 2.20)
```

### Declarative Role Dependencies

Role `meta/main.yml` dependency declarations now support version constraints:

```yaml
# meta/main.yml
dependencies:
  - role: geerlingguy.docker
    version: ">=6.0,<7.0"
  - role: common
    vars:
      common_packages:
        - htop
        - curl
```

### Removed Features

- Removed: Non-FQCN module references (now errors)
- Removed: `include:` directive (use `include_tasks:` or `import_tasks:`)
- Removed: Legacy `with_*` loop syntax (use `loop:` with filters)
- Removed: `ansible_python_interpreter` auto-detection for Python 2

### Performance

- Improved connection pool management — reduced SSH connection overhead
- Faster playbook parsing for large codebases
- Better caching for `ansible-galaxy collection list` operations
- Parallel fact gathering improvements

### Python Requirements

- **Control node**: Python 3.11+ required
- **Managed nodes**: Python 3.9+ (raised from 3.8)
- **Jinja2**: 3.2+ required

## Migration from 2.19

1. **Critical**: Convert all non-FQCN module references to FQCNs — this is now an error
2. Replace `include:` with `include_tasks:` or `import_tasks:`
3. Replace `with_items`, `with_dict`, etc. with `loop:` + filters
4. Verify managed nodes run Python 3.9+ (dropped 3.8)
5. Run `ansible-lint` with the latest ruleset to catch all deprecated patterns
6. Test in check mode against staging before production rollout
