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
    [string[]]$OnlySuites,             # limit claims to specific suites (e.g. pilot-first local runs)
    [int]$MaxRuns = 0,                 # 0 = unlimited
    [switch]$DryRun,
    [switch]$ResetStale,
    [string]$DbPath = (Join-Path $PSScriptRoot 'evalq.sqlite')
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
# pwsh -File binds "a,b,c" as ONE string (no array conversion) — normalize either style
if ($OnlySuites) { $OnlySuites = @($OnlySuites | ForEach-Object { $_ -split ',' } | Where-Object { $_ }) }
function Write-Log { param([string]$Message) Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" }
Import-Module PSSQLite
Import-Module (Join-Path $PSScriptRoot 'MatrixRunner.psm1') -Force
$cfg = Get-Content (Join-Path $PSScriptRoot 'matrix.config.json') -Raw | ConvertFrom-Json
$timeoutMin = $cfg.timeoutMinutes
$invoker = Join-Path $PSScriptRoot 'invoke-run.ps1'
$launched = 0

if ($ResetStale) {
    $n = Reset-StaleRuns -Database $DbPath -OlderThanMinutes $timeoutMin
    Write-Log "reset $n stale running rows back to queued"
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
    $refusalStreak = @{}   # provider -> consecutive quota refusals; threshold halts that provider
    while ($true) {
        if (-not $script:stopLaunching) {
            foreach ($p in @($caps.Keys)) {
                $active = @($jobs.Values | Where-Object { $_.Provider -eq $p })
                for ($i = $active.Count; $i -lt $caps[$p]; $i++) {
                    if ($MaxRuns -gt 0 -and $script:launched -ge $MaxRuns) { $script:stopLaunching = $true; break }
                    $run = Request-NextRun -Database $DbPath -Lane cloud -Provider $p -Harness $OnlyHarness -Suites $OnlySuites
                    if (-not $run) { break }
                    $script:launched++
                    Write-Log "▶ $($run.run_id)"
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
                Write-Log "✔ $out"
                # Quota backoff: N consecutive refusals on one provider -> stop claiming for it.
                if ($out -match 'REFUSAL ') {
                    $refusalStreak[$e.Provider] = 1 + $(if ($refusalStreak.ContainsKey($e.Provider)) { $refusalStreak[$e.Provider] } else { 0 })
                    if ($refusalStreak[$e.Provider] -ge 8 -and $caps.ContainsKey($e.Provider)) {
                        $caps.Remove($e.Provider)
                        Write-Log "WARN: QUOTA EXHAUSTED for provider '$($e.Provider)' ($($refusalStreak[$e.Provider]) consecutive refusals) — halting its launches. Requeue refusals and re-dispatch after the quota window resets."
                    }
                } elseif ($out -match 'DONE ') { $refusalStreak[$e.Provider] = 0 }
                $jobs.Remove($id)
            } elseif (((Get-Date) - $e.Started).TotalMinutes -gt $timeoutMin) {
                Stop-Job $e.Job -ErrorAction SilentlyContinue; Remove-Job $e.Job -Force
                Set-RunError -Database $DbPath -RunId $id -Reason "timeout ${timeoutMin}m (dispatcher)"
                Write-Log "✖ $id timeout"
                $jobs.Remove($id)
            }
        }
        $depth = Get-QueueDepth -Database $DbPath -Lane cloud
        Write-Progress -Activity 'cloud sweep' -Status "$depth queued · $($jobs.Count) running · $script:launched launched"
        if ($jobs.Count -eq 0 -and $caps.Count -eq 0) { Write-Log 'WARN: all providers quota-halted — exiting cloud pool'; break }
        if ($jobs.Count -eq 0 -and ($depth -eq 0 -or $script:stopLaunching)) { break }
        Start-Sleep -Milliseconds 400
    }
    Write-Progress -Activity 'cloud sweep' -Completed
}

function Invoke-LocalSerial {
    # GPU exclusivity: exactly one local lane may run machine-wide. Two dispatchers'
    # local phases (or a concurrent timing pass) would fight for VRAM and wreck timings.
    $lockPath = 'C:\evals\local.lock'
    if (Test-Path $lockPath) {
        $owner = Get-Content $lockPath -ErrorAction SilentlyContinue
        if ($owner -and (Get-Process -Id $owner -ErrorAction SilentlyContinue)) {
            Write-Log "WARN: local lane already running under PID $owner — skipping local phase. Re-run dispatch -Lane local after it finishes."
            return
        }
        Remove-Item $lockPath -Force   # stale lock from a dead process
    }
    Set-Content $lockPath -Value $PID
    try {
    # Group by the UNDERLYING OLLAMA TAG, not the model string: pi names the same weights
    # 'ollama/gemma4:12b' while claude/codex use 'gemma4:12b'. One load serves all three
    # harnesses; warm-up precedes every timed run so cold loads never touch the clock.
    $suiteFilter = ""
    $sp = @{}
    if ($OnlySuites) {
        $ph = @(); for ($i = 0; $i -lt $OnlySuites.Count; $i++) { $ph += "@s$i"; $sp["s$i"] = $OnlySuites[$i] }
        $suiteFilter = " AND suite IN ($($ph -join ','))"
    }
    $models = Invoke-SqliteQuery -DataSource $DbPath -Query "
        SELECT DISTINCT model FROM runs WHERE status='queued' AND lane='local'$suiteFilter ORDER BY model" -SqlParameters $sp
    $byTag = @($models | ForEach-Object model) | Group-Object { $_ -replace '^ollama/', '' }
    foreach ($g in $byTag) {
        if ($MaxRuns -gt 0 -and $script:launched -ge $MaxRuns) { break }
        $tag = $g.Name
        Write-Log "── local weights $tag ($(@($g.Group).Count) harness model ids) : warm-up"
        try { & ollama run $tag --keepalive 45m 'ok' 2>&1 | Out-Null } catch { Write-Log "WARN: warm-up failed for $tag : $_" }
        foreach ($m in $g.Group) {
            while ($run = Request-NextRun -Database $DbPath -Lane local -Model $m -Suites $OnlySuites) {
                $script:launched++
                Write-Log "▶ $($run.run_id)"
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $out = & pwsh -NoProfile -File $invoker -Database $DbPath -RunId $run.run_id 2>&1 | Out-String
                $sw.Stop()
                Write-Log "✔ $($out.Trim())  [outer $([int]$sw.ElapsedMilliseconds)ms]"
                if ($MaxRuns -gt 0 -and $script:launched -ge $MaxRuns) { break }
            }
            if ($MaxRuns -gt 0 -and $script:launched -ge $MaxRuns) { break }
        }
        try { & ollama stop $tag 2>&1 | Out-Null } catch {}
    }
    } finally { Remove-Item $lockPath -Force -ErrorAction SilentlyContinue }
}

$script:stopLaunching = $false
$script:launched = 0
if ($Lane -in 'cloud', 'all') { Invoke-CloudPool }
if ($Lane -in 'local', 'all') { Invoke-LocalSerial }

Invoke-SqliteQuery -DataSource $DbPath -Query "SELECT status, COUNT(*) n FROM runs GROUP BY status" |
    Format-Table -AutoSize | Out-String | Write-Host
Write-Log "dispatch finished: $script:launched runs launched this session. Re-run build-report.ps1 to refresh the report."

