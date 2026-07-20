# Aqua Security Platform Architecture Reference

## Platform Component Architecture

```
Developer Workstation / CI/CD Pipeline
  ├── Trivy (OSS) — local scanning
  ├── Aqua CLI (aquasec) — CI/CD pipeline scanning
  └── IDE plugins (VS Code, JetBrains)
         ↓
Aqua Console (SaaS or self-hosted)
  ├── Image Assurance Policy engine
  ├── Vulnerability database (aggregated from NVD, vendor advisories)
  ├── KSPM engine
  ├── DTA orchestration
  ├── Compliance reporting
  └── API (REST + GraphQL)
         ↓
Production Kubernetes Cluster
  ├── Aqua Enforcer (DaemonSet)
  ├── Aqua Kubernetes Admission Controller (optional webhook)
  └── Aqua Scanner (optional in-cluster image scanning)
         ↓
Aqua Gateway (optional — for air-gapped/restricted environments)
  └── Proxies encrypted traffic between Enforcer and Console
```

## Aqua Console Deployment Options

### SaaS (Aqua Cloud)

- Aqua hosts and manages the Console
- Customers connect their environments via outbound-only Enforcer connections
- Vulnerability database managed by Aqua
- Multi-region availability (US, EU, APAC)
- SOC 2 Type II certified

### Self-Hosted (On Kubernetes)

For air-gapped environments or strict data residency requirements:
```yaml
# Aqua Console components deployed on customer Kubernetes
Deployments:
  - aqua-server (main console application)
  - aqua-db (PostgreSQL — can use external managed DB)
  - aqua-gateway (optional relay component)

Services:
  - aqua-web (port 8080/8443 — console UI and API)
  - aqua-gateway (port 3622 — Enforcer communication)
```

**Self-hosted requirements:**
- PostgreSQL 12+ (can use AWS RDS, Azure Database, or in-cluster)
- Persistent storage (PVC) for database
- Load balancer for Console access
- Aqua Gateway for Enforcer connectivity if network-restricted

## Aqua Enforcer Architecture

### Enforcer Types

| Enforcer Type | Deployment | Use Case |
|---|---|---|
| DaemonSet Enforcer | Kubernetes DaemonSet | Standard K8s clusters |
| Nano Enforcer | Kubernetes DaemonSet (lightweight) | Resource-constrained environments |
| VM Enforcer | System daemon on VM | Standalone VMs, EC2 instances |
| Host Enforcer | System daemon on bare metal | Physical servers |
| MicroEnforcer | Embedded in container image | Fargate, App Runner, managed container services |

### DaemonSet Enforcer Implementation

The DaemonSet Enforcer runs with elevated privileges to access host-level telemetry:

**Required volumes (host paths):**
```yaml
volumes:
- name: var-run
  hostPath:
    path: /var/run          # Docker/containerd socket
- name: dev
  hostPath:
    path: /dev              # Device access for eBPF
- name: sys
  hostPath:
    path: /sys
- name: proc
  hostPath:
    path: /proc             # Process information
- name: etc
  hostPath:
    path: /etc              # Host OS configuration
    readOnly: true
- name: root-vol
  hostPath:
    path: /                 # Host root filesystem (for drift detection)
    readOnly: true
- name: aquasec-db
  hostPath:
    path: /var/lib/aquasec  # Local policy cache + behavioral data
```

**Container runtime interfaces:**
- **containerd:** Uses containerd CRI interface + shim
- **CRI-O:** Uses CRI interface
- **Docker (legacy):** Uses Docker daemon socket

**Kernel monitoring mechanisms:**
1. **eBPF (preferred, kernel 4.14+):**
   - No kernel module required
   - Low overhead
   - Captures process exec, open, connect, accept syscalls
   - BPF programs compiled at Enforcer startup for the running kernel

2. **Kernel module (fallback for older kernels):**
   - Compiled for the running kernel version
   - Requires kernel headers at compile time
   - Higher overhead than eBPF but works on older kernels (3.x+)

