# SSAS Architecture

## VertiPaq (xVelocity) In-Memory Columnar Engine

The VertiPaq engine is the core of SSAS Tabular. It stores, compresses, and queries data using an in-memory columnar approach.

### Columnar Storage

Data is stored per column rather than per row. When a query references only 3 columns from a 50-column table, VertiPaq scans only those 3 columns, skipping the rest entirely. This contrasts with row-based storage where the engine must read all columns for every row.

### Dictionary Encoding

Each column maintains:
- **Dictionary** -- A sorted list of distinct values in the column
- **Bitmap index** -- References from each row to its dictionary entry

Storage cost is driven primarily by the number of distinct values (cardinality), not the total row count. A column with 10 distinct values across 100 million rows is far cheaper to store than a column with 10 million distinct values across 100 million rows.

### Compression

VertiPaq applies compression algorithms per column based on data distribution:
- **Value encoding** -- When all values in a segment are integers within a narrow range, stores as (value - minimum) using fewer bits
- **Hash encoding** -- Assigns integer codes to distinct values via the dictionary
- **Run-length encoding (RLE)** -- Compresses consecutive repeated values. Sort order matters: VertiPaq tries different sort orders (up to ~10 seconds per million rows during processing) to maximize RLE effectiveness

### Segments

Each column partition is divided into segments of approximately 8 million rows. Segments enable:
- Parallel scanning across CPU cores
- Segment elimination (skipping segments where min/max values fall outside the query filter)
- Independent compression per segment

### Memory Model

- All data resides in RAM for query processing
- Paging to disk is a fallback, not a design intent -- paged queries degrade by orders of magnitude
- Memory consumption = sum of all loaded model data + processing workspace + query workspace + caches
- The server caches query results in both Formula Engine and Storage Engine caches

### Memory Consumption Drivers

| Factor | Impact | Optimization |
|--------|--------|-------------|
| Column cardinality | Primary driver -- more distinct values = more memory | Split high-cardinality columns, remove unnecessary columns |
| Data type | Strings use more memory than integers | Use integer surrogate keys, avoid storing numbers as text |
| Column count | Every column consumes memory | Remove columns not needed for analysis, filtering, or relationships |
| Relationship columns | Foreign key columns consume memory | Use integer keys, not composite or string keys |
| Calculated columns | Stored in the model during processing | Replace with measures or source query calculations when possible |

### Dictionary Sizing

- Dictionary size is proportional to column cardinality
- Monitor via VertiPaq Analyzer (DAX Studio > Advanced > View Metrics)
- Columns with >1M distinct values are candidates for optimization or removal
- Splitting a datetime column into separate date and time columns can reduce combined cardinality by 90%+

## Storage Modes

### Tabular: VertiPaq (Import)

Default mode for Tabular models. All data imported into memory during processing.
- Full VertiPaq compression and columnar scanning
- Queries never hit the source database after processing
- Data freshness depends on processing schedule

### Tabular: DirectQuery

No data imported. DAX queries translated to SQL at runtime.
- Results always current (real-time from source)
- Scale limited by source database capacity, not SSAS memory
- Query performance depends on source database and network
- No VertiPaq compression benefits
- DAX function support is more limited (some functions cannot be translated to SQL)

### Tabular: Dual (Composite Models)

Tables can be individually set to Import or DirectQuery within the same model:
- Dimension tables in Import mode for fast filtering
- Large or frequently changing fact tables in DirectQuery for freshness
- The engine chooses the optimal mode per query based on which tables are involved

### Multidimensional: MOLAP

Copies source data into a proprietary multidimensional structure:
- Pre-computed aggregations at various granularities
- Queries never hit the source database
- Highest query performance of all Multidimensional storage modes
- Trade-off: data staleness between processing runs

### Multidimensional: ROLAP

No data copied. Aggregations stored as indexed views in the source database:
- Queries always go to the relational database
- Suitable for very large dimensions or real-time requirements
- Performance depends entirely on source database optimization
- Lower storage overhead on the SSAS server

### Multidimensional: HOLAP

Hybrid approach:
- Aggregations stored in SSAS multidimensional structure (like MOLAP)
- Detail data NOT copied -- detail-level queries hit the source database
- Fast summary queries with acceptable detail-query latency

## Processing Mechanics

### Processing Pipeline

```
Source Database
     │
     ▼
┌────────────┐
│ Data Read  │  Source query executes, rows streamed to SSAS
└─────┬──────┘
      │
      ▼
┌────────────┐
│ Encoding   │  Dictionary building, value/hash/RLE encoding per column
└─────┬──────┘
      │
      ▼
┌────────────┐
│ Compression│  Segment creation (~8M rows each), sort optimization
└─────┬──────┘
      │
      ▼
┌────────────┐
│ Index Build│  Hierarchy indexes, relationship indexes
└─────┬──────┘
      │
      ▼
┌────────────┐
│ Calculated │  Calculated columns evaluated row-by-row
│ Columns    │
└────────────┘
```

### Processing Types Detail

**Process Full:**
1. Drops existing data structures
2. Reads all data from source
3. Builds dictionaries, encodes, compresses
4. Builds all indexes
5. Evaluates all calculated columns
6. Object is unavailable during processing (unless using SSAS 2019+ online attach)

