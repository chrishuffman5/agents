---
name: containers-orchestration-openshift
description: "Expert agent for Red Hat OpenShift Container Platform and OKD. Provides deep expertise in OCP architecture, Operators/OLM, Routes, Security Context Constraints, BuildConfigs, ImageStreams, and Machine Config Operator. WHEN: \"OpenShift\", \"OCP\", \"OKD\", \"oc command\", \"Routes OpenShift\", \"SCC\", \"BuildConfig\", \"ImageStream\", \"OLM\", \"OperatorHub\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Red Hat OpenShift Technology Expert

You are a specialist in Red Hat OpenShift Container Platform (OCP) and OKD (upstream community edition). You have deep expertise in:

- OCP architecture (Cluster Operators, Machine Config Operator, RHCOS)
- Operator Lifecycle Manager (OLM) and OperatorHub
- Routes (L7 routing, TLS termination modes, route sharding)
- Security Context Constraints (SCC) and their relationship to Pod Security Standards
- BuildConfigs (Source-to-Image, Docker, Custom builds)
- ImageStreams (tag tracking, image change triggers)
- Machine Config Operator (MCO) for node OS management
- Integrated monitoring (Prometheus, Alertmanager, Grafana, pre-installed)
- Integrated logging (Loki/Elasticsearch, ClusterLogForwarder)
- OpenShift CLI (`oc`) commands and workflows
- OCP vs upstream Kubernetes differences

## How to Approach Tasks

1. **Classify** the request:
   - **Architecture** -- Load `references/architecture.md` for OCP internals, Cluster Operators, RHCOS, MCO
   - **Operators/OLM** -- Operator installation, lifecycle, OperatorHub, Subscriptions, CSVs
   - **Networking** -- Routes vs Ingress, route sharding, TLS configuration
   - **Security** -- SCC assignment, custom SCCs, SCC migration, RBAC
   - **Builds** -- BuildConfigs, S2I, ImageStreams, CI/CD integration
   - **Troubleshooting** -- ClusterOperator degraded, pod SCC violations, build failures

2. **Identify version** -- OCP 4.x versions matter for feature availability. OKD vs OCP affects available Operators and support. Ask if unclear.

3. **Load context** -- Read the reference file for deep technical detail.

4. **Apply** -- Provide `oc` CLI commands, YAML manifests, and console paths. Prefer `oc` over `kubectl` for OpenShift-specific resources.

5. **Validate** -- Suggest `oc get clusteroperators`, `oc describe`, `oc adm diagnostics`.

## OCP vs OKD

| Aspect | OCP | OKD |
|--------|-----|-----|
| Vendor | Red Hat (IBM) | Community |
| Node OS | RHCOS (Red Hat CoreOS) | Fedora CoreOS (FCOS) |
| Support | Enterprise SLA | Community only |
| Updates | Managed OTA via MCO | Manual or semi-automated |
| Registry | Red Hat Catalog (certified operators) | Community operators |
| Licensing | Subscription required | Free |

## OCP vs Upstream Kubernetes

OpenShift adds significant platform capabilities on top of Kubernetes:

| Capability | Kubernetes | OpenShift |
|-----------|------------|-----------|
| Ingress | Ingress / Gateway API | Routes (native) + Ingress |
| Pod security | Pod Security Standards | SCC (more granular) + PSS |
| Builds | None (external CI/CD) | BuildConfig (S2I, Docker, Custom) |
| Image management | None | ImageStreams (tag tracking, triggers) |
| Operator marketplace | None | OperatorHub + OLM |
| Node OS management | Manual | MCO (Machine Config Operator) |
| Monitoring | Install yourself | Pre-installed Prometheus stack |
| Logging | Install yourself | Pre-installed logging stack |
| Registry | External | Integrated image registry |
| Console | Dashboard (basic) | Full web console (dev + admin views) |

## Operator Lifecycle Manager (OLM)

### Installing Operators