3. **ptrace (fallback):**
   - Used in environments where neither eBPF nor kernel module can be loaded
   - Highest overhead; not recommended for production

### Enforcer to Console Communication

```
Aqua Enforcer (in customer cluster)
  └── Outbound TCP 443 (or port 3622 for Gateway)
        ↓ [TLS 1.2+, mutual TLS with cert-pinning]
Aqua Console / Gateway
  └── Enforcer authentication via:
        - One-time registration token (first connection)
        - Generated client certificate (subsequent connections)
  └── Heartbeat: every 15 seconds
  └── Event streaming: real-time runtime events
  └── Policy sync: console pushes updated policies to Enforcer
  └── Vulnerability DB sync: Enforcer pulls updated CVE data
```

**Offline mode:**
If the Enforcer loses connectivity to the Console:
- Last-known policies remain in effect (policy cached locally at `/var/lib/aquasec`)
- Events buffered locally and sent when connectivity resumes
- Configurable grace period before failsafe mode engages

### MicroEnforcer (For Fargate and Managed Containers)

For environments where DaemonSet deployment is not possible (AWS Fargate, Azure Container Instances, GCP Cloud Run):

**Embedding the MicroEnforcer:**
```dockerfile
# Add MicroEnforcer to container image at build time
FROM myapp:base AS app-base

# Aqua's tooling copies MicroEnforcer binary into the image
COPY --from=registry.aquasec.com/microenforcer:2024.x /microenforcer /aquasec/microenforcer

# MicroEnforcer becomes the container entrypoint and wraps the original process
ENTRYPOINT ["/aquasec/microenforcer"]
CMD ["python", "app.py"]
```

**MicroEnforcer capabilities (subset vs. DaemonSet):**
- Process monitoring (within container — no host visibility)
- Network monitoring (outbound connections)
- File system monitoring (within container filesystem)
- Runtime policy enforcement
- No drift detection (requires host-level access)
- No kernel-level syscall monitoring

## vShield Implementation Details

### How Virtual Patching Is Applied

vShield rules are distributed as runtime policy updates to all Enforcers:

```
CVE Disclosed (e.g., Log4Shell CVE-2021-44228)
  ↓
Aqua Research Team analyzes exploitation technique
  ↓
vShield rule authored:
  - Condition: Process executes JNDI lookup pattern (Log4j exploitation indicator)
  - Action: Block and alert
  ↓
Rule pushed to Aqua Console vulnerability database
  ↓
All Enforcers pull updated policy within minutes
  ↓
Enforcers apply rule at runtime:
  - Monitor JVM-based containers for JNDI lookup syscall patterns
  - Block matching activity before exploitation can succeed
```

**vShield rule types:**
- **Syscall-level rules:** Block specific syscall sequences associated with exploitation
- **Process execution rules:** Block spawning of specific processes known to be part of exploitation chain
- **Network rules:** Block outbound connections to exploitation infrastructure patterns
- **File system rules:** Block creation of specific files associated with exploitation

**vShield database maintenance:**
- Aqua maintains a database of vShield rules mapped to CVEs
- Rules automatically activated when a CVE affecting a running image is detected
- Rules automatically deactivated when the CVE is patched (image rebuilt with fixed version)

## Dynamic Threat Analysis (DTA) Architecture

### Sandbox Architecture

```
Image to Analyze
  ↓
DTA Sandbox Environment (Aqua-managed isolated cloud infrastructure)
  ├── Isolated network (no external connectivity by default)
  ├── Full kernel-level instrumentation
  ├── Synthetic "bait" environment (fake credentials, fake data stores)
  └── Behavioral monitoring agents
        ↓
Container runs for N minutes (configurable)
  ↓
Behavioral analysis engine:
  ├── Process activity graph
  ├── Network activity log
  ├── File system change log
  ├── Syscall trace
  └── Bait access detection (accessed fake credentials = malicious indicator)
        ↓
Threat report with severity score and IOCs
```

