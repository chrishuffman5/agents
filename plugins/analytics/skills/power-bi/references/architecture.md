# Power BI Architecture Reference

## VertiPaq Engine (Import Mode)

VertiPaq is the in-memory columnar storage and query engine that powers Import mode and Direct Lake mode in Power BI.

### Columnar Storage

Data is stored column-by-column rather than row-by-row:
- Each column is independently compressed using value encoding, dictionary encoding, or run-length encoding
- VertiPaq automatically selects the optimal encoding per column based on data characteristics
- Columnar storage enables massive compression ratios (10:1 to 100:1 depending on data cardinality)
- Only columns referenced by a query are scanned, not entire rows

### Compression and Cardinality

Column cardinality (number of distinct values) is the primary driver of model size:

| Column Type | Cardinality | Compression | Impact |
|---|---|---|---|
| Boolean/flag | 2-5 values | Excellent (RLE) | Negligible size |
| Category/status | 10-100 values | Excellent (dictionary + RLE) | Negligible size |
| Date (day grain) | ~3,650 for 10 years | Good (dictionary) | Small |
| Integer ID (surrogate) | Millions | Moderate (dictionary) | Moderate |
| GUID/hash string | Millions (all unique) | Poor (dictionary with large dictionary size) | Large -- avoid in fact tables |
| Free-text/description | Millions (all unique) | Poor | Very large -- remove from Import models |

**Key rule:** Remove high-cardinality text columns from fact tables. Move them to dimension tables where the row count is lower.

### Relationship Materialization

Relationships in VertiPaq are materialized as join indexes:
- One-to-many relationships are stored as bitmaps mapping the "one" side key to "many" side row positions
- Referential integrity violations (orphan keys in fact tables with no matching dimension row) create a blank row in the dimension and consume additional memory
- Validate referential integrity: check "Assume Referential Integrity" on DirectQuery relationships; for Import, clean orphan keys in Power Query

### Encoding Types

| Encoding | Mechanism | When Used |
|---|---|---|
| **Value encoding** | Stores actual values (no dictionary); uses mathematical encoding | Low-cardinality numeric columns |
| **Hash encoding** | Dictionary maps values to integers; stores integers in column | String columns, high-cardinality numerics |
| **Run-Length Encoding (RLE)** | Compresses consecutive repeated values | Applied on top of value/hash encoding when beneficial |

VertiPaq chooses encoding automatically. You cannot override it, but you can influence it by reducing cardinality (bucketing, removing unnecessary precision).

### Query Execution: Storage Engine vs Formula Engine

Every DAX query is processed by two engines:

**Storage Engine (SE):**
- Scans compressed columnar data
- Multithreaded (uses all available cores)
- Produces result sets (datacaches) for the Formula Engine
- Handles: column scans, filters, simple aggregations (SUM, COUNT, MIN, MAX)
- Queries are cached -- repeated identical SE queries return instantly

**Formula Engine (FE):**
- Single-threaded
- Evaluates complex DAX logic: iterators, context transition, complex CALCULATE patterns
- Receives datacaches from SE and performs final computation
- The performance bottleneck for complex measures

**Optimization goal:** Push as much work as possible to the multithreaded Storage Engine. Minimize Formula Engine involvement by avoiding iterators on large tables, using native aggregations, and leveraging variables.

### Memory Architecture

- Each semantic model loads into memory when first queried
- Models are evicted from memory under memory pressure (LRU eviction)
- Premium/Fabric capacity guarantees dedicated memory; shared capacity models compete for resources
- Large model support (Premium): models exceeding physical memory can use paging to SSD
- Model memory = sum of all column data + relationship indexes + calculated tables + dictionary sizes

## DirectQuery Mechanics

In DirectQuery mode, Power BI does not store data. Instead, it generates queries against the source database at runtime.

### Query Generation

1. User interacts with a visual (slicer change, drill, page load)
2. Power BI generates a DAX query representing what the visual needs
3. The DAX engine translates the DAX query into one or more source-native queries (SQL for relational databases)
4. Source queries are sent to the data source via the appropriate connector
5. Results are returned and rendered in the visual

### Performance Characteristics

- **Latency:** Every interaction generates a round-trip to the source database. Typical response times: 1-10 seconds depending on source optimization.
- **Source load:** Power BI can generate dozens of concurrent queries for a single report page (one per visual). The source database must be sized to handle this.
- **Query folding:** Not all DAX patterns translate cleanly to SQL. Complex measures may result in suboptimal source queries.
- **Row limits:** DirectQuery visual queries are limited to 1 million rows returned by default.

### Optimization for DirectQuery

1. Create proper indexes on the source database for columns used in filters, aggregations, and joins
2. Use aggregation tables (Dual mode) to serve common queries from cache
3. Limit visuals per page to reduce concurrent source queries
4. Avoid complex DAX measures that don't fold well to SQL
5. Consider composite models: Import for dimensions, DirectQuery for large fact tables
6. Enable query caching in the Service to reduce source hits for identical queries

## Direct Lake Architecture

Direct Lake mode (GA March 2026) combines Import-like performance with DirectQuery-like freshness by reading Delta tables directly from OneLake.

### How Direct Lake Works

