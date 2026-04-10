# GitHub Actions Architecture

## Event System

### Event Flow

```
GitHub Event (push, PR, etc.)
        │
        ▼
┌──────────────────┐
│  Event Matching  │  Match event type + filters (branches, paths, types)
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Workflow Queue   │  Queue matching workflows for execution
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Runner Dispatch  │  Assign jobs to available runners
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Job Execution    │  Execute steps sequentially on the runner
└──────────────────┘
```

### Event Types and Contexts

| Category | Events | Context Data |
|---|---|---|
| **Code** | `push`, `pull_request`, `pull_request_target` | Commits, branch, diffs, PR metadata |
| **Release** | `release`, `create`, `delete` | Tag, release body, assets |
| **Issue** | `issues`, `issue_comment` | Issue body, labels, assignees |
| **Workflow** | `workflow_dispatch`, `workflow_call`, `workflow_run` | Inputs, caller context |
| **Schedule** | `schedule` | Cron expression, default branch context |
| **External** | `repository_dispatch` | Custom `client_payload` |

### pull_request vs pull_request_target

| Aspect | `pull_request` | `pull_request_target` |
|---|---|---|
| **Code checked out** | PR head (fork's code) | Base branch code |
| **Secrets access** | No (forks) | Yes (base repo secrets) |
| **GITHUB_TOKEN** | Read-only (forks) | Write (base repo) |
| **Use case** | Safe CI for untrusted code | Labeling, commenting on fork PRs |
| **Security risk** | Low | High — never run PR code with these permissions |

## Runner Architecture

### GitHub-Hosted Runner Lifecycle

1. **Provisioning** — Fresh VM created for each job (Azure VMs)
2. **Tool setup** — Pre-installed tools: Node, Python, Go, .NET, Docker, kubectl, Terraform, etc.
3. **Checkout** — Runner downloads repo code
4. **Step execution** — Steps run sequentially in the runner's shell
5. **Cleanup** — VM destroyed after job completes (ephemeral)

### Self-Hosted Runner Architecture

```
GitHub.com ◄──(long poll)──► Runner Application
                                    │
                              ┌─────▼─────┐
                              │  Listener  │  Polls for jobs
                              └─────┬─────┘
                                    │
                              ┌─────▼─────┐
                              │   Worker   │  Executes job steps
                              └─────┬─────┘
                                    │
                              ┌─────▼─────┐
                              │  Actions   │  Downloads and runs actions
                              └───────────┘
```

### Actions Runner Controller (ARC)

Kubernetes-based autoscaling for self-hosted runners:

```yaml
apiVersion: actions.github.com/v1alpha1
kind: AutoscalingRunnerSet
metadata:
  name: my-runners
spec:
  githubConfigUrl: "https://github.com/org/repo"
  maxRunners: 20
  minRunners: 1
  template:
    spec:
      containers:
        - name: runner
          image: ghcr.io/actions/actions-runner:latest
          resources:
            requests:
              cpu: "2"
              memory: "4Gi"
```

**How ARC scales:**
- Watches GitHub webhook for `workflow_job.queued` events
- Spins up runner pods on demand
- Scales to zero when idle (cost savings)
- Each pod runs one job then terminates (ephemeral)

## Action Types

### JavaScript Actions

```yaml
# action.yml
name: My JS Action
inputs:
  token:
    required: true
runs:
  using: node20
  main: dist/index.js
```

- Fastest startup (no container pull)
- Cross-platform (Linux, Windows, macOS)
- Must bundle dependencies (ncc or esbuild)

### Docker Container Actions

```yaml
# action.yml
name: My Docker Action
runs:
  using: docker
  image: Dockerfile
```

- Runs in a container (isolation)
- Linux runners only
- Slower startup (image pull/build)
- Full control over environment

### Composite Actions

```yaml
# action.yml
runs:
  using: composite
  steps:
    - run: echo "step 1"
      shell: bash
    - uses: actions/setup-node@v4
```

- Compose multiple steps and actions
- No custom runtime needed
- Ideal for sharing setup patterns across workflows

## Workflow Reuse Model

```
                    ┌─────────────────────┐
                    │  Caller Workflow     │
                    │  (workflow_dispatch) │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Reusable Workflow   │
                    │  (workflow_call)     │
                    │  - inputs/outputs    │
                    │  - secrets           │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
     ┌────────▼──────┐  ┌─────▼───────┐  ┌─────▼───────┐
     │  Job 1        │  │  Job 2      │  │  Job 3      │
     │  (uses: step) │  │  (matrix)   │  │  (deploy)   │
     └───────────────┘  └─────────────┘  └─────────────┘
```

### Reuse Hierarchy

| Level | Mechanism | Scope | Share Via |
|---|---|---|---|
| **Step** | Action (JS, Docker, Composite) | Single step | Marketplace, org repos |
| **Job** | Reusable workflow | Entire job | `uses: org/repo/.github/workflows/x.yml@v1` |
| **Config** | Organization defaults | Org-wide settings | `.github` repository |

### Limitations of Reusable Workflows

- Max 4 levels of nesting
- Cannot pass environment variables from caller to reusable
- Secrets must be explicitly passed (or use `secrets: inherit`)
- Outputs limited to string values
- Reusable workflow and caller share the same `GITHUB_TOKEN` scope

## Secrets and Variables Architecture

| Type | Scope | Encrypted | Use Case |
|---|---|---|---|
| **Secrets** (Actions) | Repo, Org, Environment | Yes (Libsodium sealed box) | API keys, passwords, tokens |
| **Variables** (Actions) | Repo, Org, Environment | No | Non-sensitive config (region, env name) |
| **GITHUB_TOKEN** | Workflow run | Auto-generated | GitHub API access, scoped by permissions |
| **OIDC token** | Job | Auto-generated | Cloud provider authentication |

### Secret Masking

- Secrets are automatically masked in logs (`***`)
- Use `::add-mask::value` to mask dynamic values
- Multi-line secrets are masked per-line
- Secrets are not passed to workflows triggered by forked PRs (security)
