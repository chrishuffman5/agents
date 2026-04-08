# Neo4j Architecture Reference

## Native Graph Storage Engine

Neo4j is a native graph database, meaning it stores and processes graph data using structures optimized specifically for graphs rather than mapping to relational tables or document stores.

### Index-Free Adjacency

The defining characteristic of Neo4j's storage engine is **index-free adjacency**. Each node physically stores direct pointers (file offsets) to its adjacent relationships and neighboring nodes:

- Traversing a relationship is an O(1) pointer lookup, not an index lookup or join
- Traversal cost is proportional to the subgraph visited, not the total graph size
- A graph with 1 billion nodes traverses a 3-hop path at the same speed as a graph with 1 thousand nodes (assuming the same local neighborhood)

**How it works at the storage level:**
```
Node record (fixed-size, ~15 bytes):
  ├── inUse flag (1 bit)
  ├── first relationship ID (pointer to relationship chain)
  ├── first property ID (pointer to property chain)
  ├── label field (inline or pointer to label store)
  └── extra flags

Relationship record (fixed-size, ~34 bytes):
  ├── first node ID
  ├── second node ID
  ├── relationship type
  ├── first node's previous relationship ID  ─┐ doubly-linked list
  ├── first node's next relationship ID       ─┘ for first node
  ├── second node's previous relationship ID  ─┐ doubly-linked list
  ├── second node's next relationship ID      ─┘ for second node
  └── first property ID
```

Each node maintains a doubly-linked list of its relationships. When you traverse from Node A to its neighbors, Neo4j:
1. Reads Node A's record (O(1) -- computed from node ID * record size)
2. Follows the first-relationship pointer
3. Walks the relationship chain, following next-relationship pointers
4. For each relationship, reads the target node via the stored node ID

No index lookup is needed at any step. This is fundamentally different from relational databases where JOINs require index lookups or hash/sort operations.

### Store File Layout (Record Format)

The traditional record store format uses separate files for each entity type:

| Store File | Record Size | Contents |
|---|---|---|
| `neostore.nodestore.db` | ~15 bytes | Node records: labels, first relationship, first property |
| `neostore.relationshipstore.db` | ~34 bytes | Relationship records: start/end node, type, chain pointers |
| `neostore.propertystore.db` | ~41 bytes | Property records: key, value (inline or pointer), chain pointer |
| `neostore.propertystore.db.strings` | Variable | Long string values (strings > 15 bytes) |
| `neostore.propertystore.db.arrays` | Variable | Array property values |
| `neostore.labeltokenstore.db` | Variable | Label name strings |
| `neostore.relationshiptypestore.db` | Variable | Relationship type name strings |
| `neostore.schemastore.db` | Variable | Index and constraint definitions |

**Fixed-size records** enable direct-computed lookups:
```
Node record location = node_id * record_size + header_offset
```
This means any node can be read in O(1) without an index.

### Block Storage Format (5.14+, Default in 5.26+)

The block storage format is a fundamental redesign that groups related data into **8KB blocks** aligned with modern NVMe page sizes and OS memory pages:

- **Co-location**: A node, its properties, and its most frequently accessed relationships are stored in the same block or adjacent blocks
- **Reduced I/O**: Traversing a node and reading its properties often requires a single page read instead of multiple random reads across separate store files
- **Better compression**: Related data in the same block compresses more effectively
- **Long token names**: Supports label names, property keys, and relationship type names up to 16,383 characters (GQL identifier max length)
- **Performance**: Significantly better read performance for most workloads, especially OLTP traversals

**Migration requirement**: Existing databases must be migrated from record format to block format. This is a one-way migration -- block format databases cannot be reverted to record format.

```bash
# Check current store format
neo4j-admin database info neo4j

# Migrate to block format (offline operation)
neo4j-admin database migrate neo4j --to-format=block
```

## Page Cache

The page cache is Neo4j's primary caching layer, holding graph store pages in memory:

