# Looker Best Practices

## LookML Project Structure

### File Organization

Organize LookML files into logical directories by object type:

```
my_project/
  models/
    ecommerce.model.lkml
    marketing.model.lkml
  views/
    core/
      orders.view.lkml
      customers.view.lkml
      products.view.lkml
    derived/
      customer_lifetime_value.view.lkml
      daily_revenue.view.lkml
    staging/
      stg_orders.view.lkml
  explores/
    orders.explore.lkml
    customers.explore.lkml
  refinements/
    marketing_refinements.lkml
  dashboards/
    executive_summary.dashboard.lookml
  manifest.lkml
```

### Key Principles

- **One view per file**: Each view should live in its own `.view.lkml` file
- **One-to-one Git mapping**: Maintain a single Git repository per LookML project
- **Explicit includes**: List files explicitly rather than using wildcards for predictable refinement ordering
- **Separate explores from models**: Define explores in dedicated `.explore.lkml` files for reusability across models
- **Layer separation**: Separate raw database views, business logic views, and presentation explores

### Naming Conventions

- Use **lowercase letters and underscores** for all object names (dimensions, measures, views, explores)
- Apply the `label` parameter for user-friendly display names
- Do **not** include "date" or "time" in dimension group names to avoid redundant suffixes (e.g., use `created` not `created_date`, which would generate `created_date_date`)
- Name measures descriptively: `total_revenue`, `average_order_value`, `count_distinct_customers`
- Prefix derived table views with context: `pdt_`, `ndt_`, or `dt_`

### Code Reusability

- **Substitution operators**: Use `${field_name}` syntax when referencing existing dimensions/measures so column name changes only need updating in one place
- **Extends**: Create base views with common fields and extend them for specialized use cases
- **Refinements**: Customize imported or generated LookML without modifying original files
- **Constants**: Define reusable values in the manifest file for schema names, connection references, etc.
- **DRY patterns**: Define SQL expressions once; use LookML references everywhere else

---

## Explore Design

### Join Best Practices

- **Always define `relationship`**: Specify `many_to_one`, `one_to_many`, `one_to_one`, or `many_to_many` for every join to ensure correct aggregation. Default is `many_to_one` if omitted, which may silently produce wrong results
- **Always define a primary key**: Every view must have a primary key dimension, including derived tables. Keys should uniquely identify records
- **Prefer direct joins**: Join views directly to the base view rather than chaining through intermediate views to reduce performance overhead
- **Use `sql_on` not `foreign_key`**: `sql_on` is more explicit and flexible
- **Avoid formatted timestamps in joins**: Use the `raw` timeframe for date/time fields in join conditions to prevent unnecessary casting and timezone conversion

### Field Organization

- **Group related fields**: Use `group_label` to organize dimensions/measures into logical sections in the Explore field picker
- **Hide implementation fields**: Set `hidden: yes` on primary keys, foreign keys, and intermediate calculation fields that users should not see
- **Use `description`**: Document every dimension and measure with clear business context
- **Set `drill_fields`**: Define meaningful drill paths for measures so users can click through to detail

### Access Control

- **Apply `always_filter`**: Require filters on high-cardinality or time-based fields to prevent full table scans
- **Use `conditionally_filter`**: Suggest default filters that users can modify
- **Row-level security**: Use `access_filter` with user attributes for data segmentation
- **Field-level security**: Use `access_grant` to restrict sensitive fields to authorized roles

### Explore Scoping

- **Limit exposed fields**: Use `fields` parameter on joins or explores to expose only relevant dimensions/measures
- **Create focused explores**: Build purpose-specific explores rather than one massive explore with every join
- **Use `view_label`**: Rename joined views for clarity in the field picker (avoid using `from` for simple renaming)

---

## Caching and PDT Strategy

### Caching Architecture

```
ETL completes
  -> sql_trigger detects new data
    -> datagroup triggers
      -> query cache invalidates
      -> PDTs rebuild
      -> scheduled deliveries fire
```

### Datagroup Configuration

