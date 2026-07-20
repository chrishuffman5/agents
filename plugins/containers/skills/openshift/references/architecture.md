# OpenShift Architecture Reference

Deep technical detail on OCP internals, Cluster Operators, RHCOS, and platform components.

---

## Cluster Architecture

OpenShift Container Platform builds on Kubernetes and adds a managed platform layer:

```
┌──────────────────────────────────────────┐
│  OpenShift Platform Layer                │
│  ┌────────────────────────────────────┐  │
│  │ Web Console (admin + developer)    │  │
│  │ OLM (Operator Lifecycle Manager)   │  │
│  │ Integrated Registry               │  │
│  │ Integrated Monitoring (Prometheus) │  │
│  │ Integrated Logging (Loki/ES)       │  │
│  │ Routes / HAProxy Router            │  │
│  │ Machine Config Operator            │  │
│  │ Build System (S2I, Docker builds)  │  │
│  │ ImageStreams                        │  │
│  └────────────────────────────────────┘  │
│  ┌────────────────────────────────────┐  │
│  │ Kubernetes (API Server, etcd,      │  │
│  │  Scheduler, Controller Manager)    │  │
│  └────────────────────────────────────┘  │
│  ┌────────────────────────────────────┐  │
│  │ RHCOS / Fedora CoreOS (immutable)  │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

### RHCOS (Red Hat CoreOS)

All control plane nodes must run RHCOS. Worker nodes can run RHCOS or RHEL.

**Key characteristics**:
- Immutable OS: no `yum install`, no SSH-based configuration changes
- Managed via Ignition configs (first boot) and MCO (ongoing)
- Automatic updates coordinated by MCO
- `rpm-ostree` based: atomic OS updates with rollback capability
- CRI-O as the container runtime (not containerd)
- SELinux enforcing by default

**Node access**: use `oc debug node/<name>` instead of SSH. This runs a privileged pod with the host filesystem mounted at `/host`.

---

## Cluster Operators

Every OpenShift platform component is managed as a Cluster Operator:

```bash
oc get clusteroperators
```

| Operator | Manages |
|----------|---------|
| `authentication` | OAuth server, identity providers |
| `cloud-credential` | Cloud provider credentials |
| `cluster-autoscaler` | Cluster Autoscaler |
| `console` | Web console |
| `dns` | CoreDNS |
| `etcd` | etcd cluster |
| `image-registry` | Integrated image registry |
| `ingress` | HAProxy router (IngressController) |
| `kube-apiserver` | API server |
| `kube-controller-manager` | Controller manager |
| `kube-scheduler` | Scheduler |
| `machine-api` | Machine API (MAPI) for node provisioning |
| `machine-config` | MCO, node OS management |
| `monitoring` | Prometheus, Alertmanager, Grafana |
| `network` | OVN-Kubernetes or OpenShift SDN |
| `node-tuning` | Tuned profiles for node optimization |
| `openshift-apiserver` | OpenShift API extensions |
| `storage` | CSI drivers, storage configuration |

**Cluster Operator states**:
- **Available**: functioning correctly
- **Progressing**: performing an operation (upgrade, configuration change)
- **Degraded**: functioning with errors or reduced capability

**Troubleshooting degraded operators**:
```bash
oc get co <operator-name> -o yaml   # check conditions and messages
oc logs -n openshift-<operator>-operator deploy/<operator>-operator
oc get events -n openshift-<operator>-operator --sort-by=.lastTimestamp
```

---

## Machine Config Operator (MCO) Deep Dive

### Architecture

```
MachineConfigController
  ├── Template Controller → renders MachineConfig objects
  ├── Update Controller → coordinates node updates
  └── Render Controller → merges MachineConfigs into rendered-MachineConfig

MachineConfigDaemon (runs on every node)
  ├── Watches for rendered-MachineConfig changes
  ├── Applies config (files, systemd units, kernel args)
  └── Reboots node if necessary
```

### Update Flow

1. Admin applies a new MachineConfig (or MCO generates one from cluster config)
2. Render Controller merges all MachineConfigs for the pool into a `rendered-<pool>-<hash>`
3. Update Controller starts rolling update (one node at a time by default)
4. For each node:
   a. Cordon (prevent new pods)
   b. Drain (evict existing pods, respecting PDBs)
   c. MachineConfigDaemon applies the config
   d. Reboot (if config requires it)
   e. Uncordon (re-enable scheduling)

**maxUnavailable**: controls parallelism. Default: 1. Can be set on MachineConfigPool.

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: worker
spec:
  maxUnavailable: 2    # update 2 nodes at a time
```

### Common MachineConfig Use Cases

**Custom kernel arguments**:
```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-worker-kargs
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  kernelArguments:
  - "hugepages=2048"
  - "default_hugepagesz=2M"
```

**Custom systemd unit**:
```yaml
spec:
  config:
    ignition:
      version: 3.4.0
    systemd:
      units:
      - name: my-custom.service
        enabled: true
        contents: |
          [Unit]
          Description=My Custom Service
          [Service]
          ExecStart=/usr/local/bin/my-script.sh
          [Install]
          WantedBy=multi-user.target
```

**Custom certificate trust**:
```yaml
spec:
  config:
    ignition:
      version: 3.4.0
    storage:
      files:
      - path: /etc/pki/ca-trust/source/anchors/internal-ca.crt
        mode: 0644
        contents:
          inline: |
            -----BEGIN CERTIFICATE-----
            ...
            -----END CERTIFICATE-----
```

---

## OLM Architecture

### Components

