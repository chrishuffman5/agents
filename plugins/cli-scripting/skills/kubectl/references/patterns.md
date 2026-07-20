# kubectl Scripting Patterns

Dry-run, diff, wait, jq integration, batch operations, kustomize.

---

## Dry-Run and Diff

```bash
# Dry-run client-side (generate manifest, no server contact)
kubectl run nginx --image=nginx --dry-run=client -o yaml
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yaml

# Dry-run server-side (validates but does not persist)
kubectl apply -f deployment.yaml --dry-run=server

# Diff local manifest against live state
kubectl diff -f deployment.yaml
kubectl diff -f ./k8s/
```

---

## Apply vs Create

```bash
# create: fails if exists (one-time creation)
kubectl create -f resource.yaml

# apply: create or update (idempotent, tracks changes)
kubectl apply -f resource.yaml

# Force apply (delete and recreate if needed)
kubectl apply -f resource.yaml --force

# Apply with pruning (delete resources removed from directory)
kubectl apply -f ./k8s/ --prune -l app=my-app
```

---

## Waiting for Conditions

```bash
# Pod ready
kubectl wait pod my-pod --for=condition=Ready --timeout=60s

# Deployment available
kubectl wait deployment my-app --for=condition=Available --timeout=120s

# Job complete
kubectl wait job my-job --for=condition=Complete --timeout=300s

# Pod deleted
kubectl wait pod my-pod --for=delete --timeout=30s

# Rollout (exits 0 on success)
kubectl rollout status deployment/my-app --timeout=5m
echo "Exit code: $?"
```

---

## kubectl with jq

```bash
# Pod names as JSON array
kubectl get pods -o json | jq '[.items[].metadata.name]'

# Name and status
kubectl get pods -o json | jq '.items[] | {name: .metadata.name, phase: .status.phase}'

# Filter running pods
kubectl get pods -o json | jq '.items[] | select(.status.phase=="Running") | .metadata.name'

# All container images across cluster
kubectl get pods -A -o json | jq '.items[].spec.containers[].image' | sort -u

# Pods with restarts > 0
kubectl get pods -o json | \
  jq '.items[] | select(.status.containerStatuses[]?.restartCount > 0) | .metadata.name'

# Node allocatable memory
kubectl get nodes -o json | \
  jq '.items[] | {name: .metadata.name, memory: .status.allocatable.memory}'

# All environment variables in a deployment
kubectl get deployment my-app -o json | \
  jq '.spec.template.spec.containers[0].env[]? | {(.name): .value}'
```

---

## Batch Operations

```bash
# Delete pods with label
kubectl delete pods -l app=my-app

# Delete all failed pods
kubectl delete pods --field-selector=status.phase=Failed -A

# Delete completed jobs
kubectl delete jobs --field-selector=status.completionTime!= -n my-ns

# Label multiple pods
kubectl label pods -l app=nginx tier=frontend

# Annotate a resource
kubectl annotate deployment my-app revision="2"
kubectl annotate deployment my-app revision-

# Scale all deployments in namespace to zero
kubectl scale deployment --all --replicas=0 -n staging

# Get all images running in cluster
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u

# Get all resources
kubectl get all -A
```

---

## Kustomize

```bash
# Preview kustomize output
kubectl kustomize ./k8s/overlays/production

# Apply with kustomize
kubectl apply -k ./k8s/overlays/production

# Delete with kustomize
kubectl delete -k ./k8s/overlays/production

# Dry-run kustomize
kubectl apply -k ./k8s/overlays/staging --dry-run=server
```

---

## Multi-Container Patterns

```bash
# Exec into specific container
kubectl exec -it my-pod -c main-container -- /bin/sh

# Logs from init container
kubectl logs my-pod -c init-setup

# Logs from all containers
kubectl logs my-pod --all-containers

# Container names in a pod
kubectl get pod my-pod -o jsonpath='{.spec.containers[*].name}'
```

---

## Scripting Helpers

```bash
# Get current context name
CONTEXT=$(kubectl config current-context)

# Get current namespace
NS=$(kubectl config view --minify --output 'jsonpath={..namespace}')
NS=${NS:-default}

# Check if resource exists
if kubectl get deployment my-app -n "$NS" &>/dev/null; then
  echo "Deployment exists"
fi

# Wait for pods to be ready (all pods matching label)
kubectl wait pod -l app=my-app --for=condition=Ready --timeout=120s

# Rolling restart and wait
kubectl rollout restart deployment/my-app -n "$NS"
kubectl rollout status deployment/my-app -n "$NS" --timeout=5m

# Apply and verify
kubectl apply -f deployment.yaml
kubectl rollout status deployment/my-app --timeout=5m
if [[ $? -eq 0 ]]; then
  echo "Deployment successful"
else
  echo "Deployment failed, rolling back"
  kubectl rollout undo deployment/my-app
fi
```
