# cert-manager Issuer Configuration Examples: DNS-01 Providers and Vault PKI

### DNS-01 Solver Providers

```yaml
# AWS Route 53
solvers:
- dns01:
    route53:
      region: us-east-1
      hostedZoneID: Z123456789
      # Uses pod's IAM role (IRSA) if no credentials specified

# Azure DNS
solvers:
- dns01:
    azureDNS:
      subscriptionID: <subscription-id>
      resourceGroupName: my-dns-rg
      hostedZoneName: example.com
      managedIdentity:
        clientID: <user-assigned-identity-client-id>

# Google Cloud DNS
solvers:
- dns01:
    cloudDNS:
      project: my-gcp-project
      serviceAccountSecretRef:
        name: clouddns-dns01-solver-svc-acct
        key: key.json

# Cloudflare
solvers:
- dns01:
    cloudflare:
      email: admin@example.com
      apiTokenSecretRef:
        name: cloudflare-api-token-secret
        key: api-token
```

### Vault PKI Issuer

```yaml
# Issuer using Vault PKI engine with Kubernetes auth
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-issuer
spec:
  vault:
    server: https://vault.example.com
    path: pki_int/sign/my-service    # Vault role path
    caBundle: <base64-encoded-vault-ca>
    auth:
      kubernetes:
        role: cert-manager
        mountPath: /v1/auth/kubernetes
        secretRef:
          name: cert-manager-vault-token
          key: token
```

```bash
# Vault setup for cert-manager
vault write auth/kubernetes/role/cert-manager \
    bound_service_account_names=cert-manager \
    bound_service_account_namespaces=cert-manager \
    policies=pki-policy \
    ttl=20m

vault policy write pki-policy - <<EOF
path "pki_int/sign/*" {
  capabilities = ["create", "update"]
}

path "pki_int/issue/*" {
  capabilities = ["create"]
}
EOF
```
