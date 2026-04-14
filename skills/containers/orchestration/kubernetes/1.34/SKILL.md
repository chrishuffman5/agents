---
name: containers-orchestration-kubernetes-1-34
description: "Version-specific expert for Kubernetes 1.34 (Of Wind & Will, August 2025). Covers sidecar containers GA, VolumeAttributesClass GA, Windows improvements, and OIDC discovery enhancements. WHEN: \"Kubernetes 1.34\", \"K8s 1.34\", \"sidecar containers GA\", \"VolumeAttributesClass\", \"KEP-753 stable\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Kubernetes 1.34 Version Expert

You are a specialist in Kubernetes 1.34 ("Of Wind & Will"), released August 2025. You know what graduated, what changed, and what moved between alpha/beta/GA in this release.

## Key Graduations to GA

### Sidecar Containers (KEP-753) -- Stable

Native sidecar containers are init containers with `restartPolicy: Always`. They start before regular containers and run for the pod's lifetime, solving long-standing issues with logging agents, proxies, and service mesh sidecars.

```yaml
spec:
  initContainers:
  - name: istio-proxy
    image: istio/proxyv2:1.24
    restartPolicy: Always    # this makes it a sidecar
    ports:
    - containerPort: 15001
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
  - name: log-shipper
    image: fluent/fluent-bit:3.2
    restartPolicy: Always
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  containers:
  - name: app
    image: myapp:v2.0
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
```

**Behavior**:
- Sidecar init containers start in order, each must be running before the next starts
- Regular init containers (without `restartPolicy: Always`) run after all sidecars are started
- App containers start after all init containers complete
- Sidecars are terminated in reverse order after all app containers exit
- Sidecars are included in pod resource calculations (important for LimitRange and ResourceQuota)

**Migration from pre-1.34**: if you previously ran sidecars as regular containers, convert them to init containers with `restartPolicy: Always`. This gives proper startup ordering and shutdown sequencing.

### VolumeAttributesClass (VAC) -- GA

Allows modifying storage attributes (IOPS, throughput, tier) without recreating PVCs.

```yaml
apiVersion: storage.k8s.io/v1beta1
kind: VolumeAttributesClass
metadata:
  name: high-performance
driverName: ebs.csi.aws.com
parameters:
  iops: "10000"
  throughput: "500"
```

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: gp3
  volumeAttributesClassName: high-performance   # apply VAC
  resources:
    requests:
      storage: 100Gi
```

**Use case**: adjust storage performance dynamically (e.g., increase IOPS during peak hours) without PVC recreation or data migration. CSI driver must support the `MODIFY_VOLUME` capability.

## Other Notable Changes

### Windows Container Improvements

- Improved pod networking for Windows nodes
- Better support for HostProcess containers (Windows equivalent of privileged containers)
- Group managed service accounts (gMSA) improvements

### OIDC Discovery Enhancements

- Improved ServiceAccount token OIDC discovery endpoint
- Better integration with external identity providers for workload identity (IRSA, Workload Identity)

### Deprecations in 1.34

- No major API removals
- Continued deprecation of in-tree cloud providers (migration to external cloud-controller-manager)

## Upgrade Notes

When upgrading to 1.34:
1. Sidecar containers are now GA -- if you had feature gate `SidecarContainers` explicitly enabled, it is now always on
2. VolumeAttributesClass is GA -- update any `v1alpha1` VAC manifests to `v1beta1` (or `v1` if supported by your CSI driver)
3. Test sidecar container behavior changes with service mesh deployments (Istio, Linkerd) that may have their own sidecar injection
4. Review in-tree cloud provider deprecation warnings in API server logs

## Version Context

- **Previous**: 1.33 (Octarine) -- nftables kube-proxy beta, topology spread nodeTaintsPolicy GA
- **Next**: 1.35 (Timbernetes) -- user namespaces beta, in-place pod resize beta, DRA enhancements
