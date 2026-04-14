# PowerShell Patterns Reference

> Script template, file processing, API interaction, parallel execution, output formatting.

---

## 1. Script Template

```powershell
#Requires -Version 7.0
#Requires -Modules @{ModuleName='PSReadLine'; ModuleVersion='2.0.0'}

<#
.SYNOPSIS
    Brief one-line description.
.DESCRIPTION
    Longer description of purpose and behavior.
.PARAMETER Path
    Path to the input file or directory.
.PARAMETER OutputPath
    Where to write results. Defaults to current directory.
.EXAMPLE
    PS> .\My-Script.ps1 -Path C:\Data -OutputPath C:\Reports
.NOTES
    Author: Your Name
    Version: 1.0.0
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage='Path to input data')]
    [ValidateScript({ Test-Path $_ })]
    [string[]]$Path,

    [Parameter()]
    [string]$OutputPath = $PSScriptRoot,

    [Parameter()]
    [ValidateSet('CSV','JSON','Both')]
    [string]$Format = 'CSV'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

begin {
    Write-Verbose "Script starting. Output: $OutputPath"
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
}

process {
    foreach ($p in $Path) {
        try {
            Write-Verbose "Processing: $p"
            $results.Add([PSCustomObject]@{ Path = $p; Status = 'OK' })
        } catch {
            Write-Error "Failed on ${p}: $($_.Exception.Message)"
        }
    }
}

end {
    Write-Verbose "Processed $($results.Count) items"
    if ($Format -in 'CSV','Both') {
        $csvPath = Join-Path $OutputPath 'results.csv'
        if ($PSCmdlet.ShouldProcess($csvPath, 'Write CSV')) {
            $results | Export-Csv $csvPath -NoTypeInformation
        }
    }
    if ($Format -in 'JSON','Both') {
        $jsonPath = Join-Path $OutputPath 'results.json'
        if ($PSCmdlet.ShouldProcess($jsonPath, 'Write JSON')) {
            $results | ConvertTo-Json -Depth 5 | Set-Content $jsonPath -Encoding UTF8
        }
    }
    Write-Output $results
}
```

---

## 2. File Processing Patterns

### CSV Pipeline

```powershell
# Filter, transform, re-export
Import-Csv employees.csv |
    Where-Object { $_.Department -eq 'Engineering' -and [int]$_.Salary -gt 80000 } |
    Select-Object Name, Email,
        @{Name='Salary'; Expression={[int]$_.Salary}},
        @{Name='YearsEmployed'; Expression={
            [math]::Round(((Get-Date) - [datetime]$_.HireDate).TotalDays / 365, 1)
        }} |
    Sort-Object YearsEmployed -Descending |
    Export-Csv engineers.csv -NoTypeInformation

# Process large CSV with batching
$batch = [System.Collections.Generic.List[PSCustomObject]]::new()
Import-Csv huge.csv | ForEach-Object {
    $batch.Add($_)
    if ($batch.Count -ge 1000) {
        Process-Batch $batch
        $batch.Clear()
    }
}
if ($batch.Count -gt 0) { Process-Batch $batch }

# Merge two CSVs on key
$users  = Import-Csv users.csv | Group-Object -Property Id -AsHashTable
$orders = Import-Csv orders.csv
$joined = $orders | ForEach-Object {
    $user = $users[$_.UserId]
    [PSCustomObject]@{
        OrderId  = $_.Id
        UserName = $user?.Name
        Total    = $_.Total
    }
}
```

### JSON Processing

```powershell
# Read and traverse
$data = Get-Content api-data.json -Raw | ConvertFrom-Json
$data.users | Where-Object { $_.role -eq 'admin' } | Select-Object name, email

# Modify and save
$data.version = '2.0'
$data | ConvertTo-Json -Depth 10 | Set-Content updated.json -Encoding UTF8

# JSON Lines (one object per line)
Get-Content events.jsonl | ForEach-Object {
    $_ | ConvertFrom-Json
} | Where-Object { $_.level -eq 'error' }
```

