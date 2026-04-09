# Falco Architecture Reference

## Kernel-Level Monitoring Architecture

### How Falco Sees Syscalls

Linux processes interact with the kernel through system calls. Every meaningful action a container takes — reading files, spawning processes, making network connections — goes through a syscall. Falco intercepts these syscalls to build a comprehensive picture of container behavior.

```
Container Process
  └── read("/etc/shadow")
        ↓ [user-to-kernel transition]
Linux Kernel
  └── sys_openat (or sys_open) syscall handler
        ├── Kernel executes the syscall
        └── eBPF hook fires:
              ├── Captures: PID, UID, arguments, return value
              ├── Enriches with: container ID, cgroup info
              └── Writes event to BPF ring buffer
                    ↓
Falco Userspace
  └── Reads event from ring buffer
  └── Enriches with: pod name (K8s API), container name, image
  └── Evaluates against Falco rules
  └── If rule matches → generates alert
```

### Monitored Syscalls

Falco monitors hundreds of syscalls but focuses on security-relevant ones:

**Process lifecycle:**
- `execve`, `execveat` — Process execution (with arguments)
- `fork`, `clone`, `vfork` — Process creation
- `exit`, `exit_group` — Process termination

**File operations:**
- `open`, `openat`, `openat2` — File open
- `read`, `write` — File read/write
- `unlink`, `unlinkat` — File deletion
- `rename`, `renameat` — File rename
- `chmod`, `fchmod`, `fchmodat` — Permission change
- `chown`, `fchown`, `lchown` — Ownership change
- `mmap` — Memory mapping (library loading detection)
- `link`, `linkat` — Hardlink creation

**Network:**
- `connect` — Outbound connection initiation
- `accept`, `accept4` — Inbound connection acceptance
- `bind` — Port binding
- `sendto`, `sendmsg` — Data sending
- `recvfrom`, `recvmsg` — Data receiving

**Credentials / security:**
- `setuid`, `setgid` — UID/GID changes
- `setresuid`, `setresgid` — Saved UID/GID changes
- `capset` — Capability changes
- `ptrace` — Process tracing (potential for container escape)
- `setns` — Namespace change (container escape vector)

**Memory:**
- `mprotect` — Memory protection change (shellcode injection indicator)
- `ptrace` — Debugging/tracing

### eBPF Probe Architecture

```
┌──────────────────────────────────────────────────────┐
│                 LINUX KERNEL                          │
│                                                      │
│  Process execve()                                    │
│       ↓                                              │
│  [kprobe/tracepoint on sys_enter_execve]             │
│       ↓                                              │
│  eBPF Program (verifier-approved bytecode)           │
│  ├── Reads syscall arguments from pt_regs            │
│  ├── Reads task_struct (PID, UID, cgroup)            │
│  ├── Packs event into struct (fixed layout)          │
│  └── Writes to BPF Ring Buffer (MPSC)                │
│                    │                                 │
└────────────────────│─────────────────────────────────┘
                     │ (shared memory, zero-copy)
┌────────────────────│─────────────────────────────────┐
│              FALCO USERSPACE                         │
│                    ↓                                 │
│  Ring Buffer Consumer (epoll-based)                 │
│  └── Reads events in batches                        │
│  └── Resolves paths (fd → path via /proc)           │
│  └── K8s metadata enrichment (pod name, labels)     │
│  └── Passes to Falco Rule Engine                    │
└──────────────────────────────────────────────────────┘
```

**BPF Ring Buffer vs. BPF Perf Buffer:**
- Old Falco used `perf_event_array` (one buffer per CPU)
- Modern Falco uses `BPF_MAP_TYPE_RINGBUF` (single shared ring buffer)
- Ring buffer: lower memory, no per-CPU ordering issues, better performance

**eBPF program safety:**
The Linux kernel's eBPF verifier ensures eBPF programs cannot:
- Access arbitrary kernel memory
- Loop infinitely
- Crash the kernel
All Falco eBPF programs pass the verifier before loading.

### Driver Options Comparison

