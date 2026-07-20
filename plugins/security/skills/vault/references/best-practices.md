# HashiCorp Vault — Best Practices

Operational patterns for secret engines, auth method selection, policy design, audit compliance, dynamic secrets, Transit encryption, PKI, Vault Agent, and Kubernetes integration.

---

## Secret Engine Selection Guide

| Use Case | Engine | Why |
|---|---|---|
| Application config (static) | KV v2 | Versioned, soft-delete, metadata |
| Database credentials | database | Dynamic, auto-revoked, least privilege |
| Internal TLS/mTLS | pki | Full CA, short-lived certs, auto-renewal |
| Encryption service | transit | No key management in app code |
| AWS credentials | aws | Dynamic STS or IAM user, scoped policies |
| Azure credentials | azure | Dynamic service principals |
| GCP credentials | gcp | Dynamic service accounts |
| SSH access | ssh | Signed SSH certificates (OTP or CA mode) |
| TOTP tokens | totp | Second-factor generation |
| Active Directory | ad | Service account password rotation |

### KV v2 Best Practices

**Path structure**: Organize by `<environment>/<team>/<service>/<secret-type>`

```
secret/data/prod/platform/api-gateway/tls
secret/data/prod/platform/api-gateway/config
secret/data/staging/team-a/payments/db-creds
```

**Versioning**: Set `max_versions` to 10 or fewer to control storage growth:
```bash
vault kv metadata put -max-versions=10 secret/prod/myapp/config
```

**Secret metadata**: Use custom metadata to document secrets:
```bash
vault kv metadata put \
    -custom-metadata=owner="platform-team" \
    -custom-metadata=rotation-policy="30d" \
    -custom-metadata=last-rotated="2025-01-01" \
    secret/prod/myapp/config
```

**Check-and-set (CAS)**: Prevent accidental overwrites by requiring version match:
```bash
vault kv put -cas=3 secret/prod/myapp/config key=value
# Fails if current version is not 3
```

### Database Engine Best Practices

1. **Use least-privilege creation statements**: Only grant the permissions the application needs
2. **Set short default TTL**: 1-4 hours for most apps; longer for batch jobs
3. **Use static roles for legacy apps** that cannot handle rotating credentials:

```bash
vault write database/static-roles/legacy-app \
    db_name=my-postgres \
    username="legacy_app" \
    rotation_period=24h
```

4. **Connection management**: Set `max_open_connections` and `max_idle_connections` to avoid overwhelming the database
5. **Rotate root credentials**: Rotate the Vault admin credentials after configuration:
```bash
vault write -f database/rotate-root/my-postgres
```

### Transit Engine Best Practices

1. **Never export keys**: Keep `exportable=false` (default)
2. **Set minimum decryption version** to retire old key material:
```bash
vault write transit/keys/my-key/config min_decryption_version=3
```
3. **Use batch operations** for high-throughput encryption:
```bash
vault write transit/encrypt/my-key \
    batch_input='[{"plaintext":"dGVzdA=="},{"plaintext":"dGVzdDI="}]'
```
4. **Key type selection**:
   - `aes256-gcm96`: Default, symmetric, fastest, for data encryption
   - `rsa-4096`: Asymmetric, for key wrapping or external interop
   - `ed25519`: For signing/verification (not encryption)

5. **Convergent encryption**: If you need the same plaintext to produce the same ciphertext (for deduplication/lookup), use `convergent_encryption=true` with `derived=true`. Understand the trade-off: reveals if two plaintexts are equal.

---

## Auth Method Selection Guide

| Environment | Recommended Auth Method | Rationale |
|---|---|---|
| Kubernetes pods | kubernetes | Bound to SA + namespace; no secret management |
| AWS EC2/ECS/Lambda | aws (iam type) | Bound to IAM role; no long-lived creds |
| Azure VMs/AKS | azure | Bound to managed identity |
| GCP | gcp | Bound to service account |
| CI/CD (GitHub Actions) | jwt (OIDC) | Bound to repo/branch claims |
| CI/CD (Jenkins) | jwt or approle | JWT preferred for modern Jenkins |
| Human users (SSO) | oidc | SSO with Okta/Azure AD/Google |
| Human users (legacy) | ldap | Active Directory integration |
| No platform identity | approle | Last resort; manage SecretID delivery carefully |

### AppRole SecretID Security

SecretID is effectively a password. Protect it:
- Use `secret_id_ttl` to limit validity (10-60 minutes for bootstrap)
- Use `secret_id_num_uses=1` for one-time use (recommended)
- Wrap the SecretID in a Cubbyhole response wrapping token:

```bash
# Wrap SecretID in a one-time-use token
vault write -wrap-ttl=60s -f auth/approle/role/my-app/secret-id
# Returns: wrapping_token (deliver this, not the SecretID)

# App unwraps the token to get SecretID
VAULT_TOKEN=<wrapping_token> vault unwrap
```

### Kubernetes Auth Best Practices

1. **Bind to specific namespaces and service accounts**
2. **Use `token_bound_cidrs`** to restrict token use to pod IP ranges
3. **Configure token TTLs** to match your longest-running operations
4. **Enable `token_no_default_policy`** for strict policy management

```bash
vault write auth/kubernetes/role/my-app \
    bound_service_account_names=my-sa \
    bound_service_account_namespaces=production \
    token_policies="my-app-policy" \
    token_ttl=20m \
    token_max_ttl=30m \
    token_no_default_policy=true
```

---

## Policy Design Best Practices

### Principle of Least Privilege

Write policies that grant the minimum required access:

```hcl
# GOOD: specific path, specific capabilities
path "secret/data/prod/myapp/config" {
  capabilities = ["read"]
}

# BAD: wildcard with write
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

### Policy Naming Conventions

```
<environment>-<team>-<service>-<role>

prod-platform-api-gateway-read
staging-team-a-payments-admin
shared-database-app-creds
```

### Policy Structure Template

```hcl
# Description: Read-only access for myapp in production
# Owner: platform-team
# Last reviewed: 2025-01-01

# Application secrets
path "secret/data/prod/myapp/*" {
  capabilities = ["read"]
}

path "secret/metadata/prod/myapp/*" {
  capabilities = ["list"]
}

# Dynamic database credentials
path "database/creds/prod-myapp-role" {
  capabilities = ["read"]
}

# PKI certificate issuance
path "pki_int/issue/myapp" {
  capabilities = ["update"]
}

# Token self-management
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "sys/leases/renew" {
  capabilities = ["update"]
}
```

### Sentinel Policies (Enterprise)

Endpoint Governing Policies (EGP) and Role Governing Policies (RGP) provide fine-grained control beyond path matching:

```python
# Sentinel: enforce MFA for deletion
import "strings"

main = rule {
  request.operation is not "delete" or
  identity.entity.mfa_methods contains "totp"
}
```

---

## Vault PKI Engine — Production Deployment

### Certificate Authority Hierarchy

Never use Vault as a Root CA in production. Use Vault as an Intermediate CA:

```
Offline Root CA (air-gapped, HSM-backed)
  └── Vault Intermediate CA (online, Vault PKI engine)
        └── Leaf certificates (TLS, mTLS, SSH)
```

```bash
# 1. Enable intermediate CA in Vault
vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=43800h pki_int  # 5 years max

# 2. Generate CSR (Vault holds the private key)
vault write pki_int/intermediate/generate/internal \
    common_name="My Intermediate CA 2025" \
    key_type="rsa" \
    key_bits=4096 \
    -format=json | jq -r '.data.csr' > intermediate.csr

# 3. Sign with offline Root CA (offline step)
# openssl ca -config root-ca.conf -in intermediate.csr -out intermediate.crt

# 4. Import signed certificate
vault write pki_int/intermediate/set-signed certificate=@intermediate.crt

# 5. Configure CRL and OCSP URLs
vault write pki_int/config/urls \
    issuing_certificates="https://vault.example.com/v1/pki_int/ca" \
    crl_distribution_points="https://vault.example.com/v1/pki_int/crl" \
    ocsp_servers="https://vault.example.com/v1/pki_int/ocsp"
```

### PKI Roles for Different Certificate Types

```bash
# TLS server certificates (internal services)
vault write pki_int/roles/internal-tls \
    allowed_domains="internal.example.com,svc.cluster.local" \
    allow_subdomains=true \
    allow_bare_domains=false \
    max_ttl=720h \    # 30 days
    key_type=rsa \
    key_bits=2048 \
    server_flag=true \
    client_flag=false

# mTLS client certificates
vault write pki_int/roles/mtls-client \
    allowed_domains="clients.internal.example.com" \
    allow_subdomains=true \
    max_ttl=24h \     # Short-lived for mTLS
    server_flag=false \
    client_flag=true

# ACME provider (Vault 1.14+)
vault write pki_int/config/acme enabled=true
```

---

## Audit Device Configuration

### Required for Compliance

Enable at least two audit devices so Vault doesn't block if one fails (Vault requires all audit devices to succeed):

```bash
# Primary: file audit
vault audit enable file file_path=/vault/logs/audit.log log_raw=false

