# dbt Cloud Features

## Current Capabilities

### Development Surfaces
- **Studio IDE**: Browser-based SQL/YAML editor with syntax highlighting, autocomplete, DAG visualization, preview, and compile
- **dbt Cloud CLI**: Local development with cloud features (deferral, cross-project refs, credential management)
- **VS Code Extension**: Local IDE with Fusion engine integration, LSP caching, OAuth authentication
- **dbt Canvas**: Visual drag-and-drop editor for building models without SQL (Enterprise)

### Scheduler and Orchestration
- Cron-based job scheduling with configurable frequency and model selection
- Event-driven triggers: PR open/update, merge, upstream completion, API calls
- State-aware orchestration: skips models that satisfy freshness requirements
- Job queuing, execution monitoring, run history, and notifications (email, Slack)
- Multiple job types: scheduled, CI, deploy, API-triggered

### Documentation and Lineage (dbt Explorer / Catalog)
- Auto-hosted documentation updated after each production run
- Interactive DAG lineage visualization
- Column-level lineage across sources and models
- Multi-project lineage for Mesh architectures
- Global search across all project resources
- Performance insights and optimization recommendations
- Node-level context: run status, descriptions, dependencies

### Semantic Layer
- MetricFlow-powered metric definitions in YAML
- Centralized business metrics: revenue, churn, DAU, etc.
- APIs: GraphQL, JDBC (Arrow Flight SQL), ADBC, Python SDK
- Native BI integrations: Tableau, Power BI, Hex, Mode, Excel
- Saved queries for reusable metric definitions
- Metric alias support in APIs

### Multi-Project Architecture (dbt Mesh)
- Cross-project references with `{{ ref('project', 'model') }}`
- Access modifiers: private, protected, public
- Model contracts for data shape guarantees
- Model versioning with deprecation dates
- Cross-platform Mesh via Apache Iceberg (Snowflake, BigQuery)
- Full cross-project lineage in Explorer

### APIs and Webhooks
- Administrative API (v2, v3) for programmatic management
- Discovery API (GraphQL) for metadata, lineage, monitoring
- Semantic Layer APIs for metric consumption
- Webhooks for event-driven integrations (5 retries, 30-day logs)

## dbt Cloud vs dbt Core: Feature Comparison

| Capability | dbt Core (Open Source) | dbt Cloud |
|---|---|---|
| SQL/Jinja transformations | Yes | Yes |
| Models, tests, seeds, snapshots | Yes | Yes |
| Command-line execution | Yes | Yes (CLI + IDE) |
| Web-based IDE | No | Yes (Studio IDE, Canvas) |
| Job scheduling | No (external tools needed) | Built-in scheduler |
| CI/CD automation | Manual (GitHub Actions, etc.) | Native CI jobs on PR |
| Advanced CI (compare changes) | No | Yes (Enterprise) |
| Documentation hosting | Self-hosted static site | Auto-hosted, auto-updated |
| Column-level lineage | No | Yes (Enterprise) |
| Semantic Layer (hosted) | MetricFlow OSS only | Full hosted service with APIs |
| Multi-project Mesh | Limited (dbt-loom community) | Native cross-project refs |
| RBAC / SSO / SCIM | No | Yes (Enterprise) |
| Audit logging | No | Yes (Enterprise) |
| Visual editor (Canvas) | No | Yes (Enterprise) |
| AI Copilot | No | Yes (Starter+) |
| dbt Fusion engine | Available locally | Full platform integration |
| Environment management | Manual profiles.yml | UI-based with credential isolation |
| Git integration | Manual Git workflows | Native GitHub/GitLab/Azure DevOps |
| Notifications | No | Email, Slack, webhooks |
| State-aware orchestration | No | Yes |
| IP restrictions / PrivateLink | No | Yes (Enterprise+) |

