# Google GKE Architecture Reference

Deep technical detail on GKE Autopilot, Standard mode, Enterprise features, networking, and security.

---

## Cluster Architecture

### Control Plane

GKE runs the Kubernetes control plane as a managed service:
- Regional clusters: control plane replicated across 3 zones (recommended for production)
- Zonal clusters: single control plane instance (lower cost, lower availability)
- Control plane version: managed by GKE release channels (Rapid, Regular, Stable)

**Release channels**:
| Channel | Description | SLA |
|---------|-------------|-----|
| Rapid | Latest K8s version, earliest features | No SLA |
| Regular | GA-1 version, balanced stability | 99.95% (regional) |
| Stable | GA-2 version, maximum stability | 99.95% (regional) |
| Extended | Long-term support (24 months) | 99.95% |
| No channel | Manual version management | 99.95% |

### Node Architecture

**Container-Optimized OS (COS)**: default node OS. Minimal, hardened, auto-updated by Google. Read-only root filesystem, no SSH by default.

**Ubuntu**: alternative for workloads requiring custom kernel modules or specific packages.

**Windows Server**: for Windows containers (separate node pool).

```bash
# Node pool with specific image type
gcloud container node-pools create workers \
  --cluster=prod-cluster \
  --machine-type=e2-standard-8 \
  --image-type=COS_CONTAINERD \
  --num-nodes=3 \
  --enable-autoscaling --min-nodes=1 --max-nodes=20
```

---

## Autopilot Architecture

### How Autopilot Works

```
1. User creates pod with resource requests
2. GKE Autopilot scheduler evaluates resource requirements
3. Autopilot provisions (or reuses) a node matching the requirements
4. Pod is scheduled to the node
5. When pod is deleted and node is empty, node is automatically removed
```

**Key architectural decisions**:
- Nodes are fully managed -- users cannot SSH, modify kubelet, or install custom software
- Default Pod Security Standards: Restricted (enforced)
- System workloads (kube-system) are isolated on dedicated nodes
- Burst-to-node: pods can use more resources than requested (up to node capacity)

### Autopilot Pricing

Billed per pod resource requests:
- vCPU: per hour of requested CPU
- Memory: per GiB-hour of requested memory
- Ephemeral storage: per GiB-hour above 10GiB
- GPU: per GPU-hour

No charge for unscheduled pods or system overhead. Committed Use Discounts (CUDs) apply.

### Autopilot Limitations

- No DaemonSets (except partner DaemonSets allowlisted by Google)
- No privileged pods
- No host network/PID/IPC namespaces
- No hostPath volumes
- Resource requests capped at compute class maximums
- No custom RuntimeClasses (gVisor supported via built-in GKE Sandbox)
- Init containers count toward resource billing

---

## Networking Architecture

### VPC-Native Clusters

All GKE clusters created after 2020 are VPC-native (alias IP):

```
Node IP: from node subnet (primary range)
Pod IPs: from pod subnet (secondary range, alias IPs)
Service IPs: from service subnet (secondary range)
```

**IP planning**:
```bash
gcloud container clusters create prod-cluster \
  --network=my-vpc \
  --subnetwork=my-subnet \
  --cluster-secondary-range-name=pods \      # /14 recommended (262,144 IPs)
  --services-secondary-range-name=services   # /20 recommended (4,096 IPs)
```

### Dataplane V2 (Cilium) Deep Dive

GKE Dataplane V2 uses Cilium as the networking dataplane:

**Architecture**:
```
Pod → eBPF program (attached to veth) → Cilium agent → eBPF maps
                                                          ↓
                                                   Service resolution
                                                   NetworkPolicy enforcement
                                                   Load balancing (DNAT)
                                                          ↓
                                                   Destination pod/node
```

**Features**:
- **kube-proxy replacement**: service load balancing entirely in eBPF (faster, fewer iptables rules)
- **NetworkPolicy logging**: log allowed and denied connections with source/destination pod identity
- **FQDN policy**: control egress by DNS name (e.g., allow `*.googleapis.com`)
- **Hubble**: network observability (flow logs, DNS visibility, HTTP metrics)

```bash
# Enable network policy logging
gcloud container clusters update prod-cluster \
  --enable-network-policy-logging
```

### Cloud NAT for Egress

GKE nodes (especially Autopilot) may not have external IPs. Use Cloud NAT for outbound internet access:

```bash
gcloud compute routers create nat-router --region=us-central1 --network=my-vpc
gcloud compute routers nats create nat-config \
  --router=nat-router \
  --region=us-central1 \
  --auto-allocate-nat-external-ips \
  --nat-all-subnet-ip-ranges
```

### Gateway API Implementation

GKE provides managed Gateway controllers:

| GatewayClass | Load Balancer Type |
|-------------|-------------------|
| `gke-l7-global-external-managed` | Global External Application LB |
| `gke-l7-regional-external-managed` | Regional External Application LB |
| `gke-l7-rilb` | Internal Application LB |
| `gke-l7-gxlb` | Classic Global External LB |

