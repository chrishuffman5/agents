# Prometheus Alerting

## Alert Rule Structure

Alerting rules are defined in YAML rule files, grouped by `groups`. Each rule specifies a PromQL expression that fires when the result is a non-empty instant vector.

```yaml
groups:
  - name: <group_name>
    interval: <evaluation_interval>   # optional, overrides global
    rules:
      - alert: <AlertName>             # PascalCase convention
        expr: <PromQL_expression>      # fires when result is non-empty
        for: <duration>                # pending period before firing
        labels:
          severity: <critical|warning|info>
          team: <team_name>
        annotations:
          summary: "Short description ({{ $labels.instance }})"
          description: |
            Detailed description. Value: {{ $value | humanize }}
          runbook_url: "https://runbooks.example.com/alerts/{{ .Labels.alertname }}"
```

**Key fields:**
- `expr`: Fires when result is non-empty. Each vector element becomes a separate alert instance.
- `for`: Alert must be "pending" for this duration before becoming "firing." Prevents transient spikes. Typical: `1m` (short), `5m` (medium), `10m` (long).
- `labels`: Additional labels merged onto the alert. Used by Alertmanager routing. `severity` is the most common.
- `annotations`: Human-readable fields. Support Go template syntax including `{{ $labels.* }}` and `{{ $value }}`.

## Common Alert Examples

**Service down:**
```yaml
- alert: ServiceDown
  expr: up{job="api"} == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Service {{ $labels.job }} is down on {{ $labels.instance }}"
    runbook_url: "https://runbooks.example.com/service-down"
```

**High error rate:**
```yaml
- alert: HighErrorRate
  expr: |
    sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)
    /
    sum(rate(http_requests_total[5m])) by (job)
    > 0.05
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High error rate on {{ $labels.job }}: {{ $value | humanizePercentage }}"
```

**Disk filling up:**
```yaml
- alert: DiskWillFillIn4Hours
  expr: |
    predict_linear(node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}[1h], 4 * 3600) < 0
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Disk on {{ $labels.instance }}:{{ $labels.mountpoint }} will fill in 4h"
```

**High memory usage:**
```yaml
- alert: NodeHighMemoryUsage
  expr: |
    (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.90
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "{{ $labels.instance }} memory > 90%: {{ $value | humanizePercentage }}"
```

**Absent metric (dead man's switch):**
```yaml
- alert: MetricAbsent
  expr: absent(up{job="critical-service"})
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Metric 'up' for critical-service is missing -- scrape or service failure"
```

## Alertmanager Architecture

Alertmanager receives alerts from Prometheus, deduplicates, groups, routes, and sends notifications.

```
Prometheus ──> Alertmanager ──> Receivers
                    │
             ┌──────┴────────┐
             │               │
          Routing        Inhibition
          Grouping        Rules
          Silences
```

**Components:**
- **Dispatcher:** Receives alerts, applies grouping, routes to receivers
- **Inhibitor:** Suppresses certain alerts when others are firing
- **Silencer:** Matches alerts against active silences
- **Notifier:** Sends notifications via configured receivers

## Alertmanager Configuration

```yaml
global:
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alertmanager@example.com'
  slack_api_url: 'https://hooks.slack.com/services/...'
  pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'

route:
  receiver: default
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s          # wait before sending first notification
  group_interval: 5m       # wait before sending update for ongoing alerts
  repeat_interval: 4h      # resend firing alert after this duration

  routes:
    - match:
        severity: critical
      receiver: pagerduty
      continue: false

    - match_re:
        alertname: '^(DiskWill|NodeHigh).*'
      receiver: slack-infra
      group_by: ['instance']

    - match:
        team: database
      receiver: db-team-email

receivers:
  - name: default
    slack_configs:
      - channel: '#alerts-default'
        title: '{{ .CommonAnnotations.summary }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: pagerduty
    pagerduty_configs:
      - routing_key: '<PD_INTEGRATION_KEY>'
        severity: '{{ if eq .CommonLabels.severity "critical" }}critical{{ else }}warning{{ end }}'
        description: '{{ .CommonAnnotations.summary }}'

  - name: slack-infra
    slack_configs:
      - channel: '#infra-alerts'
        send_resolved: true
        actions:
          - type: button
            text: 'Runbook'
            url: '{{ (index .Alerts 0).Annotations.runbook_url }}'

  - name: db-team-email
    email_configs:
      - to: 'db-team@example.com'
        send_resolved: true
```

## Routing Concepts

**Grouping:** Alertmanager groups related alerts into single notifications. The `group_by` labels determine grouping. A group's first notification is delayed by `group_wait`. Subsequent notifications wait `group_interval`.

**Inhibition:** When a "source" alert is firing, matching "target" alerts are suppressed:

```yaml
inhibit_rules:
  - source_match:
      severity: critical
    target_match:
      severity: warning
    equal: ['alertname', 'cluster', 'service']

  - source_match:
      alertname: ClusterDown
    target_match_re:
      alertname: '^Node.*'
    equal: ['cluster']
```

**Silencing:** Admin-created matchers that suppress matching alerts for a time period:

```bash
amtool silence add \
  --alertmanager.url=http://alertmanager:9093 \
  --duration=2h \
  --comment="Planned maintenance" \
  alertname="NodeHighMemory" instance="prod-node-01"
```

**`continue: true`** in routes: Allows an alert to match multiple route branches (fan-out to multiple receivers).

## Receiver Types

| Receiver | Key Configuration |
|----------|------------------|
| **Slack** | Webhook URL, channel, title/text templates, actions (buttons) |
| **PagerDuty** | Routing key, severity mapping, description template |
| **Email** | SMTP config, to/cc, subject/body templates |
| **Webhook** | URL, method, HTTP config; generic for any HTTP-based integration |
| **OpsGenie** | API key, priority mapping, responders |
| **VictorOps** | Routing key mapping |
| **Microsoft Teams** | Webhook URL (via webhook receiver or dedicated integration) |
| **Telegram** | Bot token, chat ID |

All receivers support Go template syntax for customizing notification content.

## Alert Fatigue Prevention

1. **Use the `for` clause** -- Never alert on transient conditions. Minimum `for: 1m` for most alerts, `for: 5m` for warnings.
2. **Set appropriate severity levels** -- `info` (FYI), `warning` (investigate), `critical` (wake someone up). Only `critical` should page on-call.
3. **Group aggressively** -- Batch related alerts (`group_by: ['alertname', 'cluster']`). Set `group_wait: 60s` to collect bursts.
4. **Use inhibition** -- Suppress downstream alerts when the root cause is already alerting.
5. **Tune `repeat_interval`** -- Do not resend every 30m. Use `4h` or `12h` for sustained conditions.
6. **Recording rules for alert expressions** -- Complex alert expressions that re-evaluate every 15s should be pre-computed as recording rules.
7. **Dead man's switch** -- Send a constant "watchdog" alert. Silence it permanently. If it stops, alerting is broken.
8. **Runbook URLs in every alert** -- `annotations.runbook_url`. Responders need context fast.

## Time Intervals

Schedule-based notification control:

```yaml
time_intervals:
  - name: business_hours
    time_intervals:
      - weekdays: ['monday:friday']
        times:
          - start_time: '09:00'
            end_time: '17:00'
```

Reference time intervals in routes to control when notifications are sent (e.g., only during business hours for non-critical alerts).
