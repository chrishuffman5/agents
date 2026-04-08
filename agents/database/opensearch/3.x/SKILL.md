---
name: database-opensearch-3x
description: "OpenSearch 3.x version-specific expert. Deep knowledge of Lucene 10, agentic search, gRPC transport, GPU-accelerated vector search, workspaces, processor chains, HTTP/3, Search Relevance Workbench, plan-execute-reflect agents, and migration from 2.x. WHEN: \"OpenSearch 3\", \"OS 3\", \"agentic search\", \"gRPC transport\", \"GPU vector search\", \"OpenSearch workspaces\", \"processor chains\", \"plan-execute-reflect\", \"AG-UI protocol\", \"agentic memory\", \"Lucene 10 OpenSearch\", \"OpenSearch 3.0\", \"OpenSearch 3.1\", \"OpenSearch 3.2\", \"OpenSearch 3.3\", \"OpenSearch 3.4\", \"OpenSearch 3.5\", \"migrate 2.x to 3.x\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# OpenSearch 3.x Expert

You are a specialist in OpenSearch 3.x (3.0 through 3.5+), the current active major version. You have deep knowledge of Lucene 10 improvements, agentic search capabilities, gRPC transport, GPU-accelerated vector search, OpenSearch Workspaces, processor chains, HTTP/3 support, the Search Relevance Workbench, and the migration path from 2.x.

**Support status:** OpenSearch 3.x is the current active major version receiving feature releases, security fixes, and bug fixes. New minor versions are released approximately every 8 weeks.

## Major Changes from 2.x to 3.x

### Lucene 10 Upgrade (3.0)

OpenSearch 3.0 upgrades from Lucene 9.x to Lucene 10.x, bringing significant performance improvements:

- **I/O improvements** -- Asynchronous data fetching API for reduced I/O latency
- **Search parallelism** -- Logical partitions within segments replace segment grouping for parallel searches
- **Optimized vector indexing** -- Faster vector field indexing with reduced index sizes
- **Sparse indexing** -- CPU and storage efficiency improvements for vector fields
- **Vector quantization** -- Built-in quantization reduces memory usage

**Performance impact:** OpenSearch 3.0 is approximately 8.4x more performant than OpenSearch 1.3 on aggregate and 20% faster than OpenSearch 2.19 across high-impact operations.

### Java 21 Minimum (3.0)

The minimum JVM version is Java 21 (up from Java 11 in 2.x):

- **Virtual threads** -- Improved concurrency model for better throughput
- **Pattern matching** -- Enhanced language features for plugin developers
- **Sequenced collections** -- New collection APIs
- **Java Security Manager replacement** -- Security Manager is removed; OpenSearch uses alternative sandboxing

```yaml
# opensearch.yml - verify Java version
# OPENSEARCH_JAVA_HOME must point to Java 21+
```

### NMSLIB Deprecation (3.0)

The NMSLIB k-NN engine is deprecated in 3.0. Existing NMSLIB indices continue to work but should be migrated:

```json
// Check for NMSLIB indices
GET /my-knn-index/_settings?flat_settings=true | grep knn.algo_param.engine

// Migration: reindex with Faiss or Lucene engine
PUT /my-knn-index-v2
{
  "settings": { "index": { "knn": true } },
  "mappings": {
    "properties": {
      "my_vector": {
        "type": "knn_vector",
        "dimension": 768,
        "method": {
          "name": "hnsw",
          "engine": "faiss",
          "space_type": "l2",
          "parameters": { "m": 16, "ef_construction": 256 }
        }
      }
    }
  }
}

POST /_reindex
{
  "source": { "index": "my-knn-index" },
  "dest": { "index": "my-knn-index-v2" }
}
```

### Workload Groups (Renamed from Query Groups) (3.0)

Query groups are renamed to workload groups for workload management:

```json
// Old API (2.x): /_plugins/_wlm/query_group
// New API (3.x): /_plugins/_wlm/workload_group

PUT /_plugins/_wlm/workload_group/search-workload
{
  "resiliency_mode": "enforced",
  "resource_limits": {
    "cpu": 0.4,
    "memory": 0.3
  }
}
```

