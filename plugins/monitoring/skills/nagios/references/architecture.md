# Nagios Architecture Reference

> Core vs XI, execution model, configuration, plugins, alerting, and operations.

---

## Core vs XI

**Nagios Core** is the open-source foundation. C-based daemon (`nagios`) reading object configuration files, scheduling checks, evaluating results, firing notifications. Web interface (CGIs) is minimal and read-only. No built-in dashboards or reporting.

**Nagios XI** is the commercial product on top of Core. Modern PHP/MySQL web UI, configuration wizards, autodiscovery, dashboards, SLA reporting, and RBAC. Licensed per monitored node. Uses the same Core scheduling engine underneath.

Key difference: Core is config-file-driven; XI provides a GUI that writes config files, then reloads Core.

---

## Execution Model

### Active Checks

Nagios initiates on a schedule. Runs a plugin binary directly or via NRPE for remote hosts. Results return synchronously within configurable timeout.

### Passive Checks

External processes submit results to the External Command File (named pipe at `/var/nagios/rw/nagios.cmd`). Nagios updates state without running a plugin. Used for event-driven systems, long-running jobs, and firewalled environments.

### NRPE (Nagios Remote Plugin Executor)

Small daemon on monitored Linux/Unix hosts. Nagios sends command name via `check_nrpe`; NRPE executes the plugin locally and returns result. Config: `/etc/nagios/nrpe.cfg`.

```ini
allowed_hosts=192.168.1.10
command[check_disk]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /
command[check_load]=/usr/lib/nagios/plugins/check_load -w 5,4,3 -c 10,8,6
```

### NSCA (Nagios Service Check Acceptor)

Server-side daemon receiving passive results from remote hosts (TCP port 5667). Remote agents use `send_nsca` to push. Supports encryption. Used for DMZ hosts initiating contact.

---

## Object Definitions

### Hosts

Represent monitored machines. Key directives: `host_name`, `alias`, `address`, `check_command`, `max_check_attempts`, `check_interval`, `retry_interval`, `check_period`, `notification_period`, `contacts`, `contact_groups`.

### Services

Checks attached to a host. Key directives: `service_description`, `host_name` or `hostgroup_name`, `check_command`, thresholds, intervals, notification settings.

### Contacts

People or teams receiving notifications. Directives: `contact_name`, `email`, `service_notification_commands`, `host_notification_commands`, `notification_period`.

### Commands

Map command name to plugin binary with arguments. Macros substituted at execution: `$HOSTADDRESS$`, `$ARG1$`, `$ARG2$`.

```cfg
define command {
    command_name    check_http_port
    command_line    $USER1$/check_http -H $HOSTADDRESS$ -p $ARG1$ -u $ARG2$ -w $ARG3$ -c $ARG4$
}
```

### Timeperiods

Named time windows (24x7, workhours). Restrict when checks run and notifications fire.

### Groups

Hostgroups, servicegroups, contactgroups for bulk assignment and routing.

---

## Templates and Inheritance

Templates are object definitions with `register 0`. Child objects override parent values. Multiple parents: `use parent1,parent2` (left-to-right precedence).

```cfg
define host {
    name                    generic-host
    check_period            24x7
    check_interval          5
    retry_interval          1
    max_check_attempts      3
    notification_period     24x7
    notification_interval   60
    register                0
}

define host {
    name                    linux-server
    use                     generic-host
    check_command           check-host-alive
    register                0
}

define host {
    use         linux-server
    host_name   web01
    alias       Web Server 01
    address     192.168.1.20
}
```

---

## Plugin System

### Standard Plugins

Installed to `/usr/lib/nagios/plugins/`. Key plugins:

| Plugin | Purpose | Options |
|--------|---------|---------|
| `check_ping` | ICMP reachability | `-H host -w rta,loss% -c rta,loss%` |
| `check_http` | HTTP/HTTPS checks | `-H host -u /path -w secs -c secs --ssl` |
| `check_disk` | Filesystem usage | `-w 20% -c 10% -p /mount` |
| `check_load` | Load averages | `-w 5,4,3 -c 10,8,6` |
| `check_procs` | Process count | `-w 300 -c 400` or `-C name` |
| `check_snmp` | SNMP OID | `-H host -o OID -w warn -c crit` |
| `check_tcp` | TCP port | `-H host -p port -w secs -c secs` |
| `check_nrpe` | Remote NRPE | `-H host -c command_name` |

### Return Codes

| Code | State | Meaning |
|------|-------|---------|
| 0 | OK | Normal |
| 1 | WARNING | Degraded |
| 2 | CRITICAL | Failed |
| 3 | UNKNOWN | Cannot determine |

### Performance Data

```
OK - Load: 0.42|load1=0.42;5;10;0; load5=0.38;4;8;0; load15=0.31;3;6;0;
```

Format: `label=value[UOM];[warn];[crit];[min];[max]`

### Check Intervals

All intervals in minutes (configurable via `interval_length` in `nagios.cfg`):
- `check_interval` -- Frequency in OK state
- `retry_interval` -- Frequency after non-OK result
- `max_check_attempts` -- Retries before HARD state and notifications
- `freshness_threshold` -- Max age for passive checks before stale

---

## Alerting

### Notifications

Fires on state transitions (OK to CRITICAL, etc.) when service reaches HARD state. Notification options: `w` (warning), `c` (critical), `u` (unknown), `r` (recovery), `f` (flapping), `s` (downtime), `n` (none).

### Escalations

```cfg
define serviceescalation {
    host_name               web01
    service_description     HTTP
    first_notification      3
    last_notification       5
    notification_interval   30
    contact_groups          senior-admins
}
```

### Dependencies

Suppress checks/notifications when parent is down:

```cfg
define servicedependency {
    host_name                       db01
    service_description             MySQL
    dependent_host_name             web01
    dependent_service_description   App
    execution_failure_criteria      c,u
    notification_failure_criteria   c,u
}
```

### Flap Detection

Tracks state change history over 21 checks. Flapping when change % exceeds `high_service_flap_threshold` (20%). Ends when below `low_service_flap_threshold` (5%).

### Event Handlers

Commands executed on state change for auto-remediation:

```cfg
define service {
    event_handler           restart-httpd
    event_handler_enabled   1
}
```

### Acknowledgements and Downtime

- **Acknowledgements:** Mark problem as known, suppress repeat notifications until recovery
- **Scheduled downtime:** Block notifications during maintenance, results still recorded
