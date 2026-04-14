# Grafana Alerting

## Unified Alerting Overview

Grafana Unified Alerting (mandatory since v10+) replaces legacy dashboard-based alerts with a centralized, multi-dimensional alerting engine modeled on Prometheus Alertmanager.

**Key concepts:**
- **Alert rules** -- Evaluate queries on a schedule and produce alert instances
- **Contact points** -- Define notification channels
- **Notification policies** -- Route alert instances to contact points using label matching
- **Silences** -- One-time notification suppression
- **Mute timings** -- Recurring scheduled suppression windows

## Alert Rules

Alert rules are organized into **rule groups** inside **folders** (replacing legacy dashboard scoping).

### Rule Definition Fields

| Field | Description |
|---|---|
| Name | Human-readable rule name |
| Folder | Organizational folder (maps to RBAC namespace) |
| Group | Rule group name; controls shared evaluation interval |
| Evaluation interval | How often the rule is evaluated (e.g., `1m`) |
| Pending period | How long condition must be true before Firing (e.g., `5m`) |
| Condition | The query ref (A, B, C...) whose result triggers the alert |
| Annotations | `summary`, `description`, `runbook_url` -- free-form key-value pairs |
| Labels | Key-value pairs for routing and grouping (e.g., `severity=critical`) |

### Multi-Dimensional Alerts

A single rule produces one alert instance per unique label-set returned by the query. Each instance is independently tracked. Example: a rule over `{job=~".+"}` produces one instance per job label value.

### Grafana-Managed vs Data Source-Managed

- **Grafana-managed** -- Evaluated by the Grafana backend; can query any data source; stored in Grafana database
- **Data source-managed** -- Rules pushed to a Prometheus-compatible ruler (Mimir, Cortex, Thanos Ruler); evaluated there; shown read-only in Grafana UI

### SQL Expressions (Private Preview, v12)

Multi-step expression pipelines can use SQL syntax to join and transform query results before the threshold condition is evaluated.

## Alert State Lifecycle

```
Normal --(condition met)--> Pending --(pending period elapsed)--> Firing
  ^                              |                                    |
  |                              └--(condition clears)───────────────>|
  |                                                                   |
  └--(keep-firing period elapsed + cleared)──── Recovering ──────────┘
```

| State | Meaning |
|---|---|
| **Normal** | Condition not met |
| **Pending** | Condition met but pending period not yet elapsed |
| **Firing** | Condition met for full pending period; notifications sent |
| **Recovering** | Condition cleared; waiting for "keep firing for" duration |
| **NoData** | Query returned no data; configurable behavior |
| **Error** | Query execution failed; configurable behavior |

## Contact Points

Contact points define how notifications are delivered. Each can have multiple integrations.

| Integration | Notes |
|---|---|
| **Email** | SMTP; Go templates for subject/body |
| **Slack** | Webhook or OAuth app; message templates |
| **PagerDuty** | Events API v2; severity mapping via labels |
| **Microsoft Teams** | Incoming webhook; adaptive card format |
| **Webhook** | Generic HTTP POST; configurable headers, auth, payload template |
| **OpsGenie** | Alerts API; priority mapping |
| **Telegram** | Bot API |
| **Alertmanager** | Forward to external Alertmanager instance |
| **Kafka** | Publish alert events to Kafka via REST Proxy |
| **Google Chat** | Webhook |

Contact point messages support **Go templating** with `{{ }}` syntax. Custom templates: Alerting > Contact points > Templates.

## Notification Policies

Notification policies form a **routing tree**. The root policy is the catch-all; child policies add label matchers to route specific alerts.

### Policy Fields

| Field | Description |
|---|---|
| Contact point | Where to send matching alerts |
| Label matchers | `key=value`, `key=~regex`, `key!=value` |
| Continue | If true, continue evaluating sibling policies after a match |
| Group by | Labels used to batch instances into a single notification |
| Group wait | Initial delay before sending first notification (default: 30s) |
| Group interval | Minimum interval between batches for same group (default: 5m) |
| Repeat interval | Re-send interval if still firing, no new alerts (default: 4h) |
| Mute timings | Reference named mute timings to suppress during windows |

### Routing Example

```
Root Policy --> contact: default-email (all alerts)
  |-- severity=critical --> contact: pagerduty-prod (continue: false)
  |-- team=platform --> contact: slack-platform
  └-- env=staging --> contact: slack-staging + mute: weekends
```

## Silences

- Created ad hoc from the Alerting UI or API
- Defined by label matchers; all matching alert instances are suppressed
- Have start time, end time, and optional comment/author
- Do not stop rule evaluation -- instances are computed and shown in UI; only notifications are suppressed
- Expire automatically; can be expired manually

## Mute Timings

- Reusable, recurring schedules (e.g., suppress every Saturday 00:00-08:00)
- Defined using time interval syntax (months, weekdays, days-of-month, times)
- Applied to notification policies (not individual rules)
- Unlike silences, mute timings match by schedule, not by label

### Active Time Intervals (v12)

The inverse of mute timings -- define when a policy should be active rather than when it should be muted.

## Alerting Best Practices

- **Test every rule** before deploying: use the "Test rule" button in the alert rule editor
- **Set pending periods** (equivalent to Prometheus `for`): minimum 1m for critical, 5m for warning
- **Use labels for routing**: add `severity`, `team`, `env` labels on rules to drive notification policies
- **Configure NoData handling**: set to `Normal` if metric gaps are expected
- **Provision alerting as code**: store rules, contact points, and policies in `provisioning/alerting/` YAML files
- **Use mute timings over silences** for recurring maintenance windows
- **Include runbook_url annotation** on every alert rule
