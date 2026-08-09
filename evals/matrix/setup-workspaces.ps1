# setup-workspaces.ps1 — build the C:\evals workspace tree the matrix runs against.
# CONFIG-DRIVEN: plugins and skills derive from the suites listed in matrix.config.json.
# Idempotent: re-running refreshes copies from the repo checkout. Legacy flat dirs from the
# aws pilot (codex-home-skills, skills\aws-cli, skills\aws) are kept while queued rows
# still reference them.
#
# Creates:
#   C:\evals\plugins\<plugin>                  (claude --plugin-dir, per owning plugin)
#   C:\evals\skills\<plugin>\<skill>           (pi --skill; plugin-nested — 'overview' exists in several plugins)
#   C:\evals\codex-homes\<plugin>              (codex CODEX_HOME skill arm: auth+config+profiles+that plugin's skills)
#   C:\evals\codex-home-bare                   (codex no-skill arm)
#   C:\evals\claude-home                       (claude scratch config home, subscription OAuth)
#   C:\evals\work\                             (per-run workspaces, created by invoke-run)
#   C:\evals\secrets.json                      (template if absent)
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$EvalRoot = 'C:\evals'
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$cfg = Get-Content (Join-Path $PSScriptRoot 'matrix.config.json') -Raw | ConvertFrom-Json
$taskPairs = foreach ($sf in $cfg.suites) {
    $s = Get-Content (Join-Path $PSScriptRoot $sf) -Raw | ConvertFrom-Json
    foreach ($t in $s.tasks) { [pscustomobject]@{ plugin = $t.plugin; skill = $t.skill } }
}
$plugins = $taskPairs | ForEach-Object plugin | Sort-Object -Unique
Write-Host "repo: $RepoRoot"
Write-Host "eval root: $EvalRoot"
Write-Host "plugins in scope: $($plugins -join ', ')"

function Copy-Fresh ($src, $dst) {
    if (-not (Test-Path $src)) { throw "missing source $src" }
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force -Confirm:$false }
    New-Item -ItemType Directory -Force $dst | Out-Null
    Copy-Item "$src\*" $dst -Recurse -Force
}

# ---- plugins (claude skill arm) -------------------------------------------
foreach ($plugin in $plugins) {
    Copy-Fresh (Join-Path $RepoRoot "plugins\$plugin") (Join-Path $EvalRoot "plugins\$plugin")
    Write-Host "plugin  -> $EvalRoot\plugins\$plugin"
}

# ---- skills (pi skill arm; plugin-nested) ----------------------------------
foreach ($pair in ($taskPairs | Sort-Object plugin, skill -Unique)) {
    $src = Join-Path $RepoRoot "plugins\$($pair.plugin)\skills\$($pair.skill)"
    Copy-Fresh $src (Join-Path $EvalRoot "skills\$($pair.plugin)\$($pair.skill)")
}
Write-Host "skills  -> $EvalRoot\skills\<plugin>\<skill> ($((($taskPairs | Sort-Object plugin, skill -Unique)).Count) skills)"
# legacy flat aws copies (older queued rows reference these paths)
foreach ($legacy in @(@('cli-scripting','aws-cli'), @('cloud-platforms','aws'))) {
    $src = Join-Path $RepoRoot "plugins\$($legacy[0])\skills\$($legacy[1])"
    if (Test-Path $src) { Copy-Fresh $src (Join-Path $EvalRoot "skills\$($legacy[1])") }
}

