# Orchestration Fundamentals

Core concepts that apply across all container orchestration platforms.

---

## Desired State and Declarative Management

Container orchestration is built on the **declarative model**: you describe the desired state of your system, and the orchestrator continuously works to make reality match that declaration.

```
User declares: "I want 3 replicas of my app, each with 256Mi memory"
Orchestrator: creates pods, monitors health, replaces failures, enforces resource limits
```

**Imperative vs Declarative**:
- Imperative: "run this container on node-2" -- specifies the action
- Declarative: "ensure 3 healthy replicas exist" -- specifies the outcome

Declarative management enables self-healing, rollback, and auditability. The desired state is stored as data (YAML/JSON manifests) and can be version-controlled.

---

## Reconciliation Loops

The core mechanism of orchestration. Every controller runs a continuous loop:

```
1. Observe: read current state from the cluster
2. Compare: diff current state against desired state
3. Act: take minimal actions to converge (create, update, delete resources)
4. Repeat
```

This pattern is called the **control loop** or **reconciliation loop**. It provides:

- **Self-healing**: if a pod crashes, the controller creates a replacement
- **Eventual consistency**: transient failures are retried automatically
- **Idempotency**: running reconciliation multiple times produces the same result

**Level-triggered vs edge-triggered**: Kubernetes controllers are level-triggered -- they react to the current state, not to change events. If a controller misses an event, it still converges on the next reconciliation because it compares the full desired state against the full current state.

### Watch Mechanism

Controllers use the API server's **watch** endpoint to receive a stream of changes efficiently rather than polling. The watch delivers:
- The initial list of resources (at a specific `resourceVersion`)
- A stream of ADDED, MODIFIED, and DELETED events

If the watch disconnects, the controller re-lists from the last known `resourceVersion` and resumes watching.

---

## Operators and Custom Controllers

An **Operator** is a controller that encodes domain-specific operational knowledge for a particular application or service. Operators extend the orchestrator's native reconciliation pattern to manage complex, stateful applications.

### What Operators Do

- Automate Day 2 operations: upgrades, backups, scaling, failover
- Encode runbooks as code: "if primary database fails, promote replica, reconfigure connection strings"
- Manage application lifecycle beyond simple deployment

### Operator Pattern

```
Custom Resource (CR) --- defines desired state for the application
     |
Operator Controller --- watches CRs, reconciles application state
     |
Managed Resources --- creates/updates Pods, Services, ConfigMaps, PVCs
```

### Operator Maturity Model

| Level | Capability | Example |
|-------|-----------|---------|
| 1 - Basic Install | Automated deployment | Helm chart wrapper |
| 2 - Seamless Upgrades | Automated version upgrades | Patch and minor version handling |
| 3 - Full Lifecycle | Backup, restore, failure recovery | Database operator with point-in-time recovery |
| 4 - Deep Insights | Metrics, alerts, log analysis | Operator exposes SLI dashboards |
| 5 - Auto Pilot | Auto-scaling, auto-tuning, anomaly detection | Self-optimizing database operator |

### Building Operators

Common frameworks:
- **Kubebuilder**: Go-based, generates scaffolding, uses controller-runtime
- **Operator SDK**: Supports Go, Ansible, and Helm-based operators
- **KUDO**: Declarative operator development (simpler but less flexible)
- **Metacontroller**: Lightweight, webhook-based custom controllers

---

## Custom Resource Definitions (CRDs)

CRDs extend the Kubernetes API with new resource types. Once a CRD is installed, users can create, read, update, and delete instances of that custom resource using kubectl and the API server, just like built-in resources.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.example.com
spec:
  group: example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              engine:
                type: string
                enum: ["postgres", "mysql", "mongodb"]
              version:
                type: string
              replicas:
                type: integer
                minimum: 1
                maximum: 7
              storage:
                type: string
            required: ["engine", "version"]
    additionalPrinterColumns:
    - name: Engine
      type: string
      jsonPath: .spec.engine
    - name: Version
      type: string
      jsonPath: .spec.version
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
    shortNames: ["db"]
```

### CRD Best Practices

- **Schema validation**: always define `openAPIV3Schema` to validate custom resource fields at admission time
- **Versioning**: use multiple versions with conversion webhooks for API evolution
- **Status subresource**: enable `.status` subresource so controllers can update status without triggering spec watches
- **Printer columns**: define `additionalPrinterColumns` so `kubectl get` shows useful information
- **Categories**: add the CRD to a category (e.g., `all`) so `kubectl get all` includes it

---

## Admission Control

Admission controllers intercept requests to the API server after authentication and authorization but before the object is persisted. They can validate, mutate, or reject requests.

### Admission Pipeline

```
Client Request
  → Authentication (who are you?)
  → Authorization (are you allowed?)
  → Mutating Admission (modify the request)
  → Schema Validation (does it match the API schema?)
  → Validating Admission (custom validation)
  → Persist to etcd
