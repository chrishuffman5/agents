# kubectl Commands Reference

Workloads, config/storage, networking, RBAC, and node management.

---

## Workloads

### Pods

```bash
kubectl run nginx --image=nginx:1.25 --port=80
kubectl run myapp --image=myapp:v2 --env="DB_HOST=postgres"
kubectl run -it --rm busybox --image=busybox --restart=Never -- /bin/sh
kubectl run nginx --image=nginx:1.25 --dry-run=client -o yaml > pod.yaml

kubectl get pods
kubectl get pods -n kube-system
kubectl get pods -A
kubectl get pods -w
kubectl get pod my-pod -o wide
kubectl describe pod my-pod

kubectl logs my-pod
kubectl logs -f my-pod
kubectl logs my-pod -c sidecar
kubectl logs my-pod --previous
kubectl logs my-pod --tail=100
kubectl logs my-pod --since=1h

kubectl exec -it my-pod -- /bin/bash
kubectl exec -it my-pod -c sidecar -- /bin/sh
kubectl exec my-pod -- env
kubectl exec my-pod -- cat /etc/hosts

kubectl delete pod my-pod
kubectl delete pod my-pod --grace-period=0 --force
kubectl delete pods -l app=nginx
kubectl delete pods --all -n my-namespace

kubectl port-forward pod/my-pod 8080:8080
kubectl port-forward pod/my-pod 8080:80 9090:9090

kubectl cp my-pod:/app/log.txt ./log.txt
kubectl cp ./config.yaml my-pod:/app/config.yaml
kubectl cp my-pod:/var/log/app.log ./app.log -c main
```

### Deployments

```bash
kubectl create deployment nginx --image=nginx:1.25 --replicas=3
kubectl apply -f deployment.yaml
kubectl apply -f ./k8s/

kubectl get deployments
kubectl describe deployment my-app

kubectl scale deployment my-app --replicas=5
kubectl scale deployment --all --replicas=3 -n staging

kubectl set image deployment/my-app my-app=myapp:v2
kubectl rollout status deployment/my-app
kubectl rollout history deployment/my-app
kubectl rollout history deployment/my-app --revision=2
kubectl rollout undo deployment/my-app
kubectl rollout undo deployment/my-app --to-revision=1
kubectl rollout pause deployment/my-app
kubectl rollout resume deployment/my-app
kubectl rollout restart deployment/my-app

kubectl set resources deployment/my-app -c my-app --limits=cpu=500m,memory=256Mi
kubectl set env deployment/my-app DB_HOST=postgres

kubectl patch deployment my-app -p '{"spec":{"replicas":4}}'
kubectl patch deployment my-app --type=json -p='[{"op":"replace","path":"/spec/replicas","value":4}]'
kubectl delete deployment my-app
```

### StatefulSets

```bash
kubectl get statefulsets
kubectl describe statefulset my-db
kubectl scale statefulset my-db --replicas=3
kubectl rollout restart statefulset/my-db
kubectl rollout status statefulset/my-db
kubectl set image statefulset/my-db my-db=mydb:v2
kubectl delete statefulset my-db --cascade=orphan
```

### DaemonSets

```bash
kubectl get daemonsets
kubectl describe ds fluentd -n kube-system
kubectl rollout restart daemonset/fluentd -n kube-system
kubectl rollout status daemonset/fluentd -n kube-system
```

### Jobs and CronJobs

```bash
kubectl create job my-job --image=busybox -- /bin/sh -c 'echo hello && exit 0'
kubectl create job manual-run --from=cronjob/my-cronjob
kubectl get jobs
kubectl get pods -l job-name=my-job
kubectl logs -l job-name=my-job
kubectl delete job my-job

kubectl create cronjob cleanup --image=busybox --schedule='0 2 * * *' -- /bin/sh -c 'find /tmp -mtime +7 -delete'
kubectl get cronjobs
kubectl patch cronjob my-cron -p '{"spec":{"suspend":true}}'
kubectl patch cronjob my-cron -p '{"spec":{"suspend":false}}'
```

---

## Configuration and Storage

### ConfigMaps

