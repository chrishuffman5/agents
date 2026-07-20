# Helm Best Practices Reference

Chart design, Helmfile orchestration, secrets management, and CI/CD integration.

---

## Chart Design Principles

### Values Design

**Make everything configurable but provide sensible defaults**:

```yaml
# values.yaml
replicaCount: 1

image:
  repository: myapp
  tag: ""                    # defaults to .Chart.AppVersion
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: ""
  hosts: []
  tls: []

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    memory: "256Mi"

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilization: 60

nodeSelector: {}
tolerations: []
affinity: {}

podSecurityContext:
  fsGroup: 10001

securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

**Guidelines**:
- Use flat keys where possible (`service.port` not `service.ports[0].port`)
- Group related settings under a common key
- Document every value in `values.yaml` with comments
- Use `values.schema.json` for validation (catches typos in value names)
- Default to secure settings (non-root, read-only root FS)
- Default to disabled for optional features (ingress, autoscaling)

### Schema Validation

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["image"],
  "properties": {
    "replicaCount": {
      "type": "integer",
      "minimum": 0
    },
    "image": {
      "type": "object",
      "required": ["repository"],
      "properties": {
        "repository": { "type": "string" },
        "tag": { "type": "string" },
        "pullPolicy": {
          "type": "string",
          "enum": ["Always", "IfNotPresent", "Never"]
        }
      }
    }
  }
}
```

Schema validation runs during `helm install`, `helm upgrade`, `helm lint`, and `helm template`. Catches value type errors and missing required values before hitting the cluster.

### Template Patterns

**Conditional resource rendering**:
```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
# ...
{{- end }}
```

**Checksum annotation for config reload**:
```yaml
metadata:
  annotations:
    checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```
This triggers a rolling update when ConfigMap content changes.

**Required values with clear error messages**:
```yaml
image: {{ required "image.repository must be set" .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
```

**Avoid deeply nested templates**: keep templates readable. If logic is complex, extract it to a named template in `_helpers.tpl`.

### Testing Charts

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "myapp.fullname" . }}-test
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
  - name: test
    image: busybox:1.36
    command: ['wget', '--spider', '-T', '5', '{{ include "myapp.fullname" . }}:{{ .Values.service.port }}']