**Process Data + Process Index (recommended):**
1. Process Data: reads source data, builds dictionaries, encodes, compresses
2. Data becomes available for queries (without indexes)
3. Process Index: builds indexes in a separate step
4. Faster overall than Process Full; reduces server stress; data available sooner

**Process Add:**
1. Appends new rows to existing segments
2. Does NOT re-encode or re-compress existing data
3. New rows must not overlap with existing data
4. Useful for append-only fact tables (no updates or deletes)

### Partition Processing

- Partitions are the unit of processing for Tabular models
- Each partition maps to a source query that retrieves a subset of data (typically by date range)
- Partitions can be processed independently and in parallel
- Strategy: process only current/recent partitions on schedule; historical partitions only when source data changes

### Processing Resource Impact

- **Memory:** Processing requires additional memory beyond the final model size (source data buffer + encoding workspace). Budget 1.5-2x the final model size during processing
- **CPU:** Dictionary encoding and compression are CPU-intensive. Multiple partitions can process in parallel up to MaxParallelism setting
- **Source database:** Processing generates full table scans or large range queries. Schedule during low-activity windows
- **ExternalCommandTimeout:** Default 3,600 seconds (60 minutes). Increase for large partitions

## Connectivity

### Protocols and Client Libraries

| Protocol/Library | Type | Purpose |
|------------------|------|---------|
| XMLA | Protocol | XML for Analysis -- standard protocol for all SSAS communication (queries, processing, admin) |
| ADOMD.NET | Client library | Managed .NET library for querying SSAS |
| AMO/TOM | Client library | Analysis Management Objects / Tabular Object Model -- .NET library for admin operations |
| MSOLAP | OLE DB provider | Used by Excel, SSRS, and COM-based clients |
| TMSL | Scripting language | Tabular Model Scripting Language (JSON-based) for Tabular models at compatibility level 1200+ |

### XMLA Endpoint

XMLA is the universal protocol for SSAS communication:
- All queries (DAX, MDX), processing commands, and administrative operations go through XMLA
- Power BI Premium/Fabric exposes an XMLA endpoint that is protocol-compatible with SSAS
- XMLA endpoints support both read and write operations
- Tools like DAX Studio, SSMS, Tabular Editor, and ALM Toolkit all use XMLA

### Power BI Integration

- **Live Connection** -- Power BI connects to SSAS without importing data. All queries executed on the SSAS server
- **Composite models (2022+)** -- Power BI combines imported data with DirectQuery connections to SSAS. Enables extending an SSAS model with local calculations
- **XMLA endpoint** -- Power BI Premium/Fabric semantic models are accessible via XMLA, enabling the same tooling ecosystem as on-prem SSAS

## Security Model

### Roles

Security principals that define access:
- A user's effective permissions are the union of all roles they belong to
- Roles can be defined for read, read and process, or administrator access
- Roles contain Windows users/groups or Azure AD identities (depending on platform)

### Row-Level Security (RLS)

DAX filter expressions on tables within roles that restrict visible rows:

**Static RLS:**
- Hardcoded filters per role: `[Region] = "West"`
- Simple but requires a role per security boundary
- Does not scale well with many distinct access patterns

**Dynamic RLS (recommended):**
1. Create a security mapping table (UserEmail, AuthorizedScope)
2. Relate the security table to the data model
3. Define one role with DAX filter: `[UserEmail] = USERPRINCIPALNAME()`
4. Manage access by updating data, not roles
5. Scales to thousands of users with distinct access patterns

### Object-Level Security (OLS) -- 2022+

- Restricts visibility of entire tables or columns for specific roles
- Role members cannot see restricted objects in any tool or query
- Complements RLS: OLS hides structure, RLS filters data within visible structure

### Bidirectional Cross-Filtering for Security

- Required when RLS filters need to propagate across many-to-many relationships
- Enable "Apply security filter in both directions" on the relationship
- Test thoroughly: bidirectional filters can have unexpected performance and correctness implications

## Model Features

### Perspectives

- Subsets of a model showing only relevant tables, columns, and measures to user groups
- Simplify the browsing experience
- NOT a security mechanism -- all data remains accessible via direct queries

### Translations

- Metadata translations for column names, table names, measure names
- Support multilingual deployments without duplicating models
- Available in both Tabular and Multidimensional

### KPIs

- Define target values, status thresholds, and trend indicators for measures
- Both modes support KPIs
- Multidimensional adds trend assessment with separate visual indicators

### Actions (Multidimensional Only)

- User-initiated operations from a cube browser (open URL, run report, drill through)
- Not available in Tabular models

## Server Configuration

### Memory Settings

| Setting | Default | Purpose |
|---------|---------|---------|
| `Memory\LowMemoryLimit` | 65% | SSAS starts clearing caches |
| `Memory\TotalMemoryLimit` | 80% | Hard cap; may reject new requests |
| `Memory\HardMemoryLimit` | 80% | Absolute limit; operations fail |
| `Memory\VertiPaqPagingPolicy` | 1 | 0 = no paging (fail on OOM); 1 = page to disk |

**Sizing guidance:**
- All active models should fit in memory with 20-30% headroom
- Budget 1.5-2x model size during processing for workspace memory
- Monitor paging: if VertiPaq data pages to disk, queries degrade by orders of magnitude
- Standard edition limits a single model to 16 GB; Enterprise is unlimited
