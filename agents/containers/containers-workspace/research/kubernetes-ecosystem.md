# Kubernetes Ecosystem Deep Dive
*Research date: April 2026*

---

## Helm 4.x

Helm is the Kubernetes package manager. Helm 4 was released at KubeCon 2025. Helm 4.1.3 is current as of early 2026.

### What Changed in Helm 4

| Feature | Helm 3 | Helm 4 |
|---------|--------|--------|
| Apply strategy | Client-side 3-way merge | Server-side apply (SSA) |
| Plugin system | Exec-based | WebAssembly (wasm) |
| Resource readiness | Rollout status | kstatus |
| OCI support | Experimental → GA | Default recommended |
| Caching | None | Local content-based cache |
| Logging | Legacy | slog-based structured logs |
| Multi-doc values | No | Yes (YAML `---` delimiters) |
| OCI install by digest | No | Yes |

### Chart Structure

```
mychart/
├── Chart.yaml             # Chart metadata
├── values.yaml            # Default values
├── values.schema.json     # JSON Schema for values validation
├── charts/                # Dependencies (sub-charts)
│   └── postgresql/
├── templates/             # Go template Kubernetes manifests
│   ├── _helpers.tpl       # Named templates (partials)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── NOTES.txt          # Post-install instructions
│   └── tests/
│       └── test-connection.yaml
├── .helmignore            # Files to exclude from chart
└── crds/                  # Custom Resource Definitions (not templated)
```

### Chart.yaml

```yaml
apiVersion: v2
name: myapp
description: My application Helm chart
type: application        # or library
version: 1.5.0           # Chart version (SemVer)
appVersion: "2.3.1"      # App version (informational)
keywords:
  - web
  - api
dependencies:
  - name: postgresql
    version: "~13.0"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: postgresql.enabled
  - name: redis
    version: "18.x.x"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    alias: cache
annotations:
  category: Infrastructure
```

### Templates

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
  annotations:
    helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        ports:
        - containerPort: {{ .Values.service.targetPort }}
        {{- with .Values.resources }}
        resources:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- if .Values.config.extraEnv }}
        env:
          {{- range .Values.config.extraEnv }}
          - name: {{ .name }}
            value: {{ .value | quote }}
          {{- end }}
        {{- end }}
```

### Hooks

```yaml
# templates/job-migrate.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "myapp.fullname" . }}-migrate
  annotations:
    "helm.sh/hook": pre-upgrade,pre-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: migrate
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        command: ["/app/migrate", "--up"]
```

Hook types: `pre-install`, `post-install`, `pre-upgrade`, `post-upgrade`, `pre-rollback`, `post-rollback`, `pre-delete`, `post-delete`, `test`.

### OCI Registries (Helm 4 Default)

```bash
# Push chart to OCI registry
helm push mychart-1.5.0.tgz oci://registry.example.com/helm-charts

# Pull and install from OCI
helm install myapp oci://registry.example.com/helm-charts/myapp --version 1.5.0

# Install by digest (Helm 4 feature for supply chain security)
helm install myapp oci://registry.example.com/helm-charts/myapp@sha256:abc123...

# Login to OCI registry
helm registry login registry.example.com -u username -p password
```

OCI distribution replaces the legacy `helm repo add` + index.yaml model. OCI repositories can be any OCI-compliant registry: Docker Hub, GHCR, ECR, ACR, GCR, Harbor.

### helm-secrets

```bash
# Encrypt secrets with SOPS
helm secrets enc secrets.yaml
helm secrets dec secrets.yaml

# Install with secrets
helm secrets install myapp ./mychart -f secrets.yaml

# Supports backends: SOPS (AWS KMS, GCP KMS, Azure Key Vault, age, PGP)
```

### Helmfile

Helmfile provides declarative multi-release Helm deployments:

```yaml
# helmfile.yaml
environments:
  staging:
    values:
    - environments/staging.yaml
  production:
    values:
    - environments/production.yaml
    secrets:
    - environments/production.secrets.yaml

repositories:
  - name: bitnami
    url: oci://registry-1.docker.io/bitnamicharts
    oci: true

