# Dynatrace Cost Reference

> Host Unit sizing, DDUs, log pricing, optimization strategies, and reserved capacity.

---

## Pricing Model

Dynatrace uses consumption-based pricing with several dimensions:

| Dimension | Unit | Coverage |
|-----------|------|----------|
| Full-Stack Monitoring | Host Unit (HU) / hour | OneAgent on host (APM + infrastructure) |
| Infrastructure Monitoring | Host Unit / hour | Infrastructure-only (no APM, lower cost) |
| Log Monitoring | GB ingest / month | Logs ingested into Grail |
| Digital Experience (RUM) | Sessions / month | RUM user sessions |
| Synthetic Monitoring | Executions / month | Browser and HTTP checks |
| Davis Data Units (DDU) | DDU | Custom metrics, metric ingestion, events, extensions |
| Application Security | Host Unit / hour | Security module (adds to full-stack HU cost) |

---

## Host Unit Sizing

Host Unit consumption scales with host resources (RAM-based tiers):

| Host RAM | Host Units |
|----------|-----------|
| <= 4 GB | 0.5 HU |
| <= 8 GB | 1 HU |
| <= 16 GB | 2 HU |
| <= 32 GB | 4 HU |
| <= 64 GB | 8 HU |
| > 64 GB | 16 HU |

**Key implication:** A 64 GB database server consumes 8 HU in full-stack mode. If it only needs infrastructure monitoring (no APM tracing), switching to infrastructure-only mode reduces cost significantly.

---

## Davis Data Units (DDU)

DDUs cover:
- Custom metrics (each unique metric:dimension time series)
- Metric ingestion via API
- Extension metric data points
- Events ingested via API (non-Davis events)

Approximately 1 DDU = 1,000 metric data points per month (varies by type).

---

## Cost Optimization Strategies

### 1. Use Infrastructure Monitoring Mode

Switch hosts that do not need APM tracing to infrastructure-only mode. Examples: monitoring hosts, jump boxes, build servers, load balancers.

**Kubernetes:** Configure via DynaKube CR using `hostMonitoring` instead of `classicFullStack`.

### 2. Control Log Ingestion

Configure log content rules to:
- Ingest only relevant log files (skip `/var/log/messages` on application servers)
- Filter out noisy log lines (DEBUG, health checks) before ingestion
- Grail billing is per GB -- reducing volume directly reduces cost

### 3. Reduce Log Retention

Default retention is 35 days. Configure shorter retention for high-volume debug logs. Keep longer retention only for audit and compliance logs.

### 4. Audit DDU Consumption

Review DDU usage via `Settings > Cloud and virtualization > Monitored technologies`. Disable unnecessary metric extensions that consume DDUs without providing value.

### 5. Right-Size Host Monitoring Mode

Full-stack mode on a host includes APM, all process detection, and distributed tracing. Infrastructure mode provides host metrics and basic process monitoring at lower HU cost. Evaluate per host group.

### 6. Scope Smartscape With Management Zones

Management zones restrict which teams see which entities but **do not reduce cost**. Cost reduction requires reducing actual agent/ingest scope. Management zones reduce noise and improve focus.

### 7. Reserved Capacity (Annual License)

Annual committed capacity is significantly cheaper than on-demand. Forecast:
- Expected host count by RAM tier
- Log volume (GB/month)
- Synthetic execution count
- RUM session count

Over-provisioning reserved capacity is still cheaper than on-demand for most organizations.

---

## Cost Estimation

### Example: 50-Host Environment

```
Application servers (20 hosts, 16 GB RAM):
  Full-stack: 20 x 2 HU = 40 HU

Database servers (5 hosts, 64 GB RAM):
  Infrastructure-only: 5 x 8 HU = 40 HU (infra rate)

Kubernetes nodes (15 hosts, 32 GB RAM):
  Full-stack: 15 x 4 HU = 60 HU

Utility hosts (10 hosts, 8 GB RAM):
  Infrastructure-only: 10 x 1 HU = 10 HU (infra rate)

Logs: 200 GB/month
Synthetic: 50,000 executions/month
RUM: 100,000 sessions/month
```

Total HU for full-stack: 100 HU
Total HU for infra-only: 50 HU (at lower per-HU rate)

Contact Dynatrace sales for per-HU pricing based on annual commitment level.

---

## Common Cost Surprises

**1. Large-RAM hosts consuming disproportionate HU**
A single 128 GB host = 16 HU. Database servers and big-data nodes are expensive to monitor in full-stack mode.

**2. Uncontrolled log ingestion**
OneAgent ships logs from all detected log files by default. Without content rules, debug and access logs consume Grail budget rapidly.

**3. DDU spikes from custom metrics**
Custom metric extensions or API-ingested metrics with high cardinality generate unexpected DDU consumption.

**4. Kubernetes node scaling**
Auto-scaling Kubernetes clusters increase host count (and HU consumption) dynamically. Monitor HU trends and set budget alerts.

**5. On-demand vs committed pricing gap**
On-demand HU rates can be 2-3x higher than committed annual pricing. Always evaluate annual commitment for stable environments.
