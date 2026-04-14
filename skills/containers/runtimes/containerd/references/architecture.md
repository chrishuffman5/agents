# containerd Architecture Deep Dive

## Daemon Architecture

### Process Model

```
containerd (single daemon process)
  |-- gRPC Server (unix:///run/containerd/containerd.sock)
  |     |-- Content Service
  |     |-- Images Service
  |     |-- Containers Service
  |     |-- Tasks Service (runtime operations)
  |     |-- Snapshots Service
  |     |-- Leases Service (garbage collection)
  |     |-- Namespaces Service
  |     |-- Events Service
  |     |-- Transfer Service (image movement)
  |     |-- Sandbox Service (pod lifecycle)
  |     +-- Introspection Service (plugins)
  |
  |-- Plugin System (everything is a plugin)
  |     |-- CRI plugin (io.containerd.grpc.v1.cri)
  |     |-- Runtime plugin (io.containerd.runtime.v2.task)
  |     |-- Snapshotter plugins
  |     |-- Content plugin
  |     |-- Metadata plugin (BoltDB)
  |     |-- NRI plugin
  |     +-- Differ plugin
  |
  +-- Shim Management
        |-- containerd-shim-runc-v2 (one per container/pod)
        |-- containerd-shim-kata-v2
        +-- containerd-shim-runsc-v1
```

### Configuration (config.toml v3)

```toml
# /etc/containerd/config.toml
version = 3

# Global settings
root = "/var/lib/containerd"
state = "/run/containerd"
oom_score = -999

[grpc]
  address = "/run/containerd/containerd.sock"
  max_recv_message_size = 16777216
  max_send_message_size = 16777216

[debug]
  address = "/run/containerd/debug.sock"
  level = "info"    # debug, info, warn, error

[metrics]
  address = "127.0.0.1:1338"
  grpc_histogram = false

# CRI plugin configuration
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "registry.k8s.io/pause:3.10"
  max_container_log_line_size = 16384
  enable_cdi = true                    # Container Device Interface

  [plugins."io.containerd.grpc.v1.cri".containerd]
    snapshotter = "overlayfs"
    default_runtime_name = "runc"

    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        SystemdCgroup = true
        BinaryName = "/usr/bin/runc"

    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
      runtime_type = "io.containerd.kata.v2"
      pod_annotations = ["io.katacontainers.*"]

    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.gvisor]
      runtime_type = "io.containerd.runsc.v1"

  [plugins."io.containerd.grpc.v1.cri".cni]
    bin_dir = "/opt/cni/bin"
    conf_dir = "/etc/cni/net.d"

  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"

# NRI configuration
[plugins."io.containerd.nri.v1.nri"]
  disable = false
  socket_path = "/var/run/nri/nri.sock"
  plugin_path = "/opt/nri/plugins"
  plugin_registration_timeout = "5s"
  plugin_request_timeout = "2s"

# Proxy plugin example (stargz snapshotter)
[proxy_plugins.stargz]
  type = "snapshot"
  address = "/run/containerd-stargz-grpc/containerd-stargz-grpc.sock"
```

## CRI Implementation Details

### Kubernetes Integration Flow

```
kubelet
  |-- CRI gRPC call (RunPodSandbox, CreateContainer, StartContainer, etc.)
  |
  containerd CRI plugin
  |-- RunPodSandbox
  |     |-- Pull pause image
  |     |-- Create sandbox container (pause)
  |     |-- Set up network namespace (CNI)
  |     |-- Start sandbox (holds network namespace)
  |
  |-- CreateContainer
  |     |-- Pull container image
  |     |-- Prepare snapshotter (unpack layers)
  |     |-- Create OCI spec (from CRI ContainerConfig)
  |     |-- Create containerd container
  |
  |-- StartContainer
  |     |-- Create shim process
  |     |-- Shim calls runc to create container process
  |     |-- Container joins sandbox's network namespace
  |
  |-- StopContainer
  |     |-- Send SIGTERM, wait for graceful shutdown
  |     |-- Send SIGKILL if timeout exceeded
  |
  |-- RemoveContainer
  |     |-- Delete shim
  |     |-- Remove snapshotter artifacts
  |
  +-- StopPodSandbox / RemovePodSandbox
        |-- Stop/remove all containers in the sandbox
        |-- Tear down CNI network
        |-- Remove sandbox container
```

### RuntimeClass (Multiple Runtimes)

Kubernetes can select different runtimes per Pod via RuntimeClass:

```yaml
# RuntimeClass definition
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata    # matches runtime name in config.toml

---
# Pod using RuntimeClass
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  runtimeClassName: kata    # runs in Kata VM
  containers:
  - name: app
    image: myapp:latest
```

## Snapshotter Deep Dive

### overlayfs Snapshotter (Default)

```
Image layer 1 (base): /var/lib/containerd/.../snapshots/1/fs/
Image layer 2:        /var/lib/containerd/.../snapshots/2/fs/
Image layer 3:        /var/lib/containerd/.../snapshots/3/fs/
Container (active):   /var/lib/containerd/.../snapshots/4/fs/  (writable)

Overlay mount:
  lowerdir=snapshots/1/fs:snapshots/2/fs:snapshots/3/fs
  upperdir=snapshots/4/fs
  workdir=snapshots/4/work
  merged -> container rootfs
```

### Stargz Remote Snapshotter

eStargz (seekable tar gzip) format enables lazy pulling:

1. Image is pushed in eStargz format with a table of contents (TOC)
2. On pull, only the TOC is downloaded (~1% of image size)
3. Container starts immediately
4. File contents are fetched on-demand from the registry via HTTP range requests
5. Prefetch hints in the TOC optimize access patterns

