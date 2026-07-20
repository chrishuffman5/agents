# Kubernetes Diagnostics Reference

Troubleshooting commands, debug workflows, and diagnostic patterns for Kubernetes.

---

## Pod Not Starting -- Diagnostic Flowchart

```
Pod stuck?
  │
  ├── Status: Pending
  │     ├── No events → Scheduler cannot find a node
  │     │     ├── Check: kubectl describe pod → Events section
  │     │     ├── Insufficient resources? → kubectl describe nodes (look at Allocatable vs Allocated)
  │     │     ├── Taints blocking? → kubectl get nodes -o json | jq '.items[].spec.taints'
  │     │     ├── Affinity/anti-affinity impossible? → Review affinity rules
  │     │     ├── PVC not bound? → kubectl get pvc (check STATUS column)
  │     │     └── ResourceQuota exceeded? → kubectl describe resourcequota -n <ns>
  │     └── Events show "FailedScheduling" → Read the message for specific constraint
  │
  ├── Status: Waiting (ContainerCreating)
  │     ├── Image pull? → kubectl describe pod → Events: "Failed to pull image"
  │     │     ├── Image name typo?
  │     │     ├── Registry auth? → check imagePullSecrets
  │     │     └── Image doesn't exist? → verify tag in registry
  │     ├── Volume mount? → "Unable to attach or mount volumes"
  │     │     ├── PV still attached to another node? (multi-attach error)
  │     │     ├── CSI driver not installed?
  │     │     └── Storage class doesn't exist?
  │     └── CNI error? → "network plugin not ready"
  │
  ├── Status: CrashLoopBackOff
  │     ├── kubectl logs <pod> → check application logs
  │     ├── kubectl logs <pod> --previous → logs from last crashed container
  │     ├── Exit code 1 → application error
  │     ├── Exit code 137 → OOMKilled (check memory limits)
  │     ├── Exit code 139 → Segfault
  │     └── Exit code 126/127 → Command not found / permission denied
  │
  ├── Status: ImagePullBackOff
  │     ├── Verify image name and tag
  │     ├── Check imagePullSecrets
  │     └── Check registry accessibility from nodes
  │
  ├── Status: Running but not Ready
  │     ├── Readiness probe failing → kubectl describe pod → check probe config
  │     ├── Application not listening on expected port?
  │     └── Startup probe still running? → increase failureThreshold
  │
  └── Status: Terminating (stuck)
        ├── Finalizers blocking deletion → kubectl get pod -o json | jq '.metadata.finalizers'
        ├── Volume unmount hanging?
        └── Force delete: kubectl delete pod <name> --grace-period=0 --force
```

---

## Essential kubectl Diagnostic Commands

### Pod Inspection

```bash
# Describe pod (shows events, conditions, volumes, container status)
kubectl describe pod <name> -n <namespace>

# Get pod with additional details
kubectl get pod <name> -n <namespace> -o wide
kubectl get pod <name> -n <namespace> -o yaml

# Logs
kubectl logs <pod> -n <namespace>                    # current container logs
kubectl logs <pod> -n <namespace> --previous         # previous crash logs
kubectl logs <pod> -n <namespace> -c <container>     # specific container
kubectl logs <pod> -n <namespace> --all-containers   # all containers
kubectl logs -l app=myapp -n <namespace> --since=1h  # label selector + time
kubectl logs <pod> -n <namespace> --tail=200 -f      # follow last 200 lines

# Events (cluster-wide, sorted by time)
kubectl get events -n <namespace> --sort-by=.lastTimestamp
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod>
kubectl get events -n <namespace> --field-selector type=Warning

# Resource usage
kubectl top pod -n <namespace> --sort-by=memory
kubectl top pod -n <namespace> --sort-by=cpu
kubectl top nodes
```

### Exec and Debug

