# OpenTelemetry Instrumentation

## Auto-Instrumentation

### Java -- OTel Java Agent

```bash
wget https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

java -javaagent:opentelemetry-javaagent.jar \
  -Dotel.service.name=my-service \
  -Dotel.exporter.otlp.endpoint=http://otelcol:4317 \
  -Dotel.traces.sampler=parentbased_traceidratio \
  -Dotel.traces.sampler.arg=0.1 \
  -jar myapp.jar
```

Instruments: Spring, Hibernate, JDBC, gRPC, Kafka, AWS SDK, HTTP clients, servlet containers, and 100+ more frameworks automatically.

### Python -- opentelemetry-instrument

```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install

OTEL_SERVICE_NAME=my-service \
OTEL_EXPORTER_OTLP_ENDPOINT=http://otelcol:4317 \
opentelemetry-instrument python app.py
```

### Node.js -- Auto-instrumentation via require

```bash
npm install @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node
```

```javascript
// tracing.js -- loaded before app code
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const sdk = new NodeSDK({
  serviceName: 'my-service',
  traceExporter: new OTLPTraceExporter({ url: 'http://otelcol:4317' }),
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

```bash
node --require ./tracing.js app.js
```

### .NET -- Auto-instrumentation startup hook

```bash
dotnet tool install --global OpenTelemetry.DotNet.Auto

OTEL_SERVICE_NAME=my-service \
OTEL_EXPORTER_OTLP_ENDPOINT=http://otelcol:4317 \
otel-dotnet-auto-run dotnet MyApp.dll
```

### Kubernetes -- OTel Operator Auto-instrumentation CR

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: my-instrumentation
spec:
  exporter:
    endpoint: http://otelcol-collector:4317
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "0.25"
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
  dotnet:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:latest
```

Annotate pods to inject: `instrumentation.opentelemetry.io/inject-java: "true"`.

## Manual Instrumentation -- Creating Spans

### Python

```python
from opentelemetry import trace
from opentelemetry.trace import StatusCode

tracer = trace.get_tracer("my.library", "1.0.0")

def process_order(order_id: str):
    with tracer.start_as_current_span("process_order") as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("order.type", "ecommerce")
        
        try:
            result = do_processing(order_id)
            span.set_attribute("order.items_count", result.item_count)
            span.add_event("order.processed", {"processing_time_ms": result.duration_ms})
            return result
        except Exception as e:
            span.record_exception(e)
            span.set_status(StatusCode.ERROR, str(e))
            raise
```

### Java

```java
Tracer tracer = openTelemetry.getTracer("my.library", "1.0.0");

Span span = tracer.spanBuilder("process_order")
    .setAttribute("order.id", orderId)
    .startSpan();

try (Scope scope = span.makeCurrent()) {
    span.addEvent("order.validated");
    span.setAttribute("order.total_usd", totalUsd);
} catch (Exception e) {
    span.recordException(e);
    span.setStatus(StatusCode.ERROR, e.getMessage());
    throw e;
} finally {
    span.end();
}
```

### Go

```go
tracer := otel.Tracer("my.library")

func processOrder(ctx context.Context, orderID string) error {
    ctx, span := tracer.Start(ctx, "process_order",
        trace.WithAttributes(
            attribute.String("order.id", orderID),
        ),
    )
    defer span.End()

    if err := doWork(ctx); err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        return err
    }
    return nil
}
```

## Manual Instrumentation -- Recording Metrics

### Python -- Counter, Histogram, UpDownCounter, Gauge

```python
from opentelemetry import metrics

meter = metrics.get_meter("my.library", "1.0.0")

# Counter
request_counter = meter.create_counter(
    "http.server.request.count",
    unit="1",
    description="Total number of HTTP requests",
)

# Histogram
request_duration = meter.create_histogram(
    "http.server.request.duration",
    unit="s",
    description="Duration of HTTP requests",
)

# UpDownCounter
active_requests = meter.create_up_down_counter(
    "http.server.active_requests",
    unit="1",
    description="Number of active HTTP requests",
)

# Usage
def handle_request(method, route):
    active_requests.add(1, {"http.method": method, "http.route": route})
    start = time.time()
    try:
        response = process(method, route)
        request_counter.add(1, {
            "http.method": method,
            "http.route": route,
            "http.status_code": response.status_code,
        })
        return response
    finally:
        duration = time.time() - start
        request_duration.record(duration, {"http.method": method, "http.route": route})
        active_requests.add(-1, {"http.method": method, "http.route": route})
```

### Observable (Async) Gauge

```python
import psutil

def cpu_usage_callback(options):
    yield metrics.Observation(psutil.cpu_percent(), {"core": "all"})

meter.create_observable_gauge(
    "system.cpu.utilization",
    callbacks=[cpu_usage_callback],
    unit="1",
    description="CPU utilization ratio",
)
```

## Structured Logging with Trace Context

### Python -- Inject trace context into logs

```python
import logging
from opentelemetry import trace

class OTelContextFilter(logging.Filter):
    def filter(self, record):
        span = trace.get_current_span()
        ctx = span.get_span_context()
        if ctx.is_valid:
            record.trace_id = format(ctx.trace_id, '032x')
            record.span_id = format(ctx.span_id, '016x')
            record.trace_flags = ctx.trace_flags
        else:
            record.trace_id = "0" * 32
            record.span_id = "0" * 16
            record.trace_flags = 0
        return True

logging.getLogger().addFilter(OTelContextFilter())
```

## Context Propagation

Context propagation passes trace context across process boundaries via HTTP headers or message metadata.

### W3C TraceContext (Default)

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
             ^  ^                                ^               ^
             |  trace-id (128-bit hex)            span-id (64-bit)  flags
             version
tracestate: vendor1=value1,vendor2=value2
```

### B3 Multi-Header (Zipkin Legacy)

```
X-B3-TraceId: 4bf92f3577b34da6a3ce929d0e0e4736
X-B3-SpanId: 00f067aa0ba902b7
X-B3-Sampled: 1
```

### Baggage (Cross-Service Key-Value)

```
baggage: userId=12345,tenantId=abc,region=us-east-1
```

### Configuring Propagators

```python
from opentelemetry.propagate import set_global_textmap
from opentelemetry.propagators.composite import CompositePropagator
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
from opentelemetry.baggage.propagation import W3CBaggagePropagator

set_global_textmap(CompositePropagator([
    TraceContextTextMapPropagator(),
    W3CBaggagePropagator(),
]))
```

## Sampling Strategies

| Strategy | Where | Pros | Cons |
|----------|-------|------|------|
| `AlwaysOn` | SDK | Full visibility | Cost-prohibitive at scale |
| `TraceIdRatioBased(0.1)` | SDK | Predictable 10% | Misses rare events |
| `ParentBased(TraceIdRatioBased(0.1))` | SDK | Respects parent, 10% roots | Production standard |
| Tail sampling (Collector) | Collector | Captures errors and slow | Requires stateful Collector |

### SDK Configuration

```python
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased

sampler = ParentBased(root=TraceIdRatioBased(0.1))
tracer_provider = TracerProvider(sampler=sampler, resource=resource)
```

**Environment variable configuration:**
```bash
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.1
```

### Cost Estimation

- Traces: 1M spans/day x 1 KB average = ~1 GB/day before sampling
- At 1% sampling: ~10 MB/day trace storage
- Metrics cardinality: each unique label combination = one time series
