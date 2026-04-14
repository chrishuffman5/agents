# Google Cloud Pub/Sub — Managed Research

**Research Date:** 2026-04-13
**Scope:** GCP Pub/Sub architecture, subscription types, features, management tooling, best practices, and diagnostics

---

## 1. Architecture Overview

### Publisher-Subscriber Model

Google Cloud Pub/Sub is a fully managed, serverless messaging service designed to decouple event producers from event consumers. It operates asynchronously: publishers send messages to a **topic** without knowing who or what will receive them, and subscribers receive messages through a **subscription** without needing to know who sent them. Typical end-to-end latency is approximately 100 milliseconds.

Key architectural differentiators from partitioned systems like Apache Kafka:
- **Per-message leasing**: Each message is individually leased to a subscriber client rather than assigned to a partition. This maximizes parallelism and allows any subscriber in a group to receive any message.
- **Serverless scaling**: No partition or shard configuration required. The service scales transparently.
- **At-least-once by default**: Pub/Sub guarantees delivery of every message at least once; duplicate handling is the application's responsibility unless exactly-once delivery is enabled.

### Topics

A **topic** is a named resource to which publishers send messages. Topics must be created before publishing. Key topic properties:

- **Message retention duration**: Topics can retain messages for 10 minutes to 31 days (default: none). Without topic-level retention, messages are only held until all subscriptions have acknowledged them.
- **Message ordering**: Must be enabled at topic creation; cannot be changed after creation.
- **Schema**: An optional schema (Avro or Protocol Buffers) can be attached to enforce message format.
- **KMS encryption**: Customer-managed encryption keys (CMEK) can be configured per topic.

**gcloud CLI — Topic management:**
```bash
# Create a topic
gcloud pubsub topics create my-topic

# Create topic with message retention (7 days)
gcloud pubsub topics create my-topic \
  --message-retention-duration=7d

# Create topic with ordering support enabled
gcloud pubsub topics create orders-topic \
  --message-ordering-enabled

# Create topic with schema attached
gcloud pubsub topics create user-events \
  --schema=user-event-schema \
  --message-encoding=json

# List topics
gcloud pubsub topics list

# Delete a topic
gcloud pubsub topics delete my-topic

# Publish a message
gcloud pubsub topics publish my-topic --message="Hello World"

# Publish with ordering key
gcloud pubsub topics publish orders-topic \
  --message='{"orderId":123}' \
  --ordering-key="customer-456"

# Publish with attributes
gcloud pubsub topics publish my-topic \
  --message="event data" \
  --attribute="priority=high,region=us-east1"
```

### Subscriptions

A **subscription** represents a stream of messages from a specific topic delivered to subscriber clients. Multiple subscriptions on the same topic each receive an independent copy of every message (fan-out pattern).

**Core subscription properties:**
- `ackDeadline`: Time window (10–600 seconds, default 60 seconds) a subscriber has to acknowledge a message before it is redelivered.
- `messageRetentionDuration`: How long unacknowledged messages are retained in the subscription (10 minutes to 7 days, default 7 days).
- `retainAckedMessages`: When true, acknowledged messages are also retained for seek/replay operations.
- `expirationPolicy`: Subscriptions expire after 31 days of inactivity by default; set to "never" to disable.

---

## 2. Subscription Types

### 2.1 Pull Subscriptions

The subscriber client explicitly requests messages from the Pub/Sub service (poll model).

**Best for:**
- High-throughput workloads (GBs per second)
- Applications that need to control processing rate
- Cases where exactly-once delivery is required
- Any non-HTTP-accessible compute (batch jobs, VMs behind firewalls)

**Key behaviors:**
- Multiple subscribers can pull from the same subscription; each message is delivered to only one subscriber (competing consumers pattern).
- Client controls acknowledgement deadline extension via `modifyAckDeadline`.
- Supports **streaming pull** (long-lived bidirectional gRPC stream) for lowest latency.
- Flow control is subscriber-managed.

