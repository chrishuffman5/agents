# Container and Kubernetes Security Concepts Reference

## Container Security Model

### Containers vs. VMs: Security Implications

Containers share the host OS kernel — unlike VMs which have hardware-level isolation. This has fundamental security implications:

**Shared kernel risks:**
- A container running as root can potentially exploit kernel vulnerabilities to escape to the host
- Kernel syscalls from all containers are processed by the same kernel
- Container isolation relies on kernel namespaces and cgroups — not hardware isolation

**Namespaces (isolation mechanisms):**
| Namespace | Isolates |
|---|---|
| `pid` | Process IDs — containers see only their own processes |
| `net` | Network interfaces, routing tables, firewall rules |
| `mnt` | Filesystem mounts |
| `uts` | Hostname and domain name |
| `ipc` | IPC resources (System V IPC, POSIX message queues) |
| `user` | User and group IDs (user namespace — allows rootless containers) |
| `cgroup` | cgroup hierarchies |

**cgroups (resource control):**
- Limit CPU, memory, block I/O, and network I/O per container
- Prevent resource exhaustion attacks (DoS from one container starving others)

### Container Security Layers

Defense in depth for containers requires controls at every layer:

```
┌─────────────────────────────────────────────────────┐
│ Supply Chain (SLSA, Sigstore, SBOM)                 │ ← Source code integrity
├─────────────────────────────────────────────────────┤
│ Build (Dockerfile security, multi-stage builds)     │ ← Image construction
├─────────────────────────────────────────────────────┤
│ Image Scanning (CVEs, secrets, misconfigs)          │ ← Pre-registry security gate
├─────────────────────────────────────────────────────┤
│ Registry (authentication, content trust, signing)   │ ← Distribution security
├─────────────────────────────────────────────────────┤
│ Admission Control (Gatekeeper/Kyverno/PSS)          │ ← Deployment-time gate
├─────────────────────────────────────────────────────┤
│ Runtime (seccomp, AppArmor, Falco, EDR)             │ ← Execution-time protection
├─────────────────────────────────────────────────────┤
│ Network (Network Policies, mTLS, service mesh)      │ ← East-west traffic
├─────────────────────────────────────────────────────┤
│ Infrastructure (RBAC, etcd encryption, API server)  │ ← Kubernetes control plane
└─────────────────────────────────────────────────────┘
```

## Image Scanning Deep Dive

### CVE Detection Methodology

Image scanners work by:
1. Extracting image layers (OCI image format: ordered tar archives)
2. Mounting/reading each layer's filesystem
3. Reading package manager databases:
   - Debian/Ubuntu: `/var/lib/dpkg/status`
   - RedHat/CentOS: `/var/lib/rpm/Packages`
   - Alpine: `/lib/apk/db/installed`
   - Language packages: `/usr/local/lib/python3.x/dist-packages/`, `node_modules/.package-lock.json`, `pom.xml`, etc.
4. Matching package names and versions against CVE databases
5. Determining fix availability

### Vulnerability Prioritization

Not all CVEs are equal. Priority ordering:

1. **CISA KEV (Known Exploited Vulnerabilities)** — actively exploited in the wild; fix immediately regardless of CVSS
2. **CVSS 9.0+ with public exploit** — high severity + weaponized; fix within 24-48 hours
3. **CVSS 7.0-8.9 with public exploit** — fix within days
4. **CVSS 9.0+ without exploit** — fix within 1-2 weeks
5. **CVSS 7.0-8.9 without exploit** — fix within 30 days (typical SLA)
6. **CVSS < 7.0** — fix in regular patching cycles

**Fix availability matters:**
If no fix is available, the severity is unchanged but the remediation changes — document acceptance, apply virtual patching (Aqua vShield, Prisma WAAS), consider mitigating controls.

**"In use" context:**
Advanced scanners (Sysdig, Wiz) can correlate CVEs with runtime data to determine if the vulnerable package/function is actually loaded and called at runtime. A CVE in a library that is never loaded at runtime poses less immediate risk than one in a library called on every request.

### SBOM (Software Bill of Materials)

An SBOM is a machine-readable inventory of all components in a software artifact:

