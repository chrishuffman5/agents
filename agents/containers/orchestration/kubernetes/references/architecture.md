# Kubernetes Architecture Reference

Deep technical detail on Kubernetes internals for architecture and "how does it work" questions.

---

## Control Plane Internals

### kube-apiserver Request Flow

```
Client Request (kubectl, controller, operator)
  → TLS termination
  → Authentication (x509 / OIDC / ServiceAccount / Webhook)
  → Authorization (RBAC / Node / Webhook)
  → Mutating Admission Webhooks (modify the object)
  → Schema Validation (OpenAPI v3 schema)
  → Validating Admission Webhooks (reject if invalid)
  → ValidatingAdmissionPolicy (CEL-based, in-process, K8s 1.30+)
  → etcd write (or read for GET requests)
  → Response to client
```

**API Groups and Versions**:
- Core group (`""`): pods, services, configmaps, secrets, namespaces, nodes, PVs, PVCs
- `apps/v1`: deployments, statefulsets, daemonsets, replicasets
- `batch/v1`: jobs, cronjobs
- `networking.k8s.io/v1`: ingresses, networkpolicies
- `rbac.authorization.k8s.io/v1`: roles, clusterroles, bindings
- `gateway.networking.k8s.io/v1`: gateways, httproutes (Gateway API)
- `autoscaling/v2`: horizontalpodautoscalers
- `policy/v1`: poddisruptionbudgets
- `storage.k8s.io/v1`: storageclasses, csinodes, csidrivers

**API Priority and Fairness (APF)**: kube-apiserver uses APF to prevent any single client from overwhelming the API server. FlowSchemas classify requests into priority levels, and each level gets a fair share of server capacity. Critical system components (kube-controller-manager, kube-scheduler) get higher priority than user requests.

### etcd Operations

etcd stores all cluster state. Only the API server communicates with etcd.

**Key space layout**:
```
/registry/pods/<namespace>/<name>
/registry/services/specs/<namespace>/<name>
/registry/deployments/<namespace>/<name>
/registry/secrets/<namespace>/<name>
/registry/configmaps/<namespace>/<name>
/registry/nodes/<name>
```

**Consistency model**: linearizable reads and writes via Raft consensus. A write is committed when a majority of members acknowledge it.

**Performance tuning**:
- Use SSDs for etcd data directory (WAL and snapshot)
- Dedicated disk for etcd (not shared with other workloads)
- `--quota-backend-bytes`: default 2GB, can increase to 8GB for large clusters
- Monitor `etcd_mvcc_db_total_size_in_bytes` vs quota
- Defragment periodically: `etcdctl defrag --endpoints=...`
- Compact old revisions: `etcdctl compact <revision>`

**Backup and restore**:
```bash
# Snapshot
etcdctl snapshot save /backup/etcd-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify snapshot
etcdctl snapshot status /backup/etcd-20260408.db --write-table

# Restore (stop kube-apiserver first)
etcdctl snapshot restore /backup/etcd-20260408.db \
  --data-dir=/var/lib/etcd-restored \
  --name=etcd-0 \
  --initial-cluster=etcd-0=https://10.0.0.1:2380 \
  --initial-advertise-peer-urls=https://10.0.0.1:2380
```

**HA etcd**: 3 members tolerate 1 failure. 5 members tolerate 2 failures. More members increase write latency (more Raft round-trips). 3 is recommended for most clusters; 5 for critical production.

### kube-scheduler Internals

**Scheduling Framework extension points** (in execution order):

| Extension Point | Purpose |
|----------------|---------|
| QueueSort | Order pods in the scheduling queue |
| PreFilter | Pre-process or check pod info |
| Filter | Eliminate infeasible nodes |
| PostFilter | Handle unschedulable pods (preemption) |
| PreScore | Pre-process for scoring |
| Score | Rank feasible nodes |
| NormalizeScore | Normalize scores across plugins |
| Reserve | Reserve resources before binding |
| Permit | Approve, deny, or delay binding |
| PreBind | Pre-binding actions (e.g., provision network/storage) |
| Bind | Bind pod to node |
| PostBind | Post-binding cleanup |

**Default filter plugins**: NodeResourcesFit, NodeName, NodePorts, NodeAffinity, TaintToleration, PodTopologySpread, VolumeBinding, InterPodAffinity.

**Default score plugins**: NodeResourcesBalancedAllocation, InterPodAffinity, NodeAffinity, PodTopologySpread, TaintToleration, ImageLocality.

**Scheduling profiles**: multiple profiles can run in the same scheduler, selected via `spec.schedulerName` in the pod spec.

### kube-controller-manager

Each controller runs an independent reconciliation loop. Controllers share informer caches (reducing API server load) via the `SharedInformerFactory`.

**Controller internals**:
```
Informer (watch API server) → Event Handler → Work Queue → Worker Goroutines → Reconcile
```

- **Informers**: cache a local copy of resources, deliver events (Add, Update, Delete)
- **Work queues**: rate-limited, deduplicated. Multiple events for the same object are collapsed into one reconciliation.
- **Resync period**: periodic re-list to catch any missed events (belt-and-suspenders)

**Key controllers**:
- **Deployment controller**: creates/updates ReplicaSets. Manages rolling update by scaling new RS up and old RS down simultaneously.
- **StatefulSet controller**: creates pods sequentially (pod-0 before pod-1). Respects `podManagementPolicy` (OrderedReady vs Parallel).
- **Garbage collector**: cascading deletion. Owner references link child objects to parents.

---

## Data Plane Internals

### kubelet Architecture