**gcloud CLI:**
```bash
# Create pull subscription
gcloud pubsub subscriptions create my-sub --topic=my-topic

# Create with custom ack deadline (120 seconds)
gcloud pubsub subscriptions create my-sub \
  --topic=my-topic \
  --ack-deadline=120

# Pull messages (blocking)
gcloud pubsub subscriptions pull my-sub --auto-ack --limit=10

# Acknowledge a message
gcloud pubsub subscriptions ack my-sub --ack-ids=ACK_ID
```

### 2.2 Push Subscriptions

Pub/Sub sends messages via HTTP POST to a configured HTTPS endpoint. The service initiates delivery.

**Best for:**
- Cloud Run, Cloud Functions, App Engine (serverless)
- Systems processing multiple topics through a single webhook
- When importing client libraries into the subscriber is not feasible

**Key behaviors:**
- Endpoint must be a public HTTPS server with a valid (non-self-signed) certificate.
- Pub/Sub automatically implements server-side flow control: when the endpoint returns errors, delivery slows.
- Limited to one outstanding message per request (lower throughput than pull).
- Authentication: Pub/Sub can attach a signed JWT to push requests for endpoint verification.

**gcloud CLI:**
```bash
# Create push subscription
gcloud pubsub subscriptions create my-push-sub \
  --topic=my-topic \
  --push-endpoint=https://my-service.run.app/pubsub/push

# Create with authentication
gcloud pubsub subscriptions create my-push-sub \
  --topic=my-topic \
  --push-endpoint=https://my-service.run.app/pubsub/push \
  --push-auth-service-account=my-sa@project.iam.gserviceaccount.com
```

### 2.3 BigQuery Subscriptions (Export)

Messages are written directly to a BigQuery table via the BigQuery Storage Write API without a separate subscriber process.

**How it works:**
1. Pub/Sub batches incoming messages.
2. Writes batches to BigQuery using the Storage Write API.
3. Failed writes are negatively acknowledged and retried.
4. Messages exceeding retry limits are forwarded to a dead-letter topic if configured.

**Schema options:**
- **Topic schema**: Use the topic's Avro/Protobuf schema, mapped to BigQuery column types.
- **Table schema**: Use the BigQuery table's schema to parse JSON message payloads.

**Advanced features:**
- Change Data Capture (CDC): Supports `_CHANGE_TYPE` (UPSERT/DELETE) and `_CHANGE_SEQUENCE_NUMBER` fields.
- Single Message Transforms (SMTs): Lightweight message modifications before writing.
- BigLake Iceberg tables: Compatible with no additional configuration.

**Limitation:** BigQuery subscriptions offer at-least-once delivery, not exactly-once. Downstream deduplication in BigQuery is required for strict exactly-once semantics.

**Type mappings (Avro → BigQuery):**
- `int` → `INTEGER`, `NUMERIC`, or `BIGNUMERIC`
- `string` → `STRING`, `JSON`, `TIMESTAMP`, `DATETIME`, `DATE`, `TIME`
- `bytes` → `BYTES`
- `boolean` → `BOOL`

**gcloud CLI:**
```bash
# Create BigQuery subscription
gcloud pubsub subscriptions create my-bq-sub \
  --topic=my-topic \
  --bigquery-table=my-project:my-dataset.my-table

# With dead-letter topic
gcloud pubsub subscriptions create my-bq-sub \
  --topic=my-topic \
  --bigquery-table=my-project:my-dataset.my-table \
  --dead-letter-topic=my-dlq-topic \
  --max-delivery-attempts=10
```

**IAM requirements:**
```bash
# Grant Pub/Sub service account write access to BigQuery
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:service-PROJECT_NUM@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"
```

### 2.4 Cloud Storage Subscriptions (Export)

Messages are written to a Cloud Storage bucket as files (objects). No separate subscriber client is needed.

**How it works:**
- Messages are batched into objects based on configured size or time thresholds.
- A single batch corresponds to one Cloud Storage object.
- Objects become visible only after successful finalization (two-step ack process).
- Failed writes trigger negative acknowledgment and retry.

**Batch configuration options:**
- Maximum bytes per object
- Maximum time elapsed before finalizing an object
- Filename prefix, suffix, and datetime format

