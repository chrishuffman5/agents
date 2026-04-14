# ThoughtSpot Best Practices

## Model Design

### Model Architecture

- **Use Models as the primary semantic layer**: connect Answers and Liveboards only to Models, not directly to Tables or Views. Models provide governed dimensions, measures, business logic, and a single reference point for maintenance.
- **One Model per Liveboard**: use a single Model for all visualizations on a Liveboard to ensure consistent joins and avoid cross-model conflicts.
- **Meaningful naming conventions**: use business-friendly names for columns, measures, and dimensions that align with how users naturally search (e.g., "Total Revenue" not "sum_amt_01").
- **Column descriptions**: add descriptions to every column to improve search relevance and help users understand available data.
- **Synonyms**: define synonyms for columns to accommodate different terminology across business units (e.g., "revenue" = "sales" = "income").

### Dimension and Measure Design

- **Explicit measure/attribute typing**: correctly classify columns as measures (aggregatable) or attributes (groupable/filterable). Misclassification degrades search quality.
- **Date hierarchies**: ensure date columns use correct date types for automatic time-based analysis (daily, weekly, monthly, quarterly, yearly).
- **Derived columns**: create calculated columns in the Model for commonly used business logic rather than expecting users to create formulas in search.
- **Currency and number formatting**: apply appropriate formatting at the Model level for consistent display across all Answers and Liveboards.

### Join Design

- **Minimize join complexity**: keep join paths simple and avoid circular joins.
- **Use appropriate join types**: choose inner, left, right, or full outer joins based on data relationships.
- **Define cardinality**: explicitly set one-to-one, one-to-many, or many-to-many relationships.
- **Test join performance**: validate that join paths produce correct results and acceptable query times against the target warehouse.
- **Pre-join in warehouse**: for complex multi-table joins that cause slow queries, consider pre-joining in the warehouse as materialized views.

### Spotter Optimization

- **Enable Spotter optimization**: use the Spotter optimization tab when editing Models/Worksheets.
- **Index key columns**: enable indexing on frequently searched columns for faster auto-suggestions (product names, regions, categories).
- **Validate date formats**: ensure date values are stored in the correct format for temporal analysis.
- **Optimize column types**: review and correct column type classifications (measure vs. attribute) to improve search accuracy.
- **Avoid over-indexing**: do not index high-cardinality columns (transaction IDs, raw timestamps) -- wastes memory without improving search.

## Search Optimization

### Improving Search Quality

- **Index strategically**: index columns that users frequently search by, but avoid over-indexing large cardinality columns.
- **Create search-friendly column names**: use plain language names that match how users think about data.
- **Define formulas at the Model level**: pre-build commonly needed calculations (year-over-year growth, running totals, percentages).
- **Use analytical keywords**: educate users on ThoughtSpot's keyword vocabulary ("top 10", "growth of", "daily", "vs last year").

### Performance Optimization

- **Limit result set size**: use filters and top/bottom constraints to reduce returned data volumes.
- **Optimize warehouse queries**: ensure underlying data warehouse tables have appropriate indexes, partitions, and clustering.
- **Monitor query performance**: use the Performance Tracking Liveboard and AI/BI Stats data model to identify slow queries.
- **Use SpotCache for repeated queries**: cache frequently accessed datasets to reduce warehouse compute costs and improve response times.

### User Adoption

- **Create sample searches**: provide example search queries for each Model to help users get started.
- **Pin commonly used answers**: save and share frequently used answers as starting points.
- **Train users on search syntax**: teach analytical keywords and filter syntax through guided onboarding.
- **Leverage Spotter**: encourage conversational analytics for complex multi-step analyses.

## Embedding Patterns (ThoughtSpot Everywhere)

### Authentication Strategy