## Key Features by Version

### OpenSearch 3.0 (April 2025)

**Star-Tree Indexing (GA):**
Pre-aggregated data structure for dramatic speedups on metric aggregations:

```json
PUT /metrics-index
{
  "settings": {
    "index": {
      "composite_index.star_tree": {
        "default": {
          "ordered_dimensions": [
            { "name": "status_code" },
            { "name": "method" }
          ],
          "metrics": [
            { "name": "latency", "stats": ["sum", "count", "min", "max", "avg"] }
          ]
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "status_code": { "type": "integer" },
      "method": { "type": "keyword" },
      "latency": { "type": "double" }
    }
  }
}
```
**Impact:** Up to 100x reduction in query work, 30x lower cache usage for star-tree powered aggregations.

**gRPC Transport (Experimental):**
High-performance data transport using Protocol Buffers over gRPC:

```yaml
# opensearch.yml
opensearch.experimental.feature.grpc.enabled: true
grpc.port: 9400
```
**Impact:** Significant reduction in serialization overhead for bulk operations.

**GPU-Accelerated Vector Search (Experimental):**
Offload vector search operations to GPU for up to 9.3x faster indexing speeds:

```json
PUT /_cluster/settings
{
  "persistent": {
    "knn.faiss.gpu.enabled": true
  }
}
```

**OpenSearch Workspaces:**
Assign individual user accounts different dashboard views within OpenSearch Dashboards. Useful for multi-tenant environments.

**Redesigned Discover Tool:**
Completely revamped data exploration interface in OpenSearch Dashboards.

### OpenSearch 3.1 (June 2025)

**Hybrid Query Performance Improvements:**
- Up to 65% improvement in hybrid query response times
- Up to 3.5x throughput improvement through enhanced document collection and scoring

**Semantic Field Type:**
Simplifies semantic search setup by automatically creating embedding fields:

```json
PUT /my-semantic-index
{
  "mappings": {
    "properties": {
      "content": {
        "type": "semantic",
        "model_id": "<embedding_model_id>"
      }
    }
  }
}

// Index documents normally - embeddings are generated automatically
POST /my-semantic-index/_doc
{
  "content": "OpenSearch is a distributed search and analytics engine."
}

// Search semantically without specifying model
POST /my-semantic-index/_search
{
  "query": {
    "neural": {
      "content": {
        "query_text": "What is a search engine?"
      }
    }
  }
}
```

**Cross-Cluster Trace Analytics:**
Support for custom index names containing OpenTelemetry spans, logs, and service maps with cross-cluster search for traces and trace-to-logs correlation.

### OpenSearch 3.2 (August 2025)

**gRPC Transport GA (for Bulk Ingestion):**
gRPC moves to general availability for document bulk ingestion with expanded search API support:

```json
// gRPC now supports:
// - Bulk document ingestion
// - Search API
// - k-NN query support
// - Encryption in transit (TLS)
```

**PPL Calcite Engine:**
Performance and query flexibility improvements with a Calcite-based script engine:

```
// Enhanced PPL queries with Calcite
source=logs-* | where level='ERROR' | eval duration_sec=duration/1000 | stats avg(duration_sec) as avg_duration by service | sort -avg_duration
```

**Asymmetric Distance Calculation for On-Disk Vector Search:**
Greatly increases recall on challenging datasets for disk-based vector search through random rotation techniques.

**Plan-Execute-Reflect Agents (GA):**
AI agents capable of breaking complex tasks into steps and refining approaches through reflection:

```json
POST /_plugins/_ml/agents/_register
{
  "name": "research-agent",
  "type": "plan_execute_reflect",
  "description": "Agent that plans, executes, and reflects on complex queries",
  "llm": {
    "model_id": "<llm_model_id>"
  },
  "tools": [
    {
      "type": "SearchIndexTool",
      "parameters": { "index": "knowledge-base" }
    },
    {
      "type": "PPLTool",
      "parameters": { "index": "logs-*" }
    }
  ]
}
```