**File formats:** Text (one message per line) or Avro (binary with schema embedded).

**gcloud CLI:**
```bash
# Create Cloud Storage subscription
gcloud pubsub subscriptions create my-gcs-sub \
  --topic=my-topic \
  --cloud-storage-bucket=my-bucket \
  --cloud-storage-filename-prefix=data/ \
  --cloud-storage-max-bytes=100000000 \
  --cloud-storage-max-duration=300s
```

**IAM requirements:**
```bash
gcloud storage buckets add-iam-policy-binding gs://my-bucket \
  --member="serviceAccount:service-PROJECT_NUM@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/storage.objectCreator"
```

---

## 3. Key Features

### 3.1 Message Ordering (Ordering Keys)

**How ordering keys work:**
- Publishers attach an **ordering key** (up to 1 KB string) to each message.
- Messages with the same ordering key published in the same region are delivered in publish order.
- Messages with different ordering keys have no ordering guarantee between them (parallel delivery).
- Ordering is strictly regional: if publishers send messages with the same key from different regions, ordering is not guaranteed.

**Requirements:**
- Topic must have `--message-ordering-enabled` at creation time (immutable).
- Subscription must have ordering enabled (`--enable-message-ordering`).
- For push subscriptions, ordering limits throughput to one outstanding message per ordering key at a time.
- For exactly-once delivery with ordering, acknowledgments must be processed in order.

**Throughput limits:**
- Per-ordering-key publish throughput: **1 MBps** maximum.
- Overall topic throughput is not limited by ordering keys; multiple keys process in parallel.

**Hot keys:**
A hot key occurs when one ordering key receives messages faster than the subscriber can process them, causing backlog to build on a single key. Mitigation:
- Use high-cardinality keys (e.g., `user-{user_id}` rather than `region-us`).
- Minimize per-message processing time.
- Monitor `subscription/oldest_unacked_message_age_by_region` per ordering key.

**Message redelivery with ordering:**
When a message is redelivered, all subsequent messages for that key are also redelivered, even if already acknowledged. This maintains strict order integrity during failures.

**gcloud CLI:**
```bash
# Create subscription with ordering
gcloud pubsub subscriptions create ordered-sub \
  --topic=orders-topic \
  --enable-message-ordering
```

### 3.2 Exactly-Once Delivery

Pub/Sub supports exactly-once delivery on **pull subscriptions only** (not push or export subscriptions).

**How it works:**
- Subscribers can determine if acknowledgments were successful.
- No redelivery occurs after successful acknowledgment.
- No redelivery occurs while a message is outstanding.
- Only the most recent acknowledgment ID is valid; previous IDs are invalidated upon expiration.

**Requirements:**
- Pull subscription only.
- Subscribers must connect to the service in the same region (cross-region deployments risk duplicates).
- Minimum client library versions: Python v2.13.6+, Java v1.139.0+, Go v1.25.1+, Node v3.2.0+.

**Trade-offs:**
- Significantly higher publish-to-subscribe latency than standard subscriptions.
- Ordering throughput limited to approximately 1,000 messages/second per ordering key.

**gcloud CLI:**
```bash
gcloud pubsub subscriptions create my-eo-sub \
  --topic=my-topic \
  --enable-exactly-once-delivery \
  --ack-deadline=60
```

### 3.3 Dead-Letter Topics (DLT)

When a message cannot be acknowledged after a configurable number of delivery attempts, Pub/Sub forwards it to a designated dead-letter topic.

**Configuration details:**
- Max delivery attempts range: **5–100** (default: 5).
- Dead-letter forwarding is best-effort (approximate delivery count).
- Forwarded messages include source subscription attributes, original delivery count, and original publish time.
- The Pub/Sub service account must have publisher access on the DLT and subscriber access on the source subscription.