- **Use Trusted Authentication for production**: provides the most seamless SSO experience for embedded deployments.
- **Implement cookieless authentication**: preferred for modern applications to avoid third-party cookie restrictions from browsers.
- **Use SAML/OIDC SSO with popup mode**: set `inPopup: true` to avoid full-page redirects in embedded contexts.
- **Token management**: implement token refresh logic to maintain sessions without user interruption.

### Embedding Architecture

- **Choose the right embed component**: match the component to the use case:
  - `SearchEmbed` for exploration
  - `LiveboardEmbed` for curated views
  - `SpotterEmbed` for AI-driven analysis
  - `SearchBarEmbed` for search-only integration
  - `AppEmbed` for full application embedding
- **Use prefetch for performance**: call the SDK's `prefetch` method before `init` to cache static assets early.
- **Implement event handlers**: listen for ThoughtSpot events (data changes, drill-downs, custom action triggers) to integrate with host application workflows.
- **Apply CSS customization**: use `customCssUrl` or inline styles to match the embedded content with the host application's design system.

### Multi-Tenancy with Orgs

- **Create an Org per tenant**: isolate content, users, and data access for each customer/tenant.
- **Use Org-level administration**: manage users, groups, and content within each Org independently.
- **Automate Org provisioning**: use REST API v2.0 to programmatically create Orgs, users, and assign content.
- **Consistent Models across Orgs**: deploy standardized TML packages across Orgs for consistent analytics experiences.

### Custom Actions

- **Callback actions for workflows**: trigger host application workflows when users interact with data (e.g., create a support ticket from an anomaly insight).
- **URL actions for integrations**: pass ThoughtSpot data to external systems via parameterized URLs.
- **Context-aware actions**: configure actions to appear only on specific visualizations or data types.
- **Test in Playground first**: use the Developer Portal Playground to validate custom action configurations before deploying.

### Security in Embedded Contexts

- **Apply RLS consistently**: ensure row-level security rules are applied on Models used in embedded contexts.
- **Map host app users to ThoughtSpot users**: synchronize user identity between the host application and ThoughtSpot.
- **Limit exposed functionality**: use SDK parameters to control which features are available (hide menus, disable downloads, restrict sharing).
- **Audit embedded usage**: monitor API calls and user activity in embedded deployments.

## TML Management

### Version Control

- **Store TML in Git**: export all ThoughtSpot objects as TML and maintain in a version control repository.
- **Branch-based development**: use Git branches for developing new analytics content, then merge to deploy.
- **Code review TML changes**: review TML modifications before importing to catch breaking changes.
- **Tag releases**: use Git tags to mark stable TML configurations for rollback capability.

### CI/CD Pipeline

- **Automate TML deployment**: use REST API TML import/export endpoints in CI/CD pipelines.
- **Environment promotion**: maintain separate ThoughtSpot environments (dev, staging, production) and promote TML through the pipeline.
- **Validate before import**: use the TML validation API to check for errors before importing.
- **Handle FQN references**: always include `fqn` parameters in TML to avoid ambiguous object references. Import fails without FQN when multiple connections or tables share names.

### Package Management

- **Deploy related objects together**: create and upload packages of related TML objects (Model + dependent Answers + Liveboards) as a unit.
- **Use unique names within packages**: even though ThoughtSpot does not enforce uniqueness, unique names prevent import ambiguity.
- **Document dependencies**: maintain documentation of which objects depend on which Models and Tables.
- **Use the Python TML library**: leverage `thoughtspot-tml` (PyPI) for programmatic TML manipulation, transformation, and validation.

### Migration and Refactoring

- **Convert Worksheets to Models**: follow ThoughtSpot's migration guide for transitioning from Worksheets to Models.
- **Update dependent objects**: when renaming columns or tables in TML, ThoughtSpot automatically updates dependents on import.
- **Test thoroughly after changes**: verify that renaming or restructuring TML does not break dependent Answers or Liveboards.
- **Maintain backward compatibility**: when making breaking changes, communicate with content consumers and coordinate migration.

