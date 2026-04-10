# dbt Cloud Best Practices

## Environment Strategy

### Recommended Environment Layout
1. **Development**: Per-developer environments with individual credentials; use deferral to avoid building upstream models
2. **Staging** (optional): Intermediate environment for release branch testing; limits access to production data while enabling advanced features (deferral, cross-project refs)
3. **Production**: Designated production environment for scheduled and deploy jobs; stores manifest artifacts for state comparison

### Environment Variables
- Use `{{ env_var('DBT_KEY', 'default') }}` for environment-specific configuration
- Store sensitive credentials (passwords, API keys) as environment variables to prevent accidental commits
- Leverage built-in variables: `DBT_CLOUD_ENVIRONMENT_NAME`, `DBT_CLOUD_ENVIRONMENT_TYPE`
- Configure separate schemas or databases per environment for data isolation

### Deferred Builds
- Enable deferral in development environments to resolve `{{ ref() }}` against production artifacts
- Developers only need to build/run/test edited models, not entire upstream DAG
- Saves significant compute and storage costs
- If additional production data controls are needed, defer to staging instead of production
- Regularly regenerate comparison manifests via scheduled `dbt compile` jobs in staging

### Environment Configuration
- Each environment can run a different dbt version (Fusion Latest is now the default for new projects)
- Use separate warehouse credentials per environment with least-privilege access
- Restrict production credentials to production jobs only
- Keep secrets out of Git; use dbt Cloud's credential management

## CI/CD Workflows

### Slim CI (State Comparison)
- **Core concept**: Use `state:modified+` selector to run only modified models and their children
- In dbt Cloud, configure a CI job to defer to the production environment; artifact storage is automatic
- Significantly reduces compute costs and CI execution time
- dbt compares PR code against the last successful deploy job manifest in the deferred environment

### CI Job Configuration
- Trigger CI jobs automatically on PR open or new commit push
- Enable SQL linting (SQLFluff) as a pre-build step for code quality
- Use Advanced CI (Enterprise) for compare changes to see data-level diffs
- Customize state selectors to exclude certain models or tags from comparison

### Deploy/Merge Jobs
- Trigger deploy jobs on merge to main branch
- Run `dbt build` (or selective commands) in the production environment
- Consider running full builds on a schedule vs. merge-triggered incremental builds

### Recommended CI/CD Flow
1. Developer creates feature branch and develops in IDE/CLI with deferral
2. PR opens → CI job auto-triggers with Slim CI
3. CI runs modified models + downstream, lints SQL, compares data changes
4. PR reviewed and approved
5. Merge → deploy job runs in production
6. Scheduled jobs handle regular full refreshes

### Release Branch Strategy (Advanced)
- Feature branches merge into a release branch
- Slim CI job in staging environment runs release branch code, deferring to production
- Weekly or periodic releases from release branch to main/production

## Semantic Layer Best Practices

### When to Define Metrics
- Define metrics for key business KPIs that need a single source of truth (revenue, churn, DAU, etc.)
- Useful when the same metric is consumed by multiple BI tools or teams
- Start with critical metrics that suffer from inconsistent definitions across the organization
- Add metrics incrementally; avoid trying to define everything at once

### How to Define Metrics
- Prefer computing values in measures and metrics rather than frozen rollups
- Define explicit expressions (e.g., `revenue - cost`) to prevent deviating calculations
- Set appropriate filters within metric definitions to eliminate ambiguity
- Use entities as join keys for traversal paths between semantic models
- Use dimensions for grouping and slicing metrics (categorical and time-based)

### Governance Patterns
- Validate semantic nodes in CI to ensure code changes do not break metrics
- Centralize metric definitions so downstream consumers cannot create divergent calculations
- Use saved queries for common metric combinations
- Document metrics with clear descriptions and business context
- Leverage dbt Copilot for auto-generated metric definition recommendations

### Performance Optimization
- MetricFlow pushes computations to the warehouse; a well-tuned warehouse equals faster queries
- For heavy metrics requiring complex calculations over large datasets, consider precomputing daily aggregate tables via dbt jobs
- Use incremental models or materializations for performance-sensitive metrics
- Balance precomputation with flexibility on a case-by-case basis

## Multi-Project (Mesh) Best Practices

### When to Split Projects
- When a single project becomes too large for one team to manage effectively
- When distinct business domains (finance, marketing, product) need independent ownership
- When deployment cycles differ across domains
- When teams need isolated CI/CD pipelines and release processes
- Do not split prematurely; governance overhead increases with each project

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

### Model Versioning
- Treat public models as stable APIs with versioned interfaces
- Test prerelease changes in production and downstream systems before bumping the latest version
- Offer migration windows off deprecated versions
- Use `deprecation_date` to notify downstream consumers of planned model removal

### Cross-Project References
- Update `{{ ref() }}` to two-argument form: `{{ ref('source_project', 'model_name') }}`
- Ensure upstream models have `access: public` configured
- Lineage renders automatically in dbt Explorer across projects
- Iceberg catalog integration enables cross-platform Mesh (Snowflake + BigQuery)

## Collaboration Best Practices

### PR Reviews
- Require PR reviews for all changes before merging to production
- CI jobs provide automated validation; reviewers can check data-level diffs (Advanced CI)
- Use `dbt docs generate` to ensure documentation is updated alongside code
- Review model contracts and access modifiers for any public-facing changes

### Documentation Standards
- Leverage dbt Copilot for auto-generated documentation as a starting point
- Document all public models with clear descriptions, column descriptions, and business context
- Keep documentation in YAML files alongside model definitions
- Auto-hosted documentation in dbt Cloud updates after each production run
- Use dbt Explorer for interactive documentation browsing

### IDE Workflows
- **Studio IDE**: Good for quick edits, onboarding, and environments without local setup
- **VS Code + Fusion**: Preferred for power users; faster compile times, local query validation
- **Canvas**: Ideal for analysts who prefer visual interfaces over SQL
- Save files before running dbt commands (unsaved changes are not picked up)
- Use dbt Cloud CLI for teams that prefer local development with cloud benefits

## Cost Optimization

### dbt Cloud Platform Costs
- Choose the appropriate tier based on team size and feature needs
- Developer (free) for individual experimentation
- Starter for small teams needing Semantic Layer and collaboration
- Enterprise for organizations needing governance, security, and Mesh

### Run Frequency Optimization
- Align scheduling with data availability; do not refresh hourly if data arrives once daily
- More frequent runs enable more model reuse via state-aware orchestration
- Use `state:modified+` in scheduled jobs to skip unchanged models
- Balance freshness requirements against compute costs

### Model Selection
- Use Slim CI to avoid rebuilding unchanged models
- Use tags, state comparison (`--state`), or `dbt run --select` for targeted runs
- Defer to production in development to avoid building upstream models
- Use incremental models for large datasets to process only new/changed data

### Warehouse Compute
- Start with a medium-sized warehouse and adjust based on workload
- Configure auto-suspend after 1-2 minutes of inactivity
- Use separate warehouses for transformation vs. ad-hoc queries vs. reporting
- Optimize heavy models with partitioning, clustering, and reduced joins
- SQL warehouses are optimized for dbt workloads (especially on Databricks)

### State-Aware Orchestration
- Enable state-aware orchestration to skip models that satisfy freshness requirements
- dbt Labs reported 64% compute cost reduction internally using Fusion + state-aware orchestration
- No rebuild when nothing upstream has changed

### Cost Insights (Enterprise)
- Use dbt Explorer's cost insights for visibility into model execution costs
- Review performance insights for optimization recommendations
- Monitor historical execution times to identify regression