### How It Works

- Store files are divided into fixed-size **pages** (default 8KB, aligned with block format)
- The page cache loads pages from disk on demand and evicts using an **LRU-K** (Least Recently Used with frequency tracking) policy
- Pages are **pinned** during active reads/writes to prevent eviction
- **Cache misses** trigger synchronous disk reads, which dominate query latency on large graphs

### Sizing

```
# neo4j.conf
server.memory.pagecache.size=16g
```

**Sizing rules:**
1. Ideal: page cache >= total store size on disk (entire graph fits in memory)
2. Minimum: page cache covers the hot working set (frequently traversed subgraph)
3. Check store size: `CALL apoc.monitor.store()` or examine data directory size

**Calculating store size:**
```bash
# Linux/macOS
du -sh /var/lib/neo4j/data/databases/neo4j/

# Or via Cypher (requires APOC)
CALL apoc.monitor.store() YIELD totalStoreSize
RETURN apoc.number.format(totalStoreSize) AS storeSize;
```

### Page Cache Hit Ratio

The single most important performance metric. A hit ratio below 95% on an OLTP workload indicates the page cache is too small:

```cypher
-- Check page cache metrics via JMX (where available)
CALL dbms.queryJmx('org.neo4j:instance=kernel#0,name=Page cache')
YIELD attributes
RETURN attributes;
```

## Transaction Log

Neo4j uses a write-ahead transaction log for durability and recovery:

### Transaction Log Mechanics

1. **Pre-write**: Before modifying store files, the transaction is written to the transaction log
2. **Commit**: The transaction log entry is fsynced to disk. The transaction is now durable.
3. **Store update**: Modified pages in the page cache are marked dirty
4. **Checkpoint**: Dirty pages are periodically flushed to store files. After checkpoint, corresponding log entries can be pruned.

### Transaction Log Files

```
data/transactions/neo4j/
├── neostore.transaction.db.0    # Transaction log files
├── neostore.transaction.db.1    # Rotated when reaching size threshold
├── neostore.transaction.db.2
└── ...
```

**Key configuration:**
```properties
# neo4j.conf

# Maximum transaction log size before rotation (default 256MB)
db.tx_log.rotation.size=256m

# Transaction log retention policy
db.tx_log.rotation.retention_policy=2 days

# Checkpoint interval (default 15 minutes)
db.checkpoint.interval.time=15m

# Checkpoint trigger by transaction count
db.checkpoint.interval.tx=100000
```

### Recovery Process

On startup after an unclean shutdown:
1. Neo4j reads the last checkpoint position from the store
2. Replays all transaction log entries after that checkpoint
3. Recovery is automatic and requires no manual intervention
4. Recovery time depends on the number of transactions since the last checkpoint

## Raft Consensus for Clustering

Neo4j clusters use the Raft distributed consensus protocol to maintain consistency across primary servers.

### Raft Fundamentals

- **Leader**: One primary is elected leader. All write transactions go through the leader.
- **Followers**: Remaining primaries replicate the leader's transaction log.
- **Log replication**: The leader appends transactions to its log and replicates to followers. A transaction is committed when a majority (quorum) acknowledges.
- **Leader election**: If followers detect leader failure (no heartbeat within election timeout), they initiate an election. The candidate with the most up-to-date log wins.

### Write Transaction Flow in a Cluster

```
Client (write) ─────────────────┐
                                 │
                                 ▼
                          ┌─────────────┐
                          │   Leader     │
                          │  (Primary)  │
                          └──────┬──────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │ Replicate        │ Replicate         │ Replicate
              ▼                  ▼                   ▼
      ┌──────────────┐  ┌──────────────┐   ┌──────────────┐
      │  Follower 1  │  │  Follower 2  │   │  Secondary   │
      │  (Primary)   │  │  (Primary)   │   │ (Read Replica)│
      └──────────────┘  └──────────────┘   └──────────────┘
           │ ACK              │ ACK               │ (async)
           └──────────┬──────┘                    │
                      ▼                           │
              Quorum reached                      │
              (2 of 3 primaries)                  │
              Transaction committed               │
                                                  ▼
                                          Async catch-up
```

