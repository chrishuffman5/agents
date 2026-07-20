# CircleCI Architecture

## Execution Model

```
config.yml
    │
    ▼
┌──────────────┐
│ Config       │  Expand orbs, evaluate parameters, validate
│ Processing   │
└──────┬───────┘
       │
┌──────▼───────┐
│ Workflow      │  Resolve job dependencies, fan-out/fan-in
│ Orchestration │
└──────┬───────┘
       │
┌──────▼───────┐
│ Job Queue    │  Match jobs to executors (resource class, type)
└──────┬───────┘
       │
┌──────▼───────┐
│ Executor     │  Provision container/VM, run steps
│ (Docker/VM)  │
└──────────────┘
```

### Job Execution Flow

1. **Spin up environment** — Create container or VM based on executor
2. **Prepare environment** — Set environment variables, attach workspace
3. **Checkout** — Clone repository (if `checkout` step present)
4. **Restore cache** — Download cached files from object storage
5. **Run steps** — Execute commands in order
6. **Save cache** — Upload new cache entries
7. **Persist workspace** — Upload workspace artifacts
8. **Store artifacts/results** — Upload test results and build artifacts
9. **Teardown** — Destroy environment

### Orb Architecture

Orbs are reusable config packages published to the CircleCI Registry:

```yaml
# Orb structure (when developing)
# src/
# ├── commands/
# │   └── install-packages.yml    # Reusable step sequences
# ├── jobs/
# │   └── build.yml               # Complete job definitions
# ├── executors/
# │   └── default.yml             # Executor definitions
# └── @orb.yml                    # Metadata
```

Orbs are expanded at config processing time — they're syntactic sugar, not runtime services.

### Caching Architecture

| Layer | Storage | Scope | TTL |
|---|---|---|---|
| **Cache** | Object storage (S3-compatible) | Project + branch | 15 days (or until key changes) |
| **Workspace** | Object storage | Single workflow run | Duration of workflow |
| **Artifacts** | Object storage | Per-job | 30 days (configurable) |
| **Docker Layer Cache** | Dedicated storage | Per-project | Varies (premium feature) |

Cache key template syntax:
- `{{ checksum "file" }}` — File hash
- `{{ .Branch }}` — Branch name
- `{{ .Revision }}` — Git SHA
- `{{ epoch }}` — Current timestamp
- `{{ arch }}` — CPU architecture

### Parallelism and Test Splitting

```
Test Suite (1000 tests)
        │
        ├── Container 0: tests[0:250]     (split by timing)
        ├── Container 1: tests[250:500]
        ├── Container 2: tests[500:750]
        └── Container 3: tests[750:1000]
```

Splitting strategies:
- `--split-by=timings` — Uses historical timing data (best balance)
- `--split-by=filesize` — Split by file size
- `--split-by=name` — Alphabetical split

Test results uploaded via `store_test_results` feed timing data back for better future splits.

### Self-Hosted Runners

```
CircleCI Cloud ◄──(polling)──► Runner Agent
                                    │
                              ┌─────▼─────┐
                              │  Task Agent│  Downloads and executes job
                              └─────┬─────┘
                                    │
                              ┌─────▼─────┐
                              │  Machine   │  or Docker executor
                              │  Executor  │
                              └───────────┘
```

Runner classes:
- **Machine runner** — Runs on bare metal or VM, manages its own lifecycle
- **Container runner** — Runs in Kubernetes, auto-scales with cluster