**gcloud CLI:**
```bash
# Create DLT topic
gcloud pubsub topics create my-dlq-topic

# Create subscription with DLT
gcloud pubsub subscriptions create my-sub \
  --topic=my-topic \
  --dead-letter-topic=my-dlq-topic \
  --max-delivery-attempts=10

# Update existing subscription to add DLT
gcloud pubsub subscriptions update my-sub \
  --dead-letter-topic=my-dlq-topic \
  --max-delivery-attempts=5

# Remove DLT policy
gcloud pubsub subscriptions update my-sub \
  --clear-dead-letter-policy

# Grant IAM permissions to Pub/Sub service account
PUBSUB_SA="service-PROJECT_NUM@gcp-sa-pubsub.iam.gserviceaccount.com"

gcloud pubsub topics add-iam-policy-binding my-dlq-topic \
  --member="serviceAccount:$PUBSUB_SA" \
  --role="roles/pubsub.publisher"

gcloud pubsub subscriptions add-iam-policy-binding my-sub \
  --member="serviceAccount:$PUBSUB_SA" \
  --role="roles/pubsub.subscriber"
```

**Monitoring DLT:**
Use the `subscription/dead_letter_message_count` Cloud Monitoring metric to track forwarded messages.

### 3.4 Message Filtering

Subscriptions can filter incoming messages by attributes before delivery, reducing unnecessary message processing.

**Syntax and operators:**
- `:` — key exists in attributes
- `=` — key equals value
- `!=` — key does not equal value
- `hasPrefix(attributes.key, "prefix")` — prefix match (only supported function)
- `AND`, `OR`, `NOT` — boolean operators (must be uppercase)

**Constraints:**
- Maximum filter length: 256 bytes.
- Filters are **immutable** after subscription creation.
- Filtering applies to **attributes only**, not message data payload.
- Case-sensitive key and value matching.

**Filter examples:**
```
attributes:environment
attributes.priority = "high"
attributes.region = "us-east1" AND attributes.tier = "premium"
NOT attributes:debug
hasPrefix(attributes.source, "api-")
```

**gcloud CLI:**
```bash
# Create pull subscription with filter
gcloud pubsub subscriptions create filtered-sub \
  --topic=my-topic \
  --message-filter='attributes.priority = "high"'

# Create push subscription with filter
gcloud pubsub subscriptions create filtered-push-sub \
  --topic=my-topic \
  --push-endpoint=https://my-service.run.app/handler \
  --message-filter='attributes.region = "us-east1"'
```

### 3.5 Schema Validation (Avro and Protocol Buffers)

Schemas enforce message format at publish time. Non-conforming messages are rejected before they enter the topic.

**Supported schema types:**
- **Apache Avro** (version 1.11): JSON-defined record schemas.
- **Protocol Buffers**: Both proto2 and proto3 syntax.

**Constraints:**
- Only one top-level type allowed (no imports referencing external types).
- Maximum schema definition size: 300 KB.
- Maximum schemas per project: 10,000.
- Maximum revisions per schema: 20.
- Do not include PII in field names (visible in logs and monitoring).

**Avro schema example:**
```json
{
  "type": "record",
  "name": "UserEvent",
  "fields": [
    {"name": "userId", "type": "string", "default": ""},
    {"name": "eventType", "type": "string", "default": ""},
    {"name": "timestamp", "type": "long", "default": 0}
  ]
}
```

**Protocol Buffer schema example:**
```protobuf
syntax = "proto3";
message UserEvent {
  string user_id = 1;
  string event_type = 2;
  int64 timestamp = 3;
}
```

**gcloud CLI:**
```bash
# Create an Avro schema
gcloud pubsub schemas create user-event-schema \
  --type=AVRO \
  --definition-file=user-event.avsc

# Create a Protobuf schema
gcloud pubsub schemas create user-event-proto \
  --type=PROTOCOL_BUFFER \
  --definition-file=user_event.proto

# Attach schema to topic (JSON encoding)
gcloud pubsub topics create user-events \
  --schema=user-event-schema \
  --message-encoding=json

# Attach schema to topic (binary encoding)
gcloud pubsub topics create user-events-binary \
  --schema=user-event-schema \
  --message-encoding=binary

# List schemas
gcloud pubsub schemas list

# Validate a message against a schema
gcloud pubsub schemas validate-message \
  --message-encoding=json \
  --message='{"userId":"abc","eventType":"click","timestamp":1234567890}' \
  --schema-name=user-event-schema
```

