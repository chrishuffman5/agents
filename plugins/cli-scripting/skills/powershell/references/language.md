# PowerShell Language Reference

> Pipeline, variables, types, operators, control flow, functions, error handling, strings, collections.

---

## 1. Pipeline and Objects

Everything in PowerShell is a .NET object. The pipeline passes objects, not text.

```powershell
# Basic pipeline: Get-Process returns [System.Diagnostics.Process] objects
Get-Process | Where-Object { $_.CPU -gt 100 } | Select-Object Name, CPU, Id

# $_ and $PSItem are identical — current pipeline object
Get-Service | ForEach-Object { "$($_.Name) is $($_.Status)" }

# Select-Object — choose/rename properties, first/last/skip/unique
Get-Process | Select-Object -Property Name, CPU, WorkingSet -First 10
Get-Process | Select-Object -Property @{Name='Mem(MB)'; Expression={[math]::Round($_.WorkingSet/1MB,1)}}
Get-ChildItem | Select-Object -ExpandProperty Name          # unwrap single property

# Where-Object — filter objects
Get-Process | Where-Object CPU -gt 50                       # simplified syntax
Get-Process | Where-Object { $_.CPU -gt 50 -and $_.Name -ne 'Idle' }
Get-ChildItem -Recurse | Where-Object { $_.Extension -eq '.log' -and $_.Length -gt 1MB }

# ForEach-Object — transform/act on each object
1..5 | ForEach-Object { $_ * 2 }
Get-Content servers.txt | ForEach-Object { Test-Connection $_ -Count 1 -Quiet }

# Sort-Object — sort on properties
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5
Get-ChildItem | Sort-Object @{Expression='LastWriteTime'; Descending=$true}

# Group-Object — group by property value
Get-Process | Group-Object -Property Company | Sort-Object Count -Descending
Get-ChildItem -Recurse | Group-Object Extension | Select-Object Name, Count

# Measure-Object — compute stats
Get-Process | Measure-Object CPU -Sum -Average -Maximum
Get-Content bigfile.txt | Measure-Object -Line -Word -Character
1..100 | Measure-Object -Sum -Average

# Multi-stage pipeline — real-world example
Get-ChildItem C:\Logs -Filter '*.log' -Recurse |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
    Select-Object FullName, Length, LastWriteTime |
    Sort-Object LastWriteTime -Descending |
    Export-Csv recent-logs.csv -NoTypeInformation

# Tee-Object — split pipeline to file/variable AND continue
Get-Process | Tee-Object -Variable procs | Where-Object CPU -gt 50

# Pipeline variable
Get-ChildItem -PipelineVariable file | Select-Object FullName |
    ForEach-Object { "File: $($file.Name) at $($file.LastWriteTime)" }
```

---

## 2. Variables and Types

```powershell
# Basic declaration — type inferred
$name    = "Alice"
$age     = 30
$active  = $true
$nothing = $null

# Explicit type constraints
[string]  $name    = "Alice"
[int]     $count   = 42
[bool]    $flag    = $false
[double]  $pi      = 3.14159
[decimal] $price   = 19.99
[datetime]$now     = Get-Date

# Type casting
[int]"42"                        # 42
[string]3.14                     # "3.14"
[bool]1                          # $true
[datetime]"2025-01-15"

# Type accelerators (.NET types)
[xml]$doc    = Get-Content config.xml
[regex]$rx   = '\d{3}-\d{4}'
[ipaddress]$ip = '192.168.1.1'
[guid]$id    = [guid]::NewGuid()
[uri]$url    = 'https://example.com'

# Arrays
$fruits    = @('apple','banana','cherry')
$nums      = 1, 2, 3, 4, 5
$fruits[0]                       # 'apple'
$fruits[-1]                      # 'cherry'
$fruits[1..2]                    # 'banana','cherry'
$fruits += 'date'                # append (creates new array — slow for large data)
$fruits.Count

# Typed arrays
[int[]]$scores  = 90, 85, 92, 78
[string[]]$tags = 'dev','ops','sec'

# Hashtables
$config = @{
    Server   = 'db01'
    Port     = 5432
    Database = 'prod'
    SSL      = $true
}
$config['Server']                # access by key
$config.Server                   # dot notation
$config.Add('Timeout', 30)
$config.ContainsKey('Port')

# Ordered hashtable — preserves insertion order
$ordered = [ordered]@{ First = 1; Second = 2; Third = 3 }

# PSCustomObject — structured object
$person = [PSCustomObject]@{
    Name  = 'Alice'
    Age   = 30
    Email = 'alice@example.com'
}
$person.Name
$person | Add-Member -MemberType NoteProperty -Name Role -Value 'Admin'

# DateTime operations
$now     = Get-Date
$future  = $now.AddDays(30)
$diff    = $future - $now           # TimeSpan
$diff.TotalHours
Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

# Automatic variables
$_                  # current pipeline object (also $PSItem)
$PSVersionTable     # PSVersion, PSEdition, OS, Platform
$Error              # array of recent errors; $Error[0] = most recent
$LASTEXITCODE       # exit code of last native command
$?                  # $true if last command succeeded
$null               # null value
$HOME               # current user's home directory
$PWD                # current working directory
$PSScriptRoot       # directory of the currently running script
$PSCommandPath      # full path of the currently running script
$args               # array of arguments passed to a script (no param())
$PID                # process ID of current PowerShell host
$ErrorActionPreference  # default error action (Stop, Continue, SilentlyContinue)

# Using $PSScriptRoot safely
$configPath = Join-Path $PSScriptRoot 'config.json'
```

