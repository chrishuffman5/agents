# AWS Serverless Reference

> Lambda patterns, API Gateway, Step Functions, EventBridge. Prices are US East (N. Virginia).

---

## Lambda Architecture Patterns

### Lambda Layers

- Share common code/libraries across functions (max 5 layers, 250 MB unzipped total)
- Use for: large dependencies, custom runtimes, shared utility code
- Version layers independently from functions

### Lambda Extensions

- Companion processes alongside your function (monitoring agents, secrets caching)
- Internal extensions run in-process; external extensions run as separate processes
- Use for: observability (Datadog, New Relic), secrets prefetching, custom logging

### Edge Compute Comparison

| Feature | CloudFront Functions | Lambda@Edge |
|---------|---------------------|-------------|
| Runtime | JavaScript only | Node.js, Python |
| Max execution | 1 ms | 5s (viewer) / 30s (origin) |
| Max memory | 2 MB | 128-3008 MB |
| Network access | No | Yes |
| Body access | No | Yes (origin events) |
| Price per request | $0.10/M | $0.60/M |
| Use case | Headers, URL rewrite, redirects, cache key | Auth, A/B testing, origin selection, dynamic content |

**Decision:** CloudFront Functions for simple transformations. Lambda@Edge only for network calls, body access, or >1ms execution.

---

## Lambda Concurrency Management

### Concurrency Types

- **Unreserved (default):** Shares account pool (default 1,000, can request increase). Risk: one function starves others.
- **Reserved:** Guarantees N concurrent slots. Also acts as throttle ceiling. **Free.** Use to protect downstream systems or ensure critical function capacity.
- **Provisioned:** Pre-initializes N environments (warm). Eliminates cold starts. Costs ~$15/mo per instance at 512 MB.

### Concurrency Formula

`Concurrency = Invocations per second x Average duration in seconds`

Example: 200 req/s x 0.5s = 100 concurrent executions

### Scaling Behavior

Lambda adds 500-3,000 instances per minute (region-dependent burst). After burst, scales linearly at 500/minute. For sudden spikes beyond burst, use Provisioned Concurrency or scheduled scaling.

---

## API Gateway

### REST API vs HTTP API

| Feature | REST API | HTTP API |
|---------|----------|----------|
| Price | $3.50/M requests | **$1.00/M requests** (71% cheaper) |
| WebSocket | Separate WebSocket API | No |
| Caching | Built-in | No (use CloudFront) |
| Usage plans/API keys | Yes | No |
| Request validation | Yes | No |
| WAF integration | Yes | No |
| Lambda authorizers | Token + Request | JWT only (native) |
| Private integration | VPC Link | VPC Link |

**Decision:** Use HTTP API by default (cheaper, simpler). Use REST API only when you need caching, usage plans, request validation, or WAF integration.

### Cost Example

2M API requests/month:
- REST API: 2M x $3.50/M = **$7.00/mo**
- HTTP API: 2M x $1.00/M = **$2.00/mo**

### Performance Tips

- Enable payload compression (REST API only): reduces data transfer
- Use Lambda Proxy integration for simplicity
- Set appropriate throttling limits (account default: 10,000 req/s, per-route configurable)
- Use custom domain names with ACM certificates (free TLS)

---

## Step Functions

### Standard vs Express Workflows

| Aspect | Standard | Express |
|--------|----------|---------|
| Max duration | 1 year | 5 minutes |
| Pricing | $0.025/1,000 state transitions | $0.00001667/GB-second (duration-based) |
| Execution model | Exactly-once | At-least-once (async) or at-most-once (sync) |
| Execution history | 90 days in console | CloudWatch Logs only |
| Best for | Long-running orchestration, human approval, error handling | High-volume, short-duration, streaming/IoT |

### Cost Comparison

**100,000 executions with 5 state transitions each:**
- Standard: 500,000 transitions x $0.025/1000 = **$12.50/mo**
- Express (64MB, 1s avg): 100K x 1s x 0.0625 GB x $0.00001667 = **$0.10/mo**

**Decision:** Use Express for high-volume, short-duration workflows (event processing, data transformation). Use Standard for complex orchestration with error handling, retries, and human approval steps.

### Common Patterns

**Map pattern:** Process items in parallel (batch). Each item runs through a sub-workflow. Combine with DynamoDB or S3 for state tracking.

**Error handling:** Use Catch/Retry blocks at each state. Retry with exponential backoff (IntervalSeconds, MaxAttempts, BackoffRate). Catch specific error types before generic.

**Wait pattern:** Pause execution for a duration or until a timestamp. Useful for scheduled processing, SLA timeouts, or human approval flows.

**Callback pattern:** Task token paused until external system calls back with `SendTaskSuccess`/`SendTaskFailure`. For human approval, third-party integration.

---

## EventBridge

### Event-Driven Architecture Patterns

**EventBridge is the default choice for event routing in AWS.** It provides content-based filtering, schema registry, archive/replay, and third-party integrations.

### Event Bus Types

- **Default event bus:** Receives AWS service events (EC2 state changes, S3 events via CloudTrail, etc.)
- **Custom event bus:** Your application events. One per domain/bounded context.
- **Partner event bus:** Third-party SaaS events (Shopify, Zendesk, Auth0)

### Rules and Targets

- Up to 300 rules per event bus, 5 targets per rule
- Content-based filtering on any JSON field (including nested)
- Input transformers: reshape events before delivering to targets
- Dead-letter queues for failed deliveries

### EventBridge Scheduler

- Cron and rate-based scheduling
- One-time scheduled events
- Built-in retry policies
- Cost: $0 for schedules, you pay only for target invocations
- **Replaces CloudWatch Events rules for scheduling.** More flexible, better retry handling.

### EventBridge Pipes

- Point-to-point integration: Source -> (optional filter) -> (optional enrichment) -> Target
- Sources: SQS, Kinesis, DynamoDB Streams, Kafka, MQ
- Enrichment via Lambda, API Gateway, Step Functions
- Cost: $0.40/M events
- Use for simple source-to-target integrations without writing glue code

### Archive and Replay

- Archive events matching specific patterns
- Storage: $0.10/GB
- Replay archived events to any event bus for debugging, testing, or reprocessing
- Set retention period (indefinite or days-based)

---

## Serverless Cost Optimization

### Lambda

1. Use ARM (Graviton2) -- 20% cheaper, often faster
2. Right-size memory with Power Tuning tool
3. Minimize package size (faster cold starts, lower duration)
4. Use Provisioned Concurrency only when needed, with Auto Scaling schedule
5. Avoid VPC attachment unless required (adds cold start latency and ENI costs)

### API Gateway

1. Use HTTP API over REST API (71% cheaper) unless you need REST-specific features
2. Enable caching on REST API to reduce backend invocations
3. Use Lambda Proxy integration to avoid mapping template complexity

### Step Functions

1. Use Express Workflows for high-volume short-duration (100x cheaper per execution)
2. Minimize state transitions in Standard workflows (you pay per transition)
3. Use Parallel states to reduce total duration
4. Batch items in Map states to reduce transition count

### EventBridge

1. Use specific rules to avoid invoking unnecessary targets
2. Archive only events needed for replay (storage costs accumulate)
3. Use Pipes for simple integrations (cheaper than Lambda glue)
4. Dead-letter queues prevent retry storms from escalating costs