```lookml
datagroup: etl_datagroup {
  sql_trigger: SELECT MAX(etl_timestamp) FROM etl_log ;;
  max_cache_age: "24 hours"
}
```

**Recommendations:**

- **Define both `sql_trigger` and `max_cache_age`**: The trigger handles normal ETL cycles; `max_cache_age` serves as a fallback if the trigger check fails
- **Cannot combine `sql_trigger` and `interval_trigger`**: If both are specified, `interval_trigger` takes precedence
- **Use `persist_with` at model level**: Sets default caching for all explores in the model
- **Override per-explore when needed**: Apply `persist_with` at the explore level for different refresh cadences
- **Avoid `persist_for`**: Prefer datagroups for their reusability, ETL sync, and admin panel visibility

### PDT Strategy

**When to Use PDTs:**

- Explores with many complex joins that can be pre-joined
- Subqueries or subselects in dimension SQL that slow queries
- Frequently accessed aggregations that rarely change
- Data transformations that are expensive at query time

**When NOT to Use PDTs:**

- Data that changes frequently and needs real-time results
- Simple queries that the database handles efficiently
- When the database already has materialized views handling the same work

**PDT Best Practices:**

- Use `datagroup_trigger` to sync PDT rebuilds with ETL schedule
- Define primary keys on all PDTs
- Use incremental PDTs for large append-only datasets to avoid full rebuilds
- Use separate scratch schemas for different Looker instances (production vs. QA)
- Monitor PDT build times and failures via the PDT Admin panel and PDT Event Log
- Test PDT builds manually before deploying to production

### Aggregate Awareness

Use aggregate tables to pre-compute common query patterns:

```lookml
explore: orders {
  aggregate_table: monthly_revenue {
    query: {
      dimensions: [created_month]
      measures: [total_revenue, count]
    }
    materialization: {
      datagroup_trigger: etl_datagroup
    }
  }
}
```

Looker automatically routes queries to aggregate tables when the requested dimensions and measures match, dramatically improving performance for common dashboard queries.

---

## Embedded Analytics Patterns

### SSO Embed Pattern

1. User authenticates with your application
2. Your server generates a signed Looker embed URL with user-specific parameters
3. Embed URL is loaded in an iframe in your application
4. User interacts with Looker content without separate login
5. Row-level security applied automatically via user attributes in the signed URL

### Embed SDK Integration

```javascript
// Initialize embedding with the Embed SDK
LookerEmbedSDK.init('https://your-instance.looker.com')

LookerEmbedSDK.createDashboardWithId(dashboardId)
  .appendTo('#dashboard-container')
  .withFilters({ 'region': userRegion })
  .on('dashboard:filters:changed', handleFilterChange)
  .on('drillmenu:click', handleDrill)
  .build()
  .connect()
```

### Best Practices for Embedding

- **Use the Embed SDK** over raw iframes for event handling and programmatic control
- **Pass user attributes** through embed URLs to drive row-level security
- **Minimize exposed fields**: Create embed-specific explores with only relevant fields
- **Use Spartan mode** (`/spartan` URL prefix) for navigation-free embedded experiences
- **Leverage Extensions Only groups**: Restrict embedded users to specific extensions/dashboards
- **Cache effectively**: Embedded dashboards often serve many users with similar queries; tune caching accordingly
- **Handle iframe communication**: Use postMessage API for bi-directional events between host and embedded content

### Multi-Tenant Embedding

- Define user attributes for tenant isolation (customer_id, organization_id)
- Apply access_filter on all explores used in embedded content
- Use model sets to restrict data access per tenant
- Test with multiple tenant contexts before deployment

---

## Governance

### Content Governance

- **Folder structure**: Organize content into folders with clear ownership and permissions
- **Content validation**: Run content validation regularly to detect broken dashboards/Looks referencing changed fields
- **Usage monitoring**: Use System Activity explores to identify unused content for cleanup
- **Dashboard standards**: Establish templates and design guidelines for consistent dashboard presentation

### Data Governance

