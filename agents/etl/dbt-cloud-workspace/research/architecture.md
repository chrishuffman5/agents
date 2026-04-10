# dbt Cloud Architecture

## Platform Overview

dbt Cloud is a managed SaaS platform built on top of dbt Core that provides a web-based IDE, job orchestration, metadata APIs, a semantic layer, and collaboration features for data transformation workflows. It runs dbt Core under the hood but adds significant infrastructure, governance, and developer experience layers.

## Development Surfaces

### Cloud IDE (Studio IDE)
- Browser-based development environment for writing, testing, and documenting dbt models
- Syntax highlighting, autocomplete, real-time DAG visualization
- No local setup required; includes file editor, Git integration, and preview/compile capabilities
- Supports SQL linting (SQLFluff) and formatting inline
- Preview results directly in the IDE before committing changes

### dbt Cloud CLI
- Local command-line interface that connects to dbt Cloud development environment
- Enables local development with cloud features (deferral, cross-project refs, etc.)
- Authenticates against dbt Cloud for credential management and artifact resolution

### VS Code Extension
- Official dbt Labs VS Code extension for local development
- Integrates with the dbt Fusion engine for fast parsing and validation
- Language server (LSP) cache for improved compile times
- Supports OAuth authentication to dbt platform (for Claude, Cursor, VS Code)

### dbt Canvas (Visual Editor)
- Drag-and-drop visual interface for building data models without writing SQL
- GA for Enterprise customers
- Analysts can discover sources/models, apply transformations (joins, filters, aggregations)
- Preview outputs step-by-step; all work compiles to SQL automatically
- Includes always-on data profiling, context-aware AI (dbt Copilot), Git-based version control
- Analysts can commit work and open PRs directly from Canvas

## dbt Fusion Engine

- Next-generation execution engine written in Rust
- Public beta launched May 2025; defaulting for new projects on supported adapters
- 30x faster parse times than dbt Core
- Local query validation from the command line
- Compile cache for faster developer feedback loops
- Supports Snowflake, Databricks, BigQuery, and Redshift
- Native understanding of SQL across multiple engine dialects
- Advanced CI (dbt compare) supported in Fusion

## Environments

### Development Environment
- Each developer gets a personal development environment
- Uses individual developer credentials for warehouse access
- Supports deferral to production/staging for resolving `{{ ref() }}` calls without building upstream models
- Environment variables available: `DBT_CLOUD_ENVIRONMENT_NAME`, `DBT_CLOUD_ENVIRONMENT_TYPE`

### Staging Environment
- Optional intermediate environment for testing with production-like tools
- Limits access to production data while enabling advanced features
- Supports deferral and cross-project references
- Useful for release branch testing before production deployment

### Production Environment
- Designated production environment for scheduled and deploy jobs
- Stores manifest artifacts used for state comparison in CI and deferral
- Should be specified explicitly in dbt Cloud for accurate state tracking

### Deployment Environments
- Separate from development; used for scheduled, CI, and deploy jobs
- Each environment can have different warehouse credentials and dbt versions
- Environment object tracks definition (intended) vs. applied (actual) state for nodes

## Job Types

### Scheduled Jobs
- Cron-based scheduling for regular dbt runs (build, test, snapshot, etc.)
- Configurable frequency, model selection, and commands
- Email and Slack notifications for job status
- Logging and alerting built in

### CI Jobs (On Pull Request)
- Triggered automatically when a PR is opened or new commits are pushed
- Slim CI: uses `state:modified+` selector to run only changed models and their children
- Defers to production environment for artifact comparison
- Advanced CI: compare changes feature shows data-level diffs between PR and production
- SQL linting (SQLFluff) can run as a pre-build step in CI jobs
- Custom state selectors configurable (exclude models, tags, run further downstream)

### API-Triggered Jobs
- Jobs can be triggered via the Administrative API
- Webhook integration for external orchestration tools
- Supports event-driven workflows with external systems

### Merge/Deploy Jobs
- Triggered on merge to the main branch
- Runs full or selective builds in the production environment

## Scheduler and Orchestration

- Built-in job scheduling with cron expressions
- Event-based triggering (PR merge, upstream completion, API calls)
- State-aware orchestration: skips models that already satisfy freshness requirements
- Job queuing, execution monitoring, and run history
- Fusion Latest improves scheduler performance

## APIs

### Administrative API (v2 and v3)
- Manage accounts, projects, environments, jobs, runs, and users programmatically
- v3 is the recommended version
- Enabled by default for Starter, Enterprise, and Enterprise+ plans
- Runs endpoint supports performance monitoring and GCP connections

### Discovery API (GraphQL)
- Query comprehensive DAG metadata: models, sources, tests, exposures, metrics
- Environment-level and node-level queries
- Supports data monitoring, alerting, lineage exploration, automated reporting
- Metadata-only service tokens for scoped access
- Paginated endpoints for large-scale metadata queries