```bash
# Exec into running container
kubectl exec -it <pod> -n <namespace> -- /bin/bash
kubectl exec -it <pod> -n <namespace> -c <container> -- /bin/sh

# Ephemeral debug container (doesn't modify the pod spec)
kubectl debug -it <pod> -n <namespace> --image=busybox --target=<container>
kubectl debug -it <pod> -n <namespace> --image=nicolaka/netshoot --target=<container>

# Debug by copying the pod (with a different command)
kubectl debug <pod> -n <namespace> --copy-to=debug-pod --container=app -- /bin/sh

# Debug node
kubectl debug node/<node-name> -it --image=busybox
```

### Network Diagnostics

```bash
# Port forwarding for local testing
kubectl port-forward pod/<pod> 8080:8080 -n <namespace>
kubectl port-forward svc/<service> 8080:80 -n <namespace>

# DNS resolution test from inside a pod
kubectl exec -it <pod> -- nslookup <service>.<namespace>.svc.cluster.local
kubectl exec -it <pod> -- nslookup kubernetes.default.svc.cluster.local

# Check endpoints (are pods registered with the service?)
kubectl get endpoints <service> -n <namespace>
kubectl get endpointslices -l kubernetes.io/service-name=<service> -n <namespace>

# Test connectivity from a debug pod
kubectl run nettest --rm -it --image=nicolaka/netshoot -- bash
# Inside: curl, dig, nslookup, traceroute, tcpdump, iperf3

# Check NetworkPolicy
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy <name> -n <namespace>
```

### Node Diagnostics

```bash
# Node status and conditions
kubectl describe node <node-name>
kubectl get nodes -o wide

# Node resource pressure
kubectl top nodes
kubectl describe node <node> | grep -A 5 "Conditions:"
kubectl describe node <node> | grep -A 20 "Allocated resources:"

# Pods on a specific node
kubectl get pods --all-namespaces --field-selector spec.nodeName=<node>
kubectl get pods -A -o wide | grep <node>

# Drain node (for maintenance)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>  # re-enable scheduling

# Cordon node (prevent new scheduling, keep existing pods)
kubectl cordon <node>
```

### Storage Diagnostics

```bash
# PVC status
kubectl get pvc -n <namespace>
kubectl describe pvc <name> -n <namespace>

# PV status
kubectl get pv
kubectl describe pv <name>

# Check StorageClass
kubectl get storageclass
kubectl describe storageclass <name>

# CSI driver status
kubectl get csidrivers
kubectl get csinodes
kubectl get volumeattachments
```

### RBAC Diagnostics

```bash
# Check what a user/SA can do
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:<sa-name>
kubectl auth can-i get pods --as=jane --namespace=production
kubectl auth can-i create deployments --as=system:serviceaccount:ci:runner

# Find bindings for a subject
kubectl get rolebindings,clusterrolebindings -A -o json | \
  jq '.items[] | select(.subjects[]?.name=="<subject>") | .metadata.name'

# Describe role to see permissions
kubectl describe role <name> -n <namespace>
kubectl describe clusterrole <name>
```

---

## Common Error Messages and Solutions

### OOMKilled

```
State:       Terminated
Reason:      OOMKilled
Exit Code:   137
```

**Cause**: container exceeded its memory limit.

**Solutions**:
1. Increase `resources.limits.memory`
2. Profile application memory usage (check for leaks)
3. Review JVM heap settings (`-Xmx` should be less than container memory limit)
4. Check: `kubectl describe pod` → last state → OOMKilled count

### CrashLoopBackOff

**Cause**: container keeps crashing and Kubernetes backs off restart attempts exponentially (10s, 20s, 40s, ..., 5m cap).

**Diagnosis**:
```bash
kubectl logs <pod> --previous    # logs from crashed container
kubectl describe pod <pod>       # exit code, events
```

**Common causes**:
- Application configuration error
- Missing environment variable or config file
- Database connection failure
- Liveness probe too aggressive (reduce frequency, increase initialDelaySeconds)

### Eviction

