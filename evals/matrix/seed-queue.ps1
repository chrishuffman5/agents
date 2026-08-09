# seed-queue.ps1 — Strategy 1: expand matrix.config.json × suite tasks into the SQLite queue.
# Every row is a fully rendered, reproducible CLI invocation. Secrets are stored as
# @secret: tokens and resolved only at dispatch time — never written into the database.
#
#   ./seed-queue.ps1                 # seed evalq.sqlite next to this script
#   ./seed-queue.ps1 -Force          # drop and re-seed
#   ./seed-queue.ps1 -WhatIfSummary  # print the expansion without writing

[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'matrix.config.json'),
    [string]$DbPath     = (Join-Path $PSScriptRoot 'evalq.sqlite'),
    [switch]$Force,
    [switch]$WhatIfSummary
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
Import-Module PSSQLite
Import-Module (Join-Path $PSScriptRoot 'MatrixRunner.psm1') -Force

$cfg   = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$suite = Get-Content (Join-Path $PSScriptRoot $cfg.suite) -Raw | ConvertFrom-Json

# Prompts must be double-quote-free: the command column embeds them verbatim.
foreach ($t in $suite.tasks) {
    if ($t.prompt -match '["`$]') { throw "Task $($t.id): prompt contains a forbidden character (double quote, backtick, or dollar sign)." }
}

if ($Force -and (Test-Path $DbPath)) { Remove-Item $DbPath -Force }
if ((Test-Path $DbPath) -and -not $WhatIfSummary) {
    $existing = (Invoke-SqliteQuery -DataSource $DbPath -Query "SELECT COUNT(*) AS n FROM runs").n
    if ($existing -gt 0) { throw "evalq.sqlite already holds $existing runs. Use -Force to re-seed, or dispatch the existing queue." }
}

# ---- expand cells ----------------------------------------------------------
$rows = [System.Collections.Generic.List[object]]::new()
foreach ($laneCfg in $cfg.lanes) {
    $sandbox = if ($laneCfg.PSObject.Properties['sandbox']) { $laneCfg.sandbox } else { $null }
    foreach ($m in $laneCfg.models) {
        foreach ($effortProp in $laneCfg.efforts.PSObject.Properties) {
            $effortNorm = $effortProp.Name; $effortLiteral = $effortProp.Value
            foreach ($skillMode in $cfg.skillModes) {
                foreach ($task in $suite.tasks) {
                    for ($a = 1; $a -le $cfg.attempts; $a++) {
                        $modelSlug = $m.id -replace '[:/\\]', '-'
                        $runId = '{0}.{1}.{2}.{3}.{4}.a{5}' -f $laneCfg.harness, $modelSlug, $effortNorm, $skillMode, $task.id, $a
                        $workspace = Join-Path $cfg.paths.workRoot (Join-Path $laneCfg.harness $runId)

                        # per-run env: resolve @skillmode tokens now; keep @secret tokens for dispatch
                        $env = @{}
                        if ($laneCfg.PSObject.Properties['env']) {
                            foreach ($kv in $laneCfg.env.PSObject.Properties) {
                                $env[$kv.Name] = switch ($kv.Value) {
                                    '@skillmode:codexHome' {
                                        if ($skillMode -eq 'skill') { $cfg.paths.codexHomeSkills } else { $cfg.paths.codexHomeBare } }
                                    default { $kv.Value }
                                }
                            }
                        }

                        $cell = @{
                            harness = $laneCfg.harness; lane = $laneCfg.lane; model = $m.id
                            effortLiteral = $effortLiteral; skillMode = $skillMode
                            sandbox = $sandbox; workspace = $workspace; prompt = $task.prompt
                            pluginDir = $cfg.paths.pluginDir
                            skillPath = $cfg.skillPaths.($task.skill)
                            codexProfile = if ($m.PSObject.Properties['profile']) { $m.profile } else { $null }
                        }

                        $rows.Add([pscustomobject]@{
                            run_id = $runId
                            harness = $laneCfg.harness; provider = $laneCfg.provider; model = $m.id
                            effort_norm = $effortNorm; effort_literal = $effortLiteral
                            skill_mode = $skillMode; lane = $laneCfg.lane; sandbox = $sandbox
                            suite = $suite.suite; task_id = $task.id; skill = $task.skill
                            knowledge = $task.knowledge; attempt = $a
                            command = New-CellCommand -Cell $cell
                            env_json = ($env | ConvertTo-Json -Compress)
                            workspace = $workspace
                        })
                    }
                }
            }
        }
    }
}

# ---- summary ---------------------------------------------------------------
$byLane    = $rows | Group-Object lane       | ForEach-Object { '{0,-6} {1,5}' -f $_.Name, $_.Count }
$byHarness = $rows | Group-Object harness    | ForEach-Object { '{0,-6} {1,5}' -f $_.Name, $_.Count }
$byMode    = $rows | Group-Object skill_mode | ForEach-Object { '{0,-9} {1,5}' -f $_.Name, $_.Count }
$cells     = ($rows | Group-Object harness, model, effort_norm, skill_mode).Count
Write-Host "expansion: $($rows.Count) runs across $cells cells"
Write-Host ("  by lane:    " + ($byLane -join '   '))
Write-Host ("  by harness: " + ($byHarness -join '   '))
Write-Host ("  by mode:    " + ($byMode -join '   '))
if ($WhatIfSummary) { return }

# ---- write -----------------------------------------------------------------
Initialize-EvalDb -Database $DbPath -SchemaPath (Join-Path $PSScriptRoot 'schema.sql')
$conn = New-SQLiteConnection -DataSource $DbPath
try {
    Invoke-SqliteQuery -SQLiteConnection $conn -Query 'BEGIN TRANSACTION' | Out-Null
    $insert = @"
INSERT INTO runs (run_id, harness, provider, model, effort_norm, effort_literal, skill_mode,
                  lane, sandbox, suite, task_id, skill, knowledge, attempt, command, env_json, workspace)
VALUES (@run_id, @harness, @provider, @model, @effort_norm, @effort_literal, @skill_mode,
        @lane, @sandbox, @suite, @task_id, @skill, @knowledge, @attempt, @command, @env_json, @workspace)
"@
    foreach ($r in $rows) {
        $p = @{}; $r.PSObject.Properties | ForEach-Object { $p[$_.Name] = $_.Value }
        Invoke-SqliteQuery -SQLiteConnection $conn -Query $insert -SqlParameters $p | Out-Null
    }
    Invoke-SqliteQuery -SQLiteConnection $conn -Query 'COMMIT' | Out-Null
} catch {
    Invoke-SqliteQuery -SQLiteConnection $conn -Query 'ROLLBACK' | Out-Null
    throw
} finally {
    $conn.Close()
}
Write-Host "seeded $($rows.Count) runs -> $DbPath"