# Secondary: syslog to SIEM
vault audit enable -path=syslog syslog tag=vault

# If using only one device, use 'fallback' mode
vault audit enable -options=fallback=true file file_path=/vault/logs/audit.log
```

### Log Format

Audit logs are JSON. Key fields:

```json
{
  "time": "2025-01-01T00:00:00Z",
  "type": "request",
  "auth": {
    "client_token": "hmac-sha256:...",
    "accessor": "hmac-sha256:...",
    "policies": ["my-app-policy"],
    "entity_id": "entity-id",
    "display_name": "kubernetes-production-my-sa"
  },
  "request": {
    "id": "req-id",
    "operation": "read",
    "path": "secret/data/prod/myapp/config",
    "remote_address": "10.0.0.1"
  },
  "response": {
    "data": {
      "metadata": { "version": 1 }
      // Secret data values are HMAC-hashed
    }
  }
}
```

### Audit Log Monitoring Alerts

Alert on:
- `auth.policies` containing `root` — root token usage
- High rate of denied requests (403) from a single entity
- Access to `sys/` paths (administrative operations)
- Token creation with TTL > 24h
- Deletion operations on production secret paths

---

## Vault Agent — Production Patterns

### Kubernetes Sidecar Pattern

```yaml
# pod spec with Vault Agent sidecar
initContainers:
- name: vault-agent-init
  image: hashicorp/vault:1.17
  args: ["agent", "-config=/vault/config/vault-agent.hcl", "-exit-after-auth"]
  volumeMounts:
  - name: vault-config
    mountPath: /vault/config
  - name: vault-secrets
    mountPath: /vault/secrets

containers:
- name: app
  image: myapp:latest
  volumeMounts:
  - name: vault-secrets
    mountPath: /vault/secrets
    readOnly: true

- name: vault-agent
  image: hashicorp/vault:1.17
  args: ["agent", "-config=/vault/config/vault-agent.hcl"]
  volumeMounts:
  - name: vault-config
    mountPath: /vault/config
  - name: vault-secrets
    mountPath: /vault/secrets
```

### Vault Secrets Operator vs. Vault Agent

| Feature | VSO | Vault Agent |
|---|---|---|
| Paradigm | Kubernetes-native (CRDs) | Sidecar/daemon |
| Secret delivery | K8s Secrets | Files or env vars |
| Rotation | Automatic (watch + sync) | Automatic (template + command) |
| Application changes needed | No (mount K8s Secret) | No (read file) |
| Dynamic secrets | Yes (VaultDynamicSecret) | Yes (lease renewal) |
| Complexity | Lower (operator manages it) | Higher (config per pod) |
| Recommendation | Prefer for new K8s deployments | Use for non-K8s or complex templating |

### VSO with ArgoCD

VSO is GitOps-compatible: define VaultStaticSecret/VaultDynamicSecret resources in git. VSO handles the actual secret fetch at runtime. No secret values in git.

---

## High Availability — Network Requirements

```
Vault nodes (Raft cluster):
  Port 8200: API + UI (HTTPS)
  Port 8201: Cluster replication (internal, TLS)
  Port 8300: Raft RPC (internal)
```

Load balancer should:
- Forward to active node only (check `/v1/sys/health?standbyok=false`)
- Or forward to any node (standby redirects to active with 307)

Health endpoint responses:
- `200`: Active node
- `429`: Standby (read-only)
- `472`: DR secondary
- `473`: Performance standby
- `501`: Not initialized
- `503`: Sealed

---

## Common Misconfigurations

| Misconfiguration | Risk | Fix |
|---|---|---|
| No audit devices | Compliance failure, breach undetected | Enable file + syslog audit |
| Root token in use | Root token compromise = full cluster access | Create admin tokens, revoke root |
| Shamir keys with one holder | No redundancy | Distribute key shares to multiple custodians |
| No auto-unseal | Manual unseal after restart | Configure cloud KMS auto-unseal |
| KV v1 instead of v2 | No versioning, no metadata, no CAS | Migrate to KV v2 |
| `path "*" { capabilities = ["sudo"] }` | Unrestricted access | Write least-privilege policies |
| Vault server -dev in production | Unsealed, in-memory, no persistence | Use production config |
| No TTL on tokens | Tokens never expire | Always set TTL and max_ttl |
| Storing Vault token in env var | Token in process list / logs | Use Vault Agent file sink |
