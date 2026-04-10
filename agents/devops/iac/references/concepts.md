# Infrastructure as Code Concepts

## Core Principles

### Declarative vs Procedural

| Approach | Description | Example |
|---|---|---|
| **Declarative** | Describe the desired end state; the tool figures out how to get there | Terraform: "I want 3 VMs" — it creates, modifies, or destroys to match |
| **Procedural** | Describe the steps to execute in order | Ansible: "Create VM A, then VM B, then VM C" — it runs the steps |

Declarative is generally preferred for infrastructure provisioning because it handles convergence automatically. Procedural is common in configuration management where ordering matters (install package before starting service).

### State and Drift

**State** is the mapping between IaC code and real-world resources:

- **Terraform**: Maintains an explicit state file that records resource IDs, attributes, and metadata. Required for plan/apply to work.
- **Ansible**: Stateless — it checks current state on each run by querying the target system directly.
- **CloudFormation/Bicep**: State managed by the cloud provider (stack state).
- **Pulumi**: State stored in Pulumi Cloud or self-hosted backend.

**Drift** occurs when real-world infrastructure diverges from IaC code — someone made a manual change via the console, CLI, or another tool. Detection strategies:

| Tool | Drift Detection |
|---|---|
| Terraform | `terraform plan` (shows diff between state + code vs reality) |
| Ansible | Run playbook in check mode (`--check --diff`) |
| CloudFormation | Drift detection feature (per-stack) |
| ArgoCD/Flux | Continuous reconciliation (K8s resources only) |

### Idempotency

Applying the same IaC code multiple times must produce the same result:

- **Terraform**: Idempotent by design — `apply` is a no-op if infrastructure matches desired state
- **Ansible**: Idempotent if modules are used correctly. Shell/command modules are NOT idempotent unless `creates`/`removes` guards are used. The `apt`/`yum`/`file`/`template` modules are idempotent.
- **Danger zone**: Non-idempotent operations include: appending to files, running arbitrary shell commands, sending notifications, incrementing counters

### Modularity and Reuse

| Concept | Terraform | Ansible | Pulumi |
|---|---|---|---|
| **Reusable unit** | Module | Role | Component / Stack |
| **Registry** | Terraform Registry | Ansible Galaxy | Pulumi Registry |
| **Composition** | Module calls in root | Role includes in playbook | Import and instantiate |
| **Versioning** | Module version constraints | Role version in requirements.yml | Package versions |

## Infrastructure Patterns

### Layered Infrastructure

Decompose infrastructure into layers with separate state/lifecycle:

1. **Foundation** — VPC, subnets, DNS zones, IAM roles (changes rarely)
2. **Platform** — Kubernetes clusters, databases, message queues (changes occasionally)
3. **Application** — Deployments, services, config maps (changes frequently)

Each layer has its own IaC code, state, and deployment pipeline. Layers reference each other via outputs/data sources (Terraform) or inventory/variables (Ansible).

### Workspace/Environment Strategy

| Strategy | How | Pros | Cons |
|---|---|---|---|
| **Workspaces** (Terraform) | Same code, different state per workspace | Simple, DRY | All envs must have same structure |
| **Directory per environment** | Separate dirs with shared modules | Full flexibility per env | Code duplication risk |
| **Terragrunt** | DRY wrapper around Terraform | Inheritance, dependencies | Additional tool, learning curve |
| **Branch per environment** | Different branches for dev/staging/prod | Git-native | Merge conflicts, drift |

### Testing IaC

| Level | What | Tools |
|---|---|---|
| **Static analysis** | Syntax, linting, security scanning | `terraform validate`, `tflint`, `ansible-lint`, `checkov`, `tfsec` |
| **Unit tests** | Module logic in isolation | `terraform test` (1.6+), Pulumi unit tests, Molecule (Ansible) |
| **Integration tests** | Apply to real infra, validate, destroy | Terratest (Go), Kitchen-Terraform, Molecule |
| **Policy as code** | Enforce organizational rules | Sentinel (Terraform Enterprise), OPA/Rego, Checkov |
