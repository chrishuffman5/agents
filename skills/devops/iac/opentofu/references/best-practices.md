# OpenTofu Best Practices

## Migration from Terraform

### Pre-Migration Checklist

1. **Audit Terraform version**: OpenTofu tracks Terraform 1.5.x as its base. Features added in Terraform 1.6+ may or may not be in OpenTofu.
2. **Audit providers**: Check all `required_providers` against the OpenTofu Registry
3. **Audit modules**: Verify modules don't use Terraform-only features (Stacks, ephemeral resources syntax differences)
4. **Audit CI/CD**: Replace `terraform` with `tofu` in pipeline scripts
5. **Audit Terraform Cloud usage**: OpenTofu has no equivalent to Terraform Cloud. Plan alternatives for remote execution, Sentinel, private registry.

### Migration Script

```bash
#!/bin/bash
# Simple migration: replace terraform command with tofu
# State files, providers, and modules are compatible

# 1. Install OpenTofu alongside Terraform
# 2. In the project directory:
tofu init -upgrade    # Re-initialize with OpenTofu Registry
tofu plan             # Verify plan matches terraform plan output
# 3. If plan is clean, migration is complete
```

### Gradual Migration

For organizations with many projects:

1. **New projects**: Use OpenTofu from day one
2. **Active projects**: Migrate during next major change
3. **Stable projects**: Migrate during scheduled maintenance
4. **Test thoroughly**: Run `tofu plan` and compare against `terraform plan` output

## State Encryption

### When to Use

- **Always** for state containing secrets (database passwords, API keys, certificates)
- **Compliance**: When regulations require encryption at rest beyond backend-level encryption
- **Defense in depth**: Even with S3 SSE, client-side encryption adds a layer

### Key Management

```hcl
# Production: Use cloud KMS
terraform {
  encryption {
    key_provider "aws_kms" "prod" {
      kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/uuid"
      region     = "us-east-1"
    }
    method "aes_gcm" "enc" {
      keys = key_provider.aws_kms.prod
    }
    state {
      method   = method.aes_gcm.enc
      enforced = true
    }
  }
}

# Development: Use passphrase (simpler)
terraform {
  encryption {
    key_provider "pbkdf2" "dev" {
      passphrase = var.state_passphrase    # From env var or CI secret
    }
    method "aes_gcm" "enc" {
      keys = key_provider.pbkdf2.dev
    }
    state {
      method = method.aes_gcm.enc
    }
  }
}
```

## CI/CD Integration

### GitHub Actions

```yaml
- uses: opentofu/setup-opentofu@v1
  with:
    tofu_version: '1.x'

- run: tofu init
- run: tofu plan -out=plan.tfplan
- run: tofu apply plan.tfplan
```

### GitLab CI

```yaml
plan:
  image:
    name: ghcr.io/opentofu/opentofu:latest
    entrypoint: [""]
  script:
    - tofu init
    - tofu plan -out=plan.tfplan
  artifacts:
    paths: [plan.tfplan]
```

## Provider Pinning

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"    # Same source — OpenTofu mirrors it
      version = "~> 5.0"
    }
  }
}
```

Commit `.terraform.lock.hcl` to ensure reproducible builds across Terraform and OpenTofu.

## Common Mistakes

1. **Assuming full Terraform feature parity** — OpenTofu diverges on newer features. Check release notes.
2. **Not testing plan output after migration** — Always verify `tofu plan` matches expectations before applying.
3. **Skipping state encryption setup** — OpenTofu's state encryption is a major advantage. Use it.
4. **Using `enforced = true` without key backup** — If you lose the encryption key, state is unrecoverable.