### Read Replica (Secondary Server) Synchronization

- Secondary servers subscribe to the transaction log stream from primaries
- They apply transactions asynchronously (eventual consistency)
- Read queries on secondaries may see slightly stale data (typically milliseconds)
- For causal consistency, use **bookmarks**: the client passes a bookmark from a write transaction to a subsequent read, ensuring the read sees at least that write

```python
# Causal consistency with bookmarks
with driver.session() as session:
    # Write
    result = session.execute_write(lambda tx: tx.run("CREATE (n:Test)"))
    bookmark = session.last_bookmarks()

    # Read with bookmark -- guaranteed to see the write
    with driver.session(bookmarks=bookmark) as read_session:
        result = read_session.execute_read(lambda tx: tx.run("MATCH (n:Test) RETURN count(n)"))
```

### Cluster Configuration

```properties
# neo4j.conf for a primary server

# Cluster member discovery
server.cluster.system_database_mode=PRIMARY
dbms.cluster.discovery.type=LIST
dbms.cluster.discovery.endpoints=server1:5000,server2:5000,server3:5000

# Raft timeouts
dbms.cluster.raft.leader_election_timeout=7s

# Minimum core cluster size for safety
dbms.cluster.minimum_initial_system_primaries_count=3
```

## Property Storage

Properties are stored in a linked list attached to each node or relationship:

### Property Record Layout

Each property record holds up to 4 property blocks. A property block stores:
- Property key (reference to property key token store)
- Property value (inline for small values, or pointer to string/array store)
- Next property record pointer (for property chains longer than 4)

**Inline value thresholds (record format):**
| Type | Inline If |
|---|---|
| Boolean | Always inline |
| Byte, Short, Int, Long | Always inline |
| Float, Double | Always inline |
| Char | Always inline |
| Short string | <= 15 bytes (depends on encoding) |
| Short array | <= 24 bytes |
| Point | 2D inline, 3D uses external store |

Longer strings and arrays are stored in the dynamic string/array stores with 120-byte records chained together.

### Property Key Tokens

Property key names (e.g., "name", "age", "createdAt") are stored once in the property key token store. Each property record references the key by token ID, not by string. This makes property key comparison a fast integer comparison.

## Label Storage

### Label Token Store

Similar to property keys, label names are tokenized. Each label is stored once in the label token store with a unique integer ID.

### Node-Label Mapping

- Nodes with up to ~3-4 labels store label IDs inline in the node record
- Nodes with more labels use a separate **label store** with a linked list of label arrays
- The **token lookup index** (enabled by default) provides the reverse mapping: given a label, find all nodes with that label

## Relationship Storage

### Relationship Chain (Record Format)

Each node maintains a doubly-linked list of all its relationships:

```
Node A
  └── first_rel ──> Rel1 ──> Rel2 ──> Rel3 ──> null
                     │         │         │
                    (A→B)     (A→C)     (D→A)   ← direction encoded in record
```

For nodes with many relationships (dense nodes), Neo4j uses a **relationship group** structure that partitions the chain by relationship type:

```
Dense Node A
  └── RelGroup(KNOWS) ──> Rel1 ──> Rel2
  └── RelGroup(WORKS_AT) ──> Rel3
  └── RelGroup(LIVES_IN) ──> Rel4
```

The dense node threshold is configurable:
```properties
# neo4j.conf -- default is 50
db.relationship_grouping_threshold=50
```

This optimization allows filtering by relationship type without scanning the entire relationship chain.

## Query Compilation Pipeline

Neo4j compiles Cypher queries through a multi-stage pipeline:

### Stage 1: Parsing

