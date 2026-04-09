<#
.SYNOPSIS
    Windows Client - Driver Health and Inventory
.DESCRIPTION
    Identifies problem devices, inventories all signed drivers sorted by
    date, flags unsigned drivers, lists recently installed/updated drivers,
    reports display driver and WDDM status with GPU TDR events, and
    surfaces driver-related error events from the System log.
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Problem Devices (Non-OK Status)
        2. Driver Inventory (Sorted by Date)
        3. Unsigned Drivers
        4. Recently Installed Drivers (Last 30 Days)
        5. Display Driver (WDDM) Status
        6. Driver Error Events (Last 7 Days)
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: Problem Devices
Write-Host "`n$sep`n SECTION 1 - Problem Devices (Non-OK Status)`n$sep"

$problemDevices = Get-PnpDevice | Where-Object { $_.Status -ne 'OK' }
if ($problemDevices) {
    $problemDevices | Select-Object FriendlyName, Class, Status, Problem, DeviceID |
        Format-Table -AutoSize

    # Decode common problem codes
    $problemDevices | ForEach-Object {
        $code = $_.Problem
        $meaning = switch ($code) {
            10 { 'Device cannot start (driver issue or resource conflict)' }
            28 { 'Drivers not installed' }
            43 { 'Device reported a problem (common for USB/GPU after crash)' }
            45 { 'Device not connected' }
            1  { 'Device not configured correctly' }
            default { "Problem code $code" }
        }
        Write-Host "  $($_.FriendlyName): Code $code -- $meaning"
    }
} else {
    Write-Host "OK: All devices report status OK."
}
#endregion

#region Section 2: Driver Inventory
Write-Host "$sep`n SECTION 2 - Driver Inventory (All Third-Party Signed Drivers)`n$sep"

$drivers = Get-WmiObject Win32_PnPSignedDriver | Where-Object { $_.DriverName } |
    Sort-Object DriverDate -Descending

Write-Host "Total signed drivers: $($drivers.Count)"
$drivers | Select-Object -First 30 DeviceName,
    @{N='DriverVersion';E={$_.DriverVersion}},
    @{N='DriverDate';E={if ($_.DriverDate) { [Management.ManagementDateTimeConverter]::ToDateTime($_.DriverDate).ToString('yyyy-MM-dd') } else { 'N/A' }}},
    @{N='Manufacturer';E={$_.Manufacturer}},
    InfName | Format-Table -AutoSize
#endregion

#region Section 3: Unsigned Drivers
Write-Host "$sep`n SECTION 3 - Unsigned Drivers`n$sep"

$unsigned = Get-WmiObject Win32_PnPSignedDriver | Where-Object { -not $_.IsSigned -and $_.DeviceName }
if ($unsigned) {
    Write-Warning "$($unsigned.Count) unsigned driver(s) found:"
    $unsigned | Select-Object DeviceName, DriverVersion, InfName | Format-Table -AutoSize
} else {
    Write-Host "OK: No unsigned drivers found."
}
#endregion

#region Section 4: Recently Installed Drivers
Write-Host "$sep`n SECTION 4 - Recently Installed/Updated Drivers (Last 30 Days)`n$sep"

$cutoff = (Get-Date).AddDays(-30)
$recentDrivers = Get-WmiObject Win32_PnPSignedDriver | Where-Object {
    $_.DriverDate -and
    [Management.ManagementDateTimeConverter]::ToDateTime($_.DriverDate) -gt $cutoff
} | Sort-Object DriverDate -Descending

if ($recentDrivers) {
    $recentDrivers | Select-Object DeviceName,
        @{N='DriverDate';E={[Management.ManagementDateTimeConverter]::ToDateTime($_.DriverDate).ToString('yyyy-MM-dd')}},
        DriverVersion, Manufacturer | Format-Table -AutoSize
} else {
    Write-Host "No drivers installed or updated in the last 30 days."
}
#endregion

#region Section 5: Display Driver (WDDM)
Write-Host "$sep`n SECTION 5 - Display Driver and WDDM Status`n$sep"

Get-CimInstance Win32_VideoController | ForEach-Object {
    [PSCustomObject]@{
        Name             = $_.Name
        DriverVersion    = $_.DriverVersion
        DriverDate       = $_.DriverDate
        Status           = $_.Status
        VRAM_MB          = [math]::Round($_.AdapterRAM/1MB, 0)
        CurrentRefreshHz = $_.CurrentRefreshRate
        VideoProcessor   = $_.VideoProcessor
        VideoMode        = $_.VideoModeDescription
    }
} | Format-List

# Check for TDR events (GPU timeout/reset)
Write-Host "Recent GPU TDR Events (Event ID 4101):"
Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Id        = 4101
    StartTime = (Get-Date).AddDays(-7)
} -ErrorAction SilentlyContinue | Select-Object -First 10 TimeCreated, Message |
    Format-Table -AutoSize
#endregion

#region Section 6: Driver Error Events
Write-Host "$sep`n SECTION 6 - Driver Error Events (Last 7 Days)`n$sep"

$driverErrors = Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Level     = 2  # Error
    StartTime = (Get-Date).AddDays(-7)
} -ErrorAction SilentlyContinue | Where-Object { $_.ProviderName -match 'disk|driver|pnp|ACPI|volmgr|storahci|nvlddmkm' }

if ($driverErrors) {
    $driverErrors | Select-Object -First 20 TimeCreated, ProviderName, Id,
        @{N='Message';E={$_.Message.Substring(0,[Math]::Min(100,$_.Message.Length))}} |
        Format-Table -AutoSize
} else {
    Write-Host "No driver-related errors in System log in the last 7 days."
}

# pnputil driver store summary
Write-Host "`nDriver Store Package Count:"
$pnpOutput = pnputil /enum-drivers 2>&1
$pkgCount  = ($pnpOutput | Select-String 'Published Name').Count
Write-Host "  Total packages in driver store: $pkgCount"
#endregion

Write-Host "`n$sep`n Driver Health Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
