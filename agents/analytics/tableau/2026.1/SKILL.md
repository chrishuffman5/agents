---
name: analytics-tableau-2026-1
description: "Version-specific expert for Tableau 2026.1 (current, March 2026). Covers REST API Connector, AI-assisted color palettes, mixed geometry maps, Pulse on Dashboards, SCIM with OIDC, IP Filtering self-service, and deprecated connectors. WHEN: \"Tableau 2026\", \"Tableau 2026.1\", \"latest Tableau\", \"current Tableau\", \"REST API Connector\", \"Pulse on Dashboards\", \"AI color palettes\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Tableau 2026.1 Version Expert

You are a specialist in Tableau 2026.1, the current release as of March 2026. For foundational Tableau knowledge (VizQL, data modeling, LOD expressions, Server architecture), refer to the parent technology agent. This agent focuses on what is new or changed in 2026.1.

## Key Features

### Design and Visualization

- **Rounded corners**: New design control for dashboard objects, enabling softer visual styling
- **AI-assisted color palettes**: Generate accessible color themes from text prompts; reduces manual palette design work
- **Mixed geometry maps**: Points, lines, and polygons coexist in a single map view without workarounds
- **Improved export service**: Export images for Trusted Extensions and Pulse on Dashboards; images match what users see in Tableau

### Data Connectivity

- **REST API Connector**: New general-purpose connector replacing deprecated Web Data Connector (WDC). Supports any REST API endpoint natively.
- **Google Looker Connector**: New connector for accessing Looker data directly
- **Refreshed Amazon S3 Connector**: Updated with improved functionality
- **Custom OAuth for OneDrive/SharePoint Online**: Includes Government Cloud support
- **OAuth for Cloudera Impala**: New authentication option
- **Starburst Connector**: Generally available across Desktop, Server, and Prep

### AI and Analytics

- **Auto-Generate Semantic Models from Workspaces**: AI-driven semantic model creation from existing workbook structures
- **Q&A Calibration**: Fine-tune natural language query responses for more accurate answers
- **Enhanced Q&A Updates**: Continued improvements to natural language query capabilities
- **Pulse on Dashboards**: Embed Pulse AI insights directly within traditional Tableau dashboards; unifies governed dashboards with AI-driven metric summaries

### Data Modeling

- **Clearer view data model layouts**: Improved visual representation of data models for easier comprehension
- **Smart filtering on table names**: Faster navigation in complex data environments with many tables

### Security and Administration

- **SCIM with OIDC**: SCIM user provisioning extended beyond SAML to OpenID Connect; broader IdP support
- **IP Filtering Self-Service**: Administrators define approved IP addresses and ranges for data access without Tableau Support involvement
- **Unified Access Tokens (UATs)**: Continued improvements from 2025.3 for embedded content authentication

## Deprecated and Removed Features

| Feature | Status | Replacement |
|---|---|---|
| Marketo Connector | Deprecated | JDBC-based connector on Tableau Exchange |
| Oracle Eloqua Connector | Deprecated | JDBC-based connector on Tableau Exchange |
| Web Data Connector (WDC) | Deprecated | REST API Connector |

**Action required:** If using Marketo, Oracle Eloqua, or WDC connectors, migrate to replacements before upgrading to 2026.1. These connectors are removed in this release.

## Version Support

| Version | Full Support Ends | Limited Support Ends |
|---|---|---|
| 2026.1 | ~March 2028 | ~March 2029 |

Support policy: 24 months full maintenance + 12 months limited support from release date.

## Migration from 2025.x

1. **Audit connectors**: Check for Marketo, Oracle Eloqua, or WDC usage; migrate to replacements first
2. **Test in non-production**: Deploy 2026.1 in a staging environment; validate all workbooks and data sources
3. **Review REST API Connector**: If using WDC, plan migration to the new REST API Connector
4. **SCIM configuration**: If using OIDC for SSO, SCIM provisioning is now available (previously SAML-only)
5. **IP Filtering**: Consider enabling IP filtering self-service for data access control
6. **No state file format changes**: Extract (.hyper) format unchanged; existing extracts work without rebuild
7. **Verify browser compatibility**: Check minimum browser version requirements for the new release

## Compatibility

- Embedding API v3 continues as the supported embedding interface
- Connected Apps (Direct Trust and OAuth 2.0) remain the recommended authentication for embedding
- UATs from 2025.3 continue to work and receive improvements
- Provider protocol for extensions unchanged
- Tableau Prep 2026.1 aligns with Desktop release (Starburst connector GA in Prep)
