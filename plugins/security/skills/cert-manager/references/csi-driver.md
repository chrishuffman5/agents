# cert-manager CSI Driver

Mount certificates directly as volumes (without creating Kubernetes Secrets):

```bash
helm install cert-manager-csi-driver jetstack/cert-manager-csi-driver \
    --namespace cert-manager
```

```yaml
# Pod with CSI volume
spec:
  volumes:
  - name: tls
    csi:
      driver: csi.cert-manager.io
      readOnly: true
      volumeAttributes:
        csi.cert-manager.io/issuer-name: internal-ca-issuer
        csi.cert-manager.io/issuer-kind: ClusterIssuer
        csi.cert-manager.io/dns-names: "${POD_NAME}.${POD_NAMESPACE}.svc.cluster.local"
        csi.cert-manager.io/duration: 1h
        csi.cert-manager.io/is-ca: "false"
  
  containers:
  - name: app
    volumeMounts:
    - name: tls
      mountPath: /tls
      readOnly: true
    # Files available: /tls/tls.crt, /tls/tls.key, /tls/ca.crt
```

CSI driver certificates are not stored in etcd (no Kubernetes Secret created). Better for high-churn, short-lived certificates.