releases:
  - name: postgresql
    chart: bitnami/postgresql
    version: "~13.0"
    namespace: data
    values:
    - charts/postgresql/values.yaml
    - charts/postgresql/values.{{ .Environment.Name }}.yaml

  - name: myapp
    chart: ./charts/myapp
    namespace: production
    needs:
      - data/postgresql
    values:
    - charts/myapp/values.yaml
    - "{{ .Values.myapp_values_file }}"
    set:
    - name: image.tag
      value: "{{ .Values.app_version }}"
```

```bash
helmfile sync                   # install/upgrade all releases
helmfile diff                   # show what would change
helmfile apply                  # diff + sync
helmfile destroy                # delete all releases
helmfile --environment staging sync
```

---

## Managed Kubernetes

### Amazon EKS

Amazon Elastic Kubernetes Service is the AWS-managed Kubernetes offering.

#### Compute Options

| Option | Description | Best For |
|--------|-------------|----------|
| Managed Node Groups | AWS manages node AMI, patching, draining | Standard workloads |
| Self-Managed Nodes | Full control over EC2 instances | Custom AMIs, specialized hardware |
| Fargate | Serverless pods; no node management | Burst workloads, isolation |
| EKS Auto Mode | Combines Karpenter + Fargate concepts | Simplest operations |

**Managed Node Groups:**
```bash
aws eks create-nodegroup \
  --cluster-name prod \
  --nodegroup-name workers \
  --node-role arn:aws:iam::ACCOUNT:role/NodeRole \
  --subnets subnet-xxx subnet-yyy \
  --instance-types m6i.xlarge m6a.xlarge \
  --ami-type AL2023_x86_64_STANDARD \
  --scaling-config minSize=2,maxSize=10,desiredSize=4 \
  --disk-size 100
```

**Karpenter** (replaces Cluster Autoscaler for EKS):
```yaml
# NodePool: defines node provisioning policies
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: general
spec:
  template:
    spec:
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1
        kind: EC2NodeClass
        name: general
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot", "on-demand"]
      - key: karpenter.k8s.aws/instance-category
        operator: In
        values: ["m", "c", "r"]
      - key: karpenter.k8s.aws/instance-generation
        operator: Gt
        values: ["5"]
  limits:
    cpu: 1000
    memory: 4000Gi
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s

# EC2NodeClass: AWS-specific configuration
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: general
spec:
  amiFamily: AL2023
  role: KarpenterNodeRole-prod
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: prod
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: prod
```

Karpenter v1.10.0 is the de facto standard. It provisions nodes in seconds, selects optimal instance types dynamically, and consolidates underutilized nodes.

**EKS Add-ons:**
- CoreDNS
- kube-proxy
- Amazon VPC CNI
- EBS CSI Driver
- EFS CSI Driver
- Amazon GuardDuty Agent
- ADOT (AWS Distro for OpenTelemetry)

**EKS Anywhere**: Run EKS on bare metal, VMware, Nutanix, or Snow devices.

**Fargate Profiles:**
```yaml
# Create Fargate profile via eksctl
fargateProfiles:
  - name: fp-default
    selectors:
    - namespace: serverless
    - namespace: kube-system
```

**IRSA (IAM Roles for Service Accounts):**
```yaml
# ServiceAccount with IRSA annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/S3ReaderRole
```

---

### Azure AKS

Azure Kubernetes Service is the Azure-managed Kubernetes offering.

#### Node Pools

```bash
# System node pool (kube-system workloads)
az aks nodepool add \
  --resource-group myRG \
  --cluster-name myAKS \
  --name systempool \
  --node-count 3 \
  --node-vm-size Standard_D4s_v5 \
  --mode System \
  --node-taints CriticalAddonsOnly=true:NoSchedule

# User node pool (workloads)
az aks nodepool add \
  --resource-group myRG \
  --cluster-name myAKS \
  --name workerpool \
  --node-count 3 \
  --node-vm-size Standard_D8s_v5 \
  --min-count 2 \
  --max-count 20 \
  --enable-cluster-autoscaler \
  --mode User
