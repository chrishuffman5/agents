# Azure AKS Architecture Reference

Deep technical detail on AKS control plane, networking, identity, and storage architecture.

---

## Control Plane Architecture

AKS runs the Kubernetes control plane as a managed Azure service:

```
                    ┌──────────────────────────┐
                    │  Azure Managed Infra       │
                    │                            │
                    │  API Server (zonal HA)     │
                    │  etcd (zonal HA)           │
                    │  Controller Manager        │
                    │  Scheduler                 │
                    │  Cloud Controller Manager  │
                    └───────────┬────────────────┘
                                │
                    Tunnel (konnectivity/aks-link)
                                │
                    ┌───────────┴────────────────┐
                    │  Customer VNet              │
                    │  Node Pool Subnet(s)        │
                    │  System Node Pool           │
                    │  User Node Pool(s)          │
                    └────────────────────────────┘
```

**API server communication**: AKS uses a tunneled connection from the managed control plane to the customer VNet. The tunnel agent runs on nodes and maintains a persistent connection to the control plane.

**Private cluster**: API server gets a private IP in the customer VNet (via Private Link). No public endpoint. Requires VPN or ExpressRoute for external access.

```bash
az aks create --resource-group myRG --name myAKS \
  --enable-private-cluster \
  --private-dns-zone system    # system | none | custom-zone-id
```

### Upgrade Channels

| Channel | Behavior |
|---------|----------|
| `none` | Manual upgrades only |
| `patch` | Auto-apply latest patch version |
| `stable` | Auto-apply latest GA-1 minor version |
| `rapid` | Auto-apply latest GA minor version |
| `node-image` | Auto-apply latest node image (weekly) |

```bash
az aks update --resource-group myRG --name myAKS --auto-upgrade-channel stable
```

**Planned maintenance windows**: schedule when automatic upgrades can occur to avoid business-hours disruption.

---

## Node Pool Architecture

### Virtual Machine Scale Sets (VMSS)

Each node pool is backed by an Azure VMSS:
- Uniform mode (default): all VMs use the same configuration
- AKS manages scaling, updates, and image rotation
- Node image upgrades: AKS periodically releases new node images with OS patches

**Node image**: contains the OS, containerd, kubelet, and kube-proxy. AKS releases new images ~weekly.

```bash
# Check current node image version
az aks nodepool show --resource-group myRG --cluster-name myAKS \
  --name workers --query nodeImageVersion

# Upgrade node image
az aks nodepool upgrade --resource-group myRG --cluster-name myAKS \
  --name workers --node-image-only
```

### Node Pool Best Practices

1. **System pool**: 3 nodes, Standard_D4s_v5 or larger, tainted with `CriticalAddonsOnly=true:NoSchedule`
2. **General worker pool**: autoscaler enabled, Standard_D4s_v5 to Standard_D8s_v5
3. **GPU pool**: tainted `sku=gpu:NoSchedule`, scaled to zero when not needed
4. **Spot pool**: for batch/CI workloads, `--min-count 0` to scale to zero

### OS Options

- **Ubuntu** (default for Linux pools): full-featured Linux
- **Azure Linux** (formerly Mariner): Microsoft's container-optimized Linux, smaller image, faster boot
- **Windows Server 2022**: for Windows containers (requires separate node pool)

```bash
az aks nodepool add --resource-group myRG --cluster-name myAKS \
  --name azlinux --os-sku AzureLinux --node-count 3
```

---

## Networking Deep Dive

### kubenet

Simplest option. Pods get IPs from a separate address space (not VNet IPs):
- Node gets a VNet IP
- Pods get IPs from `--pod-cidr` (default 10.244.0.0/16)
- AKS creates UDR (User Defined Routes) for cross-node pod traffic
- NAT applied for pod → VNet communication

**Limitations**: max 400 nodes, no VNet integration for pods, Azure NetworkPolicy not supported (Calico only).

### Azure CNI

Pods get real VNet IPs from the node subnet:
- Every pod consumes a VNet IP
- Pre-allocated: each node reserves `max-pods` IPs at creation (default 30 or 250 depending on mode)
- Direct VNet routing for pod traffic (no NAT, no UDR)

**IP planning**: subnet size must accommodate `(nodes * max-pods) + nodes + overhead`. For 10 nodes with max-pods=30: need ~310 IPs minimum.

### Azure CNI Overlay

Pods get IPs from a private overlay CIDR, nodes get VNet IPs:
- Pod CIDR: configurable (e.g., 10.244.0.0/16)
- Node CIDR: from VNet subnet
- VXLAN encapsulation for cross-node pod traffic
- No IP exhaustion concerns (overlay IPs are free)

```bash
az aks create --resource-group myRG --name myAKS \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --pod-cidr 10.244.0.0/16
```

**Recommended for most new clusters**: combines VNet integration (for node-level services, load balancers) with unlimited pod IP space.

### Azure CNI with Cilium