```bash
kubectl create configmap app-config --from-literal=DB_HOST=postgres --from-literal=DB_PORT=5432
kubectl create configmap nginx-config --from-file=nginx.conf
kubectl create configmap app-config --from-file=./config/
kubectl create configmap app-config --from-env-file=.env

kubectl get configmaps
kubectl describe configmap app-config
kubectl get configmap app-config -o yaml
kubectl edit configmap app-config
kubectl delete configmap app-config
```

### Secrets

```bash
kubectl create secret generic db-creds --from-literal=username=admin --from-literal=password='S3cr3t!'
kubectl create secret generic tls-config --from-file=./certs/
kubectl create secret tls my-tls --cert=tls.crt --key=tls.key
kubectl create secret docker-registry my-reg --docker-server=registry.example.com \
  --docker-username=myuser --docker-password=mypass --docker-email=me@example.com

kubectl get secrets
kubectl describe secret db-creds
kubectl get secret db-creds -o jsonpath='{.data.password}' | base64 --decode && echo
kubectl delete secret db-creds
```

### Persistent Volumes

```bash
kubectl get pv
kubectl describe pv my-pv
kubectl get pvc
kubectl describe pvc my-pvc
kubectl get storageclasses
kubectl describe sc standard
kubectl patch pv my-pv -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

---

## Networking

### Services

```bash
kubectl expose deployment my-app --port=80 --target-port=8080
kubectl expose deployment my-app --port=80 --target-port=8080 --type=NodePort
kubectl expose deployment my-app --port=80 --target-port=8080 --type=LoadBalancer

kubectl get services
kubectl describe service my-app
kubectl get endpoints my-app
kubectl port-forward service/my-app 8080:80
kubectl port-forward deployment/my-app 8080:8080
kubectl delete service my-app
```

### Ingress

```bash
kubectl get ingress
kubectl describe ingress my-ingress
kubectl apply -f ingress.yaml
kubectl get ingress -o wide
kubectl delete ingress my-ingress
```

### Network Policies

```bash
kubectl get networkpolicies
kubectl describe netpol my-policy
kubectl apply -f netpol.yaml
```

### DNS and Connectivity

```bash
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl http://my-svc.my-ns.svc.cluster.local
kubectl run wget-test --image=busybox --rm -it --restart=Never -- wget -qO- http://my-svc
kubectl get endpoints -A
```

---

## RBAC

### Namespaces

```bash
kubectl get namespaces
kubectl create namespace my-app
kubectl describe namespace my-app
kubectl delete namespace old-project
kubectl get all -n my-namespace
```

### Service Accounts

```bash
kubectl get serviceaccounts
kubectl create serviceaccount my-sa
kubectl create token my-sa
kubectl create token my-sa --duration=48h
```

### Roles and Bindings

```bash
kubectl create role pod-reader --verb=get,list,watch --resource=pods
kubectl create rolebinding read-pods --role=pod-reader --user=jane -n my-ns
kubectl create rolebinding read-pods --role=pod-reader --serviceaccount=my-ns:my-sa -n my-ns
kubectl get roles -n my-ns
kubectl get rolebindings -n my-ns
```

### ClusterRoles

```bash
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes
kubectl create clusterrolebinding node-reader-bind --clusterrole=node-reader --user=jane
kubectl create clusterrolebinding my-sa-admin --clusterrole=cluster-admin --serviceaccount=kube-system:my-sa
```

### Auth Can-I

```bash
kubectl auth can-i list pods
kubectl auth can-i create deployments -n production
kubectl auth can-i list secrets --as=jane
kubectl auth can-i list pods --as=system:serviceaccount:default:my-sa
kubectl auth can-i --list
kubectl auth can-i --list -n my-namespace
```

---

## Node Management

```bash
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node my-node
kubectl get nodes --show-labels

kubectl label node my-node disktype=ssd
kubectl label node my-node disktype-

kubectl get pods -A --field-selector=spec.nodeName=my-node

kubectl cordon my-node
kubectl uncordon my-node
kubectl drain my-node --ignore-daemonsets --delete-emptydir-data
kubectl drain my-node --ignore-daemonsets --delete-emptydir-data --grace-period=60

kubectl taint node my-node key=value:NoSchedule
kubectl taint node my-node dedicated=gpu:NoExecute
kubectl taint node my-node key=value:NoSchedule-

kubectl top nodes
kubectl top pods
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory
kubectl top pods --containers
```
