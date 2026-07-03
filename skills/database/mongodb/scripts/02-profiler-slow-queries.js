// Purpose:        Slowest recent operations from the profiler collection - the historical slow-query ranking
// Applies to:     MongoDB 6.0+ (run in mongosh against the target database)
// Read-only:      yes (assumes profiling level 1+ already enabled: db.setProfilingLevel(1, { slowms: 100 }))
// Inputs:         run with 'use __DATABASE__' first
// Interpretation: docsExamined far above nreturned = the missing-index signature; planSummary COLLSCAN confirms it.
//                 High numYield = the op kept ceding to others - long scan under contention. If system.profile is
//                 empty, profiling is off - enabling level 1 with a sane slowms is itself the first recommendation
//                 (small, capped overhead).
// Next step:      Build the index the shape demands; verify with .explain("executionStats") before/after

if (db.system.profile.countDocuments({}) === 0) {
    print("system.profile is empty - profiling not enabled. Run: db.setProfilingLevel(1, { slowms: 100 })");
} else {
    db.system.profile.find({ op: { $in: ["query", "update", "remove", "command"] } })
        .sort({ millis: -1 })
        .limit(15)
        .forEach(p => {
            print([
                "millis=" + p.millis,
                "ns=" + p.ns,
                "op=" + p.op,
                "plan=" + (p.planSummary || "-"),
                "examined=" + (p.docsExamined ?? "-"),
                "returned=" + (p.nreturned ?? "-"),
                "ts=" + p.ts.toISOString()
            ].join("  "));
        });
}