### What dbt Cloud Adds Over Core
1. **Managed infrastructure**: No need to host, schedule, or monitor dbt runs
2. **Developer experience**: Web IDE, Canvas, and VS Code integration with cloud features
3. **Governance**: RBAC, SSO, audit logs, model contracts enforcement in CI
4. **Collaboration**: PR-based workflows, shared environments, documentation hosting
5. **Observability**: Explorer, lineage, performance insights, cost insights
6. **Semantic Layer**: Hosted MetricFlow with API access for BI tools
7. **AI assistance**: dbt Copilot for code generation, documentation, testing
8. **Enterprise security**: PrivateLink, IP restrictions, SOC 2, ISO 27001, HIPAA

## Recent Additions (2024-2026)

### dbt Canvas (Visual Editor)
- GA for Enterprise customers
- Drag-and-drop interface for building models without SQL
- Analysts can discover sources, apply transformations, preview results
- Compiles to SQL automatically; integrates with Git for PR workflows
- Includes dbt Copilot AI assistance and data profiling

### dbt Copilot (AI Features)
- GA since March 2025
- Inline code assistance in Studio IDE, Canvas, and Insights
- **Developer Agent**: Writes/refactors models, validates changes
- **Analyst Agent**: Natural language questions powered by Semantic Layer
- Auto-generated documentation and tests
- SQL formatting and query optimization via natural language
- Semantic layer and metric definition recommendations
- Available on Starter, Enterprise, and Enterprise+ plans
- BYOK (bring your own key) on Enterprise/Enterprise+ only

### Advanced CI
- Compare changes: data-level diffs between PR and production
- Custom state selectors for comparison (exclude models, tags)
- SQL linting (SQLFluff) as CI pre-build step (GA for Team/Enterprise)
- Supported in dbt Fusion engine

### dbt Fusion Engine
- Rust-based engine, public beta May 2025
- 30x faster parse times than dbt Core
- Local query validation and compile cache
- Default for new projects on supported adapters
- Supports Snowflake, Databricks, BigQuery, Redshift

### Cross-Platform Mesh (Iceberg)
- Apache Iceberg catalog integration on Snowflake and BigQuery
- Cross-warehouse interoperability for Mesh architectures
- Lineage rendering and automatic change detection

### State-Aware Orchestration
- Skip rebuilds when models satisfy freshness requirements
- Reduced compute costs (dbt Labs reported 64% compute cost reduction internally)

### dbt MCP Server
- OAuth authentication for local dbt MCP server
- Supported for Claude, Cursor, and VS Code
- Reduces local secret management

## Enterprise Features

### Security and Compliance
- **SSO**: SAML-based Single Sign-On
- **SCIM**: Automated user provisioning and deprovisioning
- **RBAC**: Pre-built permission sets for granular access control
- **Audit Logging**: Real-time logs of user and system events; 12-month retention
- **IP Restrictions**: Control which IPs can connect to dbt Cloud
- **PrivateLink**: AWS and Azure PrivateLink for secure warehouse connectivity (Enterprise+)
- **SOC 2 Type II**: Examination through September 2025
- **ISO 27001:2022**: Certified since 2021, most recent audit November 2025
- **HIPAA**: Compliance supported

### Enterprise Governance
- Column-level lineage
- Multi-project lineage
- Model contracts and versioning
- Advanced CI with compare changes
- Canvas visual editor
- Project optimization recommendations
- Cost insights

## Licensing Tiers

### Developer (Free)
- 1 developer seat
- 3,000 successful models built per month
- Browser-based IDE
- Job scheduling
- Basic features

### Starter ($100/user/month)
- Up to 5 developer seats
- 15,000 models per month
- 5,000 queried metrics per month
- Semantic Layer access
- dbt Copilot
- APIs (Admin, Discovery, Semantic Layer)

### Enterprise (Custom pricing)
- Up to 100,000 models per month
- 20,000 queried metrics per month
- 30 projects
- SSO (SAML) and SCIM
- RBAC with granular permissions
- Audit logging
- Advanced CI (compare changes)
- Canvas visual editor
- Column-level lineage
- dbt Copilot with BYOK option
- Priority support

### Enterprise+ (Custom pricing)
- Unlimited projects
- PrivateLink (AWS, Azure)
- IP restrictions
- All Enterprise features
- Enhanced security and networking options