**DTA bait/deception:**
The sandbox environment includes intentionally fake but realistic-looking:
- AWS credentials (fake access key/secret)
- Database connection strings
- SSH private keys
- Cloud metadata service (IMDS endpoint)

If the container image accesses these "bait" resources, it's a strong indicator of malicious intent (credential theft, credential scanning behavior).

**DTA trigger modes:**
1. **Manual:** Analyst submits specific image for DTA
2. **Policy-triggered:** Images matching certain criteria (unsigned, from public registry, failed static scan) automatically submitted
3. **Threshold-triggered:** Images with specific risk score automatically submitted
4. **All new images:** DTA run on every new image (high coverage, higher cost)

## Aqua Kubernetes Admission Controller

### Webhook Configuration

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: aqua-image-scanner
webhooks:
- name: imagecheck.aquasec.com
  clientConfig:
    service:
      name: aqua-webhook
      namespace: aqua
      path: /scan/k8s/webhook
    caBundle: <base64-encoded-CA>
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE"]
    resources: ["pods"]
  namespaceSelector:
    matchExpressions:
    - key: aqua-webhook
      operator: In
      values: ["enabled"]   # Only enforce in labeled namespaces
  failurePolicy: Fail      # Block pod if webhook unreachable
  admissionReviewVersions: ["v1"]
  sideEffects: None
```

**Decision logic:**
1. Pod creation request arrives at API server
2. Webhook sends request to Aqua Console with image name and tag
3. Console checks if image has been scanned and policy result:
   - Scan result cached → return immediately (fast path)
   - No scan result → trigger scan and wait (or timeout + failOpen)
4. Console returns allow/deny based on Image Assurance Policy
5. Pod is created or rejected based on webhook response

**Namespace-based scoping:**
Best practice: enable admission webhook enforcement in production namespaces, monitor-only in dev:
```bash
# Enable enforcement for production namespace
kubectl label namespace production aqua-webhook=enabled

# Enable monitoring only for staging (admission webhook logs but doesn't block)
kubectl label namespace staging aqua-webhook=monitor
```

## Vulnerability Database

Aqua maintains an aggregated vulnerability database:

**Sources:**
- NVD (National Vulnerability Database)
- OS vendor advisories: Ubuntu USN, RedHat RHSA, Debian DSA, Alpine SecDB, Amazon Linux ALAS
- Language-specific: npm advisory, PyPI advisory, RubyGems, Maven, NuGet, Go, Cargo, Cocoapods
- GitHub Security Advisories
- Vendor-specific (e.g., Chainguard, Wolfi advisories for their images)

**Aqua enrichment beyond NVD:**
- EPSS scores (Exploit Prediction Scoring System)
- Exploit availability (Metasploit, ExploitDB, GitHub PoCs)
- CISA KEV membership
- Aqua's own research team vulnerability intelligence
- vShield coverage flag (is there a virtual patch available?)

**Update frequency:**
- Database refreshed every 2-4 hours
- Critical CVEs (especially CISA KEV additions) pushed with higher urgency

## API Reference

### Aqua REST API (key endpoints)

```bash
# Authenticate
curl -X POST "https://aqua.company.com/api/v1/login" \
  -d '{"id": "user@company.com", "password": "password"}'

# Get image scan results
curl -X GET "https://aqua.company.com/api/v2/images/{registry}/{image}/{tag}/scan_results" \
  -H "Authorization: Bearer $TOKEN"

# List vulnerabilities for an image
curl -X GET "https://aqua.company.com/api/v2/images/{registry}/{image}/{tag}/vulnerabilities" \
  -H "Authorization: Bearer $TOKEN" \
  -G -d "severity=critical,high"

# List runtime audit events
curl -X GET "https://aqua.company.com/api/v2/runtime/events" \
  -H "Authorization: Bearer $TOKEN" \
  -G -d "type=exec&limit=100"

# Get KSPM assessment results
curl -X GET "https://aqua.company.com/api/v2/risks/bench/kubernetes/json/summary" \
  -H "Authorization: Bearer $TOKEN"
```
