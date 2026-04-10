# SSAS Best Practices

## Tabular Model Design

### Star Schema Foundation
- Design the data model as a star schema: fact tables surrounded by dimension tables
- Avoid snowflake schemas (normalized dimensions) -- they complicate DAX and hurt VertiPaq compression
- Use integer surrogate keys for relationships rather than natural keys
- Keep dimension tables narrow and fact tables as the only large tables

### Column Optimization
- Remove columns that are not needed for analysis, filtering, or relationships
- Split high-cardinality columns: separate date from time in datetime columns, split composite keys
- Avoid calculated columns when a measure or source query can achieve the same result
- Use integer data types where possible (better compression than strings)
- Reduce string column cardinality by trimming, standardizing casing, and removing unnecessary precision

### Relationship Design
- Prefer single-direction cross-filtering (one-to-many from dimension to fact)
- Use bidirectional filtering only when explicitly required (e.g., many-to-many patterns, RLS)
- Avoid circular dependencies in relationships
- Use inactive relationships with USERELATIONSHIP() for role-playing dimensions

### Partition Strategies
- Partition large fact tables by time period (monthly or yearly)
- Keep partition sizes manageable: ~100K-500K rows per partition is a good target
- Historical partitions rarely need reprocessing; focus refresh on current/recent partitions
- Use separate partitions for "hot" (frequently changing) and "cold" (static) data

---

## DAX Performance

### General Principles
- Write simple, readable DAX first; optimize only when performance issues are measured
- Use variables (VAR/RETURN) to avoid redundant calculations and improve readability
- Variables are evaluated once and cached; they also help the engine push more work to the Storage Engine

### SUMMARIZECOLUMNS vs. SUMX
- **SUMMARIZECOLUMNS** is highly optimized by the engine and is the function Power BI uses internally to populate visuals. It outperforms combinations of SUMMARIZE + ADDCOLUMNS + GROUPBY
- Before SSAS 2025, SUMMARIZECOLUMNS could not be used inside measures (only as a top-level query function)
- **SUMX** (and other iterators) process row-by-row. Use them when you genuinely need row-level calculation, not for simple aggregations
- SUM is syntactic sugar for SUMX over the same column -- there is no performance difference between them

### Avoiding Nested Iterators
- Nested iterators (e.g., `SUMX(Customers, SUMX(Products, ...))`) can create a Cartesian product explosion
- 10K customers x 5K products = 50 million iterations
- Solutions:
  - Flatten calculations into a single SUMX over the fact table
  - Use SUMMARIZE/SUMMARIZECOLUMNS to pre-aggregate one dimension before iterating the other
  - Use variables to collect results from one iterator before the next

### CALCULATE Best Practices
- Understand context transition: CALCULATE in an iterator converts row context to filter context
- Place filters in CALCULATE arguments rather than wrapping FILTER around the entire expression
- Use KEEPFILTERS when you want to intersect with rather than replace existing filters
- Avoid `CALCULATE(SUM(X), FILTER(ALL(Table), ...))` when `CALCULATE(SUM(X), Table[Col] = Value)` suffices

### Other Performance Tips
- Avoid DISTINCTCOUNT on high-cardinality columns when approximate results are acceptable (consider approximate count functions)
- Minimize use of EARLIER -- use variables instead for cleaner and faster code
- Use FORMAT sparingly in measures; it forces the Formula Engine to handle string conversion
- Avoid mixing data types in comparisons (implicit type conversion is expensive)

---

## Processing / Refresh Optimization

### Processing Strategy
- **Separate Process Data and Process Index**: Faster than Process Full because data becomes available sooner and index building can run independently
- **Process Add for append-only data**: Only loads new rows. Requires no overlap with existing data
- **Incremental refresh**: Process only partitions containing changed data

### Partition Management
- Automate partition creation/management with TMSL scripts or Tabular Editor
- Roll partitions forward: create new partitions for upcoming periods, merge old partitions into larger annual partitions
- Define queries per partition that filter source data by date range or reliable timestamp
- Use TMSL `createOrReplace` for idempotent partition management

### Source Query Optimization
- Ensure source queries are efficient (indexed, filtered at the source)
- Avoid SELECT * -- select only needed columns
- Push filters to the source query rather than filtering in SSAS
- Set appropriate timeouts: default ExternalCommandTimeout is 60 minutes; increase for large partitions

---

## Memory Management

### VertiPaq Compression Optimization
- **Reduce column cardinality**: The single most impactful optimization. Fewer distinct values = better compression
- **Split datetime columns**: Separate date and time components dramatically reduce cardinality
- **Split high-cardinality keys**: A 100M-row TransactionID column can go from ~3 GB to ~200 MB by splitting into two lower-cardinality columns
- **Remove unnecessary columns**: Every column consumes memory even if never queried
- **Use appropriate data types**: Integers compress better than strings; avoid storing numbers as text

