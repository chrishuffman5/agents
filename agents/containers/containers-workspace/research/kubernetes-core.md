# Kubernetes Core Deep Dive
*Research date: April 2026*

---

## Architecture Overview

A Kubernetes cluster has two logical planes: the **Control Plane** (manages desired state) and the **Data Plane** / worker nodes (runs workloads).

```
Control Plane:
  kube-apiserver ←→ etcd
       ↑↓
  kube-scheduler
  kube-controller-manager
  cloud-controller-manager (optional)

Worker Nodes:
  kubelet ← (reads from apiserver)
  kube-proxy
  container runtime (containerd / CRI-O)
```

---

## Control Plane Components

### kube-apiserver

The single entry point for all cluster operations. All clients (kubectl, controllers, operators) communicate exclusively with the API server.

- Exposes REST API (and `kubectl` commands map to REST calls)
- Validates and persists resource definitions to etcd
- Enforces admission control (ValidatingAdmissionWebhook, MutatingAdmissionWebhook)
- Horizontal scaling: deploy multiple kube-apiserver instances behind a load balancer
- Authentication: x509 certs, OIDC tokens, ServiceAccount tokens, webhook auth
- Authorization: RBAC, ABAC, Node, Webhook

### etcd

Distributed, strongly consistent key-value store. The "source of truth" for all cluster state.

- All Kubernetes objects are stored as protobufs under `/registry/...` keys
- In HA setups: 3 or 5 member etcd cluster (Raft consensus)
- etcd v3 API only (v2 fully removed)
- Critical to back up regularly: `etcdctl snapshot save /backup/snapshot.db`
- Only the kube-apiserver writes to etcd directly; all other components use the API server

### kube-scheduler

Watches for Pods with `spec.nodeName == ""` and assigns them to nodes.

Scheduling cycle:
1. **Filter**: eliminate nodes that don't satisfy Pod requirements (resources, taints/tolerations, nodeSelector, affinity, topology constraints)
2. **Score**: rank remaining nodes (most available resources, spread, locality)
3. **Bind**: assign `spec.nodeName` to winning node

Scheduler extenders and the Scheduler Framework allow custom plugins at each extension point.

### kube-controller-manager

Runs all built-in controllers as goroutines in a single binary:

| Controller | Function |
|-----------|----------|
| ReplicaSet | Ensures desired replica count |
| Deployment | Manages ReplicaSet rollouts |
| StatefulSet | Ordered, stable pod management |
| DaemonSet | One pod per node |
| Job / CronJob | Batch workloads |
| Service | Manages ClusterIP assignments |
| Namespace | Lifecycle management |
| Node | Marks nodes as ready/not ready |
| PV / PVC | Storage binding and reclamation |
| ServiceAccount | Creates default accounts |

### cloud-controller-manager

Separates cloud-specific logic from the core controller manager:
- Node controller: checks cloud provider for node existence
- Route controller: sets up routes in cloud network
- Service controller: manages cloud load balancers

---

## Data Plane Components

### kubelet

An agent running on every node. Responsibilities:
- Registers node with the API server
- Watches for Pods assigned to its node via the API server
- Pulls container images and starts containers via CRI
- Reports Pod and Node status back to API server
- Runs liveness, readiness, and startup probes
- Manages volumes (mounts, unmounts)
- Collects resource metrics (Metrics Server scrapes kubelet `/metrics/resource`)
- Manages device plugins (GPUs, FPGAs via kubelet device plugin API)

### kube-proxy

Implements the Kubernetes Service abstraction by programming the node's network rules:

- **iptables mode** (default): creates iptables rules for each Service/Endpoint; DNAT packets to pod IPs
- **ipvs mode**: uses Linux IPVS (IP Virtual Server) for better performance at large scale (1000s of services)
- **nftables mode**: new in Kubernetes 1.33; uses nftables instead of iptables for modern kernels

kube-proxy is increasingly being replaced by CNI plugins (Cilium eBPF, Calico eBPF) that handle service load balancing more efficiently in the kernel.

### Container Runtime Interface (CRI)

CRI is the plugin interface that kubelet uses to communicate with container runtimes. Defined as a gRPC API.

Compatible runtimes:
- **containerd** (default in most distributions): uses CRI plugin built-in
- **CRI-O**: lightweight OCI runtime designed specifically for Kubernetes
- **Docker Engine**: via `cri-dockerd` shim (Docker removed native CRI support in K8s 1.24)

---

## Kubernetes API Resources

### Pods

The smallest deployable unit. A Pod wraps one or more containers sharing a network namespace and storage volumes.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  labels:
    app: myapp
    version: v1.0
