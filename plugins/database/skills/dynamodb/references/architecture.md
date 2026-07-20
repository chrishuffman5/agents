# Amazon DynamoDB Architecture Reference

## Storage Architecture

### Partition Model

DynamoDB distributes data across partitions. Each partition is a unit of storage and throughput:

- **Partition size limit:** 10 GB of data per partition
- **Partition throughput limit:** 3,000 read capacity units (RCU) + 1,000 write capacity units (WCU) per second per partition
- **Hash-based distribution:** The partition key is hashed using an internal hash function to determine which partition stores the item
- **Automatic splitting:** When a partition exceeds its size or throughput limit, DynamoDB automatically splits it into two partitions. Splits are transparent to the application.
- **No manual control:** You cannot directly control partitioning. You influence it through partition key design.

### Partition Allocation

DynamoDB allocates partitions based on:

1. **Storage:** ceil(Total table size / 10 GB)
2. **Throughput:** ceil((RCU / 3000) + (WCU / 1000))
3. **Actual partitions** = max(storage-based, throughput-based)

Example: A table with 50 GB of data and 5,000 RCU / 2,000 WCU:
- Storage-based: ceil(50 / 10) = 5 partitions
- Throughput-based: ceil(5000/3000 + 2000/1000) = ceil(1.67 + 2) = ceil(3.67) = 4 partitions
- Actual: max(5, 4) = 5 partitions

### Storage Nodes and Replication

Each partition is replicated across **three storage nodes** in different Availability Zones within a region:

- **One leader node** -- Handles all writes and strongly consistent reads
- **Two follower nodes** -- Handle eventually consistent reads and participate in replication
- **Paxos-based leader election** -- If the leader fails, a follower is promoted via Paxos consensus
- **Synchronous replication for writes:** A write is acknowledged when 2 of 3 nodes confirm (quorum write)
- **Replication lag:** Follower nodes typically lag by milliseconds. Eventually consistent reads may return slightly stale data.

### B-Tree Implementation

DynamoDB uses a B-tree variant for indexing within each partition:

- **Partition key lookup** is O(1) via the hash function to locate the partition, then O(log n) within the B-tree
- **Sort key range queries** are efficient because items with the same partition key are stored contiguously, sorted by the sort key
- **B-tree pages** are the unit of storage I/O. Reading a single item may require traversing several B-tree levels.
- **No LSM-tree** -- Unlike Cassandra or HBase, DynamoDB uses a B-tree structure, which provides consistent read latency but requires in-place updates

### Request Router

Every DynamoDB API call goes through the **request router**, a stateless fleet of servers:

1. Client sends HTTPS request to the DynamoDB endpoint (e.g., `dynamodb.us-east-1.amazonaws.com`)
2. Request router authenticates the request (IAM/SigV4)
3. Request router looks up the table metadata to find which partition holds the target data
4. Request router routes the request to the appropriate storage node:
   - **Writes** -- Always routed to the leader node
   - **Strongly consistent reads** -- Routed to the leader node
   - **Eventually consistent reads** -- Routed to any replica (often a follower for load distribution)
5. Storage node processes the request and returns the result through the request router

### Table Metadata

Table metadata is stored in a highly available metadata service:

- **Table schema** -- Primary key definition, GSI/LSI definitions, stream settings
- **Partition map** -- Mapping from hash key ranges to storage nodes
- **Capacity settings** -- Provisioned throughput, auto-scaling configuration
- **Encryption settings** -- KMS key information
- Metadata is cached in request routers for fast lookup (refreshed on table updates)

## Consistency Models

### Eventually Consistent Reads

- Default for Query and Scan operations
- May return data that does not reflect the most recent write
- Reads can be served by any of the three replica nodes
- Typically consistent within milliseconds, but no guarantee
- Consumes half the RCU of a strongly consistent read

### Strongly Consistent Reads

- Must be explicitly requested (`ConsistentRead: true`)
- Always reads from the leader node
- Guarantees the most recent committed write is returned
- Consumes full RCU (1 RCU = 1 strongly consistent read for items up to 4 KB)
- Higher latency than eventually consistent reads (must read from leader)
- Not available on GSIs (GSIs are always eventually consistent)
- Not available across regions in global tables

### Transactional Consistency

DynamoDB transactions use a variant of **two-phase commit** with optimistic concurrency:

**TransactWriteItems protocol:**
1. **Prepare phase:** The transaction coordinator sends the full transaction to each storage node involved. Each node validates the condition expressions against current data and acquires a lock on the items.
2. **Commit phase:** If all nodes successfully prepared, the coordinator sends commit. All nodes apply the mutations and release locks.
3. **Rollback:** If any node fails to prepare (condition check failure, conflict), the coordinator sends rollback to all nodes.

