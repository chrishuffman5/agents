# MatrixRunner.psm1 — shared functions for the cross-harness eval matrix.
# Flags verified 2026-08-08 on HUFFTECH01 (claude 2.1.225, codex-cli 0.144.1, pi) — see
# evals/design/cross-harness-matrix.html and train-gemma4/CLI.md.

Set-StrictMode -Version 3.0

function New-CellCommand {
    <#
      Renders the exact CLI string for one run. The prompt must not contain double
      quotes (the seeder validates this) so no escaping layer is needed.
      Footgun handled here: -p means --print for claude/pi but --profile for codex.
    #>
    param([Parameter(Mandatory)][hashtable]$Cell)
    $q = '"' + $Cell.prompt + '"'
    switch ($Cell.harness) {
        'claude' {
            # No --bare: it refuses subscription OAuth (API-key only). Isolation comes from a
            # scratch CLAUDE_CONFIG_DIR (env_json) — empty home: no plugins/CLAUDE.md/memory/hooks —
            # plus an empty per-run workspace (no project scope to discover).
            $f = @('-p', '--no-session-persistence', '--output-format', 'json',
                   '--model', $Cell.model, '--effort', $Cell.effortLiteral)
            $f += if ($Cell.skillMode -eq 'skill') {
                      # --plugin-dir is repeatable; load the plugin that owns the task's skill
                      $Cell.pluginDirs | ForEach-Object { @('--plugin-dir', $_) }
                  } else { '--disable-slash-commands' }
            "claude $($f -join ' ') $q"
        }
        'codex' {
            $f = @('e', '--ephemeral', '--skip-git-repo-check', '-C', $Cell.workspace,
                   '-s', $Cell.sandbox, '--json', '-o', (Join-Path $Cell.workspace 'last_message.txt'))
            $f += if ($Cell.lane -eq 'local') { @('--profile', $Cell.codexProfile) }
                  else                        { @('-m', $Cell.model) }
            $f += @('-c', "model_reasoning_effort=`"$($Cell.effortLiteral)`"")  # composes over profiles
            "codex $($f -join ' ') $q"
        }
        'pi' {
            # model ids in config are already provider-qualified (anthropic/…, openai/…, ollama/…)
            $f = @('-p', '--no-session', '--no-context-files', '--mode', 'json',
                   '--model', $Cell.model, '--thinking', $Cell.effortLiteral)
            $f += if ($Cell.skillMode -eq 'skill') { @('--skill', $Cell.skillPath) }
                  else                             { '--no-skills' }
            "pi $($f -join ' ') $q"
        }
        default { throw "Unknown harness '$($Cell.harness)'" }
    }
}

function Initialize-EvalDb {
    param([Parameter(Mandatory)][string]$Database, [Parameter(Mandatory)][string]$SchemaPath)
    Invoke-SqliteQuery -DataSource $Database -Query (Get-Content $SchemaPath -Raw) | Out-Null
}

function Get-QueueDepth {
    param([Parameter(Mandatory)][string]$Database, [string]$Lane)
    $q = "SELECT COUNT(*) AS n FROM runs WHERE status = 'queued'"
    if ($Lane) { $q += " AND lane = @lane" }
    (Invoke-SqliteQuery -DataSource $Database -Query $q -SqlParameters @{ lane = $Lane }).n
}

function Claim-NextRun {
    <#
      Atomically claims the next queued run (status -> running). Uses
      UPDATE-then-check-changes() because the bundled SQLite may predate RETURNING.
    #>
    param([Parameter(Mandatory)][string]$Database, [string]$Lane, [string]$Provider, [string]$Model,
          [string]$Harness, [string[]]$Suites, [string]$Worker = "$env:COMPUTERNAME/$PID")
    for ($try = 0; $try -lt 5; $try++) {
        $where = "status = 'queued'"
        $p = @{ worker = $Worker; now = (Get-Date).ToString('o') }
        if ($Lane)     { $where += " AND lane = @lane";         $p.lane = $Lane }
        if ($Provider) { $where += " AND provider = @provider"; $p.provider = $Provider }
        if ($Model)    { $where += " AND model = @model";       $p.model = $Model }
        if ($Harness)  { $where += " AND harness = @harness";   $p.harness = $Harness }
        if ($Suites) {
            $ph = @(); for ($i = 0; $i -lt $Suites.Count; $i++) { $ph += "@s$i"; $p["s$i"] = $Suites[$i] }
            $where += " AND suite IN ($($ph -join ','))"
        }
        $cand = Invoke-SqliteQuery -DataSource $Database -Query "SELECT run_id FROM runs WHERE $where LIMIT 1" -SqlParameters $p
        if (-not $cand) { return $null }
        $p.id = $cand.run_id
        Invoke-SqliteQuery -DataSource $Database -Query "
            UPDATE runs SET status='running', claimed_by=@worker, started_at=@now
            WHERE run_id=@id AND status='queued'" -SqlParameters $p | Out-Null
        $got = Invoke-SqliteQuery -DataSource $Database -Query "
            SELECT * FROM runs WHERE run_id=@id AND status='running' AND claimed_by=@worker" -SqlParameters $p
        if ($got) { return $got }        # lost the race -> loop and pick another
    }
    return $null
}

function Complete-Run {
    param([Parameter(Mandatory)][string]$Database, [Parameter(Mandatory)][string]$RunId,
          [int]$WallMs, [int]$ExitCode = 0, [hashtable]$Parsed,
          [string]$Grade, [string]$GradedBy, [string]$OutputPath)
    $p = @{ id = $RunId; wall = $WallMs; exit = $ExitCode; now = (Get-Date).ToString('o')
            ti = $Parsed.tokens_in; to = $Parsed.tokens_out; tc = $Parsed.tokens_cache_read
            cost = $Parsed.cost_usd; ans = $Parsed.answer
            grade = $Grade; gradedby = $GradedBy; outpath = $OutputPath }
    Invoke-SqliteQuery -DataSource $Database -Query "
        UPDATE runs SET status='done', finished_at=@now, wall_ms=@wall, exit_code=@exit,
               tokens_in=@ti, tokens_out=@to, tokens_cache_read=@tc, cost_usd=@cost,
               answer=@ans, grade=@grade, graded_by=@gradedby, output_path=@outpath
        WHERE run_id=@id" -SqlParameters $p | Out-Null
}

function Reset-StaleRuns {
    # Crash recovery: runs claimed but never finished go back to the queue.
    param([Parameter(Mandatory)][string]$Database, [int]$OlderThanMinutes = 10)
    $cutoff = (Get-Date).AddMinutes(-$OlderThanMinutes).ToString('o')
    Invoke-SqliteQuery -DataSource $Database -Query "
        UPDATE runs SET status='queued', claimed_by=NULL, started_at=NULL
        WHERE status='running' AND started_at < @cutoff" -SqlParameters @{ cutoff = $cutoff } | Out-Null
    (Invoke-SqliteQuery -DataSource $Database -Query "SELECT changes() n").n
}

function Resolve-RunEnv {
    # env_json -> hashtable; @secret:name tokens resolved from the secrets file at dispatch time.
    param([Parameter(Mandatory)][string]$EnvJson, [string]$SecretsFile)
    $out = @{}
    $map = $EnvJson | ConvertFrom-Json
    $secrets = if ($SecretsFile -and (Test-Path $SecretsFile)) { Get-Content $SecretsFile -Raw | ConvertFrom-Json } else { $null }
    foreach ($p in $map.PSObject.Properties) {
        if ($p.Value -like '@secret:*') {
            $name = $p.Value.Substring(8)
            $val = if ($secrets) { $secrets.$name } else { $null }
            if (-not $val) { throw "Secret '$name' missing or empty in $SecretsFile" }
            $out[$p.Name] = $val
        } else { $out[$p.Name] = $p.Value }
    }
    $out
}

function Fail-Run {
    param([Parameter(Mandatory)][string]$Database, [Parameter(Mandatory)][string]$RunId, [string]$Reason)
    Invoke-SqliteQuery -DataSource $Database -Query "
        UPDATE runs SET status='error', finished_at=@now, answer=@r WHERE run_id=@id" `
        -SqlParameters @{ id = $RunId; r = $Reason; now = (Get-Date).ToString('o') } | Out-Null
}

function Read-RunResult {
    <#
      Per-harness field mapping (verified schemas):
        claude --output-format json  -> one JSON object (result, usage.*, total_cost_usd, duration_ms)
        codex  --json                -> JSONL events; tokens from last turn.completed; answer from -o file
        pi     --mode json           -> typed events; answer from last message_end (message_update is delta-only)
      Codex exit codes are undocumented — grade from the answer artifact, never $LASTEXITCODE.
    #>
    param([Parameter(Mandatory)]$Run, [string]$Raw)
    switch ($Run.harness) {
        'claude' {
            $j = $Raw | ConvertFrom-Json
            @{ answer = $j.result
               tokens_in = $j.usage.input_tokens; tokens_out = $j.usage.output_tokens
               tokens_cache_read = $j.usage.cache_read_input_tokens
               cost_usd = $j.total_cost_usd }
        }
        'codex' {
            $turn = $Raw -split "`n" | Where-Object { $_ } | ForEach-Object {
                        try { $_ | ConvertFrom-Json } catch {} } |
                    Where-Object { $_.type -eq 'turn.completed' } | Select-Object -Last 1
            $ansFile = Join-Path $Run.workspace 'last_message.txt'
            @{ answer = if (Test-Path $ansFile) { Get-Content $ansFile -Raw } else { $null }
               tokens_in = $turn.usage.input_tokens; tokens_out = $turn.usage.output_tokens
               tokens_cache_read = $turn.usage.cached_input_tokens; cost_usd = $null }
        }
        'pi' {
            $end = $Raw -split "`n" | Where-Object { $_ } | ForEach-Object {
                       try { $_ | ConvertFrom-Json } catch {} } |
                   Where-Object { $_.type -eq 'message_end' } | Select-Object -Last 1
            $text = if ($end.message.content -is [array]) {
                        ($end.message.content | Where-Object { $_.type -eq 'text' } | ForEach-Object text) -join "`n"
                    } else { [string]$end.message.content }
            @{ answer = $text; tokens_in = $null; tokens_out = $null; tokens_cache_read = $null; cost_usd = $null }
        }
    }
}

function Test-ExpectedSpec {
    <#
      Deterministic grader — same semantics as evals/run-evals.ps1 expected specs.
      contains_all: every value present as substring (case-insensitive).
      regex: pattern matches (pattern supplies its own (?i) when needed).
    #>
    param([Parameter(Mandatory)]$Expected, [string]$Answer)
    if (-not $Answer) { return $false }
    switch ($Expected.type) {
        'contains_all' {
            foreach ($v in $Expected.value) {
                if ($Answer.IndexOf([string]$v, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
            }
            return $true
        }
        'regex' { return [bool]([regex]::Match($Answer, $Expected.value)).Success }
        default { throw "Unknown expected type '$($Expected.type)'" }
    }
}

Export-ModuleMember -Function New-CellCommand, Initialize-EvalDb, Get-QueueDepth, Claim-NextRun,
    Complete-Run, Fail-Run, Read-RunResult, Test-ExpectedSpec, Reset-StaleRuns, Resolve-RunEnv