**Formats:**
- **SPDX (Linux Foundation):** XML, JSON, TV, RDF formats
- **CycloneDX (OWASP):** XML and JSON formats — more security-focused
- **SWID (NIST):** ISO standard, less commonly used for containers

**SBOM use cases:**
- Know exactly what's in every container image
- Quickly determine blast radius when a new CVE is disclosed (query: which images contain log4j?)
- Regulatory compliance (US Executive Order 14028 requires SBOMs for federal software)
- License compliance tracking

```bash
# Generate CycloneDX SBOM with Trivy
trivy image --format cyclonedx --output sbom.cyclonedx.json nginx:latest

# Generate SPDX with Syft
syft nginx:latest -o spdx-json > nginx-sbom.spdx.json

# Query SBOM for specific package
cat sbom.cyclonedx.json | jq '.components[] | select(.name == "log4j-core")'
```

## Admission Control Deep Dive

### Admission Controller Architecture

The Kubernetes API request lifecycle:
```
kubectl apply -f pod.yaml
  ↓
API Server authenticates request
  ↓
API Server authorizes request (RBAC)
  ↓
Mutating Admission Webhooks (modify the object)
  │  └── OPA Gatekeeper mutation
  │  └── Kyverno mutation
  │  └── Istio sidecar injection
  ↓
Object schema validation
  ↓
Validating Admission Webhooks (approve or reject)
  │  └── OPA Gatekeeper validation
  │  └── Kyverno validation
  │  └── Pod Security Admission
  ↓
Object persisted to etcd
```

**Admission webhook timeout:**
If the admission webhook is unavailable, behavior depends on `failurePolicy`:
- `failurePolicy: Fail` — API request is rejected (safe, but can block deployments if webhook is down)
- `failurePolicy: Ignore` — API request is allowed (less safe)
- Best practice: use `Ignore` for non-critical webhooks; `Fail` for security-enforcing webhooks + ensure high availability

### Pod Security Standards Reference

**Privileged profile** (no restrictions):
```yaml
# No restrictions — allows any pod configuration
# Only appropriate for system namespaces (kube-system) with strict access control
```

**Baseline profile** (prevents known privilege escalations):
Forbidden:
- `hostProcess: true` (Windows only)
- `privileged: true` in securityContext
- `hostPID: true` or `hostIPC: true` or `hostNetwork: true`
- Hostpath volumes (with specific exceptions)
- Dangerous capabilities: `NET_ADMIN`, `SYS_ADMIN`, `SYS_PTRACE`, etc.
- AppArmor annotation overrides (setting to `unconfined`)
- Seccomp: `Unconfined` profile

**Restricted profile** (heavily hardened):
All Baseline restrictions plus:
- Must run as non-root (`runAsNonRoot: true`)
- Must not allow privilege escalation (`allowPrivilegeEscalation: false`)
- Seccomp: must be `RuntimeDefault` or `Localhost` (not `Unconfined`)
- Drop ALL capabilities; add back only `NET_BIND_SERVICE` if needed
- No read-only root filesystem requirement in Restricted (but recommended as additional hardening)

```yaml
# Example: Restricted-compliant pod security context
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: myapp:v1.0.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
    volumeMounts:
    - name: tmp
      mountPath: /tmp       # writable tmp volume since root fs is read-only
  volumes:
  - name: tmp
    emptyDir: {}
```

## Kubernetes RBAC Security Deep Dive

### Dangerous RBAC Permissions

Some permissions are effectively admin-equivalent even if not explicitly granting `cluster-admin`:

| Permission | Why Dangerous |
|---|---|
| `verbs: ["*"]` on any resource | Full control of that resource type |
| `secrets: get/list` in kube-system | Can read service account tokens, TLS certs |
| `pods/exec` | Execute arbitrary commands in any pod |
| `pods/attach` | Attach to running pod processes |
| `clusterroles: escalate, bind` | Grant yourself or others any permission |
| `nodes: proxy` | Proxy to kubelet API — can exec into any pod |
| `validatingwebhookconfigurations: *` | Disable admission webhooks |
| `mutatingwebhookconfigurations: *` | Hijack all deployments |
| `networkpolicies: *` | Remove network isolation |

### Service Account Token Projection

