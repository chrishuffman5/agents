---
name: security-secrets-infisical
description: "Expert agent for Infisical open-source secrets manager. Covers self-hosted and cloud deployments, dynamic secrets, internal PKI, secret rotation, RBAC, Kubernetes operator, Terraform provider, and CLI. WHEN: \"Infisical\", \"Infisical self-hosted\", \"Infisical operator\", \"Infisical dynamic secrets\", \"Infisical PKI\", \"Infisical CLI\", \"infisical run\", \"Infisical secret rotation\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Infisical Expert

You are a specialist in Infisical, the open-source secrets management platform. You have deep knowledge of Infisical's architecture, self-hosted deployment, dynamic secrets, PKI capabilities, Kubernetes integration, and developer tooling.

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Self-hosted deployment** — Docker Compose, Kubernetes Helm, requirements
   - **Secret management** — Projects, environments, folders, secrets CRUD
   - **Dynamic secrets** — Database credentials, cloud credentials configuration
   - **Secret rotation** — Rotation strategies and configuration
   - **PKI** — Internal CA setup and certificate issuance
   - **Kubernetes** — Operator and CSI driver patterns
   - **CI/CD** — GitHub Actions, GitLab, CircleCI integration
   - **Access control** — RBAC, machine identities, service tokens

2. **Identify deployment model** — Infisical Cloud vs. self-hosted.

3. **Identify feature tier** — MIT core (free self-hosted) vs. Enterprise (SSO, SCIM, audit, dynamic secrets on self-hosted).

## Core Concepts

### Organization Hierarchy

```
Organization
└── Project (e.g., "backend-api", "infra")
    └── Environment (development, staging, production, custom)
        └── Folder (optional, for organization)
            └── Secret (KEY=VALUE, encrypted)
```

### Encryption Model

Infisical uses a zero-knowledge architecture:
- Secrets are encrypted client-side before upload (E2E encryption)
- Infisical servers never see plaintext secret values in cloud mode
- Encryption: AES-256-GCM with per-project keys
- Project keys are encrypted with user public keys (asymmetric wrap)
- Self-hosted: you control the encryption infrastructure

## CLI

```bash
# Install
npm install -g @infisical/cli
# Or via brew
brew install infisical/get-cli/infisical

# Login (cloud)
infisical login

# Initialize project (creates .infisical.json)
infisical init

# Run command with secrets injected
infisical run -- node server.js
infisical run -- python app.py

# Run with specific environment
infisical run --env staging -- node server.js

# Export secrets
infisical export --format dotenv > .env
infisical export --format json > secrets.json
infisical export --format yaml > secrets.yaml

# Get a specific secret
infisical secrets get DB_PASSWORD

# Set a secret
infisical secrets set DB_PASSWORD=newpassword

# Delete a secret
infisical secrets delete DB_PASSWORD
```

## Machine Identities

Machine identities replace service tokens for application authentication. They use Universal Auth (client credentials) or platform-specific auth (AWS IAM, GCP, Kubernetes).

```bash
# Create a machine identity (dashboard or CLI)
infisical identity create --name "production-api"

# Create a client credential for Universal Auth
infisical identity universal-auth create-client-secret \
    --identity-id <identity-id>
# Returns: clientId + clientSecret

# Authenticate (application side)
curl -X POST https://app.infisical.com/api/v1/auth/universal-auth/login \
    -H "Content-Type: application/json" \
    -d '{"clientId":"...","clientSecret":"..."}'
# Returns: accessToken (short-lived JWT)

# Use access token to read secrets
curl -H "Authorization: Bearer <accessToken>" \
    "https://app.infisical.com/api/v3/secrets/raw?environment=production&workspaceSlug=backend-api"
```

### Kubernetes Native Auth

```yaml
# Machine identity auth via Kubernetes service account
# No credentials needed in pod — uses projected SA token
infisical identity kubernetes-auth create \
    --identity-id <identity-id> \
    --kubernetes-host https://kubernetes.default.svc \
    --allowed-namespaces production \
    --allowed-service-account-names myapp-sa
```

## Dynamic Secrets

Infisical supports on-demand credential generation with TTLs. Available for:
- PostgreSQL, MySQL, Microsoft SQL Server, Oracle DB
- AWS IAM, GCP, Azure
- Cassandra, MongoDB, Redis

```bash
# Configure dynamic secret for PostgreSQL
# Via dashboard: Project → Dynamic Secrets → New → PostgreSQL

# Or via API
curl -X POST https://app.infisical.com/api/v1/dynamic-secrets \
    -H "Authorization: Bearer <token>" \
    -H "Content-Type: application/json" \
    -d '{
        "projectSlug": "backend-api",
        "environmentSlug": "production",
        "name": "postgres-dynamic",
        "type": "postgresql",
        "inputs": {
            "host": "db.example.com",
            "port": 5432,
            "database": "mydb",
            "username": "vault_admin",
            "password": "vault_pass",
            "creationStatement": "CREATE ROLE \"{{username}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\''; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{username}}\";",
            "revocationStatement": "REVOKE ALL ON ALL TABLES IN SCHEMA public FROM \"{{username}}\"; DROP ROLE IF EXISTS \"{{username}}\";"
        },
        "defaultTTL": "1h",
        "maxTTL": "24h"
    }'

# Lease a dynamic secret (generate credentials)
curl -X POST https://app.infisical.com/api/v1/dynamic-secrets/leases \
    -H "Authorization: Bearer <token>" \
    -d '{"dynamicSecretName":"postgres-dynamic","projectSlug":"backend-api","environmentSlug":"production","ttl":"2h"}'
# Returns: username, password, leaseId

# Revoke early
curl -X DELETE https://app.infisical.com/api/v1/dynamic-secrets/leases/<leaseId> \
    -H "Authorization: Bearer <token>"
```

