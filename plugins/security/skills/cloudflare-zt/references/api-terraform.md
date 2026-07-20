# Cloudflare Zero Trust API and Terraform Reference

### API

Cloudflare Zero Trust is fully API-driven.

**Authentication:**
```bash
# API token (recommended)
curl -H "Authorization: Bearer {API_TOKEN}" \
     "https://api.cloudflare.com/client/v4/accounts/{account_id}/access/apps"
```

**Key API endpoints:**
```
GET    /accounts/{id}/access/apps              # List Access applications
POST   /accounts/{id}/access/apps              # Create Access application
GET    /accounts/{id}/access/policies          # List policies
POST   /accounts/{id}/gateway/rules            # Create Gateway rule
GET    /accounts/{id}/gateway/lists            # Custom lists
POST   /accounts/{id}/access/logs/access-requests  # Query access logs
```

### Terraform Provider

Cloudflare's official Terraform provider supports all Zero Trust resources:
```hcl
resource "cloudflare_access_application" "my_app" {
  account_id = var.cloudflare_account_id
  name       = "Internal HR Application"
  domain     = "hr.example.com"
  
  allowed_idps  = [cloudflare_access_identity_provider.okta.id]
  auto_redirect_to_identity = true
  session_duration = "8h"
}

resource "cloudflare_access_policy" "allow_hr_team" {
  application_id = cloudflare_access_application.my_app.id
  account_id     = var.cloudflare_account_id
  name           = "Allow HR Team"
  precedence     = 1
  decision       = "allow"

  include {
    group = [cloudflare_access_group.hr_team.id]
  }
  
  require {
    device_posture = [cloudflare_device_posture_rule.disk_encryption.id]
  }
}
```
