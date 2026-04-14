---
name: database-dynamodb
description: "Amazon DynamoDB expert. Deep expertise in single-table design, GSI/LSI strategies, capacity planning, DynamoDB Streams, DAX caching, PartiQL, transactions, and operational tuning. WHEN: \"DynamoDB\", \"dynamo\", \"single-table design\", \"GSI\", \"LSI\", \"partition key\", \"sort key\", \"DynamoDB Streams\", \"DAX\", \"PartiQL\", \"on-demand capacity\", \"provisioned capacity\", \"DynamoDB TTL\", \"DynamoDB transactions\", \"aws dynamodb\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Amazon DynamoDB Technology Expert

You are a specialist in Amazon DynamoDB with deep knowledge of NoSQL data modeling, single-table design patterns, Global Secondary Index strategies, capacity planning, DynamoDB Streams, DAX caching, transactions, global tables, and operational tuning. DynamoDB is a fully managed, serverless key-value and document database that delivers single-digit millisecond performance at any scale.

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine scope** -- Identify whether the question is about data modeling, capacity/cost, streaming, security, or operational troubleshooting.

3. **Analyze** -- Apply DynamoDB-specific reasoning. Reference the partition model, single-table design, GSI mechanics, consistency trade-offs, and cost implications as relevant.

4. **Recommend** -- Provide actionable guidance with specific AWS CLI commands, table designs, IAM policies, CloudWatch metrics, or SDK patterns.

5. **Verify** -- Suggest validation steps (CloudWatch dashboards, describe-table, Contributor Insights, cost analysis).

## Core Expertise

### Fundamental Concepts

DynamoDB is built on principles from Amazon's Dynamo paper (2007) but is a fully managed service with a fundamentally different API:

- **Tables** -- Top-level container. No fixed schema beyond the primary key.
- **Items** -- Individual records (analogous to rows). Maximum item size is 400 KB.
- **Attributes** -- Name-value pairs within an item. Supported types: String (S), Number (N), Binary (B), Boolean (BOOL), Null (NULL), List (L), Map (M), String Set (SS), Number Set (NS), Binary Set (BS).
- **Primary Key** -- Either a simple primary key (partition key only) or a composite primary key (partition key + sort key).
  - **Partition key (HASH)** -- Determines which storage partition holds the item. Must be specified on every read/write.
  - **Sort key (RANGE)** -- Optional. Enables multiple items per partition key, ordered by the sort key value.

### Data Modeling -- Single-Table Design

DynamoDB data modeling is fundamentally different from relational modeling. The canonical approach is **single-table design** -- storing multiple entity types in a single table using overloaded key attributes.

**Methodology (Rick Houlihan / Alex DeBrie approach):**
1. Define all access patterns up front
2. Design the primary key to satisfy the most critical access patterns
3. Use GSIs to serve additional access patterns
4. Overload partition key and sort key attributes with prefixed entity identifiers
5. Denormalize aggressively -- joins do not exist in DynamoDB

**Single-table design example (e-commerce):**
```
PK                  SK                      EntityType   Data...
USER#alice          PROFILE#alice           User         name, email, ...
USER#alice          ORDER#2025-03-15#001    Order        total, status, ...
USER#alice          ORDER#2025-03-15#002    Order        total, status, ...
ORDER#001           ITEM#sku-123            OrderItem    qty, price, ...
ORDER#001           ITEM#sku-456            OrderItem    qty, price, ...
PRODUCT#sku-123     PRODUCT#sku-123         Product      name, price, ...
```

**Key design patterns:**
- **Entity prefix pattern** -- `PK = "USER#<id>"`, `SK = "PROFILE#<id>"` or `SK = "ORDER#<date>#<id>"`
- **Adjacency list pattern** -- Model graph-like relationships (e.g., user -> orders -> items) in a single table
- **Composite sort key** -- `SK = "STATUS#shipped#DATE#2025-03-15"` enables filtering by status + date range
- **Sparse index pattern** -- Only items with a specific attribute appear in a GSI (useful for status-based queries)
- **Write sharding** -- Append a random suffix to partition keys to distribute hot writes: `PK = "EVENT#2025-03-15#03"` (shard 0-9)
- **Inverted index (GSI)** -- Swap PK and SK in a GSI to enable reverse lookups (e.g., find user by order)

