# Amazon EKS Architecture Reference

Deep technical detail on EKS control plane, compute, networking, and storage architecture.

---

## Control Plane Architecture

EKS runs the Kubernetes control plane across 3 Availability Zones in the selected region:

```
                      ┌─────────────────────────┐
                      │   EKS Managed VPC        │
                      │                           │
Internet ──→ NLB ──→  │  API Server (AZ-a)       │
                      │  API Server (AZ-b)       │
                      │  API Server (AZ-c)       │
                      │                           │
                      │  etcd (AZ-a)             │
                      │  etcd (AZ-b)             │
                      │  etcd (AZ-c)             │
                      └────────────┬──────────────┘
                                   │
                      ENI injected into customer VPC
                                   │
                      ┌────────────┴──────────────┐
                      │   Customer VPC             │
                      │   Worker Nodes             │
                      └───────────────────────────┘
```

**Cross-account ENI**: EKS injects ENIs from the managed VPC into the customer VPC for API server → kubelet communication. These ENIs appear in the customer's VPC but are managed by AWS.

**Endpoint access modes**:
- **Public**: API server accessible from the internet. Requests from within VPC still go through the internet.
- **Private**: API server accessible only from within the VPC (via ENIs). Requires VPN or Direct Connect for external access.
- **Public + Private**: API server accessible from internet and from VPC. Requests from within VPC use the private endpoint (ENIs). Recommended for most production clusters.

**Cluster security group**: automatically created. Applied to the cross-account ENIs and (optionally) to managed node groups. Controls communication between control plane and data plane.

### Upgrade Process

1. AWS launches new API server instances with the target version
2. New instances join behind the NLB
3. Old instances are drained and terminated
4. etcd is upgraded in-place (rolling, one member at a time)
5. Upgrade is complete when all control plane components are running the new version

**During upgrade**: the API server remains available (rolling update). Brief periods of mixed-version API servers may occur. Webhook configurations should be compatible with both versions.

**After control plane upgrade**: update managed node groups, Fargate profiles, and add-ons separately. Nodes can be up to 3 minor versions behind the control plane (Kubernetes skew policy: n-3 for kubelet).

---

## Karpenter Deep Dive

### Provisioning Flow

```
1. Pod created with resource requests
2. Scheduler cannot find a suitable node → Pod is Pending
3. Karpenter controller detects Pending pods
4. Karpenter evaluates NodePool requirements
5. Karpenter batches Pending pods (within 10s window)
6. Karpenter selects optimal instance type(s) from EC2 fleet
7. Karpenter launches EC2 instance via CreateFleet API
8. Node joins cluster (kubelet registers with API server)
9. Pods are scheduled to the new node
```

**Instance type selection**: Karpenter considers all instance types matching the NodePool requirements and selects the cheapest combination that fits all pending pods. It can bin-pack multiple pods onto a single large instance or spread across smaller instances.

### Consolidation

Karpenter continuously evaluates running nodes for consolidation:

- **WhenUnderutilized**: consolidate when a node's pods could fit on other existing nodes
- **WhenEmpty**: only consolidate when a node has no non-DaemonSet pods

**Consolidation process**:
1. Identify underutilized node
2. Find target nodes that can absorb the pods (respecting affinity, topology, PDBs)
3. Cordon the source node
4. Drain pods (respecting PDBs and `do-not-disrupt` annotation)
5. Terminate the EC2 instance

**Disruption budgets**: control how many nodes Karpenter can disrupt simultaneously:
```yaml
disruption:
  budgets:
  - nodes: "10%"          # max 10% of nodes disrupted at once
  - nodes: "0"            # during specific schedule
    schedule: "0 9 * * 1-5"
    duration: 8h
```

### Spot Instance Handling

```yaml
requirements:
- key: karpenter.sh/capacity-type
  operator: In
  values: ["spot", "on-demand"]
```

Karpenter uses EC2 Fleet with `capacity-optimized` allocation strategy for spot. If spot capacity is unavailable, it falls back to on-demand automatically.

**Spot interruption handling**: Karpenter watches for EC2 spot interruption notices (2-minute warning) and proactively cordons and drains the node.

---

## VPC CNI Architecture

### IP Address Management

**Secondary IP mode** (default):
```
Node ENI-0 (primary): node IP
Node ENI-1: secondary IPs → assigned to pods
Node ENI-2: secondary IPs → assigned to pods
...
```

Max pods = (max ENIs - 1) * (max IPs per ENI - 1) + 2

Example: m5.xlarge = (4-1) * (15-1) + 2 = 44 pods max (reduced further by system pods)

**Prefix delegation mode**:
```
Node ENI-0 (primary): node IP
Node ENI-1: /28 prefixes → 16 IPs per prefix → assigned to pods
Node ENI-2: /28 prefixes → 16 IPs per prefix → assigned to pods
```