**Isolation level:** Serializable for items within the transaction. No cross-transaction isolation (two transactions on different items can interleave).

**Transaction conflicts:**
- Two transactions touching the same item will conflict
- One succeeds, the other receives `TransactionCanceledException`
- Conflicts are detected at the item level (not attribute level)
- The DynamoDB SDK automatically retries with exponential backoff (configurable)

**Idempotency tokens:**
- `ClientRequestToken` parameter ensures at-most-once execution
- If the same token is resubmitted within 10 minutes, DynamoDB returns the same result without re-executing
- Essential for exactly-once semantics in distributed systems

## Adaptive Capacity

### How Adaptive Capacity Works

Adaptive capacity automatically distributes throughput capacity to partitions that need it:

1. **Baseline allocation:** Each partition initially gets an equal share of the table's total capacity. For a table with 1,000 WCU and 10 partitions, each partition gets 100 WCU baseline.
2. **Traffic monitoring:** DynamoDB continuously monitors per-partition traffic
3. **Capacity redistribution:** When a partition receives more traffic than its baseline, DynamoDB borrows unused capacity from other partitions
4. **Instant activation:** Adaptive capacity kicks in within 1-5 minutes of detecting an imbalance
5. **Table-level limit:** Total consumption across all partitions cannot exceed the table's provisioned capacity

**Example scenario:**
- Table: 1,000 WCU, 10 partitions (100 WCU each baseline)
- Partition A receives 500 writes/sec (5x its baseline)
- Partitions B-J receive 10 writes/sec each (90 WCU unused each)
- Adaptive capacity reallocates: Partition A gets 500 WCU, remaining 500 WCU distributed among B-J
- Result: No throttling as long as total does not exceed 1,000 WCU

**Limitations:**
- Cannot exceed the table's total provisioned throughput
- Cannot exceed the per-partition hard limit (3,000 RCU / 1,000 WCU)
- Does not help if multiple partitions are simultaneously hot

### Burst Capacity

DynamoDB reserves unused partition throughput for short bursts:

- **Burst pool:** Up to 300 seconds of unused capacity per partition
- **Example:** A partition with 100 WCU baseline that has been idle for 300 seconds has a burst pool of 30,000 write units
- **Consumption:** Burst capacity is consumed at the same rate as regular capacity
- **Not guaranteed:** DynamoDB may use burst capacity for background maintenance (split operations, replication catch-up)
- **Design guidance:** Do not rely on burst capacity for sustained workloads. It is a safety net, not a feature to engineer around.

## GSI Architecture

### GSI Replication Model

GSIs are separate partitioned tables maintained asynchronously:

1. **Write to base table** -- Application writes an item to the base table
2. **Stream to GSI** -- DynamoDB captures the change and asynchronously replicates relevant attributes to the GSI
3. **GSI write** -- The GSI partition receives the projected attributes and indexes them under the GSI key
4. **Propagation delay** -- Typically milliseconds, but can lag during heavy write loads or GSI throttling

### GSI Back-Pressure

If a GSI cannot keep up with base table writes:

1. GSI write capacity is exhausted (GSI is throttled)
2. DynamoDB propagates back-pressure to the base table
3. **Base table writes are throttled** even if the base table has sufficient capacity
4. This is the most common source of unexpected throttling in DynamoDB

**Mitigation:**
- Always provision GSI capacity >= base table capacity (for the projected attributes)
- Use on-demand capacity mode (GSI scales automatically)
- Monitor `WriteThrottleEvents` on both base table and GSI
- Use `KEYS_ONLY` projection to minimize GSI write costs

### GSI Write Cost

A GSI write is charged whenever a base table write affects the GSI:

- **New item with GSI key:** 1 GSI write (put the item in the GSI)
- **Update that changes GSI key value:** 2 GSI writes (delete old entry + put new entry)
- **Update that changes only projected attributes:** 1 GSI write (update in place)
- **Delete base table item:** 1 GSI write (delete from GSI)
- **Write that does not include GSI key attributes:** 0 GSI writes (sparse index benefit)

### Sparse Indexes

If an item does not contain the GSI partition key attribute, it will not appear in the GSI. This enables a powerful pattern:

```
Base table items:
  {PK: "USER#1", SK: "PROFILE", email: "a@b.com"}              -- no GSI key attr
  {PK: "USER#1", SK: "ORDER#001", status: "shipped", GSI1PK: "shipped"}  -- has GSI key
  {PK: "USER#1", SK: "ORDER#002", status: "pending"}            -- no GSI key attr

GSI1 (GSI1PK as partition key):
  Only contains ORDER#001 (the only item with GSI1PK attribute)
```

This is extremely efficient for querying subsets of data (e.g., all shipped orders, all flagged items).

