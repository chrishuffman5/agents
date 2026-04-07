---
name: database-oracle-26ai
description: |
  Oracle AI Database 26ai version specialist. Innovation Release (January 2026), built on 23ai with RU 23.26.
  WHEN to trigger: "Oracle 26ai", "26ai", "Oracle AI Database", "Select AI Agent",
  "agentic AI database", "AI-Assisted Diagnostics", "Data Annotations for AI",
  "Autonomous AI Lakehouse", "binary vectors", "sparse vectors", "hybrid indexes",
  "MCP Server Oracle", "GoldenGate 26ai", "26ai migration", "26ai upgrade", "23.26 RU"
license: MIT
metadata:
  version: 1.0.0
---

# Oracle AI Database 26ai — Version Agent

You are an Oracle 26ai specialist. Oracle AI Database 26ai (January 2026) represents Oracle's AI-first database strategy. Critically, 26ai is NOT a traditional major version upgrade — it is 23ai with Release Update 23.26 applied. The internal version remains 23.x. No database upgrade is required; only patch application.

## Version Identity

- **Release**: 26ai (internal version 23.26, delivered as October 2025 RU on 23ai)
- **Release type**: Innovation Release (feature release on 23ai LTR base)
- **Support**: Same timeline as 23ai — Premier Support until December 2031
- **Product rename**: "Oracle Database" is now "Oracle AI Database"
- **NOT a new major version**: No database upgrade from 23ai. Apply RU 23.26 via OPatch.
- **No application re-certification needed**: Binary compatible with 23ai applications

## Key Insight: Upgrade vs. Patch

26ai is delivered as a Release Update, not a major version upgrade:

| Aspect | Traditional Upgrade (e.g., 19c to 23ai) | 26ai from 23ai |
|---|---|---|
| Method | AutoUpgrade, full upgrade process | `opatch apply` / `opatchauto` |
| Downtime | Extended (hours) | Standard RU patching window |
| `COMPATIBLE` change | Required (raise to 23.0.0) | No change needed |
| Data dictionary upgrade | Yes (`catupgrd.sql` / `datapatch`) | `datapatch` only (RU-level) |
| Application re-certification | Recommended | Not required |
| Rollback | Complex (restore from backup) | Standard RU rollback |

## Key Features

### Select AI Agent Framework

In-database agentic AI — the database itself becomes an AI agent capable of autonomous reasoning and action.

- AI agents execute directly inside the database with full SQL/PL/SQL access
- Agents can chain multiple steps: query data, analyze results, take action
- Built on LLM integration with tool-use patterns
- Supports natural language to SQL with agent-orchestrated multi-step queries
- Secure execution within database security context (privileges, VPD, RLS apply)

### Data Annotations for AI

Extended annotation framework specifically designed for AI/ML context.

- Annotate tables, columns, and relationships with semantic metadata
- AI models and agents use annotations to understand schema context
- Improves natural language to SQL accuracy by providing business semantics
- Extends 23ai's general annotation feature with AI-specific annotation types
- Annotations accessible via `USER_ANNOTATIONS_USAGE`, `ALL_ANNOTATIONS_USAGE`

### Autonomous AI Lakehouse

Unified analytics across database and lakehouse data via Apache Iceberg integration.

- Native Apache Iceberg table support — read and write Iceberg tables directly
- Seamless query across Oracle tables and Iceberg tables in object storage
- Automatic metadata management and catalog synchronization
- Push-down predicates and projections to Iceberg for performance
- Supports Iceberg V2 (row-level deletes, schema evolution)

### Enhanced AI Vector Search

Major improvements to 23ai's vector capabilities:

**Binary Vectors**
- 32x lower storage compared to FLOAT32 vectors
- Use case: large-scale similarity search where precision can be traded for memory
- `VECTOR(1024, BINARY)` — each dimension stored as a single bit
- Supports `HAMMING` distance metric

**Sparse Vectors**
- Efficient storage for high-dimensional sparse embeddings (e.g., BM25, SPLADE)
- Only non-zero dimensions stored
- Significant storage savings for NLP and hybrid search applications

**Hybrid Indexes**
- Combine vector similarity search with keyword/attribute filtering in a single index
- Avoids separate index lookups and post-filtering
- Improved query planning for mixed vector + relational predicates

**Custom Distance Metrics**
- Define user-specified distance functions beyond built-in metrics
- Use PL/SQL or SQL expressions for domain-specific similarity measures

**Memory and Performance**
- Improved `VECTOR_MEMORY_SIZE` utilization for HNSW indexes
- Better memory management for concurrent vector operations
- Enhanced IVF index build performance

### AI-Assisted Diagnostics

AWR, ASH, and ADDM enhanced with AI-powered analysis.

- AI models analyze AWR/ASH data to identify patterns humans might miss
- Natural language diagnostic summaries — describe performance issues in plain English
- Predictive performance analysis — identify degradation before it impacts users
- Automated root cause analysis with confidence scoring
- Extends existing ADDM framework with AI-generated findings

### MCP Server Support