---

## 3. Operators

```powershell
# Comparison operators — case-insensitive by default, prefix with 'c' for case-sensitive
'Hello' -eq 'hello'     # $true
'Hello' -ceq 'hello'    # $false
10 -gt 5                 # $true
10 -ge 10                # $true

# Wildcard matching
'PowerShell' -like 'Power*'     # $true
'test123'    -like '*[0-9]'     # $true

# Regex matching — populates $Matches
'abc123' -match '\d+'           # $true; $Matches[0] = '123'
'2025-01-15' -match '(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})'
$Matches['year']                # '2025'

# Collection operators
@(1,2,3) -contains 2            # $true
2 -in @(1,2,3)                  # $true

# Type check
42 -is [int]                     # $true

# Logical
$true -and $false                # $false
$true -or  $false                # $true
-not $true                       # $false
$true -xor $false                # $true

# String operators
'abc' * 3                        # 'abcabcabc'
@('a','b','c') -join ','         # 'a,b,c'
'a,b,c' -split ','               # @('a','b','c')

# -replace (regex-based)
'Hello World' -replace 'World','PowerShell'
'abc123' -replace '[^a-z]',''    # 'abc'
'2025-01-15' -replace '(\d{4})-(\d{2})-(\d{2})','$3/$2/$1'

# -f format operator
'{0} has {1} items' -f 'Cart', 42
'{0:N2}' -f 3.14159              # '3.14'
'{0:C}' -f 19.99                 # '$19.99'
'{0,10}' -f 'right'              # right-aligned in 10 chars
'{0,-10}' -f 'left'              # left-aligned

# Range operator
1..10                             # @(1..10)
'a'..'z'                          # character range (PS 7.x)

# PowerShell 7.x operators
$status = ($age -ge 18) ? 'Adult' : 'Minor'       # Ternary
$setting = $envVar ?? 'fallback-value'              # Null-coalescing
$cache ??= @{}                                      # Null-coalescing assignment
$city = $user?.Address?.City                        # Null-conditional
$arr?[0]                                            # Safe index
git pull && git push                                # Pipeline chain
Test-Path file.txt || Write-Error "Missing!"
```

---

## 4. Control Flow

```powershell
# if / elseif / else
$score = 85
if ($score -ge 90) { 'A' }
elseif ($score -ge 80) { 'B' }
elseif ($score -ge 70) { 'C' }
else { 'F' }

# switch — multiple matches execute unless break
switch ($env:OS) {
    'Windows_NT' { 'Running on Windows' }
    'Linux'      { 'Running on Linux' }
    default      { "Unknown: $env:OS" }
}

# switch -Wildcard
switch -Wildcard ($filename) {
    '*.log'  { 'Log file' }
    '*.csv'  { 'CSV file' }
    '*.json' { 'JSON file' }
    default  { 'Unknown file type' }
}

# switch -Regex
switch -Regex ($logLine) {
    '^ERROR'   { "Error: $_"; break }
    '^WARN'    { "Warning: $_"; break }
}

# switch -File — process each line
switch -Regex -File server.log {
    'ERROR' { Write-Warning $_ }
    'FATAL' { Write-Error $_; break }
}

# for loop
for ($i = 0; $i -lt 10; $i++) { Write-Output "Index: $i" }

# foreach statement — fastest for in-memory collections
foreach ($item in $collection) { $item.Property }

# ForEach-Object — pipeline-compatible
$collection | ForEach-Object { $_.Property }

# while / do-while / do-until
$count = 0
while ($count -lt 5) { $count++ }

$attempts = 0
do {
    $result = Try-Connect -Server $server
    $attempts++
} while (-not $result -and $attempts -lt 3)

do {
    $input = Read-Host 'Enter value'
} until ($input -match '^\d+$')

# break / continue
foreach ($file in $files) {
    if ($file.Length -gt 1GB) { break }
    Process-File $file
}
foreach ($num in 1..20) {
    if ($num % 2 -eq 0) { continue }
    Write-Output $num   # only odd numbers
}
```

