# dbt Cloud Architecture Deep Dive

## Platform Overview

dbt Cloud is a managed SaaS platform built on dbt Core that adds infrastructure, governance, and developer experience layers for data transformation. It runs dbt Core under the hood but provides web-based development, job orchestration, hosted documentation, a Semantic Layer with API access, and enterprise security.

## Development Surfaces

### Studio IDE (Cloud IDE)

Browser-based development environment:

- Syntax highlighting, autocomplete, real-time DAG visualization
- File editor with inline preview and compile capabilities
- Git integration: branching, committing, opening PRs directly from the IDE
- SQLFluff linting and formatting inline
- No local installation required
- Supports SQL linting as a pre-build step

**Key considerations**:
- Save files (Cmd+S / Ctrl+S) before running dbt commands -- unsaved changes are not picked up
- IDE sessions can be affected by platform incidents (check status.getdbt.com)
- Refresh browser or restart session if compilation results seem stale

### dbt Canvas (Visual Editor)

Drag-and-drop visual interface for building models without writing SQL:

- GA for Enterprise customers
- Discover sources and models, apply transformations (joins, filters, aggregations)
- Preview outputs step by step with always-on data profiling
- All work compiles to SQL automatically
- Git-based version control: commit and open PRs from Canvas
- Includes dbt Copilot AI assistance
- Best for analysts who prefer visual interfaces over raw SQL

### dbt Cloud CLI

Local command-line interface connected to dbt Cloud development environment:

- Enables local development with cloud features (deferral, cross-project refs)
- Authenticates against dbt Cloud for credential management and artifact resolution
- Runs dbt commands locally but resolves refs and sources using cloud context
- Configuration via `dbt_cloud.yml` or `profiles.yml`

### VS Code Extension

Official dbt Labs VS Code extension:

- Integrates with dbt Fusion engine for fast parsing and validation
- Language server (LSP) with compile cache for improved developer feedback
- OAuth authentication to dbt platform
- Supports Claude, Cursor, and VS Code as clients
- Preferred development surface for power users

## dbt Fusion Engine

Next-generation execution engine written in Rust:

- Public beta launched May 2025
- **30x faster parse times** than dbt Core
- Local query validation from the command line
- Compile cache for faster developer feedback loops
- Default for new projects on supported adapters (Snowflake, Databricks, BigQuery, Redshift)
- Native SQL understanding across multiple engine dialects
- Advanced CI (dbt compare) supported in Fusion

The Fusion engine represents a significant architectural shift from the Python-based dbt Core engine. While feature parity is still in progress, it is the recommended engine for new projects.

## Environments

### Development Environment

- Each developer gets a personal development environment
- Uses individual developer credentials for warehouse access
- Supports **deferral** to production/staging for resolving `{{ ref() }}` without building upstream models
- Built-in variables: `DBT_CLOUD_ENVIRONMENT_NAME`, `DBT_CLOUD_ENVIRONMENT_TYPE`
- Developers only need to build/run/test edited models

### Staging Environment (Optional)

- Intermediate environment for release branch testing
- Limits access to production data while enabling advanced features
- Supports deferral and cross-project references
- Useful for release branch strategies before production deployment

### Production Environment

- Designated production environment for scheduled and deploy jobs
- Stores manifest artifacts used for state comparison in CI and deferral
- Should be specified explicitly for accurate state tracking

### Environment Configuration

- Each environment can run a different dbt version
- Fusion Latest is the default for new projects on supported adapters
- Separate warehouse credentials per environment with least-privilege access
- Environment tracks both definition (intended) and applied (actual) state for nodes

## Job Types

### Scheduled Jobs

- Cron-based scheduling for regular dbt runs (build, test, snapshot)
- Configurable frequency, model selection, and commands
- Email and Slack notifications for job status
- Job queuing, execution monitoring, and run history

### CI Jobs (On Pull Request)

- Triggered automatically when a PR is opened or new commits pushed
- **Slim CI**: `state:modified+` selector runs only changed models and children
- **Advanced CI** (Enterprise): Compare changes shows data-level diffs between PR and production
- SQLFluff linting as a pre-build step
- Defers to production environment for artifact comparison
- Custom state selectors configurable (exclude models, tags, run further downstream)

### Deploy/Merge Jobs

- Triggered on merge to main branch
- Runs full or selective builds in the production environment
- Can combine scheduled and merge-triggered strategies

### API-Triggered Jobs

- Triggered via the Administrative API
- Webhook integration for external orchestration tools (Airflow, Prefect, Dagster)
- Supports event-driven workflows with external systems

## Scheduler and Orchestration

- Built-in job scheduling with cron expressions
- Event-based triggering: PR merge, upstream completion, API calls
- **State-aware orchestration**: Skips models that already satisfy freshness requirements
- Job queuing, execution monitoring, and run history
- dbt Labs reported 64% compute cost reduction with Fusion + state-aware orchestration

## APIs

### Administrative API (v2 and v3)

- Manage accounts, projects, environments, jobs, runs, users programmatically
- v3 is recommended for new integrations
- Enabled by default for Starter, Enterprise, and Enterprise+ plans
- Use cases: trigger jobs from external orchestrators, monitor run status, manage resources

