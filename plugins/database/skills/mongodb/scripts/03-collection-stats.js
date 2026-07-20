// Purpose:        Collection and index sizes for the current database - capacity map and index-sprawl check
// Applies to:     MongoDB 6.0+ (run in mongosh; 'use __DATABASE__' first)
// Read-only:      yes
// Inputs:         none
// Interpretation: totalIndexSize rivaling storageSize = index sprawl - cross-check 04-index-usage.js before dropping.
//                 avgObjSize creeping up over time = documents growing in place (arrays that never stop appending) -
//                 the unbounded-array anti-pattern; redesign before 16MB document limits or move-heavy updates bite.
//                 Compare count vs your expectations - runaway collections are usually logging/queue collections
//                 nobody TTL-indexed.
// Next step:      04-index-usage.js for per-index utilization; add TTL indexes to log-like collections

db.getCollectionNames().sort().forEach(name => {
    const s = db.getCollection(name).stats();
    if (!s.ok && s.ok !== undefined) return;
    print([
        name.padEnd(40),
        "docs=" + s.count,
        "avgObj=" + (s.avgObjSize ? Math.round(s.avgObjSize) + "B" : "-"),
        "data=" + Math.round((s.size || 0) / 1048576) + "MB",
        "storage=" + Math.round((s.storageSize || 0) / 1048576) + "MB",
        "indexes=" + s.nindexes,
        "indexSize=" + Math.round((s.totalIndexSize || 0) / 1048576) + "MB"
    ].join("  "));
});
