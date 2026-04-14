---
name: devops-iac-ansible-2-19
description: "Version-specific expert for ansible-core 2.19. Covers enhanced argspec validation, improved async task handling, new inventory plugin features, and Jinja2 3.2 requirement. WHEN: \"Ansible 2.19\", \"ansible-core 2.19\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Ansible 2.19 (ansible-core) Version Expert

You are a specialist in ansible-core 2.19. This is part of the last-3-major-versions support window.

For foundational Ansible knowledge (playbooks, roles, inventory, modules), refer to the parent technology agent. This agent focuses on what is new or changed in 2.19.

## Key Changes

### Jinja2 3.2+ Requirement

- Minimum Jinja2 version bumped to 3.2 (from 3.1)
- New Jinja2 features available in templates: improved `select`/`reject` filters, enhanced error messages
- Native Jinja2 types enabled by default — `{{ 42 }}` produces an integer, not a string

### Enhanced Argspec Validation

Modules now perform stricter argument validation:
- Unknown parameters are rejected by default (previously warned)
- Type coercion is more predictable and less permissive
- `required_if`, `required_by`, `mutually_exclusive` validations are enforced earlier

**Impact**: Playbooks with incorrect parameter types that "worked" before may now fail. Run `--check` mode first.

### Improved Async Tasks

Async task handling improvements:
- Better cleanup of orphaned async jobs
- Improved status reporting for long-running async tasks
- `async_status` module now returns structured progress data

```yaml
- name: Start long backup
  ansible.builtin.command: /opt/backup/full.sh
  async: 7200
  poll: 0
  register: backup_job

- name: Wait for backup
  ansible.builtin.async_status:
    jid: "{{ backup_job.ansible_job_id }}"
  register: backup_result
  until: backup_result.finished
  retries: 60
  delay: 120
```

### Inventory Plugin Enhancements

- `constructed` inventory plugin gains `strict` mode improvements
- AWS `aws_ec2` plugin supports instance metadata v2 (IMDSv2) by default
- Azure `azure_rm` plugin supports managed identity natively
- New `compose` variables can reference Jinja2 filters

### Callback Plugin Improvements

- `junit` callback produces richer output for CI/CD integration
- `json` callback includes task-level timing data
- Custom callback plugin registration simplified

## Migration from 2.18

1. Ensure Jinja2 3.2+ installed (`pip show jinja2`)
2. Review any templates relying on Jinja2 string coercion — native types are now default
3. Run playbooks in `--check` mode to catch argspec validation failures
4. Update dynamic inventory scripts if using AWS IMDSv1 exclusively
5. Test async workflows — improved but behavior may differ