### Dictionary Sizing
- Each column has a dictionary of distinct values. Dictionary size is proportional to cardinality
- Monitor dictionary sizes via VertiPaq Analyzer
- Columns with >1M distinct values are candidates for optimization or removal

### Server-Level Memory Configuration
- **LowMemoryLimit**: Threshold at which SSAS starts clearing caches (default 65% of total memory)
- **TotalMemoryLimit**: Hard upper limit for SSAS memory usage (default 80%)
- **HardMemoryLimit**: SSAS will reject requests above this threshold
- Monitor paging: if VertiPaq data is paging to disk, query performance degrades dramatically
- Size servers so all active models fit in memory with headroom for processing

---

## Security Patterns

### Dynamic RLS (Recommended Pattern)
1. Create a security mapping table in the model (columns: UserEmail, AuthorizedScope)
2. Load the mapping data from a source system (HR, Active Directory export, etc.)
3. Create a relationship from the security table to the relevant dimension
4. Define a single role with a DAX filter: `[UserEmail] = USERPRINCIPALNAME()`
5. Manage access changes by updating the security data -- no role changes needed

**Performance considerations:**
- Keep security tables small (one row per user-scope combination)
- Use simple filters on dimension tables
- Avoid calculated columns in RLS expressions
- Ensure proper relationships exist to avoid complex DAX in the filter

### Object-Level Security (SSAS 2022+)
- Use OLS to hide entire tables or columns from specific roles
- Useful for: sensitive financial columns, HR data, audit fields
- Complements RLS (OLS hides structure; RLS filters data within visible structure)

### General Security Best Practices
- Test RLS with "View as Role" in SSMS or DAX Studio
- Remember: USERPRINCIPALNAME() returns the UPN (email format), not domain\username
- Perspectives are NOT a security mechanism -- always enforce access through roles
- Audit role membership regularly
- Document RLS expressions and their business logic

---

## Deployment

### Development Tools
- **SQL Server Data Tools (SSDT) / Visual Studio**: Traditional IDE for SSAS projects. Uses the .bim file format
- **Tabular Editor**: Open-source (v2) and commercial (v3) tool for Tabular model development. Faster than SSDT for large models, supports scripting and automation
- **ALM Toolkit**: Free tool for comparing and merging Tabular model metadata between environments. Supports database compare, selective deployment, and source control integration

### TMSL Scripting
- JSON-based scripting language for Tabular models (compatibility level 1200+)
- Commands: createOrReplace, create, alter, delete, refresh, sequence
- Execute via: SSMS, PowerShell (Invoke-ASCmd), AMO/TOM, or XMLA endpoint
- Use `createOrReplace` for idempotent deployments

### CI/CD Pipeline
1. **Source control**: Store model metadata (Model.bim or Tabular Editor folder format) in Git
2. **Build**: Validate the model metadata (Tabular Editor CLI can do schema validation)
3. **Deploy**: Use Tabular Editor CLI or TMSL scripts to deploy to target server
   - `-O` flag: overwrite existing database
   - `-C` flag: update data source connection properties for the target environment
4. **Process**: Execute TMSL refresh commands post-deployment
5. **Test**: Run DAX queries against the deployed model to validate results

### Tabular Editor CLI for CI/CD
```bash
# Deploy model from source control to SSAS
TabularEditor.exe Model.bim -D "server_name" "database_name" -O -C -R
# -O: overwrite existing
# -C: update connection strings
# -R: replace roles
```

### Environment Management
- Use deployment pipelines with environment-specific connection strings
- Maintain separate dev/test/prod SSAS instances
- Use ALM Toolkit for comparing environments and identifying drift
- Automate partition management as part of the deployment process

---

## Testing and Validation

### DAX Studio
- Free tool for writing and analyzing DAX queries
- **Server Timings**: Shows Storage Engine vs. Formula Engine time breakdown
- **Query Plan**: Displays logical and physical query plans
- Identify whether bottlenecks are in the Formula Engine (single-threaded, hard to optimize) or Storage Engine (multi-threaded, cache-friendly)

### VertiPaq Analyzer
- Built into DAX Studio as "View Metrics" (Advanced tab)
- Uses DMVs to display model structure, sizes, cardinality, and compression statistics
- Quickly identifies the most expensive columns and tables
- Integrated into Tabular Editor as well (via the SQLBI VertiPaq Analyzer library)

### Testing Approach
- Validate measure results against known correct values from the source system
- Compare query performance before and after changes using DAX Studio Server Timings
- Test RLS with different user contexts
- Monitor processing times and resource consumption across environments
- Use Tabular Editor's Best Practice Analyzer to enforce naming conventions, remove unused objects, and catch common modeling errors
