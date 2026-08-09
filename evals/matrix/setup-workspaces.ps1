# setup-workspaces.ps1 — build the C:\evals workspace tree the matrix runs against.
# Idempotent: re-running refreshes skill/plugin copies from the repo checkout.
#
# Creates:
#   C:\evals\plugins\cli-scripting, \cloud-platforms   (claude --plugin-dir, one per task plugin)
#   C:\evals\skills\aws-cli, \aws                      (pi --skill)
#   C:\evals\codex-home-skills, \codex-home-bare       (codex CODEX_HOME swap; identical except skills\)
#   C:\evals\work\                                     (per-run workspaces, created by invoke-run)
#   C:\evals\secrets.json                              (template if absent — FILL IN, never commit)
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$EvalRoot = 'C:\evals'
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Write-Host "repo: $RepoRoot"
Write-Host "eval root: $EvalRoot"

# ---- plugins (claude skill arm) -------------------------------------------
foreach ($plugin in 'cli-scripting', 'cloud-platforms') {
    $src = Join-Path $RepoRoot "plugins\$plugin"
    $dst = Join-Path $EvalRoot "plugins\$plugin"
    if (-not (Test-Path $src)) { throw "missing plugin source $src" }
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force -Confirm:$false }
    New-Item -ItemType Directory -Force $dst | Out-Null
    Copy-Item "$src\*" $dst -Recurse -Force
    Write-Host "plugin  -> $dst"
}

# ---- skills (pi skill arm) -------------------------------------------------
$skillMap = @{ 'aws-cli' = 'plugins\cli-scripting\skills\aws-cli'; 'aws' = 'plugins\cloud-platforms\skills\aws' }
foreach ($name in $skillMap.Keys) {
    $src = Join-Path $RepoRoot $skillMap[$name]
    $dst = Join-Path $EvalRoot "skills\$name"
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force -Confirm:$false }
    New-Item -ItemType Directory -Force $dst | Out-Null
    Copy-Item "$src\*" $dst -Recurse -Force
    Write-Host "skill   -> $dst"
}

# ---- codex homes (CODEX_HOME swap) ----------------------------------------
# Copy ONLY auth + config + the ollama profiles. The real ~/.codex carries session
# logs and state databases that must not leak into eval runs.
$codexSrc = Join-Path $env:USERPROFILE '.codex'
$keep = @('auth.json', 'config.toml', 'ollama-gemma.config.toml', 'ollama-glm.config.toml', 'ollama-qwen27b.config.toml')
foreach ($homeName in 'codex-home-skills', 'codex-home-bare') {
    $dst = Join-Path $EvalRoot $homeName
    New-Item -ItemType Directory -Force $dst | Out-Null
    foreach ($f in $keep) {
        $p = Join-Path $codexSrc $f
        if (Test-Path $p) { Copy-Item $p $dst -Force } else { Write-Warning "codex home file missing: $f" }
    }
    Write-Host "codex   -> $dst"
}
# skills variant gets the two skills under skills\<name>\ (codex user-scope discovery)
foreach ($name in $skillMap.Keys) {
    $dst = Join-Path $EvalRoot "codex-home-skills\skills\$name"
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force -Confirm:$false }
    New-Item -ItemType Directory -Force $dst | Out-Null
    Copy-Item (Join-Path $EvalRoot "skills\$name\*") $dst -Recurse -Force
}
Write-Host "codex   -> codex-home-skills\skills\{aws-cli,aws}"

# Contamination scrub: the user's real config.toml has the domain-expert marketplace
# installed with its plugins enabled — the BARE home would load the skill under test
# through the plugin system. Strip every domain-expert marketplace/plugin section from
# BOTH homes (identical configs; the skills arm gets skills via skills\ only).
foreach ($homeName in 'codex-home-skills', 'codex-home-bare') {
    $tomlPath = Join-Path $EvalRoot "$homeName\config.toml"
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
    # project trust entries naming the repo path are harmless; only marketplace/plugin refs matter
    $left = Select-String -Path $tomlPath -Pattern 'marketplaces\.domain-expert|@domain-expert' -Quiet
    if ($left) { throw "$homeName config.toml still references the domain-expert marketplace/plugins after scrub — inspect manually." }
    Write-Host "scrubbed domain-expert plugin config from $homeName\config.toml"
}

# ---- work root + secrets template -----------------------------------------
New-Item -ItemType Directory -Force (Join-Path $EvalRoot 'work') | Out-Null
$secrets = Join-Path $EvalRoot 'secrets.json'
if (-not (Test-Path $secrets)) {
    '{ "anthropic_api_key": "" }' | Set-Content $secrets -Encoding utf8
    Write-Warning "wrote secrets template $secrets — fill in anthropic_api_key before dispatching claude cells."
} else { Write-Host "secrets -> $secrets (exists, untouched)" }

Write-Host "`nworkspace ready. Reminder: both codex homes now hold a copy of auth.json."
