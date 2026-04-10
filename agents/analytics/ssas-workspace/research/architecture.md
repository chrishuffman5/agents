# SSAS Architecture

## Overview

SQL Server Analysis Services (SSAS) is Microsoft's enterprise OLAP and data modeling platform. It operates in two distinct modes -- Tabular and Multidimensional -- each with its own engine, query language, and design paradigm. An SSAS instance is configured for one mode at install time and cannot serve both simultaneously.

---

## Tabular Mode

### VertiPaq (xVelocity) In-Memory Columnar Engine

The Tabular model uses the VertiPaq engine (also called xVelocity), an in-memory columnar storage engine that compresses and stores data column-by-column rather than row-by-row.

**Key characteristics:**
- **Columnar storage**: Data is stored per column, allowing the engine to scan only columns relevant to a query, skipping irrelevant data entirely
- **Dictionary encoding**: VertiPaq creates a dictionary of distinct values for each column and a bitmap index that references the dictionary. Storage cost is driven primarily by the number of distinct values (cardinality)
- **Compression**: VertiPaq applies different compression algorithms per column based on data distribution. It also tries different sort orders (up to ~10 seconds per million rows) to optimize compression
- **Segment-based storage**: Each column partition is divided into segments (typically ~8 million rows each), enabling parallel scanning
- **In-memory**: All data resides in RAM for query processing; paging to disk is a fallback, not a design intent

**Memory implications:**
- Column cardinality is the primary driver of memory consumption
- High-cardinality columns (e.g., transaction IDs, GUIDs) can consume disproportionate memory
- Splitting high-cardinality columns (e.g., separating date from time in a datetime column) can reduce memory usage by 90%+

### DirectQuery Mode

DirectQuery is an alternative to VertiPaq that does not import data. Instead, it translates DAX queries into SQL and sends them directly to the source relational database.

**Characteristics:**
- No data is cached in memory; results are always current
- Near-unlimited data scale (limited by the source database, not SSAS memory)
- Query performance depends on source database performance and network latency
- SSAS 2022+ supports parallel DirectQuery, sending multiple SQL queries simultaneously for a single DAX query
- SSAS 2025 introduces Horizontal Fusion, which reduces the number of SQL queries generated per DAX query

**When to use DirectQuery:**
- Data must always be real-time (no refresh lag acceptable)
- Data volume exceeds available memory
- Security must be enforced at the source database level

---

## Multidimensional Mode

### MOLAP, ROLAP, HOLAP Storage Modes

Multidimensional models organize data into cubes with dimensions, hierarchies, and measures. Three storage modes control where data and aggregations reside:

**MOLAP (Multidimensional OLAP):**
- Copies source data and stores aggregations in a proprietary multidimensional structure on disk
- Highly optimized for query performance -- queries never hit the source database
- Processing loads data from the source and builds the multidimensional structure
- Best for: query performance priority, data can tolerate refresh latency

**ROLAP (Relational OLAP):**
- Aggregations stored as indexed views in the source relational database
- No copy of source data stored in SSAS
- Queries always go to the relational database
- Best for: very large dimensions, real-time data requirements, memory constraints

**HOLAP (Hybrid OLAP):**
- Aggregations stored in a multidimensional structure (like MOLAP)
- Source data NOT copied -- detail-level queries hit the relational database
- Best for: fast summary queries with acceptable detail-query latency

### Aggregation Design

Aggregations are pre-computed summaries stored at various granularities to accelerate queries. The aggregation design wizard balances storage requirements against the percentage of queries that can be satisfied from pre-computed results. There is always a tradeoff between disk/memory usage and query performance.

---

## DAX (Data Analysis Expressions)

DAX is the query and formula language for Tabular models. It superficially resembles Excel formulas but operates on tables and columns rather than cells.

### Core Concepts

**Calculated Columns:**
- Evaluated row-by-row during model processing
- Results stored in the model (consume memory)
- Have access to row context (current row values)

**Measures:**
- Evaluated at query time based on the filter context
- Not stored; computed dynamically
- The primary mechanism for aggregations and business logic

### Row Context vs. Filter Context

**Row Context:**
- Exists during iteration (calculated columns, iterator functions like SUMX)
- Represents "the current row"
- Does NOT automatically propagate through relationships

**Filter Context:**
- The set of active filters constraining which rows are visible to a calculation
- Set by slicers, filters, row/column axes in reports
- Propagates through relationships automatically (from one-side to many-side)

### CALCULATE

CALCULATE is the most important DAX function. It:
1. Evaluates an expression in a modified filter context
2. Converts row context to filter context (context transition)
3. Can add, remove, or replace filters

Example: `CALCULATE(SUM(Sales[Amount]), Product[Color] = "Red")` evaluates the sum of sales amount, but only for red products, regardless of the existing filter context on color.

---

## MDX (Multidimensional Expressions)

MDX is the query language for Multidimensional models. It navigates the cube's dimensional structure.

### Core Concepts

**Members:** Individual elements within a dimension hierarchy (e.g., `[Date].[Calendar].[2024]`)

