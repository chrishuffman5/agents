# Looker Best Practices Reference

## LookML Project Structure

### File Organization

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
- **Separate Explores from models**: Define Explores in dedicated `.explore.lkml` files for reusability across models
- **Layer separation**: Separate raw database views, business logic views, and presentation Explores

### Naming Conventions

- Use **lowercase letters and underscores** for all object names (dimensions, measures, views, Explores)
- Apply the `label` parameter for user-friendly display names
- Do NOT include "date" or "time" in dimension group names (avoids redundant suffixes: `created_date_date`)
- Name measures descriptively: `total_revenue`, `average_order_value`, `count_distinct_customers`
- Prefix derived table views with context: `pdt_`, `ndt_`, or `dt_`

### Code Reusability

- **Substitution operators**: Use `${field_name}` so column name changes only need updating in one place
- **Extends**: Create base views with common fields; extend for specialized use cases
- **Refinements**: Customize imported/generated LookML without modifying original files
- **Constants**: Define reusable values in `manifest.lkml` for schema names, connection references
- **DRY patterns**: Define SQL expressions once; use LookML references everywhere else

---

## Explore Design

### Join Best Practices

- **Always define `relationship`**: Specify `many_to_one`, `one_to_many`, `one_to_one`, or `many_to_many`. Default is `many_to_one` if omitted, which may silently produce wrong results
- **Always define a primary key**: Every view must have a primary key dimension, including derived tables. Keys should uniquely identify records
- **Prefer direct joins**: Join views directly to the base view rather than chaining through intermediate views
- **Use `sql_on` not `foreign_key`**: `sql_on` is more explicit and flexible

```lookml
# GOOD: Explicit join with relationship and direct sql_on
join: customers {
  type: left_outer
  relationship: many_to_one
  sql_on: ${orders.customer_id} = ${customers.id} ;;
}

# BAD: Missing relationship (silently defaults to many_to_one)
join: customers {
  sql_on: ${orders.customer_id} = ${customers.id} ;;
}
```

- **Avoid formatted timestamps in joins**: Use the `raw` timeframe for date/time fields in join conditions to prevent unnecessary casting

### Field Organization

- **Group related fields**: Use `group_label` to organize dimensions/measures into logical sections
- **Hide implementation fields**: Set `hidden: yes` on primary keys, foreign keys, and intermediate calculation fields
- **Use `description`**: Document every dimension and measure with clear business context
- **Set `drill_fields`**: Define meaningful drill paths so users can click through to detail

```lookml
measure: total_revenue {
  type: sum
  sql: ${TABLE}.revenue ;;
  value_format_name: usd
  description: "Sum of all order revenue after discounts, before tax"
  drill_fields: [order_id, customer_name, created_date, revenue]
}
```

### Access Control

- **Apply `always_filter`**: Require filters on high-cardinality or time-based fields to prevent full table scans
- **Use `conditionally_filter`**: Suggest default filters that users can modify
- **Row-level security**: Use `access_filter` with user attributes for data segmentation
- **Field-level security**: Use `access_grant` to restrict sensitive fields to authorized roles

```lookml
explore: orders {
  always_filter: {
    filters: [orders.created_date: "last 90 days"]
  }

  access_filter: {
    field: orders.region
    user_attribute: allowed_region
  }
}

access_grant: can_see_pii {
  user_attribute: department
  allowed_values: ["analytics", "compliance"]
}

dimension: customer_email {
  type: string
  sql: ${TABLE}.email ;;
  required_access_grants: [can_see_pii]
}
```

### Explore Scoping

- **Limit exposed fields**: Use `fields` parameter on joins or Explores to expose only relevant dimensions/measures
- **Create focused Explores**: Build purpose-specific Explores rather than one massive Explore with every join
- **Use `view_label`**: Rename joined views for clarity in the field picker (avoid using `from` for simple renaming)
- **Use `sql_always_where`**: Apply permanent, invisible filters to reduce data scanned

---

## Caching and PDT Strategy

### Caching Architecture