# ---- codex homes (CODEX_HOME swap) ----------------------------------------
# Copy ONLY auth + config + the ollama profiles; never session logs/state DBs.
$codexSrc = Join-Path $env:USERPROFILE '.codex'
$keep = @('auth.json', 'config.toml', 'ollama-gemma.config.toml', 'ollama-glm.config.toml', 'ollama-qwen27b.config.toml')
$codexHomes = [System.Collections.Generic.List[string]]::new()
$codexHomes.Add((Join-Path $EvalRoot 'codex-home-bare'))
$codexHomes.Add((Join-Path $EvalRoot 'codex-home-skills'))   # legacy aws home
foreach ($plugin in $plugins) { $codexHomes.Add((Join-Path $EvalRoot "codex-homes\$plugin")) }
foreach ($dst in $codexHomes) {
    New-Item -ItemType Directory -Force $dst | Out-Null
    foreach ($f in $keep) {
        $p = Join-Path $codexSrc $f
        if (Test-Path $p) { Copy-Item $p $dst -Force } else { Write-Warning "codex home file missing: $f" }
    }
}
# per-plugin homes get ALL that plugin's skills under skills\<name>\
# NOTE for scale-out: codex caps always-loaded skill name+description text at ~8k chars per
# home; plugins with very large skill counts (database: 29) may exceed it — split or trim then.
foreach ($plugin in $plugins) {
    $skillsSrc = Join-Path $RepoRoot "plugins\$plugin\skills"
    $dstRoot = Join-Path $EvalRoot "codex-homes\$plugin\skills"
    if (Test-Path $dstRoot) { Remove-Item $dstRoot -Recurse -Force -Confirm:$false }
    New-Item -ItemType Directory -Force $dstRoot | Out-Null
    foreach ($sk in (Get-ChildItem $skillsSrc -Directory)) {
        Copy-Fresh $sk.FullName (Join-Path $dstRoot $sk.Name)
    }
    Write-Host "codex   -> $EvalRoot\codex-homes\$plugin (+ $((Get-ChildItem $skillsSrc -Directory).Count) skills)"
}
# legacy aws home keeps its two skills
foreach ($legacy in @(@('cli-scripting','aws-cli'), @('cloud-platforms','aws'))) {
    $src = Join-Path $RepoRoot "plugins\$($legacy[0])\skills\$($legacy[1])"
    Copy-Fresh $src (Join-Path $EvalRoot "codex-home-skills\skills\$($legacy[1])")
}

# Contamination scrub: strip domain-expert marketplace/plugin sections from EVERY codex home —
# the user's real config.toml has domain-expert plugins enabled, which would feed the skill
# under test into no-skill arms (and double-feed skill arms).
foreach ($dst in $codexHomes) {
    $tomlPath = Join-Path $dst 'config.toml'
    if (-not (Test-Path $tomlPath)) { continue }
    $out = [System.Collections.Generic.List[string]]::new()
    $skip = $false
    foreach ($line in (Get-Content $tomlPath)) {
        if ($line -match '^\s*\[') {
            $skip = $line -match '^\s*\[(marketplaces\.domain-expert|plugins\."[^"]*@domain-expert")'
        }
        if (-not $skip) { $out.Add($line) }
    }
    Set-Content $tomlPath -Value $out -Encoding utf8
    if (Select-String -Path $tomlPath -Pattern 'marketplaces\.domain-expert|@domain-expert' -Quiet) {
        throw "$dst config.toml still references the domain-expert marketplace/plugins after scrub — inspect manually."
    }
}
Write-Host "scrubbed domain-expert plugin config from $($codexHomes.Count) codex homes"

# ---- claude scratch config home (subscription OAuth, no API key) -----------
$claudeHome = Join-Path $EvalRoot 'claude-home'
New-Item -ItemType Directory -Force $claudeHome | Out-Null
$credSrc = Join-Path $env:USERPROFILE '.claude\.credentials.json'
if (Test-Path $credSrc) { Copy-Item $credSrc $claudeHome -Force }
else { Write-Warning "no $credSrc — claude cells may fail auth; run claude /login once, then re-run setup." }
if (-not (Test-Path (Join-Path $claudeHome 'settings.json'))) {
    '{}' | Set-Content (Join-Path $claudeHome 'settings.json') -Encoding utf8
}
Write-Host "claude  -> $claudeHome (scratch config home, subscription OAuth)"

# ---- work root + secrets template -----------------------------------------
New-Item -ItemType Directory -Force (Join-Path $EvalRoot 'work') | Out-Null
$secrets = Join-Path $EvalRoot 'secrets.json'
if (-not (Test-Path $secrets)) {
    '{ }' | Set-Content $secrets -Encoding utf8
    Write-Host "wrote empty secrets template $secrets (no secrets currently required — subscription auth everywhere)"
} else { Write-Host "secrets -> $secrets (exists, untouched)" }

Write-Host "`nworkspace ready. Reminder: every codex home holds a copy of auth.json."
