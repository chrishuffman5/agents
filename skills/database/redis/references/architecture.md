# Redis Architecture Reference

## Event Loop and Threading Model

### Single-Threaded Core

Redis processes commands in a single-threaded event loop. This is the most important architectural decision:

- **No locks, no context switching** -- Every command executes atomically without synchronization overhead
- **Event-driven I/O** -- Uses epoll (Linux), kqueue (BSD/macOS), or select as the I/O multiplexer
- **ae (A simple Event library)** -- Redis's custom event loop implementation in `ae.c`
- **File events** -- Client socket reads/writes, replication, cluster bus
- **Time events** -- serverCron (runs 10x/sec by default), handles background tasks like expiry, stats, replication heartbeat

**Event loop cycle:**
```
1. Process time events (serverCron)
2. Poll for file events (epoll_wait with timeout)
3. Process readable file events (client commands)
4. Process writable file events (send responses)
5. Repeat
```

**serverCron responsibilities (hz = 10 by default):**
- Active key expiry (lazy + periodic sampling)
- Client timeout enforcement
- Replication heartbeat (PING to replicas)
- AOF and RDB background save monitoring
- Memory limit enforcement (eviction)
- Cluster state maintenance
- Statistics updates (ops/sec, memory, keyspace)
- Resize hash tables (incremental rehashing)

### I/O Threading (Redis 6.0+)

Redis 6.0 introduced I/O threading for reading client commands and writing responses, while command execution remains single-threaded:

```
io-threads 4                    # 1 main thread + 3 I/O threads
io-threads-do-reads yes         # also parallelize reading (not just writing)
```

**How I/O threading works:**
1. Main thread accepts connections and assigns clients to I/O threads in round-robin
2. I/O threads read data from sockets and parse commands (in parallel)
3. Main thread executes all commands (single-threaded, sequential)
4. I/O threads write responses to sockets (in parallel)

**When to enable I/O threads:**
- High throughput workloads (>100K ops/sec)
- Multi-core machines where network I/O is the bottleneck
- Not beneficial for small deployments or CPU-bound workloads (command execution is the bottleneck)
- Typical recommendation: set io-threads to number of CPU cores / 2, minimum 2, maximum 8

**Thread safety guarantee:** Command execution is always single-threaded. I/O threads only handle socket reads/writes and protocol parsing. No data structure access occurs outside the main thread.

## Memory Allocator

### jemalloc

Redis uses jemalloc as its default memory allocator (since Redis 2.4):

- **Arena-based allocation** -- Multiple independent arenas reduce lock contention
- **Size classes** -- Objects allocated in predefined size bins to reduce fragmentation
- **Thread caching** -- Per-thread cache (tcache) for small allocations
- **Transparent huge pages (THP)** -- Redis disables THP at startup because THP causes latency spikes during fork (copy-on-write amplification)

**Disable THP in production:**
```bash
echo never > /sys/kernel/mm/transparent_hugepages/enabled
echo never > /sys/kernel/mm/transparent_hugepages/defrag
```

**jemalloc stats via Redis:**
```bash
MEMORY STATS          # detailed memory breakdown
MEMORY MALLOC-STATS   # raw jemalloc statistics
MEMORY PURGE          # force jemalloc to release pages back to OS
MEMORY DOCTOR         # automated memory health diagnosis
```

**Key memory metrics:**
| Metric (INFO memory) | Meaning |
|---|---|
| `used_memory` | Total bytes allocated by jemalloc for data |
| `used_memory_rss` | Resident set size from OS (includes fragmentation, allocator overhead) |
| `used_memory_overhead` | Memory used for internal structures (not user data) |
| `used_memory_dataset` | `used_memory` - `used_memory_overhead` (approximate data size) |
| `mem_fragmentation_ratio` | `used_memory_rss` / `used_memory` (healthy: 1.0-1.5) |
| `mem_allocator` | Active allocator (jemalloc-X.X.X, libc, tcmalloc) |
| `allocator_frag_ratio` | jemalloc internal fragmentation ratio |
| `allocator_rss_ratio` | jemalloc RSS overhead ratio |

## Data Structure Encoding Internals

Redis uses multiple internal encodings per data type, choosing compact representations for small objects:

### String Encodings

| Encoding | Condition | Storage |
|---|---|---|
| `int` | Value is an integer representable as long | 8 bytes (stored as native long, no SDS) |
| `embstr` | String <= 44 bytes | Single allocation: robj + SDS header + data |
| `raw` | String > 44 bytes | Two allocations: robj + separate SDS buffer |