**Multi-cluster Gateway**: route traffic across clusters in different regions:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: global-gateway
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: global-route
spec:
  parentRefs:
  - name: global-gateway
  rules:
  - backendRefs:
    - group: net.gke.io
      kind: ServiceImport       # references a multi-cluster service
      name: myapp
      port: 80
```

---

## Config Sync Architecture

### Sync Model

```
Git Repository (source of truth)
    ↓ (pull every 15s by default)
Config Sync Agent (runs in config-management-system namespace)
    ↓
Reconciliation Engine
    ├── Apply new/changed resources
    ├── Delete removed resources
    └── Detect and remediate drift
```

**Source types**:
- Git repository (branch, tag, or commit)
- OCI artifact (Helm chart or YAML bundle stored in Artifact Registry)
- Helm repository

### Hierarchy

- **RootSync**: cluster-scoped. Manages cluster-level resources (namespaces, CRDs, ClusterRoles) and can manage resources in any namespace. Runs with cluster-admin privileges.
- **RepoSync**: namespace-scoped. Manages resources within a single namespace. Delegated to app teams with limited privileges.

**Multi-repo mode**: recommended. Allows multiple RootSync and RepoSync objects for separation of concerns:
```
Platform team → RootSync (cluster infra, namespaces, policies)
Security team → RootSync (NetworkPolicies, PodSecurity, RBAC)
Team Alpha → RepoSync (team-alpha namespace apps and configs)
Team Beta → RepoSync (team-beta namespace apps and configs)
```

### Drift Detection

Config Sync watches for changes to managed resources. If someone modifies a resource via kubectl or the API, Config Sync detects the drift and remediates it within seconds.

**Annotation to prevent remediation**:
```yaml
metadata:
  annotations:
    configmanagement.gke.io/managed: disabled    # Config Sync won't remediate changes
```

---

## Policy Controller Architecture

Policy Controller runs OPA Gatekeeper with GKE-specific integrations:

### Components

```
ConstraintTemplate → defines the policy logic (Rego)
Constraint → applies the template with specific parameters
    ↓
Admission Webhook → intercepts API requests
    ↓
Policy evaluation (OPA engine)
    ↓
Allow or Deny
```

### Policy Bundles

Pre-built policy libraries installable via Config Sync or directly:

| Bundle | Description |
|--------|-------------|
| CIS Benchmark | CIS Kubernetes Benchmark controls |
| Pod Security Standards | Enforce PSS at admission time |
| Cost Management | Require resource requests/limits |
| Network Security | Enforce NetworkPolicy presence |
| RBAC Security | Restrict ClusterRoleBinding usage |

### Audit Mode

Policies can run in audit-only mode to detect violations without blocking:

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-labels-audit
spec:
  enforcementAction: dryrun    # dryrun (audit only) | deny (enforce) | warn (warn but allow)
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
  parameters:
    labels:
    - key: app
```

---

## Storage Architecture

### Persistent Disk CSI

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ssd-regional
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd    # replicate across 2 zones
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

**Disk types**:
- `pd-standard`: HDD, lowest cost
- `pd-balanced`: SSD, balanced price/performance
- `pd-ssd`: SSD, highest IOPS
- `pd-extreme`: highest IOPS and throughput (up to 120K IOPS)
- `hyperdisk-balanced`: next-gen, flexible IOPS/throughput/capacity

**Regional PD**: replicated across 2 zones. Enables StatefulSet failover across zones without data loss.

### Filestore CSI

Managed NFS (ReadWriteMany):

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: filestore-standard
provisioner: filestore.csi.storage.gke.io
parameters:
  tier: standard    # standard, premium, enterprise
  network: my-vpc
```

---

## Security Architecture

### Workload Identity Federation

```
1. KSA (Kubernetes ServiceAccount) annotated with GSA email
2. Pod starts with projected SA token
3. GKE metadata server intercepts token requests
4. Returns GCP credentials scoped to the bound GSA
5. App authenticates to GCP services as the GSA
```

**Metadata server**: GKE runs a per-node metadata server that intercepts requests to the GCE metadata endpoint (169.254.169.254). It returns workload identity tokens instead of node-level credentials.

### Binary Authorization

```yaml
# Attestor-based policy
defaultAdmissionRule:
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  requireAttestationsBy:
  - projects/PROJECT/attestors/build-attestor
  - projects/PROJECT/attestors/security-scan-attestor
```

**Flow**: CI/CD pipeline builds image → signs with attestor key → pushes to Artifact Registry → Binary Authorization validates signatures at deploy time → allows or blocks.

### VPC Service Controls

Restrict GKE API access to authorized VPCs:

```bash
gcloud access-context-manager perimeters create gke-perimeter \
  --resources=projects/PROJECT_NUMBER \
  --restricted-services=container.googleapis.com
```

Prevents data exfiltration by blocking GKE API calls from outside the perimeter.