eBPF-based dataplane replacing kube-proxy:

```bash
az aks create --resource-group myRG --name myAKS \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --network-dataplane cilium
```

**Benefits**:
- kube-proxy replacement (eBPF-based service load balancing)
- NetworkPolicy enforcement in eBPF (faster than iptables)
- Hubble observability (network flow logs, DNS visibility)
- FQDN-based NetworkPolicy (egress to specific domains)

---

## Identity Architecture

### Cluster Identity

AKS uses a managed identity (system-assigned or user-assigned) for cluster operations:

```bash
# System-assigned (Azure manages the identity)
az aks create --resource-group myRG --name myAKS --enable-managed-identity

# User-assigned (you control the identity)
az aks create --resource-group myRG --name myAKS \
  --assign-identity /subscriptions/SUB/resourceGroups/RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myIdentity
```

The cluster identity needs permissions to manage infrastructure (load balancers, public IPs, disks, route tables).

### Kubelet Identity

Separate managed identity for kubelet (node-level operations like pulling images from ACR):

```bash
az aks create --resource-group myRG --name myAKS \
  --assign-kubelet-identity /subscriptions/SUB/.../myKubeletIdentity

# Grant ACR pull permission
az role assignment create \
  --assignee <kubelet-identity-client-id> \
  --role AcrPull \
  --scope /subscriptions/SUB/resourceGroups/RG/providers/Microsoft.ContainerRegistry/registries/myACR
```

### Workload Identity Flow

```
1. Pod starts with ServiceAccount labeled azure.workload.identity/use=true
2. Workload Identity webhook injects:
   - AZURE_CLIENT_ID environment variable
   - AZURE_TENANT_ID environment variable
   - AZURE_FEDERATED_TOKEN_FILE (projected SA token)
3. Azure SDK in the app reads these variables
4. SDK exchanges the projected SA token for an Azure AD token via OIDC federation
5. App authenticates to Azure services with the Azure AD token
```

**Key difference from IRSA**: AKS Workload Identity uses Azure AD federated credentials (not STS AssumeRoleWithWebIdentity). The trust relationship is between the AKS OIDC issuer and the Azure AD application/managed identity.

---

## Storage Architecture

### Azure Disk CSI

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-premium-zrs
provisioner: disk.csi.azure.com
parameters:
  skuName: PremiumV2_LRS    # Premium_LRS, StandardSSD_LRS, Premium_ZRS, etc.
  cachingMode: None           # None for PremiumV2
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

**Disk types**:
- Standard HDD (Standard_LRS): dev/test
- Standard SSD (StandardSSD_LRS): light production
- Premium SSD (Premium_LRS): production workloads
- Premium SSD v2 (PremiumV2_LRS): high-performance, configurable IOPS/throughput
- Ultra Disk: extreme IOPS (up to 160,000)

**ZRS (Zone-Redundant Storage)**: replicate disk across 3 AZs. Supports Premium_ZRS and StandardSSD_ZRS. Enables pod failover across zones without data loss.

### Azure Files CSI

Shared filesystem (ReadWriteMany):

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-files-premium
provisioner: file.csi.azure.com
parameters:
  skuName: Premium_LRS
  protocol: nfs              # smb (default) or nfs
reclaimPolicy: Delete
allowVolumeExpansion: true
mountOptions:
  - nconnect=4               # parallel NFS connections for throughput
```

**NFS vs SMB**: NFS offers better performance for Linux workloads. SMB is required for Windows pods.

### Azure Blob CSI

Mount Azure Blob containers as volumes using BlobFuse2 or NFS 3.0:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: blob-nfs
provisioner: blob.csi.azure.com
parameters:
  protocol: nfs
```

---

## Security Architecture

### Defender for Containers

Real-time threat detection:
- Node-level: detects crypto mining, reverse shells, suspicious processes
- Control plane: detects RBAC abuse, exposed dashboards, anonymous auth
- Registry: scans ACR images for vulnerabilities
- Network: detects communication with known malicious IPs

### Azure Policy for AKS

OPA/Gatekeeper-based policy enforcement:

```bash
az aks enable-addons --resource-group myRG --name myAKS --addons azure-policy
```

Built-in policy initiatives:
- **Baseline**: restrict host namespaces, capabilities, volume types
- **Restricted**: enforce non-root, drop all capabilities, read-only root FS
- **Custom**: define custom Rego policies via ConstraintTemplates

### Network Security

- **Azure NSG**: applied to node subnet (controls north-south traffic)
- **NetworkPolicy**: controls east-west pod traffic (requires Azure CNI or Calico)
- **Private cluster**: no public API endpoint
- **Authorized IP ranges**: restrict API server access to specific source IPs
- **Azure Firewall / NVA**: control egress from nodes to the internet

```bash
# Restrict API server access
az aks update --resource-group myRG --name myAKS \
  --api-server-authorized-ip-ranges "203.0.113.0/24,198.51.100.0/24"
```
