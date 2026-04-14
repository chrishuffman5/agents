# Sysdig Platform Architecture Reference

## Agent Architecture

### Sysdig Agent Components

The Sysdig agent is a DaemonSet deployed on each Kubernetes node. It consists of multiple sub-components:

```
Kubernetes Node
  ├── sysdig-agent container (main monitoring agent)
  │     ├── Kernel-level collector (eBPF or kernel module)
  │     ├── Event processor and filter
  │     ├── Falco rules engine
  │     └── Metrics collector (for Sysdig Monitor)
  │
  ├── node-analyzer container (vulnerability scanning)
  │     ├── Image scanner (scans images loaded on this node)
  │     ├── Benchmark runner (CIS checks on the node)
  │     └── Host scanner (OS package scanning on the node)
  │
  └── rapid-response container (optional, live terminal)
        └── Secure shell into containers for investigation
```

### eBPF Data Collection Pipeline

```
Linux Kernel
  └── eBPF hooks (kprobes, tracepoints, LSM)
        ├── sys_enter / sys_exit (syscall entry/exit)
        │     └── open, read, write, execve, connect, accept, clone, etc.
        ├── sched_process_exec (process execution events)
        └── net events (TCP connect, accept, close)
              ↓
eBPF Ring Buffer (shared memory between kernel and userspace)
              ↓
Sysdig Agent (userspace)
  └── Event consumer reads ring buffer
  └── Event filtering (drop noisy/irrelevant events)
  └── Event enrichment:
        ├── Container metadata (which container ID? which pod? which namespace?)
        ├── Process metadata (full command line, user, parent process)
        ├── Kubernetes metadata (labels, deployment, service account)
        └── Cloud metadata (instance ID, region, cloud account)
              ↓
Falco Rules Engine
  └── Evaluates each event against loaded rules
  └── Alert generated on rule match
              ↓
Sysdig Agent Forwarder
  └── Batches and compresses events
  └── TLS transmission to Sysdig backend (SaaS or on-prem collector)
```

### Kernel Monitoring Mode Selection

**Universal eBPF (recommended for Kubernetes 1.20+, kernel 5.8+):**
- Uses CO-RE (Compile Once, Run Everywhere) with BTF (BPF Type Format)
- Single eBPF program compiled once by Sysdig; runs on any compatible kernel
- No kernel headers needed on the node
- Lowest overhead; most portable
- Node requirement: kernel 5.8+ with BTF enabled

**Legacy eBPF (kernel 4.14-5.7):**
- eBPF but without CO-RE; must be compiled per kernel version
- Sysdig maintains pre-compiled eBPF probes for common kernel versions
- If no pre-compiled probe: Sysdig downloads kernel headers and compiles at agent startup

**Kernel module (fallback):**
- Compiled `.ko` kernel module
- Works on older kernels (3.x+)
- Requires `CONFIG_KALLSYMS=y` in kernel config
- At startup: checks if pre-compiled module available; if not, downloads and compiles
- Higher overhead than eBPF; harder to maintain in automated environments

**Checking which mode is active:**
```bash
# View Sysdig agent logs
kubectl logs -n sysdig-agent ds/sysdig-agent -c sysdig | grep -i "ebpf\|driver\|probe"

# Expected output for eBPF:
# INFO: loading eBPF driver...
# INFO: eBPF probe successfully loaded
```

## Node Analyzer Architecture

The Node Analyzer is a separate container in the Sysdig DaemonSet that handles vulnerability scanning and benchmark assessment on each node:

```
Node Analyzer Pod
  ├── Image Analyzer
  │     ├── Detects new images loaded on this node (from containerd/docker)
  │     ├── Pulls image manifest and layers
  │     ├── Extracts package lists from each layer
  │     ├── Sends package manifest to Sysdig backend for CVE matching
  │     └── Sends "in use" data: which packages are actually loaded at runtime
  │
  ├── Host Analyzer
  │     ├── Scans host OS packages (DEB, RPM on the K8s node OS)
  │     ├── Reports vulnerabilities in the node's OS
  │     └── Used for Kubernetes node hardening recommendations
  │
  ├── Benchmark Runner
  │     ├── Runs CIS Benchmark checks on this node
  │     ├── Results sent to Sysdig backend for compliance dashboard
  │     └── Checks: kubelet configuration, file permissions, network settings
  │
  └── Runtime Scanner (eBPF-based "in use" detection)
        ├── Tracks which shared libraries are loaded into each process
        ├── Tracks class/module loading in JVM, Python, Node.js runtimes
        └── Reports runtime package usage to Sysdig backend
```