```

#### AKS Automatic (GA since 2026)

AKS Automatic removes almost all infrastructure decisions: node pool management, autoscaling, OS patching, and security hardening are handled automatically. Comparable to GKE Autopilot.

#### Azure CNI vs kubenet

| CNI | IP Assignment | Pod Routing |
|-----|--------------|-------------|
| kubenet | Pods get non-VNet IPs; NAT required | Lower IP consumption |
| Azure CNI | Pods get real VNet IPs | Direct routing, no NAT |
| Azure CNI Overlay | Pods get overlay IPs, nodes get VNet IPs | Compromise: scale + routing |
| Azure CNI powered by Cilium | eBPF dataplane + Azure CNI | Best performance |

#### Workload Identity

Replaces AAD Pod Identity (deprecated):

```yaml
# ServiceAccount with workload identity annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  name: storage-reader
  namespace: production
  annotations:
    azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"
```

```bash
# Enable workload identity on AKS cluster
az aks update --resource-group myRG --name myAKS \
  --enable-oidc-issuer --enable-workload-identity

# Create federated credential
az identity federated-credential create \
  --name "aks-fed-cred" \
  --identity-name "myManagedIdentity" \
  --issuer "${OIDC_ISSUER}" \
  --subject "system:serviceaccount:production:storage-reader"
```

#### AKS-Managed Add-ons

- Azure Monitor (Container Insights)
- Azure Policy for AKS
- Application Gateway Ingress Controller (AGIC)
- Open Service Mesh (deprecated, migrating to Istio)
- Istio-based service mesh (AKS add-on)
- Secret Store CSI Driver (Azure Key Vault integration)
- Defender for Containers

**Node Auto Provisioning (Karpenter on AKS)**: GA in early 2026, using Karpenter to dynamically provision nodes matching pending pod requirements.

---

### Google GKE

Google Kubernetes Engine offers two primary modes and an enterprise tier.

#### Autopilot vs Standard

| Feature | Autopilot | Standard |
|---------|-----------|---------|
| Node management | Fully managed by Google | User-managed |
| Billing | Per pod (CPU/memory/GPU) | Per node |
| Security | Hardened by default (Restricted PSS) | Configurable |
| Node access | No SSH to nodes | Full SSH |
| Custom node pools | No | Yes |
| Spot VMs | Yes (auto) | Manual |
| Cost optimization | Automatic | Manual |

**Autopilot** is the recommended choice for most workloads in 2025-2026. Autopilot clusters are registered to the project fleet automatically, enabling Config Sync and Policy Controller.

GKE Standard clusters can now also adopt Autopilot features (container-optimized nodes, auto-scaling) without migrating to a dedicated Autopilot cluster.

#### GKE Enterprise Features

**Config Sync** (GitOps at scale):
```yaml
# RootSync: sync cluster-level config from Git
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: https://github.com/myorg/kubernetes-config
    branch: main
    dir: clusters/production
    auth: ssh
    secretRef:
      name: git-creds
```

**Policy Controller** (OPA Gatekeeper-based):
```yaml
# Constraint Template
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: requireresourcelimits
spec:
  crd:
    spec:
      names:
        kind: RequireResourceLimits
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package requireresourcelimits
      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        not container.resources.limits
        msg := sprintf("Container %v must have resource limits", [container.name])
      }
