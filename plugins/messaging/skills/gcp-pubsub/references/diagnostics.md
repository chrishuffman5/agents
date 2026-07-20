# GCP Pub/Sub Diagnostics Reference

## Unacked Message Buildup

### Diagnosis Steps
1. Check `subscription/oldest_unacked_message_age_by_region` -- growing = consumers falling behind
2. Check `subscription/expired_ack_deadlines_count` -- high = consumers overloaded or ack deadline too short
3. Check `subscription/delivery_latency_health_score` -- 0 = unhealthy
4. Review subscriber application logs for processing errors
5. For ordering keys: check for hot keys blocking progress

### Resolution
- Increase consumer parallelism (add subscriber instances)
- Extend ack deadline to match actual processing time
- Reduce flow control limits to prevent overwhelming individual consumers
- Seek to purge stale backlog if no longer relevant

## Delivery Latency Health Score

Score of 0 or 1 (10-minute window). All criteria must be true for score=1:
- Ack latency P99.9 < 30 seconds
- Negligible seek requests
- Negligible nacked messages
- Negligible expired ack deadlines
- Consistent low message utilization

### Common Causes of Score = 0
| Cause | Resolution |
|---|---|
| High nack rate | Fix processing errors in subscriber |
| High expired ack rate | Increase ack deadline or consumer capacity |
| Recent seek operation | Wait ~1 minute for recovery |
| Push endpoint errors (5xx) | Fix endpoint; check logs |

## Dead-Letter Topic Analysis

### Monitor
```
Metric: subscription/dead_letter_message_count
Alert: > 0 (any unexpected count)
```

### Investigate DLT Messages
Each forwarded message includes attributes:
- `CloudPubSubDeadLetterSourceSubscription`
- `CloudPubSubDeadLetterSourceTopicPublishTime`
- `CloudPubSubDeadLetterSourceMessageId`
- `CloudPubSubDeadLetterSourceDeliveryCount`

Correlate with application logs using source message ID.

### Common DLT Causes
| Cause | Resolution |
|---|---|
| Processing bug | Fix subscriber code; redeploy |
| Schema mismatch | Update subscriber to handle new schema |
| Downstream service unavailable | Fix downstream; replay from DLT |
| Message too large | Increase subscriber memory; implement chunking |

## Push Endpoint Issues

### Push Not Delivering
| Symptom | Cause | Resolution |
|---|---|---|
| No deliveries | Endpoint returning errors | Check `push_request_count` by response_code |
| Exponential backoff | 5xx responses | Fix endpoint; check health |
| 403 Forbidden | JWT verification failing | Configure push auth service account |
| Certificate error | Self-signed or expired cert | Use valid public CA certificate |

### Push Endpoint Debugging
Check `subscription/push_request_count` metric grouped by `response_code`. 2xx = success. 4xx = client error (fix endpoint). 5xx = server error (triggers backoff).

## Cloud Monitoring Metrics

### Subscription Metrics (Critical)

| Metric | Alert Threshold |
|---|---|
| `subscription/num_unacked_messages_by_region` | Rising trend |
| `subscription/oldest_unacked_message_age_by_region` | > processing SLA |
| `subscription/delivery_latency_health_score` | = 0 for > 5 min |
| `subscription/expired_ack_deadlines_count` | > 1% of delivery rate |
| `subscription/dead_letter_message_count` | > 0 |
| `subscription/sent_message_count` | Drop = subscriber issue |

### Topic Metrics

| Metric | Description |
|---|---|
| `topic/send_request_count` | Publish volume (by response_code) |
| `topic/message_sizes` | Message size distribution |

### Recommended Alerts

```
# Backlog growing
pubsub.googleapis.com/subscription/oldest_unacked_message_age_by_region > 300s for 5m

# Health degraded
pubsub.googleapis.com/subscription/delivery_latency_health_score < 1 for 5m

# DLT receiving messages
pubsub.googleapis.com/subscription/dead_letter_message_count > 0
```

## Seek Operations

### Replay from Point in Time
```bash
# Prerequisites: enable retainAckedMessages
gcloud pubsub subscriptions update my-sub --retain-acked-messages

# Seek to timestamp
gcloud pubsub subscriptions seek my-sub --time="2026-01-15T10:00:00Z"
```

### Purge Backlog
```bash
gcloud pubsub subscriptions seek my-sub --time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

### Important Seek Behaviors
- Delivery attempt count resets to 0 after seek
- With exactly-once: pre-seek acks fail; eligible messages redelivered
- With filters: only matching messages redelivered
- Eventually consistent: up to 1 minute to take full effect

## Ordering Key Troubleshooting

### Hot Key Detection
Monitor `subscription/oldest_unacked_message_age_by_region` -- if one key's backlog grows while others are healthy, it is a hot key.

### Resolution
- Increase key cardinality (per-entity rather than per-region)
- Minimize per-message processing time
- Split hot key into sub-keys if ordering is not strictly required within the full key space

### Publisher Ordering Failure Recovery
When publishing with ordering keys fails, the client library blocks subsequent messages for that key. Call `resumePublish()` to unblock.

## Cost Troubleshooting

### Unexpected Storage Charges
- Check for orphaned subscriptions with no consumers (accumulate backlog)
- Verify `retainAckedMessages` is not enabled unnecessarily
- Reduce subscription `messageRetentionDuration` from default 7 days

### High Throughput Costs
- Verify batching is enabled (small messages billed as 1 KB minimum)
- Reduce subscription count (each is a full copy)
- Use BigQuery/Cloud Storage subscriptions for ETL instead of Dataflow
