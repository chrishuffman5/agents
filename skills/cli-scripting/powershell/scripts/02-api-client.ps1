#!/usr/bin/env pwsh
# ============================================================================
# PowerShell - REST API Client
#
# Purpose : Generic REST API client with authentication, pagination, and
#           retry logic. Supports Bearer tokens, API keys, and Basic auth.
# Version : 1.0.0
# Targets : PowerShell 7.0+
# Safety  : Read-only by default. POST/PUT/PATCH require explicit -Method.
#
# Examples:
#   .\02-api-client.ps1 -BaseUri 'https://api.github.com' -Endpoint '/users/octocat'
#   .\02-api-client.ps1 -BaseUri $uri -Token $pat -Endpoint '/orgs/microsoft/repos' -Paginate
# ============================================================================
#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaseUri,
    [Parameter(Mandatory)][string]$Endpoint,

    [string]$Token,
    [string]$ApiKey,
    [string]$ApiKeyHeader = 'X-API-Key',

    [ValidateSet('GET','POST','PUT','PATCH','DELETE')]
    [string]$Method = 'GET',

    [hashtable]$Body,
    [hashtable]$QueryParams,
    [hashtable]$ExtraHeaders = @{},

    [switch]$Paginate,
    [int]$PageSize   = 100,
    [int]$MaxPages   = 50,

    [int]$MaxRetries = 3,
    [int]$RetryDelay = 2,

    [ValidateSet('Object','JSON','Table')]
    [string]$OutputFormat = 'Object',

    [string]$OutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Build headers ────────────────────────────────────────────────────────────
$headers = @{ Accept = 'application/json' }
if ($Token)  { $headers['Authorization'] = "Bearer $Token" }
if ($ApiKey) { $headers[$ApiKeyHeader]    = $ApiKey }
foreach ($key in $ExtraHeaders.Keys) { $headers[$key] = $ExtraHeaders[$key] }

# ── Build query string ───────────────────────────────────────────────────────
function Build-Uri([string]$base, [string]$path, [hashtable]$params) {
    $uri = "$($base.TrimEnd('/'))$path"
    if ($params -and $params.Count -gt 0) {
        $qs = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$([uri]::EscapeDataString($_.Value))" }) -join '&'
        $uri += "?$qs"
    }
    return $uri
}

# ── Retry wrapper ────────────────────────────────────────────────────────────
function Invoke-WithRetry {
    param([scriptblock]$Action, [int]$Max, [int]$Delay)
    $attempt = 0
    do {
        $attempt++
        try { return (& $Action) }
        catch {
            $code = $_.Exception.Response?.StatusCode.value__
            if ($attempt -ge $Max -or $code -notin @(429, 500, 502, 503, 504)) { throw }
            $wait = if ($code -eq 429) {
                [int]($_.Exception.Response.Headers['Retry-After'] ?? ($Delay * $attempt))
            } else { $Delay * $attempt }
            Write-Warning "Attempt $attempt/$Max failed (HTTP $code). Retrying in ${wait}s..."
            Start-Sleep -Seconds $wait
        }
    } while ($attempt -lt $Max)
}

# ── Single request ───────────────────────────────────────────────────────────
function Invoke-ApiRequest([string]$Uri, [string]$HttpMethod, [hashtable]$RequestBody) {
    $splat = @{
        Uri     = $Uri
        Method  = $HttpMethod
        Headers = $headers
    }
    if ($RequestBody) {
        $splat['Body']        = ($RequestBody | ConvertTo-Json -Depth 10)
        $splat['ContentType'] = 'application/json'
    }
    Write-Verbose "$HttpMethod $Uri"
    Invoke-WithRetry -Action { Invoke-RestMethod @splat } -Max $MaxRetries -Delay $RetryDelay
}

# ── Paginated request ────────────────────────────────────────────────────────
function Invoke-PaginatedRequest([string]$BasePath) {
    $allItems = [System.Collections.Generic.List[object]]::new()
    $page = 1
    do {
        $params = $QueryParams ?? @{}
        $params['page']     = $page
        $params['per_page'] = $PageSize
        $uri = Build-Uri $BaseUri $BasePath $params

        Write-Verbose "Page $page: $uri"
        $response = Invoke-WithRetry -Action {
            Invoke-WebRequest -Uri $uri -Headers $headers -Method GET
        } -Max $MaxRetries -Delay $RetryDelay

        $data = $response.Content | ConvertFrom-Json
        if ($data -is [array]) { $allItems.AddRange($data) }
        else { $allItems.Add($data) }

        # Check Link header for next page
        $linkHeader = $response.Headers['Link']
        $hasNext = $linkHeader -and $linkHeader -match 'rel="next"'

        $page++
        Write-Verbose "  Retrieved $($data.Count) items (total: $($allItems.Count))"
    } while ($hasNext -and $page -le $MaxPages -and $data.Count -eq $PageSize)

    return $allItems
}

# ── Main execution ───────────────────────────────────────────────────────────
Write-Verbose "API Client: $Method $BaseUri$Endpoint"

$result = if ($Paginate) {
    Invoke-PaginatedRequest -BasePath $Endpoint
} else {
    $uri = Build-Uri $BaseUri $Endpoint $QueryParams
    Invoke-ApiRequest -Uri $uri -HttpMethod $Method -RequestBody $Body
}

# ── Output ───────────────────────────────────────────────────────────────────
switch ($OutputFormat) {
    'JSON'   { $output = $result | ConvertTo-Json -Depth 10 }
    'Table'  { $result | Format-Table -AutoSize; return }
    default  { }
}

if ($OutputFile) {
    $jsonOut = $result | ConvertTo-Json -Depth 10
    Set-Content -Path $OutputFile -Value $jsonOut -Encoding UTF8
    Write-Host "Output saved to: $OutputFile ($(@($result).Count) items)"
} elseif ($OutputFormat -eq 'JSON') {
    Write-Output $output
} else {
    Write-Output $result
}
