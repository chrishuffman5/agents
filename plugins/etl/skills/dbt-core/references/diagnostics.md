# dbt Core Diagnostics and Troubleshooting

## Error Categories

dbt errors fall into four categories based on when they occur in the execution pipeline:

| Error Type | Stage | Description |
|---|---|---|
| **Runtime Error** | Initialization | Connection issues, missing files, profile problems |
| **Compilation Error** | Parsing/Compiling | Invalid Jinja, malformed YAML, invalid refs |
| **Dependency Error** | Graph Validation | Circular dependencies, missing upstream models |
| **Database Error** | SQL Execution | SQL syntax errors, permissions, data type mismatches |

## Common Errors and Solutions

### Runtime Errors

**"Not a dbt project"**
```
Runtime Error: fatal: Not a dbt project (or any of the parent directories).
Missing dbt_project.yml file
```
- Cause: Missing `dbt_project.yml` in working directory
- Fix: Ensure you're in the project root or set `--project-dir`

**"Could not find profile named 'X'"**
```
Runtime Error: Could not find profile named 'jaffle_shop'
```
- Cause: Profile in `dbt_project.yml` doesn't match any entry in `profiles.yml`
- Fix: Check `profile:` key in `dbt_project.yml` matches a profile in `~/.dbt/profiles.yml`
- Check: Run `dbt debug` to see which profiles.yml is being loaded

**Connection failures**
```
Runtime Error: Database Error -- could not connect to server
```
- Cause: Incorrect credentials, network issues, warehouse suspended
- Fix: Run `dbt debug` to validate connection. Check host, port, user, password, database, schema, warehouse (Snowflake), project (BigQuery).

**Invalid YAML**
```
Compilation Error: Error reading file: expected a single document
```
- Cause: Indentation errors, missing colons, tabs vs spaces
- Fix: Validate YAML syntax. Check for unquoted special characters. Use a YAML linter.

**"Duplicate resource name"**
```
Compilation Error: dbt found two resources with the name "customers"
```
- Cause: Two resources sharing the same name in the project
- Fix: Rename one. In 1.11+, set `require_unique_project_resource_names` behavior flag.

### Compilation Errors

**"Model depends on a node named 'X' which was not found"**
```
Compilation Error: Model 'fct_orders' depends on a node named 'stg_orders'
which was not found
```
- Cause: `ref('stg_orders')` references a model that doesn't exist
- Fix: Check model file exists, check spelling, ensure it's not disabled via `enabled: false`

**Jinja syntax errors**
```
Compilation Error: unexpected end of template
Compilation Error: expected token 'end of print statement', got 'name'
```
- Cause: Unclosed blocks (`{% endmacro %}`, `{% endif %}`), missing braces, improper nesting
- Fix: Check matching open/close tags. Use IDE with Jinja highlighting. Look for unmatched `{{ }}` or `{% %}`.

**"Recursion depth exceeded"**
```
Compilation Error: maximum recursion depth exceeded
```
- Cause: Macro calling itself infinitely or deeply nested Jinja
- Fix: Check macro logic for infinite loops. Simplify nesting.

### Dependency Errors

**Circular dependencies**
```
Compilation Error: Found a cycle: model.a -> model.b -> model.a
```
- Cause: Model A refs Model B which refs Model A (direct or indirect)
- Fix: Refactor to break the cycle. Extract shared logic into a new intermediate model.

**Self-referential model**
```
Compilation Error: Model 'my_model' depends on itself
```
- Cause: Model referencing `{{ this }}` without being incremental
- Fix: Use `{{ this }}` only inside `{% if is_incremental() %}` blocks

### Database Errors

**SQL syntax errors**
```
Database Error in model my_model: syntax error at or near "SELCT"
```
- Cause: Invalid SQL sent to the warehouse (often from Jinja compilation issues)
- Fix: Check compiled SQL in `target/compiled/`. Copy to warehouse query editor to debug.

**Permission denied**
```
Database Error: Insufficient privileges to operate on schema 'analytics'
```
- Cause: Database user lacks required privileges
- Fix: Grant CREATE, SELECT, INSERT privileges on the target schema. Check role assignments.

