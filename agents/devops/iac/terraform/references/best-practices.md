# Terraform Best Practices

## Code Organization

### Repository Structure

```
infrastructure/
├── modules/                    # Reusable modules
│   ├── vpc/
│   ├── eks-cluster/
│   └── rds-instance/
├── environments/               # Environment-specific configurations
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── prod/
├── global/                     # Shared resources (IAM, DNS zones)
│   ├── iam/
│   └── dns/
└── terragrunt.hcl              # (Optional) DRY wrapper
```

### File Naming Conventions

| File | Contents |
|---|---|
| `main.tf` | Primary resources and module calls |
| `variables.tf` | All input variable declarations |
| `outputs.tf` | All output value declarations |
| `versions.tf` | `terraform {}` block: required version, required providers |
| `backend.tf` | Backend configuration (or in `versions.tf`) |
| `locals.tf` | Local value definitions |
| `data.tf` | Data source lookups |
| `terraform.tfvars` | Variable values (environment-specific, not committed for secrets) |

### Naming Conventions

- **Resources**: `snake_case`, descriptive, no technology prefix (the resource type already includes it)
  - Good: `aws_instance.web_server`, `aws_s3_bucket.logs`
  - Bad: `aws_instance.aws-web-server-instance-1`
- **Variables**: `snake_case`, descriptive, include unit if applicable (`timeout_seconds`, `disk_size_gb`)
- **Modules**: `kebab-case` directory names matching their purpose (`vpc`, `eks-cluster`)
- **Outputs**: Match the resource attribute they expose (`vpc_id`, `cluster_endpoint`)

## State Management

### State Isolation Strategy

Separate state files by blast radius and change frequency:

| Layer | State Key | Changes | Blast Radius |
|---|---|---|---|
| Networking | `network/vpc/terraform.tfstate` | Rarely | High (everything depends on it) |
| Data stores | `data/rds/terraform.tfstate` | Occasionally | Medium |
| Compute | `compute/eks/terraform.tfstate` | Frequently | Medium |
| Application | `app/api/terraform.tfstate` | Very frequently | Low |

### Cross-State References

Use `terraform_remote_state` data source or better, export outputs to a parameter store:

```hcl
# Preferred: Read from SSM/Secrets Manager (decoupled)
data "aws_ssm_parameter" "vpc_id" {
  name = "/infrastructure/network/vpc_id"
}

# Alternative: Direct state reference (tighter coupling)
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "mycompany-terraform-state"
    key    = "network/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Security

### Secrets Handling

1. **Never commit secrets to `.tfvars` or `.tf` files** — use environment variables, Vault, or CI/CD secret injection
2. **Mark sensitive variables** — `sensitive = true` prevents values from appearing in plan output
3. **Encrypt state at rest** — Enable SSE on S3/GCS/Azure Blob backends
4. **Restrict state access** — State contains all resource attributes including secrets. IAM-restrict the backend.
5. **Use OIDC for CI/CD** — GitHub Actions, GitLab CI can assume AWS/Azure/GCP roles via OIDC without static credentials

```hcl
variable "database_password" {
  type      = string
  sensitive = true  # Hidden in plan/apply output
}
```

### Policy as Code

| Tool | Scope | Integration |
|---|---|---|
| **Sentinel** | Terraform Enterprise/Cloud only | Native (pre-plan, post-plan, post-apply) |
| **OPA/Rego** | Any Terraform | Conftest on plan JSON, or OPA server |
| **Checkov** | Any Terraform | CLI or CI/CD, 1000+ built-in rules |
| **tfsec** | Any Terraform (now part of Trivy) | CLI or CI/CD, security-focused |

## CI/CD Integration

### Pipeline Pattern

```
PR opened → terraform fmt -check → terraform validate → terraform plan → post plan as PR comment
PR merged → terraform plan → manual approval → terraform apply
```

### Key Practices

1. **Plan on PR, apply on merge** — Never apply directly from a developer's machine in production
2. **Save plan file** — `terraform plan -out=plan.tfplan` ensures what was reviewed is what gets applied
3. **Post plan output to PR** — Reviewers see exactly what will change
4. **Use OIDC authentication** — No static credentials in CI/CD
5. **Lock provider versions** — Commit `.terraform.lock.hcl` to ensure reproducible builds
6. **Limit parallelism in CI** — `terraform apply -parallelism=10` to avoid API rate limiting

## Performance

### Large State Optimization

- **Target specific resources** — `terraform plan -target=aws_instance.web` (use sparingly, not as default workflow)
- **Reduce refresh scope** — `terraform plan -refresh=false` when you know state is current
- **Split state** — Decompose monolithic state into smaller, independent states
- **Provider caching** — Use `TF_PLUGIN_CACHE_DIR` to cache provider binaries across workspaces

### Module Optimization

- **Avoid `count` on modules with many resources** — Each count index creates a separate instance of every resource in the module
- **Prefer `for_each` over `count`** — `for_each` uses map keys (stable), `count` uses indices (fragile)
- **Minimize data source calls** — Cache results in locals if used multiple times

## Common Mistakes

1. **Using `count` with a list** — Removing an item shifts all indices, causing unnecessary destroy/recreate. Use `for_each` with a map.
2. **Ignoring `.terraform.lock.hcl`** — Not committing the lock file leads to non-reproducible builds.
3. **`depends_on` overuse** — Only use when implicit dependencies aren't sufficient. Over-use serializes the graph.
4. **Inline blocks vs separate resources** — Some resources (e.g., `aws_security_group_rule`) should be separate to avoid conflicts with inline `ingress`/`egress` blocks.
5. **Not using `moved` blocks for refactoring** — Renaming a resource without a `moved` block destroys and recreates it.