```
ETL completes
  -> sql_trigger detects new data (value changes)
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
- Define both `sql_trigger` and `max_cache_age`: trigger handles normal ETL cycles; `max_cache_age` is the fallback
- Cannot combine `sql_trigger` and `interval_trigger` (interval takes precedence)
- Use `persist_with` at model level to set default caching for all Explores
- Override per-Explore with `persist_with` when different refresh cadences are needed
- Avoid `persist_for`: prefer datagroups for reusability, ETL sync, and admin panel visibility

### PDT Strategy

**When to Use PDTs:**
- Explores with many complex joins that can be pre-joined
- Subqueries or subselects in dimension SQL that slow queries
- Frequently accessed aggregations that rarely change
- Data transformations expensive at query time

**When NOT to Use PDTs:**
- Data that changes frequently and needs real-time results
- Simple queries the database handles efficiently
- When the database already has materialized views doing the same work

**PDT Best Practices:**
- Use `datagroup_trigger` to sync PDT rebuilds with ETL schedule
- Define primary keys on all PDTs
- Use incremental PDTs for large append-only datasets (avoid full rebuilds)
- Use separate scratch schemas for different Looker instances (production vs QA)
- Monitor PDT build times and failures via PDT Admin panel and PDT Event Log
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

  aggregate_table: daily_revenue_by_region {
    query: {
      dimensions: [created_date, region]
      measures: [total_revenue, average_order_value]
    }
    materialization: {
      datagroup_trigger: etl_datagroup
    }
  }
}
```

Looker automatically routes queries to aggregate tables when dimensions and measures match. This dramatically improves performance for common dashboard queries.

---

## Embedded Analytics Patterns

### SSO Embed Pattern

1. User authenticates with your application
2. Your server generates a signed Looker embed URL with user-specific parameters
3. Embed URL is loaded in an iframe
4. User interacts with Looker content without separate login
5. Row-level security applied automatically via user attributes in the signed URL

### Embed SDK Integration

```javascript
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
- **Minimize exposed fields**: Create embed-specific Explores with only relevant fields
- **Use Spartan mode** (`/spartan` URL prefix) for navigation-free embedded experiences
- **Leverage Extensions Only groups**: Restrict embedded users to specific extensions/dashboards
- **Cache effectively**: Embedded dashboards often serve many users with similar queries; tune caching accordingly
- **Handle iframe communication**: Use postMessage API for bi-directional events

### Multi-Tenant Embedding

- Define user attributes for tenant isolation (`customer_id`, `organization_id`)
- Apply `access_filter` on all Explores used in embedded content
- Use model sets to restrict data access per tenant
- Test with multiple tenant contexts before deployment

---

## Governance

### Content Governance

- **Folder structure**: Organize content into folders with clear ownership and permissions
- **Content validation**: Run Content Validator regularly to detect broken dashboards/Looks referencing changed fields
- **Usage monitoring**: Use System Activity Explores to identify unused content for cleanup
- **Dashboard standards**: Establish templates and design guidelines for consistent presentation

### Data Governance

- **Single source of truth**: Define metrics once in LookML; enforce usage through Explores
- **Access controls**: Layer model sets, permission sets, access grants, and access filters for defense in depth
- **User attributes**: Centrally manage user-specific parameters driving security and personalization
- **Audit logging**: Monitor access via System Activity and Cloud Audit Logs (Looker Core)

### LookML Governance

- **Code review**: Require pull requests for all LookML changes before deployment to production
- **Validation**: Run LookML validation and data tests before merging
- **Documentation**: Use `description` parameters on all views, dimensions, measures, and Explores
- **Style guide**: Establish and enforce naming conventions, formatting, and structural patterns
- **Change management**: Communicate model changes to impacted stakeholders before deploying

### Permission Model

Looker uses a layered permission system:

| Layer | Controls |
|---|---|
| **Permission Sets** | What actions a role can perform (view, explore, download, schedule, develop, admin) |
| **Model Sets** | Which LookML models a role can access |
| **Roles** | Combine a permission set + model set |
| **Groups** | Assign roles to groups of users |
| **User Attributes** | Dynamic per-user variables driving security rules |
| **Access Grants** | Field-level visibility tied to user attributes |
| **Access Filters** | Row-level security (WHERE clause injection) tied to user attributes |

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
6. **Create Pull Request** (optional): PR-based review before merge
7. **Merge**: Integrate changes into production branch
8. **Deploy**: Push to production; changes visible to all users

### Branching Strategies

- **Personal branches**: Auto-created `dev-` branches; read-only to other developers; cannot be deleted
- **Collaborative branches**: Shared branches (must not start with `dev-`)
- **Pull request workflow**: Configure projects to require PR review before merge
- **Advanced Deploy Mode**: Specify exact commits for deployment rather than always using latest

### Deployment Best Practices

- **Build PDTs before deploying**: Ensure all modified PDTs are built so tables are immediately available
- **Run validation before merge**: Catch LookML errors before they reach production
- **Run data tests**: Verify assertions about data quality and business rules
- **Use feature branches**: Develop large changes on dedicated branches, not personal dev branches
- **Resolve conflicts promptly**: Conflict markers in production will break the model

### Multi-Environment Patterns

- Use Advanced Deploy Mode to control which commits are live in each environment
- Maintain separate Looker instances for development, staging, and production
- Use separate scratch schemas per environment to avoid PDT conflicts
