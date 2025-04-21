<#
.SYNOPSIS
    Check and record IP address changes.
.DESCRIPTION
    Check current system IP configuration, compare with historical records and log changes.
    Supported features:
    - Silent running (suitable for scheduled tasks)
    - Display current IP information
    - Show IP change status
    - Log to Windows Event Log
.PARAMETER ShowCurrent
    Display current detected IP address information.
.PARAMETER ShowChange
    Display whether IP address has changed and show latest record information.
.PARAMETER Silent
    Run in silent mode without any output. Suitable for scheduled task scenarios.
.EXAMPLE
    Test-IPChange
    Check IP changes and update log. Typically no output is displayed.
.EXAMPLE
    Test-IPChange -ShowCurrent
    Display current IP information and update log.
.EXAMPLE
    Test-IPChange -ShowChange
    Check IP changes, display change status and latest record.
.EXAMPLE
    Test-IPChange -ShowCurrent -ShowChange
    Display both current IP and change status.
.OUTPUTS
    System.Boolean
    Returns True if IP changed, False if unchanged.
.NOTES
    External log file location: $Env:OneDrive\ip_log.json
    System log name: Application
    System log source: IPCheck
    System log EventID: 1001
    Event log source can be created if it is not detected. This requires administrator privileges.
#>
function Test-IPChange {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ShowCurrent,
        [Parameter()]
        [switch]$ShowChange,
        [Parameter()]
        [switch]$Silent
    )

    # Error handling preferences
    if ($Silent -or (-not ($ShowCurrent -or $ShowChange))) {
        $ErrorActionPreference = 'SilentlyContinue'
        $ProgressPreference    = 'SilentlyContinue'
        $InformationPreference = 'SilentlyContinue'
        $VerbosePreference     = 'SilentlyContinue'
        $DebugPreference       = 'SilentlyContinue'
        $WarningPreference     = 'SilentlyContinue'
    }

    # Check system event log
    if (-not [System.Diagnostics.EventLog]::SourceExists("IPCheck")) {
        try {
            New-EventLog -LogName Application -Source "IPCheck" -ErrorAction Stop
        }
        catch {
            # Silently fail if no admin privileges
            Write-Debug "Unable to create event log source: $_"
        }
    }

    $LogFile = "$Env:OneDrive\ip_log.json"
    $LogDir = Split-Path $LogFile -Parent

    # Check external text log
    if (-not (Test-Path $LogDir)) {
        try {
            New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction Stop | Out-Null
        }
        catch {
            $errorMessage = "Unable to create log directory: $_"
            Write-EventLog -LogName "Application" -Source "IPCheck" -EventId 1001 -EntryType Error -Message $errorMessage -ErrorAction SilentlyContinue
            throw $errorMessage
        }
    }

    try {
        $CurrentIPInfo = Get-NetIPAddress |
        Where-Object { $_.AddressFamily -in ('IPv4', 'IPv6') -and $_.IPAddress -notmatch '^(fe80|::1|127\.)' } |
        Select-Object @{
            Name       = 'Interface'
            Expression = { (Get-NetAdapter -InterfaceIndex $_.InterfaceIndex).Name }
        }, IPAddress

        # Only display current IP in non-silent mode
        if ($ShowCurrent -and -not $Silent) {
            Write-Host "`n================== Current IP Info ==================" -ForegroundColor Cyan
            Format-IPInfo -IPInfo $CurrentIPInfo
            Write-Host "=====================================================" -ForegroundColor Cyan
        }

        $isChanged = Update-IPLog -CurrentIPInfo $CurrentIPInfo -LogFile $LogFile
        
        # Only display change information in non-silent mode
        if ($ShowChange -and -not $Silent) {
            if ($isChanged) {
                Write-Host "`nIP Address Updated!" -ForegroundColor Magenta
            }
            else {
                Write-Host "`nIP Address Unchanged." -ForegroundColor Cyan
            }
            Show-LatestIPLog
        }

        return $isChanged
    }
    catch {
        $errorMessage = "IP check execution error: $_"
        Write-EventLog -LogName "Application" -Source "IPCheck" -EventId 1001 -EntryType Error -Message $errorMessage -ErrorAction SilentlyContinue
        if (-not $Silent) {
            Write-Error $errorMessage
        }
        return $false
    }
}