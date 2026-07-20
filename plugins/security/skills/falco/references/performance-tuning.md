# Falco Performance and Tuning

### eBPF Ring Buffer

The ring buffer is shared memory between kernel eBPF program and Falco userspace:
```yaml
# falco.yaml: tune ring buffer size
syscall_buf_size_preset: 4   # preset 1-6; higher = larger buffer

# Or specify directly
syscall_event_drops:
  actions:
    - log
    - alert
  rate: 0.03333
  max_burst: 10
```

**Event drops:**
If Falco can't process events fast enough, the ring buffer fills and events are dropped. Indicators:
```
Falco log: "10 system call event drops in last second"
```
Response: increase ring buffer size, add more CPU resources, or apply more aggressive event filtering.

### Rule Performance

Expensive conditions (check these if CPU is high):
- `glob` pattern matching on `proc.cmdline` (full string match on command lines)
- `pmatch` (regex on fields)
- Multiple `or` clauses in one condition

**Optimize with macros:**
```yaml
# Slow: evaluated per event
condition: >
  evt.type = execve and evt.dir = < and container.id != host
  and not proc.name in (thousands_of_allowed_processes)

# Fast: filter with cheap conditions first
condition: >
  spawned_process    # macro: evt.type=execve AND evt.dir=<
  and container      # macro: container.id != host
  and interesting_process   # only then check the expensive list
```

**Priority filtering:**
```yaml
# Only process events that could match WARNING+ priority rules
# Lower = more events = higher CPU
# Higher = fewer events = lower CPU but missed low-priority detections
syscall_event_drops:
  threshold: 0.1    # drop events if buffer >10% full
```