**Data type mismatches**
```
Database Error: Column 'amount' is of type varchar but expression is of type numeric
```
- Cause: Incompatible column types in joins, unions, or casts
- Fix: Add explicit casting. Check source column types.

**Relation does not exist**
```
Database Error: Relation 'analytics.staging.stg_customers' does not exist
```
- Cause: Referenced table/view not created yet or wrong schema
- Fix: Check execution order. Ensure upstream models ran successfully. Check schema config.

## Debugging Tools and Techniques

### dbt debug

First-line diagnostic command:

```bash
dbt debug
```

Validates: project configuration, profiles.yml location, database connection, required dependencies.

### Compiled SQL Inspection

The most important debugging technique. Two directories:

| Directory | Contents | Purpose |
|---|---|---|
| `target/compiled/` | SELECT statements only | Copy to query editor to test |
| `target/run/` | Full DDL/DML (CREATE TABLE AS, etc.) | See exactly what dbt executed |

**Workflow**:
1. Open the original `.sql` model and `target/compiled/` version side by side
2. Copy compiled SQL into warehouse query editor
3. Execute to isolate the exact error
4. Fix the model source, not the compiled output

### dbt show

Preview model output without materializing:
```bash
dbt show --select my_model --limit 10
```

### dbt compile

Compile all models to SQL without executing:
```bash
dbt compile
# Compiled SQL available in target/compiled/
```

### Debug Flag

```bash
dbt run --debug --select my_model
```

Provides: full stack traces, detailed SQL execution logs, connection debug info, timing for each step.

### Log Files

**Console output**: Real-time execution summary.

**`logs/dbt.log`**: Detailed execution log including full SQL sent to the warehouse, timing, connection details, complete error traces.

```bash
tail -100 logs/dbt.log
```

### dbt Artifacts

Generated in `target/` after each run:

| Artifact | Diagnostic Use |
|---|---|
| `manifest.json` | Inspect dependency graph, model configs |
| `run_results.json` | Identify slow models by timing |
| `catalog.json` | Verify schema/column metadata |
| `sources.json` | Check source freshness results |

## Performance Diagnostics

### Identifying Slow Models

Check `run_results.json` for execution timing. Sort by `execution_time` to find bottlenecks.

**Common causes of slow models**:
- Large table scans without partitioning/clustering
- Complex joins on non-indexed columns
- Unnecessary `SELECT *` pulling all columns
- Stacked views creating deep query plans (5+ levels of views)
- Missing incremental strategy for large datasets
- Aggregations on full tables before filtering

### When to Force Full Refresh

Incremental models need full refresh when:
- Schema changes (new/removed columns) if `on_schema_change` not configured
- Source data retroactively corrected
- Incremental logic has a bug that introduced bad data
- First deployment to a new environment

```bash
dbt run --full-refresh --select my_incremental_model
```

### Warehouse-Specific Optimization

**Snowflake**:
- Right-size virtual warehouses (start X-SMALL, scale as needed)
- Use warehouse auto-suspend and auto-resume (1-2 min)
- Monitor via `QUERY_HISTORY` view
- Use `cluster_by` for frequently filtered large tables

**BigQuery**:
- Partition by date columns used in WHERE filters
- Cluster by columns used in GROUP BY / WHERE
- Enforce partition filters to prevent full scans
- Monitor via `INFORMATION_SCHEMA.JOBS_BY_PROJECT`

**Redshift**:
- Use `dist` and `sort` keys for join/filter columns
- Monitor via `STL_QUERY` / `SVL_QUERY_SUMMARY`
- Vacuum tables periodically

**General**:
- Aggregate early (before joins)
- Filter early in CTEs
- Avoid `UNION` when `UNION ALL` suffices
- Use ephemeral models for shared intermediate logic

## CI/CD Diagnostics

### State Comparison Failures

**"Could not find a state directory"**
```
Runtime Error: Could not find a state directory at path './prod-artifacts/'
```
- Cause: `--state` path doesn't contain a valid manifest.json
- Fix: Ensure production artifacts are downloaded before CI run. Check artifact path in CI config.