## DynamoDB Streams Architecture

### Stream Internals

DynamoDB Streams uses a Kinesis-like architecture:

- **Shards** -- Each stream is divided into shards. Shards correspond roughly to table partitions.
- **Shard splitting** -- When a table partition splits, the corresponding stream shard also splits (parent-child relationship)
- **Sequence numbers** -- Each stream record has a monotonically increasing sequence number within a shard
- **Iterator types:**
  - `TRIM_HORIZON` -- Start from the oldest available record
  - `LATEST` -- Start from the most recent record
  - `AT_SEQUENCE_NUMBER` -- Start at a specific sequence number
  - `AFTER_SEQUENCE_NUMBER` -- Start after a specific sequence number

### Lambda Integration

The most common Streams integration is AWS Lambda:

- **Event source mapping** -- Lambda polls the stream (you do not manage polling infrastructure)
- **Batch size** -- 1 to 10,000 records per invocation (default 100)
- **Batch window** -- 0 to 300 seconds (wait for a batch to fill before invoking)
- **Parallelization factor** -- 1 to 10 concurrent Lambda invocations per shard (default 1)
- **Bisect on error** -- If a batch fails, split it in half and retry each half
- **Maximum retry attempts** -- Configurable (default: infinite until record expires from stream)
- **Failure destination** -- Send failed records to SQS or SNS for manual processing

### Kinesis Data Streams Integration

As an alternative to DynamoDB Streams, you can replicate changes to Amazon Kinesis Data Streams:

- **Longer retention** -- Up to 365 days (vs. 24 hours for DynamoDB Streams)
- **Enhanced fan-out** -- Multiple consumers with dedicated throughput
- **Kinesis ecosystem** -- Kinesis Data Analytics, Kinesis Data Firehose, Kinesis Client Library
- **No additional DynamoDB Streams charges** -- You pay for Kinesis Data Streams capacity

## Global Tables Architecture

### Multi-Region Replication

Global tables use DynamoDB Streams to replicate changes across regions:

1. Application writes to a table in Region A
2. DynamoDB Streams captures the change
3. A replication Lambda (managed by DynamoDB) reads the stream and writes to replica tables in Region B, C, etc.
4. Replicated writes are tagged to prevent replication loops

### Conflict Resolution

Global tables use **last-writer-wins** conflict resolution:

- Each write carries a timestamp (`aws:rep:updatetime`)
- If two regions write to the same item concurrently, the write with the later timestamp wins
- Conflict resolution is at the item level (not attribute level)
- **No application-level conflict detection** -- The "losing" write is silently overwritten
- **Design implication:** For use cases requiring conflict detection (e.g., inventory counts), use conditional writes or route all writes for a given entity to a single region

### Replication Attributes

Global tables add system attributes to each item:
- `aws:rep:deleting` -- Marks items being deleted across regions
- `aws:rep:updatetime` -- Timestamp used for conflict resolution
- `aws:rep:updateregion` -- Region where the most recent write occurred

These attributes are reserved and should not be used by application logic.

## DAX Architecture

### Cluster Topology

DAX runs as an in-VPC cluster:

- **Primary node** -- Handles all write operations and cache updates
- **Read replica nodes** -- Handle read operations. Writes are replicated from primary.
- **Endpoint types:**
  - **Cluster endpoint** -- Routes reads to replicas and writes to the primary (recommended)
  - **Node endpoints** -- Direct connection to individual nodes (for debugging)
  - **Reader endpoint** -- Routes reads to replica nodes only
- **Failover** -- If the primary fails, a read replica is automatically promoted (typically within ~10 seconds)

### Cache Behavior

**Item cache (GetItem, BatchGetItem):**
1. Application calls GetItem via DAX client
2. DAX checks the item cache for the exact key
3. Cache hit: Return cached item immediately (microsecond latency)
4. Cache miss: DAX reads from DynamoDB, caches the result, returns to application
5. TTL: Configurable (default 5 minutes). After TTL, the item is evicted.
6. Write-through: PutItem/UpdateItem/DeleteItem via DAX updates the item cache immediately

**Query cache (Query, Scan):**
1. Application calls Query via DAX client
2. DAX computes a cache key from the full request parameters (table, key conditions, filter, projection, etc.)
3. Cache hit: Return cached result set (microsecond latency)
4. Cache miss: DAX executes the query against DynamoDB, caches the result, returns to application
5. TTL: Configurable (default 5 minutes)
6. **Not updated on writes** -- A write to the base table does NOT invalidate or update the query cache. The query cache only refreshes on TTL expiry or explicit cache eviction.

**Cache eviction:**
- LRU (Least Recently Used) eviction when memory is full
- TTL-based eviction for stale entries
- Explicit eviction not directly supported via API (but you can write a dummy item to force item cache invalidation)