### Discovery API (GraphQL)

- Query comprehensive DAG metadata: models, sources, tests, exposures, metrics
- Environment-level and node-level queries
- Supports data monitoring, alerting, lineage exploration, automated reporting
- Metadata-only service tokens for scoped access
- Paginated endpoints for large-scale metadata queries

### Semantic Layer APIs

| API | Protocol | Use Case |
|---|---|---|
| **GraphQL** | HTTP | Strongly-typed metric queries; `queryRecords` endpoint |
| **JDBC** | Arrow Flight SQL | BI tool integrations (Tableau, Power BI, DataGrip) |
| **ADBC** | Arrow Database Connectivity | Alternative connectivity option |
| **Python SDK** | Python | Programmatic access to Semantic Layer |

### Webhooks

- Event-driven notifications for job status changes
- Events: `job.run.completed` with `runStatus`/`runStatusCode` filtering
- 10-second timeout per delivery; 5 retry attempts; 30-day log retention
- Integrates with Admin API and Discovery API for enriched event data

## Semantic Layer

### MetricFlow Engine

Open-source metric computation framework powering the Semantic Layer:

- Defines metrics, dimensions, entities, and semantic models in YAML
- Determines optimal join paths between tables automatically (semantic graph)
- Pushes computations down to the warehouse for performance
- Licensed under Apache 2.0; integrated with dbt Core 1.6+

### Core Concepts

```yaml
semantic_models:
  - name: orders
    model: ref('fct_orders')
    defaults:
      agg_time_dimension: ordered_at
    entities:
      - name: order_id
        type: primary
      - name: customer_id
        type: foreign
    dimensions:
      - name: ordered_at
        type: time
        type_params:
          time_granularity: day
      - name: order_status
        type: categorical
    measures:
      - name: order_total
        agg: sum
        expr: amount
      - name: order_count
        agg: count
        expr: order_id
```

- **Entities**: Join keys (primary, foreign, unique, natural)
- **Dimensions**: Attributes for grouping/filtering (categorical, time)
- **Measures**: Aggregatable expressions (sum, count, average, min, max, count_distinct)
- **Metrics**: Business definitions combining measures with filters (simple, derived, cumulative, ratio, conversion)

### BI Tool Integrations

Native integrations: Tableau (Desktop + Server), Power BI, Hex (Semantic Layer cells), Mode, Excel, DataGrip/DBeaver. Any tool supporting JDBC, ADBC, GraphQL, or Python SDK can connect.

## dbt Explorer (Catalog)

- Interactive DAG lineage visualization with click-through navigation
- Column-level lineage across sources and models
- Multi-project lineage for dbt Mesh architectures
- Global search across all project resources
- Performance insights with historical model execution data
- Project optimization recommendations and cost insights
- Documentation auto-updated after each production run

## dbt Mesh (Multi-Project Architecture)

### Access Modifiers

| Modifier | Scope |
|---|---|
| `private` | Only referenceable within the same group |
| `protected` | Referenceable within the same project (default) |
| `public` | Referenceable from any project; stable interface |

### Model Contracts

Define upfront guarantees about model shape:

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

dbt verifies output matches the contract at build time. Prevents non-compliant data from flowing downstream.

### Model Versioning

Treat data models as stable APIs with versioned interfaces:

```yaml
models:
  - name: customers
    latest_version: 2
    versions:
      - v: 1
        deprecation_date: 2026-06-01
      - v: 2
```

Reference specific versions: `{{ ref('customers', v=2) }}`

### Cross-Platform Mesh (Iceberg)

Apache Iceberg catalog integration on Snowflake and BigQuery enables interoperability across warehouse platforms. Lineage renders in dbt Explorer. Builds pick up upstream changes automatically.

## Git Provider Integration

| Provider | Integration Type | Notes |
|---|---|---|
| **GitHub** | Native OAuth | PR-triggered CI jobs |
| **GitLab** | Deploy token/key | Repository connection |
| **Azure DevOps** | Native | Repository and CI/CD |
| **Bitbucket** | Supported | Code management |
| **Managed Repository** | dbt-hosted Git | Simplest setup |

## Enterprise Security

- **SSO**: SAML-based Single Sign-On
- **SCIM**: Automated user provisioning and deprovisioning
- **RBAC**: Pre-built permission sets for granular access control
- **Audit Logging**: Real-time logs of user and system events; 12-month retention
- **IP Restrictions**: Control which IPs can connect (Enterprise+)
- **PrivateLink**: AWS and Azure PrivateLink for secure connectivity (Enterprise+)
- **Compliance**: SOC 2 Type II, ISO 27001:2022, HIPAA supported

## dbt Copilot (AI Features)

GA since March 2025. Available on Starter, Enterprise, and Enterprise+ plans.

- Inline code assistance in Studio IDE, Canvas, and Insights
- **Developer Agent**: Writes/refactors models, validates changes
- **Analyst Agent**: Natural language questions powered by Semantic Layer
- Auto-generated documentation and tests
- SQL formatting and query optimization via natural language
- BYOK (bring your own key) on Enterprise/Enterprise+ only
