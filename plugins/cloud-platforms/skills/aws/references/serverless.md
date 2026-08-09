# AWS Serverless Reference

> Lambda patterns, edge compute, concurrency and scaling, API Gateway, Step Functions, EventBridge. Prices are US East (N. Virginia) and PRICE-VOLATILE; quotas are structural facts.

---

## Lambda Architecture Patterns

### Layers and extensions

> Source: https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html (official)

- **Layers:** maximum **5 layers per function**; **250 MB unzipped deployment package including layers and custom runtimes**. Use for large dependencies, custom runtimes, and shared utility code; version layers independently from functions.
- **Extensions:** companion processes alongside the function. Internal extensions run in-process; external extensions run as separate processes. Common uses are observability agents, secrets prefetching, and custom log routing.

### Edge compute: CloudFront Functions vs Lambda@Edge

> Source: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-limits.html and https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-function-restrictions.html (official)

| Feature | CloudFront Functions | Lambda@Edge |
|---|---|---|
| Runtime | JavaScript only | Node.js, Python |
| Max memory | **2 MB** (confirmed quota) | **Same as Lambda quotas** (128 MB - 10,240 MB), subject to Lambda@Edge response-size caps |
| Max execution | Sub-millisecond class; AWS expresses it as a compute-utilization percentage, not a published millisecond number | 30 s function timeout on the general quota table; a tighter viewer-event ceiling applies |
| Network access | **No** | Yes |
| Request body access | **No** — "CloudFront Functions can't access the body of the HTTP request" | Yes (origin events) |
| Relative price | Roughly 6x cheaper per request | Baseline |

The runtime restrictions are verbatim and load-bearing: the CloudFront Functions runtime "restricts access to the network, file system, environment variables, and timers." The commonly quoted "1 ms" ceiling is **not restated numerically on the current quotas page** — describe it as sub-millisecond-class rather than asserting the figure.

**Decision:** CloudFront Functions for header manipulation, URL rewrites, redirects, and cache-key normalization. Lambda@Edge only when you need network calls, request-body access, or longer execution. CloudFront Functions gained additional capabilities in late 2025 (edge/regional-edge-cache metadata access, raw query-string retrieval, advanced origin overrides), narrowing the set of cases that require Lambda@Edge.

---

## Lambda Concurrency and Scaling

> Source: https://docs.aws.amazon.com/lambda/latest/dg/lambda-concurrency.html (official)

### Concurrency types

- **Unreserved (default):** shares the account pool, default **1,000** concurrent executions (adjustable). Risk: one function starves the others.
- **Reserved:** guarantees N slots and simultaneously caps the function at N. **Free.** Use to protect a fragile downstream dependency or to guarantee capacity for a critical function.
- **Provisioned:** pre-initializes environments to eliminate cold starts. Paid, and **not compatible with SnapStart on the same function version**.

**Concurrency = invocations per second x average duration in seconds.** 200 req/s at 0.5 s is 100 concurrent executions.

### Scaling behavior — current model

The old "burst of 500-3,000 then linear 500/minute" description is obsolete. AWS documents a single steady rule:

> "In each AWS Region, and for each function, your concurrency scaling rate is **1,000 execution environment instances every 10 seconds** (or 10,000 requests per second every 10 seconds)."

That is up to 6,000 new execution environments per minute **per function**, applied continuously and independently per function — there is no separate burst-then-linear phase. Scaling is not shared across functions in the account.

### The second throttle nobody plans for

Alongside the concurrency quota there is a **requests-per-second quota equal to 10x the concurrency limit**, at both account and function level. A function with sub-100 ms duration can exhaust the RPS ceiling while concurrency utilization still looks low. When throttling appears without concurrency pressure, check RPS.

---

## API Gateway

> Source: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html (official)

| Feature | REST API | HTTP API |
|---|---|---|
| Relative price | Baseline | Materially cheaper per million requests |
| Caching | Built-in | **No** (front with CloudFront) |
| Usage plans / API keys | Yes | **No** |
| Request validation | Yes | **No** |
| WAF integration | Yes | **No** |
| X-Ray tracing, mock integrations, canary deployments | Yes | **No** |
| Authorizers | Token + Request Lambda authorizers (JWT only via custom Lambda authorizer) | **Native JWT authorizer** plus Lambda authorizers |
| Private integration | VPC Link | VPC Link **plus AWS Cloud Map** service discovery |
| Deployments | Manual deployment trigger | Automatic |

**Decision:** use HTTP API by default. Move to REST API only when you specifically need caching, usage plans/API keys, request validation, WAF, X-Ray, mock integrations, or canary deployments — the "No" column is the whole decision.