**"No nodes selected"**
```
WARNING: Nothing to do. No nodes selected.
```
- Cause: `state:modified` found no changes relative to production state
- Fix: Verify the correct production manifest is being compared. Check if changes are in non-model files (macros, tests).

**Model selected but dependencies missing**
- Cause: `state:modified` selected a model whose upstream models aren't in the CI build
- Fix: Use `--defer` flag to reference production tables for unmodified upstream models

### Environment-Specific Problems

**Schema conflicts**
- Cause: Multiple CI jobs writing to the same schema
- Fix: Use PR-specific schemas:
  ```yaml
  schema: "ci_pr_{{ env_var('PR_NUMBER') }}"
  ```

**Different results in dev vs prod**
- Cause: Data differences, timezone settings, warehouse-specific behavior
- Fix: Use `audit_helper` package to compare outputs. Check `target.name` conditionals.

**Profile not found in CI**
```
Runtime Error: Could not find profile named 'my_project'
```
- Cause: CI environment doesn't have profiles.yml or environment variables
- Fix: Set `DBT_PROFILES_DIR` or use `env_var()` in profiles.yml with CI-provided secrets

### Common CI Pipeline Issues

**dbt deps failures**
```
Runtime Error: Failed to download package
```
- Cause: Network issues, private packages, version conflicts
- Fix: Cache packages, pin versions, use `--upgrade` for fresh installs

**Timeout errors**
- Cause: Models taking too long in CI environment
- Fix: Use `--fail-fast`, limit thread count, use `--empty` for schema-only validation

**State file version mismatch**
```
IncompatibleSchemaError: The manifest file version is not compatible
```
- Cause: Different dbt versions between CI and production
- Fix: Ensure consistent dbt versions across environments. Pin dbt version in requirements.

## Debugging Checklist

### Quick Diagnostic Steps

1. **Run `dbt debug`** -- Validates configuration and connection
2. **Read the error message** -- dbt provides file location and error type
3. **Check compiled SQL** -- Open `target/compiled/` for the failing model
4. **Test compiled SQL** -- Paste into warehouse query editor
5. **Check logs** -- Review `logs/dbt.log` for detailed error context
6. **Isolate the model** -- Run single model: `dbt run --select my_model`
7. **Check dependencies** -- Run upstream models: `dbt run --select +my_model`
8. **Use debug flag** -- `dbt run --debug --select my_model`

### Common Pitfalls

1. **Editing files in `target/`** -- Target is regenerated each run. Edit source files only.
2. **Forgetting to save files before running** -- dbt compiles the last-saved version.
3. **Running `dbt test` before `dbt run`** -- Tables must exist first. Use `dbt build` instead.
4. **Missing `dbt deps` after adding packages** -- New packages require `dbt deps` before first use.
5. **YAML indentation errors** -- Use spaces, not tabs. Validate with a linter.
6. **Unsupported Jinja operations** -- Not all Python syntax works in dbt Jinja (e.g., f-strings, list comprehensions are limited).
7. **Wrong target environment** -- Verify with `dbt debug` which target is active. Use `--target` to override.
8. **Stale `target/` artifacts** -- Run `dbt clean` then rebuild to clear cached state.

## Node Selection Syntax

For targeted debugging and execution:

| Selector | Meaning |
|---|---|
| `my_model` | Single model |
| `+my_model` | Model and all upstream dependencies |
| `my_model+` | Model and all downstream dependents |
| `+my_model+` | Full upstream and downstream chain |
| `tag:daily` | All models with the `daily` tag |
| `source:jaffle_shop` | All models that depend on the jaffle_shop source |
| `state:modified` | Models with code changes vs. production state |
| `state:modified+` | Modified models and their downstream dependents |
| `test_type:unit` | Only unit tests |
| `test_type:data` | Only data (generic/singular) tests |
| `config.materialized:incremental` | All incremental models |
| `path:models/staging` | All models in a directory |

Combine with set operators: `model_a model_b` (union), `model_a,model_b` (intersection), `model_a --exclude model_b` (exclusion).
