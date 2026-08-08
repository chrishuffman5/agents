# AWS Messaging Reference

> SQS, SNS, EventBridge, Kinesis Data Streams, Step Functions selection. Prices are US East (N. Virginia) and PRICE-VOLATILE; quotas are structural facts.

---

## Service Selection Decision Tree

> Source: https://aws.amazon.com/kinesis/data-streams/faqs/ (official)

```
Need asynchronous communication between services?
  Decouple one producer from one consumer ------------ SQS
    Strict ordering + deduplication needed? ---------- SQS FIFO
    At-least-once with best-effort ordering OK? ------ SQS Standard (near-unlimited TPS)
  Fan out one message to many consumers -------------- SNS
    Canonical pattern: SNS -> multiple SQS queues (fan-out plus per-consumer buffering)
  Content-based routing, schema registry, SaaS events  EventBridge
  Ordered stream, multiple independent consumers,
    replay window measured in days ------------------- Kinesis Data Streams
  Workflow orchestration ---------------------------- Step Functions
```

AWS's own Kinesis-vs-SQS split: use Kinesis when you need "routing related records to the same record processor," "ordering of records," or "ability for multiple applications to consume the same stream concurrently." Use SQS when you need per-message acknowledgement and failure semantics, per-message delay, or transparent scaling with no capacity decision.

---

## SQS

> Source: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-messages.html (official)

### Quotas — corrected

| Quota | Value |
|---|---|
| **Maximum message size** | **1,048,576 bytes (1 MiB)** — not 256 KB. Use the S3 Extended Client Library beyond that, up to 2 GB. |
| **Message retention** | **60 seconds minimum**, 14 days maximum, **4 days default** |
| Visibility timeout | 30 s default, 0 s minimum, 12 h maximum |
| FIFO throughput (standard mode) | 300 TPS per API action without batching; up to 3,000 messages/second with 10-message batches |

### FIFO High Throughput Mode

Strict ordering no longer forces you off FIFO at scale. High throughput mode raises FIFO limits far above the classic 300/3,000 ceiling — up to **70,000 TPS non-batched / 700,000 messages per second batched** in us-east-1, us-west-2, and eu-west-1, with lower but still much higher tiers elsewhere (19,000/190,000 in us-east-2 and eu-central-1; 9,000/90,000 in several APAC Regions; 4,500/45,000 in eu-west-2 and sa-east-1; 2,400/24,000 by default elsewhere).

**Directive:** when a design needs both ordering and high throughput, enable high throughput mode and distribute load across `MessageGroupId` values before considering a move to Standard queues or Kinesis.

### Pricing model

> Source: https://aws.amazon.com/sqs/pricing/, https://aws.amazon.com/sqs/faqs/, https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-pricing.html (official)

**The billing model is the answer here; the per-million rates are not published in any fetchable form.** SQS bills **per request plus data transfer** — "cost of Amazon SQS is calculated per request, plus data transfer charges" — with **Standard and FIFO priced separately and FIFO priced higher**, and **the first 1 million SQS requests per month free for all customers**. AWS's rate table renders client-side and yielded no dollar figures across three independent fetch attempts on three official surfaces, so no per-million digit is stated here by design. Read a current figure off the console pricing page or the AWS Pricing Calculator when you need one.

This is rarely the deciding factor anyway: at realistic volumes SQS is cheap enough that **ordering and deduplication requirements, not price, should decide Standard versus FIFO.**

### Cost and reliability levers

- **Long polling.** Set `ReceiveMessageWaitTimeSeconds: 20`. Short polling returns immediately on an empty queue and bills for the empty receive.
- **Batching.** `SendMessageBatch` and `ReceiveMessage` with `MaxNumberOfMessages: 10` cut request count roughly tenfold.
- **Dead-letter queues.** Set `maxReceiveCount` (3 is a reasonable start) so poison messages stop consuming capacity.
- **Visibility timeout** around 6x average processing time. Too short causes duplicate processing; too long delays retries after a consumer failure.

---

## SNS

> Source: https://docs.aws.amazon.com/general/latest/gr/sns.html and https://aws.amazon.com/sns/faqs/ (official)

- **Subscriptions per topic: 12,500,000** for Standard topics; **FIFO topics cap at 100 subscriptions per topic.**
- Pricing: **$0.50 per 1 million SNS requests**; **$0.60 per 1 million HTTP notification deliveries** ($0.06 per 100,000). Free tier: first 1 million requests and first 100,000 HTTP notifications per month.
- **Delivery to SQS and Lambda carries no per-message delivery charge** — AWS charges only for data transferred. This is what makes SNS-to-SQS fan-out cheap.
- Filter policies operate on **message attributes**, which is the key limitation versus EventBridge.

### SNS versus EventBridge

