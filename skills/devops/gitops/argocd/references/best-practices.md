# ArgoCD Best Practices

## Application Design

### Use ApplicationSet for Scale

```yaml
# Instead of manually creating 50 Applications:
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: all-apps
spec:
  generators:
    - git:
        repoURL: https://github.com/org/config-repo.git
        revision: main
        directories:
          - path: apps/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/config-repo.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Sync Policy Recommendations

```yaml
syncPolicy:
  automated:
    prune: true           # Always enable — keeps cluster clean
    selfHeal: true        # Enable for production — reverts kubectl edits
    allowEmpty: false     # Safety net — don't wipe everything on empty source
  syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground   # Wait for dependent resources
    - PruneLast=true                       # Prune after new resources are healthy
    - ServerSideApply=true                 # Better for large resources, CRDs
    - RespectIgnoreDifferences=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

### Ignore Differences

For fields that are legitimately different between Git and live state:

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas    # HPA manages replicas, not Git
    - group: ""
      kind: Service
      jqPathExpressions:
        - .spec.clusterIP   # Assigned by K8s, not declared in Git
```

## RBAC Configuration

### Project Isolation

```yaml
# Team-scoped project
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-api
spec:
  sourceRepos:
    - 'https://github.com/org/api-*'
  destinations:
    - namespace: 'api-*'
      server: https://kubernetes.default.svc
    - namespace: 'api-*'
      server: https://staging.example.com
  clusterResourceWhitelist: []    # No cluster-scoped resources
  roles:
    - name: developer
      policies:
        - p, proj:team-api:developer, applications, get, team-api/*, allow
        - p, proj:team-api:developer, applications, sync, team-api/*, allow
        - p, proj:team-api:developer, applications, override, team-api/*, deny
      groups: [api-developers]
    - name: admin
      policies:
        - p, proj:team-api:admin, applications, *, team-api/*, allow
      groups: [api-admins]
```

### RBAC Policy Format

```
p, <role>, <resource>, <action>, <object>, <allow/deny>

# Resources: applications, clusters, repositories, projects, logs, exec
# Actions: get, create, update, delete, sync, override, action
```

## SSO Integration

```yaml
# argocd-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
data:
  url: https://argocd.example.com
  oidc.config: |
    name: Okta
    issuer: https://example.okta.com
    clientID: xxxxxxxx
    clientSecret: $oidc.okta.clientSecret    # Reference to argocd-secret
    requestedScopes: ["openid", "profile", "email", "groups"]
```

## Performance Tuning

### Repo Server

```yaml
# Increase repo server resources for large repos
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-repo-server
spec:
  replicas: 3    # Scale horizontally
  template:
    spec:
      containers:
        - name: argocd-repo-server
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 2
              memory: 2Gi
          env:
            - name: ARGOCD_EXEC_TIMEOUT
              value: "3m"    # Increase for complex Helm charts
```

### Webhook Configuration

Use Git webhooks instead of polling for faster sync:

```yaml
# argocd-cm ConfigMap
data:
  # Configure webhook secret
  webhook.github.secret: $webhook.github.secret    # Reference to argocd-secret
```

This triggers immediate reconciliation on push instead of waiting for the 3-minute poll interval.

### Application Controller Tuning

```yaml
env:
  - name: ARGOCD_RECONCILIATION_TIMEOUT
    value: "180s"
  - name: ARGOCD_HARD_RECONCILIATION_TIMEOUT
    value: "0s"    # Disable hard reconciliation (expensive)
  - name: ARGOCD_RECONCILIATION_JITTER
    value: "30s"   # Spread reconciliation load
```

## Multi-Cluster Best Practices

1. **Dedicated ArgoCD per environment tier** — Dev ArgoCD manages dev clusters, prod ArgoCD manages prod clusters
2. **Or hub-and-spoke** — Single ArgoCD with project RBAC isolation per team/cluster
3. **NetworkPolicy** — Restrict ArgoCD API server access, especially cluster credential secrets
4. **Cluster credential rotation** — Use short-lived tokens or OIDC federation

## Common Mistakes

1. **Not enabling `prune: true`** — Without pruning, deleted resources linger in the cluster forever
2. **Not using Projects** — Default project allows deploying to any namespace/cluster. Create team-specific projects.
3. **Storing secrets in Application source** — Use SealedSecrets or External Secrets Operator
4. **Ignoring sync waves for stateful apps** — Databases, migrations, and config must sync before the app
5. **Too many sync retries** — Retrying a fundamentally broken sync wastes resources. Set reasonable limits.
6. **Helm `install` instead of ArgoCD** — ArgoCD uses `helm template` + `kubectl apply`, not `helm install`. Don't mix both.
