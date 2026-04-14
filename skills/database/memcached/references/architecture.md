# Memcached Architecture Reference

## Memory Architecture: The Slab Allocator

### Why a Slab Allocator

Memcached's slab allocator exists to solve a fundamental problem: `malloc()/free()` fragmentation. In a high-throughput cache where millions of items are stored and evicted continuously, general-purpose memory allocators (glibc malloc, jemalloc) suffer from severe fragmentation -- allocated memory becomes riddled with unusable gaps. Memcached's slab allocator pre-divides memory into fixed-size chunks, completely eliminating external fragmentation at the cost of some internal waste (the unused portion of each chunk).

### Slab Class Hierarchy

```
Total memory (-m flag, e.g., 4096 MB)
 |
 +-- Slab Class 1 (chunk size: 96 bytes)
 |    +-- Page 0 (1 MB) -> 10,922 chunks
 |    +-- Page 1 (1 MB) -> 10,922 chunks
 |    +-- ...
 |
 +-- Slab Class 2 (chunk size: 120 bytes)
 |    +-- Page 0 (1 MB) -> 8,738 chunks
 |    +-- ...
 |
 +-- Slab Class 3 (chunk size: 152 bytes)
 |    +-- Page 0 (1 MB) -> 6,898 chunks
 |    +-- ...
 |
 +-- ... (up to ~42 classes with default growth factor 1.25)
 |
 +-- Slab Class 42 (chunk size: 1,048,576 bytes = 1 MB)
      +-- Page 0 (1 MB) -> 1 chunk
```

**Page allocation:**
- Memory is allocated in 1 MB pages (configurable, but rarely changed)
- When a slab class needs more chunks, a new page is allocated from the free pool
- Once assigned to a slab class, a page belongs to that class permanently (unless slab reassignment is enabled)
- When all pages are assigned, new allocations trigger eviction from the target slab class

### Chunk Size Calculation

The chunk size for each slab class is calculated at startup:

```
chunk_size[0] = base_size + item_header_size
chunk_size[n] = chunk_size[n-1] * growth_factor

Where:
  base_size = -n flag (default 48 bytes, key+value minimum)
  item_header_size = ~48 bytes (struct item: prev/next pointers, hash chain, exptime, flags, etc.)
  growth_factor = -f flag (default 1.25)
```

**Item header structure (struct item):**
```c
typedef struct _stritem {
    struct _stritem *next;      // 8 bytes: next item in hash chain
    struct _stritem *prev;      // 8 bytes: prev item in LRU
    struct _stritem *h_next;    // 8 bytes: next item in hash bucket
    rel_time_t      exptime;    // 4 bytes: expiration time
    int             nbytes;     // 4 bytes: value size (including \r\n)
    unsigned short  refcount;   // 2 bytes: reference count
    uint16_t        it_flags;   // 2 bytes: item flags (LINKED, SLABBED, CAS, etc.)
    uint8_t         slabs_clsid;// 1 byte: slab class ID
    uint8_t         nkey;       // 1 byte: key length
    // CAS value follows if CAS is enabled (8 bytes)
    // Key string follows
    // Value follows key
} item;
```

Total item overhead: ~48 bytes (without CAS) or ~56 bytes (with CAS). The key and value are stored inline after the header, within the same chunk.

### Growth Factor Impact

The growth factor (`-f`) controls how rapidly chunk sizes increase between slab classes:

| Growth Factor | Classes (up to 1 MB) | Avg Internal Waste | Use Case |
|---|---|---|---|
| 1.05 | ~200 | ~2.5% | Very uniform item sizes, memory-critical |
| 1.10 | ~100 | ~5% | Low waste, many classes |
| 1.25 (default) | ~42 | ~12.5% | Good balance for mixed workloads |
| 1.50 | ~25 | ~25% | Fewer classes, higher waste |
| 2.00 | ~20 | ~50% | Maximum waste, few classes |