```

```bash
helm test <release-name> -n <namespace>
```

### Library Charts

Create reusable template libraries:

```yaml
# Chart.yaml
apiVersion: v2
name: common-templates
type: library
version: 1.0.0
```

```yaml
# templates/_labels.tpl
{{- define "common.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

Consuming chart adds the library as a dependency and uses `include "common.labels" .`.

---

## Helmfile

Helmfile manages multiple Helm releases declaratively:

```yaml
# helmfile.yaml
environments:
  staging:
    values:
    - environments/staging.yaml
  production:
    values:
    - environments/production.yaml
    secrets:
    - environments/production.secrets.yaml

releases:
  - name: cert-manager
    chart: jetstack/cert-manager
    namespace: cert-manager
    version: "1.16.x"
    values:
    - charts/cert-manager/values.yaml
    hooks:
    - events: ["presync"]
      command: kubectl
      args: ["apply", "-f", "crds/cert-manager.yaml"]

  - name: postgresql
    chart: oci://registry-1.docker.io/bitnamicharts/postgresql
    namespace: data
    version: "~13.0"
    values:
    - charts/postgresql/values.yaml
    - charts/postgresql/values.{{ .Environment.Name }}.yaml

  - name: myapp
    chart: ./charts/myapp
    namespace: production
    needs:
      - data/postgresql          # dependency ordering
      - cert-manager/cert-manager
    values:
    - charts/myapp/values.yaml
    set:
    - name: image.tag
      value: {{ .Values | get "app_version" "latest" }}
```

**Key commands**:
```bash
helmfile sync                    # install/upgrade all releases
helmfile diff                    # show what would change
helmfile apply                   # diff + sync (only apply changes)
helmfile destroy                 # delete all releases
helmfile -e staging sync         # apply to specific environment
helmfile -l name=myapp sync      # apply specific release by label
```

**Helmfile best practices**:
- Use `needs` for dependency ordering between releases
- Use environment-specific values files for per-environment configuration
- Use `helmfile diff` in CI to preview changes before apply
- Pin chart versions (don't use `latest` or unbounded ranges)

---

## helm-secrets

Encrypt sensitive values with SOPS:

```bash
# Install plugin
helm plugin install https://github.com/jkroepke/helm-secrets

# Encrypt a values file
helm secrets enc secrets.yaml

# Decrypt (view only)
helm secrets dec secrets.yaml

# Install with encrypted secrets
helm secrets install myapp ./mychart -f values.yaml -f secrets.yaml

# Upgrade with encrypted secrets
helm secrets upgrade myapp ./mychart -f values.yaml -f secrets.yaml
```

**SOPS backends**: AWS KMS, GCP KMS, Azure Key Vault, age, PGP.

**`.sops.yaml` configuration**:
```yaml
creation_rules:
  - path_regex: \.secrets\.yaml$
    kms: arn:aws:kms:us-east-1:ACCOUNT:key/KEY_ID
  - path_regex: \.secrets\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Best practice**: store encrypted secrets files in Git alongside values files. Decryption keys are managed via cloud KMS or age keys, not in the repository.

---

## CI/CD Integration

### Pipeline Pattern

```yaml
# GitLab CI example
stages:
  - lint
  - test
  - diff
  - deploy

lint:
  script:
    - helm lint ./charts/myapp -f values/production.yaml
    - helm template myapp ./charts/myapp -f values/production.yaml | kubectl apply --dry-run=server -f -

test:
  script:
    - helm install myapp ./charts/myapp -n test --create-namespace -f values/test.yaml --wait --timeout=5m
    - helm test myapp -n test
    - helm uninstall myapp -n test

diff:
  script:
    - helm diff upgrade myapp ./charts/myapp -n production -f values/production.yaml
  only:
    - merge_requests

deploy:
  script:
    - helm upgrade --install myapp ./charts/myapp -n production -f values/production.yaml --wait --timeout=10m --atomic
  only:
    - main
```

**`--atomic`**: if the upgrade fails, automatically rollback to the previous release.

**`--wait`**: wait until all resources are ready before marking the release as successful.

**`--timeout`**: maximum time to wait for readiness (prevents infinite hangs).

### Chart Versioning

- Chart version (`version` in Chart.yaml) follows SemVer
- Bump patch for bug fixes, minor for features, major for breaking changes
- Use `appVersion` to track the application version independently
- CI should validate that `version` is bumped on chart changes (prevent duplicate versions in registry)

---

## Dependency Management Best Practices

1. **Pin versions**: use `~13.0` (patch flexibility) or exact versions, not `*` or unbounded ranges
2. **Use OCI repositories**: prefer `oci://` over legacy `https://` chart repositories
3. **Commit Chart.lock**: ensures reproducible builds across environments
4. **Use conditions**: enable/disable optional dependencies via values (`condition: postgresql.enabled`)
5. **Use aliases**: when you need two instances of the same sub-chart (`alias: cache` for a second Redis)
6. **Override sub-chart values carefully**: only override what you need, let sub-chart defaults handle the rest

---

## Common Pitfalls

1. **Forgetting `{{- -}}` whitespace trimming** -- produces YAML with blank lines that cause parsing errors
2. **Using `template` instead of `include`** -- `template` cannot be piped to functions; always use `include`
3. **Not quoting string values** -- `{{ .Values.port }}` where port is "8080" renders as integer; use `{{ .Values.port | quote }}` for string context
4. **CRD management** -- CRDs in `crds/` are never upgraded by Helm. Manage CRD lifecycle separately.
5. **Large releases hitting etcd limit** -- release Secrets store rendered manifests. Charts with many templates can exceed the 1.5MB etcd object limit. Split large charts.
6. **Ignoring `helm diff`** -- always diff before upgrade in production to catch unexpected changes
7. **Not using `--atomic` in CI/CD** -- failed upgrades without `--atomic` leave releases in a failed state requiring manual intervention
