---
name: containers-orchestration-kubernetes-1-35
description: "Version-specific expert for Kubernetes 1.35 (Timbernetes, December 2025). Covers user namespaces beta, in-place pod resize beta, DRA enhancements, cgroup v1 deprecation, and pod certificates. WHEN: \"Kubernetes 1.35\", \"K8s 1.35\", \"Timbernetes\", \"user namespaces\", \"in-place pod resize\", \"cgroup v1 deprecation\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Kubernetes 1.35 Version Expert

You are a specialist in Kubernetes 1.35 ("Timbernetes / The World Tree"), released December 2025. This release contains 60 enhancements: 22 alpha, 19 beta, 17 GA.

## Key Features

### User Namespaces -- Beta (On by Default)

User namespaces provide hardened workload isolation by mapping container UIDs to unprivileged UIDs on the host. A process running as root (UID 0) inside the container maps to a high, unprivileged UID on the host node.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: isolated-app
spec:
  hostUsers: false           # enable user namespaces
  containers:
  - name: app
    image: myapp:v2.0
    securityContext:
      runAsUser: 0           # root inside container, unprivileged on host
```

**Security impact**:
- Container escapes are significantly mitigated -- even if a process escapes the container, it runs as an unprivileged user on the host
- File ownership on host-mounted volumes maps to the unprivileged UID range
- Not all workloads are compatible -- some require true host UID 0 (e.g., certain CNI plugins, device plugins)

**Requirements**:
- Container runtime must support user namespaces (containerd 2.0+, CRI-O 1.30+)
- Linux kernel 6.3+ recommended
- Host must have sufficient subordinate UID/GID ranges (`/etc/subuid`, `/etc/subgid`)

### In-Place Pod Vertical Resize -- Beta

Allows changing container CPU and memory resources without restarting the pod. Reduces VPA's need to evict and recreate pods.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: app
    image: myapp:v2.0
    resources:
      requests:
        cpu: "250m"
        memory: "256Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
    resizePolicy:
    - resourceName: cpu
      restartPolicy: NotRequired    # resize CPU without restart
    - resourceName: memory
      restartPolicy: RestartContainer  # memory resize requires restart
```

**How it works**:
- Patch the pod's container resources: `kubectl patch pod myapp --subresource resize -p '{"spec":{"containers":[{"name":"app","resources":{"requests":{"cpu":"500m"}}}]}}'`
- CPU resize is typically non-disruptive (cgroup limit update)
- Memory increase may or may not require restart depending on the application and kernel capabilities
- `status.resize` field shows the resize state: Proposed, InProgress, Deferred, Infeasible

**Limitations**:
- Cannot change resource requests/limits that would change the QoS class
- Node must have sufficient resources for the resize
- Some CSI drivers and device plugins may not support resize

### Pod Certificates (KEP-4317) -- Beta (On by Default)

Kubelet can now issue serving certificates for pods, enabling mutual TLS between pods without external certificate management.

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: pod-serving-cert
spec:
  signerName: kubernetes.io/kubelet-serving
  usages:
  - digital signature
  - server auth
```

Pods can request short-lived certificates automatically, with kubelet handling issuance and rotation.

### Dynamic Resource Allocation (DRA) Enhancements

DRA continues to mature for GPU, FPGA, and specialized hardware scheduling:

- **Consumable capacity**: track how much of a device's capacity has been allocated
- **Partitionable devices**: split GPUs into smaller units (MIG-like partitioning)
- **Device taints**: mark devices as unhealthy or reserved, preventing scheduling

```yaml
apiVersion: resource.k8s.io/v1alpha3
kind: ResourceClaim
metadata:
  name: gpu-claim
spec:
  devices:
    requests:
    - name: gpu
      deviceClassName: gpu.nvidia.com
      count: 1
```

### cgroup v1 Deprecation

Kubernetes 1.35 begins preparing to retire cgroup v1 support:
- Warning logs emitted when running on cgroup v1 hosts
- cgroup v2 is now the expected default for all distributions
- Plan to remove cgroup v1 support in a future release (likely 1.38 or 1.39)

**Action required**: verify your nodes use cgroup v2 (`stat -fc %T /sys/fs/cgroup` should show `cgroup2fs`). Migrate cgroup v1 nodes before support is removed.

### KYAML -- Beta (On by Default)

KYAML is the new YAML parser for kubectl, replacing the legacy go-yaml v2 parser. It provides:
- Stricter YAML compliance
- Better error messages for malformed manifests
- Consistent parsing behavior across all kubectl commands

**Potential impact**: manifests that relied on non-standard YAML behavior (duplicate keys, certain edge cases) may now fail validation. Test existing manifests with `kubectl apply --dry-run=server`.

## Graduations to GA (17 total)

Notable GA graduations include:
- Multiple improvements to Job and CronJob controllers
- Scheduler improvements for topology-aware scheduling
- API server efficiency improvements

## Deprecations and Removals

- cgroup v1 deprecated (warnings emitted, removal planned for future release)
- Continued push to remove in-tree cloud providers
- Legacy kube-proxy iptables behaviors flagged for future removal in favor of nftables

## Upgrade Notes

When upgrading to 1.35:
1. **cgroup v2**: verify all nodes use cgroup v2. If on cgroup v1, plan migration.
2. **User namespaces**: enabled by default. Test workloads that mount host paths or run privileged containers.
3. **KYAML**: run `kubectl apply --dry-run=server` against all manifests to catch YAML parsing changes.
4. **In-place resize**: if using VPA, test interaction with the new resize capability.
5. **Pod certificates**: review kubelet certificate signing configurations if you have custom PKI.

## Version Context

- **Previous**: 1.34 (Of Wind & Will) -- sidecar containers GA, VolumeAttributesClass GA
- **Next**: 1.36 (expected April 2026) -- Gateway API improvements, further DRA maturation