**Schema evolution:**
- New schema revisions can be committed; topic retains the revision ID used at publish time.
- Backward-compatible changes (adding optional fields) are safe.
- Breaking changes require schema revision validation before updating topics.
- Each schema supports up to 20 revisions; older revisions can be deleted with `gcloud pubsub schemas delete-revision`.

### 3.6 Snapshots and Seek

The **seek** feature allows bulk modification of message acknowledgment state — either replaying previously acknowledged messages or purging backlog.

**Snapshots:**
- A snapshot captures the acknowledgment state of a subscription at a specific point in time.
- Retains all unacknowledged messages at creation time, plus all subsequently published messages.
- Maximum lifetime: **7 days** (calculated as 7 days minus the age of the oldest unacknowledged message).
- Snapshots cannot be created if they would expire within 1 hour.

**Seek to snapshot vs. seek to timestamp:**

| Aspect | Seek to Snapshot | Seek to Timestamp |
|---|---|---|
| Pre-configuration | Create snapshot ahead of time | Enable `retainAckedMessages` first |
| Precision | High (exact message-level point) | Lower (clock-dependent) |
| Replay capability | Specific acknowledged messages | All messages after timestamp |
| Consistency | Eventually consistent (up to 1 minute) | Eventually consistent (up to 1 minute) |

**gcloud CLI:**
```bash
# Create a snapshot
gcloud pubsub snapshots create my-snapshot \
  --subscription=my-sub \
  --project=my-project

# List snapshots
gcloud pubsub snapshots list

# Seek subscription to snapshot (replay from point-in-time)
gcloud pubsub subscriptions seek my-sub \
  --snapshot=my-snapshot

# Seek to timestamp (replay from time)
gcloud pubsub subscriptions seek my-sub \
  --time="2026-01-15T10:00:00Z"

# Seek to "now" (purge all backlog)
gcloud pubsub subscriptions seek my-sub \
  --time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

**Use cases:**
- Safe deployment recovery: Create snapshot before deploying new subscriber code; seek back if the new code has bugs.
- Bulk purge: Seek to "now" to clear stale backlog.
- Repeatable testing: Seek to snapshot to replay the same dataset consistently.

**Important behaviors with other features:**
- With dead-letter topics: Delivery attempt count resets to 0 after seek.
- With exactly-once delivery: Pre-seek acknowledgments fail; eligible acknowledged messages are redelivered.
- With message filters: Only matching messages are redelivered after seek.

### 3.7 Flow Control

Flow control prevents subscribers from being overwhelmed during traffic spikes.

**Subscriber-side (pull subscriptions):**
Two configurable limits:
1. **Max outstanding messages**: Maximum number of unacknowledged messages held in the client at once.
2. **Max outstanding bytes**: Maximum total size of unacknowledged messages in memory.

When either limit is crossed, the client stops pulling additional messages until existing ones are acknowledged or negatively acknowledged.

**Configuration examples by language:**

*Python:*
```python
from google.pubsub_v1.services.subscriber import SubscriberClient
from google.pubsub_v1.types import FlowControl

flow_control = FlowControl(
    max_messages=100,
    max_bytes=10 * 1024 * 1024  # 10 MiB
)
```

*Go:*
```go
settings := pubsub.ReceiveSettings{
    MaxOutstandingMessages: 100,
    MaxOutstandingBytes:    10 * 1024 * 1024,
}
```

*Java:*
```java
FlowControlSettings flowControlSettings = FlowControlSettings.newBuilder()
    .setMaxOutstandingRequestBytes(10L * 1024 * 1024)
    .setMaxOutstandingElementCount(100L)
    .build();
