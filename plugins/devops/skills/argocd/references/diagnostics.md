# ArgoCD Diagnostics

## Sync Failures

### OutOfSync but Won't Sync

**Diagnosis:**
1. Check sync status: `argocd app get myapp`
2. Check diff: `argocd app diff myapp`
3. Check sync operation result: `argocd app get myapp --show-operation`

**Common causes:**
- Resource validation errors (invalid YAML, missing required fields)
- RBAC restrictions (ArgoCD service account lacks permissions)
- Resource already managed by another Application
- Finalizer blocking deletion

### Sync Error: ComparisonError

```
ComparisonError: failed to load live state: the server could not find the requested resource
```

**Cause**: CRD not installed in the cluster.

**Resolution:**
1. Ensure CRDs are installed before resources that use them
2. Use sync waves: CRDs at wave `-1`, custom resources at wave `0`

```yaml
# Install CRD first
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
```

### Sync Error: Pruning

```
one or more objects failed to apply, reason: Resource "myapp" already exists and is not managed by ArgoCD
```

**Resolution:**
- Add the ArgoCD tracking label: `argocd.argoproj.io/managed-by: argocd`
- Or use `argocd app sync myapp --force` (use cautiously)

### Helm Rendering Failures

```
rpc error: helm template failed: exit status 1: Error: template: ...
```

**Diagnosis:**
1. Check Helm values: `argocd app get myapp --show-params`
2. Test locally: `helm template myapp chart/ -f values.yaml`
3. Check repo server logs: `kubectl logs -n argocd deploy/argocd-repo-server`

## Health Issues

### Application Stuck at Progressing

**Diagnosis:**
```bash
# Check resource health
argocd app get myapp --output tree

# Check specific resources
kubectl describe deployment myapp -n myapp-ns
kubectl get events -n myapp-ns --sort-by=.lastTimestamp
```

**Common causes:**
- Deployment waiting for pods to be ready (image pull, readiness probe failure)
- PVC pending (no matching StorageClass, insufficient capacity)
- Service account or RBAC not configured
- Resource quota exceeded

### Degraded Health

```bash
# Identify degraded resources
argocd app get myapp --output tree | grep -i degraded

# Check pod status
kubectl get pods -n myapp-ns
kubectl describe pod <pod-name> -n myapp-ns
kubectl logs <pod-name> -n myapp-ns
```

### Custom Health Checks

For CRDs that ArgoCD doesn't know how to health-check:

```yaml
# argocd-cm ConfigMap
data:
  resource.customizations.health.mycrd.example.com_MyResource: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.phase == "Running" then
        hs.status = "Healthy"
        hs.message = "Running"
      elseif obj.status.phase == "Failed" then
        hs.status = "Degraded"
        hs.message = obj.status.message
      else
        hs.status = "Progressing"
        hs.message = "Waiting"
      end
    end
    return hs
```

## Connectivity Issues

### Cannot Connect to Cluster

```
rpc error: dial tcp: connect: connection refused
```

**Diagnosis:**
1. Check cluster credentials: `argocd cluster list`
2. Check network connectivity from ArgoCD to cluster API server
3. Check if cluster credentials have expired (bearer token, client cert)

**Resolution:**
```bash
# Re-add cluster
argocd cluster rm production
argocd cluster add production-context --name production

# Check cluster status
argocd cluster get production
```

### Repository Connection Failures

```
rpc error: repository not accessible: authentication required
```

**Resolution:**
```bash
# Check repository config
argocd repo list

# Re-add repository
argocd repo rm https://github.com/org/repo.git
argocd repo add https://github.com/org/repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# For HTTPS with token
argocd repo add https://github.com/org/repo.git \
  --username git \
  --password <token>
```

## Performance Issues

### Slow Reconciliation

**Diagnosis:**
```bash
# Check controller metrics
kubectl port-forward -n argocd svc/argocd-metrics 8082:8082
curl localhost:8082/metrics | grep argocd_app_reconcile

# Check repo server cache hit rate
curl localhost:8082/metrics | grep argocd_git_request_total
```

**Resolution:**
1. Enable Git webhooks (reduces polling)
2. Increase repo server replicas
3. Use shallow clones for large repos
4. Reduce reconciliation frequency for stable apps
5. Shard the Application Controller

### High Memory Usage

```bash
# Check component memory
kubectl top pods -n argocd

# Common causes:
# - Repo server caching too many manifests
# - Application controller watching too many resources
# - Redis cache growing unbounded
```

**Resolution:**
- Increase memory limits
- Configure Redis eviction policies
- Use ApplicationSet instead of many individual Applications
- Shard the controller for 100+ applications

## Debugging Commands

```bash
# Application debugging
argocd app get myapp                    # Full application status
argocd app get myapp --output tree      # Resource tree with health
argocd app diff myapp                   # Show diff between Git and live
argocd app diff myapp --local ./path    # Diff against local files
argocd app manifests myapp              # Show generated manifests
argocd app history myapp                # Deployment history

# Manual sync with options
argocd app sync myapp --dry-run         # Preview only
argocd app sync myapp --force           # Force sync (replace resources)
argocd app sync myapp --prune           # Include pruning
argocd app sync myapp --resource apps:Deployment:myapp  # Sync specific resource

# Logs
kubectl logs -n argocd deploy/argocd-server
kubectl logs -n argocd deploy/argocd-repo-server
kubectl logs -n argocd deploy/argocd-application-controller
kubectl logs -n argocd deploy/argocd-applicationset-controller

# Admin tools
argocd admin settings validate --argocd-cm-path argocd-cm.yaml
argocd admin proj generate-spec myproject
```
