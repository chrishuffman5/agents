# regrade.ps1 — re-grade stored answers against the CURRENT suite specs. No tokens spent.
# Suites are the grading source of truth (see README: "Where tasks come from"), so a spec fix
# means completed runs can be re-graded from their stored answers instead of re-executed.
#
#   ./regrade.ps1            # regrade every done run, report changes
#   ./regrade.ps1 -WhatIf    # show what would change without writing
[CmdletBinding()]
param(
    [string]$DbPath = (Join-Path $PSScriptRoot 'evalq.sqlite'),
    [switch]$WhatIf
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
Import-Module PSSQLite
Import-Module (Join-Path $PSScriptRoot 'MatrixRunner.psm1') -Force -WarningAction SilentlyContinue
$cfg = Get-Content (Join-Path $PSScriptRoot 'matrix.config.json') -Raw | ConvertFrom-Json

# task_id -> expected map across all suites
$specs = @{}
foreach ($sf in $cfg.suites) {
    $file = if ($sf -is [string]) { $sf } else { $sf.file }
    $s = Get-Content (Join-Path $PSScriptRoot $file) -Raw | ConvertFrom-Json
    foreach ($t in $s.tasks) { $specs[$t.id] = $t.expected }
}

$rows = Invoke-SqliteQuery -DataSource $DbPath -Query "
    SELECT run_id, task_id, answer, grade FROM runs WHERE status='done' AND answer IS NOT NULL"
$changed = [System.Collections.Generic.List[object]]::new()
foreach ($r in $rows) {
    if (-not $specs.ContainsKey($r.task_id)) { continue }
    $ans = if ($r.answer -is [System.DBNull]) { $null } else { [string]$r.answer }
    $new = if (Test-ExpectedSpec -Expected $specs[$r.task_id] -Answer $ans) { 'pass' } else { 'fail' }
    if ($new -ne $r.grade) { $changed.Add([pscustomobject]@{ run_id = $r.run_id; old = $r.grade; new = $new }) }
}
"checked $($rows.Count) done runs; grade changes: $($changed.Count)"
$changed | Group-Object old, new | ForEach-Object { "  $($_.Name): $($_.Count)" }
if ($WhatIf -or -not $changed.Count) { return }

foreach ($c in $changed) {
    Invoke-SqliteQuery -DataSource $DbPath -Query "
        UPDATE runs SET grade=@g, graded_by='expected-spec (regraded)' WHERE run_id=@id" `
        -SqlParameters @{ g = $c.new; id = $c.run_id } | Out-Null
}
"applied $($changed.Count) grade updates"