```bash
# Convert standard image to eStargz
ctr-remote image optimize docker.io/library/node:22 \
  registry.example.com/node:22-esgz

# Configure in config.toml
[proxy_plugins.stargz]
  type = "snapshot"
  address = "/run/containerd-stargz-grpc/containerd-stargz-grpc.sock"
```

### Nydus Snapshotter

Nydus uses RAFS (Registry Acceleration File System) v6 format:
- Block-level deduplication (vs stargz's file-level)
- Better compression ratios than eStargz
- Chunk-level caching with pluggable backends (local, S3, OSS)
- Compatible with EROFS (Enhanced Read-Only File System) in kernel

## NRI Architecture

### Plugin Lifecycle

```
1. containerd starts -> NRI broker initializes
2. NRI plugin connects via Unix socket
3. Plugin receives Synchronize() with current state
4. Plugin receives lifecycle events:
   - RunPodSandbox / StopPodSandbox
   - CreateContainer / PostCreateContainer
   - StartContainer / PostStartContainer
   - UpdateContainer / PostUpdateContainer
   - StopContainer
   - RemoveContainer / RemovePodSandbox
5. Plugin returns adjustments (modify OCI spec, resources, devices)
```

### ContainerAdjustment

Plugins can modify container specifications via ContainerAdjustment:

```go
type ContainerAdjustment struct {
    Annotations map[string]string
    Mounts      []*Mount
    Env         []*KeyValue
    Hooks       *Hooks
    Linux       *LinuxContainerAdjustment  // resources, devices, cgroups
    Rlimits     []*POSIXRlimit
}

type LinuxContainerAdjustment struct {
    Devices   []*LinuxDevice
    Resources *LinuxResources   // CPU, memory, hugepages
    CgroupsPath string
}
```

### Common NRI Plugin Use Cases

**Topology-aware scheduling:**
```
Pod annotation: topology.nri/cpu-affinity=0-3
NRI plugin reads annotation -> sets cpuset.cpus=0-3 in container cgroup
```

**Device injection:**
```
Pod annotation: devices.nri/gpu=nvidia0
NRI plugin reads annotation -> adds /dev/nvidia0 to container devices
```

**Resource balancing:**
```
NRI plugin monitors node CPU pressure
When pressure detected -> reduces CPU quota of best-effort containers
```

## Sandbox API Deep Dive

### API Operations

```protobuf
service Controller {
  rpc Create(ControllerCreateRequest) returns (ControllerCreateResponse);
  rpc Start(ControllerStartRequest) returns (ControllerStartResponse);
  rpc Platform(ControllerPlatformRequest) returns (ControllerPlatformResponse);
  rpc Stop(ControllerStopRequest) returns (ControllerStopResponse);
  rpc Wait(ControllerWaitRequest) returns (ControllerWaitResponse);
  rpc Status(ControllerStatusRequest) returns (ControllerStatusResponse);
  rpc Shutdown(ControllerShutdownRequest) returns (ControllerShutdownResponse);
  rpc Metrics(ControllerMetricsRequest) returns (ControllerMetricsResponse);
  rpc Update(ControllerUpdateRequest) returns (ControllerUpdateResponse);  // containerd 2.x
}
```

### VM-Based Runtime Integration

For Kata Containers / Firecracker:
1. `Create` starts the VM (allocates vCPUs, memory)
2. `Start` boots the VM kernel
3. Container operations (`CreateContainer`) run processes inside the VM
4. `Update` can resize VM resources (add vCPUs, memory)
5. `Stop` shuts down the VM

This separation enables clean resource lifecycle management that the traditional pod sandbox model cannot provide.

## Transfer Service

### Architecture

```
Transfer source (registry, archive, OCI dir)
  |
  Transfer Service
  |-- Authentication (credentials, tokens)
  |-- Content negotiation (OCI vs Docker media types)
  |-- Parallel layer downloads (configurable concurrency)
  |-- Verification (digest matching, signature checking)
  |-- Decompression (gzip, zstd)
  |-- Snapshotter integration (unpack layers)
  |
  Transfer destination (content store, registry, archive)
```

### Usage

```bash
# Registry to registry transfer
ctr transfer docker.io/library/nginx:latest localhost:5000/nginx:latest

# Archive to containerd
ctr transfer --local archive.tar containerd://nginx:latest

# Containerd to archive
ctr transfer containerd://nginx:latest --local /tmp/nginx.tar
```

## Garbage Collection

containerd uses a reference-counting system with leases:

```bash
# List leases
ctr leases ls

# Manual garbage collection
ctr content gc

# Garbage collection removes:
# - Unreferenced content blobs
# - Unused snapshotter data
# - Expired leases
```

Leases prevent content from being garbage collected while in use. Images, containers, and tasks hold leases on their content.

## Metrics and Monitoring

containerd exposes Prometheus metrics at the configured metrics address:

```
# Key metrics:
containerd_container_count                    # total containers
containerd_image_count                        # total images
containerd_task_count{status}                 # tasks by status
containerd_grpc_server_handled_total          # gRPC call counts
containerd_grpc_server_handling_seconds       # gRPC latency
containerd_snapshotter_usage_bytes            # snapshotter disk usage
containerd_content_store_bytes                # content store size
```

```bash
# Query metrics
curl http://127.0.0.1:1338/v1/metrics
```

## Operational Commands

```bash
# Check containerd status
systemctl status containerd

# Check containerd version and plugins
ctr version
ctr plugins ls

# Check available snapshotters
ctr plugins ls | grep snapshotter

# List namespaces
ctr namespaces ls

# List containers across all namespaces
for ns in $(ctr namespaces ls -q); do
  echo "=== $ns ==="
  ctr -n $ns containers ls
done

# Check containerd logs
journalctl -u containerd -f

# Validate config
containerd config dump    # show effective config
containerd config default # show default config
```