1. Data resides in OneLake as Delta/Parquet files (written by Data Factory, Spark, dataflows, or other Fabric workloads)
2. When a query arrives, the VertiPaq engine reads Parquet columnar data directly from OneLake into memory
3. Data is transcoded (converted from Parquet encoding to VertiPaq encoding) on demand
4. Once in memory, query performance matches traditional Import mode
5. When source Delta tables change, the in-memory cache is invalidated and fresh data is loaded on next query

### Framing

"Framing" is the process of capturing a snapshot of the Delta table's state:
- A frame is a set of Parquet files that represent the table at a point in time
- Frames are updated automatically or manually (no traditional "refresh" needed)
- The semantic model always reads from the current frame
- Automatic framing detects Delta log changes and updates frames transparently

### Fallback to DirectQuery

If Direct Lake cannot serve a query from memory (e.g., data exceeds memory, unsupported pattern), it falls back to DirectQuery against the SQL analytics endpoint:
- Fallback adds latency (similar to DirectQuery)
- Monitor fallback events via capacity metrics
- Reduce fallback by ensuring data fits in memory and avoiding patterns that force SQL execution

### Composite Models with Direct Lake

- Mix Direct Lake tables (from OneLake) with Import tables (from any connector)
- Enables enriching lakehouse data with small reference tables from Excel, SharePoint, or other sources
- Import tables are refreshed on schedule; Direct Lake tables update via framing

## Power BI Service Architecture

### Workspaces

Workspaces are organizational containers for all Power BI artifacts:
- Reports, semantic models, dataflows, datamarts, paginated reports
- Backed by Premium capacity, PPU, or shared (Pro) capacity
- Roles: Admin, Member, Contributor, Viewer
- Best practice: Assign Azure AD/Entra ID groups to workspace roles, not individual users

### Deployment Pipelines

Built-in ALM tool for promoting content across environments:
- 2-10 configurable stages (default: Dev, Test, Prod)
- Compare content between stages; deploy selectively
- Deployment rules for environment-specific parameters (connection strings, data sources)
- Automate via REST API for CI/CD integration
- Requires Premium capacity or PPU
- As of 2025: supports continuous deployment for Org Apps

### XMLA Endpoint

Read/write access to semantic models via the XMLA protocol (same protocol as SSAS):
- Enables third-party tools: Tabular Editor, ALM Toolkit, DAX Studio
- Supports scripted deployments via TMSL (Tabular Model Scripting Language)
- Programmatic partition management for incremental refresh
- Available in PPU and F64+ capacities

### Git Integration (PBIR Format)

- PBIR: JSON-based report format designed for source control (vs binary .pbix)
- Becoming default format as of April 2026
- Enables meaningful diffs and branch-based development
- Combine with Fabric git integration for full DevOps workflow
- TMDL (Tabular Model Definition Language) for semantic model definitions in source control

## Fabric Convergence

### Strategic Direction

Power BI is the analytics/visualization layer within Microsoft Fabric. The platform investment is increasingly Fabric-centric:
- OneLake as the universal data lake for all analytics data
- Direct Lake as the primary high-performance storage mode for Fabric
- Data Factory, Synapse, and Real-Time Intelligence produce data consumed by Power BI
- Unified security model spanning OneLake access control, workspace roles, and RLS

### What Fabric Adds Beyond Standalone Power BI

| Capability | Standalone Power BI | With Fabric |
|---|---|---|
| OneLake | Not available | Unified data lake for all analytics |
| Direct Lake | Not available | In-memory performance without import |
| Data Factory | Limited (dataflows only) | Full ETL/ELT orchestration |
| Synapse Data Engineering | Not available | Spark notebooks, lakehouses |
| Real-Time Intelligence | Streaming datasets (deprecating) | Full real-time analytics engine |
| Capacity billing | PPU per-user | F-SKU with Azure metering, pause/resume |

### Streaming Data (Migration)

Legacy streaming dataset types (push, streaming, PubNub) are deprecated and retiring October 2027. Migration path: Real-Time Intelligence in Fabric with Eventstreams and KQL databases.

## Embedded Analytics Architecture

### App-Owns-Data (Embed for Customers)

- Application authenticates via service principal (certificate-based, no MFA, no password expiry)
- Users do not need Power BI licenses
- Pay by capacity (F-SKU), not per user
- Best for ISVs and customer-facing applications
- Supports DirectQuery, Import, and Direct Lake models

### User-Owns-Data (Embed for Your Org)

- Users authenticate with their own Azure AD/Entra ID token
- Each user needs a Pro license (or F64+ capacity for viewers)
- Best for internal portals and intranets
- Simpler to implement but per-user licensing cost

### Embedding Implementation

- JavaScript SDK (`powerbi-client`) for iframe-based embedding
- REST APIs for programmatic report and semantic model management
- Row-Level Security enforced through effective identity tokens
- Capacity isolation: embed workloads run on dedicated capacity, not shared infrastructure

## Power BI Report Server (On-Premises)

On-premises reporting solution for organizations that cannot use cloud:
- Updated 3 times per year (vs monthly for cloud)
- Starting with SQL Server 2025, PBIRS replaces SSRS as default on-premises reporting
- Supports Power BI reports (.pbix) and paginated reports (.rdl)
- Does NOT support: Copilot, AI features, Direct Lake, dataflows, deployment pipelines, apps, Q&A, monthly feature updates
- Requires SQL Server Enterprise license with Software Assurance