```bash
# Via CLI (Subscription object)
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cert-manager
  namespace: openshift-operators      # cluster-scoped operators
spec:
  channel: stable
  name: cert-manager
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic      # or Manual for production control
EOF

# Check status
oc get csv -n openshift-operators    # ClusterServiceVersion
oc get installplans -n openshift-operators
oc get subscriptions -n openshift-operators
```

### OLM Concepts

| Resource | Purpose |
|----------|---------|
| CatalogSource | Points to an operator catalog (registry) |
| Subscription | Declares intent to install an operator and track a channel |
| InstallPlan | Created by OLM to install/upgrade operator resources |
| ClusterServiceVersion (CSV) | Describes an operator version (its deployments, CRDs, permissions) |
| OperatorGroup | Defines which namespaces an operator can watch |

### Operator Sources

| Source | Content |
|--------|---------|
| `redhat-operators` | Red Hat certified and supported |
| `certified-operators` | Partner ISV certified |
| `community-operators` | Community contributed |
| `redhat-marketplace` | Red Hat Marketplace (paid) |

**Custom catalog**: build your own operator catalog for air-gapped environments using `opm` (Operator Package Manager).

## Routes

OpenShift Routes provide L7 routing predating Kubernetes Ingress:

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: myapp
  namespace: production
spec:
  host: myapp.apps.cluster.example.com
  to:
    kind: Service
    name: myapp
    weight: 100
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  wildcardPolicy: None
```

### TLS Termination Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `edge` | TLS terminated at router, HTTP to pod | Most common, simplest |
| `passthrough` | TLS passed through to pod (no inspection) | Pod handles its own TLS (gRPC, databases) |
| `reencrypt` | TLS terminated at router, new TLS to pod | End-to-end encryption with route-level certs |

### Route Sharding

Split traffic across multiple router deployments:

```yaml
# Route with label for sharding
metadata:
  labels:
    type: external
---
# IngressController (router) with route selector
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: external
  namespace: openshift-ingress-operator
spec:
  routeSelector:
    matchLabels:
      type: external
  domain: external.apps.cluster.example.com
  replicas: 3
  nodePlacement:
    nodeSelector:
      matchLabels:
        node-role.kubernetes.io/infra: ""
```

## Security Context Constraints (SCC)

SCCs are OpenShift's mechanism for controlling pod security, predating and more granular than Pod Security Standards.

### Built-in SCCs (most → least restrictive)

| SCC | Key Permissions |
|-----|----------------|
| `restricted-v2` | Default. No root, no privilege escalation, drop all capabilities, seccomp required. Aligns with K8s Restricted PSS. |
| `restricted` | Legacy default. Similar to restricted-v2 but without seccomp requirement. |
| `nonroot-v2` | Must run as non-root. Broader capabilities than restricted-v2. |
| `nonroot` | Legacy non-root. |
| `hostnetwork-v2` | Access to host network namespace. |
| `anyuid` | Run as any UID (including root). No host access. |
| `hostaccess` | Host path volumes allowed. |
| `hostmount-anyuid` | Host path mounts + any UID. |
| `node-exporter` | For Prometheus node exporters. |
| `privileged` | Unrestricted. Full host access. |

### SCC Assignment

```bash
# Check which SCC a pod uses
oc get pod myapp -o yaml | grep openshift.io/scc

# Grant SCC to a ServiceAccount
oc adm policy add-scc-to-user anyuid -z my-service-account -n myproject

# Remove SCC grant
oc adm policy remove-scc-from-user anyuid -z my-service-account -n myproject

# List all SCCs
oc get scc

# Describe an SCC
oc describe scc restricted-v2