- **Single source of truth**: Define metrics once in LookML; enforce usage through explores
- **Access controls**: Layer model sets, permission sets, access grants, and access filters for defense in depth
- **User attributes**: Centrally manage user-specific parameters driving security and personalization
- **Audit logging**: Monitor who accessed what data via System Activity and Cloud Audit Logs (Looker Core)

### LookML Governance

- **Code review**: Require pull requests for all LookML changes before deployment to production
- **Validation**: Run LookML validation and data tests before merging
- **Documentation**: Use `description` parameters on all views, dimensions, measures, and explores
- **Style guide**: Establish and enforce naming conventions, formatting standards, and structural patterns
- **Change management**: Communicate model changes to impacted stakeholders before deploying

### Permission Model

Looker uses a layered permission system:

1. **Permission Sets**: Define what actions a role can perform (view, explore, download, schedule, develop, admin)
2. **Model Sets**: Define which LookML models a role can access
3. **Roles**: Combine a permission set with a model set
4. **Groups**: Assign roles to groups of users
5. **User Attributes**: Drive dynamic, per-user data access rules
6. **Access Grants**: Field-level visibility tied to user attributes
7. **Access Filters**: Row-level security tied to user attributes

---

## Version Control

### Git Integration

- Every LookML project maps to a Git repository
- Supports GitHub, GitLab, Bitbucket, and other Git providers
- Changes tracked with full commit history, diffs, and blame

### Development Workflow

1. **Enter Development Mode**: Developer gets a personal branch (`dev-username`)
2. **Edit LookML**: Changes visible only to the developer
3. **Validate**: Run LookML validation to catch syntax and reference errors
4. **Test**: Run data tests to verify business logic assertions
5. **Commit**: Save changes with descriptive commit messages
6. **Create Pull Request** (optional): If project requires PR approval
7. **Merge**: Integrate changes into the production branch
8. **Deploy**: Push to production, making changes visible to all users

### Branching Strategies

- **Personal branches**: Auto-created `dev-` branches, read-only to other developers, cannot be deleted
- **Collaborative branches**: Shared branches for team work (must not start with `dev-`)
- **Pull request workflow**: Configure projects to require PR review before merge
- **Advanced deploy mode**: Specify exact commits for deployment rather than always using latest production branch

### Deployment Best Practices

- **Build PDTs before deploying**: Ensure all modified PDTs are built so tables are immediately available in production
- **Run validation before merge**: Catch LookML errors before they reach production
- **Run data tests**: Verify assertions about data quality and business rules
- **Use feature branches**: Develop large changes on dedicated branches, not personal dev branches
- **Resolve conflicts promptly**: Address merge conflicts immediately; conflict markers in production will break the model

### Multi-Environment Patterns

- Use Advanced Deploy Mode to control which commits are live in each environment
- Maintain separate Looker instances for development, staging, and production
- Use separate scratch schemas per environment to avoid PDT conflicts

Sources:
- [Best practice: LookML dos and don'ts](https://docs.cloud.google.com/looker/docs/best-practices/best-practices-lookml-dos-and-donts)
- [Using version control and deploying](https://docs.cloud.google.com/looker/docs/version-control-and-deploying-changes)
- [Caching queries](https://docs.cloud.google.com/looker/docs/caching-and-datagroups)
- [Optimize Looker performance](https://docs.cloud.google.com/looker/docs/best-practices/how-to-optimize-looker-server-performance)
- [Best Practices for Looker Development](https://kartaca.com/en/best-practices-for-looker-development-a-practical-guide-for-data-teams/)
- [LookML refinements](https://docs.cloud.google.com/looker/docs/lookml-refinements)
- [5 Ways to Configure Looker for Performance](https://blog.montrealanalytics.com/top-5-ways-to-configure-your-looker-instance-for-performance-and-scalability-33e6b3bf01b9)
- [Writing sustainable, maintainable LookML](https://docs.cloud.google.com/looker/docs/best-practices/how-to-write-sustainable-maintainable-lookml)
- [Row-Level Security in Looker](https://medium.com/@likkilaxminarayana/34-row-level-security-access-filters-user-attributes-in-looker-91992d40f7d6)