**Tuples:** A coordinate in the cube formed by selecting one member from each of one or more dimensions. Written in parentheses: `([Date].[Calendar].[2024], [Product].[Category].[Bikes])`

**Sets:** Ordered collections of tuples, written in curly braces: `{[Product].[Category].[Bikes], [Product].[Category].[Clothing]}`

**Calculated Members:** Virtual members defined with the WITH keyword that evaluate an MDX expression. Used for custom aggregations, ratios, and time intelligence.

---

## Processing and Refresh

### Processing Types

| Type | Description | Use Case |
|------|-------------|----------|
| Process Full | Drops existing data, reloads everything, rebuilds indexes | Initial load, schema changes |
| Process Data | Loads data only, no index rebuild | Followed by Process Index separately |
| Process Index | Rebuilds indexes and aggregations only | After Process Data |
| Process Add | Appends new rows without reprocessing existing data | Incremental loads (new data only, no updates) |
| Process Update | Reloads data and updates aggregations | When rows have been modified |
| Process Clear | Drops all data from the object | Before a clean reload |

### Partition Strategies

- Divide fact tables by time period (e.g., monthly partitions)
- Process only recent partitions on a regular schedule
- Process historical partitions only when source data changes
- Best practice: Process Data + Process Index separately (faster than Process Full, reduces server stress, makes data available sooner)
- Target ~100K-500K rows per partition for optimal processing speed

---

## Connectivity

### Protocols and Client Libraries

| Protocol/Library | Description |
|------------------|-------------|
| **XMLA** | XML for Analysis -- the standard protocol for communicating with SSAS. All commands (queries, processing, admin) go through XMLA |
| **ADOMD.NET** | Managed .NET client library for querying SSAS. Used by .NET applications |
| **AMO (Analysis Management Objects)** | Managed .NET library for administrative operations (create/alter/delete objects) |
| **MSOLAP (OLE DB for OLAP)** | OLE DB provider. Used by Excel, SSRS, and other COM-based clients |
| **TMSL** | Tabular Model Scripting Language (JSON-based). Commands for Tabular models at compatibility level 1200+ |

### Power BI Integration

- Power BI can connect to SSAS via Live Connection (no data import)
- Power BI Premium/Fabric exposes an XMLA endpoint that is protocol-compatible with SSAS
- SSAS 2022+ supports composite models: Power BI can combine imported data with DirectQuery to an SSAS model
- XMLA endpoints support both read and write operations

---

## Platform Variants

### On-Premises SSAS
- Full feature set (Tabular + Multidimensional)
- Self-managed infrastructure (RAM, CPU, storage)
- Licensed through SQL Server editions (Standard limits model to 16 GB RAM; Enterprise is unlimited)

### Azure Analysis Services (AAS)
- Tabular mode only (no Multidimensional)
- Managed PaaS service with SKU-based pricing
- Scale up/down and pause/resume capabilities
- Same XMLA protocol as on-prem
- Microsoft recommends migrating AAS to Power BI/Fabric

### Power BI Premium / Fabric Semantic Models
- Tabular engine (same VertiPaq core)
- Superset of AAS features
- Memory limit per model (not per server)
- Better parallel refresh capabilities
- XMLA endpoint for external tool access
- Microsoft's strategic direction for all new semantic model development

---

## Additional Model Features

### Perspectives
- Subsets of a model that show only relevant tables, columns, and measures to specific user groups
- Not a security mechanism -- all data is still accessible via queries
- Simplify the browsing experience for end users

### Translations
- Metadata translations for column names, table names, measure names
- Support multilingual deployments without duplicating models
- Available in both Tabular and Multidimensional

### KPIs (Key Performance Indicators)
- Define target values, status thresholds, and trend indicators for measures
- Both modes support KPIs; Multidimensional adds trend assessment with separate visual indicators

### Actions (Multidimensional only)
- User-initiated operations triggered from a cube browser (e.g., open a URL, run a report, drill through)
- Not available in Tabular models

---

## Security

### Roles
- Security principals that define who can access the model and what they can see
- A user's effective permissions are the union of all roles they belong to

### Row-Level Security (RLS)
- DAX expressions on table roles that filter rows visible to role members
- **Static RLS**: Hardcoded filters per role (e.g., `[Region] = "West"`)
- **Dynamic RLS**: Data-driven filters using `USERPRINCIPALNAME()` to look up the current user in a security mapping table

Dynamic RLS pattern:
1. Create a security mapping table (UserEmail, AuthorizedRegion)
2. Create a relationship between the security table and the data model
3. Define a single role with a DAX filter: `[UserEmail] = USERPRINCIPALNAME()`
4. Manage access by updating data rather than creating/modifying roles

### Object-Level Security (OLS)
- Restricts visibility of entire tables or columns to specific roles
- Members of a role with OLS restrictions cannot see the restricted objects in any query or tool
- Available in SSAS 2022+ and Power BI

### Bidirectional Cross-Filtering for RLS
- Required when security filters need to propagate across many-to-many relationships
- Enable "Apply security filter in both directions" on the relationship
