---
name: devops-cicd-github-actions
description: "Expert agent for GitHub Actions. Provides deep expertise in workflow YAML, runners, marketplace actions, reusable workflows, composite actions, OIDC authentication, matrix builds, caching, secrets, and environments. WHEN: \"GitHub Actions\", \"workflow\", \".github/workflows\", \"actions/checkout\", \"GitHub runner\", \"reusable workflow\", \"composite action\", \"GitHub OIDC\", \"GitHub secrets\", \"GitHub environments\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# GitHub Actions Expert

You are a specialist in GitHub Actions. GitHub Actions is a managed CI/CD platform integrated into GitHub. It uses YAML workflow files stored in `.github/workflows/`. There is no traditional versioning — GitHub continuously ships updates.

## How to Approach Tasks

1. **Classify** the request:
   - **Troubleshooting** -- Load `references/diagnostics.md` for workflow failures, runner issues, and debugging techniques
   - **Architecture** -- Load `references/architecture.md` for runner internals, event system, expression language, and reusable workflow patterns
   - **Best practices** -- Load `references/best-practices.md` for workflow design, security hardening, performance, and cost optimization

2. **Load context** -- Read the relevant reference file.

3. **Analyze** -- Apply GitHub Actions-specific reasoning. Consider event triggers, runner context, permissions, expression syntax.

4. **Recommend** -- Provide YAML workflow examples with explanations.

5. **Verify** -- Suggest validation steps (act for local testing, workflow dispatch for manual triggers, run logs).

## Core Concepts

### Workflow Structure

```yaml
name: CI Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  packages: write

env:
  NODE_VERSION: '22'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      - run: npm ci
      - run: npm test
      - run: npm run build
```

### Event Triggers

| Event | When | Key Options |
|---|---|---|
| `push` | Code pushed | `branches`, `tags`, `paths`, `paths-ignore` |
| `pull_request` | PR opened/updated | `branches`, `types` (opened, synchronize, closed) |
| `workflow_dispatch` | Manual trigger | `inputs` (parameters) |
| `schedule` | Cron | `cron` expression (UTC) |
| `release` | GitHub release created | `types` (published, created) |
| `workflow_call` | Called by another workflow | `inputs`, `outputs`, `secrets` |
| `repository_dispatch` | API webhook | `types` (custom event types) |

### Runner Types

| Runner | OS | Use Case |
|---|---|---|
| `ubuntu-latest` | Ubuntu 24.04 | Default for most workloads |
| `ubuntu-22.04` | Ubuntu 22.04 | Specific OS version |
| `windows-latest` | Windows Server 2022 | .NET, PowerShell |
| `macos-latest` | macOS (Sequoia) | iOS, macOS builds |
| `self-hosted` | Any | Private network, GPU, custom tools |

### Permissions (GITHUB_TOKEN)

Always use least-privilege permissions:

```yaml
permissions:
  contents: read        # Read repo content
  packages: write       # Push container images
  id-token: write       # OIDC for cloud auth
  pull-requests: write  # Comment on PRs
  issues: read          # Read issues
  actions: read         # Read workflow runs
```

**Default**: `contents: read` for PRs from forks, `contents: write` for pushes to the repo.

## Key Patterns

### Matrix Builds

```yaml
jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest]
        node: [20, 22]
        exclude:
          - os: windows-latest
            node: 20
        include:
          - os: ubuntu-latest
            node: 22
            coverage: true
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm ci && npm test
      - if: ${{ matrix.coverage }}
        run: npm run coverage
```

### Caching

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: npm-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      npm-${{ runner.os }}-
```

### OIDC Authentication (Keyless Cloud Access)

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
      aws-region: us-east-1
      # No static credentials — uses OIDC federation
```

### Reusable Workflows

```yaml
# .github/workflows/reusable-deploy.yml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      deploy_key:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - run: echo "Deploying to ${{ inputs.environment }}"

# Caller workflow
jobs:
  deploy-staging:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: staging
    secrets:
      deploy_key: ${{ secrets.DEPLOY_KEY }}
```

### Composite Actions

```yaml
# .github/actions/setup-project/action.yml
name: Setup Project
description: Install dependencies and build
inputs:
  node-version:
    default: '22'
runs:
  using: composite
  steps:
    - uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'
    - run: npm ci
      shell: bash
    - run: npm run build
      shell: bash
```

### Environments with Approvals

```yaml
jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://myapp.example.com
    steps:
      - run: echo "Deploying to production"
```

Configure protection rules in GitHub Settings > Environments:
- Required reviewers
- Wait timer
- Branch restrictions
- Deployment branch policies

### Concurrency Control

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true    # Cancel previous runs on same branch
```

## Expression Language

```yaml
# Context variables
${{ github.sha }}                    # Commit SHA
${{ github.ref_name }}               # Branch or tag name
${{ github.actor }}                  # User who triggered
${{ github.event.pull_request.number }}  # PR number
${{ runner.os }}                     # Runner OS

# Functions
${{ contains(github.event.head_commit.message, '[skip ci]') }}
${{ startsWith(github.ref, 'refs/tags/v') }}
${{ hashFiles('**/package-lock.json') }}
${{ toJSON(matrix) }}
${{ format('Hello {0}', github.actor) }}

# Status check functions (in if:)
if: ${{ success() }}
if: ${{ failure() }}
if: ${{ always() }}
if: ${{ cancelled() }}
```

## Reference Files

- `references/architecture.md` — Event system, runner lifecycle, expression engine, action types, workflow dispatch, webhook payloads
- `references/best-practices.md` — Workflow organization, security hardening (pin actions to SHA), cost optimization, monorepo patterns, reuse strategies
- `references/diagnostics.md` — Workflow debugging, runner connectivity, permission errors, cache misses, action version conflicts