Modern Kubernetes (1.20+) uses projected service account tokens:
- Short-lived (default 1 hour)
- Audience-bound (only usable by the intended audience)
- Automatically rotated by kubelet

**Legacy token issue:**
Kubernetes < 1.24 auto-creates long-lived non-expiring service account secrets. If these exist:
```bash
# Find long-lived service account tokens (pre-1.24 style)
kubectl get secrets --all-namespaces -o json | \
  jq '.items[] | select(.type == "kubernetes.io/service-account-token") | 
    {namespace: .metadata.namespace, name: .metadata.name, sa: .metadata.annotations["kubernetes.io/service-account.name"]}'
```

**Cloud-specific identity (preferred over SA tokens for cloud API access):**
- AWS: IRSA (IAM Roles for Service Accounts) — OIDC federation
- Azure: Azure AD Workload Identity — OIDC federation
- GCP: Workload Identity — GSA ↔ KSA binding

```yaml
# AWS IRSA: annotate service account with IAM role
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: my-namespace
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-app-role
```

### Kubernetes API Server Security

**Authentication methods:**
- X.509 client certificates (for admin access, node bootstrapping)
- Bearer tokens (service account tokens, OIDC tokens)
- OIDC (integrate with corporate IdP: Dex, Okta, Azure AD)
- Webhook token authentication
- Proxy authentication

**Authorization modes:**
- RBAC (standard, should always be enabled)
- Node (kubelet authorization — should always be enabled)
- ABAC (older, not recommended)
- Webhook (custom authorization)

**API server hardening:**
```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --anonymous-auth=false           # disable anonymous access
    - --audit-log-path=/var/log/audit.log
    - --audit-log-maxage=30
    - --audit-log-maxbackup=10
    - --audit-log-maxsize=100
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
    - --enable-admission-plugins=NodeRestriction,PodSecurity
    - --encryption-provider-config=/etc/kubernetes/encryption-config.yaml  # etcd encryption
    - --tls-min-version=VersionTLS12
    - --insecure-port=0                # disable http
```

## Network Policy Deep Dive

### CNI Comparison for Network Security

| CNI | Network Policy Support | Advanced Features |
|---|---|---|
| Calico | Full K8s NetworkPolicy + extended CalicoNetworkPolicy | Host endpoint policies, BGP, WireGuard encryption |
| Cilium | Full K8s NetworkPolicy + CiliumNetworkPolicy (L7) | eBPF-based, L7 HTTP/gRPC policies, Hubble observability, WireGuard |
| Weave Net | Full K8s NetworkPolicy | Simple deployment, less feature-rich |
| Flannel | None (network policy not supported) | Simple overlay — use Calico for policy with Flannel for routing |
| AWS VPC CNI | Requires Calico for network policy | Native VPC networking; use with Calico policy engine |

### Kubernetes Network Policy Limitations