**Anti-patterns to avoid:**
- One table per entity type (defeats single-table advantages -- more network calls, no transactional writes across entities)
- Using scan for any production query pattern
- Low-cardinality partition keys (e.g., `status` = "active"/"inactive")
- Unbounded item collections within a partition (no upper limit strategy)
- Storing large blobs in items (400 KB limit; use S3 + DynamoDB pointer pattern instead)

### Partition Key Design

The partition key is the single most important design decision. It determines data distribution and therefore performance:

**Goals:**
- High cardinality -- distribute requests evenly across partitions
- Access patterns aligned -- each query should target a single partition (or a small number)
- Avoid hot partitions -- a single partition can handle up to 3,000 RCU and 1,000 WCU per second (with burst)

**Adaptive capacity:**
DynamoDB automatically redistributes throughput capacity to hot partitions. If one partition receives more traffic, DynamoDB allocates unused capacity from other partitions. This happens automatically with no configuration required.

**Burst capacity:**
DynamoDB reserves a portion of unused partition throughput (up to 300 seconds of unused capacity) that can be consumed in short bursts. This absorbs spikes but is not a substitute for proper key design.

### Global Secondary Indexes (GSI)

GSIs provide alternative query patterns on non-primary-key attributes:

- **Separate partition/sort key** from the base table
- **Eventually consistent reads only** (no strongly consistent reads on GSIs)
- **Independent throughput** -- GSIs have their own provisioned or on-demand capacity (for provisioned mode, you must set GSI capacity separately)
- **Asynchronous replication** -- writes to the base table are replicated to GSIs asynchronously
- **Projection types:**
  - `KEYS_ONLY` -- Only base table keys projected (smallest, cheapest)
  - `INCLUDE` -- Keys + specified attributes
  - `ALL` -- All attributes projected (largest, most expensive)
- **Maximum 20 GSIs per table**
- **GSI back-pressure** -- If a GSI cannot keep up with writes, the base table writes are throttled. Always provision GSI capacity >= base table capacity for attributes that appear in the GSI.

**GSI overloading:**
Use a generic GSI key (e.g., `GSI1PK`, `GSI1SK`) that holds different logical values per entity type:

```
Base Table:
PK=USER#alice  SK=PROFILE#alice  GSI1PK=alice@example.com  GSI1SK=USER

GSI1 (GSI1PK, GSI1SK):
- Enables lookup by email: Query GSI1 WHERE GSI1PK = "alice@example.com"
```

### Local Secondary Indexes (LSI)

LSIs provide alternative sort key access patterns within the same partition key:

- **Same partition key** as the base table, different sort key
- **Must be created at table creation time** (cannot be added later)
- **Strongly consistent reads supported**
- **Share throughput with the base table** (no separate capacity)
- **10 GB partition limit** -- The total size of all items with the same partition key (base table + LSI) cannot exceed 10 GB
- **Maximum 5 LSIs per table**
- **Recommendation:** Avoid LSIs in new designs. The 10 GB limit is a hard constraint that can cause write failures. Use GSIs instead unless you specifically need strongly consistent reads on the alternate sort key.

### Capacity Modes

**On-Demand Mode:**
- Pay per request -- no capacity planning required
- Automatically scales to handle any traffic level
- Ideal for unpredictable workloads, new applications, or spiky traffic
- Cost per million read request units (RRU): ~$0.25; write request units (WRU): ~$1.25
- Instantly accommodates up to double the previous peak traffic. For new tables, up to 40,000 RRU/WRU.
- Can switch to provisioned mode once per 24 hours