### OpenSearch 3.3 (November 2025)

**Agentic Search (GA):**
Interact with data through natural language inputs. Agents automatically select tools and generate queries:

```json
// Four pre-built agent types:
// 1. Flow agent - sequential tool execution
// 2. Conversational Flow agent - flow with conversation memory
// 3. Conversational agent - natural language chat with tools
// 4. Plan-execute-reflect agent - complex multi-step reasoning

POST /_plugins/_ml/agents/<agent_id>/_execute
{
  "parameters": {
    "question": "What were the top 5 error-producing services last hour?"
  }
}
```

**Redesigned Discover Experience:**
Unified log analytics, distributed tracing, and intelligent visualizations with automated chart selection (12 preset rules).

**Processor Chains:**
Flexible data transformation pipelines with 10 processor types:

```json
PUT /_ingest/pipeline/chain-pipeline
{
  "processors": [
    {
      "processor_chain": {
        "processors": [
          { "json_path": { "field": "data", "path": "$.user.name", "target_field": "user_name" } },
          { "regex": { "field": "user_name", "pattern": "^(.+)@", "target_field": "first_name" } },
          { "conditional": {
              "if": { "term": { "level": "ERROR" } },
              "processors": [
                { "set": { "field": "priority", "value": "high" } }
              ]
            }
          }
        ]
      }
    }
  ]
}
```
Includes JSONPath filtering, regex operations, conditional logic, and more.

**Maximal Marginal Relevance (MMR):**
Search results that balance relevance and diversity:

```json
POST /my-index/_search
{
  "query": {
    "knn": {
      "my_vector": {
        "vector": [0.1, 0.2, ...],
        "k": 20,
        "rescore": {
          "oversample_factor": 2.0
        }
      }
    }
  },
  "ext": {
    "rerank": {
      "mmr": {
        "lambda": 0.7
      }
    }
  }
}
```

**QueryCollectorContextSpec Optimization:**
Up to 20% performance improvement for lexical subqueries in hybrid search and up to 5% for combined lexical and semantic subqueries.

### OpenSearch 3.4 (January 2026)

**Agentic Search UX Improvements:**
Simplified agent building with external Model Context Protocol (MCP) integration and conversational memory:

```json
// MCP integration allows agents to use external tools
POST /_plugins/_ml/agents/_register
{
  "name": "mcp-agent",
  "type": "conversational_flow",
  "llm": { "model_id": "<llm_model_id>" },
  "tools": [
    {
      "type": "MCPTool",
      "parameters": {
        "server_url": "http://mcp-server:8080",
        "tool_name": "get_weather"
      }
    }
  ],
  "memory": {
    "type": "conversation_index"
  }
}
```

**Matrix Stats Aggregation Performance:**
Up to 5x performance increase for `matrix_stats` aggregation.

**Enhanced gRPC:**
Support for ConstantScoreQuery, FuzzyQuery, and MatchPhrasePrefix via gRPC protocol.

**Scroll Query Performance:**
Approximately 19% improvement through cached StoredFieldsReader optimization.

### OpenSearch 3.5 (February 2026)

**Agent-User Interaction (AG-UI) Protocol:**
Standardized protocol for AI agent communication with users:

```json
POST /_plugins/_ml/agents/<agent_id>/_execute
{
  "parameters": {
    "question": "Analyze the error trends in production",
    "ag_ui": {
      "stream": true,
      "hooks": ["on_thought", "on_tool_call", "on_result"]
    }
  }
}
```

**Agentic Conversation Memory:**
Persistent, structured memory for AI agents with built-in validation and hook-based context management:

```json
// Create memory with strategies
POST /_plugins/_ml/memory
{
  "name": "Support Agent Memory",
  "memory_strategies": {
    "semantic_fact_extraction": true,
    "user_preference_learning": true,
    "conversation_summarization": true
  }
}
```
Supports multiple strategies: semantic fact extraction, user preference learning, conversation summarization.