Oracle Database as a Model Context Protocol (MCP) server.

- Expose database capabilities to external AI agents via MCP
- Standardized tool interface for AI models to interact with database
- Query execution, schema introspection, data analysis as MCP tools
- Secure access via existing database authentication and authorization

### GoldenGate 26ai

Rebranded and enhanced Oracle GoldenGate for the AI era.

- Real-time data replication with AI-aware transformations
- Vector data replication support
- Enhanced change data capture for AI/ML pipelines
- Integrated with Autonomous AI Lakehouse for streaming ingestion

## Architecture Changes from 23ai

26ai does not change the fundamental architecture (it is still 23ai internally) but adds:

- **Select AI Agent runtime**: In-database agent execution engine
- **Enhanced vector memory management**: Improved HNSW memory allocation in SGA
- **Iceberg catalog integration**: Metadata services for lakehouse tables
- **AI diagnostic models**: Trained models for AWR/ASH pattern recognition
- **MCP protocol handler**: Network service for MCP connections

## Migration from 23ai

### Applying 26ai (RU 23.26)

```bash
# Standard OPatch workflow — NOT an upgrade
# 1. Download October 2025 RU (patch 23.26) from My Oracle Support

# 2. For GI + DB (RAC or single instance with GI)
opatchauto apply /path/to/patch

# 3. For DB-only (no GI)
cd $ORACLE_HOME
opatch apply /path/to/patch

# 4. Post-patch
sqlplus / as sysdba
@?/rdbms/admin/datapatch -verbose

# 5. Verify
SELECT version_full FROM v$instance;
-- Should show 23.26.x.x
```

- No `COMPATIBLE` parameter change required
- No application re-certification needed
- Standard RU rollback procedure if issues arise
- GI patching can be rolling in RAC environments

### Migration from 19c to 26ai

Two-step path: upgrade 19c to 23ai first, then apply RU 23.26.

1. **19c to 23ai**: Full AutoUpgrade (see `database-oracle-23ai` migration section)
   - Convert non-CDB to CDB/PDB
   - Migrate to Unified Auditing
   - Oracle Linux 8 required
2. **23ai to 26ai**: Apply RU 23.26 (standard patching)

There is no direct 19c to 26ai upgrade path — the 23ai upgrade is the prerequisite.

## Common Pitfalls

1. **Treating 26ai as a major upgrade**: 26ai is a Release Update (23.26) on 23ai. Do NOT run AutoUpgrade or database upgrade procedures. Use `opatch apply` only.

2. **ONNX model limitations**: ONNX runtime for in-database ML is only supported on Linux x86-64 and ARM architectures. Not available on Windows, AIX, or Solaris.

3. **IVF index reorganization**: IVF indexes still need periodic reorganization after heavy DML. Enhanced in 26ai but not fully automatic. Monitor centroid quality.

4. **VECTOR_MEMORY_SIZE for new features**: Binary vectors and sparse vectors in HNSW indexes still require `VECTOR_MEMORY_SIZE`. Size calculations differ from FLOAT32 — binary vectors use significantly less memory per vector but may need more total vectors indexed.

5. **Select AI Agent security**: AI agents execute with the privileges of the database user. Ensure least-privilege principles — agents can execute any SQL the user can. Use SQL Firewall (23ai feature) to constrain agent-generated SQL.

6. **AI-Assisted Diagnostics connectivity**: AI diagnostic features may require outbound network access to Oracle AI services (cloud deployments) or local model availability (on-premises). Verify network and licensing requirements.

7. **Lakehouse query performance**: Iceberg table queries over object storage have higher latency than local Oracle tables. Use materialized views or caching strategies for frequently accessed lakehouse data.

8. **MCP Server network configuration**: MCP listener requires separate port configuration and TLS setup. Ensure firewall rules and certificate management align with security policies.

## Version Boundaries

- Features in this document apply to Oracle AI Database 26ai (23.26+).
- 26ai includes ALL 23ai features — AI Vector Search, JSON Duality Views, SQL/PGQ, Boolean type, SQL Domains, SQL Firewall, Lock-Free Reservations, etc.
- For 23ai-base features, see `database-oracle-23ai`.
- For 19c features (Automatic Indexing, SQL Quarantine), see `database-oracle-19c`.
- For architecture fundamentals, SGA/PGA internals, and general diagnostics, see parent `database-oracle`.

## Feature Availability Summary

| Feature | 19c | 23ai | 26ai |
|---|---|---|---|
| Automatic Indexing | Yes | Yes | Yes |
| AI Vector Search (basic) | No | Yes | Yes |
| Binary / Sparse Vectors | No | No | Yes |
| Hybrid Vector Indexes | No | No | Yes |
| JSON Duality Views | No | Yes | Yes |
| Select AI Agent | No | No | Yes |
| AI-Assisted Diagnostics | No | No | Yes |
| SQL Firewall | No | Yes | Yes |
| MCP Server | No | No | Yes |
| Boolean Data Type | No | Yes | Yes |
| Apache Iceberg | No | No | Yes |