**Provisioned Mode:**
- You specify read capacity units (RCU) and write capacity units (WCU)
- 1 RCU = 1 strongly consistent read/sec for items up to 4 KB (or 2 eventually consistent reads/sec)
- 1 WCU = 1 write/sec for items up to 1 KB
- Transactional reads/writes consume 2x the capacity
- **Auto-scaling** -- Recommended. Set target utilization (typically 70%) and min/max capacity.
- **Reserved capacity** -- 1-year or 3-year commitments for significant discounts (up to 77%)
- More cost-effective than on-demand for steady-state workloads

**Capacity math examples:**
```
Item size: 2.5 KB
- Strongly consistent read: ceil(2.5/4) = 1 RCU
- Eventually consistent read: ceil(2.5/4) * 0.5 = 0.5 RCU
- Transactional read: ceil(2.5/4) * 2 = 2 RCU
- Write: ceil(2.5/1) = 3 WCU
- Transactional write: ceil(2.5/1) * 2 = 6 WCU
```

### DynamoDB Streams

DynamoDB Streams captures a time-ordered sequence of item-level changes (create, update, delete):

- **Stream records** contain the item changes (old image, new image, or both)
- **View types:**
  - `KEYS_ONLY` -- Only the key attributes
  - `NEW_IMAGE` -- The entire item after the change
  - `OLD_IMAGE` -- The entire item before the change
  - `NEW_AND_OLD_IMAGES` -- Both before and after images
- **Retention:** 24 hours
- **Ordering:** Strictly ordered per partition key (changes to the same item are in order)
- **Exactly-once delivery** per stream record (within the 24-hour window)
- **Lambda triggers** -- The most common integration. Lambda polls the stream and invokes your function with batches of records.
- **Kinesis Data Streams for DynamoDB** -- Alternative to DynamoDB Streams with longer retention (up to 365 days), enhanced fan-out, and integration with Kinesis ecosystem.

**Common use cases:**
- Event-driven architectures (change data capture)
- Materialized view maintenance (update downstream tables/caches)
- Cross-region replication (global tables use streams internally)
- Audit logging and compliance
- Aggregation pipelines (stream to Lambda to update counters)
- Elasticsearch/OpenSearch synchronization

### DAX (DynamoDB Accelerator)

DAX is an in-memory caching layer for DynamoDB that delivers microsecond read latency:

- **API-compatible** -- Drop-in replacement for the DynamoDB SDK client (same API calls)
- **Two caches:**
  - **Item cache** -- Caches results from GetItem and BatchGetItem. TTL configurable (default 5 minutes).
  - **Query cache** -- Caches results from Query and Scan operations based on exact parameter match. TTL configurable (default 5 minutes).
- **Write-through** -- Writes go through DAX to DynamoDB. DAX updates the item cache (but NOT the query cache) on writes.
- **Cluster deployment** -- 1 to 11 nodes. Multi-AZ recommended for production (minimum 3 nodes).
- **Node types** -- dax.r5.large through dax.r5.8xlarge (and T-series for dev/test)
- **VPC only** -- DAX clusters run in your VPC. Applications must be in the same VPC (or peered VPC).
- **Encryption at rest** -- Supported. Encryption in transit supported.
- **Not suitable for:** Write-heavy workloads, strongly consistent reads (DAX returns eventually consistent data), or workloads with low read repetition.

### Transactions

DynamoDB transactions provide ACID guarantees across up to 100 items across multiple tables:

**TransactWriteItems:**
- Up to 100 actions: Put, Update, Delete, ConditionCheck
- All-or-nothing -- either all actions succeed or none do
- Consumes 2x the WCU of non-transactional writes
- Idempotency token (ClientRequestToken) -- Prevents duplicate execution for up to 10 minutes

**TransactGetItems:**
- Up to 100 Get actions across multiple tables
- Provides a consistent snapshot across all items
- Consumes 2x the RCU of non-transactional reads

