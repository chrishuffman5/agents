# Flux CD Diagnostics

## Reconciliation Failures

### Kustomization Not Ready

```
✗ kustomization myapp not ready: kustomize build failed
```

**Diagnosis:**
```bash
# Check Kustomization status
flux get kustomization myapp

# Detailed events
flux events --for Kustomization/myapp

# Controller logs
flux logs --kind=Kustomization --name=myapp
```

**Common causes:**
1. **Invalid YAML/Kustomize**: Syntax errors, missing resources, invalid patches
2. **Source not ready**: GitRepository failed to clone
3. **Dependency not ready**: `dependsOn` resource still reconciling
4. **RBAC**: Service account lacks permissions to create resources
5. **Variable substitution**: Missing variables in `postBuild.substitute`

**Resolution:**
```bash
# Test kustomize build locally
kustomize build ./overlays/production

# Check source artifact
flux get sources git app-config

# Force reconciliation
flux reconcile kustomization myapp --with-source
```

### HelmRelease Not Ready

```
✗ helmrelease nginx not ready: Helm upgrade failed: ...
```

**Diagnosis:**
```bash
# Check HelmRelease status
flux get helmrelease nginx -n ingress-system

# Check Helm release history
flux logs --kind=HelmRelease --name=nginx --namespace=ingress-system

# Check underlying Helm release
helm history nginx -n ingress-system
```

**Common causes:**
1. **Chart not found**: Wrong chart name, version, or repository
2. **Values error**: Invalid values, schema validation failure
3. **Timeout**: Chart install/upgrade takes too long
4. **CRD conflict**: Chart creates CRDs that already exist
5. **Resource conflict**: Resources already managed by another release

**Resolution:**
```bash
# Test Helm chart locally
helm template nginx ingress-nginx/ingress-nginx -f values.yaml

# Suspend, fix, resume
flux suspend helmrelease nginx
# Fix the issue
flux resume helmrelease nginx
flux reconcile helmrelease nginx
```

### Remediation and Rollback

```yaml
# HelmRelease with remediation
spec:
  upgrade:
    remediation:
      retries: 3                    # Retry upgrade 3 times
      remediateLastFailure: true    # Rollback after last retry fails
  rollback:
    cleanupOnFail: true             # Clean up failed resources on rollback
```

Check remediation status:
```bash
flux get helmrelease nginx --watch
# Look for "upgrade remediation exhausted" or "rollback succeeded"
```

## Source Failures

### GitRepository Not Ready

```
✗ gitrepository app-config not ready: failed to checkout: authentication required
```

**Diagnosis:**
```bash
flux get sources git app-config
kubectl describe gitrepository app-config -n flux-system
```

**Common causes and fixes:**

| Error | Cause | Fix |
|---|---|---|
| `authentication required` | Missing/invalid credentials | Check secret: `kubectl get secret git-credentials -n flux-system -o yaml` |
| `host key verification failed` | SSH host key not trusted | Add known_hosts to secret |
| `couldn't find remote ref` | Branch doesn't exist | Check `spec.ref.branch` |
| `unable to clone` | Network issue | Check DNS, firewall, proxy |

**Re-create credentials:**
```bash
flux create secret git git-credentials \
  --url=ssh://git@github.com/org/repo \
  --private-key-file=./id_ed25519
```

### HelmRepository Not Ready

```
✗ helmrepository ingress-nginx not ready: failed to fetch index: 403 Forbidden
```

**Resolution:**
1. Check repository URL is correct
2. For private repos, add credentials:
   ```bash
   flux create secret helm repo-credentials \
     --username=admin \
     --password=${TOKEN}
   ```
3. For OCI repos, check authentication and repository type

## Image Automation Issues

### ImageRepository Scan Failing

```
✗ imagerepository myapp not ready: failed to list tags: denied
```

**Resolution:**
1. Check registry credentials:
   ```bash
   kubectl create secret docker-registry regcred \
     --docker-server=ghcr.io \
     --docker-username=flux \
     --docker-password=${GHCR_TOKEN} \
     -n flux-system
   ```
2. Reference in ImageRepository:
   ```yaml
   spec:
     secretRef:
       name: regcred
   ```

### ImagePolicy Not Resolving

**Diagnosis:**
```bash
flux get image policy myapp
# Check if latest image matches policy
```

**Common issues:**
- Semver filter too restrictive
- No tags in registry match the policy
- Image repository not scanning successfully

### ImageUpdateAutomation Not Committing

**Diagnosis:**
```bash
flux get image update flux-system
flux logs --kind=ImageUpdateAutomation
```

**Common issues:**
- No image policy markers in YAML files (`{"$imagepolicy": "..."}`)
- Git push authentication failure
- Branch protection rules blocking pushes
- No changes detected (image already up to date)

## General Debugging

### Check All Flux Resources

```bash
# Overview of all Flux resources
flux get all

# Detailed status with conditions
flux get all --status-selector ready=false

# Events across all resources
flux events

# Controller logs (all controllers)
flux logs --all-namespaces

# Specific controller logs
flux logs --kind=Kustomization
flux logs --kind=HelmRelease
flux logs --kind=GitRepository
```

### Suspend and Resume

When debugging, suspend reconciliation to prevent interference:

```bash
# Suspend to prevent reconciliation during debugging
flux suspend kustomization myapp

# Make manual changes, test, debug

# Resume when ready
flux resume kustomization myapp
```

### Force Reconciliation

```bash
# Reconcile source and downstream
flux reconcile source git app-config
flux reconcile kustomization myapp --with-source

# Reconcile HelmRelease
flux reconcile helmrelease nginx --with-source
```

### Verify Flux Installation

```bash
# Full health check
flux check

# Expected output:
# ✔ source-controller: deployment ready
# ✔ kustomize-controller: deployment ready
# ✔ helm-controller: deployment ready
# ✔ notification-controller: deployment ready

# Check controller versions
flux version
```

### Export for Backup/Recovery

```bash
# Export all Flux resources (can be re-applied)
flux export source git --all > sources.yaml
flux export kustomization --all > kustomizations.yaml
flux export helmrelease --all --all-namespaces > helmreleases.yaml
flux export image repository --all > imagerepositories.yaml
flux export image policy --all > imagepolicies.yaml
```

### Uninstall and Reinstall

```bash
# If Flux is in a bad state, uninstall and re-bootstrap
flux uninstall --namespace=flux-system

# Re-bootstrap (will re-read config from Git)
flux bootstrap github \
  --owner=my-org \
  --repository=fleet-config \
  --path=clusters/production
```
