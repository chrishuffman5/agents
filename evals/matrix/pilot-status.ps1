# pilot-status.ps1 — one-line pilot local-lane status for monitors: "left|errors|done"
Import-Module PSSQLite
$r = Invoke-SqliteQuery -DataSource (Join-Path $PSScriptRoot 'evalq.sqlite') -Query @"
SELECT SUM(CASE WHEN status IN ('queued','running') THEN 1 ELSE 0 END) leftn,
       SUM(CASE WHEN status = 'error' THEN 1 ELSE 0 END) errn,
       SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) donen
FROM runs WHERE lane = 'local' AND suite IN ('aws','cli-scripting','cloud-platforms')
"@
Write-Output "$($r.leftn)|$($r.errn)|$($r.donen)"