---

## 5. Functions

```powershell
# Basic function
function Get-Greeting {
    param([string]$Name = 'World')
    "Hello, $Name!"
}

# Advanced function — full template
function Invoke-DataProcess {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position=0, ValueFromPipeline,
                   HelpMessage='Enter the input data path')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Position=1)]
        [ValidateSet('CSV','JSON','XML')]
        [string]$Format = 'CSV',

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$BatchSize = 100,

        [Parameter()]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Write-Verbose "Starting. Format: $Format, BatchSize: $BatchSize"
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        foreach ($p in $Path) {
            if ($PSCmdlet.ShouldProcess($p, 'Process data')) {
                try {
                    $data = Import-DataFile -Path $p -Format $Format
                    $results.Add($data)
                } catch {
                    Write-Error "Failed to process $p`: $_"
                }
            }
        }
    }

    end {
        Write-Verbose "Processed $($results.Count) items"
        if ($PassThru) { $results }
    }
}

# Pipeline input example
function Get-ItemSize {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [System.IO.FileInfo]$File
    )
    process {
        [PSCustomObject]@{
            Name   = $File.Name
            SizeMB = [math]::Round($File.Length / 1MB, 2)
        }
    }
}
Get-ChildItem *.log | Get-ItemSize

# Validation attributes
function Set-Config {
    param(
        [ValidateSet('dev','staging','prod')]
        [string]$Environment,

        [ValidateRange(1024, 65535)]
        [int]$Port,

        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigFile,

        [ValidateCount(1,5)]
        [string[]]$Tags
    )
}

# Write-Verbose, Write-Debug, Write-Warning
function Process-Item {
    [CmdletBinding()]
    param([string]$Name)
    Write-Verbose  "Processing: $Name"
    Write-Debug    "Debug detail for: $Name"
    Write-Warning  "This may cause issues: $Name"
    Write-Output [PSCustomObject]@{ Item = $Name; Status = 'Done' }
}

# -WhatIf and -Confirm
function Remove-OldLogs {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param([int]$DaysOld = 30)
    Get-ChildItem *.log |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$DaysOld) } |
        ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_.FullName, 'Delete log file')) {
                Remove-Item $_.FullName
            }
        }
}
```

---

## 6. Error Handling

```powershell
# try / catch / finally
try {
    $result = Invoke-RestMethod -Uri $url
}
catch [System.Net.Http.HttpRequestException] {
    Write-Error "HTTP error: $($_.Exception.Message)"
}
catch [System.UnauthorizedAccessException] {
    Write-Error "Access denied: $($_.Exception.Message)"
}
catch {
    Write-Error "Unexpected: $($_.Exception.Message)"
    Write-Verbose "Type: $($_.Exception.GetType().FullName)"
}
finally {
    if ($connection) { $connection.Dispose() }
}

# ErrorActionPreference
$ErrorActionPreference = 'Stop'             # any error throws
$ErrorActionPreference = 'Continue'         # default — display, continue
$ErrorActionPreference = 'SilentlyContinue' # suppress, continue

# Per-cmdlet override
Get-Item 'missing.txt' -ErrorAction SilentlyContinue
Get-Item 'missing.txt' -ErrorAction Stop

# Capture errors to variable
Get-Item 'missing.txt' -ErrorVariable myErr -ErrorAction SilentlyContinue
if ($myErr) { Write-Warning "Not found: $($myErr[0].Exception.Message)" }

# ErrorRecord anatomy
try { 1/0 }
catch {
    $err = $_
    $err.Exception.Message
    $err.Exception.GetType().FullName
    $err.CategoryInfo.Category
    $err.FullyQualifiedErrorId
    $err.ScriptStackTrace
    $err.InvocationInfo.ScriptLineNumber
}

