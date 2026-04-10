# dbt Core Research Summary

## Research Scope

Comprehensive research on dbt Core as a data transformation platform, covering architecture, features, best practices, and diagnostics. Research conducted April 2026.

## Key Findings

### Architecture

dbt Core is a mature, well-documented SQL transformation framework following the ELT pattern. The architecture centers on a project-based structure with clear separation of concerns:

- **Project configuration** via `dbt_project.yml` and `profiles.yml`
- **Resource types**: models, sources, seeds, snapshots, tests, macros, documentation, analyses, metrics, semantic models, saved queries, UDFs (1.11+), groups, exposures
- **Execution model**: DAG-based dependency resolution using `ref()` and `source()` functions
- **Five materializations**: view (default), table, incremental, ephemeral, materialized view
- **Jinja2 templating**: Full programming environment within SQL (loops, conditionals, macros, variables)
- **Adapter system**: 7+ officially maintained adapters (PostgreSQL, Snowflake, BigQuery, Redshift, Spark, Databricks, Fabric) plus 20+ community adapters

**Confidence**: HIGH -- sourced from official dbt documentation (docs.getdbt.com)

### Features (dbt Core 1.11)

The current release (1.11.8, April 2026) introduces User-Defined Functions as first-class resources. Recent major additions across 1.8-1.11:

- **UDFs** (1.11): Warehouse-persisted custom functions, reusable outside dbt
- **Unit testing** (1.8): Mock-based model logic testing without database execution
- **Microbatch** (1.9): Time-series batch processing with parallel execution and automatic late-data handling
- **dbt Mesh**: Cross-project references, contracts, groups, access modifiers for multi-team governance
- **MetricFlow / Semantic Layer**: Centralized metric definitions via YAML, SQL generation for consistent metrics

**Confidence**: HIGH -- sourced from official release notes and documentation

### Best Practices

The community has converged on well-established patterns:

- **Three-layer structure**: staging (stg_) > intermediate (int_) > marts (fct_/dim_)
- **Naming conventions**: `stg_[source]__[entity]`, `int_[entity]_[verb]`, entity names for marts
- **Materialization progression**: views -> tables -> incremental (Golden Rule)
- **Testing**: Primary keys (unique + not_null) on every model, relationships on foreign keys
- **CI/CD**: Slim CI with `state:modified+` and `--defer`, `--fail-fast` for fast feedback
- **Code style**: 4-space indent, lowercase keywords, trailing commas, CTE-organized models

**Confidence**: HIGH -- sourced from official best practices guide and community consensus

### Diagnostics

dbt provides comprehensive debugging tools:

- **Error categories**: Runtime, Compilation, Dependency, Database
- **Primary tools**: `dbt debug`, compiled SQL in `target/`, `logs/dbt.log`, `--debug` flag
- **Artifacts**: `manifest.json`, `run_results.json`, `catalog.json` for programmatic analysis
- **CI/CD**: State comparison via artifacts, `--defer` for dependency resolution, environment isolation

**Confidence**: HIGH -- sourced from official debugging guides and community resources

## Architecture Decision Points

| Decision | Options | Recommendation |
|----------|---------|----------------|
| Materialization | view / table / incremental / ephemeral / materialized_view | Start with views, optimize as needed |
| Incremental strategy | append / merge / delete+insert / insert_overwrite / microbatch | merge for small-medium, delete+insert for large, microbatch for time-series |
| Testing scope | generic + singular + unit | All three; generic for data quality, unit for logic |
| Project structure | monolith vs. multi-project (Mesh) | Monolith until team/performance pain, then Mesh |
| CI approach | full build vs. slim CI | Slim CI (`state:modified+`) for PRs, full build for production |

## Gaps and Limitations

### Research Gaps
- **dbt Cloud-specific features**: This research focused on dbt Core (open source). dbt Cloud adds IDE, scheduling, environment management, and enhanced Semantic Layer features not covered in depth
- **Adapter-specific deep dives**: Each adapter has unique configurations, optimizations, and limitations that could warrant individual research
- **Migration patterns**: Upgrading between major dbt versions, migrating from other tools (Dataform, SQLMesh) not covered
- **Python models**: dbt supports Python models (via dbt-snowflake, dbt-databricks, dbt-bigquery) but this was not deeply researched

### Platform Limitations
- **Microbatch support**: Currently limited to Snowflake and Databricks adapters
- **Materialized views**: Not all adapters support them (Snowflake uses Dynamic Tables instead)
- **Custom incremental strategies**: Not supported by BigQuery or Spark adapters
- **dbt Mesh**: Cross-project references are a dbt Cloud Enterprise feature; Core users must manage inter-project dependencies manually
- **Semantic Layer**: Full Semantic Layer API requires dbt Cloud; dbt Core users get MetricFlow CLI

## Sources

### Primary Sources (Official)
- [dbt Documentation](https://docs.getdbt.com/) -- Official docs covering all features, configuration, and best practices
- [dbt Core Releases](https://github.com/dbt-labs/dbt-core/releases) -- GitHub release notes
- [dbt Core 1.11 GA announcement](https://www.getdbt.com/blog/dbt-core-1-11-is-ga) -- Feature overview
- [dbt Upgrading to v1.11](https://docs.getdbt.com/docs/dbt-versions/core-upgrade/upgrading-to-v1.11) -- Migration guide
- [dbt Best Practices: Project Structure](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview) -- Official structure guide
- [dbt Best Practices: Materializations](https://docs.getdbt.com/best-practices/materializations/5-best-practices) -- Materialization guide
- [dbt Best Practices: SQL Style](https://docs.getdbt.com/best-practices/how-we-style/2-how-we-style-our-sql) -- Code style guide
- [dbt Mesh Introduction](https://docs.getdbt.com/best-practices/how-we-mesh/mesh-1-intro) -- Multi-project pattern
- [About MetricFlow](https://docs.getdbt.com/docs/build/about-metricflow) -- Semantic layer docs
- [dbt Package Hub](https://hub.getdbt.com/) -- Package registry

### Secondary Sources
- [dbt Compatible Track Changelog](https://docs.getdbt.com/docs/dbt-versions/compatible-track-changelog) -- Version changelog
- [dbt Supported Data Platforms](https://docs.getdbt.com/docs/supported-data-platforms) -- Adapter list
- [Debugging dbt Errors](https://docs.getdbt.com/guides/debug-errors) -- Official debugging guide
- [Slim CI Best Practices](https://select.dev/posts/best-practices-for-dbt-workflows-2) -- CI/CD patterns
- [dbt on PyPI](https://pypi.org/project/dbt-core/) -- Package distribution

### Tertiary Sources
- Community blog posts, Medium articles, and technical guides from phData, Dagster, DataCamp, and others were used for cross-referencing and practical pattern validation