Choose **EventBridge** when you need to filter on the event **body** rather than attributes, archive and replay events, a schema registry for event contracts, third-party SaaS event sources, or cross-account/cross-Region routing with content-based target selection. Choose **SNS** for straightforward fan-out, alerting, and mobile/email/SMS notification, where its lower per-message price and enormous subscription ceiling win.

EventBridge custom-bus publishing is billed per million events; **same-account delivery is free**, cross-account delivery is billed at the same per-million rate as publishing.

---

## Kinesis Data Streams

> Source: https://aws.amazon.com/kinesis/data-streams/pricing/ and https://docs.aws.amazon.com/streams/latest/dev/service-sizes-and-limits.html (official)

### Capacity and limits (confirmed)

- One shard: **1 MB/s and 1,000 records/second in, 2 MB/s out.**
- Retention: **24 hours minimum, 8,760 hours (365 days) maximum.**
- On-Demand: **$0.08/GB ingested plus $0.04/hour per stream.**
- Provisioned: **$0.015/shard-hour plus $0.014 per million PUT payload units** (25 KB each).
- Enhanced Fan-Out: **$0.015 per consumer-shard-hour plus $0.013/GB retrieved.** Dedicated 2 MB/s per consumer instead of a shared 2 MB/s. Worth it only above two consumers per shard.

### On-Demand Advantage mode

A third capacity mode with lower per-GB rates — **$0.032/GB in and $0.016/GB out** versus $0.08/$0.04 for standard On-Demand — in exchange for a **25 MB/s minimum throughput commitment on both ingest and retrieval**. Evaluate it before defaulting a sustained high-volume stream to standard On-Demand or to Provisioned.

Provisioned remains cheaper than standard On-Demand for predictable throughput; the decision is forecastability, not raw volume.

### Kinesis versus SQS

| Aspect | Kinesis Data Streams | SQS |
|---|---|---|
| Model | Ordered event log with replay | Task queue, consumed once |
| Consumers | Many, each replaying the same data | One per message |
| Ordering | Per shard (by partition key) | Best-effort (Standard) or per message group (FIFO) |
| Retention | 24 hours - 365 days | 60 seconds - 14 days |
| Throughput | 1 MB/s per shard, scale by adding shards | Near-unlimited |
| Operational complexity | Higher (shard or capacity-mode management) | Lower |

---

## Cost Shape at Volume

> Source: https://aws.amazon.com/sns/faqs/, https://aws.amazon.com/eventbridge/pricing/, https://aws.amazon.com/kinesis/data-streams/pricing/ (official)

At 10 million messages per month, SQS and SNS are both trivially cheap; EventBridge is roughly an order of magnitude more per event than SNS; Kinesis is dominated by shard-hours rather than message count, so it is cheapest at high sustained volume and most expensive at low volume. **Choose on semantics — ordering, replay, fan-out shape, filtering — and treat cost as a tiebreaker except at very high volume, where Kinesis's shard economics and EventBridge's per-event charge start to matter.**

## Common Integration Patterns

### Fan-out (SNS + SQS)

```
Producer -> SNS topic -+-> SQS queue A -> Service A
                       +-> SQS queue B -> Service B
                       +-> SQS queue C -> Service C
```

Each consumer gets its own buffer, retry policy, and DLQ, and can process at its own rate. SNS filter policies stop unwanted deliveries at the topic.

### Event-driven microservices (EventBridge)

```
Service A -> custom event bus -+-> rule 1 -> Lambda (Service B)
                               +-> rule 2 -> SQS (Service C)
                               +-> rule 3 -> Step Functions (Workflow D)
```

Content-based routing on the event body, schema registry for contracts, archive for replay.

### Stream processing (Kinesis + Lambda)

```
Producers -> Kinesis Data Stream -+-> Lambda (batch processing)
                                  +-> Lambda (real-time analytics)
                                  +-> Data Firehose -> S3 (data lake)
```

Multiple consumers read the same ordered stream; the Lambda event source mapping handles batching and checkpointing.

### Saga (Step Functions)

Step Functions orchestrates the happy path and compensating transactions on failure, with retries, timeouts, and a DLQ for unrecoverable cases. Use Standard workflows for exactly-once semantics and visible execution history.

## Sources

- https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-messages.html
- https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-pricing.html
- https://aws.amazon.com/sqs/pricing/
- https://aws.amazon.com/sqs/faqs/
- https://docs.aws.amazon.com/general/latest/gr/sns.html
- https://aws.amazon.com/sns/pricing/
- https://aws.amazon.com/sns/faqs/
- https://aws.amazon.com/eventbridge/pricing/
- https://aws.amazon.com/kinesis/data-streams/pricing/
- https://aws.amazon.com/kinesis/data-streams/faqs/
- https://docs.aws.amazon.com/streams/latest/dev/service-sizes-and-limits.html
- https://aws.amazon.com/step-functions/pricing/

Fetched: 2026-08-08
