// Purpose:        Replica set health - member states, replication lag, oplog window
// Applies to:     MongoDB 6.0+ replica sets (run in mongosh; requires clusterMonitor)
// Read-only:      yes
// Inputs:         none
// Interpretation: Lag over a few seconds sustained = secondary falling behind (undersized, index builds, or network) -
//                 reads-from-secondary serve stale data and a failover loses more. Oplog window shrinking below your
//                 longest maintenance window = a resynced/restarted secondary may need a full initial sync instead of
//                 catching up - grow the oplog before that happens. Any member not SECONDARY/PRIMARY/ARBITER is the
//                 incident.
// Next step:      Fix the lagging member (resources, hidden+delayed config review); size oplog via replSetResizeOplog

const s = rs.status();
const primary = s.members.find(m => m.stateStr === "PRIMARY");

print("== Members");
s.members.forEach(m => {
    const lag = (primary && m.optimeDate && primary.optimeDate)
        ? Math.round((primary.optimeDate - m.optimeDate) / 1000) : "-";
    print([
        m.name.padEnd(35),
        m.stateStr.padEnd(10),
        "health=" + m.health,
        "lagSecs=" + (m.stateStr === "PRIMARY" ? 0 : lag),
        "uptime=" + m.uptime
    ].join("  "));
});

print("\n== Oplog window");
const ol = db.getSiblingDB("local").oplog.rs;
const first = ol.find().sort({ $natural: 1 }).limit(1).next().ts;
const last  = ol.find().sort({ $natural: -1 }).limit(1).next().ts;
print("window_hours=" + Math.round((last.getTime() - first.getTime()) / 3600 * 10) / 10);
