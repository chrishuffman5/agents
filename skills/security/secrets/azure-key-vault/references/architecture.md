# Azure Key Vault — Architecture Internals

Deep reference covering Key Vault tiers, Managed HSM, soft-delete/purge mechanics, RBAC vs. access policies internals, networking, BYOK patterns, and geo-redundancy.

---

## Vault Tiers

### Standard Tier

- Keys protected by software (FIPS 140-2 Level 1)
- Suitable for most development and non-regulated workloads
- RSA 2048/3072/4096, EC P-256/P-384/P-521/K-256
- No oct (symmetric) key type
- SLA: 99.99% availability

### Premium Tier

- Keys optionally protected by shared HSM (FIPS 140-3 Level 3)
- Add `-HSM` suffix to key type to request HSM protection: `RSA-HSM`, `EC-HSM`
- oct-HSM (AES symmetric keys) available only in Premium
- Suitable for PCI-DSS, HIPAA workloads requiring HSM-backed keys
- Same SLA as Standard (99.99%)
- Higher cost: ~4x per key operation vs. Standard

### Azure Managed HSM

Dedicated single-tenant HSM pool:
- FIPS 140-3 Level 3 certified
- Keys never leave the HSM in plaintext
- Full administrative control: you manage the security domain
- Required for highest compliance tiers: FedRAMP High, some financial regulations
- Multi-region: create one HSM per region, use Managed HSM Pool for HA
- HSM pool: 3 HSM instances (2 needed for quorum operations)

**Security domain**: When provisioning a Managed HSM, a security domain is downloaded — a JSON file encrypted with your administrator keys that contains the key material necessary to recover the HSM. Store this securely offline.

```bash
# Provision Managed HSM
az keyvault create \
    --hsm-name MyManagedHSM \
    --resource-group my-rg \
    --location eastus \
    --administrators $(az ad signed-in-user show --query objectId -o tsv) \
    --sku Standard_B1

# Download security domain (one-time, requires quorum of signers)
az keyvault security-domain download \
    --hsm-name MyManagedHSM \
    --sd-wrapping-keys cert1.pem cert2.pem cert3.pem \
    --sd-quorum 2 \
    --security-domain-file security-domain.json
```

---

## Soft-Delete Internals

### Lifecycle States

```
Active Object
  │
  │ (delete operation)
  ▼
Soft-Deleted (retention period: 7-90 days)
  │              │
  │ (recover)    │ (purge, if purge protection OFF)
  ▼              ▼
Active         Permanently Deleted
```

### Storage Behavior

When an object is soft-deleted:
- Its name is reserved — you cannot create a new object with the same name
- It is moved to a "deleted" container, still encrypted and stored
- The deleted object is accessible via the `-deleted` variants of the CLI commands
- After retention period expires: automatically purged (permanently deleted)

### Vault-Level Soft-Delete

If a Key Vault itself is deleted:
- It enters a soft-deleted state for 90 days (fixed, regardless of secret retention)
- The vault name is reserved globally — no other subscription can create a vault with the same name in the same region
- Recover: `az keyvault recover --name MyVault`
- After recovery, all secrets/keys/certs that were in the vault are restored

**Name collision**: This is a common operational issue. If a CI pipeline creates and deletes vaults with the same name, the next create will fail because the name is reserved in soft-delete. Either recover or purge first.

```bash
# List soft-deleted vaults
az keyvault list-deleted

# Recover soft-deleted vault
az keyvault recover --name MyVault

# Purge soft-deleted vault (permanently destroys all contents)
az keyvault purge --name MyVault
```

---

## RBAC vs. Access Policies — Internals

### Access Policy Model (Legacy)

Access policies are stored directly on the Key Vault resource in Azure Resource Manager. Each policy entry is a tuple of:
- Object ID (user, group, service principal, managed identity)
- Permissions for keys (list of operations)
- Permissions for secrets (list of operations)
- Permissions for certificates (list of operations)

**Limits**: Maximum 1024 access policy entries per vault. Exceeded in large organizations.

**No inheritance**: Access policies do not inherit from RBAC or management group policies. If a user has Contributor role on the subscription, they still cannot access secret values without an explicit access policy or RBAC role.

**Management vs. data plane split**: Azure RBAC controls the management plane (create/delete vault, view configuration). Access policies (or RBAC) control the data plane (read/write secrets).

### RBAC Data Plane Model

When `--enable-rbac-authorization` is set to `true`:
- Access policies are completely ignored
- Azure RBAC roles control all data plane access
- Roles assigned at vault scope, resource group scope, or subscription scope
- Supports conditional access (based on tags, resource names, etc.)

**Data plane RBAC roles** are a separate set from management plane roles. A user with `Contributor` on the resource group can manage the vault configuration but cannot read secret values unless also assigned a data plane role.

**Scoping behavior**:
```
Subscription: Key Vault Secrets User → access to ALL vaults in subscription
  Resource Group: Key Vault Secrets User → access to ALL vaults in RG
    Vault: Key Vault Secrets User → access to THIS vault only
      (No per-secret RBAC — vault is the minimum scope)
```

---

## BYOK (Bring Your Own Key)

Import your own key material into Key Vault or Managed HSM under HSM protection.

### Standard Import (Wrapped Key)

