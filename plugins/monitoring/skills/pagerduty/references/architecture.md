# PagerDuty Architecture Reference

> Services, integrations, Events API, on-call management, incident lifecycle, and analytics.

---

## Core Data Model

### Services

The primary organizational unit. A service represents a team-owned component or application (e.g., "Payment API", "Auth Service"). Each service has:
- Integration key (routing key)
- Escalation policy
- Alert grouping settings (time, content, intelligent)
- Urgency rules (high vs low urgency)

Services map 1:1 to team ownership boundaries.

### Integrations

PagerDuty supports 500+ native integrations. Each integration on a service has a unique routing key. Categories:
- Monitoring (Datadog, Dynatrace, CloudWatch, Prometheus, Grafana, Zabbix, Nagios)
- CI/CD (Jenkins, GitHub Actions, CircleCI)
- ITSM (ServiceNow, Jira, Remedy)
- Chat (Slack, Microsoft Teams)
- Custom via Events API v2

### Escalation Policies

Define notification flow. Each service must have one. Policies have layers (levels); PagerDuty escalates to the next level if current does not acknowledge within timeout.

### On-Call Schedules

Define who is currently on-call. Referenced by escalation policy layers. Support multiple layers, overrides, and rotation types.

### Response Plays

Automated runbooks triggered by incidents. Add responders, subscribers, and conference bridges in one action. Used for major incident mobilization.

### Event Intelligence

Add-on module for noise reduction:
- Alert grouping (time-based, content-based, intelligent)
- Change correlation (recent deployments correlated with incidents)
- Suppression and pause rules
- Transient alert suppression

---

## Events API v2

Primary inbound API. Endpoint: `https://events.pagerduty.com/v2/enqueue`

### Payload Structure

```json
{
  "routing_key": "<integration_key>",
  "event_action": "trigger | acknowledge | resolve",
  "dedup_key": "<unique_alert_identifier>",
  "payload": {
    "summary": "Human-readable summary",
    "severity": "critical | error | warning | info",
    "source": "hostname or service name",
    "timestamp": "2026-04-08T12:00:00Z",
    "component": "optional component name",
    "group": "optional grouping",
    "class": "optional event class",
    "custom_details": {}
  },
  "links": [],
  "images": []
}
```

`dedup_key` controls deduplication. Sending `acknowledge` or `resolve` with the same key updates state without creating a new incident.

### Common Inbound Integrations

| Source | Method |
|--------|--------|
| Prometheus/Alertmanager | Native webhook, maps labels to severity |
| Datadog | Native OAuth, bi-directional |
| AWS CloudWatch | SNS > PagerDuty webhook |
| Grafana | Webhook contact point (Events API v2) |
| Zabbix | HTTP media type with routing key |
| Nagios | pagerduty-nagios plugin |
| Dynatrace | Native problem notification |

### Bi-Directional Integrations

**Slack:** Posts incident notifications to channels. Ack/resolve/add notes directly from Slack.

**Jira:** Incidents create Jira issues. Status syncs both directions. Field mapping configurable.

**ServiceNow:** Full bi-directional sync. Priority, assignment group, and resolution notes sync.

### Webhooks (Outbound)

Webhook subscriptions (v3) send payloads on incident lifecycle events:
- `incident.triggered`, `incident.acknowledged`, `incident.resolved`
- `incident.reassigned`, `incident.escalated`, `incident.annotated`
- `incident.priority_updated`, `incident.status_update_published`

---

## On-Call Management

### Schedule Types

**Layer-based schedules:** Multiple rotation layers applied in order. Supports daily, weekly, or custom rotation length with handoff times and restriction windows.

**Round-robin:** Users rotate in sequence.

### Overrides

Temporary on-call assignments overriding the schedule. Used for vacation coverage, swaps, and holiday coverage.

### Rotation Patterns

- **Follow-the-sun:** Multiple schedules per region, handoff at local business hours
- **Primary/Secondary:** Two schedules in escalation layers 1 and 2
- **Specialty rotation:** Per-domain schedules (database, network) from service-specific policies

### Escalation Policy Design

Each layer specifies:
- Which schedule or user(s) to notify
- Acknowledgment timeout
- Whether to repeat the policy

### Handoff Notifications

Shift change notifications sent X hours before handoff. Configurable per user.

---

## Incident Response

### Incident Lifecycle

```
TRIGGERED -> ACKNOWLEDGED -> RESOLVED
                |
           (no ack within timeout)
                |
           ESCALATED -> next layer
```

### Priority Levels

P1 (Critical) through P5 (Informational). Priority affects:
- Stakeholder notifications
- SLA tracking
- Reporting and analytics
- Response play triggers

### Response Mobilization

- **Add Responders:** Invite additional team members
- **Conference Bridge:** Dedicated bridge URL/number per incident
- **Status Updates:** Published to subscribed stakeholders
- **Response Plays:** One-click mobilization (add responders, subscribe stakeholders, attach bridge)

### Postmortems

Auto-generated timeline from incident data: alert timestamps, ack/escalation events, responder actions, integration events. Exportable. Integrates with Confluence, Jira, Google Docs.

---

## Analytics

| Metric | What It Measures |
|--------|-----------------|
| MTTA | Mean Time to Acknowledge |
| MTTR | Mean Time to Resolve |
| Incident volume | By service, team, time range |
| On-call burden | Hours on-call, interrupts, overnight pages per user |
| Service health score | Composite metric from MTTA, MTTR, volume |

Available in built-in dashboards and Reporting API.

---

## User Management

| Role | Access |
|------|--------|
| Responder | Ack/resolve incidents, manage own schedule |
| Manager | Service config, escalation policies, team management |
| Admin | Account settings, integrations, billing |
| Global Admin | Organization-wide config |
| Stakeholder | Read-only visibility (lower-cost license) |

SSO supported (SAML 2.0) with SCIM provisioning. Teams group users for ownership, scheduling, and reporting.
