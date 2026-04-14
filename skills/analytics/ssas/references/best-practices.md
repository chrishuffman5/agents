# SSAS Best Practices

## Star Schema Design

### Foundation Principles

Design every Tabular model as a star schema: fact tables surrounded by dimension tables.

- **Fact tables** -- Contain numeric measures and foreign keys to dimensions. These are the only large tables
- **Dimension tables** -- Contain descriptive attributes for filtering and grouping. Keep them narrow
- **Avoid snowflake schemas** -- Normalized dimensions complicate DAX filter propagation and hurt VertiPaq compression. Flatten dimension hierarchies into single tables
- **Use integer surrogate keys** -- Better compression than natural keys, composite keys, or strings
- **One-to-many relationships** -- Always from dimension (one) to fact (many) with single-direction cross-filtering

### Column Optimization

- Remove columns not needed for analysis, filtering, or relationships
- Split high-cardinality columns: separate date from time in datetime columns, split composite keys
- Avoid calculated columns when a measure or source query achieves the same result
- Use integer data types where possible (better compression than strings)
- Reduce string column cardinality by trimming, standardizing casing, removing unnecessary precision

### Relationship Design

- Prefer single-direction cross-filtering (dimension to fact)
- Use bidirectional filtering only when explicitly required (many-to-many patterns, RLS propagation)
- Avoid circular dependencies
- Use inactive relationships with `USERELATIONSHIP()` for role-playing dimensions (e.g., OrderDate, ShipDate both relating to a single Date dimension)

### Partition Strategy

- Partition large fact tables by time period (monthly or yearly)
- Target ~100K-500K rows per partition for optimal processing speed
- Separate "hot" (frequently changing) from "cold" (static) data
- Historical partitions rarely need reprocessing -- focus refresh on current/recent periods
- Automate partition management with TMSL scripts or Tabular Editor

## DAX Performance

### General Principles

- Write simple, readable DAX first -- optimize only when performance issues are measured
- Use `VAR/RETURN` to cache intermediate results and avoid redundant calculations
- Variables are evaluated once and cached; they help push more work to the Storage Engine

### SUMMARIZECOLUMNS

- The most optimized aggregation function in DAX
- Power BI uses it internally to populate visuals
- Outperforms combinations of SUMMARIZE + ADDCOLUMNS + GROUPBY
- Before SSAS 2025, could not be used inside measures (only as a top-level query function)

### Avoiding Nested Iterators

Nested iterators create Cartesian product explosions:
- `SUMX(Customers, SUMX(Products, ...))` with 10K customers and 5K products = 50 million iterations

**Solutions:**
- Flatten calculations into a single SUMX over the fact table
- Use SUMMARIZE/SUMMARIZECOLUMNS to pre-aggregate one dimension before iterating the other
- Use variables to collect results from one iterator before the next

### CALCULATE Best Practices

- Understand context transition: CALCULATE inside an iterator converts row context to filter context
- Place filters in CALCULATE arguments rather than wrapping FILTER around the expression
- Use KEEPFILTERS to intersect with (rather than replace) existing filters
- Prefer `CALCULATE(SUM(X), Table[Col] = Value)` over `CALCULATE(SUM(X), FILTER(ALL(Table), ...))`

### Other DAX Performance Tips

- Avoid DISTINCTCOUNT on high-cardinality columns when approximate results are acceptable
- Minimize use of EARLIER -- use variables instead for cleaner and faster code
- Use FORMAT sparingly in measures: forces single-threaded Formula Engine string conversion
- Avoid mixing data types in comparisons (implicit type conversion is expensive)
- SUM and SUMX over the same column have identical performance (SUM is syntactic sugar for SUMX)

## Processing Optimization

### Processing Strategy

- **Separate Process Data and Process Index:** Faster than Process Full. Data becomes available for queries sooner, and index building runs independently
- **Process Add for append-only data:** Only loads new rows. Requires no overlap with existing data
- **Incremental refresh:** Process only partitions containing changed data

### Partition Management

- Automate partition creation and rollover with TMSL scripts or Tabular Editor
- Roll partitions forward: create new partitions for upcoming periods, merge old partitions into larger annual partitions
- Define per-partition queries that filter source data by date range or reliable timestamp
- Use TMSL `createOrReplace` for idempotent partition management

### Source Query Optimization

- Ensure source queries are efficient: indexed at the source, filtered to only needed rows
- Avoid `SELECT *` -- select only needed columns
- Push filters to the source query rather than filtering in SSAS
- Set appropriate timeouts: default ExternalCommandTimeout is 3,600 seconds (60 minutes); increase for large partitions

### Processing Resource Management

- Budget 1.5-2x the final model size in memory during processing
- MaxParallelism controls concurrent partition processing. Reduce if source database cannot handle concurrent loads
- Schedule processing during low-activity windows on the source database
- Implement retry logic in processing automation for transient connectivity failures

## Memory Management

### VertiPaq Compression Optimization

