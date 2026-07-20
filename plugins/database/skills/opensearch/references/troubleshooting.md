# OpenSearch Troubleshooting Decision Tree

Symptom-first routing tree pointing to the relevant diagnostics or best-practices section for each failure mode.

---

## Troubleshooting Decision Tree

```
Problem reported
  |
  +-- Cluster health red/yellow?
  |     --> references/diagnostics.md (Cluster Health section)
  |     --> GET _cluster/allocation/explain
  |
  +-- Slow search queries?
  |     --> references/diagnostics.md (Search Performance section)
  |     --> Check slow logs, profile API, hot threads
  |
  +-- High memory/GC pressure?
  |     --> references/diagnostics.md (JVM/Memory section)
  |     --> Check circuit breakers, fielddata, segment memory
  |
  +-- Indexing throughput low?
  |     --> references/best-practices.md (Indexing Performance section)
  |     --> Check refresh interval, bulk size, merge throttle
  |
  +-- Security/access issues?
  |     --> GET _plugins/_security/api/roles
  |     --> GET _plugins/_security/authinfo
  |     --> Check audit logs
  |
  +-- ISM policy not executing?
  |     --> GET _plugins/_ism/explain/index-name
  |     --> Check policy validation, state transitions
  |
  +-- k-NN search slow or OOM?
  |     --> references/diagnostics.md (k-NN section)
  |     --> Check circuit_breaker_limit, warmup, graph memory
  |
  +-- Migration from Elasticsearch?
        --> Check API compatibility, plugin equivalents, terminology changes
```
