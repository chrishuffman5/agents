# GCP Pub/Sub Architecture Reference

## Topics

Named resource for publishing. Key properties:
- **Message retention:** 10 min to 31 days (default: none -- retained only until all subscriptions ack)
- **Message ordering:** Must be enabled at creation (immutable). Ordering keys route messages.
- **Schema:** Optional Avro or Protocol Buffers. Non-conforming messages rejected at publish.
- **CMEK:** Customer-managed encryption keys per topic.

```bash
gcloud pubsub topics create orders-topic --message-ordering-enabled
gcloud pubsub topics create events --message-retention-duration=7d
gcloud pubsub topics create typed-events --schema=event-schema --message-encoding=json
```

## Subscription Types

### Pull Subscriptions
Client requests messages (poll model). Streaming pull for lowest latency (bidirectional gRPC). Multiple subscribers compete (each message to one subscriber). Supports exactly-once delivery.

```bash
gcloud pubsub subscriptions create my-sub --topic=my-topic --ack-deadline=120
gcloud pubsub subscriptions pull my-sub --auto-ack --limit=10
```

### Push Subscriptions
HTTP POST to HTTPS endpoint. Auto flow control (server slows on errors). Auth via signed JWT. Best for serverless (Cloud Run, Functions).

```bash
gcloud pubsub subscriptions create push-sub --topic=my-topic \
  --push-endpoint=https://my-service.run.app/handler \
  --push-auth-service-account=sa@project.iam.gserviceaccount.com
```

### BigQuery Subscriptions
Direct export to BigQuery table via Storage Write API. No subscriber process needed. Supports CDC and Single Message Transforms. At-least-once (dedup in BigQuery required).

```bash
gcloud pubsub subscriptions create bq-sub --topic=my-topic \
  --bigquery-table=project:dataset.table
```

### Cloud Storage Subscriptions
Batch messages into GCS objects. Configurable by size or time. Text or Avro format.

```bash
gcloud pubsub subscriptions create gcs-sub --topic=my-topic \
  --cloud-storage-bucket=my-bucket --cloud-storage-max-duration=300s
```

## Ordering Keys

Publishers attach ordering key (up to 1 KB). Same key = delivered in publish order. Different keys = parallel. Strictly regional.

**Throughput limit:** 1 MBps per ordering key. Overall topic throughput not limited by ordering.

**Redelivery with ordering:** When a message is redelivered, all subsequent messages for that key are also redelivered (maintains order integrity).

**Hot keys:** One key receiving messages faster than subscriber can process. Mitigate with high-cardinality keys.

```bash
gcloud pubsub subscriptions create ordered-sub --topic=orders-topic --enable-message-ordering
```

## Exactly-Once Delivery

Pull subscriptions only (not push or export). Subscribers determine ack success. No redelivery after successful ack. Requires same-region clients.

**Trade-offs:** Higher latency than standard. ~1,000 msg/s per ordering key limit.

```bash
gcloud pubsub subscriptions create eo-sub --topic=my-topic --enable-exactly-once-delivery
```

## Dead-Letter Topics

Messages forwarded after max delivery attempts (5-100). Best-effort delivery count tracking.

```bash
gcloud pubsub topics create dlq-topic
gcloud pubsub subscriptions create my-sub --topic=my-topic \
  --dead-letter-topic=dlq-topic --max-delivery-attempts=10

# IAM for Pub/Sub service account
PUBSUB_SA="service-PROJECT_NUM@gcp-sa-pubsub.iam.gserviceaccount.com"
gcloud pubsub topics add-iam-policy-binding dlq-topic \
  --member="serviceAccount:$PUBSUB_SA" --role="roles/pubsub.publisher"
gcloud pubsub subscriptions add-iam-policy-binding my-sub \
  --member="serviceAccount:$PUBSUB_SA" --role="roles/pubsub.subscriber"
```

## Message Filtering

Immutable attribute-based filters on subscriptions:
```
attributes.priority = "high"
attributes.region = "us-east1" AND attributes.tier = "premium"
NOT attributes:debug
hasPrefix(attributes.source, "api-")
```

Max 256 bytes. Applied to attributes only (not body). Case-sensitive.

```bash
gcloud pubsub subscriptions create filtered-sub --topic=my-topic \
  --message-filter='attributes.priority = "high"'
```

## Schema Validation

Avro or Protocol Buffers. Max 300 KB schema. Up to 20 revisions per schema. Non-conforming messages rejected at publish.

```bash
gcloud pubsub schemas create event-schema --type=AVRO --definition-file=event.avsc
gcloud pubsub schemas validate-message --schema-name=event-schema --message-encoding=json \
  --message='{"userId":"abc","eventType":"click","timestamp":1234567890}'
```

## Snapshots and Seek

**Snapshots:** Capture ack state at point in time. Max 7-day lifetime. Seek to snapshot replays specific messages.

**Seek to timestamp:** Requires `retainAckedMessages=true`. Replays all messages after timestamp.

**Seek to now:** Purges all backlog.

```bash
gcloud pubsub snapshots create my-snapshot --subscription=my-sub
gcloud pubsub subscriptions seek my-sub --snapshot=my-snapshot
gcloud pubsub subscriptions seek my-sub --time="2026-01-15T10:00:00Z"
gcloud pubsub subscriptions seek my-sub --time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"  # purge
```

## Flow Control

### Subscriber-Side (Pull)
- `max_messages`: Max unacked messages in client
- `max_bytes`: Max unacked bytes in memory
- Client stops pulling when limits crossed

### Publisher-Side
- `MaxOutstandingMessages`, `MaxOutstandingBytes`
- Overflow behavior: Block, Ignore, or Signal Error

## Message Retention Summary

| Level | Default | Maximum |
|---|---|---|
| Topic retention | None | 31 days |
| Subscription backlog | 7 days | 7 days |
| Acked message retention | Disabled | 7 days |
| Snapshot retention | 7 days - oldest unacked age | 7 days |

## IAM Roles

| Role | Description |
|---|---|
| `roles/pubsub.admin` | Full management |
| `roles/pubsub.editor` | Create/delete topics and subscriptions |
| `roles/pubsub.publisher` | Publish messages |
| `roles/pubsub.subscriber` | Pull/consume messages |
| `roles/pubsub.viewer` | View metadata |
