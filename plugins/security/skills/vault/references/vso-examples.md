# Vault Secrets Operator (VSO) Full Manifests

Kubernetes Operator that syncs Vault secrets into Kubernetes Secrets and auto-rotates them.

```yaml
# VaultAuth — authenticate to Vault
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: default
  namespace: my-namespace
spec:
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: my-app
    serviceAccount: my-sa

---
# VaultStaticSecret — sync KV secret
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: my-app-secret
  namespace: my-namespace
spec:
  type: kv-v2
  mount: secret
  path: myapp/config
  destination:
    name: my-app-secret  # K8s Secret name
    create: true
  refreshAfter: 30s

---
# VaultDynamicSecret — sync dynamic credentials
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  name: db-creds
  namespace: my-namespace
spec:
  mount: database
  path: creds/app-role
  destination:
    name: db-credentials
    create: true
```
