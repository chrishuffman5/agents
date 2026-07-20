# GCP Pub/Sub Best Practices Reference

## Subscription Type Selection

| Scenario | Type |
|---|---|
| High throughput, exactly-once | Pull (streaming pull) |
| Serverless trigger | Push |
| Stream to data warehouse | BigQuery subscription |
| Archival, batch processing | Cloud Storage subscription |
| Fan-out to multiple consumers | Multiple pull subscriptions |

## Ordering Key Design

- Enable ordering on topics at creation (immutable)
- Use most granular key for needed ordering (e.g., `order-{orderId}`)
- High-cardinality keys distribute load and avoid hot keys
- Max per-key publish throughput: 1 MBps
- Monitor `oldest_unacked_message_age_by_region` per key
- Implement `resumePublish()` for recovery after ordering key failure

## Ack Deadline Tuning

- Default: 60 seconds
- Set to at least P99 of processing time
- Extend dynamically with `modifyAckDeadline` (max 600s)
- Monitor `expired_ack_deadlines_count`: 0.1-1% acceptable; higher = overloaded
- Never ack before processing completes

## Flow Control Tuning

Start conservative, increase based on measurements:
- Typical starting point: 100 messages, 10 MiB bytes
- CPU-bound: limit to worker thread count
- I/O-bound: test higher counts
- Monitor `num_outstanding_messages` for chronic saturation

## Retry Policies

```bash
gcloud pubsub subscriptions create my-sub --topic=my-topic \
  --min-retry-delay=10s --max-retry-delay=300s
```

Combine retry policy with dead-letter topic for consistently failing messages.

## Schema Evolution

- Add optional fields only for backward compatibility
- Never remove or rename fields in breaking way
- Test with `gcloud pubsub schemas validate-message` before deployment
- Keep schema < 300 KB; max 20 revisions per schema

## Cost Optimization

**Pricing:** $40/TiB (beyond 10 GiB/month free). Min billing unit: 1 KB per request. Storage: $0.10-0.21/GiB-month. First 24h storage free.

**Strategies:**
- Batch small messages (100-byte message costs same as 1 KB)
- Use BigQuery/Cloud Storage subscriptions to eliminate Dataflow costs
- Minimize subscription count (each is independent copy)
- Set appropriate retention (default 7 days incurs storage cost)
- Monitor orphaned subscriptions (accumulate backlog charges)

## Terraform Examples

```hcl
resource "google_pubsub_topic" "events" {
  name                       = "events"
  message_retention_duration = "604800s"
}

resource "google_pubsub_subscription" "processor" {
  name  = "event-processor"
  topic = google_pubsub_topic.events.name
  ack_deadline_seconds    = 60
  enable_message_ordering = true

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

## gcloud CLI Quick Reference

```bash
# Topics
gcloud pubsub topics create my-topic
gcloud pubsub topics publish my-topic --message="Hello" --attribute="key=value"
gcloud pubsub topics list
gcloud pubsub topics delete my-topic

# Subscriptions
gcloud pubsub subscriptions create my-sub --topic=my-topic
gcloud pubsub subscriptions pull my-sub --auto-ack --limit=10
gcloud pubsub subscriptions seek my-sub --time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
gcloud pubsub subscriptions delete my-sub

# Schemas
gcloud pubsub schemas create schema --type=AVRO --definition-file=schema.avsc
gcloud pubsub schemas validate-message --schema-name=schema --message-encoding=json --message='...'

# IAM
gcloud pubsub topics add-iam-policy-binding my-topic \
  --member="serviceAccount:sa@proj.iam.gserviceaccount.com" --role="roles/pubsub.publisher"
```