# $Error global array
$Error.Count                     # number of errors in session
$Error[0]                        # most recent error
$Error.Clear()

# Terminating vs non-terminating
Write-Error "Something went wrong"  # non-terminating
throw "Invalid input"                # terminating

# Typed throw
throw [System.ArgumentException]::new("Value cannot be null", "paramName")

# $? and $LASTEXITCODE
git status
if (-not $?) { Write-Error "git status failed" }
git push
if ($LASTEXITCODE -ne 0) { Write-Error "git push failed with code $LASTEXITCODE" }
```

---

## 7. Strings

```powershell
# Single vs double quotes
$name = 'Alice'
'Hello $name'                    # literal: Hello $name
"Hello $name"                    # interpolated: Hello Alice
"Result: $(2 + 2)"              # expression interpolation

# Escape sequences in double-quoted strings
"`n"    # newline
"`t"    # tab
"`""    # double quote
"``"    # literal backtick
"`$"    # literal dollar sign

# Here-strings
$html = @"
<html>
    <body>Hello, $name</body>
</html>
"@

$query = @'
SELECT * FROM users WHERE name = '$name'
'@

# String methods (.NET)
$s = "  Hello, World!  "
$s.Trim()                        # "Hello, World!"
$s.Trim().ToUpper()              # "HELLO, WORLD!"
$s.Trim().Replace(',','')        # "Hello World!"
$s.Trim().Contains('World')      # $true
$s.Trim().StartsWith('He')       # $true
$s.Trim().Split(',')             # @('Hello', ' World!')
$s.Trim().Substring(7, 5)        # "World"
[string]::IsNullOrEmpty($s)
[string]::IsNullOrWhiteSpace($s)
[string]::Join(' | ', @('a','b','c'))

# Padding
'left'.PadRight(10)              # "left      "
'42'.PadLeft(6, '0')             # "000042"

# Regex
'abc123' -match '\d+'            # $true, $Matches[0] = '123'

# Named capture groups
'2025-01-15' -match '(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})'
$Matches['year']                 # '2025'

# [regex] class
$pattern = [regex]'\b\w{5}\b'
$pattern.Matches('Hello World Again')
[regex]::Replace('Hello World', '\bWorld\b', 'PowerShell')

# Select-String — grep-like
Get-Content app.log | Select-String 'ERROR' | Select-Object LineNumber, Line
Select-String -Path '*.log' -Pattern 'FATAL|CRITICAL' -CaseSensitive
```

---

## 8. Collections

```powershell
# Arrays
$arr = @(1, 2, 3, 4, 5)
$arr.Count
$arr[0]                          # first
$arr[-1]                         # last
$arr[1..3]                       # slice
$arr -contains 3                 # $true

# ArrayList — mutable (no type restriction)
$list = [System.Collections.ArrayList]::new()
[void]$list.Add('item1')
$list.Remove('item1')

# Generic List — type-safe, preferred
$strings = [System.Collections.Generic.List[string]]::new()
$strings.Add('alpha')
$strings.Add('beta')
$strings.Sort()

$objects = [System.Collections.Generic.List[PSCustomObject]]::new()
$objects.Add([PSCustomObject]@{ Name = 'Alice'; Age = 30 })

# Hashtables
$ht = @{ Key1 = 'Value1'; Key2 = 42 }
$ht['Key1']
$ht.Key1
$ht.GetEnumerator() | Sort-Object Key
$ht.ContainsKey('Key2')

# Nested hashtable
$config = @{
    Database = @{ Host='db01'; Port=5432 }
    Cache    = @{ Host='cache01'; Port=6379 }
}
$config.Database.Host

# Ordered hashtable
$ordered = [ordered]@{ Third = 3; First = 1; Second = 2 }

# Splatting — pass hashtable as parameters
$params = @{
    Path        = 'C:\Logs'
    Filter      = '*.log'
    Recurse     = $true
    ErrorAction = 'SilentlyContinue'
}
Get-ChildItem @params

# Array splatting
$args = @('C:\source', 'C:\dest')
Copy-Item @args

# Generic Dictionary
$dict = [System.Collections.Generic.Dictionary[string,int]]::new()
$dict.Add('alpha', 1)
$dict.TryGetValue('alpha', [ref]$out)
```
