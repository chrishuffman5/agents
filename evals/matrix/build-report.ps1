# build-report.ps1 — aggregate evalq.sqlite into report/results.js for the local report page.
# Run after (or during) a sweep; the page falls back to the labeled synthetic sample
# only when results.js is absent or reports zero completed runs.
[CmdletBinding()]
param(
    [string]$DbPath  = (Join-Path $PSScriptRoot 'evalq.sqlite'),
    [string]$OutPath = (Join-Path $PSScriptRoot 'report\results.js')
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
Import-Module PSSQLite

$status = @{}
Invoke-SqliteQuery -DataSource $DbPath -Query "SELECT status, COUNT(*) n FROM runs GROUP BY status" |
    ForEach-Object { $status[$_.status] = $_.n }
foreach ($s in 'queued','running','done','error') { if (-not $status.ContainsKey($s)) { $status[$s] = 0 } }

$lanes = Invoke-SqliteQuery -DataSource $DbPath -Query "
    SELECT lane, harness, COUNT(*) total, SUM(CASE WHEN status='done' THEN 1 ELSE 0 END) done
    FROM runs GROUP BY lane, harness"

# pass = grade='pass'; wall/tokens averaged over completed runs only
$cells = Invoke-SqliteQuery -DataSource $DbPath -Query "
    SELECT harness, provider, model, lane, effort_norm AS effort, skill_mode AS mode,
           COUNT(*) runs,
           SUM(CASE WHEN status='done' THEN 1 ELSE 0 END) done,
           SUM(CASE WHEN grade='pass' THEN 1 ELSE 0 END) pass,
           CAST(AVG(CASE WHEN status='done' THEN wall_ms END) AS INTEGER) wallMs,
           CAST(AVG(CASE WHEN status='done' THEN tokens_out END) AS INTEGER) tokensOut,
           ROUND(SUM(CASE WHEN status='done' THEN cost_usd END), 4) cost
    FROM runs
    GROUP BY harness, provider, model, lane, effort_norm, skill_mode"

$tasks = Invoke-SqliteQuery -DataSource $DbPath -Query "
    SELECT task_id AS id, skill, knowledge,
           SUM(CASE WHEN skill_mode='skill' THEN 1 ELSE 0 END) nSkill,
           SUM(CASE WHEN skill_mode='skill' AND grade='pass' THEN 1 ELSE 0 END) passSkill,
           SUM(CASE WHEN skill_mode='no-skill' THEN 1 ELSE 0 END) nNoSkill,
           SUM(CASE WHEN skill_mode='no-skill' AND grade='pass' THEN 1 ELSE 0 END) passNoSkill
    FROM runs GROUP BY task_id, skill, knowledge"

$payload = [ordered]@{
    sample    = $false
    generated = (Get-Date).ToString('o')
    suite     = ((( Get-Content (Join-Path $PSScriptRoot 'matrix.config.json') -Raw | ConvertFrom-Json ).suites |
                  ForEach-Object { if ($_ -is [string]) { $_ } else { $_.file } } |
                  ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) }) -join ' + ')
    status    = $status
    lanes     = @($lanes)
    cells     = @($cells)
    tasks     = @($tasks)
}
$json = $payload | ConvertTo-Json -Depth 6 -Compress
New-Item -ItemType Directory -Force (Split-Path $OutPath) | Out-Null
Set-Content -Path $OutPath -Value "window.MATRIX_RESULTS = $json;" -Encoding utf8
Write-Host "wrote $OutPath ($($status['done']) done / $(($status.Values | Measure-Object -Sum).Sum) total runs)"