Max pods increases significantly. m5.xlarge with prefix delegation: (4-1) * (15-1) * 16 = ~672 theoretical (limited by `max-pods` setting, typically 110).

**Environment variables (aws-node DaemonSet)**:
```
ENABLE_PREFIX_DELEGATION=true       # Enable prefix delegation
WARM_PREFIX_TARGET=1                 # Prefixes to keep warm
WARM_IP_TARGET=5                     # IPs to keep warm (secondary IP mode)
MINIMUM_IP_TARGET=10                 # Minimum IPs to maintain
AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true  # Custom networking
```

### Custom Networking

Pods use a different subnet than the node's primary interface:

```yaml
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
  name: us-east-1a
spec:
  subnet: subnet-0123456789abcdef0     # pod subnet in AZ-a
  securityGroups:
  - sg-0123456789abcdef0
```

**Use cases**: node subnet has limited IPs; pods need to be in a different CIDR range for routing/firewall rules; secondary CIDR added to VPC for pod IPs (100.64.0.0/16).

### Network Policy

VPC CNI supports Kubernetes NetworkPolicy natively (since VPC CNI v1.14+). Enable with:
```bash
aws eks create-addon --cluster-name prod --addon-name vpc-cni \
  --configuration-values '{"enableNetworkPolicy": "true"}'
```

Alternative: install Calico or Cilium as the network policy engine alongside VPC CNI.

---

## Storage Architecture

### EBS CSI Driver

Provisions EBS volumes as PersistentVolumes:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
  kmsKeyId: arn:aws:kms:REGION:ACCOUNT:key/KEY_ID
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer    # bind in the AZ where pod is scheduled
```

**Critical**: EBS volumes are AZ-scoped. `WaitForFirstConsumer` ensures the volume is created in the same AZ as the pod. Without this, a PV could be created in AZ-a while the pod is scheduled to AZ-b.

### EFS CSI Driver

Shared filesystem (ReadWriteMany):

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-0123456789abcdef0
  directoryPerms: "700"
  basePath: "/dynamic-provisioning"
```

EFS supports `ReadWriteMany` -- multiple pods across multiple nodes can mount the same volume simultaneously.

---

## Security Architecture

### Envelope Encryption

EKS can encrypt Kubernetes Secrets with a customer-managed KMS key:

```bash
aws eks create-cluster \
  --name prod \
  --encryption-config '[{"resources":["secrets"],"provider":{"keyArn":"arn:aws:kms:REGION:ACCOUNT:key/KEY_ID"}}]'
```

Double encryption: Kubernetes Secrets are encrypted with a DEK (data encryption key), which is encrypted with the KMS CMK. The DEK is cached in memory on the API server.

### Security Groups

Three layers of security groups:
1. **Cluster security group**: communication between control plane ENIs and worker nodes
2. **Node security group**: additional rules for worker node communication
3. **Pod security groups**: per-pod security groups via SecurityGroupPolicy CRD

### OIDC Provider

Every EKS cluster has an OIDC provider URL. This provider issues tokens to ServiceAccounts that can be exchanged for IAM credentials (IRSA) or used for other OIDC-aware systems.

```bash
# Get OIDC provider URL
aws eks describe-cluster --name prod --query "cluster.identity.oidc.issuer"

# Associate with IAM
eksctl utils associate-iam-oidc-provider --cluster prod --approve
```

---

## EKS Anywhere

Run EKS on your own infrastructure:

| Provider | Infrastructure |
|----------|---------------|
| vSphere | VMware ESXi clusters |
| Bare Metal | Tinkerbell provisioner |
| Nutanix | Nutanix AHV |
| Snow | AWS Snow Family devices (edge) |
| CloudStack | Apache CloudStack |

EKS Anywhere clusters run the same Kubernetes distribution as EKS (Bottlerocket or Ubuntu nodes) and can be managed by EKS Connector from the AWS console.

**Curated packages**: EKS Anywhere includes curated versions of Harbor (registry), Emissary (ingress), MetalLB (load balancer), and Prometheus.

---

## Observability

### Container Insights

CloudWatch Container Insights provides metrics and logs:

```bash
# Enable via Fluent Bit DaemonSet
aws eks create-addon --cluster-name prod --addon-name amazon-cloudwatch-observability
```

Metrics collected: CPU, memory, network, disk per pod/node/cluster. Logs: application stdout/stderr, node system logs.

### ADOT (AWS Distro for OpenTelemetry)

Vendor-neutral observability pipeline:

```bash
aws eks create-addon --cluster-name prod --addon-name adot
```

Collects metrics and traces, exports to CloudWatch, X-Ray, Prometheus, or third-party backends.

### Prometheus Managed Service (AMP)

```bash
# Create AMP workspace
aws amp create-workspace --alias prod-metrics

# Configure Prometheus remote write from the cluster
# (via ADOT collector or self-managed Prometheus)
```
