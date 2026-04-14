# Helm Architecture Reference

Deep technical detail on Helm internals, chart structure, template rendering, hooks, OCI registries, and SSA.

---

## Chart Metadata (Chart.yaml)

```yaml
apiVersion: v2                 # Required. v2 for Helm 3/4 charts. v1 is legacy Helm 2.
name: myapp                    # Required. Chart name.
description: My application    # Optional. One-line summary.
type: application              # application (default) or library
version: 1.5.0                 # Required. Chart version. Must be SemVer 2.
appVersion: "2.3.1"            # Optional. Application version (informational only).
kubeVersion: ">=1.28.0"        # Optional. Kubernetes version constraint.
keywords:                      # Optional. Search keywords.
  - web
  - api
home: https://example.com      # Optional. Project homepage.
sources:                       # Optional. Source code URLs.
  - https://github.com/myorg/myapp
maintainers:                   # Optional.
  - name: Team Alpha
    email: team@example.com
icon: https://example.com/icon.png  # Optional. Chart icon URL.
deprecated: false              # Optional. Mark chart as deprecated.
annotations:                   # Optional. Arbitrary metadata.
  category: Infrastructure
```

**`type: library`**: library charts cannot be installed directly. They provide named templates and helpers that other charts import as dependencies. No `templates/` directory resources are rendered from library charts.

---

## Template Rendering Pipeline

```
Chart.yaml + values.yaml + user values (-f, --set)
    ↓
Values merge (user values override chart defaults)
    ↓
Template engine (Go template + Sprig)
    ↓
YAML parse and validate
    ↓
Kubernetes manifests sent to cluster (SSA in Helm 4, 3-way merge in Helm 3)
```

### Values Merge Order

Values are merged in this order (later overrides earlier):
1. `values.yaml` in the chart
2. Parent chart's `values.yaml` (for sub-chart values)
3. `-f` / `--values` files (in order specified)
4. `--set` and `--set-string` flags
5. `--set-file` flags

**Helm 4 multi-document values**: values files can contain multiple YAML documents separated by `---`. Later documents override earlier ones within the same file.

### Template Objects

| Object | Description |
|--------|-------------|
| `.Values` | Merged values from all sources |
| `.Release.Name` | Release name |
| `.Release.Namespace` | Target namespace |
| `.Release.IsInstall` | True if this is an install (not upgrade) |
| `.Release.IsUpgrade` | True if this is an upgrade |
| `.Release.Revision` | Release revision number |
| `.Release.Service` | Always "Helm" |
| `.Chart` | Contents of Chart.yaml |
| `.Capabilities` | Cluster capabilities (API versions, K8s version) |
| `.Template.Name` | Current template file path |
| `.Template.BasePath` | Templates directory path |
| `.Files` | Access non-template files in the chart |

### Named Templates (_helpers.tpl)

```yaml
{{- define "myapp.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "myapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "myapp.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

Use `include` (not `template`) to call named templates -- `include` captures output as a string that can be piped to functions like `nindent`.

---

## Hooks Lifecycle

### Execution Order

**Install**:
1. `helm install` invoked
2. Templates rendered
3. `pre-install` hooks executed (in weight order)
4. Release resources created (SSA/apply)
5. Wait for readiness (kstatus in Helm 4)
6. `post-install` hooks executed
7. Release marked as deployed

**Upgrade**:
1. `helm upgrade` invoked
2. Templates rendered with new values
3. `pre-upgrade` hooks executed
4. Release resources updated (SSA/apply)
5. Wait for readiness
6. `post-upgrade` hooks executed
7. Release revision incremented

**Hook failure**: if a hook fails, the release is marked as failed. `pre-install` failure prevents resource creation. `pre-upgrade` failure prevents resource update.

### Hook Resource Management

Hooks are NOT managed as part of the release. They are created, executed, and optionally deleted based on `hook-delete-policy`. Without a delete policy, hook resources persist in the namespace.

---

## Server-Side Apply (Helm 4)

Helm 4 uses Kubernetes Server-Side Apply (SSA) instead of client-side 3-way merge:

**How SSA works**:
1. Each field in a resource has a "field manager" (owner)
2. Helm sets its field manager to `helm` when applying resources
3. Fields not managed by Helm can be modified by other tools without conflict
4. Conflicts occur only when two managers try to own the same field

**Benefits over 3-way merge**:
- No "has been modified by another client" errors for non-Helm-managed fields
- Annotations added by operators/controllers are preserved
- No need for `--force` to resolve conflicts
- Metadata labels added outside Helm are not removed on upgrade

**Force conflicts**: if another field manager owns a field Helm wants to manage, use `--force` to take ownership.

---

## OCI Registry Protocol

Helm charts stored in OCI registries use the OCI Distribution Specification:

```
registry.example.com/charts/myapp:1.5.0
  ├── Config blob (application/vnd.cncf.helm.config.v1+json)
  │     └── Chart.yaml contents
  └── Layer blob (application/vnd.cncf.helm.chart.content.v1.tar+gzip)
        └── Packaged chart (.tgz)
```

**OCI vs legacy repositories**:
- Legacy: `helm repo add` downloads an `index.yaml` listing all charts. Client-side index management.
- OCI: each chart version is an OCI artifact. No index file. Registry handles discovery.

**Authentication**: uses the same credential mechanisms as container image registries (Docker config, credential helpers).

---

## Release Storage

Helm stores release state as Kubernetes Secrets in the release namespace:

```
sh.helm.release.v1.<release-name>.v<revision>
```

Each Secret contains:
- Release metadata (name, namespace, version, status)
- Chart metadata
- Rendered manifest (compressed, base64-encoded)
- Values used for the release
- Hook results

**Max history**: controlled by `--history-max` (default 10). Old revisions are garbage collected.

**Implications**:
- Release data is scoped to the namespace (two releases with the same name in different namespaces are independent)
- RBAC for Secrets in the namespace = RBAC for Helm releases
- Large charts with many templates can produce large Secrets (etcd has a 1.5MB per-object limit)

---

## Sub-Chart Behavior

### Values Scoping

```yaml
# Parent values.yaml
replicaCount: 3
postgresql:              # values for the postgresql sub-chart
  auth:
    username: myapp
    database: myappdb
  primary:
    persistence:
      size: 50Gi
global:                  # accessible to all sub-charts via .Values.global
  domain: example.com
  imageRegistry: registry.example.com
```

- Sub-chart values are namespaced under the dependency name (or alias)
- `global` values are shared across all charts and sub-charts
- Sub-charts cannot access parent chart values (only their own scope + globals)

### Condition and Tags

```yaml
# Chart.yaml dependency
dependencies:
- name: postgresql
  condition: postgresql.enabled    # single boolean value path
  tags:
    - database                     # enable/disable by tag group
```

```yaml
# values.yaml
postgresql:
  enabled: true           # condition check

tags:
  database: true           # tag group check
```

Condition takes precedence over tags. If condition is set and evaluates to false, the sub-chart is skipped regardless of tags.

---

## CRD Handling

Files in the `crds/` directory:
- Applied before any templates
- Not templated (no Go template processing)
- Not upgraded on `helm upgrade` (CRDs are install-only)
- Not deleted on `helm uninstall`

This is by design: CRDs are cluster-scoped and shared. Deleting them would destroy all custom resources across all namespaces.

**Workaround for CRD upgrades**: manage CRDs separately (kubectl apply, dedicated CRD chart, or operator-managed).