```
1. Generate target key in Key Vault / MHSM → get wrapping key (exchange key)
2. Locally generate your key in HSM / nCipher / Luna
3. Wrap your key with the exchange key using RSA-AES key wrapping
4. Upload the wrapped key to Key Vault
5. Key Vault / HSM unwraps and imports — your key never travels in plaintext
```

```bash
# Generate wrapping key in Key Vault
az keyvault key create --vault-name MyVaultPremium --name kek --kty RSA-HSM \
    --ops import --size 4096

# Get wrapping public key
az keyvault key download --vault-name MyVaultPremium --name kek --file kek.pem

# (External: wrap your key with kek.pem using BYOK tool)

# Import wrapped key
az keyvault key import --vault-name MyVaultPremium --name my-byok-key \
    --byok-file wrapped-key.byok
```

### Managed HSM Security Domain Transfer

For Managed HSM, the security domain enables transfer of keys between HSM instances (e.g., for DR or migration):

1. Export key with `az keyvault key export` (wraps key in security domain)
2. Import into target HSM with `az keyvault key import`

---

## Geo-Redundancy and Availability

### Automatic Replication

Key Vault content is **automatically replicated**:
- Within the primary region (paired zones within the same Azure region)
- To the paired region (read-only replica during normal operation)

The replica is used automatically if the primary region becomes unavailable. Failover is transparent to clients (same endpoint URL).

**Failover behavior**:
- During regional failover, Key Vault enters **read-only mode** for a period
- Write operations (create/update/delete) may fail during this window
- Read operations (get secret, decrypt, verify) continue to work
- Applications must handle write failures gracefully during failover

### Cross-Region Access Pattern

For latency-sensitive workloads requiring writes in multiple regions, create a vault in each region and use your application-layer logic to write to the appropriate vault:

```
Region A: vault-prod-eastus.vault.azure.net
Region B: vault-prod-westus.vault.azure.net
```

Use Azure Traffic Manager or Application Gateway with region affinity to route requests.

---

## Key Rotation

### Manual Rotation

```bash
# Create new key version (new rotation)
az keyvault key rotate --vault-name MyVault --name my-key

# List all versions
az keyvault key list-versions --vault-name MyVault --name my-key
```

### Automated Rotation Policy

Set an automatic rotation schedule (Portal or via REST/ARM):

```bash
# Set rotation policy (rotate 30 days before expiry)
az keyvault key rotation-policy update \
    --vault-name MyVault \
    --name my-key \
    --value '{
      "lifetimeActions": [
        {
          "trigger": {"timeBeforeExpiry": "P30D"},
          "action": {"type": "Rotate"}
        },
        {
          "trigger": {"timeBeforeExpiry": "P7D"},
          "action": {"type": "Notify"}
        }
      ],
      "attributes": {
        "expiryTime": "P1Y"
      }
    }'
```

### Key Rotation for Disk Encryption

Azure Disk Encryption (ADE) and Server-Side Encryption (SSE) with customer-managed keys (CMK):
- Key rotation does NOT require re-encrypting disk data
- Envelope encryption: DEK is re-wrapped with new key version
- New VM reads/writes use new key version for DEK unwrapping
- Old key versions must be retained until all encrypted snapshots using that version are deleted

---

## Network Architecture

### Private Endpoint DNS Resolution

When using private endpoints, Key Vault DNS must resolve to the private IP:

```
vault.azure.net → Private DNS Zone: privatelink.vaultcore.azure.net
MyVault.vault.azure.net → A record: 10.0.1.5 (private endpoint IP)
```

For on-premises or hybrid access:
- Use DNS forwarder (Azure Private Resolver or custom DNS)
- Forward `privatelink.vaultcore.azure.net` queries to Azure DNS (168.63.129.16)

### Service Endpoints vs. Private Endpoints

| Feature | Service Endpoints | Private Endpoints |
|---|---|---|
| Traffic path | Through public internet backbone | Through private IP, no public internet |
| DNS | Public FQDN | Private DNS zone |
| Cost | No extra charge | PE + DNS zone charges |
| Exfiltration protection | No | Yes (traffic stays on private network) |
| Recommendation | Legacy; use private endpoints | Recommended for production |

---

## Throttling and Limits

Key Vault enforces per-region, per-subscription, per-vault limits:

| Operation Type | Vault Limit | Notes |
|---|---|---|
| Key operations | 2,000 / 10 sec | Per vault |
| Secret operations | 4,000 / 10 sec | Per vault |
| Certificate operations | 200 / 10 sec | Per vault |
| Vault transactions | 20,000 / 10 sec | Across all types |

**429 Too Many Requests**: Implement exponential backoff with jitter. SDK clients (Azure SDK) handle retry automatically with configurable policy.

**Strategies to avoid throttling**:
- Cache secrets locally (in-memory) with reasonable TTL
- Batch certificate operations
- Use Key Vault References for App Service (reduces per-request API calls)
- Multiple vaults for high-throughput workloads

---

## SLA and Compliance

| Tier | Availability SLA | FIPS Level |
|---|---|---|
| Standard | 99.99% | FIPS 140-2 Level 1 |
| Premium | 99.99% | FIPS 140-3 Level 3 (HSM-backed keys) |
| Managed HSM | 99.9% | FIPS 140-3 Level 3 (all keys) |

Compliance certifications: PCI DSS, HIPAA, FedRAMP, ISO 27001, SOC 1/2, HITRUST. Check Azure compliance documentation for current certifications — the set expands regularly.