**Waste calculation:** An item of size S placed in a chunk of size C wastes `(C - S) / C` on average. With factor 1.25, the worst case for any single item is ~20% waste (item is just larger than the previous class's chunk).

### Slab Reassignment (Page Rebalancing)

Without slab reassignment, slab classes accumulate pages permanently. This causes **slab calcification**: a class that was once busy retains many pages even if the workload shifts.

**Slab reassignment (enabled with `-o slab_reassign`):**
1. The **slab rebalance thread** identifies a source class (most free chunks or highest eviction rate relative to allocation)
2. It freezes the source page: items on that page are evicted or moved
3. The page is returned to the global free pool
4. The page is reassigned to the requesting class

**Slab automove algorithm (`-o slab_automove=1`):**
- Every 10 seconds, checks eviction rates across all slab classes
- If one class has a significantly higher eviction rate than others, moves a page from the class with the most free pages
- `slab_automove=2`: aggressive mode -- moves pages immediately when evictions occur, can cause thrashing

### Hash Table

Memcached uses a power-of-two hash table for O(1) key lookups:

**Hash function:** MurmurHash3 (fast, good distribution, non-cryptographic)

**Hash table expansion:**
- Starts at a configurable size (default based on expected keys, `-o hashpower=N` where table size = 2^N)
- When the load factor exceeds a threshold (default ~1.5 items per bucket), the table expands
- Expansion is performed by a **dedicated thread** to avoid blocking worker threads
- During expansion:
  1. A new table 2x the size is allocated
  2. Items are gradually moved from old buckets to new buckets
  3. Lookups check both old and new tables during migration
  4. When migration is complete, the old table is freed

**Hash table locking:**
- Per-bucket locks (not a global lock)
- Workers can access different buckets concurrently
- Same-bucket operations are serialized

```bash
# Pre-size hash table for expected key count
-o hashpower=20    # 2^20 = ~1M buckets; good for ~1.5M keys
-o hashpower=24    # 2^24 = ~16M buckets; good for ~24M keys
```

## Threading Model

### Thread Architecture

```
                    +-----------------+
                    | Listener Thread |
                    | (accept conns)  |
                    +--------+--------+
                             |
              +--------------+--------------+
              |              |              |
       +------+------+ +----+------+ +-----+-----+
       | Worker #1   | | Worker #2 | | Worker #N |
       | (libevent)  | | (libevent)| | (libevent)|
       | connections | | connections| | connections|
       +------+------+ +-----+-----+ +-----+-----+
              |              |              |
       [shared hash table with per-bucket locks]
       [shared slab allocator with per-class locks]
              |              |              |
       +------+------+ +----+------+ +-----+-----+
       | LRU Maint.  | | LRU      | | Slab      |
       | Thread      | | Crawler  | | Rebalance |
       +-------------+ +----------+ +-----------+
```

**Listener thread:**
- Single thread that calls `accept()` on the listening socket
- New connections are dispatched to worker threads in round-robin
- Uses a pipe or eventfd to wake the target worker thread

**Worker threads:**
- Each runs its own libevent event loop
- Handles all I/O for its assigned connections (read request, process, write response)
- Command execution accesses the shared hash table and slab allocator
- Number set by `-t` flag (default 4)

**Background threads:**
- **LRU maintainer**: Manages segmented LRU queues, shuffles items between HOT/WARM/COLD
- **LRU crawler**: Scans for expired items to reclaim memory proactively
- **Hash table expander**: Resizes hash table without blocking workers
- **Slab rebalancer**: Moves pages between slab classes
- **Logger thread**: Writes to the logger watcher (if external logging is configured)

### Connection Handling

Each connection has a state machine:

```
NEW_CMD          -> waiting for a new command
READ_CMD         -> reading the command line
PARSE_CMD        -> parsing the command
WRITE_RESPONSE   -> writing response back to client
CLOSE            -> connection closed
```

**Connection memory:**
- Each connection has read/write buffers (default 2KB + 2KB, grow on demand)
- `stats conns` shows per-connection buffer usage
- At 10,000 connections: ~40 MB just for connection buffers

**UDP mode (`-U` flag):**
- Memcached can listen on UDP for simple GET operations
- No connection state needed (stateless)
- Lower overhead per "connection" but no flow control
- Largely deprecated due to amplification attack concerns; use with caution or disable (`-U 0`)

## LRU Algorithm Internals

### Segmented LRU Details

Each slab class maintains four independent LRU queues (doubly-linked lists):

```
Slab Class N:
  HOT  head <-> item <-> item <-> item <-> tail
  WARM head <-> item <-> item <-> item <-> tail
  COLD head <-> item <-> item <-> item <-> tail
  TEMP head <-> item <-> item <-> item <-> tail
```

**Item lifecycle:**
1. **New item** (SET/ADD): inserted at HOT head (or TEMP head if TTL <= temporary_ttl)
2. **HOT aging**: LRU maintainer moves items from HOT tail to WARM head (if recently accessed) or COLD head (if not)
3. **WARM promotion**: On access (GET), item is bumped to WARM head. WARM tail items move to COLD.
4. **COLD eviction**: When the slab class needs a chunk, it evicts from COLD tail
5. **COLD rescue**: If a COLD item is accessed, it is promoted to WARM head
6. **TEMP**: Items with short TTL go here. Never promoted. Evicted when expired. This prevents short-lived items from polluting HOT/WARM.

**LRU maintainer thread:**
- Runs in a loop, processing each slab class
- Moves items between queues based on access times
- Frequency: configurable via `-o lru_maintainer_sleep=N` (microseconds between runs)

### Item Bumping and Access Tracking

To avoid locking overhead on every GET, Memcached uses **lazy bumping**:

- On GET, the item's `time` field is updated (last access time)
- The item is NOT immediately moved in the LRU (no linked-list manipulation under lock)
- The LRU maintainer thread periodically scans and moves items based on their `time`
- This reduces lock contention: GETs are essentially lock-free for LRU purposes

**Bump frequency limiting:**
- Even the `time` update can cause cache-line contention on hot items
- Memcached 1.6.x limits bumps to once per ~60 seconds for frequently accessed items
- This is configurable and designed to reduce CPU overhead for extremely hot keys

### Expiration Mechanisms

**Lazy expiration (on access):**
- When a GET encounters an expired item, it is treated as a miss
- The item is unlinked and returned to the slab free list
- Zero cost for items that are never accessed after expiration

**LRU crawler (proactive reclamation):**
- Background thread that crawls LRU queues looking for expired items
- Reclaims memory without waiting for access
- Important for slab classes with many expired items that are never GET'd
- Configurable crawl speed: `lru_crawler metadump` or `lru_crawler crawl <class>`

## Protocol Internals

### Text Protocol

The ASCII text protocol is line-oriented with `\r\n` delimiters:

**Storage commands:**
```
<cmd> <key> <flags> <exptime> <bytes> [noreply]\r\n
<data block>\r\n

Where:
  cmd = set | add | replace | append | prepend | cas
  key = up to 250 bytes (no spaces, no control chars)
  flags = 32-bit unsigned integer (opaque to server, stored with item)
  exptime = 0 (never), <30 days (relative seconds), >=30 days (Unix timestamp)
  bytes = data length (not including \r\n)
  noreply = optional, suppresses response (fire-and-forget)

CAS form: cas <key> <flags> <exptime> <bytes> <cas_unique> [noreply]\r\n
```

**Retrieval commands:**
```
get <key1> [key2] [key3] ...\r\n
gets <key1> [key2] [key3] ...\r\n    # includes CAS token

Response:
VALUE <key> <flags> <bytes> [<cas_unique>]\r\n
<data block>\r\n
...
END\r\n
```

**Delete and arithmetic:**
```
delete <key> [noreply]\r\n
incr <key> <value> [noreply]\r\n
decr <key> <value> [noreply]\r\n
touch <key> <exptime> [noreply]\r\n
```

### Binary Protocol

The binary protocol uses fixed-size headers for efficient parsing:

**Request header (24 bytes):**
```
Byte/  0       |       1       |       2       |       3       |
     / |       |               |               |               |
    |0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|
    +---------------+---------------+---------------+---------------+
   0| Magic (0x80)  | Opcode        | Key length                    |
    +---------------+---------------+---------------+---------------+
   4| Extras length | Data type     | vbucket id (or status)        |
    +---------------+---------------+---------------+---------------+
   8| Total body length                                             |
    +---------------+---------------+---------------+---------------+
  12| Opaque (echoed back)                                          |
    +---------------+---------------+---------------+---------------+
  16| CAS value                                                     |
    |                                                               |
    +---------------+---------------+---------------+---------------+
```

**Key opcodes:** 0x00 Get, 0x01 Set, 0x02 Add, 0x03 Replace, 0x04 Delete, 0x05 Increment, 0x06 Decrement, 0x09 GetQ (quiet), 0x0c GetK (return key), 0x21 SASL Auth

**Quiet commands (pipelining):**
- GetQ, SetQ, DeleteQ: no response unless there is an error
- Client sends a batch of quiet commands, followed by a non-quiet command (Noop)
- Server responds only for errors + the final Noop, reducing response traffic

### Meta Commands Protocol (1.6.x)

Meta commands replace both text and binary protocol with a single, extensible command set:

**Meta get (`mg`):**
```
mg <key> [flags]\r\n

Flags:
  v     - return value
  t     - return TTL remaining (-1 = no expiry, -2 = not found)
  c     - return CAS value
  f     - return client flags
  l     - return last access time
  h     - return hit status (0 = miss, 1 = hit)
  k     - return key
  s     - return size (bytes)
  O<token> - opaque token (echoed back, for pipelining)
  N<ttl> - vivify on miss (create with TTL if not found)
  R<ttl> - recache (bump TTL if item is close to expiring)
  u     - mark stale (for stale-while-revalidate)

Response:
  VA <size> <response_flags>\r\n<data>\r\n   (hit with value)
  HD <response_flags>\r\n                    (hit, no value requested)
  EN\r\n                                      (miss)
```

**Meta set (`ms`):**
```
ms <key> <size> [flags]\r\n<data>\r\n

Flags:
  T<ttl>   - set TTL
  F<flags> - set client flags
  C<cas>   - CAS operation (set only if CAS matches)
  N<ttl>   - create-only (like ADD) with TTL
  q        - quiet mode (no response on success)
  M<mode>  - mode: E=set, A=add, R=replace, P=append, X=prepend
  O<token> - opaque token
  W        - win flag: returns whether this SET "won" a race
```

**Meta delete (`md`):**
```
md <key> [flags]\r\n

Flags:
  T<ttl>   - invalidate: mark stale for TTL seconds instead of deleting
  I        - invalidate mode (works with stale-while-revalidate)
  q        - quiet mode
  O<token> - opaque token
```

**Stale-while-revalidate pattern with meta commands:**
```
1. Client A: mg mykey t v
   -> VA 100 t=5 ...   (TTL remaining: 5 seconds, getting close)

2. Client A: ms mykey 100 T3600 W   (attempt recache, "win" flag)
   -> HD W              ("won" the race to recache)
   or -> NS W           ("lost", another client is already recaching)

3. Meanwhile, Client B: mg mykey t v u
   -> VA 100 t=-1 X ... (stale data, marked with X flag)
   Client B uses stale data while A recaches
```

This pattern prevents cache stampedes without external locking.

## Network I/O

### libevent Integration

Memcached uses libevent for event-driven I/O multiplexing:

- Each worker thread runs its own `event_base`
- Uses `epoll` on Linux, `kqueue` on BSD/macOS, `select` fallback
- Connections are assigned to threads at accept() time
- No connection migration between threads

**Event flow:**
```
1. Listener thread: accept() -> pick worker thread N (round-robin)
2. Notify worker N via pipe/eventfd
3. Worker N: register connection fd with its event_base
4. Worker N: epoll_wait() returns when connection is readable
5. Worker N: read command, process, write response
6. Worker N: re-register for read events (next command)
```

### Pipelining

Clients can send multiple commands without waiting for responses (pipelining):

**Text protocol pipelining:**
```
get key1\r\nget key2\r\nget key3\r\n
```
Server processes sequentially and sends all responses in order.

**Binary protocol pipelining (more efficient):**
- Use GetQ (quiet get): no response unless miss
- Terminate batch with Noop (opcode 0x0a)
- Server sends error responses only + Noop response

**Meta protocol pipelining:**
- Use `O<token>` opaque flag to correlate responses
- Use `q` flag for quiet mode where appropriate
```
mg key1 v Oaaa\r\nmg key2 v Obbb\r\nmg key3 v Occc\r\nmn\r\n
```
Responses carry the opaque token for correlation.

### Connection Limits and Backpressure

**Max connections:**
```bash
-c 1024          # Maximum simultaneous connections (default)
-c 65535         # High-traffic production setting
```

**Backpressure behavior:**
- When max connections is reached, new connections are rejected
- `listen_disabled_num` increments in stats
- Client receives connection refused (TCP RST)
- No graceful queuing -- configure enough connections or use a proxy layer for pooling

**Per-connection memory:**
```bash
# Read buffer: starts at 2KB, grows up to item size limit
# Write buffer: starts at 2KB, grows as needed
# At 10,000 connections with default buffers: ~40 MB
# At 100,000 connections: ~400 MB just for buffers
```

## CAS (Compare-And-Swap) Mechanism

CAS provides optimistic locking for concurrent updates:

**CAS flow:**
```
1. Client: gets mykey
   -> VALUE mykey 0 5 12345\r\nhello\r\nEND\r\n
   (12345 is the CAS token, a 64-bit unique version)

2. Client computes new value

3. Client: cas mykey 0 3600 5 12345\r\nworld\r\n
   -> STORED              (CAS matched, update succeeded)
   -> EXISTS              (CAS mismatch, another client modified the item)
   -> NOT_FOUND           (item expired or was evicted between gets and cas)
```

**CAS memory cost:**
- Each item stores an 8-byte CAS token
- Disable with `-C` flag to save 8 bytes per item (useful if CAS is never needed)
- At 100 million items: ~800 MB saved

**CAS with meta commands:**
```
mg mykey v c         # get value + CAS token
-> VA 5 c12345\r\nhello\r\n

ms mykey 5 C12345 T3600\r\nworld\r\n   # set only if CAS matches
-> HD                 (success)
-> EX                 (CAS mismatch)
```

## Extstore (External Storage)

Memcached 1.5.4+ includes **extstore**, which allows offloading large item values to flash/SSD storage while keeping metadata in RAM:

**How it works:**
1. Items above a configurable size threshold are written to an external flash device
2. Only the item header (key, metadata, pointer) stays in RAM
3. On GET, the value is read from flash (adds latency but saves RAM)
4. Hot items can be promoted back to RAM

**Configuration:**
```bash
-o ext_path=/mnt/ssd/extstore:64G    # External storage path and size
-o ext_item_size=512                   # Minimum item size to offload (bytes)
-o ext_item_age=10                     # Minimum age (seconds) before offloading
-o ext_low_ttl=3600                    # Items with TTL < this stay in RAM
-o ext_wbuf_size=8388608               # Write buffer size (8 MB)
-o ext_threads=1                       # I/O threads for extstore
```

**Trade-offs:**
- Greatly increases effective cache size (RAM for metadata + SSD for values)
- Increases GET latency for offloaded items (SSD read ~100us vs RAM ~1us)
- Write amplification on SSD (compaction, rewriting)
- Best for large items (> 512 bytes) with moderate access frequency

## Memory Layout Example

For a Memcached instance with `-m 4096 -f 1.25 -n 48`:

```
Total memory: 4096 MB
Item overhead: ~56 bytes (with CAS)

Slab Class 1: chunk = 96B, items/page = 10,922
  Item capacity: key + value <= 40 bytes
  
Slab Class 5: chunk = 240B, items/page = 4,369
  Item capacity: key + value <= 184 bytes
  
Slab Class 10: chunk = 736B, items/page = 1,424
  Item capacity: key + value <= 680 bytes
  
Slab Class 15: chunk = 2,272B, items/page = 461
  Item capacity: key + value <= 2,216 bytes
  
Slab Class 20: chunk = 6,944B, items/page = 150
  Item capacity: key + value <= 6,888 bytes
  
Slab Class 30: chunk = 65,632B, items/page = 15
  Item capacity: key + value <= 65,576 bytes
  
Slab Class 42: chunk = 1,048,576B (1 MB), items/page = 1
  Item capacity: key + value <= 1,048,520 bytes
```

**Capacity estimation formula:**
```
items_per_class = (total_memory * fraction_for_class) / chunk_size
total_items = sum(items_per_class) for all active classes

Example: 4 GB, all items ~200 bytes, using class 5 (240B chunks)
  pages_for_class = 4096 (all memory for one class)
  chunks_per_page = 1,048,576 / 240 = 4,369
  total_items = 4,096 * 4,369 = ~17.9 million items
```
