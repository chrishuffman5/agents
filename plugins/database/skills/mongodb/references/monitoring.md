# MongoDB Monitoring

## Monitoring: currentOp, serverStatus, Profiler

**db.currentOp():** The real-time view of in-flight operations.
```javascript
// All active operations
db.currentOp({ active: true })

// Operations running longer than 10 seconds
db.currentOp({ active: true, secs_running: { $gte: 10 } })

// Operations waiting for locks
db.currentOp({ waitingForLock: true })
```

**db.serverStatus():** Global server metrics (connections, opcounters, WiredTiger, replication).
```javascript
// Full server status
db.serverStatus()

// Specific sections
db.serverStatus().connections
db.serverStatus().opcounters
db.serverStatus().wiredTiger.cache
db.serverStatus().repl
```

**Database profiler:** Records slow operations to the `system.profile` capped collection.
```javascript
// Enable profiling for operations > 100ms
db.setProfilingLevel(1, { slowms: 100 })

// Profile all operations (caution: overhead)
db.setProfilingLevel(2)

// Disable profiling
db.setProfilingLevel(0)

// Query profiler data
db.system.profile.find().sort({ ts: -1 }).limit(10)
```