### XML Processing

```powershell
[xml]$config = Get-Content app.config
$connStr = $config.configuration.connectionStrings.add |
    Where-Object { $_.name -eq 'Main' } |
    Select-Object -ExpandProperty connectionString

# XPath
$nodes = Select-Xml -Xml $config -XPath '//add[@key]' | Select-Object -ExpandProperty Node

# Modify XML
$config.configuration.appSettings.add |
    Where-Object { $_.key -eq 'Environment' } |
    ForEach-Object { $_.value = 'Production' }
$config.Save('C:\app.config')
```

### Log Parsing with Regex

```powershell
$pattern = '^(?<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+(?<level>DEBUG|INFO|WARN|ERROR|FATAL)\s+\[(?<thread>[^\]]+)\]\s+(?<message>.+)$'

$entries = Get-Content app.log | ForEach-Object {
    if ($_ -match $pattern) {
        [PSCustomObject]@{
            Timestamp = [datetime]$Matches['timestamp']
            Level     = $Matches['level']
            Thread    = $Matches['thread']
            Message   = $Matches['message']
        }
    }
} | Where-Object { $_ }

# Summary by level
$entries | Group-Object Level | Select-Object Name, Count | Sort-Object Count -Descending

# Recent errors only
$entries |
    Where-Object { $_.Level -eq 'ERROR' -and $_.Timestamp -gt (Get-Date).AddHours(-1) } |
    Select-Object Timestamp, Message
```

---

## 3. API Interaction

### Basic REST Calls

```powershell
# GET with headers
$headers = @{
    'Authorization' = "Bearer $token"
    'Accept'        = 'application/json'
}
$response = Invoke-RestMethod -Uri $uri -Headers $headers

# POST with body
$body = @{ name = 'New Repo'; private = $true } | ConvertTo-Json
Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body -ContentType 'application/json'

# PUT / PATCH / DELETE
Invoke-RestMethod -Uri "$baseUri/items/$id" -Method PUT -Body $body -Headers $headers
Invoke-RestMethod -Uri "$baseUri/items/$id" -Method DELETE -Headers $headers
```

### Authentication Patterns

```powershell
# Bearer token
$headers['Authorization'] = "Bearer $accessToken"

# Basic auth
$cred    = Get-Credential
$encoded = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($cred.UserName):$($cred.GetNetworkCredential().Password)"))
$headers['Authorization'] = "Basic $encoded"

# API Key
$headers['X-API-Key'] = $apiKey

# OAuth2 token fetch
$tokenParams = @{
    grant_type    = 'client_credentials'
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = 'https://graph.microsoft.com/.default'
}
$token = Invoke-RestMethod -Uri $tokenUrl -Method POST -Body $tokenParams
$accessToken = $token.access_token
```

### Pagination

```powershell
# Link header pagination (GitHub style)
$allItems = [System.Collections.Generic.List[object]]::new()
$uri = 'https://api.github.com/orgs/microsoft/repos?per_page=100'

do {
    $response = Invoke-WebRequest -Uri $uri -Headers $headers
    $data     = $response.Content | ConvertFrom-Json
    $allItems.AddRange($data)
    $linkHeader = $response.Headers['Link']
    $nextUri = if ($linkHeader -match '<([^>]+)>;\s*rel="next"') { $Matches[1] } else { $null }
    $uri = $nextUri
} while ($uri)

# Offset pagination
$page = 1
$allResults = [System.Collections.Generic.List[object]]::new()
do {
    $resp = Invoke-RestMethod -Uri "${baseUri}?page=${page}&limit=100" -Headers $headers
    $allResults.AddRange($resp.data)
    $page++
} while ($resp.hasMore -or $resp.data.Count -eq 100)
```

### Retry Logic