```
kubelet
  ├── Pod Lifecycle Manager
  │   ├── Container Runtime (via CRI gRPC)
  │   ├── Image Manager (pull, GC)
  │   └── Probe Manager (liveness, readiness, startup)
  ├── Volume Manager
  │   ├── CSI plugins
  │   └── Mount/Unmount operations
  ├── Device Plugin Manager
  │   └── GPU, FPGA, SR-IOV devices
  ├── Node Status Manager
  │   └── Reports conditions, capacity, allocatable
  ├── Metrics Server endpoint
  │   └── /metrics/resource (CPU, memory per pod)
  └── Certificate Manager
      └── TLS bootstrap, cert rotation
```

**Pod startup sequence**:
1. kubelet receives pod spec from API server (via watch)
2. Admit pod (check node resources, pod security)
3. Create pod sandbox (network namespace via CNI)
4. Pull images for init containers (sequentially)
5. Run init containers (sequentially, each must exit 0)
6. Pull images for app containers
7. Start app containers (and sidecar init containers if defined)
8. Begin probe checks (startup probe first, then liveness + readiness)

**Pod shutdown sequence**:
1. Pod marked for deletion
2. Endpoints controllers remove pod from Service endpoints
3. kubelet sends SIGTERM to all containers
4. Wait `terminationGracePeriodSeconds` (default 30s)
5. Send SIGKILL if containers haven't exited
6. Clean up volumes, network namespace

**Node conditions**: Ready, MemoryPressure, DiskPressure, PIDPressure, NetworkUnavailable. Node controller marks node NotReady after `--node-monitor-grace-period` (default 40s) without heartbeat.

### CRI Details

```
kubelet ←(gRPC)→ CRI Runtime
                    ├── containerd
                    │     ├── CRI plugin (built-in)
                    │     ├── runc (default OCI runtime)
                    │     └── Alternative runtimes: gVisor (runsc), Kata Containers (kata-runtime)
                    └── CRI-O
                          ├── Designed for K8s only
                          ├── runc (default)
                          └── crun (lightweight C runtime)
```

**Runtime classes**: enable running different workloads with different OCI runtimes on the same cluster:
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    sandbox: gvisor
```

### kube-proxy Modes Deep Dive

**iptables mode**:
- Creates DNAT rules for each Service → Endpoint pair
- Random load balancing (iptables probability module)
- O(n) rule evaluation per connection (slow at >10K services)
- No connection draining on endpoint removal

**IPVS mode**:
- Uses Linux IPVS (L4 load balancer in kernel)
- O(1) connection dispatch regardless of service count
- Multiple load balancing algorithms: round-robin, least-connections, source-hash
- Connection draining on endpoint changes

**nftables mode** (K8s 1.33+ beta):
- Uses nftables (successor to iptables)
- Better performance than iptables mode
- Cleaner rule management (sets and maps vs linear chains)
- Requires kernel 5.13+

### CNI (Container Network Interface)

CNI plugins configure pod networking when the sandbox is created:

| Plugin | Dataplane | Features |
|--------|-----------|----------|
| Calico | iptables / eBPF | NetworkPolicy, BGP, VXLAN, WireGuard encryption |
| Cilium | eBPF | NetworkPolicy, service mesh, observability, Hubble |
| Flannel | VXLAN / host-gw | Simple overlay, no NetworkPolicy |
| Weave Net | VXLAN | NetworkPolicy, encryption, multicast |
| AWS VPC CNI | Native VPC | Pods get VPC IPs, security groups for pods |
| Azure CNI | Native VNet | Pods get VNet IPs, overlay option available |

**Pod networking model**: every pod gets a unique IP. Pods can communicate directly without NAT across nodes. The CNI plugin implements this (overlay or native routing).

---

## API Server Aggregation Layer

The API server can be extended with additional API servers that handle custom API groups:

```yaml
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1beta1.metrics.k8s.io
spec:
  service:
    name: metrics-server
    namespace: kube-system
  group: metrics.k8s.io
  version: v1beta1
  insecureSkipTLSVerify: true
  groupPriorityMinimum: 100
  versionPriority: 100
```

The Metrics Server registers `metrics.k8s.io` via the aggregation layer. `kubectl top` queries this API.

---

## Cluster Networking Architecture

```
Pod A (10.244.1.5) ──CNI overlay/route──→ Pod B (10.244.2.8)
                                            (different node)

Pod A (10.244.1.5) ──→ Service ClusterIP (10.96.0.10)
                         ──kube-proxy/eBPF DNAT──→ Pod B (10.244.2.8)

External ──→ LoadBalancer ──→ NodePort ──→ Service ClusterIP ──→ Pod
```

**IP address ranges**:
- Pod CIDR: `--cluster-cidr` (e.g., 10.244.0.0/16)
- Service CIDR: `--service-cluster-ip-range` (e.g., 10.96.0.0/12)
- Node IPs: from the infrastructure network

These three ranges must not overlap.

---

## Certificate Architecture

Kubernetes uses TLS extensively. Key certificates:

| Certificate | Purpose | Issued By |
|------------|---------|-----------|
| API server serving cert | TLS for API server | Cluster CA |
| API server client cert for etcd | API server authenticates to etcd | etcd CA |
| etcd peer certs | etcd member-to-member communication | etcd CA |
| kubelet client cert | kubelet authenticates to API server | Cluster CA |
| kubelet serving cert | API server connects to kubelet (logs, exec) | Cluster CA |
| Front proxy cert | API aggregation | Front Proxy CA |
| ServiceAccount signing key | Signs SA tokens | Key pair (not CA) |

**Certificate rotation**: kubelet rotates its client certificate automatically (`--rotate-certificates`, enabled by default). Server certificate rotation available via `RotateKubeletServerCertificate` feature gate (stable).

**kubeadm** manages certificate lifecycle: `kubeadm certs check-expiration`, `kubeadm certs renew all`.