The Cypher query string is tokenized and parsed into an **Abstract Syntax Tree (AST)**:
- Lexical analysis: tokenize keywords, identifiers, literals, operators
- Syntactic analysis: build AST according to Cypher grammar
- Errors at this stage: syntax errors (misspelled keywords, unclosed parentheses)

### Stage 2: Semantic Analysis

The AST undergoes semantic checking:
- Variable scope validation (are all referenced variables defined?)
- Type checking (are operations valid for the types involved?)
- Label/type resolution
- Errors at this stage: unknown variables, type mismatches

### Stage 3: AST Rewriting and Normalization

The AST is optimized and normalized:
- Predicate pushdown: move WHERE filters as close to the scan/expand as possible
- Pattern normalization: rewrite equivalent patterns into canonical form
- Constant folding: evaluate constant expressions at compile time
- Subquery inlining where possible

### Stage 4: Logical Planning

The normalized AST is converted into a **logical plan** -- a tree of logical operators:
- Select access methods (index seek, label scan, etc.)
- Choose join strategies (hash join, nested loop, apply)
- Apply cardinality estimation using database statistics
- The **cost-based planner** evaluates multiple candidate plans and selects the lowest-cost one

### Stage 5: Physical Planning (Slotted/Pipelined Runtime)

The logical plan is compiled into a **physical execution plan** for one of the available runtimes:

| Runtime | Characteristics | Best For |
|---|---|---|
| **Pipelined** | Streaming, morsel-driven, parallel execution within operators | Default for most queries; best throughput |
| **Slotted** | Row-at-a-time interpretation | Fallback for queries not supported by pipelined |
| **Interpreted** | Simple row-at-a-time | Legacy fallback |

The pipelined runtime uses a **morsel-driven parallelism** model:
- Data is divided into morsels (batches of rows)
- Worker threads process morsels in parallel
- Operators are fused into pipelines that process morsels without materializing intermediate results

### Stage 6: Execution

The physical plan is executed against the store:
- Operators pull rows from child operators (demand-driven / volcano model in slotted; push-based in pipelined)
- Results stream to the client as they are produced
- Execution can be profiled with `PROFILE` to see actual row counts and db hits per operator

### Query Caching

Compiled query plans are cached to avoid re-compilation:
```properties
# neo4j.conf
# Query cache size (number of cached plans)
server.db.query_cache_size=1000
```

- Cache key: parameterized query text (another reason to always use parameters)
- String-concatenated queries each get their own cache entry, wasting cache space
- The first execution of a query incurs compilation cost; subsequent executions reuse the cached plan

## Memory Architecture

### JVM Heap

Neo4j runs on the JVM. The heap is used for:
- Query execution state (intermediate results, sorting buffers)
- Transaction state
- Query plan cache
- Internal data structures

```properties
# neo4j.conf
server.memory.heap.initial_size=8g
server.memory.heap.max_size=8g   # Set equal to initial to avoid GC pauses from heap resizing
```

### Off-Heap (Page Cache)

The page cache is allocated outside the JVM heap:
- Not subject to garbage collection
- Directly managed by Neo4j's page cache implementation
- Sized via `server.memory.pagecache.size`

### Memory Allocation Strategy

```
Total Server RAM
├── JVM Heap (server.memory.heap.max_size)
│   ├── Query execution buffers
│   ├── Transaction state
│   └── Query plan cache
├── Page Cache (server.memory.pagecache.size)
│   └── Cached store pages (graph data)
├── OS / Filesystem Cache (1-2 GB minimum)
│   └── Caches file I/O not managed by page cache
└── Other processes
```

**Rule of thumb for a dedicated Neo4j server:**
```
Heap = 8-16 GB (rarely needs more; excessive heap = long GC pauses)
Page Cache = Total Store Size (or as much as fits)
OS Reserve = 1-2 GB minimum
Total = Heap + Page Cache + OS Reserve <= Physical RAM
```

Use the built-in recommendation tool:
```bash
neo4j-admin server memory-recommendation --memory=64g
```
