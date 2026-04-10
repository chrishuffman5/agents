# Tableau Version Features

## Tableau 2026.1 (Current Release - March 2026)

### Design & Visualization
- **Rounded corners**: New design control for dashboard objects
- **AI-assisted color palettes**: Generate accessible color themes from text prompts
- **Mixed geometry maps**: Points, lines, and polygons coexist in a single map view
- **Improved export service**: Export images for Trusted Extensions and Pulse on Dashboards; images match what users see in Tableau

### Data Connectivity
- **REST API Connector**: New general-purpose connector (replaces deprecated WDC)
- **Google Looker Connector**: New connector for Looker data
- **Refreshed Amazon S3 Connector**: Updated with improved functionality
- **Custom OAuth for OneDrive/SharePoint Online**: Includes Government Cloud support
- **OAuth for Cloudera Impala**: New authentication option
- **Starburst Connector**: Generally available across Desktop, Server, and Prep

### AI & Analytics
- **Auto-Generate Semantic Models from Workspaces**: AI-driven semantic model creation
- **Q&A Calibration**: Fine-tune natural language query responses
- **Enhanced Q&A Updates**: Improved natural language query capabilities
- **Pulse on Dashboards**: Embed Pulse AI insights within traditional dashboards

### Data Modeling
- **Clearer view data model layouts**: Improved visual representation of data models
- **Smart filtering on table names**: Faster navigation in complex data environments

### Security & Administration
- **SCIM with OIDC**: SCIM user provisioning extended beyond SAML to OpenID Connect
- **IP Filtering Self-Service**: Administrators define approved IP addresses/ranges for data access
- **Unified Access Tokens (UATs)**: Continued improvements from 2025.3

### Deprecated Features (2026.1)
- **Marketo Connector**: Deprecated; JDBC-based replacement on Tableau Exchange
- **Oracle Eloqua Connector**: Deprecated; JDBC-based replacement on Tableau Exchange
- **Web Data Connector (WDC)**: Deprecated; replaced by REST API Connector

---

## Tableau 2025.x Features

### 2025.1
- Continued Tableau Einstein integration
- Tableau Pulse enhancements
- Prep Builder improvements

### 2025.2
- SCIM token support via Connected Apps (June 2025)
- REST API authorization for VizQL Data Service via Connected Apps (February 2025)
- Extended platform improvements

### 2025.3
- **Unified Access Tokens (UATs)**: New JWT-based authentication via Tableau Cloud Manager
- Enhanced embedding authentication options
- VizQL Data Service improvements

### Cross-Version 2025 Themes
- **Tableau Einstein**: AI-powered analytics platform combining Tableau with Salesforce Einstein
  - Natural language interaction via Tableau Agent
  - Tableau Pulse for proactive metric delivery
  - Tableau Semantics for consistent metric definitions (GA February 2025)
  - Pre-built metrics for Salesforce data
- **VizQL Data Service**: Programmatic API access to published data sources
- **Table Viz Extensions**: Custom UI components within Tableau views
- **Enhanced Q&A**: Premium natural language query (Tableau+ exclusive)
- **Multi-language Pulse**: Insights in all Tableau-supported languages

---

## Salesforce Integration (Post-Acquisition)

### Tableau Einstein
- Announced at Dreamforce 2024 as the unified AI analytics platform
- Combines Tableau's visualization with Salesforce Einstein's AI capabilities
- Out-of-the-box metrics for Salesforce objects
- Predictive AI and agents suggesting actionable steps

### Data Cloud Integration
- Real-time data integration through Salesforce Data Cloud
- Securely access structured and unstructured data from hundreds of sources
- No manual data movement required
- Direct connections to Salesforce objects in real-time

### Tableau Semantics
- Semantic layer aligning Tableau metrics with Salesforce data definitions
- Pre-built metrics for common Salesforce CRM data (pipeline, revenue, cases)
- AI-driven management tools for the semantic layer

### Marketplace
- Launched mid-2025 for composable infrastructure
- APIs for personalizing Tableau environments
- Share AI assets across departments
- Collaborative ecosystem for extensions and accelerators

### Embedded in Salesforce Clouds
- Tableau visualizations embedded directly in Sales Cloud, Service Cloud, etc.
- Pulse metrics surfaced within Salesforce workflows
- Unified analytics experience across Salesforce platform

---

## Version Lifecycle and Support Policy

### Support Tiers (Since 2021.4)
1. **Full Maintenance & Technical Support**: 24 months from release date
   - Bug fixes and maintenance releases
   - Full technical support
   - Security patches
2. **Limited Support**: 12 months after full support ends (36 months total from release)
   - Documentation clarification
   - Upgrade assistance
   - No new maintenance releases
3. **End of Life**: After 36 months total
   - No support available
   - Upgrade required

### Version Support Timeline Examples
| Version | Release | Full Support Ends | Limited Support Ends |
|---------|---------|-------------------|----------------------|
| 2024.1 | ~Feb 2024 | ~Feb 2026 | ~Feb 2027 |
| 2024.2 | ~May 2024 | ~May 2026 | ~May 2027 |
| 2025.1 | ~Feb 2025 | ~Feb 2027 | ~Feb 2028 |
| 2025.2 | ~May 2025 | ~Nov 2025* | ~Nov 2026* |
| 2026.1 | ~Mar 2026 | ~Mar 2028 | ~Mar 2029 |

*Note: Support dates for 2025.2 per official Tableau KB article.

### Upgrade Recommendations
- Maintain at least one version behind current for stability
- Upgrade at least every 24 months to stay within full support
- Test upgrades in non-production environments first
- Review breaking changes and deprecated features before upgrading

---

## Breaking Changes Between Versions

### 2026.1 Breaking Changes
- Marketo, Oracle Eloqua, and WDC connectors removed (deprecated in prior version, removed in 2026.1)
- Must migrate to JDBC-based connectors (Exchange) or REST API Connector

### Common Upgrade Considerations
- **Connector deprecations**: Check Tableau Exchange for replacement connectors
- **Authentication changes**: Connected Apps replacing legacy trusted authentication
- **API version changes**: REST API and Embedding API versions may change
- **Extract format**: .hyper format required (legacy .tde format long since deprecated)
- **Browser support**: Minimum browser versions may change between releases
- **Data model**: Relationships model recommended over legacy join-based models
- **Python/R integration**: TabPy and Rserve version compatibility should be verified
