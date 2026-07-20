# Kubernetes Best Practices Reference

Production-grade guidance for resource management, security, autoscaling, and operations.

---

## Resource Management

### Setting Requests and Limits

**Memory**:
- Always set both requests and limits
- Set limits equal to or slightly above requests for predictable behavior
- Exceeding memory limits causes OOMKill (exit code 137)
- Profile actual usage with `kubectl top pod` or VPA recommendations before setting values

**CPU**:
- Always set requests (scheduler uses these for placement)
- Be cautious with CPU limits -- they cause CFS throttling even when the node has free CPU
- Many teams set CPU requests but omit CPU limits (Burstable QoS) to avoid throttling
- If using CPU limits, set them to 2-5x the request to allow burst headroom

**QoS class strategy**:
- **Guaranteed** (requests == limits): use for critical workloads (databases, payment processing) that must not be evicted
- **Burstable** (requests < limits or partial): use for most application workloads
- **BestEffort** (no requests/limits): avoid in production -- first evicted under pressure

```yaml
# Recommended pattern: memory limits, CPU requests only
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    memory: "512Mi"
    # cpu limit intentionally omitted to prevent throttling
```

### LimitRanges

Apply per-namespace to set defaults and enforce boundaries:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: defaults
  namespace: production
spec:
  limits:
  - type: Container
    default:
      cpu: "200m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "4"
      memory: "8Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
```

### ResourceQuotas

Prevent namespace resource exhaustion:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-alpha
spec:
  hard:
    pods: "50"
    requests.cpu: "20"
    requests.memory: "40Gi"
    limits.memory: "80Gi"
    persistentvolumeclaims: "20"
    requests.storage: "200Gi"
```

Set quotas on every non-system namespace. Without quotas, a single team can consume all cluster resources.

---

## Security Best Practices

### Pod Security Standards

Apply Restricted PSS to all production namespaces:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Adoption strategy**: start with `warn` and `audit` modes to identify non-compliant workloads before switching to `enforce`.

### Pod Security Context

Every production pod should have:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault
containers:
- name: app
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop: ["ALL"]
```

If the application needs to write temporary files, mount an `emptyDir` at the write path instead of allowing a writable root filesystem.

### RBAC Design

**Principles**:
1. Least privilege: grant only the verbs and resources needed
2. Namespace-scoped roles over cluster-scoped when possible
3. Bind to Groups (from IdP) rather than individual Users
4. Use separate ServiceAccounts per workload (not the default SA)
5. Never bind `cluster-admin` to application ServiceAccounts

**Common role patterns**:

```yaml
# Read-only access for developers
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-readonly
  namespace: staging
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["pods", "pods/log", "deployments", "services", "configmaps", "jobs"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]   # allow exec for debugging

# CI/CD deployer
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployer
  namespace: production
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "patch", "update"]
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch"]
```

### ServiceAccount Tokens

- Disable token auto-mounting when not needed: `automountServiceAccountToken: false`
- Use projected volume tokens with audience and expiration for workloads that need API access
- Audit: `kubectl get secrets -A -o json | jq '.items[] | select(.type=="kubernetes.io/service-account-token") | .metadata.name'` to find legacy non-expiring tokens

### Network Security

**Default deny policy** (apply to every namespace):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

Then add specific allow rules for each service's required traffic. Always:
- Block access to cloud metadata endpoints (169.254.169.254)
- Restrict egress to only required destinations
- Allow DNS egress (port 53 to kube-system/kube-dns) explicitly when using default-deny

```yaml
# Allow DNS for all pods in namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

### Secrets Management

- Kubernetes Secrets are base64-encoded, not encrypted at rest by default
- Enable encryption at rest: `--encryption-provider-config` on API server (AES-CBC or AES-GCM)
- Better: use external secrets management (Vault, AWS Secrets Manager, Azure Key Vault) via:
  - External Secrets Operator (syncs external secrets to K8s Secrets)
  - Secrets Store CSI Driver (mounts secrets as volumes)
- Never commit Secrets in YAML to Git. Use Sealed Secrets or SOPS-encrypted values.

---

## Autoscaling Best Practices

### HPA Configuration

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2             # never scale to 0 (use KEDA for scale-to-zero)
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60    # target 60% to leave headroom
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300   # wait 5 min before scaling down
      policies:
      - type: Percent
        value: 25                        # max 25% reduction per period
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0     # scale up immediately
      policies:
      - type: Percent
        value: 100                       # can double replicas per period
        periodSeconds: 15