### DAX vs. ElastiCache

| Aspect | DAX | ElastiCache (Redis/Memcached) |
|---|---|---|
| API compatibility | Drop-in DynamoDB SDK replacement | Custom caching logic required |
| Cache management | Automatic (write-through for items) | Application-managed |
| Consistency | Eventually consistent only | Application-controlled |
| Use case | DynamoDB read acceleration | General-purpose caching |
| Latency | Microseconds | Sub-millisecond |
| Cost | Higher (dedicated cluster) | Varies |

## Encryption Architecture

### Encryption at Rest

All DynamoDB tables are encrypted at rest. Three key options:

1. **AWS owned key (DEFAULT):** DynamoDB manages the key entirely. No KMS charges. No customer visibility into key rotation.
2. **AWS managed key (`aws/dynamodb`):** Key managed in your AWS KMS account. Automatic annual rotation. You can audit key usage via CloudTrail. Free KMS charges for DynamoDB operations.
3. **Customer managed key (CMK):** You create and manage the key in KMS. You control rotation, policies, and grants. KMS charges apply. Required for cross-account access or custom key policies.

### Encryption in Transit

- All DynamoDB API calls use HTTPS (TLS 1.2+)
- DAX supports encryption in transit (TLS between client and DAX cluster, and between DAX and DynamoDB)
- VPC endpoints keep traffic on the AWS network (no internet traversal)

## Table Classes

DynamoDB offers two table classes:

1. **Standard** -- Default. Balanced cost for storage and throughput.
2. **Standard-Infrequent Access (Standard-IA)** -- Up to 60% lower storage cost, higher per-request cost. Ideal for tables where storage cost dominates (large tables with infrequent access).

Table class can be changed at any time with no downtime or performance impact.

## On-Demand Scaling Architecture

### How On-Demand Scaling Works

On-demand mode uses an adaptive algorithm:

1. **Initial capacity:** New on-demand tables start with capacity to handle up to 40,000 read/write request units per second
2. **Traffic tracking:** DynamoDB continuously monitors request rates
3. **Previous peak tracking:** DynamoDB remembers the table's previous traffic peak
4. **Instant scaling:** The table can instantly accommodate up to double the previous peak
5. **Gradual scaling beyond 2x:** If traffic exceeds 2x the previous peak, DynamoDB scales up within minutes but may briefly throttle
6. **No scale-down penalty:** Capacity is released automatically when traffic drops

### Auto-Scaling for Provisioned Mode

Application Auto Scaling manages provisioned capacity:

1. **Target tracking:** You set a target utilization (e.g., 70% of provisioned capacity)
2. **CloudWatch alarms:** Auto-scaling creates CloudWatch alarms for ConsumedReadCapacityUnits and ConsumedWriteCapacityUnits
3. **Scale-up:** When utilization exceeds target for 2 consecutive 1-minute periods, capacity is increased
4. **Scale-down:** When utilization is below target for 15 consecutive 1-minute periods, capacity is decreased
5. **Min/max bounds:** You set minimum and maximum capacity values
6. **Cool-down periods:** Default 60 seconds for scale-up, 60 seconds for scale-down (configurable via Application Auto Scaling API, not in the DynamoDB console)

## Export/Import Architecture

### Export to S3

Export uses PITR (Point-in-Time Recovery) data:

1. DynamoDB reads from PITR backup storage (no impact on live table performance)
2. Data is written to your S3 bucket in the specified format (DynamoDB JSON or Amazon Ion)
3. Export runs as a background job (can take minutes to hours depending on table size)
4. Supports full export or incremental export (changes since last export)
5. Exported data can be queried with Athena, Redshift Spectrum, EMR, or Glue

### Import from S3

Import creates a new table:

1. Specify source S3 bucket, format (CSV, DynamoDB JSON, or Amazon Ion), and target table schema
2. DynamoDB reads the S3 data and loads it into a new table
3. Import is significantly faster than individual PutItem calls
4. CloudWatch metrics track import progress
5. No WCU consumed during import (import uses dedicated capacity)

## Contributor Insights

Contributor Insights identifies the most accessed and throttled keys:

- **Most accessed keys** -- Top partition keys by read/write request count
- **Most throttled keys** -- Top partition keys experiencing throttling
- **CloudWatch integration** -- Data visible in CloudWatch dashboards and available via GetInsightRuleReport API
- **5-minute granularity** -- Data points every 5 minutes
- **24-hour reporting window** -- Rolling 24-hour view of top keys
- **Cost** -- Charged per table/GSI with Contributor Insights enabled

This is the primary tool for diagnosing hot partition issues. Enable it on any table experiencing throttling.
