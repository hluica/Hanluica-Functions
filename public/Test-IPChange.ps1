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
    System log name   : Application
    System log source : IPCheck
    System log EventID: 1001
    Event log source can be created if it is not detected. This requires administrator privileges.
.LINK
    https://github.com/Hanluica-Functions
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

    try {
        $monitor = [IPMonitor]::new()
        return $monitor.CheckAndRecordIPChange($ShowCurrent, $ShowChange, $Silent)
    }
    catch {
        # If IPMonitor constructor fails (e.g., can't create log directory), this catch handles it.
        # The constructor itself will attempt to write to event log.
        # We might want to Write-Error here if not in silent mode.
        if (-not $Silent) {
            Write-Error "Failed to initialize IP Monitor for Test-IPChange: $_"
        }
        return $false # Indicate failure
    }
}