### Semantic Layer APIs
- **GraphQL API**: Strongly-typed interface for querying metrics and dimensions; includes `queryRecords` endpoint
- **JDBC API**: Based on Apache Arrow Flight SQL; SQL-like metric queries; used by BI tool integrations
- **ADBC (Arrow Database Connectivity)**: Alternative connectivity option
- **Python SDK**: Programmatic access to Semantic Layer

### Webhooks
- Event-driven notifications for job status changes
- Events include `job.run.completed`, with `runStatus`/`runStatusCode` filtering
- 10-second timeout per delivery; 5 retry attempts; 30-day delivery log retention
- Integrates with Admin API and Discovery API for enriched event data

## Semantic Layer

### MetricFlow Engine
- Open-source metric computation framework powering the dbt Semantic Layer
- Defines metrics, dimensions, entities, and semantic models in YAML
- SQL engine determines optimal join paths between tables automatically
- Pushes computations down to the warehouse for performance

### Core Concepts
- **Semantic Models**: Define the structure of data (entities, dimensions, measures)
- **Entities**: Join keys that serve as traversal paths between semantic models
- **Dimensions**: Attributes for grouping/slicing metrics (categorical, time-based)
- **Measures**: Aggregations on columns (sum, count, average, etc.)
- **Metrics**: Business definitions combining measures with filters and calculations
- **Saved Queries**: Pre-defined metric queries for reuse

### API Access
- GraphQL and JDBC APIs for downstream consumption
- Metric alias support in both APIs
- Paginated metadata endpoints
- Native integrations with Tableau, Power BI, Hex, Mode, and others
- Any BI tool can connect via JDBC, ADBC, GraphQL, or Python SDK

## dbt Explorer (Catalog)

- Visual lineage exploration with interactive DAG navigation
- Click on nodes for context: run status, description, dependencies
- Global search across all project resources
- Column-level lineage across sources and models
- Multi-project lineage for dbt Mesh architectures
- Performance insights with historical model execution data
- Project optimization recommendations
- Documentation hosting updated after each production run

## dbt Mesh (Multi-Project Architecture)

### Core Concepts
- Multiple dbt projects aligned to business domains
- Federated ownership with cross-project dependencies
- Enables scaling data collaboration without sacrificing quality

### Access Modifiers
- **Private**: Only referenceable within the same group
- **Protected**: Referenceable within the same project or when installed as a package
- **Public**: Referenceable across groups, packages, and projects; suitable for stable interfaces

### Cross-Project References
- Two-argument `{{ ref('project_name', 'model_name') }}` syntax
- Upstream model must have `access: public` configured
- Full cross-project lineage rendered in dbt Explorer

### Model Contracts
- Define upfront guarantees about model shape (columns, types, constraints)
- dbt verifies transformation output matches the contract at build time
- Prevents non-compliant data from flowing downstream

### Model Versioning
- Treat data models as stable APIs with versioned interfaces
- Prerelease testing, latest version designation, migration windows
- `deprecation_date` for graceful sunsetting of old versions

### Cross-Platform Mesh (Iceberg)
- Apache Iceberg catalog integration on Snowflake and BigQuery
- Enables interoperability across different warehouse platforms
- Lineage renders in dbt Explorer; builds pick up upstream changes automatically

## Integration Points

### Git Providers
- **GitHub**: Native integration with OAuth; PR-triggered CI jobs
- **GitLab**: Deploy token/key integration; repository connection
- **Azure DevOps**: Native integration for repository and CI/CD
- **Bitbucket**: Supported for code management
- **Managed Repository**: dbt-hosted Git for simple setups
- **Git Clone**: SSH/deploy key for any Git provider

### Data Warehouses
- **Snowflake**: Full support including Iceberg, PrivateLink
- **BigQuery**: Full support including Iceberg
- **Databricks**: Full support including SQL warehouses optimization
- **Redshift**: Full support with Fusion engine
- **PostgreSQL**: Supported
- Additional adapters via community plugins

### BI Tools (via Semantic Layer)
- **Tableau**: Native integration (Desktop and Server); live connection
- **Power BI**: Native integration; live connection to Semantic Layer
- **Looker**: Supported via Semantic Layer APIs
- **Mode**: Supported via JDBC/Semantic Layer
- **Hex**: Semantic Layer cells for direct metric queries
- **Excel**: Supported via Semantic Layer integrations
- **DataGrip/DBeaver**: Via JDBC driver
- Any tool supporting JDBC, ADBC, GraphQL, or Python SDK

### External Orchestrators
- GitHub Actions, GitLab CI, Azure DevOps Pipelines
- Airflow, Prefect, Dagster (via API triggers)
- Webhook-based integration with any external system