## Security and Governance

### Row-Level Security (RLS)

- **Start restrictive, expand as needed**: begin with minimal access and broaden permissions over time.
- **Keep rules simple**: complex RLS rules can impact system performance.
- **Use Access Control Lists (ACLs)**: for complex RLS, use an ACL table mapping users/groups to data value combinations.
- **Separate RLS groups from sharing groups**: create dedicated groups for RLS that do not appear in the Share dialog (mark as NOT SHAREABLE).
- **Audit regularly**: periodically review user roles, group memberships, and RLS rules.

### Column-Level Security (CLS)

- Control visibility of specific columns per user/group.
- Apply CLS at the Model level for consistent enforcement.
- Use for sensitive fields (PII, salary, SSN) that should be hidden from certain user groups.

### Sharing and Access Control

- **Share as first-level access control**: non-admin users cannot access any data without explicit sharing.
- **Use groups for scalable sharing**: organize users into groups aligned with business roles and data access needs.
- **Minimize admin accounts**: restrict admin privileges to necessary personnel only.
- **Document sharing policies**: maintain governance documentation on what content is shared with which groups.

### SpotCache Security

- **Apply security controls manually**: SpotCache does not inherit security controls from the source warehouse.
- **Configure RLS and CLS on cached data**: set up row-level and column-level security on SpotCache datasets.
- **Maintain audit trails**: monitor and log access to cached data.
- **Review cached datasets periodically**: ensure cached data remains current and security policies are up to date.

### Data Warehouse Security

- **Use service accounts with least privilege**: connect to warehouses with accounts that have only necessary permissions.
- **Enable OAuth where possible**: use OAuth instead of static credentials for warehouse connections.
- **Configure PrivateLink**: use AWS PrivateLink for Snowflake, Databricks, and other supported connections.
- **Rotate credentials**: regularly update service account credentials and OAuth tokens.

## Performance Best Practices

### Data Warehouse Optimization

- **Optimize table structures**: ensure warehouse tables have appropriate clustering, partitioning, and indexing.
- **Materialize complex views**: pre-compute expensive transformations in the warehouse rather than at query time.
- **Monitor warehouse costs**: use ThoughtSpot's query performance metrics to identify expensive queries and optimize or cache them.
- **Right-size warehouse compute**: adjust compute resources based on ThoughtSpot query patterns.

### ThoughtSpot Configuration

- **Use SpotCache strategically**: cache high-frequency, high-cost datasets while keeping real-time data on live connections.
- **Optimize Models for query patterns**: structure Models to align with common query paths for efficient SQL generation.
- **Limit Liveboard complexity**: keep Liveboards focused with a manageable number of visualizations to avoid slow load times.
- **Schedule data refreshes appropriately**: balance data freshness with warehouse cost.

### Monitoring and Diagnostics

- **Use System Liveboards**: monitor cluster health, query performance, and user activity through built-in dashboards.
- **Create custom monitoring Answers**: leverage the AI/BI Stats data model for tailored performance monitoring.
- **Set up Monitor alerts**: configure threshold and anomaly alerts on key performance metrics.
- **Review Performance Tracking Liveboard**: regularly check cluster performance metrics and query execution times.

## Liveboard Design

### Layout and Structure

- Keep Liveboards focused on a single analytical theme or business question.
- Place the most important KPIs and metrics at the top.
- Use cross-filtering to create interactive exploration without overwhelming the user with controls.
- Limit the number of visualizations to maintain fast load times.
- Use scheduling to distribute Liveboard snapshots (PDF/CSV) via email for stakeholders who do not log in.

### Visualization Selection

- Let ThoughtSpot auto-select chart types when possible -- the engine optimizes for the data being displayed.
- Override chart type selection only when the auto-selected type does not match the analytical intent.
- Use KPI cards for headline metrics with trend context.
- Use tables for detailed data review and export scenarios.