**SDS (Simple Dynamic Strings):**
- Redis's custom string type replacing C strings
- Binary-safe (can contain null bytes)
- O(1) length retrieval (stored in header)
- Space pre-allocation on growth (reduces reallocation)
- Multiple header sizes (sdshdr5, sdshdr8, sdshdr16, sdshdr32, sdshdr64) based on string length

### listpack (Replaces ziplist in Redis 7.0+)

A compact, sequentially-allocated representation for small collections:

- **Structure:** Total bytes (4B) + num entries (2B) + entry1 + entry2 + ... + end byte (0xFF)
- **Each entry:** encoding + data + backlen (for reverse traversal)
- **O(n) access** but cache-friendly for small n (everything in one contiguous memory block)
- **No cascading updates** (unlike the old ziplist which had cascading update bugs)

Used by: Hashes (small), Sets (small), Sorted Sets (small), Streams (inside radix tree nodes)

**Conversion thresholds:**
```
hash-max-listpack-entries 128     # fields > 128 --> hashtable
hash-max-listpack-value 64        # field/value > 64 bytes --> hashtable
zset-max-listpack-entries 128     # members > 128 --> skiplist
zset-max-listpack-value 64        # member > 64 bytes --> skiplist
set-max-listpack-entries 128      # members > 128 --> hashtable
```

### quicklist (List encoding)

A doubly-linked list of listpack nodes:

```
quicklist: head <-> [listpack] <-> [listpack] <-> [listpack] <-> tail
```

- Each node contains a listpack with multiple list elements
- Balances O(1) push/pop (linked list) with cache-friendly storage (listpack)
- Nodes can be individually compressed with LZF (middle nodes only):
```
list-max-listpack-size -2       # -1 = 4KB, -2 = 8KB (default), -3 = 16KB, -4 = 32KB, -5 = 64KB per node
list-compress-depth 0           # 0 = no compression, 1 = compress all but head/tail, etc.
```

### skiplist + hashtable (Sorted Set encoding for large sets)

When a sorted set exceeds listpack thresholds, it uses a dual data structure:

- **Skiplist** -- O(log n) range queries, ordered traversal
  - Multiple levels of forward pointers (probabilistic balancing, p=0.25)
  - Max 32 levels (supports 2^32 elements efficiently)
  - Each node: element pointer + score (double) + backward pointer + level array
- **Hashtable** -- O(1) score lookups by member (ZSCORE)
  - Both structures reference the same SDS member string (no duplication)

**Why both?** ZRANGEBYSCORE needs the skiplist; ZSCORE needs the hashtable. Neither alone satisfies all operations efficiently.

### intset (Small integer Set encoding)

When all set members are integers and count is below `set-max-intset-entries`:

- Sorted array of integers
- Supports 16-bit, 32-bit, or 64-bit entries (upgrades automatically)
- O(log n) lookup via binary search
- Very memory-efficient for small integer sets

### hashtable (dict)

Redis's general-purpose hash table implementation:

- **Incremental rehashing** -- When load factor exceeds threshold, a second table is allocated and entries are gradually migrated (1 bucket per command + bulk migration in serverCron)
- **Load factor thresholds:**
  - Expand: ratio >= 1 (or >= 5 during BGSAVE to avoid copy-on-write amplification)
  - Shrink: ratio < 0.1
- **MurmurHash2** for key hashing (good distribution, fast)
- **Chaining** for collision resolution

**Rehashing process:**
```
ht[0]: [bucket0] -> [bucket1] -> ... -> [bucketN]    (old table)
ht[1]: [bucket0] -> [bucket1] -> ... -> [bucket2N]   (new table, 2x size)

During rehashing:
- Reads check both tables
- Writes go to ht[1]
- Each operation migrates one bucket from ht[0] to ht[1]
- When ht[0] is empty, swap ht[0] = ht[1], free old table
```

### Streams Internal Structure

Streams use a radix tree (rax) where each node contains a listpack:

```
Radix tree (indexed by stream entry ID):
  root
  ├── "1234567890" -> listpack [field1, val1, field2, val2, ...]
  ├── "1234567891" -> listpack [field1, val1, field2, val2, ...]
  └── "1234567892" -> listpack [...]
```

- Entry IDs: `<milliseconds>-<sequence>` (monotonically increasing)
- Listpacks store multiple entries with the same field set (field name deduplication)
- Consumer groups stored as separate structures referencing stream entry IDs
- PEL (Pending Entries List) is a radix tree mapping entry IDs to consumer + delivery info

## Persistence Internals

### RDB (Fork-Based Snapshots)

**Process:**
1. `BGSAVE` triggers: Redis calls `fork()`
2. Child process writes the dataset to a temporary file `temp-<pid>.rdb`
3. Parent continues serving clients (copy-on-write semantics)
4. Child completes writing, renames temp file to `dump.rdb`
5. Child exits, parent records completion