- **Reduce column cardinality** -- The single most impactful optimization. Fewer distinct values = better compression
- **Split datetime columns** -- Separate date and time components can reduce cardinality by 90%+
- **Split high-cardinality keys** -- A 100M-row TransactionID column can go from ~3 GB to ~200 MB by splitting into two lower-cardinality columns
- **Remove unnecessary columns** -- Every column consumes memory even if never queried
- **Use appropriate data types** -- Integers compress better than strings; avoid storing numbers as text

### Dictionary Sizing

- Each column has a dictionary of distinct values. Dictionary size is proportional to cardinality
- Monitor dictionary sizes via VertiPaq Analyzer
- Columns with >1M distinct values are candidates for optimization or removal

### Server Memory Configuration

| Setting | Default | Guidance |
|---------|---------|----------|
| LowMemoryLimit | 65% | SSAS starts clearing caches. Increase if caches are frequently evicted |
| TotalMemoryLimit | 80% | Hard cap on SSAS memory. Set based on other services sharing the server |
| HardMemoryLimit | 80% | Absolute limit. Operations fail above this |
| VertiPaqPagingPolicy | 1 | Set to 0 in production if you prefer fast failure over degraded paged performance |

- Size servers so all active models fit in memory with 20-30% headroom
- If multiple models share a server, monitor per-model memory via DMVs
- Paged queries are orders of magnitude slower -- prevent paging in production

## Security Patterns

### Dynamic RLS (Recommended)

1. Create a security mapping table (UserEmail, AuthorizedScope)
2. Load mapping data from a source system (HR, Active Directory export)
3. Create a relationship from the security table to the relevant dimension
4. Define a single role with DAX filter: `[UserEmail] = USERPRINCIPALNAME()`
5. Manage access changes by updating data -- no role modifications needed

**Performance considerations:**
- Keep security tables small (one row per user-scope combination)
- Use simple filters on dimension tables
- Avoid calculated columns in RLS expressions
- Ensure proper relationships exist to avoid complex DAX in the filter

### OLS (SSAS 2022+)

- Use to hide entire tables or columns from specific roles
- Useful for sensitive financial columns, HR data, audit fields
- Complements RLS: OLS hides structure, RLS filters data within visible structure

### General Security Guidance

- Test RLS with "View as Role" in SSMS or DAX Studio
- `USERPRINCIPALNAME()` returns UPN (email format), not domain\username
- Perspectives are NOT a security mechanism -- enforce access through roles
- Audit role membership regularly
- Document RLS expressions and their business logic

## Deployment and CI/CD

### Development Tools

| Tool | Use Case |
|------|----------|
| SSDT / Visual Studio | Traditional IDE for SSAS projects. Uses .bim file format |
| Tabular Editor (v2/v3) | Faster than SSDT for large models. Supports scripting, automation, Best Practice Analyzer |
| ALM Toolkit | Compare and merge model metadata between environments. Selective deployment |
| DAX Studio | Query development, performance analysis, model metrics |

### TMSL Scripting

JSON-based scripting language for Tabular models (compatibility level 1200+):
- Commands: `createOrReplace`, `create`, `alter`, `delete`, `refresh`, `sequence`
- Execute via SSMS, PowerShell (Invoke-ASCmd), AMO/TOM, or XMLA endpoint
- Use `createOrReplace` for idempotent deployments

### CI/CD Pipeline

1. **Source control:** Store model metadata (Model.bim or Tabular Editor folder format) in Git
2. **Build:** Validate model metadata using Tabular Editor CLI for schema validation
3. **Deploy:** Use Tabular Editor CLI or TMSL scripts to deploy to target server
   - `-O` flag: overwrite existing database
   - `-C` flag: update data source connection properties for the target environment
   - `-R` flag: replace roles
4. **Process:** Execute TMSL refresh commands post-deployment
5. **Test:** Run DAX queries against the deployed model to validate results

### Tabular Editor CLI Example

```bash
# Deploy model from source control to SSAS
TabularEditor.exe Model.bim -D "server_name" "database_name" -O -C -R
```

### Environment Management

- Use deployment pipelines with environment-specific connection strings
- Maintain separate dev/test/prod SSAS instances
- Use ALM Toolkit for comparing environments and identifying drift
- Automate partition management as part of the deployment process

## Testing and Validation

### Performance Testing

- Use DAX Studio Server Timings to measure Storage Engine vs. Formula Engine time
- Benchmark mode in DAX Studio provides repeatable measurements
- Compare performance before and after changes
- Test with both cold cache (first run) and warm cache (subsequent runs)

### Data Validation

- Validate measure results against known correct values from the source system
- Test RLS with different user contexts using "View as Role"
- Monitor processing times and resource consumption across environments

### Model Quality

- Use Tabular Editor Best Practice Analyzer to enforce naming conventions, remove unused objects, and catch common modeling errors
- Review VertiPaq Analyzer output for memory optimization opportunities
- Document and review all DAX measures for clarity and correctness