Standard Kubernetes Network Policies have important limitations:
- No DNS-based policies (can't say "allow outbound to api.github.com")
- No L7 HTTP policies (can't say "allow GET /health but not POST /admin")
- No logging of policy decisions
- Namespace-level granularity only (no cluster-level default policy)
- No egress policies to specific external IPs without knowing IP in advance

**Cilium fills these gaps:**
```yaml
# Cilium L7 HTTP policy
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-health-check-only
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: monitoring
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/health"     # only allow GET /health, not any other path

---
# Cilium DNS-based egress policy
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
spec:
  endpointSelector:
    matchLabels:
      app: my-app
  egress:
  - toFQDNs:
    - matchName: "api.github.com"
  - toPorts:
    - ports:
      - port: "443"
```

## Service Mesh Security (mTLS)

### mTLS in Service Meshes

A service mesh like Istio or Linkerd provides mutual TLS (mTLS) between all services automatically:

**Without mTLS:**
- Service-to-service traffic inside the cluster is plaintext
- Any pod in the cluster can eavesdrop on traffic (if network policy allows)
- No cryptographic identity verification between services

**With mTLS (Istio strict mode):**
- Every sidecar proxy has a cryptographic identity (SPIFFE SVID X.509 cert)
- All service-to-service communication is TLS-encrypted
- Services can verify the identity of the caller
- Non-mTLS traffic is rejected

```yaml
# Istio: Enable strict mTLS for entire mesh
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system   # applies to entire mesh
spec:
  mtls:
    mode: STRICT

---
# Istio AuthorizationPolicy: service-level access control
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend-only
  namespace: my-app
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/my-app/sa/frontend"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/v1/*"]
```

### SPIFFE/SPIRE

SPIFFE (Secure Production Identity Framework for Everyone) and SPIRE (SPIFFE Runtime Environment) provide workload identity:

- SPIFFE SVIDs (SPIFFE Verifiable Identity Documents) — X.509 certificates with a SPIFFE URI identity
- SPIRE issues SVIDs to workloads based on node and workload attestation
- Used by Istio, Envoy, Consul, and other service meshes as the identity foundation
- Enables cross-cluster and cross-cloud identity without static credentials

## Container Escape Techniques and Mitigations

Understanding container escape vectors is essential for defensive configuration:

### Common Container Escape Vectors

**1. Privileged container (`--privileged`)**
- Grants all capabilities + access to host devices
- Attacker can mount host filesystem: `mount /dev/sda1 /mnt`
- Mitigation: Never use `--privileged`; use specific capabilities instead

**2. Mounted Docker socket (`/var/run/docker.sock`)**
- Attacker can create a new privileged container and mount host filesystem
- Mitigation: Never mount Docker socket into containers

**3. Host PID namespace (`hostPID: true`)**
- Container sees all host processes
- Can send signals to host processes, ptrace host processes
- Mitigation: `hostPID: false` (default); Pod Security Standards block this

**4. Capabilities abuse**
- `CAP_SYS_ADMIN` — most powerful capability; equivalent to root in many scenarios
- `CAP_NET_ADMIN` — can reconfigure network interfaces
- `CAP_SYS_PTRACE` — can ptrace any process
- Mitigation: `capabilities.drop: ["ALL"]`; add back only what's needed

**5. Writable host path volumes**
```yaml
# Dangerous: mounting host path
volumes:
- name: host-etc
  hostPath:
    path: /etc    # attacker can modify /etc/crontab for persistence
```
Mitigation: Avoid hostPath volumes; if needed, mount as readOnly

**6. Kernel exploit from container**
- Container shares kernel — kernel CVE exploitable from container context
- Mitigation: Seccomp profiles reduce available syscall surface; keep kernel patched; gVisor or Kata for stronger isolation

### Sandbox Runtimes

For high-risk workloads, use stronger isolation:

**gVisor (runsc):**
- Google's container sandbox
- Intercepts syscalls in a user-space kernel (Sentry)
- Provides stronger isolation at cost of some compatibility and performance

**Kata Containers:**
- Runs each container (or pod) in a lightweight VM
- Hardware-level isolation like VMs with container ergonomics
- Slower startup but maximum isolation
- Supported on most managed Kubernetes platforms

```yaml
# Use Kata Containers for a specific pod
spec:
  runtimeClassName: kata-containers
  containers:
  - name: untrusted-workload
    image: untrusted-image:latest
```

## CIS Kubernetes Benchmark

The CIS Kubernetes Benchmark provides configuration hardening guidance organized by component:

**Control plane components:**
- API server: disable anonymous auth, enable audit logging, enable RBAC, encrypt etcd
- etcd: TLS client authentication, data encryption
- Controller Manager: disable profiling, use least-privilege service accounts
- Scheduler: disable profiling, bind to localhost

**Worker node components:**
- Kubelet: disable anonymous auth, enable node restriction, use certificate rotation
- Kubernetes file permissions (various config files should not be world-readable)

**RBAC and service accounts:**
- Don't use default service account (disable token auto-mounting for default SA)
- Apply minimal RBAC
- Don't bind cluster-admin to service accounts

**Network policies:**
- Apply network policies to all namespaces
- Apply default-deny policy

**Pod security:**
- Apply Pod Security Standards (Restricted profile where possible)
- Use resource limits

**Tools to audit against CIS benchmark:**
- `kube-bench` (open source, Aqua) — runs CIS benchmark checks on the node
- `kube-hunter` (open source, Aqua) — active security testing of Kubernetes cluster
- Defender for Cloud Kubernetes CIS checks
- Sysdig Secure KSPM
- Aqua KSPM