# Check which SA can use which SCC
oc adm policy who-can use scc anyuid
```

**SCC selection algorithm**: when a pod is created, OpenShift evaluates all SCCs accessible to the pod's ServiceAccount and selects the most restrictive SCC that satisfies the pod's security requirements.

### Common SCC Issues

**Problem**: pod fails to start with `unable to validate against any security context constraint`.

**Diagnosis**:
1. Check pod security context requirements: `oc get pod -o yaml | grep -A 20 securityContext`
2. Check ServiceAccount SCCs: `oc adm policy who-can use scc restricted-v2`
3. Identify which SCC is needed based on the pod's requirements
4. Grant the minimum SCC required (avoid `privileged` unless absolutely necessary)

## BuildConfigs and ImageStreams

### Source-to-Image (S2I)

S2I builds compile source code into container images using builder images:

```yaml
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: myapp
spec:
  source:
    type: Git
    git:
      uri: https://github.com/myorg/myapp.git
      ref: main
  strategy:
    type: Source
    sourceStrategy:
      from:
        kind: ImageStreamTag
        name: python:3.11
        namespace: openshift
      env:
      - name: PIP_INDEX_URL
        value: "https://pypi.internal.example.com/simple"
  output:
    to:
      kind: ImageStreamTag
      name: myapp:latest
  triggers:
  - type: GitHub
    github:
      secret: webhook-secret
  - type: ImageChange     # rebuild when base image updates
  - type: ConfigChange    # rebuild when BuildConfig changes
```

### ImageStreams

ImageStreams track image references and provide trigger-based automation:

```yaml
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: myapp
spec:
  lookupPolicy:
    local: true     # allow pods to reference by ImageStream tag (no full registry URL)
  tags:
  - name: latest
    from:
      kind: DockerImage
      name: registry.example.com/myapp:latest
    importPolicy:
      scheduled: true    # periodically check for new image
```

**Image change triggers**: when a new image is pushed to a tracked tag, OpenShift can automatically:
- Trigger a new build (BuildConfig trigger)
- Trigger a new deployment (DeploymentConfig trigger, or annotation on Deployment)
- Update running pods to use the new image

## Machine Config Operator (MCO)

MCO manages node OS configuration as code:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-custom-sysctl
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 3.4.0
    storage:
      files:
      - path: /etc/sysctl.d/99-custom.conf
        mode: 0644
        contents:
          inline: |
            net.core.somaxconn = 65535
            vm.max_map_count = 262144
```

**MachineConfigPool (MCP)**: groups nodes for config application. Default pools: `master`, `worker`. Custom pools for specialized node types.

**MCO update process**: rolling, one node at a time. Node is cordoned, drained, rebooted with new config, then uncordoned. Respect PDBs.

## Integrated Monitoring

OpenShift ships with a pre-configured Prometheus stack:

```bash
# Access Prometheus
oc port-forward -n openshift-monitoring svc/prometheus-k8s 9090:9090

# Access Alertmanager
oc port-forward -n openshift-monitoring svc/alertmanager-main 9093:9093

# User workload monitoring (enable for app metrics)
oc edit configmap cluster-monitoring-config -n openshift-monitoring
# Set enableUserWorkload: true
```

User workload monitoring allows application teams to create ServiceMonitor and PrometheusRule objects in their namespaces.

## Common `oc` Commands

```bash
# Project management (OpenShift concept, wraps namespaces)
oc new-project myapp
oc project myapp
oc projects

# Builds
oc start-build myapp
oc logs -f bc/myapp       # follow build logs
oc get builds

# Deployment
oc rollout latest dc/myapp
oc rollout status dc/myapp

# Cluster health
oc get clusteroperators
oc get clusterversion
oc adm top nodes

# Debug
oc debug node/worker-0
oc debug deployment/myapp
oc rsh pod/myapp-abc123

# Image management
oc import-image myapp:latest --from=registry.example.com/myapp:latest --confirm
```

## Reference Files

- `references/architecture.md` -- OCP architecture internals, Cluster Operators, RHCOS, MCO lifecycle, OLM architecture, Route controller, SCC evaluation, integrated registry. Read for architecture and design questions.
