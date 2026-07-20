# OpenTofu Architecture

## Fork History and Divergence

OpenTofu forked from Terraform v1.5.6 (the last MPL-licensed version) in September 2023. Since then:

- **Shared heritage**: Core HCL parser, provider protocol, state format, backend system
- **Independent development**: State encryption, early evaluation, registry, removed block semantics
- **Provider compatibility**: OpenTofu uses the same provider protocol, so most providers work without modification

### Version Mapping

| OpenTofu | Terraform Equivalent | Notes |
|---|---|---|
| 1.6.x | ~1.6.x | First OpenTofu release, high compatibility |
| 1.7.x | ~1.7.x | State encryption added, early evaluation |
| 1.8.x | ~1.8.x | Provider-defined functions (own implementation) |
| 1.9.x+ | Diverging | Increasing divergence on new features |

## Registry Architecture

### OpenTofu Registry

The OpenTofu Registry (`registry.opentofu.org`) serves providers and modules:

- **Provider mirroring**: Automatically mirrors providers from the Terraform Registry
- **Community providers**: Accepts direct provider submissions
- **Module registry**: Supports the same module registry protocol as Terraform
- **CDN-backed**: Artifacts served via CDN for performance

### Provider Resolution

```
tofu init
    │
    ▼
┌──────────────────┐
│ Read required_    │
│ providers block   │
└──────┬───────────┘
       │
┌──────▼───────────┐
│ Check lock file   │  .terraform.lock.hcl
│ (exact versions)  │
└──────┬───────────┘
       │
┌──────▼───────────┐
│ Query OpenTofu    │  registry.opentofu.org
│ Registry          │  (falls back to Terraform Registry if configured)
└──────┬───────────┘
       │
┌──────▼───────────┐
│ Download + verify │  SHA256 hash + GPG signature
└──────┬───────────┘
       │
┌──────▼───────────┐
│ Store in          │  .terraform/providers/
│ plugin cache      │
└──────────────────┘
```

### Provider Installation Configuration

```hcl
# Override provider resolution
provider_installation {
  # Try OpenTofu Registry first
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }

  # Mirror for air-gapped environments
  filesystem_mirror {
    path    = "/usr/share/terraform/providers"
    include = ["registry.opentofu.org/*/*"]
  }

  # Network mirror
  network_mirror {
    url = "https://providers.example.com/"
  }
}
```

## State Encryption Deep Dive

### Encryption Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│ State Data   │────▶│ Key Provider │────▶│ Encryption   │
│ (JSON)       │     │ (KMS/PBKDF2) │     │ Method       │
└─────────────┘     └──────────────┘     │ (AES-GCM)    │
                                          └──────┬───────┘
                                                 │
                                          ┌──────▼───────┐
                                          │ Encrypted    │
                                          │ State File   │
                                          │ (backend)    │
                                          └──────────────┘
```

### Key Providers

| Provider | Key Source | Use Case |
|---|---|---|
| `pbkdf2` | Passphrase-derived | Development, simple setups |
| `aws_kms` | AWS KMS key | AWS environments |
| `gcp_kms` | GCP Cloud KMS key | GCP environments |
| `openbao` | OpenBao (Vault fork) | Self-hosted key management |

### Encryption Targets

```hcl
terraform {
  encryption {
    key_provider "aws_kms" "state_key" {
      kms_key_id = "alias/tofu-state-key"
      region     = "us-east-1"
    }

    method "aes_gcm" "state_enc" {
      keys = key_provider.aws_kms.state_key
    }

    # Encrypt state file
    state {
      method   = method.aes_gcm.state_enc
      enforced = true    # Fail if encryption unavailable
    }

    # Encrypt plan files
    plan {
      method   = method.aes_gcm.state_enc
      enforced = true
    }
  }
}
```

### Key Rotation

```hcl
terraform {
  encryption {
    key_provider "aws_kms" "new_key" {
      kms_key_id = "alias/tofu-state-key-v2"
    }
    key_provider "aws_kms" "old_key" {
      kms_key_id = "alias/tofu-state-key-v1"
    }

    method "aes_gcm" "new_enc" {
      keys = key_provider.aws_kms.new_key
    }
    method "aes_gcm" "old_enc" {
      keys = key_provider.aws_kms.old_key
    }

    state {
      method = method.aes_gcm.new_enc
      fallback {
        method = method.aes_gcm.old_enc    # Decrypt with old, encrypt with new
      }
    }
  }
}
```

## Early Variable Evaluation

OpenTofu evaluates variables and locals before backend and module source resolution:

```hcl
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type = string
}

# Variables in backend config — OpenTofu only
terraform {
  backend "s3" {
    bucket = "mycompany-${var.environment}-tfstate"
    key    = "infrastructure/terraform.tfstate"
    region = var.region
  }
}

# Variables in module source — OpenTofu only
module "vpc" {
  source  = "git::https://github.com/org/modules.git//vpc?ref=${var.module_version}"
  # ...
}
```

This eliminates the need for `-backend-config` flags or wrapper tools like Terragrunt for dynamic backend configuration.
