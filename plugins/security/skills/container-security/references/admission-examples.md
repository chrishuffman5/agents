# Admission Control and Supply Chain Policy Examples

## OPA Gatekeeper

Policy enforcement via Open Policy Agent (Rego language):

```yaml
# ConstraintTemplate: defines the policy logic
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing required labels: %v", [missing])
        }

---
# Constraint: applies the template with parameters
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-app-label
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    labels: ["app", "environment", "owner"]
```

## Kyverno

Policy enforcement with Kubernetes-native YAML syntax (no Rego needed):

```yaml
# Kyverno policy: block privileged containers
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
spec:
  validationFailureAction: Enforce
  rules:
    - name: privileged-containers
      match:
        any:
        - resources:
            kinds: ["Pod"]
      validate:
        message: "Privileged mode is not allowed"
        pattern:
          spec:
            containers:
              - =(securityContext):
                  =(privileged): "false"

---
# Kyverno policy: mutate - add default resource limits
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-resources
spec:
  rules:
    - name: add-resource-limits
      match:
        any:
        - resources:
            kinds: ["Pod"]
      mutate:
        patchStrategicMerge:
          spec:
            containers:
              - (name): "*"
                resources:
                  limits:
                    memory: "512Mi"
                    cpu: "500m"
```

## Policy Enforcement with Sigstore (Kyverno)

```yaml
# Require signed images from trusted registry
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-image-signature
      match:
        any:
        - resources:
            kinds: ["Pod"]
      verifyImages:
      - imageReferences:
        - "registry.example.com/*"
        attestors:
        - entries:
          - keys:
              publicKeys: |-
                -----BEGIN PUBLIC KEY-----
                <cosign public key>
                -----END PUBLIC KEY-----
```
