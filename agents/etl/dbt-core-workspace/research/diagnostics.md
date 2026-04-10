# dbt Core Diagnostics

## Error Categories

dbt errors fall into four main categories based on when they occur in the execution pipeline:

| Error Type | Stage | Description |
|-----------|-------|-------------|
| **Runtime Error** | Initialization | Connection issues, missing files, profile problems |
| **Compilation Error** | Parsing/Compiling | Invalid Jinja, malformed YAML, invalid refs |
| **Dependency Error** | Graph Validation | Circular dependencies, missing upstream models |
| **Database Error** | SQL Execution | SQL syntax errors, permission issues, data type mismatches |

---

## Common Errors and Solutions

### Runtime Errors

**"Not a dbt project"**
- Cause: Missing `dbt_project.yml` in working directory
- Fix: Ensure you're in the project root or set `--project-dir`

**"Could not find profile named 'X'"**
- Cause: Profile in `dbt_project.yml` doesn't match any entry in `profiles.yml`
- Fix: Check `profile:` key in `dbt_project.yml` matches a profile in `~/.dbt/profiles.yml`

**Connection failures**
- Cause: Incorrect credentials, network issues, warehouse down
- Fix: Run `dbt debug` to validate connection; check host, port, user, password, database, schema

**Invalid YAML**
- Cause: Indentation errors, incorrect keys, missing colons
- Fix: Validate YAML using online tools; check for tabs vs spaces; look for unquoted special characters

**"Duplicate resource name"**
- Cause: Two resources sharing the same name in the project
- Fix: Rename conflicting resources; in 1.11+, set `require_unique_project_resource_names` flag

### Compilation Errors

**"Model depends on a node named 'X' which was not found"**
- Cause: `ref('X')` references a model that doesn't exist
- Fix: Check model file exists, check spelling, ensure it's not disabled

**Jinja syntax errors**
- Cause: Unclosed blocks (`{% endmacro %}`, `{% endif %}`), missing braces, improper nesting
- Fix: Check matching open/close tags; use IDE with Jinja highlighting

**"Encountered an error when attempting to parse"**
- Cause: Invalid Jinja/SQL syntax that prevents parsing
- Fix: Check for unmatched `{{ }}`, `{% %}` delimiters; validate SQL syntax

**"Recursion depth exceeded"**
- Cause: Macro calling itself infinitely or deeply nested Jinja
- Fix: Check macro logic for infinite recursion; simplify nesting

### Dependency Errors

**Circular dependencies**
- Cause: Model A refs Model B which refs Model A (direct or indirect)
- Fix: Refactor to break the cycle; extract shared logic into a new intermediate model

**Self-referential model**
- Cause: Model referencing `{{ this }}` without being incremental
- Fix: Use `{{ this }}` only inside `{% if is_incremental() %}` blocks

### Database Errors

**SQL syntax errors**
- Cause: Invalid SQL sent to the warehouse (often from Jinja compilation)
- Fix: Check compiled SQL in `target/compiled/`; copy to query editor and debug

**Permission denied**
- Cause: Database user lacks required privileges
- Fix: Grant appropriate CREATE, SELECT, INSERT permissions

**Data type mismatches**
- Cause: Incompatible column types in joins, unions, or casts
- Fix: Explicit casting; check source column types

**Relation does not exist**
- Cause: Referenced table/view not created yet or wrong schema
- Fix: Check execution order; ensure upstream models ran successfully; check schema configuration

---

## Debugging Tools and Techniques

### dbt debug

First-line diagnostic command. Validates:
- Project configuration is valid
- profiles.yml is found and parseable
- Database connection succeeds
- Required dependencies are installed

```bash
dbt debug
# Output: Checks config, profile, connection, dependencies
```

### dbt show

Preview model output without materializing:
```bash
dbt show --select my_model --limit 10
# Shows first 10 rows of compiled query
```

### dbt compile

Compile all models to SQL without executing:
```bash
dbt compile
# Output goes to target/compiled/
```

Useful for:
- Inspecting generated SQL before execution
- Debugging Jinja template issues
- Validating ref/source resolution

### Compiled SQL Inspection

The most important debugging technique. Two directories:

| Directory | Contents | Purpose |
|-----------|----------|---------|
| `target/compiled/` | SELECT statements only | Copy to query editor to test |
| `target/run/` | Full DDL/DML (CREATE TABLE AS, etc.) | See exactly what dbt executed |

**Workflow**:
1. Open both the original `.sql` model and `target/compiled/` version side by side
2. Copy compiled SQL into warehouse query editor
3. Execute to isolate the exact error
4. Fix the model source, not the compiled output

### Debug Flag