```

**Publisher-side flow control:**
Prevents the publisher client from overwhelming Pub/Sub during bursts. Configurable with `MaxOutstandingMessages`, `MaxOutstandingBytes`, and overflow behavior (`Block`, `Ignore`, or `Signal Error`).

**Push subscriptions:**
Server-side flow control is automatic. Pub/Sub slows delivery when the endpoint returns errors (5xx, timeouts).

---

## 4. Management Tools

### 4.1 gcloud CLI

All topic, subscription, and schema operations available via `gcloud pubsub`:

```bash
# Subscription operations
gcloud pubsub subscriptions list
gcloud pubsub subscriptions describe my-sub
gcloud pubsub subscriptions modify-push-config my-sub --push-endpoint=https://...
gcloud pubsub subscriptions delete my-sub

# IAM on topics/subscriptions
gcloud pubsub topics add-iam-policy-binding my-topic \
  --member="serviceAccount:sa@project.iam.gserviceaccount.com" \
  --role="roles/pubsub.publisher"

gcloud pubsub subscriptions add-iam-policy-binding my-sub \
  --member="serviceAccount:sa@project.iam.gserviceaccount.com" \
  --role="roles/pubsub.subscriber"
```

### 4.2 Terraform

**Topic with schema and retention:**
```hcl
resource "google_pubsub_schema" "user_event" {
  name       = "user-event-schema"
  type       = "AVRO"
  definition = file("user-event.avsc")
}

resource "google_pubsub_topic" "user_events" {
  name                       = "user-events"
  message_retention_duration = "604800s"  # 7 days

  schema_settings {
    schema   = google_pubsub_schema.user_event.id
    encoding = "JSON"
  }
}
```

**Subscription with DLT and retry policy:**
```hcl
resource "google_pubsub_topic" "dlq" {
  name = "user-events-dlq"
}

resource "google_pubsub_subscription" "user_events_sub" {
  name  = "user-events-processor"
  topic = google_pubsub_topic.user_events.name

  message_retention_duration = "604800s"
  retain_acked_messages      = true
  ack_deadline_seconds       = 60
  enable_message_ordering    = true

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = 10
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }
}
```

**BigQuery subscription:**
```hcl
resource "google_pubsub_subscription" "bq_sub" {
  name  = "events-to-bigquery"
  topic = google_pubsub_topic.user_events.name

  bigquery_config {
    table            = "my-project:my-dataset.events"
    use_topic_schema = true
    write_metadata   = true
  }
}
```

### 4.3 Client Libraries

Supported languages: Python, Java, Go, Node.js, C#, C++, Ruby, PHP.

All support:
- Publishing with batching, ordering keys, and flow control.
- Subscribing with streaming pull, flow control, and exactly-once delivery.
- Schema management (Avro/Protobuf serialization helpers).

### 4.4 Console

The GCP Console provides:
- Topic and subscription creation wizards.
- Subscription health dashboards with delivery latency health score.
- Schema browser and validation tools.
- Monitoring integration with Cloud Monitoring.

---

## 5. Best Practices

### 5.1 Subscription Type Selection

| Scenario | Recommended Type |
|---|---|
| High throughput (GBs/sec), exactly-once needed | Pull (streaming pull) |
| Low/medium throughput, serverless trigger | Push |
| Stream to data warehouse, minimal transformation | BigQuery subscription |
| Archival, batch processing from files | Cloud Storage subscription |
| Fan-out to multiple consumers | Multiple pull subscriptions on same topic |

### 5.2 Ordering Key Design

- Enable ordering on topics that require it at creation time — cannot be changed later.
- Choose the most granular key that provides needed ordering (e.g., `order-{orderId}` not `all-orders`).
- High-cardinality keys (millions of unique keys) distribute load and avoid hot keys.
- Monitor `subscription/oldest_unacked_message_age_by_region` and watch for individual keys with growing backlog.
- Max per-key publish throughput is 1 MBps; design key cardinality accordingly.
- Implement `resumePublish()` in publisher code to recover after ordering key publish failure.

### 5.3 Acknowledgement Deadline Tuning

- Default ack deadline: 60 seconds.
- Set ack deadline to at least the 99th percentile of message processing time.
- For long-running processing, extend the deadline dynamically using `modifyAckDeadline` (maximum extension: 600 seconds).
- Monitor `subscription/expired_ack_deadlines_count`: a small rate (0.1–1%) is acceptable; higher rates indicate overloaded subscribers or deadline misconfiguration.
- Do not acknowledge messages before processing is complete — redelivery after ack requires seek.

### 5.4 Flow Control Tuning

- Start with conservative limits and increase based on measured throughput.
- Typical starting point: 100 outstanding messages, 10 MiB outstanding bytes.
- For CPU-bound subscribers, limit outstanding messages to the number of worker threads.
- For I/O-bound subscribers (DB writes), test higher outstanding message counts.
- Monitor `subscription/num_outstanding_messages` to verify the limit is not chronically saturated.
- Use flow control to allow autoscaling time to respond, rather than dropping messages.

### 5.5 Retry Policies

Retry policy controls the backoff between delivery attempts (applies to pull subscriptions):

```bash
gcloud pubsub subscriptions create my-sub \
  --topic=my-topic \
  --min-retry-delay=10s \
  --max-retry-delay=300s
