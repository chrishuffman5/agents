<#
.SYNOPSIS
    Windows Client - System Information Dashboard
.DESCRIPTION
    Comprehensive system identity overview including OS build, edition,
    hardware summary, TPM/Secure Boot status, activation, domain/Entra ID
    join status, and Intune enrollment. Provides a single-pane snapshot
    of device identity and configuration state.
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. OS Identity and Build
        2. Hardware Summary (CPU/RAM/Disk/GPU)
        3. TPM and Secure Boot
        4. Activation Status
        5. Domain / Workgroup / Entra ID Status
        6. Intune Enrollment Status
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region Section 1: OS Identity and Build
Write-Host "`n$sep`n SECTION 1 - OS Identity and Build`n$sep"

$os   = Get-CimInstance Win32_OperatingSystem
$cs   = Get-CimInstance Win32_ComputerSystem
$regCV = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue

[PSCustomObject]@{
    ComputerName     = $env:COMPUTERNAME
    OSCaption        = $os.Caption
    Edition          = $regCV.EditionID
    Version          = $regCV.DisplayVersion     # e.g., 23H2
    BuildNumber      = $os.BuildNumber
    UBR              = $regCV.UBR                # Update Build Revision
    FullBuild        = "$($os.BuildNumber).$($regCV.UBR)"
    OSArchitecture   = $os.OSArchitecture
    InstallDate      = $os.InstallDate
    LastBoot         = $os.LastBootUpTime
    UptimeDays       = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 1)
} | Format-List
#endregion

#region Section 2: Hardware Summary
Write-Host "$sep`n SECTION 2 - Hardware Summary`n$sep"

$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$disk = Get-CimInstance Win32_DiskDrive

[PSCustomObject]@{
    Manufacturer         = $cs.Manufacturer
    Model                = $cs.Model
    CPU                  = $cpu.Name
    Cores                = $cpu.NumberOfCores
    LogicalProcessors    = $cpu.NumberOfLogicalProcessors
    RAM_GB               = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    SystemType           = $cs.SystemType
} | Format-List

Write-Host "Disk Drives:"
$disk | Select-Object Model, @{N='Size_GB';E={[math]::Round($_.Size/1GB,0)}}, MediaType, InterfaceType |
    Format-Table -AutoSize

Write-Host "Logical Volumes:"
Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel,
    FileSystem, @{N='Size_GB';E={[math]::Round($_.Size/1GB,1)}},
    @{N='Free_GB';E={[math]::Round($_.SizeRemaining/1GB,1)}},
    @{N='Free_Pct';E={[math]::Round($_.SizeRemaining/$_.Size*100,0)}} |
    Format-Table -AutoSize

Write-Host "GPU(s):"
Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion,
    @{N='VRAM_MB';E={[math]::Round($_.AdapterRAM/1MB,0)}}, VideoModeDescription |
    Format-Table -AutoSize
#endregion

#region Section 3: TPM and Secure Boot
Write-Host "$sep`n SECTION 3 - TPM and Secure Boot`n$sep"

try {
    $tpm = Get-Tpm -ErrorAction Stop
    [PSCustomObject]@{
        TpmPresent       = $tpm.TpmPresent
        TpmReady         = $tpm.TpmReady
        TpmEnabled       = $tpm.TpmEnabled
        TpmActivated     = $tpm.TpmActivated
        ManufacturerId   = $tpm.ManufacturerId
        TpmVersion       = $tpm.ManufacturerIdTxt
        SpecVersion      = $tpm.SpecVersion
    } | Format-List
} catch {
    Write-Warning "TPM cmdlet not available: $($_.Exception.Message)"
    $tpmReg = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\TPM\WMI' -ErrorAction SilentlyContinue
    Write-Host "TPM registry state: $($tpmReg | Out-String)"
}

$secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
Write-Host "Secure Boot Enabled: $secureBoot"
#endregion

#region Section 4: Activation Status
Write-Host "$sep`n SECTION 4 - Activation Status`n$sep"

$slmgr = cscript //nologo C:\Windows\System32\slmgr.vbs /dli 2>&1
$slmgr | Select-String -Pattern 'License Status|Product Name|Partial Product Key' |
    ForEach-Object { Write-Host $_.Line }
#endregion

#region Section 5: Domain / Workgroup / Entra ID Status
Write-Host "$sep`n SECTION 5 - Domain / Entra ID Status`n$sep"

[PSCustomObject]@{
    Domain           = $cs.Domain
    DomainRole       = switch ($cs.DomainRole) {
                           0 {'Standalone Workstation'}
                           1 {'Member Workstation'}
                           2 {'Standalone Server'}
                           3 {'Member Server'}
                           4 {'Backup DC'} 5 {'Primary DC'}
                       }
    PartOfDomain     = $cs.PartOfDomain
    Workgroup        = if (-not $cs.PartOfDomain) { $cs.Workgroup } else { 'N/A' }
} | Format-List

# Entra ID (Azure AD) join status
$dsreg = dsregcmd /status 2>&1
$dsreg | Select-String -Pattern 'AzureAdJoined|DomainJoined|WorkplaceJoined|TenantName|DeviceAuthStatus' |
    ForEach-Object { Write-Host "  $($_.Line.Trim())" }
#endregion

#region Section 6: Intune Enrollment
Write-Host "$sep`n SECTION 6 - Intune Enrollment Status`n$sep"

$mdmReg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Enrollments\*' -ErrorAction SilentlyContinue
if ($mdmReg) {
    $mdmReg | Where-Object { $_.ProviderID -like '*Intune*' -or $_.EnrollmentType } |
        Select-Object PSChildName, ProviderID, EnrollmentType, UPN |
        Format-Table -AutoSize
} else {
    Write-Host "No MDM enrollment records found."
}

# Check MDM enrollment via dsregcmd
$dsreg | Select-String -Pattern 'MDMUrl|IsEnrolled|MdmDeviceID' |
    ForEach-Object { Write-Host "  $($_.Line.Trim())" }
#endregion

Write-Host "`n$sep`n System Info Complete - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n$sep`n"