```bash
dbt run --debug
# or
dbt run -d
```

Provides:
- Full stack traces on errors
- Detailed SQL execution logs
- Connection debug information
- Timing for each step

### Log Files

**Console output**: Real-time execution summary
**`logs/dbt.log`**: Detailed execution log including:
- Full SQL sent to the warehouse
- Timing information
- Connection details
- Complete error traces

```bash
# View recent log entries
tail -100 logs/dbt.log
```

### dbt Artifacts

Generated in `target/` after each run:

| Artifact | Purpose |
|----------|---------|
| `manifest.json` | Complete project graph (models, tests, sources, macros) |
| `run_results.json` | Execution results (timing, status, rows affected) |
| `catalog.json` | Database schema information (generated by `dbt docs generate`) |
| `sources.json` | Source freshness results |

Use artifacts for:
- Programmatic analysis of build performance
- CI/CD state comparison (`state:modified`)
- Custom alerting on failures
- Documentation generation

---

## Performance Diagnostics

### Slow Model Identification

```bash
# Check run_results.json for timing
# Models with longest execution times need optimization
```

**Common causes of slow models**:
- Large table scans without partitioning/clustering
- Complex joins on non-indexed columns
- Unnecessary `SELECT *` pulling all columns
- Stacked views creating deep query plans
- Missing incremental strategy for large datasets
- Aggregations on full tables before filtering

### Full Refresh Triggers

Incremental models may need full refresh when:
- Schema changes (new/removed columns) if `on_schema_change` not configured
- Source data retroactively corrected
- Incremental logic has a bug that introduced bad data
- First deployment to a new environment

```bash
dbt run --full-refresh --select my_incremental_model
```

### Warehouse Compute Optimization

**Snowflake**:
- Right-size virtual warehouses (start X-SMALL, scale up as needed)
- Use warehouse auto-suspend and auto-resume
- Monitor with `QUERY_HISTORY` view
- Use `cluster_by` for frequently filtered large tables

**BigQuery**:
- Partition by date columns used in WHERE filters
- Cluster by columns used in GROUP BY / WHERE
- Enforce partition filters to prevent full scans
- Monitor with `INFORMATION_SCHEMA.JOBS_BY_PROJECT`

**Redshift**:
- Use `dist` and `sort` keys for join/filter columns
- Monitor with `STL_QUERY` / `SVL_QUERY_SUMMARY`
- Vacuum tables periodically

**General**:
- Aggregate early (before joins)
- Filter early in CTEs
- Avoid `UNION` when `UNION ALL` suffices
- Use ephemeral models for shared intermediate logic

---

## CI/CD Diagnostics

### State Comparison Failures

**"Could not find a state directory"**
- Cause: `--state` path doesn't contain a valid manifest.json
- Fix: Ensure production artifacts are downloaded before CI run

**"No nodes selected"**
- Cause: `state:modified` found no changes relative to production state
- Fix: Verify the correct production manifest is being compared; check if changes are in non-model files

**Model selected but dependencies missing**
- Cause: `state:modified` selected a model whose upstream models aren't in the CI build
- Fix: Use `--defer` flag to reference production tables for unmodified upstream models

### Environment-Specific Problems

**Schema conflicts**
- Cause: Multiple CI jobs writing to the same schema
- Fix: Use PR-specific schemas: `{{ env_var('DBT_SCHEMA', 'ci') }}_pr_{{ env_var('PR_NUMBER') }}`

**Different results in dev vs prod**
- Cause: Data differences, timezone settings, warehouse-specific behavior
- Fix: Use `audit_helper` package to compare outputs; check `target.name` conditionals

**Profile not found in CI**
- Cause: CI environment doesn't have profiles.yml or environment variables
- Fix: Set `DBT_PROFILES_DIR` or use environment variables in profiles.yml

### Common CI Pipeline Issues

**dbt deps failures**
- Cause: Network issues, private packages, version conflicts
- Fix: Cache packages, pin versions, use `--upgrade` for fresh installs

**Timeout errors**
- Cause: Models taking too long in CI environment
- Fix: Use `--fail-fast`, limit thread count, use `--empty` for schema-only validation

**State file version mismatch**
- Cause: Different dbt versions between CI and production
- Fix: Ensure consistent dbt versions across environments

---

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

- Editing files in `target/` instead of source directory (target is regenerated each run)
- Forgetting to save files before running (dbt uses last-saved version)
- Running `dbt test` before `dbt run` (tables must exist first, or use `dbt build`)
- Missing `dbt deps` after adding new packages
- YAML indentation errors (use spaces, not tabs; validate with linter)
- Unsupported Jinja operations in model SQL (e.g., Python-specific syntax)
