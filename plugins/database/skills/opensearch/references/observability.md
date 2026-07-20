# OpenSearch Observability Reference

Anomaly detection, alerting, and the built-in observability stack (trace analytics, PPL, SQL, notebooks, event analytics, metrics).

---

## Anomaly Detection

The anomaly detection plugin uses the Random Cut Forest (RCF) algorithm to detect anomalies in streaming data:

```json
POST _plugins/_anomaly_detection/detectors
{
  "name": "high_error_rate_detector",
  "description": "Detect anomalous error rates",
  "time_field": "@timestamp",
  "indices": ["logs-*"],
  "feature_aggregation": [
    {
      "feature_name": "error_count",
      "feature_enabled": true,
      "aggregation_query": {
        "error_count": {
          "filter": { "term": { "level": "ERROR" } },
          "aggs": { "count": { "value_count": { "field": "_id" } } }
        }
      }
    }
  ],
  "detection_interval": { "period": { "interval": 5, "unit": "Minutes" } },
  "window_delay": { "period": { "interval": 1, "unit": "Minutes" } }
}
```

Pair with the alerting plugin for notifications when anomalies are detected.

## Alerting

The alerting plugin monitors data and sends notifications. Since OpenSearch 2.0, notification channels replaced alerting destinations.

**Monitor types:** per-query, per-bucket, per-cluster-metrics, per-document, composite.

**Monitor example:**
```json
POST _plugins/_alerting/monitors
{
  "type": "monitor",
  "name": "High Error Rate Monitor",
  "monitor_type": "query_level_monitor",
  "enabled": true,
  "schedule": {
    "period": { "interval": 5, "unit": "MINUTES" }
  },
  "inputs": [
    {
      "search": {
        "indices": ["logs-*"],
        "query": {
          "size": 0,
          "query": {
            "bool": {
              "filter": [
                { "range": { "@timestamp": { "gte": "now-5m" } } },
                { "term": { "level": "ERROR" } }
              ]
            }
          },
          "aggs": { "error_count": { "value_count": { "field": "_id" } } }
        }
      }
    }
  ],
  "triggers": [
    {
      "query_level_trigger": {
        "name": "High errors",
        "severity": "1",
        "condition": {
          "script": { "source": "ctx.results[0].aggregations.error_count.value > 100", "lang": "painless" }
        },
        "actions": [
          {
            "name": "Notify Slack",
            "destination_id": "slack-channel-id",
            "message_template": {
              "source": "High error rate detected: {{ctx.results[0].aggregations.error_count.value}} errors in last 5 minutes"
            }
          }
        ]
      }
    }
  ]
}
```

## Observability

OpenSearch provides a comprehensive observability stack:

- **Trace Analytics** -- Distributed tracing compatible with OpenTelemetry. Dashboard views for trace groups, error rates, throughput, and service maps. Indices: `otel-v1-apm-span-*`, `otel-v1-apm-service-map*`.
- **PPL (Piped Processing Language)** -- Intuitive query language for log analytics. Pipe-delimited syntax for filtering, aggregating, and transforming data:
  ```
  source=logs-* | where level='ERROR' | stats count() by service | sort -count()
  ```
- **SQL** -- ANSI SQL support for querying OpenSearch indices via `_plugins/_sql` API.
- **Notebooks** -- Combine PPL/SQL queries, visualizations, and narrative text in collaborative notebooks.
- **Event Analytics** -- Explore and visualize events with saved queries and visualizations.
- **Metrics** -- Prometheus-compatible metrics ingestion and querying (3.x).
