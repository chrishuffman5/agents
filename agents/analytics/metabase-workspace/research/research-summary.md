# Metabase Research Summary

## Research Date
April 9, 2026

## Platform Overview
Metabase is an open-source business intelligence and embedded analytics platform built in Clojure/Java. It enables organizations to explore data, build dashboards, and embed analytics into their products. The platform spans from free open-source self-hosted deployments to managed cloud Enterprise plans with full multi-tenant embedded analytics.

## Key Findings

### Architecture
- **Confidence: High** - Well-documented, stable architecture
- Java/Clojure application deployed as JAR or Docker container
- Application database (H2 for dev, PostgreSQL recommended for production) stores all configuration
- Connects to 18+ officially supported data sources including PostgreSQL, MySQL, BigQuery, Snowflake, Redshift, MongoDB, Databricks, and more
- REST API with API key or session token authentication for full programmatic access
- Three question types: graphical query builder, advanced custom questions, native SQL

### Current Version (v59, March 2026)
- **Confidence: High** - Sourced from official release notes
- Major release introducing Data Studio, an analyst workbench for semantic layer management
- Transforms (SQL/Python) are replacing model persistence for data preparation
- AI SQL generation (Metabot) now available in open source with bring-your-own Anthropic key
- Box plots, conditional number formatting, and Agent API added
- v60 is currently in beta (April 2026) with series panel splitting as the headline feature

### Embedding
- **Confidence: High** - Comprehensive documentation reviewed
- Three embedding approaches: Static/Guest Embeds (free), Full-App Embedding (Pro/Enterprise), Modular Embedding SDK (Pro/Enterprise)
- Guest Embeds (v58) replace static embedding with improved theming
- React SDK requires exact version matching with Metabase instance
- Full-app embedding supports JWT SSO (recommended), SAML, and LDAP
- Multi-tenant embedding supported via Tenants feature (v58) and data sandboxing

### Permissions
- **Confidence: High** - Detailed permission model documented
- Group-based, additive permission system (most permissive group wins)
- Five data access levels: Can view, Granular, Sandboxed (row/column), Impersonated, Blocked
- Row and column security (formerly "data sandboxing") requires Pro/Enterprise
- Native SQL access automatically disabled for sandboxed databases
- Collection permissions separate from data permissions
- "All Users" group is the baseline; must be restricted before granular permissions work

### Pricing and Plans
- **Confidence: High** - Sourced from official pricing page
- Open Source: Free, self-hosted only, basic permissions, branded embedding
- Starter: $100/mo + $6/user, cloud-hosted, basic support
- Pro: $575/mo + $12/user, full features, row-level security, SSO, SDK
- Enterprise: $20k+/year custom, priority support, dedicated engineer, air-gapping
- Add-ons: Metabot AI ($100/mo), Advanced Transforms ($250/mo), Storage ($40/mo per 500k rows)

### Performance and Caching
- **Confidence: High** - Well-documented caching system
- Four cache policies: Duration, Schedule, Adaptive (time-based multiplier), None
- Hierarchy: Question > Dashboard > Database > Site-wide
- Automatic cache refresh available on Pro/Enterprise
- Dashboard performance optimized at 20-25 cards; use tabs for more
- Model persistence stores results in data warehouse (being replaced by Transforms)

## Research Gaps

### Areas with Limited Information
1. **v60 Features**: Only beta information available; full feature list not yet published. Headline feature is series panel splitting. Full release notes expected upon stable release.
2. **Agent API Details**: Introduced in v59 for programmatic semantic layer access, but detailed API documentation not yet widely available.
3. **Transforms Deep Dive**: New in v59 as the replacement for model persistence; limited real-world deployment experience documented.
4. **Community Drivers**: The full list of community-maintained database drivers was not enumerated in research; only the 18 official drivers were documented.
5. **Advanced Metabot Capabilities**: AI features are actively evolving; capabilities may change between minor releases.
6. **Cluster Deployment Details**: Horizontal scaling architecture, load balancer configuration, and session management in clustered deployments not deeply covered.

### Areas Requiring Ongoing Monitoring
- v60 stable release (expected Q2 2026)
- Transforms feature maturation and model persistence deprecation timeline
- Metabot AI evolution and additional LLM provider support
- Modular Embedding SDK component expansion
- Pricing changes (add-on model is relatively new)

## Source Quality Assessment

| Source Type | Quality | Notes |
|-------------|---------|-------|
| Official Metabase Docs | High | Primary source, well-maintained, current |
| Metabase Release Notes | High | Authoritative for version-specific features |
| Metabase Learn Articles | High | Best practices and tutorials from Metabase team |
| Metabase Blog | High | Strategic direction and feature announcements |
| Metabase Pricing Page | High | Authoritative for plan comparison |
| Metabase Discussion Forum | Medium | Community experiences, may contain outdated info |
| Third-party Reviews | Medium | Useful for perspective but may lag behind releases |
| GitHub Issues | Medium | Useful for known bugs, may be noisy |

## Files Produced

| File | Content | Lines |
|------|---------|-------|
| `architecture.md` | Application server, databases, questions, models, dashboards, embedding, permissions, caching, API | Comprehensive |
| `features.md` | v57-v60 features, plan comparison, Cloud vs self-hosted, feature trajectory | Comprehensive |
| `best-practices.md` | Question/model/dashboard design, embedding patterns, permissions, performance | Comprehensive |
| `diagnostics.md` | Diagnostic tools, common issues, troubleshooting, upgrade procedures, performance diagnostics | Comprehensive |
| `research-summary.md` | This file - findings, confidence levels, gaps, sources | Summary |

## Key Sources

- [Metabase Official Documentation](https://www.metabase.com/docs/latest/)
- [Metabase Releases](https://www.metabase.com/releases)
- [Metabase v59 Release Notes](https://www.metabase.com/releases/metabase-59)
- [Metabase v58 Release Notes](https://www.metabase.com/releases/metabase-58)
- [Metabase v57 Release Notes](https://www.metabase.com/releases/metabase-57)
- [Metabase Pricing](https://www.metabase.com/pricing/)
- [Metabase Learn](https://www.metabase.com/learn/)
- [Metabase Cloud vs Self-Hosting](https://www.metabase.com/docs/latest/cloud/cloud-vs-self-hosting)
- [Metabase API Documentation](https://www.metabase.com/docs/latest/api)
- [Metabase Troubleshooting Guides](https://www.metabase.com/docs/latest/troubleshooting-guide/)
- [Metabase Embedding Documentation](https://www.metabase.com/docs/latest/embedding/sdk/introduction)
- [Metabase Data Permissions](https://www.metabase.com/docs/latest/permissions/data)
- [Metabase Caching Documentation](https://www.metabase.com/docs/latest/configuring-metabase/caching)
- [Metabase Data Studio](https://www.metabase.com/product/data-studio/)
- [Metabase Changelog](https://www.metabase.com/changelog)
- [Pursuit Technology - Metabase April '26 Update](https://www.pursuittechnology.co.uk/metabase-april-26-update/)