```

- Default behavior: exponential backoff starting at 10 seconds, maximum 600 seconds.
- Set minimum backoff high enough to avoid thundering-herd during outages.
- Combine retry policy with dead-letter topic for messages that consistently fail.

### 5.6 Schema Evolution

- Add optional fields only for backward-compatible changes.
- Never remove or rename existing fields in a backward-incompatible way.
- Commit new schema revisions and update topics to use the new revision.
- Test new schema revisions with `gcloud pubsub schemas validate-message` before deploying.
- Keep schema definition under 300 KB; split large schemas if needed.

### 5.7 Cost Optimization

**Pricing (as of early 2026):**
- **Free tier**: 10 GiB/month.
- **Throughput**: $40 per TiB beyond free tier.
- **Minimum billing unit**: 1 KB per publish or pull request (small messages billed as 1 KB).
- **Storage**: $0.10–$0.21 per GiB-month; first 24 hours of message storage is free.
- **Data transfer**: Inbound free; same-region free; cross-region at standard egress rates.

**Cost reduction strategies:**
- **Batch messages**: Group small messages to approach 1 KB per publish. A 100-byte message costs the same as a 1 KB message.
- **Use BigQuery/Cloud Storage subscriptions**: Eliminate Dataflow costs for simple ETL pipelines.
- **Minimize subscription count**: Each subscription is an independent copy of every message.
- **Set appropriate retention**: Default 7-day retention on subscriptions incurs storage cost. Reduce if data is not needed for replay.
- **Monitor orphaned subscriptions**: Subscriptions with no active consumers accumulate backlog storage charges.
- **Pub/Sub Lite is deprecated**: Not available to new customers after September 24, 2024; migrates to Managed Service for Apache Kafka or standard Pub/Sub.

---

## 6. Diagnostics

### 6.1 Cloud Monitoring Metrics

**Subscription metrics (most critical):**

| Metric | Description | Alert Threshold |
|---|---|---|
| `subscription/num_unacked_messages_by_region` | Count of unacknowledged messages | Rising trend |
| `subscription/oldest_unacked_message_age_by_region` | Age of oldest pending message (seconds) | > processing SLA |
| `subscription/delivery_latency_health_score` | 0 or 1 — health indicator (10-min window) | Score = 0 |
| `subscription/expired_ack_deadlines_count` | Messages redelivered due to ack timeout | > 1% of delivery rate |
| `subscription/dead_letter_message_count` | Messages forwarded to DLT | Any unexpected count |
| `subscription/sent_message_count` | Messages delivered to subscribers | Drop indicates service issue |
| `subscription/num_outstanding_messages` | Messages currently leased to subscribers | Saturated at flow control limit |
| `subscription/push_request_count` | Push request batches (grouped by response_code) | 4xx/5xx error rate |

**Topic metrics:**

| Metric | Description |
|---|---|
| `topic/send_request_count` | Publish batch volume (by response_code) |
| `topic/message_sizes` | Distribution of individual message sizes |

**Delivery latency health score criteria (all must be true for score=1):**
- Acknowledgment latency (99.9th percentile) < 30 seconds.
- Negligible seek requests.
- Negligible negatively acknowledged (nacked) messages.
- Negligible expired ack deadlines.
- Consistent low message utilization (queue is not chronically full).

### 6.2 Diagnosing Unacked Message Buildup

**Step 1:** Check `subscription/oldest_unacked_message_age_by_region`. If this is growing, consumers are falling behind.

**Step 2:** Check `subscription/expired_ack_deadlines_count`. High expiration rate = consumers are overloaded or processing is too slow relative to ack deadline.

**Step 3:** Check `subscription/delivery_latency_health_score = 0`. Drill into which criterion fails.

**Step 4:** Review subscriber application logs for processing errors.

**Step 5:** If using ordering keys, check for hot keys — one key's backlog can block progress on that key while others remain healthy.

**Remediation options:**
- Increase consumer parallelism (add subscriber instances).
- Extend ack deadline to match actual processing time.
- Reduce flow control limits to prevent overwhelming individual consumers.
- Use seek to purge stale backlog if it is no longer relevant.

### 6.3 Diagnosing High Delivery Latency

**Check:** `subscription/delivery_latency_health_score = 0`.

**Common causes:**
- High nack rate: Application is rejecting messages; check for processing errors.
- High expired ack deadline rate: Processing too slow; increase ack deadline or consumer capacity.
- Seek operations: Seek causes temporary latency spike; normal to resolve within 1 minute.
- Push endpoint returning errors: 5xx responses trigger exponential backoff.

### 6.4 Dead-Letter Topic Analysis

Monitor `subscription/dead_letter_message_count`. For each DLT message:
- Attributes include: `CloudPubSubDeadLetterSourceSubscription`, `CloudPubSubDeadLetterSourceTopicPublishTime`, `CloudPubSubDeadLetterSourceMessageId`, `CloudPubSubDeadLetterSourceDeliveryCount`.
- Use these attributes to correlate with application logs and identify the root cause of processing failures.
- Create a Cloud Monitoring alert when DLT count exceeds a threshold.

### 6.5 Subscription Health Monitoring Setup

**Recommended alerts:**
```
# Alert: Subscription backlog growing (unacked message age > 5 minutes)
Metric: pubsub.googleapis.com/subscription/oldest_unacked_message_age_by_region
Threshold: > 300 seconds for 5 minutes

