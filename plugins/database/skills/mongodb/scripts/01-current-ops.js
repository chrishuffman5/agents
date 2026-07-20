// Purpose:        Long-running operations right now - the MongoDB equivalent of a blocking/activity check
// Applies to:     MongoDB 6.0+ (run in mongosh; requires clusterMonitor role or better)
// Read-only:      yes
// Inputs:         none; adjust the 5-second threshold as needed
// Interpretation: Ops with secs_running in the hundreds holding locks starve everything behind them. planSummary
//                 COLLSCAN on a large collection = missing index (cross-check 02-profiler-slow-queries.js). Ops from
//                 'unknown' or admin apps doing collection scans at business hours are usually ad-hoc analytics -
//                 route those to a secondary. Kill with db.killOp(opid) ONLY with user signoff.
// Next step:      02-profiler-slow-queries.js for the historical pattern; 04-index-usage.js for the index angle

const threshold = 5; // seconds

db.currentOp({ active: true, secs_running: { $gte: threshold } }).inprog.forEach(op => {
    print([
        "opid=" + op.opid,
        "secs=" + op.secs_running,
        "ns=" + (op.ns || "-"),
        "op=" + op.op,
        "plan=" + (op.planSummary || "-"),
        "client=" + (op.client || op.client_s || "-"),
        "desc=" + (op.desc || "-")
    ].join("  "));
    if (op.command) printjson(op.command);
    print("---");
});