spec:
  containers:
  - name: app
    image: myapp:v1.0
    ports:
    - containerPort: 8080
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 15
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      periodSeconds: 5
    startupProbe:
      httpGet:
        path: /health
        port: 8080
      failureThreshold: 30
      periodSeconds: 10
    securityContext:
      runAsNonRoot: true
      runAsUser: 10001
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
  initContainers:
  - name: migrate-db
    image: myapp-migrations:v1.0
    command: ["./migrate", "up"]
  securityContext:
    fsGroup: 10001
  terminationGracePeriodSeconds: 30
```

### Pod Lifecycle

1. **Pending**: Pod accepted, waiting for scheduling/image pull
2. **Running**: Pod is scheduled, at least one container is running
3. **Succeeded**: All containers terminated with exit code 0
4. **Failed**: All containers terminated, at least one non-zero exit
5. **Unknown**: Node communication lost

**Container states**: Waiting → Running → Terminated

### Pod QoS Classes

Kubernetes assigns QoS classes based on resource requests/limits:

| QoS Class   | Criteria | Eviction Priority |
|-------------|----------|------------------|
| Guaranteed  | requests == limits for all containers | Last evicted |
| Burstable   | At least one container has requests/limits but not equal | Middle |
| BestEffort  | No requests or limits set | First evicted |

### Deployments

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app: myapp
        version: v1.0
    spec:
      containers:
      - name: app
        image: myapp:v1.0
        # ... (same as pod spec above)
```

### StatefulSets

For stateful workloads (databases, message queues) requiring stable network identity and persistent storage:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres-headless
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 50Gi
```

StatefulSets provide: stable network names (pod-0, pod-1, ...), ordered deployment/scaling, and persistent volume per pod.

### DaemonSets

Run exactly one pod per node (or per matching node):

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
spec:
  selector:
    matchLabels:
      name: fluentd
  template:
    metadata:
      labels:
        name: fluentd
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1
```

### Jobs and CronJobs

```yaml
# Job
apiVersion: batch/v1
kind: Job
spec:
  completions: 5          # run 5 successful completions
  parallelism: 2          # run up to 2 in parallel
  backoffLimit: 3         # retry up to 3 times
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: myapp-worker:v1

# CronJob
apiVersion: batch/v1
kind: CronJob
spec:
  schedule: "0 * * * *"          # every hour
  concurrencyPolicy: Forbid       # don't start if previous still running
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template: ...
```

### Services

```yaml
# ClusterIP (default, internal)
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP

# LoadBalancer (cloud)
spec:
  type: LoadBalancer
  loadBalancerSourceRanges:
    - 10.0.0.0/8

# NodePort
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080  # 30000-32767

# Headless (no ClusterIP, DNS returns pod IPs)
spec:
  clusterIP: None
  selector:
    app: myapp
```

### Ingress (Legacy) and Gateway API

**Ingress** (legacy, maintenance mode):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: myapp-api
            port:
              number: 80
```

**Ingress NGINX is entering maintenance-only mode** (best-effort until March 2026, then archived). The recommended migration path is the **Gateway API**.

**Gateway API v1.4** (GA, October 2025):
```yaml
# GatewayClass (infra provider declares this)
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  controllerName: k8s.nginx.org/nginx-gateway-controller

# Gateway (infra team creates)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: prod-gateway
  namespace: infra
spec:
  gatewayClassName: nginx
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      certificateRefs:
      - name: my-cert

# HTTPRoute (app team creates)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp
  namespace: production
spec:
  parentRefs:
  - name: prod-gateway
    namespace: infra
  hostnames: ["myapp.example.com"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: myapp-api
      port: 80
      weight: 100
```

Gateway API v1.4 adds: BackendTLSPolicy (TLS between gateway and backend), GRPCRoute (stable), TCPRoute/TLSRoute (experimental).

### ConfigMaps and Secrets

```yaml
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DATABASE_HOST: "postgres.production.svc.cluster.local"
  config.yaml: |
    server:
      port: 8080
      timeout: 30s

# Secret (base64-encoded)
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  DATABASE_PASSWORD: cGFzc3dvcmQxMjM=   # base64

# Using in pods
spec:
  containers:
  - name: app
    envFrom:
    - configMapRef:
        name: app-config
    - secretRef:
        name: app-secrets
    volumeMounts:
    - name: config
      mountPath: /app/config
  volumes:
  - name: config
    configMap:
      name: app-config
```

### PersistentVolumes and PVCs

```yaml
# StorageClass (provisioner creates PVs on demand)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

# PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mydata
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 10Gi
```

Access modes: `ReadWriteOnce` (single node), `ReadOnlyMany`, `ReadWriteMany`, `ReadWriteOncePod` (single pod, K8s 1.22+).

**VolumeAttributesClass (VAC)** graduated to GA in Kubernetes 1.34, allowing storage attributes to be modified without recreating PVCs.

---

## RBAC

```yaml
# Role (namespace-scoped)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]

# ClusterRole (cluster-scoped)
kind: ClusterRole
metadata:
  name: node-viewer
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]