# Alert: Health score degraded
Metric: pubsub.googleapis.com/subscription/delivery_latency_health_score
Threshold: < 1 for 5 minutes

# Alert: DLT receiving messages
Metric: pubsub.googleapis.com/subscription/dead_letter_message_count
Threshold: > 0
```

---

## 7. Additional Reference

### Message Retention Summary

| Level | Where Configured | Default | Maximum |
|---|---|---|---|
| Topic retention | Topic property | None | 31 days |
| Subscription backlog | Subscription `messageRetentionDuration` | 7 days | 7 days |
| Acknowledged message retention | Subscription `retainAckedMessages` | Disabled | 7 days |
| Snapshot retention | Automatic (7 days - oldest unacked age) | — | 7 days |

### Pub/Sub Service Account Pattern

Every GCP project has a Pub/Sub service account:
```
service-{PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com
```

This service account is used by Pub/Sub for:
- Publishing to dead-letter topics (requires `roles/pubsub.publisher` on DLT).
- Acknowledging from source subscriptions (requires `roles/pubsub.subscriber`).
- Writing to BigQuery tables (requires `roles/bigquery.dataEditor`).
- Writing to Cloud Storage buckets (requires `roles/storage.objectCreator`).

### IAM Roles Reference

| Role | Description |
|---|---|
| `roles/pubsub.admin` | Full management of topics and subscriptions |
| `roles/pubsub.editor` | Create/delete topics and subscriptions |
| `roles/pubsub.publisher` | Publish messages to topics |
| `roles/pubsub.subscriber` | Pull/consume messages from subscriptions |
| `roles/pubsub.viewer` | View topic and subscription metadata |
