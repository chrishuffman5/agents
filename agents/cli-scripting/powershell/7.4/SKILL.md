---
name: cli-powershell-7.4
description: "PowerShell 7.4 LTS version agent. Released November 2023, supported through November 2026. Built on .NET 8. Features stable ternary/null-coalescing/null-conditional operators, pipeline chain operators, ForEach-Object -Parallel improvements, web cmdlet timeouts (ConnectionTimeoutSeconds, OperationTimeoutSeconds), Brotli decompression, auto-retry on HTTP 429, and PSReadLine 2.3.6 with predictive IntelliSense."
license: MIT
metadata:
  version: "1.0.0"
---

# PowerShell 7.4 LTS

**Released:** November 2023 | **LTS until:** November 2026 | **Runtime:** .NET 8

PowerShell 7.4 is the recommended LTS version for production environments. All operators introduced in 7.0 are fully stable and battle-tested.

## Key Features

### Stable Operators (Introduced 7.0, Fully Stable in 7.4)

```powershell
# Ternary operator
$label = ($count -gt 0) ? 'has items' : 'empty'
$env   = ($isProd) ? 'production' : 'development'

# Null-coalescing
$port    = $config.Port ?? 8080
$timeout = $env:TIMEOUT ?? 30
$name    = $null ?? $null ?? 'last-resort'

# Null-coalescing assignment
$cache ??= @{}
$list  ??= [System.Collections.Generic.List[string]]::new()

# Null-conditional member access
$city  = $user?.Address?.City ?? 'Unknown'
$first = $arr?[0]

# Pipeline chain operators
npm install && npm test && npm run build
git pull || Write-Error "Pull failed"
```

### Web Cmdlet Improvements (7.4)

```powershell
# New timeout parameters
Invoke-RestMethod -Uri $url -ConnectionTimeoutSeconds 10 -OperationTimeoutSeconds 30

# Brotli decompression support — automatic
$r = Invoke-WebRequest -Uri 'https://example.com'

# Auto-retry on HTTP 429 with Retry-After header
Invoke-RestMethod -Uri $rateLimitedApi   # respects Retry-After automatically

# Ctrl+C support when connection hangs — no code change needed
```

### ForEach-Object -Parallel Improvements

```powershell
# Better error propagation from parallel blocks
# -ThrottleLimit default raised to match processor count
1..100 | ForEach-Object -Parallel {
    Get-Process -Id $PID
} -ThrottleLimit 10
```

### ConvertTo-Json Changes (Breaking from 7.3)

```powershell
# Large enums serialized as numbers (not strings)
[System.DayOfWeek]::Monday | ConvertTo-Json   # produces 1 (number), not "Monday"

# BigInteger serialized as number
[System.Numerics.BigInteger]::Parse('999999999999999999') | ConvertTo-Json
```

### PSReadLine 2.3.6

```powershell
# Predictive IntelliSense
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView    # ghost text
Set-PSReadLineOption -PredictionViewStyle ListView      # dropdown

# Tab completion improvements
# - Better hashtable key completion
# - Parameter completion respects ValidateRange
# - Enum parameter completion
```

### PSFeedbackProvider (Experimental in 7.4)

Enables "Did you mean Get-ChildItem?" style suggestions for mistyped commands. Graduates to stable in 7.6.

## Installation

```powershell
# Windows (winget)
winget install Microsoft.PowerShell

# Linux (apt)
# sudo apt install powershell

# macOS (brew)
# brew install --cask powershell

# Verify
$PSVersionTable.PSVersion   # 7.4.x
```

## Migration from 5.1

See the parent `powershell/SKILL.md` for 5.1 vs 7.x differences. Key points:
- Runtime: .NET Framework 4.x (5.1) vs .NET 8 (7.4)
- Executable: `powershell.exe` (5.1) vs `pwsh.exe` (7.x)
- Side-by-side: both can coexist on the same system
- Use `Import-Module -UseWindowsPowerShell` for 5.1-only modules
