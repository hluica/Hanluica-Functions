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
    $logPath = "$Env:OneDrive\ip_log.json"

    try {
        $logContent = Get-Content -Path $logPath -Raw | ConvertFrom-Json
        $latestLog = $logContent[0]
        $logTime = [DateTime]::ParseExact($latestLog.TimeStamp, "yyyy-MM-dd HH:mm:ss", $null)
        $timeDiff = (Get-Date) - $logTime
        
        Write-Host "`n===================== Time Information =====================" -ForegroundColor Cyan
        Write-Host "Record Time: $($latestLog.TimeStamp)"
        Write-Host "Time Since: $([math]::Floor($timeDiff.TotalHours)) h $($timeDiff.Minutes) min"
        
        Write-Host "`n================== Network Interface Info ==================" -ForegroundColor Cyan
        Format-IPInfo -IPInfo $latestLog.IPInfo
        Write-Host "============================================================" -ForegroundColor Cyan
    }
    catch {
        Write-Error "Error occurred while reading or processing IP log: $_"
    }
}