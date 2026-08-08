# OpenTelemetry monitoring reference

Read when instrumenting a Claude Code fleet — exporters, metrics, events, tracing, mTLS, cardinality control, and enterprise header rotation.

## Quick start

> Source: https://code.claude.com/docs/en/monitoring-usage.md

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp        # otlp | prometheus | console | none
export OTEL_LOGS_EXPORTER=otlp           # otlp | console | none
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc  # grpc | http/json | http/protobuf
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer your-token"   # optional
export OTEL_METRIC_EXPORT_INTERVAL=10000   # default 60000ms
export OTEL_LOGS_EXPORT_INTERVAL=5000      # default 5000ms
claude
```

Verify by looking for the `claude_code.session.count` metric, or the `claude_code.user_prompt` event after a prompt.

Signal-specific overrides: `OTEL_EXPORTER_OTLP_METRICS_PROTOCOL` / `_METRICS_ENDPOINT`, `OTEL_EXPORTER_OTLP_LOGS_PROTOCOL` / `_LOGS_ENDPOINT`.

## Content logging

Off by default for privacy. Enable deliberately and only with the user's or org's explicit decision:

`OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_ASSISTANT_RESPONSES` (falls back to `OTEL_LOG_USER_PROMPTS`), `OTEL_LOG_TOOL_DETAILS`, `OTEL_LOG_TOOL_CONTENT`, `OTEL_LOG_RAW_API_BODIES`.

## Metrics

`claude_code.session.count`, `claude_code.lines_of_code.count`, `claude_code.pull_request.count`, `claude_code.commit.count`, `claude_code.cost.usage` (USD), `claude_code.token.usage`, `claude_code.code_edit_tool.decision`, `claude_code.active_time.total` (seconds).

Standard attributes: `session.id`, `user.id`, `user.email`, `organization.id`, `app.version`, `app.entrypoint`, `terminal.type`, plus anything from `OTEL_RESOURCE_ATTRIBUTES`.

## Events

Exported as `claude_code.<event_type>`: `user_prompt`, `assistant_response`, `api_request`, `api_error`, `api_refusal`, `tool_decision`, `tool_result`, `auth`, `mcp_server_connection`, `permission_mode_changed`, `plugin_installed`, `plugin_loaded`.

Correlation IDs: `prompt.id` (all events from one prompt), `message.uuid` (matches transcript entries), `client_request_id` (equals the `x-client-request-id` header), `tool_use_id`.

## Example configurations

```bash
# console debug, 1s intervals
export CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_METRICS_EXPORTER=console OTEL_METRIC_EXPORT_INTERVAL=1000

# Prometheus (scrape http://localhost:9464/metrics)
export CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_METRICS_EXPORTER=prometheus

# split exporters
export OTEL_EXPORTER_OTLP_METRICS_PROTOCOL=http/protobuf OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://metrics.example.com:4318
export OTEL_EXPORTER_OTLP_LOGS_PROTOCOL=grpc OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://logs.example.com:4317
```

## Distributed tracing (beta)

```bash
export CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1
export OTEL_TRACES_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_TRACES_EXPORT_INTERVAL=5000
```

Span hierarchy: `claude_code.interaction` (root) → `claude_code.llm_request`, `claude_code.hook`, `claude_code.tool` → `claude_code.tool.blocked_on_user`, `claude_code.tool.execution`, and subagent spans. Spans redact prompts, tool input, and content by default; the same `OTEL_LOG_*` flags include them.

## Admin configuration via managed settings

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://collector.example.com:4317",
    "OTEL_EXPORTER_OTLP_HEADERS": "Authorization=Bearer example-token"
  }
}
```

When OTLP settings arrive via managed settings, Claude Code strips conflicting user-set OTel env vars to prevent signal redirection ("lock-down behavior").

## mTLS

```bash
# grpc
export OTEL_EXPORTER_OTLP_CLIENT_KEY=/path/key.pem
export OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE=/path/cert.pem
export OTEL_EXPORTER_OTLP_CERTIFICATE=/path/ca-cert.pem
# http/protobuf, http/json
export CLAUDE_CODE_CLIENT_KEY=/path/key.pem
export CLAUDE_CODE_CLIENT_CERT=/path/cert.pem
export NODE_EXTRA_CA_CERTS=/path/ca-cert.pem
```

## Cardinality control

```bash
export OTEL_METRICS_INCLUDE_SESSION_ID=false            # default true
export OTEL_METRICS_INCLUDE_VERSION=true                # default false
export OTEL_METRICS_INCLUDE_ACCOUNT_UUID=false          # default true
export OTEL_METRICS_INCLUDE_ENTRYPOINT=true             # default false
export OTEL_METRICS_INCLUDE_RESOURCE_ATTRIBUTES=false   # default true
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative   # default delta
```

## Multi-team attribution

```bash
export OTEL_RESOURCE_ATTRIBUTES="department=engineering,team.id=platform,cost_center=eng-123"
```

No spaces (use underscores or camelCase); percent-encode special characters.

## Dynamic OTel auth headers (enterprise)

```json
{ "otelHeadersHelper": "/path/to/generate-otel-headers.sh" }
```

The script prints JSON such as `{"Authorization": "Bearer $(get-token.sh)", "X-API-Key": "$(get-api-key.sh)"}`. Default refresh interval is 29 minutes; override with `CLAUDE_CODE_OTEL_HEADERS_HELPER_DEBOUNCE_MS`.

## Content size limits

```bash
export CLAUDE_CODE_OTEL_CONTENT_MAX_LENGTH=262144   # default 61440 (60KB)
```

Applies to model responses, tool content, system prompts, and raw API bodies, and is also bounded by `OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT`.

## Troubleshooting

`claude --debug` shows OTel export errors in the log. The HTTP `Content-Length` header is sent rather than chunked encoding as of v2.1.212+.

## Sources

- https://code.claude.com/docs/en/monitoring-usage.md

Fetched: 2026-08-05