# RoleBinding
kind: RoleBinding
metadata:
  name: read-pods
  namespace: production
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: ci-runner
  namespace: ci
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io

# ClusterRoleBinding
kind: ClusterRoleBinding
metadata:
  name: view-nodes
subjects:
- kind: Group
  name: ops-team
roleRef:
  kind: ClusterRole
  name: node-viewer
```

---

## Scheduling

### nodeSelector and nodeAffinity

```yaml
spec:
  nodeSelector:
    disktype: ssd         # simple label match

  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:   # hard rule
        nodeSelectorTerms:
        - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values: ["us-east-1a", "us-east-1b"]
      preferredDuringSchedulingIgnoredDuringExecution:  # soft rule
      - weight: 80
        preference:
          matchExpressions:
          - key: node-type
            operator: In
            values: ["compute-optimized"]
```

### Pod Affinity/Anti-Affinity

```yaml
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: myapp
        topologyKey: kubernetes.io/hostname   # one pod per node
    podAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: cache
          topologyKey: topology.kubernetes.io/zone  # co-locate with cache pods
```

### Taints and Tolerations

```bash
# Taint a node
kubectl taint nodes node1 gpu=true:NoSchedule
kubectl taint nodes node1 maintenance=true:NoExecute

# Remove taint
kubectl taint nodes node1 gpu=true:NoSchedule-
```

```yaml
# Toleration in Pod spec
spec:
  tolerations:
  - key: "gpu"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  - key: "maintenance"
    operator: "Exists"
    effect: "NoExecute"
    tolerationSeconds: 3600  # stay for 1h before eviction
```

### Topology Spread Constraints

Distribute pods evenly across failure domains:

```yaml
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule     # hard (ScheduleAnyway = soft)
    labelSelector:
      matchLabels:
        app: myapp
    matchLabelKeys: ["pod-template-hash"]  # K8s 1.29+: version-aware spreading
  - maxSkew: 2
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: myapp
```

`nodeTaintsPolicy` graduated to GA in Kubernetes 1.33, allowing topology spread constraints to consider taints.

---

## Resource Management

### Requests and Limits

- **Requests**: what's reserved/scheduled against. Guaranteed to the pod.
- **Limits**: maximum the container can use. Enforced by cgroups.

```yaml
resources:
  requests:
    cpu: "250m"       # 0.25 vCPU
    memory: "256Mi"
    nvidia.com/gpu: 1  # device plugin resource
  limits:
    cpu: "1000m"
    memory: "512Mi"
    nvidia.com/gpu: 1
```

CPU: fractional millicores (`m`). Memory: `Ki`, `Mi`, `Gi`, `Ti`.

**Best practice**: always set memory limits; be careful with CPU limits (can cause throttling even if node has free CPU).

### LimitRanges

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
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
      memory: "4Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
  - type: PersistentVolumeClaim
    max:
      storage: 50Gi
```

### ResourceQuotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    pods: "50"
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    persistentvolumeclaims: "20"
    requests.storage: 200Gi
    count/deployments.apps: "20"
    count/services: "30"
    count/secrets: "100"
    count/configmaps: "100"
```

### HPA (Horizontal Pod Autoscaler)

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
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: AverageValue
        averageValue: 400Mi
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
```

### VPA (Vertical Pod Autoscaler)

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
    updateMode: "Auto"   # Off | Initial | Recreate | Auto
  resourcePolicy:
    containerPolicies:
    - containerName: app
      minAllowed:
        cpu: "100m"
        memory: "128Mi"
      maxAllowed:
        cpu: "4"
        memory: "4Gi"
      controlledResources: ["cpu", "memory"]
```

VPA and HPA cannot scale the same metric simultaneously. Use HPA for CPU/memory + VPA for initial sizing, or use KEDA for event-driven autoscaling.

### PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 2          # or maxUnavailable: 1
  selector:
    matchLabels:
      app: myapp
```

---

## Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32  # block cloud metadata
    ports:
    - protocol: TCP
      port: 443