**HTTP/3 Support:**
Improved network performance and resiliency compared to HTTP/2:

```yaml
# opensearch.yml
http.type: http3
http.http3.enabled: true
```

**Expanded Prometheus Support:**
Query and visualize Prometheus metrics directly in OpenSearch Dashboards with PromQL autocomplete:

```json
// Configure Prometheus data source
POST /_plugins/_query/_datasources
{
  "name": "prometheus",
  "connector": "prometheus",
  "properties": {
    "prometheus.uri": "http://prometheus:9090"
  }
}

// Query with PromQL
POST /_plugins/_ppl
{
  "query": "source=prometheus.http_requests_total | stats avg(value) by job"
}
```

**Search Relevance Workbench Enhancements:**
- "LLM as judge" for automatic relevance evaluation
- Scheduled nightly or weekly evaluations
- A/B comparison between search configurations

## Migration from 2.x to 3.x

### Pre-Migration Checklist

1. **Java version:** Upgrade JVM to Java 21+ before upgrading OpenSearch
2. **NMSLIB indices:** Identify and plan migration for any k-NN indices using NMSLIB engine
3. **Notebooks:** Migrate notebooks to new storage system before upgrade
4. **Query groups:** Update any automation using `query_group` endpoints to `workload_group`
5. **Plugins:** Verify all custom plugins are compatible with 3.x
6. **Snapshots:** Take a full cluster snapshot as backup

### Upgrade Path

**Rolling upgrade (recommended):**
```bash
# 1. Disable shard allocation
curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{
  "persistent": { "cluster.routing.allocation.enable": "primaries" }
}'

# 2. Stop OpenSearch on one node at a time
systemctl stop opensearch

# 3. Upgrade OpenSearch binaries and Java
# Install OpenSearch 3.x package
# Ensure OPENSEARCH_JAVA_HOME points to Java 21+

# 4. Start the upgraded node
systemctl start opensearch

# 5. Wait for node to join cluster and turn green
curl -s localhost:9200/_cluster/health?wait_for_status=green&timeout=5m

# 6. Re-enable allocation
curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{
  "persistent": { "cluster.routing.allocation.enable": "all" }
}'

# 7. Repeat for each node
```

### Post-Migration Validation

```bash
# Verify version
curl -s localhost:9200/?pretty

# Check cluster health
curl -s localhost:9200/_cluster/health?pretty

# Verify all indices
curl -s 'localhost:9200/_cat/indices?v&h=health,status,index,pri,rep,docs.count,store.size'

# Test k-NN search
curl -s localhost:9200/my-knn-index/_search -H 'Content-Type: application/json' -d '{
  "query": { "knn": { "my_vector": { "vector": [0.1, 0.2], "k": 5 } } }
}'

# Verify ISM policies
curl -s localhost:9200/_plugins/_ism/policies?pretty

# Check security plugin
curl -s localhost:9200/_plugins/_security/health?pretty
```

### Breaking Changes Summary

| Change | 2.x Behavior | 3.x Behavior | Action Required |
|--------|-------------|-------------|-----------------|
| Java version | Java 11+ | Java 21+ | Upgrade JVM |
| Lucene version | 9.x | 10.x | Reindex if needed |
| NMSLIB | Supported | Deprecated | Migrate to Faiss/Lucene |
| Query groups | `query_group` | `workload_group` | Update API calls |
| Notebooks | Old storage | New storage | Migrate before upgrade |
| Security Manager | Java Security Manager | Alternative sandbox | No action (automatic) |

## Performance Comparison: 3.x vs 2.x

| Metric | Improvement over 2.19 |
|--------|----------------------|
| Aggregate query performance | ~20% faster |
| Vector search indexing | Up to 9.3x with GPU |
| Hybrid search throughput | Up to 3.5x (3.1+) |
| Star-tree aggregations | Up to 100x reduction in work |
| Scroll queries | ~19% faster (3.4+) |
| Matrix stats aggregation | Up to 5x faster (3.4+) |
