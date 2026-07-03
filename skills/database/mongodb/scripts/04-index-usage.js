// Purpose:        Per-index usage counts via $indexStats - find dead indexes burning write throughput
// Applies to:     MongoDB 6.0+ (run in mongosh; 'use __DATABASE__' first). On clusters, run against each shard/replica set member serving reads - stats are per-node since last restart
// Read-only:      yes
// Inputs:         none
// Interpretation: ops = 0 since 'since' on every read-serving node = a drop candidate - every write pays for that
//                 index forever. EXCEPTIONS: unique indexes (constraint, not lookup), TTL indexes (expiry, not lookup),
//                 and recent restarts (check the since timestamp!). Confirm across all nodes and a full business cycle
//                 (month-end reports) before dropping.
// Next step:      db.collection.dropIndex() for confirmed dead ones - with user signoff and after a full-cycle check

db.getCollectionNames().sort().forEach(name => {
    try {
        db.getCollection(name).aggregate([{ $indexStats: {} }]).forEach(ix => {
            print([
                (name + "." + ix.name).padEnd(60),
                "ops=" + ix.accesses.ops,
                "since=" + ix.accesses.since.toISOString()
            ].join("  "));
        });
    } catch (e) { /* views and special collections have no $indexStats */ }
});
