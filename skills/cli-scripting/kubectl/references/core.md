# kubectl Core Reference

Configuration, output formats, and core verbs.

---

## kubeconfig

```bash
kubectl config view                                    # full kubeconfig
kubectl config view --raw                              # unredacted
kubectl config view --kubeconfig=/path/to/other        # specific file
```

### Contexts

```bash
kubectl config get-contexts                            # list all
kubectl config current-context                         # show current
kubectl config use-context my-prod-cluster             # switch
kubectl config set-context staging --cluster=staging-cluster --user=staging-user --namespace=default
kubectl config rename-context old-name new-name
kubectl config delete-context old-context
```

### Default Namespace

```bash
kubectl config set-context --current --namespace=my-app
kubectl config get-contexts | grep '*'                 # verify
kubectl config set-context --current --namespace=default   # reset
```

### Multiple Clusters

```bash
KUBECONFIG=/path/to/other kubectl get nodes            # single alternate
KUBECONFIG=~/.kube/config:~/.kube/other kubectl config view --merge --flatten > ~/.kube/merged
export KUBECONFIG=~/.kube/merged
kubectl config get-clusters                            # list clusters
kubectl config get-users                               # list users
```

### Auth / Credentials

```bash
kubectl config set-credentials ci-bot --token=eyJhbGc...
kubectl config set-credentials admin --client-certificate=/path/client.crt --client-key=/path/client.key
kubectl config set-cluster my-cluster --server=https://k8s.example.com:6443 --certificate-authority=/path/ca.crt
```

---

## Output Formats

### Standard

```bash
kubectl get pods                                       # default table
kubectl get pods -o wide                               # extra columns
kubectl get deployment my-app -o yaml                  # full YAML
kubectl get pods -o json                               # full JSON
kubectl get pods -o name                               # kind/name format
```

### JSONPath

```bash
# All pod names
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# One per line with range
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'

# Name and status side-by-side
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Node assignment
kubectl get pod my-pod -o jsonpath='{.spec.nodeName}'

# Container images in deployment
kubectl get deployment my-app -o jsonpath='{.spec.template.spec.containers[*].image}'

# First container image
kubectl get deployment my-app -o jsonpath='{.spec.template.spec.containers[0].image}'

# Cluster server URL
kubectl config view -o jsonpath='{.clusters[0].cluster.server}'

# Filter with @
kubectl get pods -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}'

# Secret value (decode)
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 --decode
```

### Custom Columns

```bash
kubectl get pods -o custom-columns='NAME:.metadata.name,NS:.metadata.namespace,STATUS:.status.phase'
kubectl get deployments -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas'
kubectl get pods -o custom-columns-file=columns.txt
```

### Go Templates

```bash
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'
kubectl get pods -o go-template='{{range .items}}{{if eq .status.phase "Running"}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}'
```

### Sorting and Filtering

```bash
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'

# Field selectors (server-side)
kubectl get pods --field-selector=status.phase=Running
kubectl get pods --field-selector=spec.nodeName=node01
kubectl get events --field-selector=involvedObject.name=my-pod

# Label selectors
kubectl get pods -l app=nginx
kubectl get pods -l 'app=nginx,env=prod'
kubectl get pods -l 'env in (dev,staging)'
kubectl get pods -l 'app!=redis'
kubectl get pods --show-labels
```

---

## Core Verbs

| Verb | Purpose |
|------|---------|
| `get` | List or get resources |
| `describe` | Detailed info including events |
| `create` | Create from file or flags |
| `apply` | Declarative create or update |
| `delete` | Delete resources |
| `edit` | Open in editor (live update) |
| `patch` | Partial update |
| `exec` | Execute command in container |
| `logs` | Fetch container logs |
| `port-forward` | Forward local port to pod/service |
| `cp` | Copy files to/from container |
| `top` | CPU/memory usage |
| `explain` | Show field documentation |
| `auth can-i` | Check RBAC permissions |
| `diff` | Diff local vs live manifest |
| `rollout` | Manage rollouts |
| `scale` | Scale replicas |
| `drain` | Drain node for maintenance |
| `cordon` / `uncordon` | Mark node un/schedulable |
| `taint` | Add/remove node taint |
