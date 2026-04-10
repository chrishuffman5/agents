# Looker Research Summary

## Platform Identity

Looker is Google Cloud's enterprise business intelligence and analytics platform, differentiated by its code-first approach through LookML, a declarative semantic modeling language. Acquired by Google in 2020, Looker has evolved from a standalone BI tool into the semantic layer backbone of Google Cloud's data analytics stack. Google was recognized as a Leader in the 2025 Gartner Magic Quadrant for Analytics and Business Intelligence Platforms.

---

## Key Architectural Takeaways

### LookML Semantic Layer

The core differentiator is LookML, which creates a centralized, version-controlled definition of business logic between raw database tables and end users. This semantic layer ensures metric consistency regardless of consumption tool (Looker UI, Looker Studio, Tableau, Power BI, or custom applications via the Open SQL Interface).

### Direct Query Model

Looker does not extract or store source data. It generates optimized SQL against connected databases in real time, with caching and PDTs as performance optimization layers rather than data storage.

### Deployment Flexibility

- **Looker (Google Cloud Core)**: Fully managed by Google, provisioned via Google Cloud console
- **Customer-Hosted**: Self-managed on VMs or Kubernetes (Helm-based deployments recommended)
- Google recommends Kubernetes-based architecture for customer-hosted deployments

---

## Current Feature Landscape (2025-2026)

### AI and Gemini Integration

The most significant evolution. Looker now includes:

- **Conversational Analytics**: Natural language data querying grounded in LookML definitions (Looker 25.0+)
- **LookML Assistant**: AI-generated LookML code from natural language (Looker 25.2+)
- **Visualization Assistant**: Natural language chart customization
- **Code Interpreter**: Python code generation for forecasting and anomaly detection (experimental)
- **Conversational Analytics API**: Enables partners to build AI-powered analytics on Looker's semantic layer

### Universal Semantic Layer Expansion

The semantic layer now extends beyond Looker's UI:

- Open SQL Interface (JDBC) for any compatible tool
- Native BI connectors for Tableau, Power BI, and Google Sheets
- Looker Studio can connect directly to LookML models
- API access for custom applications

### Looker + Looker Studio Unification

Google is actively merging capabilities:

- Looker Studio in Looker is in Preview
- Each Looker license includes a Looker Studio Pro license
- Goal is unified governance with flexible visualization options

---

## Architecture Considerations

### Strengths

- **Governance-first design**: Row-level security, field-level access grants, centralized metric definitions
- **Version control**: Git-native development with branching, PRs, and deployment workflows
- **Extensibility**: Extension Framework, API, Embed SDK, Marketplace, and Open SQL Interface
- **Database-agnostic**: Supports 50+ SQL databases with dialect-aware SQL generation
- **Embedded analytics**: Mature embedding with SSO, SDK, programmatic control, and multi-tenant support

### Limitations

- **Steep learning curve**: LookML requires SQL knowledge and dedicated training
- **Pricing**: Premium enterprise pricing; not suitable for small teams or simple dashboards
- **AI features require Looker-hosted instances**: Customer-hosted deployments cannot use Gemini features
- **BigQuery affinity**: Deepest integration is with BigQuery; other databases have fewer native optimizations

---

## Best Practices Summary

### LookML Development

- Organize files by type (views/, explores/, models/) with one view per file
- Define primary keys on every view, including derived tables
- Always specify join relationships explicitly
- Use refinements for customizing imported/generated LookML; extends for creating variants
- Follow DRY principles with substitution operators and shared definitions

### Performance

- Use datagroups to synchronize caching with ETL schedules
- Convert expensive joins and subqueries into PDTs
- Add aggregate tables for common dashboard query patterns
- Apply always_filter on time-series Explores
- Keep dashboard tile counts reasonable; each tile generates a query

### Governance

- Require pull requests for LookML changes
- Run validation and data tests before deployment
- Layer permission sets, model sets, access grants, and access filters
- Use System Activity dashboards for ongoing monitoring
- Run Content Validator regularly to detect broken content

---

## Common Diagnostic Areas

| Area | Key Tools | Primary Causes |
|------|-----------|----------------|
| Slow Explores | System Activity, SQL Runner, Admin Queries | Complex joins, missing filters, database bottlenecks |
| PDT Failures | PDT Event Log, Admin PDT panel | Scratch schema issues, permissions, timeout, schema changes |
| Connection Issues | Admin Connections test, network tools | Firewall rules, credentials, SSL, connection pool exhaustion |
| LookML Errors | IDE validation, Content Validator | Typos, missing includes, circular references, wrong cardinality |
| Query Performance | System Activity History, Explore Recommendations | Missing indexes, no aggregate awareness, cache misses |

---

## Research File Index

| File | Contents |
|------|----------|
| [architecture.md](architecture.md) | LookML semantic layer, Explores, Views, Models, instance architecture, database connections, caching/PDTs, Looker Studio vs Looker, embedded analytics |
| [features.md](features.md) | Current capabilities, LookML refinements, Universal Semantic Layer, Extensions, Looker Studio Pro, AI/Gemini features |
| [best-practices.md](best-practices.md) | Project structure, Explore design, caching/PDT strategy, embedded analytics patterns, governance, version control |
| [diagnostics.md](diagnostics.md) | Slow Explores, PDT build failures, connection issues, LookML validation errors, query performance |

---

## Key Sources

- [Introduction to LookML](https://docs.cloud.google.com/looker/docs/what-is-lookml)
- [LookML Best Practices](https://docs.cloud.google.com/looker/docs/best-practices/best-practices-lookml-dos-and-donts)
- [Performance Optimization](https://docs.cloud.google.com/looker/docs/best-practices/how-to-optimize-looker-performance)
- [PDT Troubleshooting](https://docs.cloud.google.com/looker/docs/best-practices/pdt-troubleshooting)
- [Caching and Datagroups](https://docs.cloud.google.com/looker/docs/caching-and-datagroups)
- [LookML Refinements](https://docs.cloud.google.com/looker/docs/lookml-refinements)
- [Extension Framework](https://docs.cloud.google.com/looker/docs/intro-to-extension-framework)
- [Version Control and Deploying](https://docs.cloud.google.com/looker/docs/version-control-and-deploying-changes)
- [Looker Error Catalog](https://docs.cloud.google.com/looker/docs/error-catalog)
- [Opening up the Looker Semantic Layer](https://cloud.google.com/blog/products/business-intelligence/opening-up-the-looker-semantic-layer)
- [Looker (Google Cloud core) Overview](https://docs.cloud.google.com/looker/docs/looker-core-overview)
- [Looker AI Features 2025-2026](https://querio.ai/articles/looker-ai-features-natural-language-query-gemini-2025-2026)
- [Looker vs Looker Studio 2026](https://improvado.io/blog/looker-vs-looker-studio-comparison)
- [Looker Embedded Analytics 2026](https://qrvey.com/blog/looker-embedded-analytics/)
- [Looker Marketplace](https://cloud.google.com/looker/docs/marketplace)
