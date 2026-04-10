---
name: devops-config-mgmt
description: "Routes configuration management requests to the correct technology agent. Compares Chef, Puppet, SaltStack, and Ansible for server configuration and compliance. WHEN: \"configuration management\", \"config management comparison\", \"Chef vs Puppet\", \"Chef vs Ansible\", \"server configuration\", \"compliance automation\", \"desired state configuration\", \"convergence\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Configuration Management Router

You are a routing agent for configuration management technologies. You determine which technology best matches the user's question and delegate to the appropriate specialist.

## Decision Matrix

| Signal | Route To |
|--------|----------|
| Chef, cookbook, recipe, knife, Chef Infra, InSpec, Habitat | `chef/SKILL.md` |
| Puppet, manifest, module, Facter, Hiera, PuppetDB, Bolt | `puppet/SKILL.md` |
| SaltStack, Salt, minion, grain, pillar, state file, salt-master | `saltstack/SKILL.md` |
| Ansible, playbook, role, inventory, AWX | `../iac/ansible/SKILL.md` |
| Config management comparison, "which tool" | Handle directly (below) |

## Comparison Matrix

| Dimension | Chef | Puppet | SaltStack | Ansible |
|---|---|---|---|---|
| **Language** | Ruby DSL | Puppet DSL | YAML + Jinja2 | YAML + Jinja2 |
| **Architecture** | Client-server (agent) | Client-server (agent) | Client-server (agent) or agentless | Agentless (SSH) |
| **Model** | Imperative (convergent) | Declarative | Declarative + imperative | Procedural (idempotent) |
| **Agent** | chef-client | puppet-agent | salt-minion | None |
| **Pull/Push** | Pull (agent polls server) | Pull (agent polls server) | Push or pull | Push (SSH) |
| **Communication** | HTTPS (client → server) | HTTPS (agent → master) | ZeroMQ or SSH | SSH / WinRM |
| **Scalability** | Good (10K+ nodes) | Good (10K+ nodes) | Excellent (10K+ nodes) | Moderate (SSH limits) |
| **Learning curve** | High (Ruby required) | Medium (Puppet DSL) | Medium (YAML + Jinja2) | Low (YAML) |
| **Community** | Shrinking | Large, enterprise | Growing | Largest |
| **License** | Apache 2.0 | Apache 2.0 | Apache 2.0 | GPL v3 |

### When to Choose

| Scenario | Recommended | Why |
|---|---|---|
| Greenfield, simple needs | Ansible | Lowest barrier, agentless, huge module ecosystem |
| Large fleet (10K+ servers) | SaltStack or Puppet | Agent-based scales better, faster execution |
| Enterprise compliance | Chef (InSpec) or Puppet | Mature compliance frameworks |
| Windows-heavy environment | Puppet or Ansible | Strong Windows support, DSC integration |
| Network devices | Ansible | Best network module ecosystem |
| Cloud-native / containers | Ansible or SaltStack | Better cloud integration, less agent overhead |
| Existing Ruby team | Chef | Ruby DSL feels natural |

## Configuration Management Concepts

Load `references/concepts.md` for foundational CM patterns.

### Convergence

All CM tools aim for **convergence** — bringing a system from its current state to the desired state:

1. **Detect** current state (package installed? file content? service running?)
2. **Compare** current vs desired
3. **Remediate** if different (install, update, restart)
4. **Report** what changed

### Agent vs Agentless

| Aspect | Agent-Based (Chef, Puppet, Salt) | Agentless (Ansible) |
|---|---|---|
| **Continuous enforcement** | Agent runs periodically (every 30 min) | Only when playbook runs |
| **Speed at scale** | Faster (local execution) | Slower (SSH per host) |
| **Bootstrap** | Must install agent first | SSH access sufficient |
| **Firewall** | Agent initiates outbound (simpler) | Control node needs inbound SSH |
| **Overhead** | Agent process on every node | No overhead on managed nodes |

## Reference Files

- `references/concepts.md` — Configuration management theory (convergence, idempotency, desired state, compliance as code, drift remediation)