```

**Multi-Cluster:**
- Multi-Cluster Services (MCS): expose services across clusters with a single DNS name
- Multi-Cluster Ingress: route traffic to multiple regional clusters from a single Global Load Balancer
- Fleet management: centralized RBAC and policy across all registered clusters

#### Node Auto Provisioning (GKE NAP)

GKE's NAP (backed by Cluster Autoscaler, not Karpenter) automatically creates new node pools when no existing pool satisfies pending pod requirements.

---

## OpenShift 4.x

OpenShift Container Platform (OCP) is Red Hat's enterprise Kubernetes distribution. OKD is the upstream community edition (uses Fedora CoreOS instead of RHCOS).

### OCP vs OKD

| Aspect | OCP | OKD |
|--------|-----|-----|
| Vendor | Red Hat (IBM) | Community |
| OS | Red Hat CoreOS (RHCOS) | Fedora CoreOS |
| Support | Enterprise SLA | Community |
| Updates | Integrated OTA (MCO) | Manual |
| Registry | Red Hat Catalog | Community |
| Operators | OperatorHub (certified) | OperatorHub (community) |

### Architecture

OpenShift layers on top of Kubernetes and adds:
- **Operator Lifecycle Manager (OLM)**: manages Operator installation and lifecycle
- **OperatorHub**: marketplace for Operators (Red Hat certified, community, partner)
- **Integrated image registry**: built-in registry at `image-registry.openshift-image-registry.svc`
- **Routes**: OpenShift-specific L7 routing (predates Ingress; now both supported)
- **Machine Config Operator (MCO)**: manages node OS configuration as code
- **Cluster Operators**: all platform components managed as Operators
- **OpenShift Monitoring**: Prometheus + Alertmanager + Grafana stack, pre-installed
- **OpenShift Logging**: Elasticsearch/Loki + Kibana log aggregation

### Security Context Constraints (SCC)

OpenShift's SCC is an older, more granular alternative to Pod Security Standards. SCCs exist in the `security.openshift.io` API group:

```yaml
# Check which SCC a pod uses
oc get pod mypod -o yaml | grep openshift.io/scc

# Grant SCC to ServiceAccount
oc adm policy add-scc-to-user anyuid -z my-service-account -n myproject

# List available SCCs
oc get scc
```

Built-in SCCs (from most to least restrictive):
- `restricted-v2` — default, no root, no privilege escalation (aligns with K8s Restricted PSS)
- `restricted` — legacy default
- `baseline` — aligns with K8s Baseline PSS
- `nonroot` — non-root users only
- `anyuid` — any UID
- `hostaccess` — host path access
- `hostmount-anyuid` — host path mounts
- `hostnetwork-v2` / `hostnetwork` — host network namespace
- `node-exporter` — for node metrics
- `privileged` — fully privileged, no restrictions

### Routes vs Ingress

```yaml
# OpenShift Route
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: myapp
spec:
  host: myapp.apps.cluster.example.com
  to:
    kind: Service
    name: myapp
    weight: 100
  port:
    targetPort: 8080
  tls:
    termination: edge      # edge | passthrough | reencrypt
    insecureEdgeTerminationPolicy: Redirect

# Standard Ingress also works in OpenShift 4.x
# Routes offer more TLS options and are more native
```

### BuildConfigs and ImageStreams

```yaml
# BuildConfig: source-to-image (S2I) build
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
  output:
    to:
      kind: ImageStreamTag
      name: myapp:latest
  triggers:
  - type: GitHub
    github:
      secret: mysecret
  - type: ImageChange

# ImageStream: tracks image tags and automatically triggers updates
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: myapp
spec:
  lookupPolicy:
    local: true
```

### OperatorHub and OLM

```bash
# Install an Operator via CLI
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cert-manager
  namespace: openshift-operators
spec:
  channel: stable
  name: cert-manager
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

# Check installed operators
oc get csv -A               # ClusterServiceVersions
oc get installplans -A
```

---

## Rancher 2.x

SUSE Rancher is a multi-cluster Kubernetes management platform supporting clusters wherever they run: cloud, on-premises, edge.

### Kubernetes Distributions

| Distribution | Target | Binary Size | Notes |
|-------------|--------|-------------|-------|
| RKE2 | Enterprise on-prem | ~220MB | CIS hardened, FIPS 140-2, replaces RKE |
| K3s | Edge / IoT | <100MB | Single binary, SQLite default (etcd optional) |
| RKE (legacy) | On-prem | Large | Deprecated; migrate to RKE2 |

**RKE2 features**: built-in etcd, CIS hardening profiles, containerd runtime, Canal CNI (Calico + Flannel), integrated audit logging. Uses the same `containerd` and `runc` stack as upstream K8s.

**K3s features**: embeds containerd, kube-proxy, flannel (optional), traefik ingress, local-path-provisioner. Fully OCI-conformant. Suitable for Raspberry Pi to production edge.

### Provisioning v2 (CAPI-based)

Rancher's Provisioning v2 uses Cluster API (CAPI) under the hood to manage RKE2 and K3s cluster lifecycles:

```yaml
# RKE2 cluster provisioned via Rancher
apiVersion: provisioning.cattle.io/v1
kind: Cluster
metadata:
  name: my-rke2-cluster
  namespace: fleet-default
