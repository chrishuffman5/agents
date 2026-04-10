# Looker Features

## Current Platform Capabilities

### Data Exploration

- **Explores**: Interactive query builder allowing business users to select dimensions, measures, filters, and pivots without writing SQL
- **Custom Fields**: Ad-hoc calculations created by end users within Explores
- **Drill-down**: Click-through from aggregated metrics to underlying detail rows
- **Merged Results**: Combine results from multiple Explores into a single view
- **Cross-filtering**: Dashboard tiles that filter each other interactively

### Visualization

- **Chart Types**: Bar, line, area, scatter, pie, funnel, map, table, single value, waterfall, and more
- **Custom Visualizations**: Marketplace-hosted or developer-built visualizations
- **Conditional Formatting**: Color rules and thresholds on table cells
- **Dashboard Layouts**: Grid-based dashboard design with responsive tile sizing
- **Dashboard Filters**: Global filters applied across all tiles in a dashboard
- **Dashboard-Only Fields**: Fields that exist only in dashboard filter context

### Data Delivery and Alerting

- **Scheduled Deliveries**: Send Looks, dashboards, and queries via email, Slack, S3, SFTP, webhooks
- **Conditional Alerts**: Threshold-based alerts on specific metrics
- **Datagroup-triggered Delivery**: Deliveries fired when ETL completes (datagroup triggers)
- **Content Delivery Formats**: PDF, PNG, CSV, Excel, and inline visualizations

### Administration

- **System Activity Dashboards**: Monitor instance health, query performance, user activity, and content usage
- **Usage Tracking**: Built-in i__looker and System Activity Explores for self-service admin analytics
- **Content Validation**: Detect broken content (dashboards, Looks) referencing deleted or changed fields
- **Scheduled Plan Admin**: Manage and audit all scheduled deliveries across the instance

---

## LookML Refinements

Refinements allow modification of existing views and explores without editing original files, using the `+` prefix syntax:

```lookml
view: +orders {
  dimension: priority_label {
    type: string
    sql: CASE WHEN ${priority} > 5 THEN 'High' ELSE 'Standard' END ;;
  }
}
```

### Key Behaviors

- **Override by default**: Most parameters replace the original value
- **Additive parameters**: Some parameters combine with originals (joins, links, actions, access_filters, aggregate_tables, allowed_values)
- **Order matters**: Applied in file include order; later refinements override earlier ones
- **Final keyword**: Use `final: yes` to prevent further refinements and catch conflicts at validation time

### Use Cases

- Customizing Looker Blocks (pre-built LookML packages) without forking
- Adapting imported LookML from other projects
- Layered model organization (raw layer, business logic layer, presentation layer)
- Hub-and-spoke configurations where a central project is refined per department

### Refinements vs. Extends

| Aspect | Refinements | Extends |
|--------|-------------|---------|
| Creates new object | No (modifies in place) | Yes (new copy) |
| Requires new name | No (uses `+existing_name`) | Yes |
| Best for | Read-only sources, layering | Multiple variants of a base |
| Syntax | `view: +name { }` | `extends: [base_name]` |

---

## Universal Semantic Layer

Looker's semantic layer has expanded beyond the Looker UI to become a universal access point for business logic:

### Open SQL Interface

- Exposes LookML Explores as virtual database tables via JDBC
- Any JDBC-compatible tool can query the semantic layer directly
- Based on BigQuery, with automatic SQL translation
- Supported by tools including Tableau, Python, R, and custom applications

### BI Connectors

- **Tableau Connector**: GA custom-built connector for querying LookML models from Tableau
- **Power BI Connector**: Direct connectivity from Power BI to Looker semantic layer
- **Google Sheets Connector**: Native integration for spreadsheet-based analysis
- **Looker Studio Connector**: Connect Looker Studio reports to LookML models

### Conversational Analytics API

- Enables partner tools and custom applications to leverage Looker's semantic layer for natural language querying
- Grounded in LookML definitions to reduce hallucination and ensure metric consistency
- Powered by Gemini with retrieval-augmented generation

### Benefits of Universal Access

- Single source of truth regardless of consumption tool
- Consistent metric definitions across the organization
- Governance and access controls applied universally
- Reduces data silos and metric fragmentation

---

## Looker Extensions

### Extension Framework

Custom JavaScript/TypeScript applications that run within the Looker platform:

- **Authentication**: Leverages Looker's existing auth (password, LDAP, SAML, OpenID Connect)
- **API Access**: Full Looker API available through the Extension SDK
- **UI Components**: Pre-built React component library (Looker Components) for consistent UX
- **Embed SDK**: Embed dashboards, Looks, and Explores within extensions
- **Dashboard Tiles**: Extensions can run as tiles within dashboards (Looker 24.0+)
- **Spartan Mode**: Full-screen mode hiding Looker chrome for immersive embedded experiences

### Development Tools

- `create-looker-extension` CLI tool generates starter projects
- Kitchen Sink template demonstrates framework capabilities
- TypeScript and React recommended (raw JavaScript SDK also available)
- Extensions require a LookML project with a manifest file defining entitlements

### Entitlements and Security

Extensions declare required permissions in the manifest file:

- Local storage access
- Navigation permissions
- External API endpoints
- Core SDK API methods
- User attribute access
- New window/tab creation