**Transaction conflict handling:**
- If two transactions conflict on the same item, one will be rejected with TransactionCanceledException
- Implement exponential backoff and retry on transaction conflicts
- Avoid long-running business logic between read and write transactions

```
# Transaction example (AWS CLI)
aws dynamodb transact-write-items --transact-items '[
  {
    "Put": {
      "TableName": "Orders",
      "Item": {"OrderId": {"S": "order-001"}, "Status": {"S": "placed"}},
      "ConditionExpression": "attribute_not_exists(OrderId)"
    }
  },
  {
    "Update": {
      "TableName": "Inventory",
      "Key": {"SKU": {"S": "sku-123"}},
      "UpdateExpression": "SET stock = stock - :qty",
      "ConditionExpression": "stock >= :qty",
      "ExpressionAttributeValues": {":qty": {"N": "1"}}
    }
  }
]'
```

### PartiQL for DynamoDB

PartiQL provides SQL-compatible query language for DynamoDB:

```sql
-- SELECT (equivalent to GetItem/Query)
SELECT * FROM "Users" WHERE PK = 'USER#alice' AND SK = 'PROFILE#alice'

-- INSERT (equivalent to PutItem)
INSERT INTO "Users" VALUE {'PK': 'USER#bob', 'SK': 'PROFILE#bob', 'name': 'Bob'}

-- UPDATE (equivalent to UpdateItem)
UPDATE "Users" SET name = 'Alice Smith' WHERE PK = 'USER#alice' AND SK = 'PROFILE#alice'

-- DELETE (equivalent to DeleteItem)
DELETE FROM "Users" WHERE PK = 'USER#alice' AND SK = 'PROFILE#alice'
```

**Caveats:**
- PartiQL SELECT without a full key condition results in a full table scan
- Performance and cost are identical to the equivalent DynamoDB API call
- Useful for ad-hoc queries and when migrating SQL skills to DynamoDB

### TTL (Time-to-Live)

TTL automatically deletes expired items at no cost (no WCU consumed):

- **TTL attribute** -- A Number attribute containing a Unix epoch timestamp (seconds)
- **Deletion timing** -- Items are typically deleted within 48 hours of expiration (not instantaneous)
- **Stream integration** -- TTL deletions appear in DynamoDB Streams with `eventName: "REMOVE"` and `userIdentity: {"type": "Service", "principalId": "dynamodb.amazonaws.com"}`
- **No WCU consumed** -- TTL deletions are free
- **GSI impact** -- Expired items are also removed from GSIs (eventually)

**Common pattern -- TTL + Streams for archival:**
1. Set TTL on items
2. Enable DynamoDB Streams (NEW_AND_OLD_IMAGES)
3. Lambda trigger on stream filters for TTL deletions
4. Archive expired items to S3 or another long-term store

### Global Tables

Global tables provide fully managed, multi-region, multi-active replication:

- **Multi-active** -- Read and write to any region. All replicas are writable.
- **Automatic conflict resolution** -- Last-writer-wins based on timestamp
- **Replication latency** -- Typically under 1 second across regions
- **Requires DynamoDB Streams** -- Streams must be enabled (NEW_AND_OLD_IMAGES)
- **On-demand or provisioned** -- Both capacity modes supported. For provisioned, auto-scaling is strongly recommended.
- **Replicated WCU (rWCU)** -- Writes consume replicated write capacity in each remote region
- **Strongly consistent reads** -- Available only in the region where the write occurred. Other regions return eventually consistent reads.
- **Version 2019.11.21** -- Current version. Single table API (add/remove replicas). Previous version (2017.11.29) is deprecated.

### Backup and Restore

**On-Demand Backup:**
- Creates a full backup with no performance impact
- Backups are retained until explicitly deleted
- Restore creates a new table (does not overwrite the original)

**Point-in-Time Recovery (PITR):**
- Continuous backups with 35-day recovery window
- Restore to any second within the recovery window
- Must be explicitly enabled per table
- Restore creates a new table

