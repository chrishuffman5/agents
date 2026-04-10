# Qlik Sense Research Summary

## Platform Identity

Qlik Sense is an enterprise analytics and business intelligence platform differentiated by its proprietary Qlik Associative Engine (QIX Engine). Unlike SQL-based BI tools that rely on predefined queries and drill paths, Qlik's engine dynamically indexes all data associations in memory, enabling unrestricted data exploration across the entire data model. This architectural distinction is the foundation of Qlik's competitive positioning and shapes every aspect of the platform -- from data modeling to performance optimization.

## Architecture Highlights

- **QIX Engine**: 64-bit, multi-threaded, in-memory associative engine using columnar storage with symbol/data table compression. "QIX Engine" and "Qlik Associative Engine" are the same technology under different branding.
- **Deployment Options**: Qlik Cloud (SaaS on AWS, Kubernetes-based microservices), Qlik Sense Enterprise on Windows (client-managed, multi-node shared persistence), and Qlik Sense Enterprise on Kubernetes (private cloud).
- **Qlik Cloud Architecture**: Container-based microservices on Kubernetes, MongoDB for metadata, NGINX for ingress, horizontal auto-scaling, zero-downtime deployments. Tested for 10,000+ users/hour.
- **App Model**: Self-contained .qvf files containing data model, load script, sheets, visualizations, and stories. Organized into sheets with a recommended Dashboard/Analysis/Reporting (DAR) pattern.
- **Embedding**: qlik-embed (web components) is the primary recommended framework, backed by nebula.js for visualization rendering. Legacy options include Capability APIs, iframe, and enigma.js for direct engine communication.

## Feature Landscape (2025-2026)

| Feature | Status | Notes |
|---------|--------|-------|
| **Qlik Answers** | GA (expanding 2026) | Agentic AI assistant combining structured analytics and unstructured data with LLMs; MCP integration for third-party assistants |
| **Discovery Agent** | GA March 2026 | Autonomous data exploration within Qlik Answers |
| **Insight Advisor** | Mature | NLP-based search, conversational analytics, auto-generated visualizations; merging with Qlik Answers |
| **Qlik Predict** | GA | Formerly AutoML; no-code ML model building, predictive scoring, scenario analysis |
| **Qlik Automate** | GA | Formerly Application Automation; no-code workflow builder with 400+ connectors |
| **Qlik Talend Cloud** | GA | Unified data integration and quality platform; ELT/ETL, CDC, data catalog |
| **Open Lakehouse** | Announced 2025 | Managed Apache Iceberg solution within Qlik Talend Cloud |
| **Qlik Reporting Service** | GA | Pixel-perfect PDF/PowerPoint report generation and scheduled distribution |
| **Embedded Analytics** | Mature | qlik-embed web components, OEM/white-label support, multi-tenant embedding |

Qlik's strategic direction is clearly toward agentic AI and the unification of structured/unstructured analytics under Qlik Answers, while maintaining the associative engine as the analytical core.

## Key Best Practices

### Data Modeling
- Star schema is the optimal structure for the associative engine
- Resolve synthetic keys and circular references proactively -- they are the most common causes of poor performance
- Use QVD files as an intermediate data layer (10-100x faster reads)
- Drop unused fields, separate date/time, and use AutoNumber for key optimization

### Performance
- Prefer set analysis over If() conditions in expressions (set filters apply before aggregation)
- Add calculation conditions to heavy objects to prevent full-dataset calculations
- Limit objects per sheet to 5-10; use containers for additional content
- For large datasets: QVD segmentation, ODAG, and application chaining are the primary strategies

### Governance
- Use managed spaces for production content in Qlik Cloud
- Implement section access for row-level security
- Standardize naming conventions and master items across the organization
- Track load scripts in version control

## Diagnostic Priorities

The most common performance and reliability issues in Qlik Sense deployments, ranked by frequency:

1. **Synthetic keys and circular references** -- Unresolved data model issues that degrade calculation performance and memory usage
2. **Excessive data loading** -- Loading full datasets when aggregates or filtered subsets would suffice; loading unused fields
3. **Inefficient expressions** -- Using If() instead of set analysis; nested Aggr(); string operations in measures
4. **Memory exhaustion** -- Apps exceeding available server RAM or Qlik Cloud's 5 GB per-app limit
5. **Reload failures** -- Expired credentials, changed source schemas, network timeouts, insufficient memory during load
6. **Connectivity issues** -- ODBC drivers not installed on all nodes, DSN misconfiguration, firewall/proxy blocking

### Key Diagnostic Tools
- Data Model Viewer (in-app) for model health assessment
- Operations Monitor app (client-managed) for system-wide metrics
- Performance Profiler for per-object calculation timing
- Windows PerfMon for hardware-level monitoring
- Qlik Management Console for reload logs and task management

## Research Sources

Research conducted April 2026 using current Qlik documentation (November 2025 and May 2025 releases), Qlik Community forums, Qlik developer portal, Qlik press releases, and third-party analyst reviews. Key source domains:

- help.qlik.com -- Official product documentation
- qlik.dev -- Developer portal and API references
- community.qlik.com -- Community articles and support knowledge base
- qlik.com/blog -- Product announcements and roadmap
- qlik.com/us/news -- Press releases (agentic AI, Open Lakehouse, MCP)
- G2, BARC, Gartner -- Independent analyst reviews and ratings

## Files in This Research Set

| File | Contents |
|------|----------|
| `architecture.md` | QIX engine internals, deployment models (SaaS/on-prem/Kubernetes), app model, data load scripting, set analysis, embedding frameworks, extension development, Qlik Cloud services |
| `features.md` | Current capabilities: visualization library, Insight Advisor, Qlik Answers, Qlik Predict, Qlik Automate, Talend integration, embedded analytics, governance and security |
| `best-practices.md` | Data modeling patterns, set analysis recipes, app design guidelines, performance optimization strategies, governance practices, deployment recommendations |
| `diagnostics.md` | Troubleshooting slow apps, memory issues, reload failures, engine performance, connectivity problems; monitoring checklists and resolution steps |
| `research-summary.md` | This file -- executive overview and research index |
