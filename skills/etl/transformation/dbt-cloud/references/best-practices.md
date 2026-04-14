# dbt Cloud Best Practices

## Environment Strategy

### Recommended Environment Layout

```
Development (per developer, individual credentials)
  --> Staging (optional, release branch testing)
       --> Production (scheduled + deploy jobs, service account)
```

**Development**: Each developer gets a personal environment with individual warehouse credentials. Enable deferral to production to avoid building upstream models. Developers only build/test edited models.

**Staging** (optional): Intermediate environment for release branch testing. Limits access to production data while enabling advanced features (deferral, cross-project refs). Useful for teams with formal release processes.

**Production**: Designated production environment for scheduled and deploy jobs. Stores manifest artifacts used for state comparison in CI and deferral.

### Environment Variables

```yaml
# In profiles or dbt Cloud UI
{{ env_var('DBT_KEY', 'default_value') }}
```

- Store sensitive credentials (passwords, API keys) as environment variables in dbt Cloud
- Never commit secrets to Git
- Leverage built-in variables: `DBT_CLOUD_ENVIRONMENT_NAME`, `DBT_CLOUD_ENVIRONMENT_TYPE`
- Configure separate schemas or databases per environment for data isolation

### Deferral Configuration

- Enable deferral in development environments to resolve `{{ ref() }}` against production artifacts
- Developers only build/run/test edited models, not the entire upstream DAG
- Saves significant compute and storage costs
- If production data controls are needed, defer to staging instead of production
- Regularly regenerate comparison manifests via scheduled `dbt compile` jobs in staging

### Environment Best Practices

- Each environment can run a different dbt version (Fusion Latest is default for new projects)
- Use separate warehouse credentials per environment with least-privilege access
- Restrict production credentials to production jobs only
- Keep all secrets in dbt Cloud's credential management, never in Git

## CI/CD Workflows

### Slim CI (State Comparison)

The foundation of efficient CI in dbt Cloud:

- Uses `state:modified+` selector to run only modified models and their children
- Defers to production environment for artifact comparison (automatic in dbt Cloud)
- dbt compares PR code against the last successful deploy job manifest
- Significantly reduces compute costs and CI execution time

### CI Job Configuration

1. Create a new job with "Run on Pull Requests" trigger
2. Set the deferred environment to production
3. Add commands:
   ```
   dbt build --select state:modified+
   ```
4. Optionally enable SQL linting (SQLFluff) as a pre-build step
5. For Enterprise: enable Advanced CI (compare changes) for data-level diffs
6. Customize state selectors to exclude certain models or tags if needed

### Deploy/Merge Jobs

- Trigger on merge to main branch
- Run `dbt build` (or selective commands) in the production environment
- Consider: full builds on schedule vs merge-triggered incremental builds
- Use `--fail-fast` for faster feedback on failures

### Advanced CI (Enterprise)

- **Compare changes**: Shows data-level diffs between PR and production
- Identifies how model changes affect downstream data
- Catches unintended data regressions before they reach production
- Supported in the Fusion engine

### Recommended CI/CD Flow

```
1. Developer creates feature branch, develops in IDE/CLI with deferral
2. PR opens --> CI job auto-triggers with Slim CI
3. CI runs modified models + downstream, lints SQL, compares data changes
4. PR reviewed and approved
5. Merge --> deploy job runs in production
6. Scheduled jobs handle regular full refreshes
```

### Release Branch Strategy (Advanced)

For teams with formal release processes:

```
Feature branches --> Release branch --> Main
                           |
                    Staging CI job runs, defers to production
                           |
                    Weekly/periodic release to main/production
```

## Semantic Layer Best Practices

### When to Define Metrics

- Key business KPIs that need a single source of truth (revenue, churn, DAU)
- Same metric consumed by multiple BI tools or teams
- Start with critical metrics suffering from inconsistent definitions across the org
- Add incrementally; avoid trying to define everything at once

### How to Define Metrics

```yaml
metrics:
  - name: revenue
    type: simple
    type_params:
      measure: order_total
    filter:
      - "{{ Dimension('order__order_status') }} = 'completed'"
    description: "Total revenue from completed orders"

  - name: revenue_growth
    type: derived
    type_params:
      expr: (current_revenue - prior_revenue) / prior_revenue
      metrics:
        - name: revenue
          offset_window: 1 month
          alias: prior_revenue
        - name: revenue
          alias: current_revenue
```

**Guidelines**:
- Define explicit expressions (e.g., `revenue - cost`) to prevent divergent calculations
- Set appropriate filters within metric definitions to eliminate ambiguity
- Use entities as join keys for traversal paths between semantic models
- Use dimensions for grouping and slicing (categorical and time-based)

### Governance Patterns

