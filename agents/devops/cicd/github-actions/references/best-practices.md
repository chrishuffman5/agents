# GitHub Actions Best Practices

## Security

### Pin Actions to SHA

```yaml
# BAD: Tag can be moved to point to malicious code
- uses: actions/checkout@v4

# GOOD: SHA is immutable
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

Use Dependabot or Renovate to keep SHA pins updated:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
```

### Least-Privilege Permissions

```yaml
# Set restrictive defaults at workflow level
permissions:
  contents: read

# Override per-job only where needed
jobs:
  deploy:
    permissions:
      contents: read
      id-token: write    # Only this job needs OIDC
```

### Fork Safety

- `pull_request` events from forks cannot access secrets — by design
- Never use `pull_request_target` with `actions/checkout` of PR code + secrets
- Require approval for first-time contributors' workflow runs

### Secret Hygiene

- Use environment-scoped secrets for deployment credentials
- Rotate secrets regularly
- Never echo or print secrets (even indirectly via debug output)
- Use OIDC instead of static credentials for cloud providers

## Performance

### Caching Strategy

```yaml
# Cache dependencies with hash-based key
- uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      node_modules
    key: deps-${{ runner.os }}-${{ hashFiles('package-lock.json') }}
    restore-keys: |
      deps-${{ runner.os }}-
```

### Dependency Installation

Use the built-in caching in setup actions when available:

```yaml
# This handles caching automatically
- uses: actions/setup-node@v4
  with:
    node-version: 22
    cache: 'npm'      # Built-in npm/yarn/pnpm cache
```

### Minimize Checkout

```yaml
# Shallow clone for faster checkout
- uses: actions/checkout@v4
  with:
    fetch-depth: 1    # Default (shallow clone)

# Full clone only when needed (release notes, git history)
- uses: actions/checkout@v4
  with:
    fetch-depth: 0    # Full history
```

### Parallel Jobs

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  build:
    runs-on: ubuntu-latest
    needs: [lint, test]    # Wait for both, but lint and test run in parallel
    steps:
      - run: npm run build
```

### Skip Unnecessary Runs

```yaml
on:
  push:
    paths-ignore:
      - '**.md'
      - 'docs/**'
      - '.gitignore'
    branches: [main]
```

## Cost Optimization

### Runner Minutes

- **Linux** is cheapest (1x multiplier)
- **Windows** costs 2x
- **macOS** costs 10x
- Use Linux runners unless you specifically need Windows or macOS
- Self-hosted runners for high-volume workloads (no per-minute cost)
- Use `concurrency` to cancel redundant runs

### Storage

- Delete old artifacts with retention policies
- Cache only what significantly speeds up builds
- Use GitHub Packages for container images (included in free storage)

## Workflow Organization

### Directory Structure

```
.github/
├── workflows/
│   ├── ci.yml              # Main CI pipeline (build, test, lint)
│   ├── deploy.yml          # Deployment pipeline
│   ├── release.yml         # Release automation
│   └── _reusable-*.yml     # Reusable workflows (prefix convention)
├── actions/
│   └── setup-project/      # Composite actions
│       └── action.yml
└── dependabot.yml           # Dependency updates
```

### Naming Conventions

- Workflow names: descriptive, action-oriented (`CI Pipeline`, `Deploy to Production`, `Release`)
- Job names: short, lowercase (`build`, `test`, `deploy-staging`)
- Step names: verb + noun (`Install dependencies`, `Run tests`, `Build Docker image`)

### Conditional Deployment

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    needs: [test, lint]
    runs-on: ubuntu-latest
    environment: production
    steps:
      - run: echo "Deploy only on main push, after tests pass"
```

## Monorepo Patterns

### Path-Based Triggers

```yaml
on:
  push:
    paths:
      - 'services/api/**'
      - 'libs/shared/**'     # Also trigger on shared lib changes

jobs:
  build-api:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Building API service"
```

### Dynamic Matrix from Changed Files

```yaml
jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      services: ${{ steps.filter.outputs.changes }}
    steps:
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            api:
              - 'services/api/**'
            web:
              - 'services/web/**'

  build:
    needs: detect-changes
    if: needs.detect-changes.outputs.services != '[]'
    strategy:
      matrix:
        service: ${{ fromJSON(needs.detect-changes.outputs.services) }}
    steps:
      - run: echo "Building ${{ matrix.service }}"
```

## Common Mistakes

1. **Using `latest` runner tags blindly** — `ubuntu-latest` will change periodically. Pin to `ubuntu-24.04` if your workflow depends on specific tools.
2. **Not setting `fail-fast: false`** — Default matrix behavior cancels all jobs when one fails. Set `false` to see all failures.
3. **Ignoring `concurrency`** — Without it, every push queues a new run. Use `cancel-in-progress: true` for PR workflows.
4. **Large artifacts** — Uploading GBs of artifacts burns storage quota. Be selective.
5. **Hardcoded values** — Use `env:` at workflow level for tool versions, image names, etc.
