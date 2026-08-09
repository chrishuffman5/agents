# invoke-run.ps1 — execute ONE run in a clean child process. The only place $env: is set.
# The dispatcher claims the row (status=running) and launches this script; it executes the
# pre-rendered command, parses, grades, and writes the result itself. Always exits 0 —
# outcomes live in the database, not in exit codes (codex's are undocumented anyway).
#
#   pwsh -NoProfile -File invoke-run.ps1 -Database <db> -RunId <id>
#   pwsh -NoProfile -File invoke-run.ps1 -Database <db> -RunId <id> -TimingOnly   # execute + print ms, no DB writes
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Database,
    [Parameter(Mandatory)][string]$RunId,
    [switch]$TimingOnly
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
Import-Module PSSQLite
Import-Module (Join-Path $PSScriptRoot 'MatrixRunner.psm1') -Force
$cfg = Get-Content (Join-Path $PSScriptRoot 'matrix.config.json') -Raw | ConvertFrom-Json

try {
    $run = Invoke-SqliteQuery -DataSource $Database -Query "SELECT * FROM runs WHERE run_id=@id" -SqlParameters @{ id = $RunId }
    if (-not $run) { throw "run $RunId not found" }

    # per-run env — child process only; @secret: tokens resolved here, never stored
    $envMap = Resolve-RunEnv -EnvJson $run.env_json -SecretsFile $cfg.paths.secretsFile
    foreach ($k in $envMap.Keys) { Set-Item "env:$k" $envMap[$k] }

    New-Item -ItemType Directory -Force $run.workspace | Out-Null
    Set-Location $run.workspace

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $raw = Invoke-Expression $run.command 2>&1 | Out-String
    $sw.Stop()
    $exit = $LASTEXITCODE

    if ($TimingOnly) {
        Write-Output ("TIMING {0} {1}" -f $RunId, $sw.ElapsedMilliseconds)
        exit 0
    }

    $rawPath = Join-Path $run.workspace 'raw-output.txt'
    Set-Content -Path $rawPath -Value $raw -Encoding utf8

    $parsed = Read-RunResult -Run $run -Raw $raw
    if (-not $parsed) { $parsed = @{} }

    # Quota/rate-limit refusal: distinct error class (requeueable, never graded as a failure).
    # Emits REFUSAL so the dispatcher can back off instead of churning the queue.
    if ($parsed['refusal']) {
        Set-RunError -Database $Database -RunId $RunId -Reason ("QUOTA-REFUSAL: " + $parsed.refusal)
        Write-Output ("REFUSAL {0} {1}" -f $RunId, $parsed.refusal)
        exit 0
    }
    if (-not $parsed['answer']) {
        Set-RunError -Database $Database -RunId $RunId -Reason "no answer parsed (raw at $rawPath)"
        Write-Output ("ERROR {0} no answer parsed" -f $RunId)
        exit 0
    }

    # Cost: harness-reported when present (claude); otherwise estimated from config pricing
    # rates ([input, cached, output] USD/Mtok). Local lane costs $0. No rates -> stays NULL.
    if ($null -eq $parsed.cost_usd -or $parsed.cost_usd -is [System.DBNull]) {
        if ($run.lane -eq 'local') { $parsed.cost_usd = 0.0 }
        else {
            $key  = $run.model -replace '^(anthropic|openai|ollama)/', ''
            $prop = $cfg.pricing.PSObject.Properties[$key]
            if ($prop -and $prop.Value) {
                $r = $prop.Value
                $tin  = if ($parsed.tokens_in) { [double]$parsed.tokens_in } else { 0 }
                $cin  = if ($parsed.tokens_cache_read) { [double]$parsed.tokens_cache_read } else { 0 }
                $tout = if ($parsed.tokens_out) { [double]$parsed.tokens_out } else { 0 }
                $parsed.cost_usd = [math]::Round((([math]::Max(0, $tin - $cin) * $r[0]) + ($cin * $r[1]) + ($tout * $r[2])) / 1e6, 6)
            }
        }
    }

    # deterministic grade against the expected spec (task looked up across all suites)
    $task = $null
    foreach ($sf in $cfg.suites) {
        $file = if ($sf -is [string]) { $sf } else { $sf.file }
        $s = Get-Content (Join-Path $PSScriptRoot $file) -Raw | ConvertFrom-Json
        $task = $s.tasks | Where-Object { $_.id -eq $run.task_id }
        if ($task) { break }
    }
    $grade = 'ungraded'; $gradedBy = $null
    if ($task -and $parsed.answer) {
        $grade = if (Test-ExpectedSpec -Expected $task.expected -Answer $parsed.answer) { 'pass' } else { 'fail' }
        $gradedBy = 'expected-spec'
    }

    Complete-Run -Database $Database -RunId $RunId -WallMs $sw.ElapsedMilliseconds -ExitCode $exit `
                 -Parsed $parsed -Grade $grade -GradedBy $gradedBy -OutputPath $rawPath
    Write-Output ("DONE {0} {1} {2}ms" -f $RunId, $grade, $sw.ElapsedMilliseconds)
} catch {
    if (-not $TimingOnly) { Set-RunError -Database $Database -RunId $RunId -Reason $_.Exception.Message }
    Write-Output ("ERROR {0} {1}" -f $RunId, $_.Exception.Message)
}
exit 0
