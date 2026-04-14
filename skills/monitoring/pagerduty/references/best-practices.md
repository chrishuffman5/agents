# PagerDuty Best Practices Reference

> Service design, noise reduction, escalation patterns, and SLA management.

---

## Service Design

### One Service Per Component

- One service per team-owned component. Avoid monolithic "all alerts" services.
- Name descriptively: `[team]-[component]` (e.g., `payments-api`, `auth-service`).
- Each service should have a clear owner (team), integration source, and escalation policy.

### Service Dependencies

Model upstream/downstream relationships in PagerDuty's service graph. When a parent service has an active incident, child services' incidents are suppressed or marked as related.

**Use case:** Shared database goes down. Without dependencies, every downstream service pages separately. With dependencies, only the database service pages.

### Urgency Rules

- **High urgency:** Actionable alerts requiring immediate human response. Pages on-call via push/SMS/phone.
- **Low urgency:** Informational alerts. Creates incident without paging. On-call reviews during business hours.

Configure per-service. Default: all alerts high urgency (wrong for most teams).

### Support Hours

Configure service support hours to auto-lower urgency outside business hours for non-critical services. After-hours alerts for a staging environment should never page.

---

## Escalation Policy Design

### Always Two Layers Minimum

- Layer 1: Primary on-call schedule
- Layer 2: Secondary schedule or team manager
- Include a catch-all final layer that pages a manager or broadcast channel

### Use Schedules, Not Individuals

Pointing policies at individuals breaks when that person is on PTO, sick, or leaves the company. Schedules provide rotation and override capability.

### Acknowledgment Timeouts

| Priority | Timeout |
|----------|---------|
| P1/P2 | 5 minutes |
| P3/P4 | 15 minutes |
| P5 | 30 minutes or low-urgency (no page) |

### Repeat Policy

Enable policy repeat (up to 3 times) for P1 incidents. If no one acknowledges after cycling through all layers, repeat ensures the issue is not lost.

---

## Noise Reduction

### Alert Grouping (Event Intelligence)

| Mode | Behavior |
|------|----------|
| Time-based | Groups alerts within a time window (e.g., 5 minutes) |
| Content-based | Groups by matching fields (source, component, class) |
| Intelligent | ML-based grouping using historical patterns |

Intelligent grouping is recommended for most services. It learns from operator merge/split behavior.

### Deduplication

Use `dedup_key` consistently in Events API calls. Format recommendation: `{source}/{check-name}/{entity}`.

Example: `datadog/high-error-rate/checkout-api`

Same `dedup_key` updates existing alert rather than creating new incident.

### Transient Alert Suppression

Suppress alerts that trigger and auto-resolve within a short window (e.g., 2 minutes). Prevents flapping checks from generating noise. Configure per service.

### Suppression Rules

Event rules that match and suppress alerts based on conditions. Used for:
- Known maintenance windows
- Expected deployment transients
- Low-value alerts during specific hours

---

## SLA Management

### Define Targets Per Priority

| Priority | MTTA Target | MTTR Target |
|----------|-------------|-------------|
| P1 | < 5 minutes | < 1 hour |
| P2 | < 15 minutes | < 4 hours |
| P3 | < 1 hour | < 1 business day |
| P4/P5 | < 4 hours | Best effort |

### Review MTTA/MTTR Weekly

- High MTTA indicates schedule gaps, unclear ownership, or alert fatigue
- High MTTR indicates tooling gaps, insufficient runbooks, or missing automation
- High overnight interrupts signal need for alert tuning or follow-the-sun scheduling

### Track On-Call Burden

Monitor per-user metrics:
- Hours on-call per month
- Number of interrupts (especially overnight)
- Pages per on-call shift

Distribute burden evenly. Uneven distribution leads to burnout and attrition.

---

## Incident Response Best Practices

### Response Plays for Major Incidents

Pre-configure response plays for P1 incidents:
- Add war-room responders (5-10 key people)
- Subscribe stakeholders (VPs, product managers)
- Attach conference bridge
- Post initial status update template

One-click activation during a P1 saves critical minutes.

### Status Updates

Publish regular status updates for active P1/P2 incidents:
- Every 30 minutes for P1
- Every 2 hours for P2
- Include: current status, impact, ETA, next steps

Stakeholders subscribed to the incident receive updates automatically.

### Postmortem Discipline

Generate postmortem for every P1 and every P2 lasting > 1 hour. PagerDuty auto-populates the timeline. Add:
- Root cause analysis
- Contributing factors
- Action items with owners and due dates
- Follow-up tracking in Jira/Linear

Review postmortems in team retrospectives. Track action item completion rate.
