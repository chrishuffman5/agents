#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
  Runs domain-specialist agent evals: known-correct task suites executed by
  Sonnet subagents, logging token utilization, wall-clock, and attempts-to-correct.
.EXAMPLE
  ./evals/run-evals.ps1 -Suite database,os -MaxAttempts 3
.EXAMPLE
  ./evals/run-evals.ps1 -Suite database -Baseline   # control run without agents/skills
#>
[CmdletBinding()]
param(
    [string[]]$Suite,              # suite names (file base names in suites/); default: all
    [int]$MaxAttempts = 3,         # independent attempts per task before recording failure
    [string]$Model,                # optional --model override for the orchestrating session
    [switch]$Baseline,             # answer from raw model knowledge; no agents, no tools
    [int]$MaxTurns = 30,           # turn cap per attempt
    [string]$OutDir = (Join-Path $PSScriptRoot 'results')
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$suiteDir = Join-Path $PSScriptRoot 'suites'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw "The 'claude' CLI is not on PATH. Install Claude Code and authenticate first."
}

$suiteFiles = Get-ChildItem $suiteDir -Filter '*.json' | Where-Object { $_.BaseName -notlike '_*' }
if ($Suite) { $suiteFiles = $suiteFiles | Where-Object { $Suite -contains $_.BaseName } }
if (-not $suiteFiles) { throw "No suites matched. Available: $((Get-ChildItem $suiteDir -Filter '*.json').BaseName -join ', ')" }

$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + ($Baseline ? '-baseline' : '')
$attemptLog = Join-Path $OutDir "$runId-attempts.jsonl"
$summaryCsv = Join-Path $OutDir "$runId-summary.csv"

