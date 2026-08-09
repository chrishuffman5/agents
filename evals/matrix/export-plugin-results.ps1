# export-plugin-results.ps1 — publish matrix results into each plugin's evals/ folder
# and feed the docs/ dashboard.
#
# Per skill under test it writes, into the OWNING plugin:
#   plugins/<plugin>/evals/matrix/<skill>-results.json   raw aggregates + the exact prompts used
#   plugins/<plugin>/evals/matrix/<skill>-report.md      readable report: skill vs no-skill,
#                                                        by harness, by model, price-to-performance
# And for the public dashboard:
#   docs/matrix-results.js                               window.MATRIX_SKILLS payload
#
# Cost policy: claude's CLI reports cost_usd natively (used as-is). codex/pi costs are
# ESTIMATED from matrix.config.json "pricing" rates ([in, cached, out] USD/Mtok); models
# with null rates get cost "rates not configured" — never a guessed number.
[CmdletBinding()]
param(
    [string]$DbPath   = (Join-Path $PSScriptRoot 'evalq.sqlite'),
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
Import-Module PSSQLite
$cfg = Get-Content (Join-Path $PSScriptRoot 'matrix.config.json') -Raw | ConvertFrom-Json
$suiteNames = @(); $suiteTasks = [System.Collections.Generic.List[object]]::new()
foreach ($sf in $cfg.suites) {
    $file = if ($sf -is [string]) { $sf } else { $sf.file }
    $s = Get-Content (Join-Path $PSScriptRoot $file) -Raw | ConvertFrom-Json
    $suiteNames += $s.suite
    foreach ($t in $s.tasks) { $suiteTasks.Add($t) }
}
$suite = [pscustomobject]@{ suite = ($suiteNames -join ' + '); tasks = $suiteTasks }
$now = (Get-Date).ToString('o')

$all  = Invoke-SqliteQuery -DataSource $DbPath -Query "
    SELECT skill, harness, provider, model, lane, effort_norm effort, skill_mode mode, status, grade,
           wall_ms, tokens_in, tokens_out, tokens_cache_read, cost_usd
    FROM runs"
$done = @($all | Where-Object { $_.status -eq 'done' })
$planned = @($all).Count

function Get-RunCost {
    param($Row)
    if ($Row.cost_usd -is [double] -or $Row.cost_usd -is [decimal]) { return [double]$Row.cost_usd }
    $key = $Row.model -replace '^(anthropic|openai|ollama)/', ''
    $prop = $cfg.pricing.PSObject.Properties[$key]
    $rates = if ($prop) { $prop.Value } else { $null }
    if (-not $rates) { if ($Row.lane -eq 'local') { return 0.0 } else { return $null } }
    if ($Row.lane -eq 'local') { return 0.0 }
    $cin = if ($Row.tokens_cache_read) { $Row.tokens_cache_read } else { 0 }
    $tin = if ($Row.tokens_in) { $Row.tokens_in } else { 0 }
    $tout = if ($Row.tokens_out) { $Row.tokens_out } else { 0 }
    return (([math]::Max(0, $tin - $cin) * $rates[0]) + ($cin * $rates[1]) + ($tout * $rates[2])) / 1e6
}

function Get-Agg {
    param($Rows)
    $Rows = @($Rows | Where-Object { $_ })   # @($null).Count is 1 — strip nulls first
    $n = $Rows.Count
    if (-not $n) { return $null }
    $pass = @($Rows | Where-Object grade -eq 'pass').Count
    $costs = @($Rows | ForEach-Object { Get-RunCost $_ } | Where-Object { $_ -ne $null })
    $costKnown = $costs.Count -eq $n
    $totalCost = if ($costKnown) { [math]::Round(($costs | Measure-Object -Sum).Sum, 4) } else { $null }
    $wallAgg = $Rows | Where-Object { $_.wall_ms -isnot [System.DBNull] -and $null -ne $_.wall_ms } | Measure-Object wall_ms -Average
    $tokAgg  = $Rows | Where-Object { $_.tokens_out -isnot [System.DBNull] -and $_.tokens_out } | Measure-Object tokens_out -Average
    [ordered]@{
        runs = $n; pass = $pass
        accuracy = [math]::Round(100.0 * $pass / $n, 1)
        meanWallMs = if ($wallAgg) { [int]$wallAgg.Average } else { $null }
        meanTokensOut = if ($tokAgg) { [int]$tokAgg.Average } else { $null }
        totalCostUsd = $totalCost
        costPerCorrect = if ($costKnown -and $pass -gt 0) { [math]::Round($totalCost / $pass, 4) } else { $null }
    }
}

$fmtC = { param($v) if ($v -eq $null) { 'rates n/c' } else { '$' + $v } }
$docsPayload = [ordered]@{ generated = $now; suite = $suite.suite; planned = $planned; done = $done.Count; skills = [ordered]@{} }

foreach ($skillName in ($suite.tasks | ForEach-Object skill | Sort-Object -Unique)) {
    $tasks  = @($suite.tasks | Where-Object skill -eq $skillName)
    $plugin = $tasks[0].plugin
    $rows   = @($done | Where-Object skill -eq $skillName)
    $plannedSkill = @($all | Where-Object skill -eq $skillName).Count
    $outDir = Join-Path $RepoRoot "plugins\$plugin\evals\matrix"
    New-Item -ItemType Directory -Force $outDir | Out-Null

    # dimension rollups
    $overall  = [ordered]@{}; foreach ($m in 'skill','no-skill') { $overall[$m] = Get-Agg ($rows | Where-Object mode -eq $m) }
    $byHarness = @(); $byModel = @(); $byCell = @()
    foreach ($g in ($rows | Group-Object harness)) {
        $byHarness += [ordered]@{ harness = $g.Name
            skill = Get-Agg ($g.Group | Where-Object mode -eq 'skill'); noskill = Get-Agg ($g.Group | Where-Object mode -eq 'no-skill') } }
    foreach ($g in ($rows | Group-Object model)) {
        $byModel += [ordered]@{ model = $g.Name; lane = $g.Group[0].lane
            skill = Get-Agg ($g.Group | Where-Object mode -eq 'skill'); noskill = Get-Agg ($g.Group | Where-Object mode -eq 'no-skill') } }
    foreach ($g in ($rows | Group-Object harness, model, effort, mode)) {
        $c = $g.Group[0]
        $byCell += [ordered]@{ harness = $c.harness; model = $c.model; effort = $c.effort; mode = $c.mode; agg = Get-Agg $g.Group } }

    # ---- results.json ----
    $payload = [ordered]@{
        skill = $skillName; plugin = $plugin; generated = $now
        partial = ($rows.Count -lt $plannedSkill)
        runsDone = $rows.Count; runsPlanned = $plannedSkill
        prompts = @($tasks | ForEach-Object { [ordered]@{
            id = $_.id; knowledge = $_.knowledge; prompt = $_.prompt
            expected = $_.expected; source = $_.notes } })
        overall = $overall; byHarness = $byHarness; byModel = $byModel; byCell = $byCell
        costPolicy = 'claude: CLI-reported cost_usd. codex/pi: estimated from matrix.config.json pricing rates; null rates -> cost omitted, never guessed. local lane: $0.'
    }
    $payload | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $outDir "$skillName-results.json") -Encoding utf8
    $docsPayload.skills[$skillName] = $payload

    # ---- report.md ----
    $L = [System.Collections.Generic.List[string]]::new()
    $L.Add("# $skillName — cross-harness eval report")
    $L.Add("")
    $L.Add("Generated: $now · plugin: ``$plugin`` · runs: **$($rows.Count) / $plannedSkill**" +
           $(if ($rows.Count -lt $plannedSkill) { ' · **PARTIAL — sweep incomplete, numbers will change**' } else { '' }))
    $L.Add("")
    $L.Add("## The exact prompts used")
    $L.Add("")
    $L.Add("One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.")
    $L.Add("")
    $L.Add("| id | knowledge | prompt | expected |")
    $L.Add("|---|---|---|---|")
    foreach ($t in $tasks) {
        $exp = "$($t.expected.type): ``$(@($t.expected.value) -join '``, ``')``"
        $L.Add("| $($t.id) | $($t.knowledge) | $($t.prompt) | $exp |")
    }
    $L.Add("")
    $L.Add("## Skill vs no-skill — overall")
    $L.Add("")
    $L.Add("| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |")
    $L.Add("|---|---|---|---|---|---|---|")
    foreach ($m in 'skill','no-skill') {
        $a = $overall[$m]
        if ($a) { $L.Add("| $m | $($a.runs) | **$($a.accuracy)%** | $([math]::Round($a.meanWallMs/1000.0,1))s | $($a.meanTokensOut) | $(& $fmtC $a.totalCostUsd) | $(& $fmtC $a.costPerCorrect) |") }
        else    { $L.Add("| $m | 0 | — | — | — | — | — |") }
    }
    $L.Add("")
    $L.Add("## By harness")
    $L.Add("")
    $L.Add("| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |")
    $L.Add("|---|---|---|---|---|---|")
    foreach ($h in $byHarness) {
        $s = $h.skill; $n = $h.noskill
        $L.Add("| $($h.harness) | $(if($s){"$($s.accuracy)%"}else{'—'}) | $(if($n){"$($n.accuracy)%"}else{'—'}) | " +
               "$(if($s -and $n){"+$([math]::Round($s.accuracy-$n.accuracy,1))pp"}else{'—'}) | " +
               "$(if($s){"$([math]::Round($s.meanWallMs/1000.0,1))s"}else{'—'}) | $(if($n){"$([math]::Round($n.meanWallMs/1000.0,1))s"}else{'—'}) |")
    }
    $L.Add("")
    $L.Add("## By model — price to performance")
    $L.Add("")
    $L.Add("Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.")
    $L.Add("")
    $L.Add("| model | mode | accuracy | mean wall | cost/correct |")
    $L.Add("|---|---|---|---|---|")
    foreach ($mo in ($byModel | Sort-Object { $_.model })) {
        foreach ($m in 'skill','noskill') {
            $a = $mo[$m]
            if ($a) { $L.Add("| $($mo.model) | $(if($m -eq 'skill'){'skill'}else{'no-skill'}) | $($a.accuracy)% | $([math]::Round($a.meanWallMs/1000.0,1))s | $(& $fmtC $a.costPerCorrect) |") }
        }
    }
    $L.Add("")
    $L.Add("_Full per-cell aggregates (harness × model × effort × mode) in ``$skillName-results.json``. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._")
    ($L -join "`n") | Set-Content (Join-Path $outDir "$skillName-report.md") -Encoding utf8
    Write-Host "exported $skillName -> $outDir ($($rows.Count)/$plannedSkill runs)"
}

# ---- docs dashboard feed ----
$docsJs = Join-Path $RepoRoot 'docs\matrix-results.js'
"window.MATRIX_SKILLS = $($docsPayload | ConvertTo-Json -Depth 9 -Compress);" | Set-Content $docsJs -Encoding utf8
Write-Host "exported docs feed -> $docsJs"