**Fork and copy-on-write:**
- `fork()` is nearly instant (duplicates page tables, not data)
- OS uses copy-on-write: pages are shared until modified
- When parent modifies a page, OS creates a private copy for the child
- Peak memory = used_memory + modified_pages_during_save
- Worst case (100% write rate during save): 2x memory usage
- Monitor: `INFO persistence` -> `latest_fork_usec` (fork time in microseconds)

**RDB file format:**
```
[REDIS magic "REDIS0011"] [AUX fields: redis-ver, redis-bits, ctime, used-mem]
[DB selector 0]
  [TYPE] [KEY] [VALUE] [EXPIRE if set]
  [TYPE] [KEY] [VALUE]
  ...
[DB selector 1]
  ...
[EOF] [CRC64 checksum]
```

Type-specific serialization: strings as-is, lists as length+elements, sets as length+members, sorted sets as length+(member,score) pairs, hashes as length+(field,value) pairs.

### AOF (Append-Only File)

**Write path:**
1. Command executes and modifies data
2. Command is appended to the AOF buffer (`aof_buf`)
3. Buffer is written to file based on `appendfsync` policy:
   - `always`: fsync after every command (safest, ~100x slower)
   - `everysec`: fsync once per second in background thread (default, good trade-off)
   - `no`: never fsync explicitly (OS flushes, typically every 30 seconds)

**AOF rewrite (background):**
1. `BGREWRITEAOF` triggers: Redis calls `fork()`
2. Child iterates the dataset and writes minimal commands to reproduce current state
3. While child rewrites, parent accumulates new commands in a rewrite buffer
4. Child completes; parent appends the rewrite buffer to the new AOF
5. Atomic rename of new AOF over old AOF

**Multi-part AOF (Redis 7.0+):**
```
appendonlydir/
├── appendonly.aof.1.base.rdb       # base file (RDB format)
├── appendonly.aof.1.incr.aof       # incremental commands since base
├── appendonly.aof.2.incr.aof       # more incremental commands
└── appendonly.aof.manifest         # tracks file ordering
```

Benefits of multi-part AOF:
- No atomic rename of potentially large files
- Incremental files can be deleted independently
- Safer rewrite process (no data loss if rewrite fails)

### Hybrid AOF+RDB (Default since 7.0)

When `aof-use-rdb-preamble yes`:
- AOF rewrite generates an RDB-format base file
- Subsequent commands are appended in RESP format
- On restart: load the RDB preamble (fast binary load), then replay AOF tail
- Combines the speed of RDB loading with the durability of AOF

## Cluster Protocol

### Gossip Protocol

Cluster nodes communicate via the **cluster bus** (port = data port + 10000):

- **PING/PONG** messages exchanged every second (with a subset of known node states)
- Each message contains: sender's config epoch, replication offset, slot bitmap, flags
- Gossip section: state information about a random subset of other nodes
- **Failure detection:**
  1. Node A hasn't received PONG from Node B within `cluster-node-timeout`
  2. A marks B as PFAIL (probable failure) locally
  3. A gossips B's PFAIL to other nodes
  4. If majority of masters agree B is PFAIL within `cluster-node-timeout * 2`, B is marked FAIL
  5. If B is a master, its replica initiates failover

**Cluster handshake:**
```
Node A                     Node B
  |--- MEET(A_addr) ------->|
  |<-- PONG(B_state) -------|
  |--- PING(A_state) ------->|
  |<-- PONG(B_state) -------|
  (now exchanging gossip regularly)
```

### MOVED and ASK Redirections

**MOVED redirection (permanent):**
```
Client -> Node A: GET {user:1000}:name
Node A -> Client: MOVED 3999 192.168.1.2:6379
Client -> updates slot table: slot 3999 -> 192.168.1.2:6379
Client -> Node B: GET {user:1000}:name
Node B -> Client: "John"
```

**ASK redirection (during migration):**
```
Client -> Node A: GET {user:1000}:name
Node A -> Client: ASK 3999 192.168.1.2:6379   (slot being migrated)
Client -> Node B: ASKING
Client -> Node B: GET {user:1000}:name
Node B -> Client: "John"
(client does NOT update slot table -- migration is temporary)
```

**Slot migration process:**
1. `CLUSTER SETSLOT <slot> MIGRATING <target-node-id>` on source
2. `CLUSTER SETSLOT <slot> IMPORTING <source-node-id>` on target
3. For each key in the slot: `MIGRATE <target-host> <target-port> <key> 0 5000`
4. `CLUSTER SETSLOT <slot> NODE <target-node-id>` on all nodes

### Cluster Failover