| Driver | Kernel Req | Compilation | Overhead | Notes |
|---|---|---|---|---|
| Modern eBPF (CO-RE) | 5.8+ with BTF | Pre-compiled | Lowest | Recommended; portable; no headers needed |
| eBPF probe | 4.14+ | Per-kernel | Low | Auto-downloads/compiles for your kernel |
| Kernel module | 3.x+ | Per-kernel | Low | Falls back if eBPF unavailable |
| gVisor (runsc) | Any | N/A | Higher | For sandboxed workloads; different tracing model |

**CO-RE (Compile Once, Run Everywhere):**
Traditional eBPF required the eBPF program to be compiled for the exact kernel version it would run on (because kernel struct layouts vary between versions). CO-RE uses BTF (BPF Type Format) — metadata embedded in the kernel that describes struct layouts — allowing a single compiled eBPF program to run on any compatible kernel. This is why modern eBPF is the recommended choice.

**Checking BTF availability:**
```bash
# If this file exists, BTF is supported
ls /sys/kernel/btf/vmlinux

# Or check kernel config
grep CONFIG_DEBUG_INFO_BTF /boot/config-$(uname -r)
# Should return: CONFIG_DEBUG_INFO_BTF=y
```

## Falco Rule Evaluation Pipeline

### Event Processing Flow

```
Raw syscall event from ring buffer
  ↓
EventReader (libscap)
  └── Decodes raw event bytes into structured fields
  └── Resolves FD numbers to file paths (via /proc/PID/fd/)
  └── Resolves PID to process info (via /proc/PID/status)
  ↓
K8s Metadata Enrichment (libsinsp)
  └── Looks up container ID in container runtime (containerd/docker)
  └── Gets pod name, namespace, labels from K8s API server (or cache)
  └── Adds: k8s.pod.name, k8s.ns.name, k8s.pod.label[*], container.image.*
  ↓
Rule Engine (libsinsp)
  └── For each loaded rule:
        └── Evaluates condition against event fields
        └── If condition matches: trigger output formatter
              └── Format output string with field values
              └── Generate Alert object (priority, text, fields)
  ↓
Output Handlers
  ├── stdout (JSON or human-readable)
  ├── file (rotation support)
  ├── syslog
  ├── HTTP endpoint (for Falcosidekick)
  └── gRPC (for programmatic consumers)
```

### Rule Condition Evaluation

The rule engine evaluates conditions using a compiled expression tree:

```
condition: spawned_process and container and proc.name in (shell_binaries)

Compiled AST:
  AND
  ├── spawned_process (macro → AND(evt.type=execve, evt.dir=<))
  ├── container (macro → container.id != host)
  └── IN(proc.name, [bash, sh, zsh, ksh, tcsh, csh, fish])

Evaluation per event:
  1. Check evt.type = execve   → if false, short-circuit (fast fail)
  2. Check evt.dir = <         → if false, short-circuit
  3. Check container.id != host → if false, short-circuit
  4. Check proc.name in list   → O(1) hash lookup
```

**Short-circuit evaluation:** Conditions are ordered by cost (cheapest first). `evt.type` checks are nearly free (integer comparison) and evaluated before expensive string operations.

## Falco Plugin Framework

### Plugin Architecture

Falco's plugin system enables extensibility without modifying core Falco:

```
Plugin (shared library .so)
  Implements:
    ├── plugin_get_name()          → "cloudtrail"
    ├── plugin_get_description()   → description string
    ├── plugin_get_event_source()  → "aws_cloudtrail"
    ├── plugin_open()              → Opens event source (SQS queue, file, etc.)
    ├── plugin_next_batch()        → Returns next batch of events
    ├── plugin_get_fields()        → Field descriptors (name, type, description)
    └── plugin_extract_fields()    → Field extractor for event data

Falco loads plugin via:
  dlopen(libcloudtrail.so)
  dlsym(plugin_get_name)
```

**Plugin isolation:** Plugins run in the same process as Falco but in their own execution context. A crashing plugin can destabilize Falco — use tested, stable plugins in production.

### Writing a Custom Plugin (Python via SDK)

Falco provides a Python SDK for writing plugins:

```python
import falco_plugin
import json

class MyPlugin(falco_plugin.Plugin):
    # Define fields this plugin extracts
    class MyEvent(falco_plugin.PluginEvent):
        fields = {
            "my.event.type": falco_plugin.FieldType.FTYPE_STRING,
            "my.event.user": falco_plugin.FieldType.FTYPE_STRING,
            "my.event.resource": falco_plugin.FieldType.FTYPE_STRING,
        }

    def get_name(self):
        return "my_custom_source"

    def get_description(self):
        return "Custom event source for my application audit log"

    def get_event_source(self):
        return "my_app_audit"

    def open(self, params):
        # Open connection to event source
        self.reader = open_kafka_consumer(topic="audit-log")
        return None

    def next_batch(self, context):
        events = []
        for msg in self.reader.poll(timeout=0.1):
            data = json.loads(msg.value)
            event = self.MyEvent(
                data=msg.value,  # raw event data
                timestamp=data["timestamp"]
            )
            events.append(event)
        return events

    def extract_fields(self, event, fields):
        data = json.loads(event.data)
        return {
            "my.event.type": data.get("event_type"),
            "my.event.user": data.get("user_email"),
            "my.event.resource": data.get("resource_name"),
        }
```

## Falcosidekick Internal Architecture

### Message Flow

```
Falco → HTTP POST (JSON) → Falcosidekick

Falcosidekick receives:
{
  "output": "Shell spawned in container (user=root container=myapp ...)",
  "priority": "WARNING",
  "rule": "Terminal shell in container",
  "time": "2024-01-15T10:30:00.000Z",
  "output_fields": {
    "container.id": "abc123",
    "container.name": "myapp",
    "proc.name": "bash",
    "user.name": "root",
    "k8s.pod.name": "myapp-7d9f8b-xyz",
    "k8s.ns.name": "production"
  },
  "hostname": "k8s-node-01",
  "tags": ["container", "shell", "process"]
}

Falcosidekick:
  ├── Applies output filters (priority threshold, rule whitelist/blacklist)
  ├── Formats message per output type (Slack rich message, PagerDuty incident, etc.)
  └── Sends to all configured outputs concurrently (goroutines)
```

### Output Formatters

Falcosidekick ships custom formatters for each output type:

**Slack formatter:**
```json
{
  "attachments": [{
    "color": "warning",
    "title": "Falco Alert: Terminal shell in container",
    "fields": [
      {"title": "Rule", "value": "Terminal shell in container", "short": true},
      {"title": "Priority", "value": "WARNING", "short": true},
      {"title": "Container", "value": "myapp (abc123)", "short": true},
      {"title": "Pod", "value": "myapp-7d9f8b-xyz / production", "short": true},
      {"title": "User", "value": "root", "short": true},
      {"title": "Time", "value": "2024-01-15T10:30:00Z", "short": true}
    ],
    "footer": "Falco | Kubernetes: my-cluster"
  }]
}
```

**PagerDuty formatter:**
- Maps CRITICAL/ALERT → trigger (page on-call)
- Maps WARNING/NOTICE → trigger (low urgency)
- Maps INFORMATIONAL/DEBUG → not triggered (below threshold)
- Deduplication key: rule name + container ID (prevents flood from same container)

### Falcosidekick Configuration File

```yaml
# /etc/falcosidekick/config.yaml
listenaddress: 0.0.0.0
listenport: 2801
debug: false

# Custom fields added to every alert
customfields:
  cluster: "production-eks"
  environment: "production"

# Output throttling (prevent flood for same rule)
outputfieldformat: "text"
bracketreplacer: ""

# Priority threshold (applies globally if per-output not set)
minimumpriority: "warning"

# Outputs
slack:
  webhookurl: "https://hooks.slack.com/services/..."
  channel: "#security"
  footer: "Falco"
  minimumpriority: "warning"
  messageformat: "Alert : rule=%rule priority=%priority"

pagerduty:
  routingkey: "abc123"
  minimumpriority: "critical"

elasticsearch:
  hostport: "http://elasticsearch:9200"
  index: "falco"
  minimumpriority: "debug"
  mutualtls: false

webhook:
  address: "http://falco-talon:2803"
  minimumpriority: "warning"
  headers:
    Authorization: "Bearer my-talon-token"
```