### Marketplace

The Looker Marketplace provides a distribution channel for extensions:

- **Looker Blocks**: Pre-built LookML data models for common data sources (Salesforce, Google Analytics, etc.)
- **Applications**: Custom tools like Data Dictionary and LookML Diagram
- **Custom Visualizations**: Shareable visualization types
- **Actions**: Integrations with external services (Slack, email, webhooks)
- Developers host code on public Git repositories and submit for review

---

## Looker Studio Pro

### Overview

Looker Studio Pro is the paid tier of Looker Studio (formerly Google Data Studio), offering team management features on top of the free version.

### Pro Features

- **Team Workspaces**: Organize reports and data sources into team-managed spaces
- **Linked Looker Models**: Connect Looker Studio reports directly to LookML semantic layer
- **Google Cloud IAM Integration**: Enterprise identity and access management
- **Enhanced Support**: Google Cloud support channels
- **Audit Logging**: Cloud Audit Logs for compliance and monitoring
- **Data Freshness Controls**: Scheduled data refresh and caching policies

### Licensing

- Each Looker user license includes one complimentary Looker Studio Pro license
- Can also be purchased independently through Google Cloud

### Unification with Looker (2025-2026)

Google is merging Looker and Looker Studio capabilities:

- **Looker Studio in Looker**: Allows creating Looker Studio reports within the Looker interface (Preview)
- **Shared Governance**: Looker Studio Pro reports can inherit LookML governance
- **Unified Navigation**: Single pane of glass for both Looker and Looker Studio content

---

## AI and Gemini Features (2025-2026)

### Conversational Analytics

- Natural language querying of data via Gemini
- Multi-turn conversations for iterative analysis ("add a filter for enterprise customers", "show as a bar chart")
- Grounded in LookML semantic layer for accuracy (reduces data errors by up to two-thirds)
- Supports up to 5,000 rows per query with multiple chart types
- "Show reasoning" and "How was this calculated?" transparency features
- Insights button for automatic pattern detection
- Requires Looker version 25.0+

### LookML Assistant ("Help Me Code")

- Generates LookML code from natural language descriptions
- Available since April 2025 (Looker version 25.2+)
- Examples: "Create a dimension group for order dates with month and quarter"
- Speeds up development for both new and experienced LookML developers

### Visualization Assistant

- Natural language customization of charts
- Eliminates manual JSON configuration for visualization properties
- Requires Looker version 25.2+

### Formula Assistant

- Automated generation of calculated field syntax
- Natural language to Looker formula translation

### Code Interpreter (Experimental)

- Translates natural language into executable Python code
- Advanced analytics: forecasting, anomaly detection, statistical analysis
- Supports scikit-learn, statsmodels, tensorflow, torch libraries

### Architecture

The AI system combines four components for accuracy:

1. **Reasoning Agent**: Determines optimal query paths for complex questions
2. **Semantic Layer**: Grounds AI responses in governed data definitions
3. **Knowledge Graph**: Enhanced accuracy through retrieval-augmented generation
4. **Fine-tuned Models**: Generate precise SQL and Python code

### Requirements

- Looker-hosted instances only (customer-hosted deployments unsupported)
- Vertex AI API activation in linked Google Cloud project
- Required IAM permissions: `gemini_in_looker`, `access_data`
- Customer data remains within Looker instances; not used to train Google AI models

---

## Data Governance Features

### Row-Level Security

- **Access Filters**: LookML-defined filters that inject WHERE clauses based on user attributes
- **User Attributes**: Dynamic per-user variables (region, department, customer ID) driving security rules
- Automatic SQL injection of security filters on every query

### Field-Level Security

- **Access Grants**: Control which fields are visible to specific users/groups
- **Field-level permissions**: Hide sensitive dimensions/measures from unauthorized users

### Content Access

- **Folder Permissions**: Manage access to dashboards and Looks via folder hierarchy
- **Model Sets**: Control which LookML models are accessible to each user role
- **Permission Sets**: Granular permissions (view, explore, download, schedule, admin, etc.)

### Data Freshness and Lineage

- **Content Validator**: Detect broken content referencing changed/deleted fields
- **Explore Queries**: Track field usage and data lineage through system activity
- **LookML Validation**: Automated checks on model changes before deployment

Sources:
- [LookML refinements](https://docs.cloud.google.com/looker/docs/lookml-refinements)
- [Reusing code with extends](https://docs.cloud.google.com/looker/docs/reusing-code-with-extends)
- [Looker Extension Framework](https://docs.cloud.google.com/looker/docs/intro-to-extension-framework)
- [Looker Marketplace](https://cloud.google.com/looker/docs/marketplace)
- [Open SQL Interface](https://docs.cloud.google.com/looker/docs/sql-interface)
- [Looker AI features 2025-2026](https://querio.ai/articles/looker-ai-features-natural-language-query-gemini-2025-2026)
- [Looker vs Looker Studio 2026](https://improvado.io/blog/looker-vs-looker-studio-comparison)
- [Looker business intelligence platform](https://cloud.google.com/looker)
- [Row-Level Security in Looker](https://medium.com/@likkilaxminarayana/34-row-level-security-access-filters-user-attributes-in-looker-91992d40f7d6)