**Automatic failover (when master detected as FAIL):**
1. All replicas of the failed master wait: `DELAY = 500ms + random(0,500) + REPLICA_RANK * 1000`
2. Replica with lowest rank (highest replication offset) waits least
3. Replica requests votes: sends FAILOVER_AUTH_REQUEST to all masters
4. Masters vote: grant AUTH_ACK if they haven't voted for this epoch
5. If replica receives majority votes, it becomes the new master
6. New master broadcasts PONG with new config epoch to claim slots

**Manual failover:**
```bash
# On the replica you want to promote:
CLUSTER FAILOVER           # graceful: waits for replication sync
CLUSTER FAILOVER FORCE     # force: doesn't wait for master
CLUSTER FAILOVER TAKEOVER  # immediate: doesn't wait for vote (use for disasters)
```

## Replication Protocol

### Full Synchronization

1. Replica sends `PSYNC ? -1` (or `PSYNC <replid> <offset>` for partial)
2. Master responds with `+FULLRESYNC <replid> <offset>`
3. Master triggers BGSAVE (or uses diskless replication)
4. Master sends RDB to replica
5. While sending, master buffers new commands in the replication backlog
6. After RDB transfer, master sends buffered commands
7. Replica loads RDB, then processes the command stream

### Partial Resynchronization (PSYNC2)

After a brief disconnection, the replica can resume from where it left off:

1. Replica reconnects and sends `PSYNC <replid> <offset>`
2. Master checks if offset is within the replication backlog
3. If yes: `+CONTINUE` and sends only missing commands
4. If no (offset too old or different replid): full sync

**Replication backlog:**
```
repl-backlog-size 256mb      # circular buffer; larger = longer disconnection tolerance
repl-backlog-ttl 3600        # seconds to keep backlog after last replica disconnects
```

### Replication ID and Offset

- **Replication ID** (`master_replid`): unique identifier for a replication stream
- **Replication offset** (`master_repl_offset`): byte offset in the replication stream
- **Second replication ID** (`master_replid2`): previous master's replid (for failover continuity)
- Replicas can partial-sync with a promoted peer if they share replid2

## Client Output Buffer Management

Each client has an output buffer for pending responses:

```
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
```

Format: `<class> <hard-limit> <soft-limit> <soft-seconds>`
- **Hard limit**: disconnect immediately if buffer exceeds this
- **Soft limit**: disconnect if buffer exceeds this for soft-seconds continuously
- **normal**: regular clients (0 = unlimited, but use with caution)
- **replica**: replication clients (allow large buffers for sync)
- **pubsub**: pub/sub subscribers (protect against slow subscribers)

**Monitor with:**
```bash
CLIENT LIST    # omem column shows output buffer size per client
INFO clients   # client_recent_max_output_buffer shows recent peak
```

## Key Expiry Mechanism

Redis uses a hybrid approach for key expiration:

**Lazy expiry (passive):**
- Checked on every key access
- If key is expired, delete it and return "key not found"
- Zero CPU cost for keys that are never accessed after expiration

**Active expiry (periodic, in serverCron):**
- 10 times per second (adjustable with `hz`):
  1. Sample 20 random keys with TTL from each database
  2. Delete expired keys found
  3. If > 25% of sampled keys were expired, repeat immediately
  4. Continue until < 25% expired or time limit reached (25% of 100ms = 25ms)
- Adaptive: more aggressive when many keys are expiring

**Implications:**
- Memory may not be freed immediately when keys expire
- A database with millions of expired keys can temporarily use more memory than expected
- Increase `hz` (default 10, max 500) for faster expiry at the cost of CPU
- `dynamic-hz yes` (default) adjusts effective hz based on client activity

## RESP Protocol

Redis Serialization Protocol (RESP) is the wire protocol between clients and server:

**RESP2 types:**
| Prefix | Type | Example |
|---|---|---|
| `+` | Simple String | `+OK\r\n` |
| `-` | Error | `-ERR unknown command\r\n` |
| `:` | Integer | `:1000\r\n` |
| `$` | Bulk String | `$5\r\nhello\r\n` |
| `*` | Array | `*2\r\n$3\r\nGET\r\n$3\r\nkey\r\n` |

**RESP3 (Redis 6.0+, opt-in via HELLO 3):**
- Adds: Map (`%`), Set (`~`), Double (`,`), Boolean (`#`), Null (`_`), Big Number (`(`)
- Push messages (`>`) for client-side caching invalidations
- Verbatim strings (`=`) with format prefix (txt, mkd)
- Attribute type (`|`) for metadata

**Client handshake:**
```
Client: HELLO 3 AUTH username password
Server: (RESP3 map with server info: version, mode, role, modules)
```
