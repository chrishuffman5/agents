# timing-pass.ps1 — Strategy 6: serial timing confirmation for headline cells.
# The parallel sweep decides WHICH configs win; this pass produces the wall-clock numbers
# that get quoted (median of N serial repeats, warm-up for local models). Samples land in
# timing_samples; build-report and the report page prefer them where present.
#
#   ./timing-pass.ps1 -CellKey 'claude|claude-opus-5|E1|skill' -Repeats 3
#   ./timing-pass.ps1 -Auto -TopPerCombo 1 -Repeats 3     # auto-pick each combo's P1 pair
[CmdletBinding()]
param(
    [string[]]$CellKey = @(),          # 'harness|model|effort|mode' (pipe-separated)
    [switch]$Auto,                     # derive headline cells (best no-skill + fastest parity skill per combo)
    [int]$TopPerCombo = 1,
    [int]$Repeats = 3,
    [string]$DbPath = (Join-Path $PSScriptRoot 'evalq.sqlite')
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
Import-Module PSSQLite
Import-Module (Join-Path $PSScriptRoot 'MatrixRunner.psm1') -Force
$invoker = Join-Path $PSScriptRoot 'invoke-run.ps1'

$cells = [System.Collections.Generic.List[object]]::new()
foreach ($k in $CellKey) {
    $h, $m, $e, $mo = $k -split '\|'
    $cells.Add(@{ harness = $h; model = $m; effort = $e; mode = $mo })
}
if ($Auto) {
    $agg = Invoke-SqliteQuery -DataSource $DbPath -Query "
        SELECT harness, model, effort_norm effort, skill_mode mode,
               SUM(CASE WHEN grade='pass' THEN 1 ELSE 0 END)*1.0/COUNT(*) acc,
               AVG(wall_ms) wall
        FROM runs WHERE status='done'
        GROUP BY harness, model, effort_norm, skill_mode"
    $combos = $agg | Group-Object harness, model
    foreach ($g in $combos) {
        $ns = $g.Group | Where-Object mode -eq 'no-skill' | Sort-Object @{e='acc';Descending=$true}, wall | Select-Object -First $TopPerCombo
        foreach ($n in $ns) {
            $cells.Add(@{ harness = $n.harness; model = $n.model; effort = $n.effort; mode = 'no-skill' })
            $par = $g.Group | Where-Object { $_.mode -eq 'skill' -and $_.acc -ge $n.acc } | Sort-Object wall | Select-Object -First 1
            if ($par) { $cells.Add(@{ harness = $par.harness; model = $par.model; effort = $par.effort; mode = 'skill' }) }
        }
    }
}
if (-not $cells.Count) { throw 'no cells: pass -CellKey or -Auto' }

foreach ($c in $cells) {
    $runs = Invoke-SqliteQuery -DataSource $DbPath -Query "
        SELECT run_id, model, lane FROM runs
        WHERE harness=@h AND model=@m AND effort_norm=@e AND skill_mode=@mo AND status='done'" `
        -SqlParameters @{ h = $c.harness; m = $c.model; e = $c.effort; mo = $c.mode }
    if (-not $runs) { Write-Warning "no completed runs for $($c.harness)|$($c.model)|$($c.effort)|$($c.mode)"; continue }
    if (@($runs)[0].lane -eq 'local') {
        $tag = @($runs)[0].model -replace '^ollama/', ''
        try { & ollama run $tag --keepalive 45m 'ok' 2>&1 | Out-Null } catch {}
    }
    Write-Host "timing $($c.harness)|$($c.model)|$($c.effort)|$($c.mode) — $(@($runs).Count) runs × $Repeats reps, serial"
    foreach ($r in @($runs)) {
        $base = (Invoke-SqliteQuery -DataSource $DbPath -Query "
            SELECT COALESCE(MAX(rep),0) n FROM timing_samples WHERE run_id=@id" -SqlParameters @{ id = $r.run_id }).n
        for ($i = 1; $i -le $Repeats; $i++) {
            $out = & pwsh -NoProfile -File $invoker -Database $DbPath -RunId $r.run_id -TimingOnly 2>&1 | Out-String
            if ($out -match 'TIMING\s+\S+\s+(\d+)') {
                Invoke-SqliteQuery -DataSource $DbPath -Query "
                    INSERT INTO timing_samples (run_id, rep, wall_ms) VALUES (@id, @rep, @ms)" `
                    -SqlParameters @{ id = $r.run_id; rep = $base + $i; ms = [int]$Matches[1] } | Out-Null
            } else { Write-Warning "no timing line for $($r.run_id): $($out.Trim())" }
        }
    }
}
Invoke-SqliteQuery -DataSource $DbPath -Query "
    SELECT r.harness, r.model, r.effort_norm effort, r.skill_mode mode,
           COUNT(t.wall_ms) samples, CAST(AVG(t.wall_ms) AS INTEGER) mean_ms
    FROM timing_samples t JOIN runs r ON r.run_id = t.run_id
    GROUP BY r.harness, r.model, r.effort_norm, r.skill_mode" |
    Format-Table -AutoSize | Out-String | Write-Host
