# dispatch.ps1 — drain the eval queue. Cloud lane: per-provider ThreadJob slot pool
# (threads only schedule; every run executes in a child pwsh via invoke-run.ps1, which is
# where env vars are allowed). Local lane: strictly serial, grouped by model, VRAM warm-up.
#
#   ./dispatch.ps1 -DryRun                      # show what would run, touch nothing
#   ./dispatch.ps1 -Lane cloud -MaxRuns 2       # smoke test: two cloud runs, then stop
#   ./dispatch.ps1 -Lane all                    # the full sweep (cloud pool, then local serial)
#   ./dispatch.ps1 -ResetStale                  # crash recovery: running -> queued, then exit
[CmdletBinding()]
param(
    [ValidateSet('cloud', 'local', 'all')][string]$Lane = 'all',
    [string]$OnlyProvider,             # limit the cloud pool to one provider (smoke tests)
    [string]$OnlyHarness,              # limit claims to one harness (smoke tests)
    [int]$MaxRuns = 0,                 # 0 = unlimited
    [switch]$DryRun,
    [switch]$ResetStale,
    [string]$DbPath = (Join-Path $PSScriptRoot 'evalq.sqlite')
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
Import-Module PSSQLite
Import-Module (Join-Path $PSScriptRoot 'MatrixRunner.psm1') -Force
$cfg = Get-Content (Join-Path $PSScriptRoot 'matrix.config.json') -Raw | ConvertFrom-Json
$timeoutMin = $cfg.timeoutMinutes
$invoker = Join-Path $PSScriptRoot 'invoke-run.ps1'
$launched = 0

if ($ResetStale) {
    $n = Reset-StaleRuns -Database $DbPath -OlderThanMinutes $timeoutMin
    Write-Host "reset $n stale running rows back to queued"
    return
}

if ($DryRun) {
    Invoke-SqliteQuery -DataSource $DbPath -Query "
        SELECT lane, provider, harness, COUNT(*) queued FROM runs
        WHERE status='queued' GROUP BY lane, provider, harness ORDER BY lane, provider" |
        Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "dry run: nothing claimed. Throttles: $((($cfg.throttle.PSObject.Properties | ForEach-Object { $_.Name + '=' + $_.Value }) -join ', '))"
    return
}

# secrets sanity before spending anything: every distinct @secret: token must resolve —
# but only for the lane(s) actually being dispatched
$laneFilter = if ($Lane -eq 'all') { "" } else { " AND lane = '$Lane'" }
$tokens = Invoke-SqliteQuery -DataSource $DbPath -Query "
    SELECT DISTINCT env_json FROM runs WHERE status='queued' AND env_json LIKE '%@secret:%'$laneFilter"
foreach ($t in $tokens) { Resolve-RunEnv -EnvJson $t.env_json -SecretsFile $cfg.paths.secretsFile | Out-Null }

function Invoke-CloudPool {
    $caps = @{}
    $cfg.throttle.PSObject.Properties | ForEach-Object { $caps[$_.Name] = [int]$_.Value }
    if ($OnlyProvider) { foreach ($k in @($caps.Keys)) { if ($k -ne $OnlyProvider) { $caps.Remove($k) } } }
    $jobs = @{}
    while ($true) {
        if (-not $script:stopLaunching) {
            foreach ($p in @($caps.Keys)) {
                $active = @($jobs.Values | Where-Object { $_.Provider -eq $p })
                for ($i = $active.Count; $i -lt $caps[$p]; $i++) {
                    if ($MaxRuns -gt 0 -and $script:launched -ge $MaxRuns) { $script:stopLaunching = $true; break }
                    $run = Claim-NextRun -Database $DbPath -Lane cloud -Provider $p -Harness $OnlyHarness
                    if (-not $run) { break }
                    $script:launched++
                    Write-Host "▶ $($run.run_id)"
                    $jobs[$run.run_id] = @{ Provider = $p; Started = Get-Date
                        Job = Start-ThreadJob -ArgumentList $invoker, $DbPath, $run.run_id {
                            param($inv, $db, $id)
                            & pwsh -NoProfile -File $inv -Database $db -RunId $id 2>&1 | Out-String
                        } }
                }
            }
        }
        foreach ($id in @($jobs.Keys)) {
            $e = $jobs[$id]
            if ($e.Job.State -in 'Completed', 'Failed') {
                $out = (Receive-Job $e.Job -ErrorAction SilentlyContinue | Out-String).Trim()
                Remove-Job $e.Job -Force
                Write-Host "✔ $out"
                $jobs.Remove($id)
            } elseif (((Get-Date) - $e.Started).TotalMinutes -gt $timeoutMin) {
                Stop-Job $e.Job -ErrorAction SilentlyContinue; Remove-Job $e.Job -Force
                Fail-Run -Database $DbPath -RunId $id -Reason "timeout ${timeoutMin}m (dispatcher)"
                Write-Host "✖ $id timeout"
                $jobs.Remove($id)
            }
        }
        $depth = Get-QueueDepth -Database $DbPath -Lane cloud
        Write-Progress -Activity 'cloud sweep' -Status "$depth queued · $($jobs.Count) running · $script:launched launched"
        if ($jobs.Count -eq 0 -and ($depth -eq 0 -or $script:stopLaunching)) { break }
        Start-Sleep -Milliseconds 400
    }
    Write-Progress -Activity 'cloud sweep' -Completed
}

function Invoke-LocalSerial {
    $models = Invoke-SqliteQuery -DataSource $DbPath -Query "
        SELECT DISTINCT model FROM runs WHERE status='queued' AND lane='local' ORDER BY model"
    foreach ($m in @($models | ForEach-Object model)) {
        if ($MaxRuns -gt 0 -and $script:launched -ge $MaxRuns) { break }
        $tag = $m -replace '^ollama/', ''
        Write-Host "── local model $tag : warm-up"
        try { & ollama run $tag --keepalive 45m 'ok' 2>&1 | Out-Null } catch { Write-Warning "warm-up failed for $tag : $_" }
        while ($run = Claim-NextRun -Database $DbPath -Lane local -Model $m) {
            $script:launched++
            Write-Host "▶ $($run.run_id)"
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $out = & pwsh -NoProfile -File $invoker -Database $DbPath -RunId $run.run_id 2>&1 | Out-String
            $sw.Stop()
            Write-Host "✔ $($out.Trim())  [outer $([int]$sw.ElapsedMilliseconds)ms]"
            if ($MaxRuns -gt 0 -and $script:launched -ge $MaxRuns) { break }
        }
        try { & ollama stop $tag 2>&1 | Out-Null } catch {}
    }
}

$script:stopLaunching = $false
$script:launched = 0
if ($Lane -in 'cloud', 'all') { Invoke-CloudPool }
if ($Lane -in 'local', 'all') { Invoke-LocalSerial }

Invoke-SqliteQuery -DataSource $DbPath -Query "SELECT status, COUNT(*) n FROM runs GROUP BY status" |
    Format-Table -AutoSize | Out-String | Write-Host
Write-Host "dispatch finished: $script:launched runs launched this session. Re-run build-report.ps1 to refresh the report."
