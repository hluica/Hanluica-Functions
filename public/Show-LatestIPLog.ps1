<#
.SYNOPSIS
    Display the latest IP address log information.
.DESCRIPTION
    Read and display the latest IP address records from JSON log file, including recording time and IP address information for each network interface.
    Display content includes:
    - Record timestamp
    - Time difference from now
    - IP addresses for all network interfaces (sorted by interface type)
.EXAMPLE
    Show-LatestIPLog
    Display the latest recorded IP information and time details.
.NOTES
    Log file location: $Env:OneDrive\ip_log.json
    Network interface display priority:
    1. WLAN
    2. Ethernet
    3. vEthernet (Default Switch)
    4. Other interfaces
    5. Unknown interfaces
.LINK
    https://github.com/Hanluica-Functions
#>
function Show-LatestIPLog {
    try {
        $monitor = [IPMonitor]::new()
        $monitor.ShowLatestIPLogInfo()
    }
    catch {
        Write-Error "Failed to initialize IP Monitor for Show-LatestIPLog: $_"
    }
}