```

**HPA tips**:
- Target utilization of 50-70% (not 80-90%) to handle traffic spikes during scale-up lag
- Use `behavior` to prevent flapping (scale-down too fast)
- Metrics Server must be installed for resource metrics
- For custom metrics (requests/sec, queue depth), use Prometheus Adapter or KEDA

### VPA Configuration

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  updatePolicy:
    updateMode: "Off"          # start with Off to get recommendations
  resourcePolicy:
    containerPolicies:
    - containerName: app
      minAllowed:
        cpu: "50m"
        memory: "64Mi"
      maxAllowed:
        cpu: "4"
        memory: "8Gi"
```

**VPA tips**:
- Start in `Off` mode to collect recommendations before enabling `Auto`
- VPA evicts pods to resize them (until in-place resize is GA)
- Never use VPA and HPA on the same CPU/memory metric
- Common pattern: HPA on custom metric (RPS) + VPA for right-sizing resources

### PodDisruptionBudgets

Every production Deployment should have a PDB:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp
spec:
  minAvailable: "50%"       # or maxUnavailable: 1
  selector:
    matchLabels:
      app: myapp
```

**PDB tips**:
- `minAvailable: 1` prevents draining the last pod during node maintenance
- Use percentage for scaling workloads, absolute numbers for fixed-size services
- PDBs only protect against voluntary disruptions (drain, upgrade). They do not prevent OOMKill or node failure.

---

## Deployment Strategies

### Rolling Update (default)

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0       # zero-downtime: never remove old pods before new are ready
    maxSurge: "25%"         # create up to 25% extra pods during rollout
```

Setting `maxUnavailable: 0` with `maxSurge: 1` (or 25%) ensures zero-downtime deployments. Requires readiness probes to be configured correctly.

### Blue-Green and Canary

Kubernetes doesn't natively support blue-green or canary. Implement via:
- **Service selector switch** (blue-green): deploy new version with different labels, then update Service selector
- **Gateway API weight-based routing** (canary): route a percentage of traffic to canary pods
- **Argo Rollouts**: CRD-based progressive delivery with canary, blue-green, and analysis
- **Flagger**: automates canary deployments with service mesh or Ingress controller metrics

---

## Cluster Operations

### Upgrade Strategy

1. Read release notes and changelog for deprecations and breaking changes
2. Back up etcd: `etcdctl snapshot save`
3. Upgrade control plane nodes first (one at a time in HA)
4. Upgrade worker nodes (drain → upgrade → uncordon, one at a time)
5. Only skip one minor version at a time (1.34 → 1.35, not 1.34 → 1.36)
6. Test upgrades in staging first

### Node Maintenance

```bash
# Cordon (prevent new pods, keep existing)
kubectl cordon <node>

# Drain (evict all pods respecting PDBs)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --timeout=300s

# Perform maintenance...

# Uncordon (allow scheduling again)
kubectl uncordon <node>
```

### Namespace Hygiene

- Use namespaces to separate environments (staging, production) or teams
- Apply ResourceQuota and LimitRange to every user namespace
- Apply Pod Security Standards labels
- Apply default NetworkPolicy (deny-all + explicit allows)
- Clean up completed Jobs: use `ttlSecondsAfterFinished`

---

## Observability

### Metrics Pipeline

```
kubelet /metrics/resource → Metrics Server → HPA / kubectl top
kubelet /metrics/cadvisor → Prometheus (scrape) → Grafana / Alertmanager
kube-state-metrics → Prometheus → Dashboard (deployment/pod/node state)
```

**Essential alerts**:
- Pod CrashLoopBackOff for >10 minutes
- Node NotReady for >5 minutes
- PVC >85% utilized
- Certificate expiration <30 days
- API server error rate >1%
- etcd database size approaching quota

### Logging Strategy

- Aggregate logs centrally (Loki, Elasticsearch, CloudWatch)
- Use structured logging (JSON) from applications
- Include request IDs for distributed tracing correlation
- Set log retention policies per namespace or severity
- DaemonSet-based collectors (Fluent Bit, Vector) are preferred over sidecar collectors for resource efficiency

---

## Label and Annotation Conventions

### Recommended Labels (kubernetes.io/docs)

```yaml
metadata:
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-production
    app.kubernetes.io/version: "2.3.1"
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: myplatform
    app.kubernetes.io/managed-by: helm
```

Consistent labeling enables:
- Service selectors to target the right pods
- Monitoring dashboards to filter by app/component
- Cost allocation by team or application
- NetworkPolicy selectors
- PDB and HPA selectors