```

### Built-in Admission Controllers

| Controller | Purpose |
|-----------|---------|
| NamespaceLifecycle | Prevents operations in terminating namespaces |
| LimitRanger | Applies default resource requests/limits |
| ResourceQuota | Enforces namespace resource quotas |
| PodSecurity | Enforces Pod Security Standards (restricted/baseline/privileged) |
| DefaultStorageClass | Assigns default StorageClass to PVCs |
| MutatingAdmissionWebhook | Calls external webhooks to mutate objects |
| ValidatingAdmissionWebhook | Calls external webhooks to validate objects |

### Dynamic Admission Webhooks

External webhooks allow custom admission logic without modifying the API server:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: validate-pods
webhooks:
- name: validate.example.com
  clientConfig:
    service:
      name: validation-service
      namespace: system
      path: /validate
    caBundle: <base64-ca>
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE", "UPDATE"]
    resources: ["pods"]
  failurePolicy: Fail        # Fail closed (reject if webhook unavailable)
  sideEffects: None
  timeoutSeconds: 5
```

### ValidatingAdmissionPolicy (KEP-3488)

Kubernetes 1.30+ supports in-process validation using CEL (Common Expression Language), eliminating the need for webhook servers for simple validation rules:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-labels
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: ["apps"]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["deployments"]
  validations:
  - expression: "has(object.metadata.labels) && 'app' in object.metadata.labels"
    message: "All deployments must have an 'app' label"
  - expression: "object.spec.replicas <= 50"
    message: "Replica count must not exceed 50"
```

CEL-based policies are faster (no network call), more reliable (no webhook availability concern), and simpler to deploy than webhook-based validation.

---

## Scheduling Concepts

Orchestrators must decide where to place workloads. Key scheduling concepts:

### Resource-Based Scheduling

Nodes advertise capacity (CPU, memory, GPUs). The scheduler matches pod resource requests against available node capacity. A pod is only scheduled to a node with sufficient allocatable resources.

### Affinity and Anti-Affinity

- **Node affinity**: attract pods to specific nodes (e.g., GPU nodes, SSD nodes)
- **Pod affinity**: co-locate pods that communicate frequently (same zone, same node)
- **Pod anti-affinity**: spread pods apart for high availability (one per node, one per zone)

### Topology-Aware Scheduling

Distribute workloads across failure domains (zones, regions, racks) to survive infrastructure failures. Topology spread constraints define maximum skew between domains.

### Preemption and Priority

Higher-priority pods can evict lower-priority pods when resources are scarce. PriorityClasses define the priority levels. Critical system components (CoreDNS, kube-proxy) use built-in high-priority classes.

### Bin Packing vs Spreading

- **Bin packing**: maximize utilization by filling nodes densely (cost-efficient)
- **Spreading**: distribute across nodes for resilience (availability-focused)

Most production environments balance both: spread across zones for HA, bin-pack within zones for cost.

---

## Service Discovery and Load Balancing

Orchestrators abstract away individual pod IPs and provide stable service endpoints:

- **DNS-based discovery**: services get DNS names (e.g., `myapp.production.svc.cluster.local`)
- **Virtual IPs (ClusterIP)**: stable IP that load-balances to backend pods
- **Headless services**: DNS returns individual pod IPs for client-side load balancing
- **External exposure**: LoadBalancer, NodePort, Ingress, Gateway API

### Health-Based Routing

Orchestrators only route traffic to healthy pods:
- **Readiness probes**: pod is added to service endpoints only when ready
- **Liveness probes**: pod is restarted if the liveness check fails
- **Startup probes**: allow slow-starting containers to initialize before liveness checks begin

---

## Multi-Tenancy Models

How orchestration platforms isolate workloads for different teams or customers:

| Model | Isolation | Overhead | Use Case |
|-------|-----------|----------|----------|
| Namespace-per-tenant | Soft (RBAC, NetworkPolicy, ResourceQuota) | Low | Internal teams |
| Cluster-per-tenant | Strong (separate control planes) | High | Regulated / hostile tenants |
| Virtual clusters (vCluster) | Medium (virtual control plane, shared nodes) | Medium | Platform-as-a-service |

Key isolation mechanisms:
- **RBAC**: restrict API access per namespace
- **NetworkPolicy**: restrict pod-to-pod traffic
- **ResourceQuota**: cap resource consumption per namespace
- **LimitRange**: enforce per-pod resource boundaries
- **Pod Security Standards**: enforce security baselines per namespace
- **User namespaces** (K8s 1.35 beta): map container root to unprivileged host UID