**"In Use" data flow:**
```
Container starts
  ↓
Runtime Scanner observes:
  - dlopen() calls (shared library loading)
  - Java ClassLoader activity
  - Python import statements
  - Node.js require() calls
  ↓
Package-to-library mapping:
  "log4j-core-2.14.1.jar is loaded" → CVE-2021-44228 package is IN USE
  "openssl 1.1.1k" has never been dlopen'd → CVE-XXXX package is NOT IN USE
  ↓
Sysdig vulnerability dashboard:
  Vulnerability A: CVSS 9.8, IN USE = true  → Priority: Critical
  Vulnerability B: CVSS 9.8, IN USE = false → Priority: Lower
```

## Sysdig Backend Pipeline

```
Sysdig Agent (customer cluster)
  └── Encrypted event stream (Sysdig protocol over TCP/443)
        ↓
Sysdig Ingestion Layer (SaaS)
  └── Event validation and schema enforcement
  └── Tenant routing (multi-tenant isolation)
        ↓
Event Processing Pipeline
  ├── Falco rule evaluation at scale (centralized rule engine + edge agent evaluation)
  ├── ML anomaly detection (behavioral baseline deviation)
  ├── CDR correlation engine (workload + K8s audit + cloud audit correlation)
  ├── Insights engine (automated threat detection across event streams)
  └── Metric aggregation pipeline (for Sysdig Monitor)
        ↓
Storage Layer
  ├── Hot storage: recent events (last 7-30 days, queryable in UI)
  ├── Cold storage: long-term event archive (for compliance and investigation)
  └── Time-series database: metrics (for Sysdig Monitor)
        ↓
Sysdig Secure UI / API
  ├── Threat detection alerts
  ├── Vulnerability findings with "in use" context
  ├── Compliance posture
  ├── CDR incidents
  └── Sysdig Monitor dashboards
```

## Kubernetes Audit Log Integration

### How K8s Audit Logs Reach Sysdig

**Option 1: Sysdig Audit Sink (K8s Dynamic Audit)**
```yaml
# Configure Kubernetes API server to send audit events to Sysdig webhook
apiVersion: v1
kind: Config
# kube-apiserver --audit-webhook-config-file=/etc/kubernetes/audit-webhook.yaml
clusters:
- cluster:
    server: https://us2.app.sysdig.com/api/k8s/audit
    certificate-authority-data: <Sysdig CA cert>
  name: sysdig
contexts:
- context:
    cluster: sysdig
    user: sysdig
  name: sysdig
current-context: sysdig
users:
- name: sysdig
  user:
    token: <Sysdig API token>
```

**Option 2: Sysdig Agent reads audit log file**
For environments where webhook configuration is not possible:
- Configure K8s API server to write audit logs to a file
- Sysdig agent reads the audit log file from the control plane node

**Option 3: Managed K8s (EKS, AKS, GKE)**
- AWS EKS: enable control plane logging to CloudWatch; Sysdig reads from CloudWatch
- Azure AKS: send diagnostic logs to Azure Monitor; Sysdig reads via Event Hub
- GCP GKE: GKE Audit Logs to Cloud Logging; Sysdig reads via Pub/Sub

### Kubernetes Audit Rules (Examples)

Sysdig ships Falco rules that operate on Kubernetes audit log data:

```yaml
- rule: K8s Namespace Created
  desc: Detect any new Kubernetes namespace creation
  condition: >
    kaudit and ka.verb = create and ka.target.resource = namespaces
    and not ka.user.name in (known_namespace_creators)
  output: >
    Namespace created (user=%ka.user.name ns=%ka.target.name)
  priority: INFO
  source: k8s_audit

- rule: Attach to cluster-admin Role
  desc: Detect any attempt to attach a user/group/SA to cluster-admin
  condition: >
    kaudit and ka.verb in (create,update)
    and ka.target.resource in (clusterrolebindings, rolebindings)
    and ka.req.binding.role = cluster-admin
    and not ka.user.name in (allowed_k8s_users)
  output: >
    Attached to cluster-admin role (user=%ka.user.name resource=%ka.target.resource
    subject=%ka.req.binding.subjects)
  priority: WARNING
  source: k8s_audit

- rule: Create Privileged Pod
  desc: Detect creation of privileged pods
  condition: >
    kaudit and ka.verb = create and ka.target.resource = pods
    and ka.req.pod.containers.privileged = true
    and not ka.user.name in (allowed_privileged_users)
  output: >
    Privileged pod created (user=%ka.user.name pod=%ka.target.name
    ns=%ka.target.namespace image=%ka.req.container.image)
  priority: WARNING
  source: k8s_audit
```

## CDR Correlation Architecture

Sysdig CDR is powered by a correlation engine that links events across multiple data sources:

```
Data Sources (ingested in real-time):
  ├── Kernel syscall events (from Sysdig agent)
  │     Context: container, pod, namespace, node, process, user
  ├── Kubernetes audit log events
  │     Context: K8s resource type, verb, user, service account, namespace
  ├── AWS CloudTrail events
  │     Context: API call, IAM identity, source IP, region, affected resource
  ├── Azure Activity Logs
  │     Context: operation, identity, subscription, resource
  └── GCP Audit Logs
        Context: method, principal, project, resource
          ↓
Sysdig CDR Correlation Engine
  ├── Entity resolution: "this container" runs on "this EC2 instance" = same entity
  ├── Timeline reconstruction: events from different sources ordered chronologically
  ├── Attack chain detection: sequence of events matching known attack patterns
  │     e.g., [container shell] + [cloud API call from same instance] = lateral movement
  └── Confidence scoring: how likely is this sequence to be malicious?
          ↓
Sysdig Insights
  ├── Automated threat scenarios (mapped to MITRE ATT&CK)
  ├── Entity timeline (complete attack story: workload → cloud → impact)
  └── Investigation workflow (built-in queries for common scenarios)
```

### Example CDR Correlation: Compromised Container

```
Timeline (Sysdig automatically correlates):

T+0:00  [K8s Audit] kubectl exec into pod "payment-api" (user: dev@company.com)
T+0:15  [Kernel] bash process spawned in container "payment-api"
T+0:23  [Kernel] curl process executing: curl http://169.254.169.254/latest/meta-data/iam/
         (IMDS credential access attempt)
T+0:25  [Kernel] AWS credentials written to /tmp/.aws_credentials
T+0:30  [CloudTrail] API call: DescribeBuckets from EC2 instance i-abc123
         (IAM user: AROAXXXXXXX — EC2 instance role)
T+00:45 [CloudTrail] API call: GetObject s3://prod-customer-data/users.csv
         from EC2 instance i-abc123

Sysdig CDR Alert:
  Title: "Credential Theft and Cloud Data Exfiltration"
  Severity: CRITICAL
  MITRE: T1552.004 (Unsecured Credentials: Cloud Instance Metadata API)
         T1530 (Data from Cloud Storage Object)
  Entities involved:
    - Pod: payment-api (namespace: production)
    - Node: ip-10-0-1-55 (i-abc123)
    - IAM Role: prod-ec2-role
    - S3 Bucket: prod-customer-data
  Evidence timeline: [all events linked]
```

## Sysdig Rapid Response (Live Terminal)

For incident investigation, Sysdig provides Rapid Response — a secure, audited terminal into running containers:

```
Security Analyst (Sysdig Console)
  └── Initiates Rapid Response session to container "payment-api"
        ↓ [authenticated via Sysdig Console RBAC]
Rapid Response Agent (in cluster)
  └── Establishes secure reverse shell to target container
  └── All commands and output logged to Sysdig (audit trail)
  └── Session time-limited (configurable max duration)
  └── Requires approval workflow (optional: 4-eyes principle)
        ↓
Security Analyst can:
  - Run forensic commands in the container context
  - Examine running processes, network connections, files
  - Collect artifacts (heap dumps, core dumps, logs)
  - NOT: modify files in the container (read-only session by default)
```

**Rapid Response RBAC:**
- Not all Sysdig users can initiate Rapid Response
- Requires explicit `rapid_response` permission in Sysdig RBAC
- All sessions fully audited (commands, output, user, timestamp)
- Optional: require manager approval before session is established

## Sysdig SaaS Regions and Data Residency

| Region | Endpoint | Data Residency |
|---|---|---|
| US East (default) | us2.app.sysdig.com | United States |
| EU | eu1.app.sysdig.com | European Union |
| AP Southeast | app.au1.sysdig.com | Australia |
| US West | us4.app.sysdig.com | United States |
| India | in1.app.sysdig.com | India |

**On-premises deployment:**
For air-gapped or strict data residency requirements, Sysdig is available as a self-hosted platform running on Kubernetes. Contact Sysdig for licensing details.

## Vulnerability Database

Sysdig maintains its own vulnerability database aggregating from:
- NVD + OS vendor advisories (same as Trivy)
- GitHub Security Advisories
- Language-specific advisories
- Sysdig Threat Research Team intelligence (exploitation analysis, weaponized CVE tracking)

**Key enrichment Sysdig adds:**
- Runtime "in use" correlation (the major differentiator)
- EPSS scores
- CISA KEV membership
- Exploitation context (is this being actively exploited in cloud-native environments?)
- Fix availability and patch timing recommendations

**Vulnerability scoring formula:**
```
Sysdig Risk Score = f(
  CVSS base score,
  EPSS score,
  CISA KEV membership,
  "In Use" status,
  Network exposure of the affected workload,
  Publicly available exploit,
  Time since vulnerability disclosure
)
```
