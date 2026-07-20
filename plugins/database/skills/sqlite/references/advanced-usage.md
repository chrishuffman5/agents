# SQLite Advanced Usage

## ATTACH DATABASE

```sql
-- Attach a second database
ATTACH DATABASE 'analytics.db' AS analytics;

-- Cross-database query
SELECT u.name, a.event_type, a.ts
FROM main.users u
JOIN analytics.events a ON u.id = a.user_id;

-- Cross-database INSERT
INSERT INTO analytics.summary
SELECT date, count(*) FROM main.events GROUP BY date;

-- List attached databases
PRAGMA database_list;

-- Detach
DETACH DATABASE analytics;
```

**Limitations:** Atomic transactions across attached databases require rollback journal mode (not WAL). In WAL mode, transactions are atomic per-database but not across databases.

## SQLite WASM

SQLite compiles to WebAssembly for browser and server-side JavaScript deployment:

```javascript
// Official npm package: @sqlite.org/sqlite-wasm
import sqlite3InitModule from '@sqlite.org/sqlite-wasm';

const sqlite3 = await sqlite3InitModule();
const db = new sqlite3.oo1.DB('/mydb.sqlite3', 'ct');

db.exec("CREATE TABLE IF NOT EXISTS t(a, b)");
db.exec("INSERT INTO t(a, b) VALUES (1, 'hello')");

const rows = [];
db.exec({
  sql: "SELECT * FROM t",
  rowMode: 'object',
  callback: (row) => rows.push(row)
});

db.close();
```

**Persistence options:**
- **Origin Private File System (OPFS):** Best performance, supported in Chrome, Firefox, Safari (2025+)
- **IndexedDB VFS:** Broader browser support, slower
- **In-memory only:** No persistence, fastest
- **OPFS via SAH Pool:** High-performance OPFS using SQLite Access Handle Pool VFS

## Ecosystem

**Litestream** (v0.5.0, Oct 2025) -- Streaming replication for SQLite:
- Continuously replicates WAL changes to S3, GCS, Azure Blob, SFTP, or local filesystem
- Near-zero RPO (recovery point objective) for disaster recovery
- VFS read replicas can query directly from object storage without local restore
- LTX format with hierarchical compaction for efficient storage

**rqlite** (v9.4.x) -- Fault-tolerant distributed SQLite:
- Uses Raft consensus for multi-node replication
- HTTP API for reads and writes
- Change Data Capture (CDC) for streaming changes to external systems
- Automatic leader election and failover
- Best for applications needing HA without complex infrastructure

**Turso / libSQL** -- SQLite fork and managed platform:
- libSQL: Open-contribution SQLite fork with embedded replicas, native vector search, WASM UDFs, and `BEGIN CONCURRENT` for multi-writer support
- Turso Database: SQLite-compatible database rewritten in Rust with native async, concurrent writes, and bi-directional sync
- Turso Cloud: Managed edge database service with copy-on-write branching

**Cloudflare D1** -- Managed SQLite at the edge:
- SQLite databases deployed to Cloudflare's edge network
- Automatic replication across regions
- Integrated with Cloudflare Workers

**SQLite tools:**
- `sqlite3` -- Command-line shell
- `sqlite3_analyzer` -- Page-level storage analysis
- `sqldiff` -- Database differencing tool
- `sqlite3_rsync` -- Efficient database synchronization (page-level rsync for SQLite)