- Validate semantic nodes in CI to ensure code changes don't break metrics
- Centralize metric definitions -- downstream consumers cannot create divergent calculations
- Use saved queries for common metric combinations
- Document metrics with clear descriptions and business context
- Leverage dbt Copilot for auto-generated metric definition recommendations

### Performance Optimization

- MetricFlow pushes computations to the warehouse; a well-tuned warehouse = faster queries
- For heavy metrics requiring complex calculations over large datasets, precompute daily aggregate tables via dbt jobs
- Use incremental models for performance-sensitive metrics
- Balance precomputation with flexibility case by case

## Multi-Project (Mesh) Best Practices

### When to Split Projects

Split when:
- A single project is too large for one team to manage effectively
- Distinct business domains (finance, marketing, product) need independent ownership
- Deployment cycles differ across domains
- Teams need isolated CI/CD pipelines and release processes

Do **not** split prematurely. Governance overhead increases with each project.

### Implementing Mesh

- Align projects to business domains for federated ownership
- Use access modifiers intentionally:
  - `private`: Internal models only relevant within a group
  - `protected`: Shared within a project or installed package
  - `public`: Stable interfaces consumed by other projects
- Only expose mature, stable models as `public`

### Model Contracts

- Add contracts to upstream public models to guarantee data shape for downstream consumers
- Contracts verify column names, types, and constraints at build time
- Do not adopt contracts too early while models are still changing frequently
- Contract enforcement prevents non-compliant data from flowing downstream

```yaml
models:
  - name: dim_customers
    access: public
    config:
      contract:
        enforced: true
    columns:
      - name: customer_id
        data_type: int
      - name: customer_name
        data_type: varchar(100)
```

### Model Versioning

- Treat public models as stable APIs with versioned interfaces
- Test prerelease changes in production and downstream systems before bumping latest version
- Offer migration windows off deprecated versions
- Use `deprecation_date` to notify downstream consumers of planned removal

```yaml
models:
  - name: customers
    latest_version: 2
    versions:
      - v: 1
        deprecation_date: 2026-06-01
      - v: 2
```

### Cross-Project References

- Use two-argument ref: `{{ ref('source_project', 'model_name') }}`
- Upstream models must have `access: public`
- Lineage renders automatically in dbt Explorer across projects
- Iceberg catalog enables cross-platform Mesh (Snowflake + BigQuery)

## Collaboration Best Practices

### PR Reviews

- Require PR reviews for all changes before merging to production
- CI jobs provide automated validation; reviewers check data-level diffs (Advanced CI)
- Ensure documentation is updated alongside code
- Review model contracts and access modifiers for public-facing changes

### Documentation Standards

- Leverage dbt Copilot for auto-generated documentation as a starting point
- Document all public models with clear descriptions and business context
- Keep documentation in YAML files alongside model definitions
- Auto-hosted documentation in dbt Cloud updates after each production run
- Use dbt Explorer for interactive documentation browsing

### IDE Workflows

| Surface | Best For |
|---|---|
| Studio IDE | Quick edits, onboarding, no local setup needed |
| VS Code + Fusion | Power users; fastest compile times, local query validation |
| Canvas | Analysts preferring visual interfaces |
| dbt Cloud CLI | Local development with cloud benefits (deferral, refs) |

- Always save files before running dbt commands (IDE uses last-saved version)
- Use dbt Cloud CLI for teams that prefer local development with cloud features

## Cost Optimization

### Platform Costs

| Tier | Best For |
|---|---|
| Developer (free) | Individual experimentation, learning |
| Starter ($100/user/mo) | Small teams needing Semantic Layer, Copilot |
| Enterprise (custom) | Organizations needing governance, security, Mesh |

### Run Frequency Optimization

- Align scheduling with data availability; don't refresh hourly if data arrives daily
- More frequent runs enable more model reuse via state-aware orchestration
- Use `state:modified+` in scheduled jobs to skip unchanged models
- Balance freshness requirements against compute costs

### Model Selection Optimization

- Use Slim CI to avoid rebuilding unchanged models in PRs
- Use tags, state comparison, or `dbt run --select` for targeted runs
- Defer to production in development to avoid building upstream models
- Use incremental models for large datasets to process only new/changed data

### Warehouse Compute

- Start with a medium-sized warehouse and adjust based on workload
- Configure auto-suspend after 1-2 minutes of inactivity
- Use separate warehouses for transformation vs ad-hoc queries vs reporting
- Optimize heavy models with partitioning, clustering, and reduced joins
- SQL warehouses are optimized for dbt workloads on Databricks

### State-Aware Orchestration

- Enable state-aware orchestration to skip models satisfying freshness requirements
- No rebuild when nothing upstream has changed
- dbt Labs reported 64% compute cost reduction internally
- Available on Enterprise tier
- Requires Fusion engine

### Cost Insights (Enterprise)

- Use dbt Explorer's cost insights for visibility into model execution costs
- Review performance insights for optimization recommendations
- Monitor historical execution times to identify regression