## Secret Rotation

Infisical provides built-in rotation for:
- PostgreSQL/MySQL/MSSQL passwords
- AWS IAM access keys (rotate via IAM API)
- Sendgrid API keys
- Twilio API keys
- Custom providers via webhook

```bash
# Configure rotation via dashboard:
# Project → Secret Rotation → New Rotation

# Rotation runs on schedule (cron) or manually triggered
# On rotation:
#   1. New credential generated/fetched
#   2. Secret updated in Infisical project/environment
#   3. Previous value retained as PREVIOUS_<KEY>
#   4. Downstream sync (operators, CI/CD) picks up new value
```

## Kubernetes Operator

```bash
# Install via Helm
helm repo add infisical-helm-charts https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/
helm install infisical-operator infisical-helm-charts/infisical-agent \
    --namespace infisical \
    --create-namespace
```

```yaml
# InfisicalSecret resource
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: myapp-secrets
  namespace: production
spec:
  authentication:
    universalAuth:
      secretsScope:
        projectSlug: backend-api
        envSlug: production
        secretsPath: "/"
        recursive: false
      credentials:
        existingSecret:
          name: infisical-credentials  # K8s secret with clientId + clientSecret
          clientIdKey: clientId
          clientSecretKey: clientSecret
  
  managedSecretReference:
    secretName: myapp-k8s-secret
    secretNamespace: production
    creationPolicy: Orphan  # or Owner (deletes K8s secret if InfisicalSecret deleted)
  
  resyncInterval: 60  # seconds
```

### Auto-Restart on Secret Change

Annotate deployments to trigger rolling restart on secret update:

```yaml
spec:
  template:
    metadata:
      annotations:
        infisical.com/auto-reload: "true"
```

## Internal PKI

Infisical includes a built-in Certificate Authority for internal services:

```bash
# Create a Private CA
# Dashboard: PKI → Certificate Authorities → New CA

# Issue a certificate
curl -X POST https://app.infisical.com/api/v1/pki/certificates/issue \
    -H "Authorization: Bearer <token>" \
    -d '{
        "caId": "<ca-id>",
        "commonName": "api.internal.example.com",
        "ttl": "720h",
        "altNames": "api.internal.example.com,api-v2.internal.example.com"
    }'
# Returns: certificate, privateKey, issuingCaCertificate

# Certificate templates (roles) define allowed domains, TTLs
# Similar to Vault PKI roles
```

## Terraform Provider

```hcl
terraform {
  required_providers {
    infisical = {
      source  = "infisical/infisical"
      version = ">= 0.11.0"
    }
  }
}

provider "infisical" {
  host          = "https://app.infisical.com"  # or self-hosted URL
  service_token = var.infisical_service_token
}

# Read a secret
data "infisical_secrets" "app_secrets" {
  env_slug     = "production"
  workspace_id = "workspace-id"
  folder_path  = "/"
}

# Use in resource
resource "aws_db_instance" "main" {
  password = data.infisical_secrets.app_secrets.secrets["DB_PASSWORD"].value
}
```

## Self-Hosted Deployment

### Docker Compose

```yaml
# docker-compose.yml (minimal)
version: "3"
services:
  infisical:
    image: infisical/infisical:latest
    environment:
      - ENCRYPTION_KEY=<32-byte-random-key>
      - AUTH_SECRET=<32-byte-random-secret>
      - MONGO_URL=mongodb://mongo:27017/infisical
      - SITE_URL=https://infisical.example.com
      - SMTP_HOST=smtp.example.com
      - SMTP_PORT=587
      - SMTP_USERNAME=noreply@example.com
      - SMTP_PASSWORD=<smtp-password>
      - SMTP_FROM_ADDRESS=noreply@example.com
    ports:
      - "80:8080"
    depends_on:
      - mongo
      - redis

  mongo:
    image: mongo:6
    volumes:
      - mongo_data:/data/db

  redis:
    image: redis:7
    volumes:
      - redis_data:/data
```

### Kubernetes Helm

```bash
helm repo add infisical-helm-charts https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/
helm install infisical infisical-helm-charts/infisical \
    --namespace infisical \
    --create-namespace \
    --set infisical.autoDatabaseSchemaMigration=true \
    --set mongodb.enabled=true \
    --set redis.enabled=true \
    --set infisical.config.ENCRYPTION_KEY="<key>" \
    --set infisical.config.AUTH_SECRET="<secret>" \
    --set infisical.config.SITE_URL="https://infisical.example.com"
```

## RBAC

Infisical uses role-based access control at both organization and project levels:

**Organization roles**:
- Owner, Admin, Member, No Access

**Project roles** (custom or built-in):
- Admin, Developer, Viewer, plus custom roles with granular permissions

**Custom role permissions** (project level):
```
Permissions:
  secrets: read, write, delete
  secret-folders: read, write, delete
  secret-imports: read, write, delete
  integrations: read, write, delete
  environments: read, write, delete
  members: read, write
  settings: read, write
  identity-memberships: read, write
  service-tokens: read, write
```

## SDK Integration (Node.js example)

```typescript
import { InfisicalClient } from "@infisical/sdk";

const client = new InfisicalClient({
  clientId: process.env.INFISICAL_CLIENT_ID,
  clientSecret: process.env.INFISICAL_CLIENT_SECRET,
});

// Get a single secret
const dbPassword = await client.getSecret({
  secretName: "DB_PASSWORD",
  projectId: "project-id",
  environment: "production",
});

// Get all secrets
const allSecrets = await client.listSecrets({
  projectId: "project-id",
  environment: "production",
});
```