```

NetworkPolicies require a CNI plugin that enforces them (Calico, Cilium, Weave). kube-proxy does NOT enforce NetworkPolicies.

---

## Pod Security Standards

Replaces PodSecurityPolicy (removed in K8s 1.25). Applied via namespaced labels:

```yaml
# Label a namespace with a security policy
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

| Level       | Description |
|-------------|-------------|
| Privileged  | No restrictions (equivalent to no policy) |
| Baseline    | Minimal restrictions; blocks most known privilege escalations |
| Restricted  | Hardened; requires non-root, no privilege escalation, read-only root FS |

**Restricted** requires:
- `securityContext.runAsNonRoot: true`
- `securityContext.allowPrivilegeEscalation: false`
- `capabilities.drop: ["ALL"]`
- `seccompProfile.type: RuntimeDefault` or `Localhost`
- No hostNetwork, hostPID, hostIPC

---

## Kubernetes Version History (2025-2026)

### Kubernetes 1.33 (Octarine - early 2025)
- `nodeTaintsPolicy` in topology spread constraints graduated to GA
- nftables mode for kube-proxy moves to beta
- In-place pod vertical scaling improvements
- DRA (Dynamic Resource Allocation) enhancements

### Kubernetes 1.34 (Of Wind & Will - August 2025)
- VolumeAttributesClass (VAC) graduates to GA
- Sidecar containers (KEP-753) stable
- Improved Windows container support
- OIDC discovery improvements

### Kubernetes 1.35 (Timbernetes / The World Tree - December 2025)
- 60 enhancements: 22 alpha, 19 beta, 17 GA
- **User namespaces** graduated to beta and on-by-default (hardened workload isolation)
- **Pod Certificates (KEP-4317)** moved to beta and enabled by default (kubelet-issued serving certs)
- **DRA** (Dynamic Resource Allocation): consumable capacity, partitionable devices, device taints
- **cgroup v1 deprecation**: Kubernetes 1.35 prepares to retire legacy cgroup v1 support
- KYAML graduated to beta and enabled by default
- In-Place Pod Resize graduated to beta

### Kubernetes 1.36 (Expected April 2026)
- Gateway API improvements
- Improved Windows container support
- Further DRA maturation

---

## kubectl Essential Commands

```bash
# Context management
kubectl config get-contexts
kubectl config use-context production
kubectl config set-context --current --namespace=myapp

# Resource inspection
kubectl get all -n myapp
kubectl describe pod myapp-abc123 -n myapp
kubectl get events --sort-by=.lastTimestamp -n myapp
kubectl top pods -n myapp --sort-by=memory
kubectl top nodes

# Editing resources
kubectl apply -f manifest.yaml
kubectl apply -k kustomize/overlays/production/
kubectl set image deployment/myapp app=myapp:v2.0
kubectl rollout status deployment/myapp
kubectl rollout history deployment/myapp
kubectl rollout undo deployment/myapp --to-revision=2

# Scaling
kubectl scale deployment/myapp --replicas=5
kubectl autoscale deployment myapp --min=2 --max=10 --cpu-percent=60

# Debugging
kubectl exec -it myapp-abc123 -- bash
kubectl exec -it myapp-abc123 -c sidecar -- sh
kubectl port-forward pod/myapp-abc123 8080:8080
kubectl port-forward svc/myapp 8080:80
kubectl logs myapp-abc123 --previous --tail=100
kubectl logs -l app=myapp --all-containers --since=1h

# Node operations
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data
kubectl uncordon node1
kubectl cordon node1

# Resource queries
kubectl get pods -o wide --field-selector spec.nodeName=node1
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods --sort-by=.metadata.creationTimestamp

# Namespace operations
kubectl create namespace staging
kubectl delete namespace old-env     # cascading delete of all resources

# Force delete stuck pod
kubectl delete pod stuck-pod --grace-period=0 --force
```

---

## References

- [Kubernetes v1.35 Release](https://kubernetes.io/blog/2025/12/17/kubernetes-v1-35-release/)
- [Gateway API v1.4](https://kubernetes.io/blog/2025/11/06/gateway-api-v1-4/)
- [Kubernetes Security 2025 Features (CNCF)](https://www.cncf.io/blog/2025/12/15/kubernetes-security-2025-stable-features-and-2026-preview/)
- [Pod Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)
- [Kubernetes Architecture (Official)](https://kubernetes.io/docs/concepts/architecture/)
- [Kubernetes Autoscaling: HPA vs VPA](https://scaleops.com/blog/hpa-vs-vpa-understanding-kubernetes-autoscaling-and-why-its-not-enough-in-2025/)
