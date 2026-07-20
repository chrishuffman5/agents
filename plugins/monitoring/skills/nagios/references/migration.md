# Nagios Migration Reference

> Detailed migration paths from Nagios to Zabbix and Nagios to Prometheus.

---

## Nagios to Zabbix

Zabbix is the most common migration target. Similar mental model (host/service monitoring) with native auto-discovery, templates, and built-in graphing.

### Concept Mapping

| Nagios | Zabbix |
|--------|--------|
| Host | Host |
| Service | Item (data collection) + Trigger (alerting) |
| Check command / plugin | External check, Zabbix agent item, or SNMP item |
| Contact / contact group | User / user group |
| Notification command | Media type (email, webhook, SMS) |
| Timeperiod | Time period |
| Hostgroup | Host group |
| NRPE | Zabbix Agent (native, replaces NRPE entirely) |
| Passive check / NSCA | Zabbix trapper item |
| Template (register 0) | Zabbix template |
| Escalation | Action escalation steps |

### Migration Steps

1. **Export Nagios inventory** -- Parse `.cfg` files or use XI export to catalog all hosts and services.

2. **Import hosts into Zabbix** -- Use Zabbix API or CSV import for bulk host creation.

3. **Map check commands to templates** -- Most standard Nagios checks have built-in Zabbix equivalents in the official template library (500+ templates). `check_disk` maps to `vfs.fs.size`, `check_load` maps to `system.cpu.load`, `check_http` maps to HTTP Agent items.

4. **Rewrite custom plugins** -- Place in `$ZABBIX_HOME/externalscripts/` as external checks or convert to UserParameters in `zabbix_agentd.conf`. Exit codes and stdout format are compatible with Nagios plugins.

5. **Recreate notification routing** -- Map Nagios contacts/contact groups to Zabbix users/user groups with media types. Recreate escalations using Zabbix action operation steps.

6. **Parallel operation** -- Run both systems during cutover. Disable Nagios notifications first, then decommission after validation period.

### Plugin Reuse

Nagios plugins can be reused directly in Zabbix as external checks with minimal modification. The exit code (0/1/2/3) and output format are compatible if the plugin follows the Nagios plugin standard. However, native Zabbix agent items are preferred for performance and features (historical data, trends, LLD).

---

## Nagios to Prometheus

Prometheus uses a pull model storing time-series metrics. The paradigm shift from check-based (pass/fail) to metric-based (values over time with alert rules) is significant.

### Concept Mapping

| Nagios | Prometheus |
|--------|-----------|
| Plugin exit code | Alert rule (threshold on metric value) |
| Performance data | Metric (scraped from exporter) |
| NRPE | Node Exporter, custom exporters |
| Passive check | Pushgateway |
| Notification | Alertmanager (routes, receivers, inhibitions) |
| Timeperiod | Alertmanager time_intervals |
| Host | Target (scrape endpoint) |
| Service | Metric + PromQL alert rule |

### Migration Steps

1. **Deploy Node Exporter** on all Linux hosts. Replaces most NRPE checks (CPU, memory, disk, network).

2. **Deploy application exporters** -- `mysqld_exporter`, `redis_exporter`, etc. for database-specific monitoring.

3. **Use blackbox_exporter** for availability checks. Direct replacement for `check_http`, `check_tcp`, `check_ssh`.

4. **Use Pushgateway** for passive/batch job metrics. Replaces NSCA passive submissions.

5. **Translate thresholds to PromQL** -- Nagios `-w 5 -c 10` on check_load becomes:
   ```yaml
   - alert: HighLoad
     expr: node_load1 > 10
     for: 5m
     labels:
       severity: critical
   ```

6. **Configure Alertmanager** for notification routing, deduplication, grouping, and escalation. Replaces Nagios contact groups and escalations.

### Incremental Migration

The `prometheus-nagios-exporter` and similar wrappers execute Nagios plugins and expose results as Prometheus metrics, enabling incremental migration. Not recommended long-term (native exporters are preferable) but useful during transition.

---

## Key Differences to Communicate to Teams

- **Nagios is check-oriented** (pass/fail); **Prometheus/Zabbix are metric-oriented** (values over time with alert rules on those values)
- **Nagios configuration is file-based** and statically compiled; Zabbix/Prometheus support dynamic configuration via UI or service discovery
- **Zabbix natively supports auto-discovery and templates** covering most Nagios check use cases with less per-host configuration
- **Prometheus requires separate tooling** (Grafana) for visualization; Nagios Core has minimal graphing (requires PNP4Nagios or Graphite)
- **Nagios expertise translates well to Zabbix** (similar mental model); Prometheus requires learning PromQL and metric-based alerting
- **Zabbix Agent replaces NRPE entirely** -- richer metrics, native encryption, no per-check NRPE configuration