spec:
  kubernetesVersion: v1.35.x+rke2r1
  rkeConfig:
    machineGlobalConfig:
      cni: calico
    machinePools:
    - name: control-plane
      controlPlaneRole: true
      quantity: 3
      machineConfigRef:
        kind: VmwarevsphereConfig
        name: control-plane-config
    - name: workers
      workerRole: true
      quantity: 5
```

### Fleet GitOps

Fleet is Rancher's GitOps engine for deploying to hundreds or thousands of clusters simultaneously:

```yaml
# fleet.yaml in your Git repository
defaultNamespace: production
helm:
  chart: ./charts/myapp
  version: 1.5.0
  values:
    replicaCount: 3
    image:
      tag: v2.0
targets:
  - name: production
    clusterSelector:
      matchLabels:
        env: production
  - name: staging
    clusterSelector:
      matchLabels:
        env: staging
    helm:
      values:
        replicaCount: 1
```

Fleet treats the Git repository as the source of truth. `GitRepo` objects define which repos Fleet monitors:

```yaml
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: myapp-config
  namespace: fleet-local
spec:
  repo: https://github.com/myorg/fleet-config
  branch: main
  paths:
  - apps/myapp
  targets:
  - name: all-clusters
    clusterSelector: {}
```

### Harvester HCI

Harvester is SUSE's open-source HCI (Hyperconverged Infrastructure) solution built on Kubernetes:
- Based on KubeVirt (VMs as Kubernetes resources)
- Built on RKE2
- Longhorn for distributed storage
- Integrates with Rancher for guest K8s cluster provisioning
- VMs, containers, and storage managed through Rancher UI

```yaml
# VM in Harvester (KubeVirt-based)
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: ubuntu-vm
  namespace: default
spec:
  running: true
  template:
    spec:
      domain:
        resources:
          requests:
            memory: 4Gi
            cpu: "2"
        devices:
          disks:
          - name: rootdisk
            disk:
              bus: virtio
      volumes:
      - name: rootdisk
        persistentVolumeClaim:
          claimName: ubuntu-rootdisk
```

### Multi-Cluster Management at Scale

- Rancher server runs on a dedicated K3s or RKE2 cluster
- Recommended sizing: 4 vCPU + 8GB RAM per 10 managed clusters
- Authentication: integrates with Active Directory, LDAP, SAML, GitHub, Google, Keycloak
- Multi-tenancy: Projects (namespace groupings), multi-cluster RBAC
- Monitoring: cluster-wide Prometheus + Grafana stack deployed per cluster via Rancher monitoring app
- CIS scanning: built-in CIS Kubernetes benchmark scanning

---

## References

- [Helm 4 Overview](https://helm.sh/docs/overview/)
- [Helm 4.0 Features & Breaking Changes](https://alexandre-vazquez.com/helm-40/)
- [EKS Karpenter Best Practices](https://docs.aws.amazon.com/eks/latest/best-practices/karpenter.html)
- [AKS Automatic vs EKS Auto Mode vs GKE Autopilot](https://engineering.01cloud.com/2025/10/09/aks-automatic-vs-aws-eks-auto-mode-and-gke-autopilot-simplified-kubernetes-showdown/)
- [GKE Autopilot Overview](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [GKE Enterprise Configuration Management](https://timberry.dev/configuration-management-in-gke-enterprise)
- [OpenShift SCC Documentation](https://andreaskaris.github.io/blog/openshift/scc/)
- [OKD 4.19 Overview](https://docs.okd.io/4.19/welcome/ocp-overview.html)
- [Rancher Enterprise K8s Management 2025](https://www.baytechconsulting.com/blog/rancher-enterprise-kubernetes-management-2025)
- [Rancher in Practice: Managing 50+ Clusters](https://timderzhavets.com/blog/rancher-in-practice-managing-50-kubernetes-clusters/)