Account-level default throttle is 10,000 requests per second, configurable per route. Use custom domain names with ACM certificates for free TLS.

---

## Step Functions

> Source: https://aws.amazon.com/step-functions/pricing/ (official)

| Aspect | Standard | Express |
|---|---|---|
| Max duration | 1 year | 5 minutes |
| Pricing | **$0.025 per 1,000 state transitions** | Duration-based (GB-second) |
| Execution model | Exactly-once | At-least-once (async) or at-most-once (sync) |
| History | 90 days in console | CloudWatch Logs only |
| Best for | Long orchestration, human approval, rich error handling | High-volume, short-duration, streaming/IoT |

Express is orders of magnitude cheaper for high-volume, short workflows because it bills on duration rather than per transition. Standard is worth its per-transition cost when you need exactly-once semantics, visible execution history, and long-running waits.

### Patterns

- **Map** — fan out items to a sub-workflow in parallel; batch items to reduce transition count in Standard workflows.
- **Retry/Catch** — retry with exponential backoff (`IntervalSeconds`, `MaxAttempts`, `BackoffRate`); catch specific error types before generic ones.
- **Wait** — pause for a duration or until a timestamp; use for SLA timeouts and scheduled steps.
- **Callback (task token)** — pause until an external system calls `SendTaskSuccess`/`SendTaskFailure`; the standard human-approval and third-party-integration pattern.

---

## EventBridge

> Source: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-quota.html and https://aws.amazon.com/eventbridge/pricing/ (official)

EventBridge is the default event router on AWS: content-based filtering on any JSON field, schema registry, archive and replay, and third-party SaaS sources.

### Buses, rules, and quotas

- Bus types: **default** (AWS service events), **custom** (your application events, one per bounded context), **partner** (SaaS sources).
- **Rules per event bus: 300** in most Regions — **but only 100 in af-south-1 and eu-south-1**. Adjustable.
- **Targets per rule: 5** — not adjustable.
- **Rules using wildcard event patterns: 30 per event bus per account** — a separate, non-adjustable ceiling below the 300-rule quota. Wildcard-heavy filtering strategies hit this first.
- Input transformers reshape events before delivery; configure dead-letter queues on every target.

### The rest of the EventBridge family

- **Pipes** — point-to-point source -> filter -> enrichment -> target with no glue Lambda. Sources include SQS, Kinesis, DynamoDB Streams, Kafka, and MQ. Billed per million requests after filtering. Concurrency defaults: **3,000 concurrent pipe executions** in us-east-1/us-west-2/eu-west-1, **1,000** elsewhere; **1,000 pipes per account**.
- **Scheduler** — cron, rate, and one-time schedules with built-in retry policies; **14 million invocations free per month**, then per-million pricing. Replaces CloudWatch Events rules for scheduling.
- **API Destinations** — the supported way to target arbitrary public or private HTTP endpoints from a rule, billed per million events.

### Archive and replay — two separate charges

Archive **processing** (writing events into the archive) and archive **storage** are billed separately, and storage is roughly 4x cheaper per GB than the processing rate. Collapsing them into one "$0.10/GB stored" figure overstates the standing cost of retention by a wide margin. Archive only what you would actually replay, and set a finite retention period.

Same-account event delivery is free; cross-account delivery is billed per million events, as is publishing to a custom bus.

---

## Serverless Cost Optimization

> Source: https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html, https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html, https://aws.amazon.com/step-functions/pricing/, https://aws.amazon.com/eventbridge/pricing/ (official)

1. **Lambda:** use `arm64`; right-size memory with a power-tuning sweep (more memory often lowers total cost for CPU-bound work); minimize package size; use SnapStart where the runtime supports it — remembering it is free for Java but billed for Python and .NET; use Provisioned Concurrency only on a schedule; avoid VPC attachment unless required.
2. **API Gateway:** HTTP API unless a REST-only feature is required; enable caching on REST APIs to cut backend invocations.
3. **Step Functions:** Express for high-volume short workflows; minimize state transitions in Standard; batch inside Map states.
4. **EventBridge:** write specific rules so targets are not invoked unnecessarily; archive selectively and account for processing and storage separately; use Pipes instead of glue Lambdas; attach DLQs so retry storms cannot escalate cost.

## Sources

- https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html
- https://docs.aws.amazon.com/lambda/latest/dg/lambda-concurrency.html
- https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html
- https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-limits.html
- https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-function-restrictions.html
- https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html
- https://aws.amazon.com/step-functions/pricing/
- https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-quota.html
- https://aws.amazon.com/eventbridge/pricing/

Fetched: 2026-08-08
