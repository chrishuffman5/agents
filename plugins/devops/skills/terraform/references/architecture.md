# Terraform Architecture

## Provider Plugin Protocol

Terraform providers are separate binaries that communicate with the Terraform core via gRPC (protocol version 5 for SDK v1, version 6 for the Terraform Plugin Framework).

### Provider Lifecycle

1. **Discovery** -- Terraform reads `required_providers` blocks, downloads from the registry (or mirrors)
2. **Initialization** -- `terraform init` downloads provider binaries to `.terraform/providers/`
3. **Configuration** -- Provider block sets authentication, region, endpoints
4. **Schema exchange** -- Provider advertises its resource and data source schemas to core
5. **CRUD operations** -- Core calls provider's Create, Read, Update, Delete methods via gRPC

### Provider Configuration

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"    # >= 5.0.0, < 6.0.0
    }
  }
}

provider "aws" {
  region = "us-east-1"
  # Authentication: env vars (AWS_ACCESS_KEY_ID), shared config, IAM role, OIDC
}
```

**Version constraints:**
- `= 5.0.0` -- Exact version
- `~> 5.0` -- Compatible (>= 5.0.0, < 6.0.0)
- `>= 5.0, < 5.5` -- Range
- Lock file (`.terraform.lock.hcl`) records exact versions and hashes

### Provider Authentication Patterns

| Provider | Preferred Auth | Avoid |
|---|---|---|
| AWS | OIDC federation, IAM instance profile, SSO | Static access keys in config |
| Azure | Managed identity, OIDC, service principal + client cert | Client secret in config |
| GCP | Workload identity federation, service account key file (limited) | Key file in version control |

## State File Internals

The state file is JSON with this structure:

```json
{
  "version": 4,
  "terraform_version": "1.15.0",
  "serial": 42,
  "lineage": "unique-uuid",
  "outputs": { ... },
  "resources": [
    {
      "module": "module.vpc",
      "mode": "managed",
      "type": "aws_vpc",
      "name": "main",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 1,
          "attributes": {
            "id": "vpc-0abc123",
            "cidr_block": "10.0.0.0/16",
            ...
          }
        }
      ]
    }
  ]
}
```

### State Semantics

- **serial** -- Incremented on every write. Used for conflict detection.
- **lineage** -- UUID created on `terraform init`. Prevents applying state from a different workspace.
- **Resources** -- Each resource instance stores all attributes, including computed ones (IDs, ARNs).
- **Sensitive values** -- Marked in state but NOT encrypted. State file must be encrypted at rest.

### Backend Architecture

| Backend | State Storage | Locking | Encryption |
|---|---|---|---|
| S3 | S3 bucket | DynamoDB table | SSE-S3 or SSE-KMS |
| GCS | GCS bucket | Native (object versioning) | Google-managed or CMEK |
| Azure Blob | Storage container | Native (blob lease) | SSE or CMEK |
| Terraform Cloud | HashiCorp managed | Native | HashiCorp managed |
| Consul | Consul KV | Native (session locking) | TLS + ACLs |
| pg (PostgreSQL) | PostgreSQL table | Advisory locks | TLS + column encryption |

## Dependency Graph

Terraform builds a directed acyclic graph (DAG) of all resources and data sources:

1. **Implicit dependencies** -- Resource A references resource B's attribute → A depends on B
2. **Explicit dependencies** -- `depends_on` meta-argument forces ordering
3. **Parallel execution** -- Independent resources are created/destroyed in parallel (configurable via `-parallelism`)
4. **Destroy ordering** -- Reverse of creation order

View the graph: `terraform graph | dot -Tsvg > graph.svg`

### Dependency Issues

- **Cycles** -- Two resources referencing each other. Break with `depends_on` or restructure.
- **Implicit via provider** -- Resources in the same provider share authentication. Provider config changes affect all resources.
- **Cross-module** -- Module outputs create dependencies between modules. Design module interfaces carefully.

## Plan/Apply Mechanics

### Plan Phase

1. Read current state from backend
2. Refresh: query each provider to get real-world resource state (skip with `-refresh=false`)
3. Compare: desired (config) vs known (state) vs actual (refreshed)
4. Generate plan: list of create, update, destroy, or no-op actions
5. Save plan to file (optional: `terraform plan -out=plan.tfplan`)

### Apply Phase

1. Read the plan (from file or re-plan)
2. Walk the dependency graph in topological order
3. For each resource: call provider's CRUD method
4. Update state after each successful operation
5. Report results

### Plan Output Symbols

| Symbol | Meaning |
|---|---|
| `+` | Create |
| `-` | Destroy |
| `~` | Update in-place |
| `-/+` | Destroy and recreate (replacement) |
| `<=` | Read (data source) |

## Terraform Cloud / Enterprise Architecture

### Execution Modes

| Mode | Where plan/apply runs | State storage |
|---|---|---|
| **Remote** | Terraform Cloud workers | Terraform Cloud |
| **Local** | Your machine | Terraform Cloud (state only) |
| **Agent** | Self-hosted agents behind firewall | Terraform Cloud |

### Workspace Model

Terraform Cloud workspaces map to state files, not CLI workspaces:

- Each workspace = one state file + one VCS repo/directory + variables + run history
- Workspaces can be organized by environment (dev, staging, prod) or component (network, compute, data)
- Run triggers: workspace A's apply can trigger workspace B's plan (cross-workspace dependencies)