```
CatalogSource (operator catalog)
    ↓
OLM Operator (runs in openshift-operator-lifecycle-manager)
    ├── Resolves dependencies between operators
    ├── Creates InstallPlans
    └── Creates ClusterServiceVersions
    ↓
Catalog Operator
    ├── Watches CatalogSources
    ├── Resolves Subscriptions to specific operator versions
    └── Creates or updates InstallPlans
    ↓
InstallPlan
    ├── Lists all resources to create/update
    ├── Approval: Automatic or Manual
    └── When approved, creates CSV + CRDs + RBAC + Deployments
```

### Operator Dependency Resolution

OLM resolves dependencies between operators automatically:
- Operator A depends on CRD X
- OLM finds Operator B that provides CRD X
- OLM installs Operator B before Operator A

### Custom Operator Catalogs (Air-Gapped)

```bash
# Mirror operator catalog to internal registry
oc adm catalog mirror \
  registry.redhat.io/redhat/redhat-operator-index:v4.16 \
  registry.internal.example.com/olm \
  --insecure

# Create CatalogSource pointing to mirrored catalog
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: custom-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: registry.internal.example.com/olm/redhat-operator-index:v4.16
  displayName: Custom Catalog
  updateStrategy:
    registryPoll:
      interval: 30m
EOF
```

---

## Route Controller (HAProxy Router)

### Architecture

The IngressController operator manages HAProxy instances that serve as the default router:

```
External Traffic → Load Balancer → HAProxy Pods (router-default)
                                      ↓
                                   Route evaluation (host + path matching)
                                      ↓
                                   Backend Service → Pods
```

**Router deployment**: runs as a Deployment in `openshift-ingress` namespace. Default: 2 replicas.

### Route Evaluation

Routes are evaluated by:
1. **Host match**: exact hostname
2. **Path match**: path prefix (if specified)
3. **Wildcard**: `*.apps.cluster.example.com` (if wildcardPolicy allows)

### Performance Tuning

```yaml
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: default
  namespace: openshift-ingress-operator
spec:
  tuningOptions:
    maxConnections: 50000
    threadCount: 4
    headerBufferBytes: 32768
    headerBufferMaxRewriteBytes: 8192
  replicas: 3
```

---

## Integrated Image Registry

OpenShift runs an internal registry at `image-registry.openshift-image-registry.svc:5000`:

```bash
# Check registry status
oc get configs.imageregistry.operator.openshift.io cluster -o yaml

# Expose registry externally
oc patch configs.imageregistry.operator.openshift.io cluster \
  --type merge --patch '{"spec":{"defaultRoute":true}}'

# Access registry
oc registry login
podman login -u $(oc whoami) -p $(oc whoami -t) default-route-openshift-image-registry.apps.cluster.example.com
```

**Storage backends**: Azure Blob, AWS S3, GCS, OpenStack Swift, PVC (bare metal).

---

## Networking

### OVN-Kubernetes (Default since OCP 4.12)

OpenShift's default CNI uses OVN (Open Virtual Network):
- Overlay networking via Geneve tunnels
- Built-in NetworkPolicy enforcement
- Hybrid networking (Linux + Windows nodes)
- EgressFirewall (cluster-scoped egress rules)
- EgressIP (stable source IPs for external communication)

### EgressFirewall

```yaml
apiVersion: k8s.ovn.org/v1
kind: EgressFirewall
metadata:
  name: default
  namespace: production
spec:
  egress:
  - type: Allow
    to:
      cidrSelector: 10.0.0.0/8
  - type: Allow
    to:
      dnsName: "*.internal.example.com"
  - type: Deny
    to:
      cidrSelector: 0.0.0.0/0
```

### EgressIP

Assign stable egress IPs to pods in a namespace (useful for firewall allowlisting):

```yaml
apiVersion: k8s.ovn.org/v1
kind: EgressIP
metadata:
  name: production-egress
spec:
  egressIPs:
  - 192.168.1.100
  - 192.168.1.101
  namespaceSelector:
    matchLabels:
      env: production
```

---

## Security Architecture

### SCC Evaluation Algorithm

When a pod is created:

```
1. Collect all SCCs accessible to the pod's ServiceAccount
   (via RoleBindings/ClusterRoleBindings granting "use" verb on SCC resources)
2. Sort SCCs by restrictiveness (most restrictive first)
3. For each SCC:
   a. Check if the pod's securityContext satisfies the SCC constraints
   b. If yes, mutate the pod to fill in missing fields with SCC defaults
   c. Assign this SCC to the pod
4. If no SCC matches, reject the pod
```

**Default**: all authenticated users can use `restricted-v2` SCC.

### OAuth and Identity

OpenShift includes an OAuth server for authentication:

```yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: ldap
    type: LDAP
    mappingMethod: claim
    ldap:
      url: "ldaps://ldap.example.com/ou=users,dc=example,dc=com?uid"
      bindDN: "cn=admin,dc=example,dc=com"
      bindPassword:
        name: ldap-bind-password
      insecure: false
      ca:
        name: ldap-ca
  - name: htpasswd
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpasswd-secret
```

Supported identity providers: LDAP, Active Directory, OIDC, GitHub, Google, GitLab, Basic Auth, HTPasswd, Keystone, Request Header.

### Certificate Management

OpenShift manages internal certificates automatically:
- API server serving cert
- Ingress controller (router) certs
- etcd peer and client certs
- kubelet certs

Custom certificates can be set for the API server and ingress:

```bash
# Custom ingress cert
oc create secret tls ingress-cert \
  --cert=cert.pem --key=key.pem -n openshift-ingress

oc patch ingresscontroller default \
  -n openshift-ingress-operator \
  --type=merge \
  --patch='{"spec":{"defaultCertificate":{"name":"ingress-cert"}}}'
```