```powershell
function Invoke-RestWithRetry {
    param(
        [string]$Uri,
        [hashtable]$Headers = @{},
        [string]$Method = 'GET',
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 2
    )
    $attempt = 0
    do {
        $attempt++
        try {
            return Invoke-RestMethod -Uri $Uri -Headers $Headers -Method $Method
        } catch {
            $code = $_.Exception.Response?.StatusCode.value__
            if ($attempt -ge $MaxRetries -or $code -notin @(429, 500, 502, 503, 504)) { throw }
            $delay = if ($code -eq 429) {
                [int]($_.Exception.Response.Headers['Retry-After'] ?? ($DelaySeconds * $attempt))
            } else { $DelaySeconds * $attempt }
            Write-Warning "Attempt $attempt failed (HTTP $code). Retrying in ${delay}s..."
            Start-Sleep -Seconds $delay
        }
    } while ($attempt -lt $MaxRetries)
}
```

---

## 4. Parallel Execution

### ForEach-Object -Parallel (PS 7.0+)

```powershell
# Basic parallel processing
$servers = 'server01','server02','server03','server04'
$results = $servers | ForEach-Object -Parallel {
    [PSCustomObject]@{
        Server = $_
        Online = Test-Connection $_ -Count 1 -Quiet
        Time   = Get-Date
    }
} -ThrottleLimit 4

# $using: scope for outer variables
$baseUrl = 'https://api.example.com'
$headers = @{ Authorization = "Bearer $token" }
$data = 1..50 | ForEach-Object -Parallel {
    $url = "$using:baseUrl/items/$_"
    Invoke-RestMethod -Uri $url -Headers $using:headers
} -ThrottleLimit 10 -TimeoutSeconds 60
```

### Start-ThreadJob (Lightweight)

```powershell
$jobs = @()
foreach ($server in $servers) {
    $jobs += Start-ThreadJob -ScriptBlock {
        param($s)
        [PSCustomObject]@{
            Server = $s
            Uptime = (Get-CimInstance Win32_OperatingSystem -ComputerName $s).LastBootUpTime
        }
    } -ArgumentList $server -ThrottleLimit 5
}
$results = $jobs | Wait-Job | Receive-Job
$jobs | Remove-Job
```

### Runspaces (Maximum Performance)

```powershell
$pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, 8)
$pool.Open()

$runspaces = @()
foreach ($item in $items) {
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript({
        param($x)
        # ... work on $x ...
    }).AddArgument($item)
    $runspaces += [PSCustomObject]@{ PS = $ps; Handle = $ps.BeginInvoke() }
}

$results = foreach ($r in $runspaces) {
    $r.PS.EndInvoke($r.Handle)
    $r.PS.Dispose()
}
$pool.Close(); $pool.Dispose()
```

---

## 5. Output Formatting

```powershell
# Format cmdlets (terminal display only — not for data)
Get-Process | Format-Table -AutoSize
Get-Process | Format-Table Name, @{Label='Mem(MB)'; Expression={[math]::Round($_.WorkingSet/1MB,1)}}
Get-Process | Format-List Name, CPU, Id
Get-Service | Format-Wide -Column 4 -Property DisplayName

# Write-* streams
Write-Output  'To pipeline'                  # stream 1
Write-Error   'To error stream'              # stream 2
Write-Warning 'To warning stream'            # stream 3
Write-Verbose 'Shown with -Verbose'          # stream 4
Write-Debug   'Shown with -Debug'            # stream 5
Write-Host "Console only" -ForegroundColor Green

# ANSI colors
$ESC = [char]27
"${ESC}[31mRed text${ESC}[0m"
"${ESC}[32mGreen text${ESC}[0m"

# PSStyle (PS 7.2+)
$PSStyle.Foreground.Green + "Green text" + $PSStyle.Reset
$PSStyle.Bold + "Bold" + $PSStyle.BoldOff

# File output
Get-Process | Out-File processes.txt -Encoding UTF8 -Append
Get-Process > processes.txt               # overwrite
Get-Process >> processes.txt              # append
Get-Process 2> errors.txt                 # error stream
Get-Process *> all.txt                    # all streams
```