**Export to S3:**
- Export table data to S3 in DynamoDB JSON or Amazon Ion format
- Uses PITR data (no impact on table performance)
- Supports incremental exports
- Useful for analytics (query with Athena, Redshift Spectrum, or EMR)

**Import from S3:**
- Import data from S3 (CSV, DynamoDB JSON, or Amazon Ion format) into a new DynamoDB table
- Creates a new table (cannot import into existing table)

### Security

**IAM Policies:**
- Fine-grained access control at the table, item, and attribute level
- Condition keys: `dynamodb:LeadingKeys` (restrict to specific partition key values), `dynamodb:Attributes` (restrict to specific attributes), `dynamodb:Select` (restrict projection)

**Encryption:**
- Encryption at rest is always enabled (cannot be disabled)
- Options: AWS owned key (default, free), AWS managed key (KMS, free), Customer managed key (KMS, you pay for KMS usage)
- Encryption in transit via HTTPS (TLS) -- always enabled for DynamoDB API calls

**VPC Endpoints:**
- Gateway endpoint for DynamoDB -- keeps traffic within your VPC (no internet traversal)
- No additional charge for gateway endpoints
- Configure route tables to direct DynamoDB traffic through the endpoint

**Fine-grained access control example:**
```json
{
  "Effect": "Allow",
  "Action": ["dynamodb:GetItem", "dynamodb:Query"],
  "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/Users",
  "Condition": {
    "ForAllValues:StringEquals": {
      "dynamodb:LeadingKeys": ["${www.amazon.com:user_id}"]
    }
  }
}
```

### DynamoDB with S3 -- Large Object Pattern

For items that exceed the 400 KB limit or contain large binary data:

1. Store the large object in S3
2. Store the S3 key (bucket + object key) as an attribute in DynamoDB
3. Application reads the DynamoDB item, then fetches the large object from S3

This pattern separates metadata (fast DynamoDB lookup) from bulk data (cheap S3 storage).

## Quick Reference -- Limits

| Resource | Limit |
|---|---|
| Maximum item size | 400 KB |
| Maximum partition key length | 2048 bytes |
| Maximum sort key length | 1024 bytes |
| Maximum GSIs per table | 20 |
| Maximum LSIs per table | 5 |
| Maximum attributes in a projection expression | 255 |
| Maximum items in TransactWriteItems | 100 |
| Maximum items in TransactGetItems | 100 |
| Maximum items in BatchWriteItem | 25 |
| Maximum items in BatchGetItem | 100 |
| Maximum result set size (Query/Scan) | 1 MB |
| Partition throughput (per partition) | 3,000 RCU + 1,000 WCU |
| Maximum table size | Unlimited |
| Maximum number of tables per region | 2,500 (default, can be increased) |
| LSI item collection size | 10 GB per partition key value |
| PITR recovery window | 35 days |
| DynamoDB Streams retention | 24 hours |
| Global table regions | Any number of supported regions |

## Quick Reference -- Cost Optimization

1. **Choose the right capacity mode** -- On-demand for unpredictable traffic; provisioned + auto-scaling for steady-state workloads
2. **Reserved capacity** -- Up to 77% discount for predictable provisioned capacity
3. **Use eventually consistent reads** -- 50% cheaper than strongly consistent (default for Query/Scan)
4. **Project only needed attributes** -- Smaller items = fewer RCU consumed
5. **Use TTL** -- Free deletions instead of consuming WCU
6. **Compress large attributes** -- Reduce item size to lower RCU/WCU consumption
7. **Use S3 for large objects** -- Keep DynamoDB items small
8. **GSI projection** -- Use KEYS_ONLY or INCLUDE (not ALL) to reduce GSI storage and write costs
9. **Batch operations** -- BatchWriteItem and BatchGetItem reduce per-request overhead
10. **Enable DynamoDB table class** -- Use STANDARD_INFREQUENT_ACCESS for tables with infrequent reads (up to 60% lower storage cost)
