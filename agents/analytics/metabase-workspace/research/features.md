# Metabase Features

## Version History (Recent)

### Metabase v60 (Beta - April 2026)

**Visualization Enhancements:**
- **Separate Panels**: Split multiple series into separate panels within the same visualization, eliminating confusing dual-axis charts and ensuring consistent x-axis ranges across compared series
- **Box Plots**: Box and whisker charts for comparing value distributions across categories (carried from v59)

**Status**: Currently in beta testing. Full feature list expected upon stable release.

### Metabase v59 (March 5, 2026)

**Data Studio (Major Feature):**
- New analyst workbench for structuring data and building a semantic layer
- **Transforms**: Use SQL or Python to transform raw data into analytics-ready tables with Metabot AI assistance
- **Dependency Graph**: Visual mapping showing entity dependencies before making upstream changes
- **Library**: Curated source of truth where analysts publish formatted tables and metrics
- **Data Structure**: Upgraded metadata editor for managing table visibility, naming, ownership, segments, and measures
- **Diagnostics**: Identifies broken dependencies and unreferenced entities for cleanup

**AI and Query Capabilities:**
- AI SQL generation now available in open-source (bring your own Anthropic API key)
- Single-prompt natural language to SQL conversion in the SQL editor
- Metabot AI assistance for transform code generation

**New Visualizations:**
- Box and whisker charts (boxplots) for value distribution comparison
- Customizable whiskers, points, mean values, and goal lines
- Conditional color formatting for number charts based on thresholds

**Semantic Layer Improvements:**
- Reusable segments (predefined filters) and measures (aggregations)
- Agent API for programmatic semantic layer access
- Writable database connections for Transforms

**Embedding Updates:**
- JWT SSO tenant provisioning
- Modular embedding content localization
- SQL editor embedding support
- Alert subscriptions for embedded questions
- Dashboard auto-refresh capability in embeds

**Breaking Change:**
- ClickHouse connection settings now require `clickhouse_settings_` prefix

**Deprecation:**
- Model persistence being phased out in favor of Transforms

### Metabase v58 (January 2026)

**Key Features:**
- **Documents for All**: Previously Pro/Enterprise-only, now available in open source
- **Tenants**: Multi-tenant customer analytics with simplified data isolation; group external users so each tenant only sees relevant data without content duplication
- **Guest Embeds**: New successor to static embedding with smoother migration and enhanced theming (Pro/Enterprise)
- **Metabot exits beta**: Available as paid add-on for all Metabase Cloud plans
- **AWS IAM Authentication**: Aurora Postgres and MySQL support IAM auth instead of username/password

**Embedding Changes:**
- Renamed: Embedded Analytics JS -> Modular Embedding
- Renamed: Interactive Embedding -> Full-app Embedding
- Renamed: Embedded Analytics JS SDK -> Modular Embedding SDK
- Dashboard subscriptions in Modular Embedding (Pro/Enterprise)

**Additional:**
- Custom Y-axis range enforcement
- Sydney cloud hosting region
- Performance optimizations reducing render times by ~1 second

### Metabase v57 (November 2025)

**Major Features:**
- **Dark Mode**: System-preference-aware dark mode for content and admin views
- **Remote Sync**: Connect to git repositories for versioning questions, dashboards, and models; push to repos, pull into read-only production instances (Pro/Enterprise)
- **Documents**: Reports combining charts, metrics, and context with Markdown/rich text, collaborative commenting (Pro/Enterprise initially)
- **Parameterizable SQL Snippets**: Variables in snippets, snippet-to-snippet references with circular reference detection
- **Automatic Dependency Checks**: Alerts about breaking downstream changes before saving (Pro/Enterprise)

**AI Improvements:**
- Enhanced Metabot with improved context-awareness and semantic search
- Metabot embeddable in customer-facing apps via SDK

**Embedded Analytics:**
- Customizable click behavior for datapoints (modals, new tabs, custom routing)
- Hosted SDK bundles for automatic version compatibility
- Step-by-step embedding setup guide

**Additional Features:**
- Inline data editing for tables (Postgres, MySQL, H2)
- Dynamic goal-setting in Progress visualizations
- Enhanced Detail View for record exploration
- List views for models with customizable column display
- Organizational glossary for term definitions
- Local currency symbol options
- CSV/XLSX-only subscription options
- Database routing for additional platforms

## Open Source vs Pro vs Enterprise

### Open Source (Free, Self-Hosted Only)

