---
name: cli-powershell-7.6
description: "PowerShell 7.6 LTS version agent. Released March 2026, 3-year LTS on .NET 10. Graduated features: PSFeedbackProvider (command suggestions), PSRedirectToVariable (redirect streams to variables), PSNativeWindowsTildeExpansion. New: Join-Path multi-child, ThreadJob module renamed, extensive tab completion improvements, PSReadLine 2.4.5. Includes 5.1 vs 7.x comparison guidance."
license: MIT
metadata:
  version: "1.0.0"
---

# PowerShell 7.6 LTS

**Released:** March 18, 2026 | **LTS:** 3 years | **Runtime:** .NET 10

PowerShell 7.6 is the latest LTS release, graduating several experimental features and shipping on .NET 10 for improved performance.

## Graduated Experimental Features

### PSFeedbackProvider (No Flag Needed)

```powershell
# Mistype a command — PS 7.6 suggests corrections
# Example: type "get-chiditem" → "Did you mean Get-ChildItem?"

# Register custom feedback providers
Register-PSFeedbackProvider -Name 'MyProvider' -ScriptBlock { }
```

### PSRedirectToVariable

```powershell
# Redirect error stream to variable using Variable: drive
Get-ChildItem /nonexistent 2> Variable:myErrors
$myErrors   # contains ErrorRecord objects

# Redirect info stream
Write-Information 'test' 6> Variable:infoLog
```

### PSNativeWindowsTildeExpansion

```powershell
# Before 7.6: ~ did NOT expand in native command arguments on Windows
# After 7.6: ~ expands correctly
notepad.exe ~/Documents/notes.txt   # works like Linux/macOS now
```

## New Cmdlet Enhancements

### Join-Path Multi-Child (Breaking Change)

```powershell
# Before: had to chain Join-Path calls
# Join-Path C:\ -ChildPath 'Program Files' | Join-Path -ChildPath 'App'

# After (7.6): -ChildPath accepts string[]
$path = Join-Path 'C:\' -ChildPath 'Program Files', 'MyApp', 'config.xml'
# Result: C:\Program Files\MyApp\config.xml
```

### Tab Completion Improvements

```powershell
# Path completion across all providers
# Module short-name completion (e.g., 'PSRead' → PSReadLine)
# Value completion for additional cmdlet parameters

# NativeFallback completer for native tools
Register-ArgumentCompleter -NativeFallback -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    # fallback completer for ALL native commands
}
```

## Breaking Changes from 7.4

### ThreadJob Module Renamed

```powershell
# Before 7.6:
Import-Module ThreadJob

# PS 7.6: renamed to Microsoft.PowerShell.ThreadJob
Import-Module Microsoft.PowerShell.ThreadJob
# Start-ThreadJob cmdlet name unchanged
```

### WildcardPattern.Escape()

Lone backticks now correctly escaped. Test wildcard patterns that use backticks.

## PSReadLine 2.4.5

```powershell
# Bug fixes for crashes and incorrect behavior
# Enhanced prediction stability
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView
```

## .NET 10 Benefits

- JIT improvements and smaller memory footprint
- New APIs: spans, memory-efficient string operations
- LINQ improvements passed through to PS pipeline operations

## Installation

```powershell
# Windows (winget)
winget install Microsoft.PowerShell --version 7.6.0

# Verify
$PSVersionTable.PSVersion   # 7.6.x
[System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
# .NET 10.x.x
```

## Windows PowerShell 5.1 vs PowerShell 7.x

### Key Differences

| Aspect | PS 5.1 | PS 7.x |
|--------|--------|--------|
| Runtime | .NET Framework 4.x | .NET 10 (7.6) |
| Executable | `powershell.exe` | `pwsh.exe` |
| Platform | Windows only | Windows, Linux, macOS |
| Default encoding | UTF-16 LE | UTF-8 (no BOM) |
| Ternary `? :` | Not supported | Supported |
| Null operators `??` `??=` `?.` | Not supported | Supported |
| Pipeline chains `&&` `\|\|` | Not supported | Supported |
| ForEach-Object -Parallel | Not available | Available |
| SSH remoting | Not available | Available |
| Write-Host stream | Not capturable | Goes to Information stream (6) |

### Cross-Version Compatibility

```powershell
# Detect version at runtime
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $result = $x ?? 'default'
} else {
    $result = if ($null -ne $x) { $x } else { 'default' }
}

# Use #Requires to enforce
#Requires -PSEdition Core       # PS 7.x only
#Requires -PSEdition Desktop    # Windows PS 5.1 only

# Run 5.1 modules from PS7
Import-Module -UseWindowsPowerShell ActiveDirectory

# Check module compatibility
$module = Get-Module -Name MyModule -ListAvailable
$module.CompatiblePSEditions
```

### Common Traps

1. **ConvertTo-Json depth** -- default depth 2, always specify `-Depth 10`
2. **$LASTEXITCODE** -- more consistently set in 7.x
3. **Out-File encoding** -- 5.1 defaults to UTF-16 LE; 7.x defaults to UTF-8
4. **Snap-ins removed** -- PS7 removed snap-in support entirely
