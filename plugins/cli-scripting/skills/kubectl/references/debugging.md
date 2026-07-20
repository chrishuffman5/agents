# kubectl Debugging Reference

Pod debugging, common error states, network debugging, events, and explain.

---

## Pod Debugging

```bash
# Check status and events
kubectl describe pod my-pod

# Logs (running pod)
kubectl logs my-pod

# Logs from crashed/restarted container
kubectl logs my-pod --previous

# Follow logs
kubectl logs -f my-pod

# Logs from all pods with a label
kubectl logs -l app=my-app --all-containers

# Exec into pod
kubectl exec -it my-pod -- /bin/sh

# Run command without interactive shell
kubectl exec my-pod -- ps aux
kubectl exec my-pod -- cat /etc/resolv.conf

# Ephemeral debug container (Kubernetes 1.23+)
kubectl debug my-pod -it --image=busybox --target=my-app

# Debug with copy of pod
kubectl debug my-pod -it --image=ubuntu --copy-to=my-pod-debug

# Temporary debug pod in same namespace
kubectl run debug-pod --image=busybox --restart=Never --rm -it -- /bin/sh

# Debug pod with same labels (test service routing)
kubectl run debug-pod --image=busybox -l app=my-app --restart=Never --rm -it -- /bin/sh
```

---

## Common Error States

### ImagePullBackOff

Image cannot be pulled. Check image name, tag, and registry auth.

```bash
# Check events for pull errors
kubectl describe pod my-pod | grep -A 10 Events
kubectl get events --field-selector=involvedObject.name=my-pod

# Check image pull secret
kubectl get pod my-pod -o jsonpath='{.spec.imagePullSecrets}'

# Verify image exists (from local machine)
docker pull registry.example.com/myapp:v2

# Common causes:
# - Typo in image name or tag
# - Private registry without imagePullSecret
# - Expired registry credentials
# - Image tag does not exist
```

### CrashLoopBackOff

Container starts, crashes, and keeps restarting.

```bash
# Check previous container logs (most important step)
kubectl logs my-pod --previous

# Check exit code
kubectl get pod my-pod -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
# Exit code 1   = application error
# Exit code 137 = OOMKilled (128 + signal 9)
# Exit code 139 = segfault (128 + signal 11)
# Exit code 143 = SIGTERM (128 + signal 15)

# Check if OOM killed
kubectl get pod my-pod -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
# "OOMKilled" = increase memory limit

# Check container command/args
kubectl get pod my-pod -o jsonpath='{.spec.containers[0].command}'
kubectl get pod my-pod -o jsonpath='{.spec.containers[0].args}'

# Common causes:
# - Application error at startup (check logs --previous)
# - Missing environment variables or config
# - Wrong entrypoint/command
# - OOMKilled (needs more memory)
# - Liveness probe failing too aggressively
```

### OOMKilled

Container exceeded its memory limit.

```bash
# Confirm OOMKilled
kubectl get pod my-pod -o jsonpath='{.status.containerStatuses[0].lastState}'

# Check memory limits
kubectl get pod my-pod -o jsonpath='{.spec.containers[0].resources}'

# Check actual memory usage before kill
kubectl top pods | grep my-pod

# Fix: increase memory limit
kubectl set resources deployment/my-app -c my-app --limits=memory=512Mi
# Or edit the deployment manifest and apply
```

### Pending

Pod cannot be scheduled.

```bash
# Check events for scheduling failures
kubectl describe pod my-pod | grep -A 20 Events

# Common reasons:
# - Insufficient CPU/memory on nodes
kubectl describe nodes | grep -A 5 'Allocated resources'

# - PVC not bound
kubectl get pvc -n my-namespace

# - Node selector/affinity not matching
kubectl get pod my-pod -o jsonpath='{.spec.nodeSelector}'

# - Taints without tolerations
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, taints: .spec.taints}'
```

### Evicted

Pod was evicted due to resource pressure.

```bash
kubectl get pod my-pod -o jsonpath='{.status.reason}'
kubectl describe node | grep -A 10 Conditions

# Common cause: DiskPressure, MemoryPressure
# Fix: clean up disk space or add node capacity
```

---

## Network Debugging

```bash
# Test service from within cluster
kubectl run net-test --image=busybox:1.28 --rm -it --restart=Never -- \
  wget -qO- http://my-svc.my-ns.svc.cluster.local:80

# Test with curl
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -v http://my-svc:80

# DNS resolution
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- \
  nslookup my-svc.my-ns.svc.cluster.local

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Verify endpoints behind a service
kubectl get endpoints my-svc
# Empty endpoints = service selector does not match pod labels

# Port-forward for local testing
kubectl port-forward service/my-svc 8080:80 &
curl http://localhost:8080/health

# Check network policies
kubectl describe networkpolicy -n my-namespace

# DNS debugging pod (runs indefinitely for repeated tests)
kubectl run dnsutils --image=registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3 \
  --restart=Never -- sleep infinity
kubectl exec dnsutils -- nslookup my-svc
kubectl exec dnsutils -- dig my-svc.my-ns.svc.cluster.local
kubectl delete pod dnsutils
```

---

## Events

```bash
# All events sorted by time (most recent last)
kubectl get events --sort-by=.metadata.creationTimestamp

# Events for a specific object
kubectl get events --field-selector=involvedObject.name=my-pod

# Warning events only
kubectl get events --field-selector=type=Warning

# Watch events in real time
kubectl get events -w

# Events across all namespaces
kubectl get events -A --sort-by=.lastTimestamp

# Custom output for events
kubectl get events -o custom-columns='TIME:.lastTimestamp,NS:.metadata.namespace,REASON:.reason,OBJECT:.involvedObject.name,MSG:.message'

# Resource quotas (may cause pod rejection)
kubectl get resourcequota -n my-namespace
kubectl describe resourcequota -n my-namespace

# Limit ranges (may affect default limits)
kubectl get limitrange -n my-namespace
kubectl describe limitrange -n my-namespace
```

---

## Explain Command

```bash
# Resource documentation
kubectl explain pod
kubectl explain deployment

# Specific field documentation
kubectl explain pod.spec.containers
kubectl explain pod.spec.containers.resources
kubectl explain pod.spec.containers.livenessProbe

# Full recursive documentation
kubectl explain pod --recursive | head -100

# API resources available
kubectl api-resources
kubectl api-resources --namespaced=true
kubectl api-resources --namespaced=false

# API versions
kubectl api-versions
```

---

## Debugging Checklist

When a pod is not working:

1. `kubectl get pod my-pod -o wide` -- Check phase, restarts, node
2. `kubectl describe pod my-pod` -- Check events, conditions, resource limits
3. `kubectl logs my-pod` -- Check application output
4. `kubectl logs my-pod --previous` -- If restarting, check previous logs
5. `kubectl get events --field-selector=involvedObject.name=my-pod` -- Check events
6. `kubectl get pod my-pod -o jsonpath='{.status.containerStatuses[0]}'` -- Container state details
7. `kubectl exec -it my-pod -- /bin/sh` -- If running, exec in and investigate
8. `kubectl debug my-pod -it --image=busybox` -- If no shell in image, use ephemeral container

When a service is not reachable:

1. `kubectl get endpoints my-svc` -- Check if pods are registered
2. `kubectl get pods -l <selector>` -- Verify selector matches pods
3. `kubectl describe svc my-svc` -- Check service config
4. `kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -v http://my-svc:80` -- Test from inside cluster
5. `kubectl logs -n kube-system -l k8s-app=kube-dns` -- Check DNS
6. `kubectl describe netpol -n my-ns` -- Check network policies