**Included:**
- Query builder and SQL editor
- Unlimited charts, dashboards, and documents (v58+)
- Static embedding (with "Powered by Metabase" badge)
- Basic collection permissions
- Community forum support
- Single-shot AI SQL generation (bring your own Anthropic key, v59+)
- All core visualization types
- REST API access
- H2, PostgreSQL, or MySQL application database

**Not Included:**
- SSO (SAML, LDAP, JWT, SCIM)
- Row and column-level permissions (data sandboxing)
- Audit logs
- White-labeling
- Modular Embedding SDK
- Full-app embedding
- Advanced caching policies (duration, schedule)
- Automatic cache refresh
- Remote sync / version control
- Dependency checks
- Tenants / multi-tenant support
- Metabot AI add-on
- Official support

### Starter ($100/month + $6/user/month)

**Adds to Open Source:**
- Cloud-hosted managed instance
- First 5 users included
- 3-day Slack/Teams/email support
- Metabot AI available as add-on
- Metabase-branded scheduled delivery

### Pro ($575/month + $12/user/month)

**Adds to Starter:**
- Cloud or self-hosted deployment
- First 10 users included
- Row and column-level permissions
- Multi-tenant support (Tenants feature)
- SSO: SAML 2.0, LDAP, JWT, SCIM
- White-labeling (remove Metabase branding)
- Modular Embedding SDK
- Full-app embedding
- Guest Embeds with enhanced theming
- Advanced caching (duration, schedule, adaptive, auto-refresh)
- Remote sync / version control
- Automatic dependency checks
- Dashboard-specific and question-specific caching
- Staging environments
- Audit logs

### Enterprise (Custom pricing, $20k+/year)

**Adds to Pro:**
- Priority support with 1-day SLA
- Dedicated success engineer
- SOC2 Type II compliance
- Air-gapped deployment option
- Single-tenant option
- Procurement assistance
- Advanced LDAP/SAML/JWT/SCIM configuration
- Full multi-tenant isolation for embedding
- Metabot AI included (not add-on)

### Add-on Pricing
- **Metabot AI**: $100/month
- **Advanced Transforms**: $250/month
- **Additional Storage**: $40/month (500k rows)

## Metabase Cloud vs Self-Hosted

### Metabase Cloud

**Advantages:**
- Managed infrastructure (setup, backups, upgrades handled by Metabase)
- Automatic upgrades with each release
- Predictable costs
- SOC 2 Type 2 certification included
- Multi-region hosting: US, Europe, Latin America, Asia-Pacific (Sydney added v58)
- No DevOps overhead
- Same pricing as self-hosted for Pro/Enterprise

**Limitations:**
- Cannot use custom builds or source-level modifications
- Community database drivers not available
- Cannot run in air-gapped environments
- No on-premises deployment

### Self-Hosted

**Advantages:**
- Full control over infrastructure and configuration
- Custom builds and source modifications possible
- Community database drivers supported
- Air-gapped deployment possible
- On-premises deployment
- Open source edition is completely free

**Limitations:**
- Requires DevOps resources for maintenance
- Manual upgrades required
- Infrastructure costs separate from licensing
- Backup management responsibility

### Migration
- Easy migration between Cloud and self-hosted in both directions
- Application database export/import preserves all questions, dashboards, and collections

## Recent Feature Trajectory

The recent release trajectory shows Metabase focusing on several strategic areas:

1. **Semantic Layer / Data Governance**: Data Studio, Transforms, reusable segments/measures, dependency graphs
2. **AI Integration**: Metabot AI for SQL generation, chart summaries, and semantic search (Anthropic-powered)
3. **Embedded Analytics**: SDK improvements, guest embeds, tenant provisioning, localization
4. **Developer Experience**: Remote sync with git, parameterizable snippets, Agent API
5. **Visualization**: Dark mode, box plots, separate panels, conditional formatting
6. **Multi-Tenancy**: Tenants feature for simplified customer data isolation
7. **Collaboration**: Documents, comments, glossary, detail views

## Sources

- [Metabase Releases](https://www.metabase.com/releases)
- [Metabase v59 Release](https://www.metabase.com/releases/metabase-59)
- [Metabase v58 Release](https://www.metabase.com/releases/metabase-58)
- [Metabase v57 Release](https://www.metabase.com/releases/metabase-57)
- [Metabase Pricing](https://www.metabase.com/pricing/)
- [Metabase Cloud vs Self-Hosting](https://www.metabase.com/docs/latest/cloud/cloud-vs-self-hosting)
- [Metabase Changelog](https://www.metabase.com/changelog)
- [Metabase April '26 Update - Pursuit Technology](https://www.pursuittechnology.co.uk/metabase-april-26-update/)
- [Metabase Review 2026](https://valiotti.com/blog/metabase-review/)