## falco-talon Engine Architecture

### Response Rule Processing

```
Alert received from Falcosidekick (HTTP POST)
  ↓
falco-talon rule matching:
  ├── Match by rule name: does alert.rule match talon rule.name?
  ├── Match by priority: does alert.priority >= talon rule.minimumpriority?
  ├── Match by namespace: does k8s.ns.name match talon rule.namespace?
  └── Match by output fields: custom field matching
  ↓
Action selection:
  ├── Direct action: execute immediately
  └── With approval: wait for human approval before executing
        └── Approval request sent to configured channel (Slack, etc.)
        └── Human approves/denies via Slack button or API
  ↓
Action execution:
  ├── K8s actions: uses in-cluster SA (ServiceAccount with RBAC)
  ├── AWS actions: uses IAM role (IRSA or instance role)
  └── GCP actions: uses GCP Service Account (Workload Identity)
  ↓
Action audit log:
  └── All actions logged with: alert details, action taken, user (if approval), timestamp
  └── Sent to configured notification channels
```

### Built-in Actions

**Kubernetes actions:**
- `Terminate Pod` — delete pod (forces recreation if managed by Deployment)
- `Label Pod` — add labels to pod (for NetworkPolicy isolation, GitOps processing)
- `Annotate Pod` — add annotations to pod
- `Network Policy` — create or update NetworkPolicy for the pod
- `Exec` — run a command inside the container (for evidence collection)

**AWS actions:**
- `Snapshot EBS` — create forensic snapshot before remediation
- `Quarantine EC2` — change security group to isolation group
- `Disable IAM User` — disable IAM user's console access + delete access keys
- `Lambda Invoke` — invoke Lambda function with alert context

**GCP actions:**
- `Quarantine GCE Instance` — move instance to isolation VPC/firewall rule

**Notification actions:**
- `Slack` — post message to Slack (used for approval flows)
- `Webhook` — send to arbitrary HTTP endpoint

## Falco in Production: Operational Considerations

### High Availability

Falco itself is a DaemonSet — one pod per node. For the control plane:
- **Falcosidekick:** Deploy with 2+ replicas; it's stateless
- **falco-talon:** Stateful (approval workflows); deploy with 2 replicas + shared state (Redis)

### Log Management

Falco generates JSON alerts that should be retained:
```yaml
# falco.yaml: JSON output for log aggregation
json_output: true
json_include_output_property: true
json_include_tags_property: true

# File output for log forwarding
file_output:
  enabled: true
  keep_alive: false
  filename: /var/log/falco/falco.log
  # Rotate: external log rotation via logrotate or Fluentd
```

**Fluentd / Fluent Bit integration:**
```yaml
# Fluent Bit: tail Falco log file and forward to Elasticsearch/SIEM
[INPUT]
    Name tail
    Path /var/log/falco/falco.log
    Parser json
    Tag falco

[OUTPUT]
    Name es
    Match falco
    Host elasticsearch
    Port 9200
    Index falco-logs
    Type _doc
```

### Kernel Upgrade Impact

When Kubernetes nodes are upgraded (new OS image, new kernel):
- eBPF CO-RE (Modern eBPF): no action needed — CO-RE probes are portable
- Legacy eBPF: Falco automatically recompiles/downloads the probe for the new kernel on next start
- Kernel module: same as legacy eBPF — auto-recompile on restart

**Recommendation:** Pin to Modern eBPF driver to eliminate kernel upgrade disruption.

### Security of Falco Itself

Falco requires elevated privileges — it's important to secure it:
- DaemonSet runs with `privileged: true` (required for kernel access)
- Falco's ServiceAccount should have minimal RBAC (only what's needed for K8s metadata)
- Falcosidekick should not run with elevated privileges (it's just an HTTP relay)
- Restrict access to Falco configuration (rules can be weakened if tampered with)
- Integrity monitoring: use OPA/Kyverno to prevent modification of Falco DaemonSet without approval