function Test-Answer([string]$answer, $expected) {
    switch ($expected.type) {
        'exact'        { return $answer.Trim() -eq $expected.value }
        'regex'        { return $answer -match $expected.value }
        'contains_all' { foreach ($s in $expected.value) { if ($answer.IndexOf([string]$s, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false } } return $true }
        'contains_any' { foreach ($s in $expected.value) { if ($answer.IndexOf([string]$s, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true } } return $false }
        default        { throw "Unknown expected.type '$($expected.type)'" }
    }
}

function Invoke-Attempt([string]$prompt, [string]$agent) {
    if ($Baseline) {
        $fullPrompt = "Answer from your own knowledge only. Do NOT use any tools, skills, files, or subagents.`n`nTask: $prompt"
        $tools = ''   # no tools auto-approved; task demands none
    } else {
        $fullPrompt = "Use the Task tool to delegate the following task to the '$agent' subagent. When it finishes, reply with ONLY the subagent's final answer - no commentary of your own.`n`nTask: $prompt"
        $tools = 'Task,Read,Glob,Grep'
    }

    $args = @('-p', $fullPrompt, '--output-format', 'json', '--max-turns', $MaxTurns)
    if ($tools) { $args += @('--allowedTools', $tools) }
    if ($Model) { $args += @('--model', $Model) }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Push-Location $repoRoot
    try     { $raw = & claude @args 2>&1 | Out-String }
    finally { Pop-Location; $sw.Stop() }

    $rec = [ordered]@{
        wall_ms = $sw.ElapsedMilliseconds; answer = $null; ok = $false
        api_ms = $null; num_turns = $null; cost_usd = $null
        input_tokens = $null; output_tokens = $null; cache_read_tokens = $null; cache_creation_tokens = $null
        raw_error = $null
    }
    try {
        $j = $raw | ConvertFrom-Json
        $rec.ok            = ($j.subtype -eq 'success')
        $rec.answer        = [string]$j.result
        $rec.api_ms        = $j.duration_api_ms ?? $j.duration_ms
        $rec.num_turns     = $j.num_turns
        $rec.cost_usd      = $j.total_cost_usd
        $u = $j.usage
        if ($u) {
            $rec.input_tokens          = $u.input_tokens
            $rec.output_tokens         = $u.output_tokens
            $rec.cache_read_tokens     = $u.cache_read_input_tokens
            $rec.cache_creation_tokens = $u.cache_creation_input_tokens
        }
    } catch {
        $rec.raw_error = ($raw.Length -gt 2000) ? $raw.Substring(0, 2000) : $raw
    }
    return $rec
}

$allRows = @()
foreach ($sf in $suiteFiles) {
    $suiteDef = Get-Content $sf.FullName -Raw | ConvertFrom-Json
    Write-Host "`n=== Suite: $($suiteDef.domain)  (agent: $($suiteDef.agent), mode: $($Baseline ? 'BASELINE' : 'agent'))" -ForegroundColor Cyan

    foreach ($task in $suiteDef.tasks) {
        $firstPass = $null
        for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
            Write-Host ("  [{0}] attempt {1}/{2} ... " -f $task.id, $attempt, $MaxAttempts) -NoNewline
            $r = Invoke-Attempt -prompt $task.prompt -agent $suiteDef.agent
            $pass = $r.ok -and $r.answer -and (Test-Answer -answer $r.answer -expected $task.expected)
            Write-Host ($pass ? 'PASS' : 'fail') -ForegroundColor ($pass ? 'Green' : 'Yellow')

            $row = [pscustomobject]([ordered]@{
                run_id = $runId; timestamp = (Get-Date -Format 'o'); mode = ($Baseline ? 'baseline' : 'agent')
                suite = $suiteDef.domain; task_id = $task.id; agent = $suiteDef.agent
                attempt = $attempt; pass = $pass
                wall_ms = $r.wall_ms; api_ms = $r.api_ms; num_turns = $r.num_turns; cost_usd = $r.cost_usd
                input_tokens = $r.input_tokens; output_tokens = $r.output_tokens
                cache_read_tokens = $r.cache_read_tokens; cache_creation_tokens = $r.cache_creation_tokens
                answer_excerpt = if ($r.answer) { ($r.answer.Length -gt 500) ? $r.answer.Substring(0, 500) : $r.answer } else { $r.raw_error }
            })
            $row | ConvertTo-Json -Compress | Add-Content -Path $attemptLog
            $allRows += $row
            if ($pass) { $firstPass = $attempt; break }
        }
        if (-not $firstPass) { Write-Host ("  [{0}] FAILED after {1} attempts" -f $task.id, $MaxAttempts) -ForegroundColor Red }
    }
}

# ---- Summary ----
$summary = $allRows | Group-Object suite | ForEach-Object {
    $rows = $_.Group
    $byTask = $rows | Group-Object task_id
    $passedTasks = $byTask | Where-Object { $_.Group.pass -contains $true }
    [pscustomobject]@{
        suite            = $_.Name
        mode             = $rows[0].mode
        tasks            = $byTask.Count
        solved           = $passedTasks.Count
        pass_at_1        = [math]::Round((($byTask | Where-Object { ($_.Group | Where-Object attempt -eq 1).pass }).Count / $byTask.Count), 3)
        mean_attempts    = [math]::Round((($passedTasks | ForEach-Object { ($_.Group | Where-Object pass).attempt | Select-Object -First 1 } | Measure-Object -Average).Average ?? 0), 2)
        mean_out_tokens  = [math]::Round((($rows.output_tokens | Where-Object { $_ } | Measure-Object -Average).Average ?? 0), 0)
        mean_wall_s      = [math]::Round((($rows.wall_ms | Measure-Object -Average).Average / 1000), 1)
        total_cost_usd   = [math]::Round((($rows.cost_usd | Where-Object { $_ } | Measure-Object -Sum).Sum ?? 0), 4)
    }
}
$summary | Export-Csv -Path $summaryCsv -NoTypeInformation
Write-Host "`n=== Summary ($runId)" -ForegroundColor Cyan
$summary | Format-Table -AutoSize
Write-Host "Attempts log: $attemptLog`nSummary CSV:  $summaryCsv"
