# Terraform Diagnostics

## Common Errors and Resolution

### State Lock Errors

```
Error: Error acquiring the state lock
Lock Info:
  ID:        xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Path:      s3://bucket/key/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
  Version:   1.15.0
  Created:   2026-04-01 10:30:00.000000 UTC
```

**Diagnosis:**
1. Check if another `terraform apply` is running (legitimate lock)
2. Check if a previous run crashed (stale lock)
3. Check the `Who` field — is it a CI pipeline or a person?

**Resolution:**
- If stale: `terraform force-unlock <LOCK_ID>` (confirm no other operation is running first)
- If legitimate: Wait for the other operation to complete
- Prevention: Use CI/CD with queued runs (Terraform Cloud, Atlantis) to prevent concurrent operations

### Provider Authentication Failures

```
Error: error configuring Terraform AWS Provider: no valid credential sources found
```

**Diagnosis:**
1. Check environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_PROFILE`
2. Check shared credentials file: `~/.aws/credentials`
3. Check IAM instance profile (EC2) or OIDC federation (CI/CD)
4. Check `provider` block configuration

**Resolution:**
- Set credentials via environment variables or AWS SSO: `aws sso login --profile myprofile`
- In CI/CD: Configure OIDC role assumption
- Verify IAM permissions for the operations Terraform needs

### Dependency Cycle

```
Error: Cycle: aws_security_group.a, aws_security_group.b
```

**Diagnosis:** Two or more resources reference each other, creating a circular dependency.

**Resolution:**
1. Break the cycle by using separate resources for the cross-reference:
   ```hcl
   # Instead of inline security group rules that reference each other:
   resource "aws_security_group_rule" "a_to_b" {
     security_group_id        = aws_security_group.a.id
     source_security_group_id = aws_security_group.b.id
     type                     = "ingress"
     ...
   }
   ```
2. Use `depends_on` with a third resource that both depend on
3. Restructure to eliminate the circular reference

### Plan Shows Unexpected Changes (Drift)

```
# aws_instance.web will be updated in-place
  ~ resource "aws_instance" "web" {
      ~ tags = {
          + "ManagedBy" = "manual-change"
        }
    }
```

**Diagnosis:** Someone modified the resource outside of Terraform (console, CLI, another tool).

**Resolution:**
1. If the manual change should be kept: Update the Terraform config to match, then `terraform plan` shows no changes
2. If the manual change should be reverted: `terraform apply` to enforce the declared state
3. If the attribute should be ignored: Add `lifecycle { ignore_changes = [tags] }`

### Resource Already Exists

```
Error: creating EC2 Instance: InvalidParameterValue: The instance ID 'i-0abc123' already exists
```

**Diagnosis:** The resource exists in the cloud but not in Terraform state. Common after:
- Manual creation
- State loss
- `terraform state rm` without destroying

**Resolution:**
1. Import the existing resource: `terraform import aws_instance.web i-0abc123`
2. Or use import blocks (1.5+):
   ```hcl
   import {
     to = aws_instance.web
     id = "i-0abc123"
   }
   ```
3. Run `terraform plan` to verify alignment between config and imported state

### Provider Version Constraints

```
Error: Failed to query available provider packages
Could not retrieve the list of available versions for provider hashicorp/aws:
locked provider registry.terraform.io/hashicorp/aws 5.30.0 does not match configured version constraint ~> 5.40
```

**Resolution:**
1. Update the lock file: `terraform init -upgrade`
2. Or adjust the version constraint in `versions.tf`
3. Review changelog for breaking changes between versions

## Debugging Workflows

### Enable Detailed Logging

```bash
# Set log level (TRACE, DEBUG, INFO, WARN, ERROR)
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log

# Provider-specific logging
export TF_LOG_PROVIDER=DEBUG
export TF_LOG_CORE=WARN

terraform plan 2>&1 | tee plan-output.log
```

### Inspect State

```bash
# List all resources in state
terraform state list

# Show specific resource
terraform state show aws_instance.web

# Pull remote state to local file for inspection
terraform state pull > state.json

# Compare plan output in JSON
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json
```

### Validate Configuration

```bash
# Syntax and internal consistency check
terraform validate

# Format check (CI-friendly)
terraform fmt -check -recursive

# Check for security issues
checkov -d .
trivy config .
```

## State Recovery

### Corrupted State

1. Check for backups: S3 versioning, GCS object versioning, or `.terraform.tfstate.backup`
2. Restore from backup: download previous version from backend
3. Re-import resources if no backup exists

### Lost State

If state is completely lost but infrastructure exists:

1. Create `.tf` files describing the existing infrastructure
2. Import each resource: `terraform import <resource_address> <resource_id>`
3. Run `terraform plan` to verify — iterate until plan shows no changes
4. Tools like `terraformer` can generate config from existing cloud resources (use as starting point, not final config)

### State Surgery

```bash
# Remove a resource from state (Terraform stops managing it, doesn't destroy it)
terraform state rm aws_instance.old_server

# Move a resource (refactoring)
terraform state mv aws_instance.old_name aws_instance.new_name
terraform state mv module.old_module.aws_instance.web module.new_module.aws_instance.web

# Replace provider in state (e.g., after provider fork)
terraform state replace-provider hashicorp/aws registry.example.com/aws
```