```
Status:  Failed
Reason:  Evicted
Message: The node was low on resource: memory.
```

**Cause**: kubelet evicted the pod due to node resource pressure.

**Solutions**:
1. Set appropriate resource requests (prevents overcommit)
2. Use Guaranteed QoS (requests == limits) for critical workloads
3. Set PodDisruptionBudgets
4. Check node allocatable: `kubectl describe node | grep Allocatable`

### FailedScheduling

```
Warning  FailedScheduling  0/5 nodes are available:
  2 Insufficient cpu, 3 node(s) had taint {gpu=true: NoSchedule}
```

**Diagnosis**:
1. Check node resources: `kubectl describe nodes | grep -A 5 "Allocated resources"`
2. Check taints: `kubectl get nodes -o json | jq '.items[].spec.taints'`
3. Check affinity/anti-affinity constraints in pod spec
4. Check if PVCs are bound (WaitForFirstConsumer binding mode)
5. Check ResourceQuota: `kubectl describe resourcequota -n <namespace>`

### ImagePullBackOff

**Diagnosis**:
```bash
kubectl describe pod <pod>    # look for "Failed to pull image" in events
```

**Common causes**:
- Image name or tag typo
- Private registry without imagePullSecrets
- Registry rate limiting (Docker Hub: 100 pulls/6h for anonymous)
- Image architecture mismatch (amd64 image on arm64 node)

---

## Cluster Health Checks

```bash
# Control plane health
kubectl get componentstatuses    # deprecated but still works in some versions
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/healthz?verbose'
kubectl get --raw='/livez?verbose'

# Check all system pods
kubectl get pods -n kube-system
kubectl get pods -n kube-system -o wide --field-selector status.phase!=Running

# etcd health (if accessible)
etcdctl endpoint health --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# API server audit
kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp | head -30

# Certificate expiration (kubeadm clusters)
kubeadm certs check-expiration
```

---

## Performance Diagnostics

### API Server Latency

```bash
# Check API server request latency via metrics
kubectl get --raw /metrics | grep apiserver_request_duration_seconds

# Watch for slow requests
kubectl get --raw /metrics | grep apiserver_request_total | grep -E "verb=(LIST|WATCH)"

# Check if APF is throttling
kubectl get --raw /metrics | grep apiserver_flowcontrol
```

### etcd Performance

```bash
# Check etcd latency
etcdctl endpoint status --write-table
etcdctl check perf

# Key metrics to monitor:
# etcd_disk_wal_fsync_duration_seconds (should be <10ms p99)
# etcd_disk_backend_commit_duration_seconds (should be <25ms p99)
# etcd_server_slow_apply_total (should be 0 or very low)
# etcd_mvcc_db_total_size_in_bytes (approaching quota = problem)
```

### Scheduler Performance

```bash
# Check scheduling latency
kubectl get --raw /metrics | grep scheduler_scheduling_attempt_duration_seconds

# Unschedulable pods
kubectl get pods -A --field-selector status.phase=Pending

# Scheduler queue depth
kubectl get --raw /metrics | grep scheduler_pending_pods
```

---

## Resource Debugging with JSONPath

```bash
# Pod IPs
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Container images in use
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u

# Pods not in Running state
kubectl get pods -A -o json | jq '.items[] | select(.status.phase != "Running") | {name: .metadata.name, namespace: .metadata.namespace, phase: .status.phase}'

# Nodes with taints
kubectl get nodes -o json | jq '.items[] | select(.spec.taints != null) | {name: .metadata.name, taints: .spec.taints}'

# PVCs not bound
kubectl get pvc -A -o json | jq '.items[] | select(.status.phase != "Bound") | {name: .metadata.name, namespace: .metadata.namespace, status: .status.phase}'

# Container restart counts
kubectl get pods -A -o json | jq '.items[] | select(.status.containerStatuses != null) | .status.containerStatuses[] | select(.restartCount > 0) | {pod: .name, restarts: .restartCount}'
```
