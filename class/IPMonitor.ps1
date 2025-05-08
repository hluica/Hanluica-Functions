#region Data Classes
class IPAddressDetail {
    [string]$Interface
    [string]$IPAddress

    IPAddressDetail([string]$Interface, [string]$IPAddress) {
        $this.Interface = $Interface
        $this.IPAddress = $IPAddress
    }
}

class IPLogRecord {
    [string]$TimeStamp
    [IPAddressDetail[]]$IPInfo

    IPLogRecord([string]$TimeStamp, [IPAddressDetail[]]$IPInfo) {
        $this.TimeStamp = $TimeStamp
        $this.IPInfo = $IPInfo
    }
}
#endregion Data Classes

#region Main Class
class IPMonitor {
    #region Properties
    [string]    $LogFile
    [string]    $EventLogSource
    [string]    $EventLogName
    [int]       $MaxLogEntries
    [hashtable] $InterfaceSortOrder
    static [string] $DEFAULT_ERROR_ACTION = 'Continue'
    static [string] $DEFAULT_PROGRESS_PREFERENCE = 'Continue'
    static [string] $DEFAULT_WARNING_PREFERENCE = 'Continue'
    static [string] $SILENT_PREFERENCE = 'SilentlyContinue'
    #endregion Properties

    #region Constructor
    IPMonitor() {
        $this.LogFile = "$Env:OneDrive\ip_log.json"
        $this.EventLogSource = "IPCheck"
        $this.EventLogName = "Application"
        $this.MaxLogEntries = 100
        $this.InterfaceSortOrder = @{
            'WLAN'                       = 1
            'Ethernet'                   = 2
            'vEthernet (Default Switch)' = 3
            '<Unknown Interface>'        = 5
        }

        # Ensure Event Log source exists
        $this._EnsureEventLogSource()

        # Ensure Log Directory exists
        $this._EnsureLogDirectory()
    }
    #endregion Constructor

    #region Private Helper Methods
    hidden [void] _EnsureEventLogSource() {
        if (-not [System.Diagnostics.EventLog]::SourceExists($this.EventLogSource)) {
            try {
                New-EventLog -LogName $this.EventLogName -Source $this.EventLogSource -ErrorAction Stop
            }
            catch {
                # Silently fail if no admin privileges, debug message for developers
                Write-Debug "Unable to create event log source '$($this.EventLogSource)': $_"
            }
        }
    }

    hidden [void] _EnsureLogDirectory() {
        $LogDir = Split-Path $this.LogFile -Parent
        if (-not (Test-Path $LogDir)) {
            try {
                New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction Stop | Out-Null
            }
            catch {
                $errorMessage = "Unable to create log directory '$LogDir': $_"
                $this.WriteToEventLog($errorMessage, 'Error')
                throw $errorMessage # Re-throw for constructor failure
            }
        }
    }

    hidden [void] WriteToEventLog([string]$Message, [string]$EntryType = 'Error') {
        # Ensure source exists before attempting to write, though constructor should handle it.
        if ([System.Diagnostics.EventLog]::SourceExists($this.EventLogSource)) {
            try {
                Write-EventLog -LogName $this.EventLogName -Source $this.EventLogSource -EventId 1001 -EntryType $EntryType -Message $Message -ErrorAction SilentlyContinue
            }
            catch {
                Write-Debug "Failed to write to event log: $_"
            }
        }
        else {
            Write-Debug "Event log source '$($this.EventLogSource)' does not exist. Cannot write message: $Message"
        }
    }

    hidden [IPAddressDetail[]] GetCurrentSystemIPInfo() {
        $currentIPs = Get-NetIPAddress |
        Where-Object { $_.AddressFamily -in ('IPv4', 'IPv6') -and $_.IPAddress -notmatch '^(fe80|::1|127\.)' } |
        Select-Object @{
            Name       = 'Interface'
            Expression = {
                $adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
                if ($adapter) { $adapter.Name } else { "<Unknown Interface>" }
            }
        }, IPAddress | ForEach-Object {
            [IPAddressDetail]::new($_.Interface, $_.IPAddress)
        }
        return $currentIPs
    }

    hidden [IPLogRecord[]] ReadLogHistory() {
        if (Test-Path $this.LogFile) {
            try {
                $logData = Get-Content $this.LogFile -Raw | ConvertFrom-Json -ErrorAction Stop
                if ($logData -is [array]) {
                    # Convert plain objects from JSON back to IPLogRecord and IPAddressDetail
                    return ($logData | ForEach-Object {
                            $ipDetails = $_.IPInfo | ForEach-Object { [IPAddressDetail]::new($_.Interface, $_.IPAddress) }
                            [IPLogRecord]::new($_.TimeStamp, $ipDetails)
                        })
                }
                elseif ($logData) {
                    $ipDetails = $logData.IPInfo | ForEach-Object { [IPAddressDetail]::new($_.Interface, $_.IPAddress) }
                    return @([IPLogRecord]::new($logData.TimeStamp, $ipDetails))
                }
            }
            catch {
                Write-Warning "Failed to read or parse log file '$($this.LogFile)': $_. Assuming empty history."
                # Optionally, attempt to backup corrupted log file here
            }
        }
        return @() # Return empty array if file doesn't exist or is invalid
    }

    hidden [void] WriteLogHistory([IPLogRecord[]]$LogHistory) {
        # Convert IPLogRecord objects to a structure that ConvertTo-Json handles well (PSCustomObject-like)
        $serializableHistory = $LogHistory | ForEach-Object {
            [PSCustomObject]@{
                TimeStamp = $_.TimeStamp
                IPInfo    = ($_.IPInfo | ForEach-Object { [PSCustomObject]@{ Interface = $_.Interface; IPAddress = $_.IPAddress } })
            }
        }
        $serializableHistory | ConvertTo-Json -Depth 10 | Set-Content -Path $this.LogFile -Encoding UTF8 -ErrorAction Stop
    }
    #endregion Private Helper Methods

    #region Public Methods
    [void] FormatIPInfoForDisplay([IPAddressDetail[]]$IPInfo) {
        $table = @()
        foreach ($ip in $IPInfo) {
            $interfaceName = if ([string]::IsNullOrEmpty($ip.Interface)) { "<Unknown Interface>" } else { $ip.Interface }
            $table += [PSCustomObject]@{
                "Interface" = $interfaceName
                "IPAddress" = $ip.IPAddress
            }
        }

        $tableToShow = (
            $table |
            Sort-Object {
                $interface = $_.'Interface'
                if ($this.InterfaceSortOrder.ContainsKey($interface)) {
                    $this.InterfaceSortOrder[$interface]
                }
                else {
                    4  # Default sort value for other known interfaces
                }
            } |
            Format-Table -AutoSize |
            Out-String
        )
        Write-Host $tableToShow
    }

    [bool] UpdateIPLog([IPAddressDetail[]]$CurrentIPInfo) {
        $logHistory = $this.ReadLogHistory()

        $lastIPInfo = if ($logHistory.Count -gt 0) { $logHistory[0].IPInfo } else { @() }

        # For comparison, convert to JSON string as it's a reliable way to compare complex objects for equality
        # Ensure consistent property order for JSON conversion if direct object comparison is tricky
        $currentIPJson = ($CurrentIPInfo | Sort-Object Interface, IPAddress | ConvertTo-Json -Compress)
        $lastIPJson = ($lastIPInfo | Sort-Object Interface, IPAddress | ConvertTo-Json -Compress)

        if ($currentIPJson -ne $lastIPJson) {
            $newEntry = [IPLogRecord]::new(
                (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"),
                $CurrentIPInfo
            )
            
            $updatedLogHistory = @($newEntry) + $logHistory
            if ($updatedLogHistory.Count -gt $this.MaxLogEntries) {
                $updatedLogHistory = $updatedLogHistory | Select-Object -First $this.MaxLogEntries
            }
            
            try {
                $this.WriteLogHistory($updatedLogHistory)
                return $true
            }
            catch {
                $errorMessage = "Failed to write updated IP log: $_"
                $this.WriteToEventLog($errorMessage, 'Error')
                # Depending on severity, you might want to throw here or just return $false
                Write-Warning $errorMessage
                return $false
            }
        }
        return $false
    }

    [void] ShowLatestIPLogInfo() {
        try {
            $logHistory = $this.ReadLogHistory()
            if ($logHistory.Count -eq 0) {
                Write-Host "No IP log entries found in '$($this.LogFile)'." -ForegroundColor Yellow
                return
            }

            $latestLog = $logHistory[0]
            $logTime = [DateTime]::ParseExact($latestLog.TimeStamp, "yyyy-MM-dd HH:mm:ss", $null)
            $timeDiff = (Get-Date) - $logTime
            
            Write-Host "`n===================== Time Information =====================`n" -ForegroundColor Green
            Write-Host "Record Time: $($latestLog.TimeStamp)" -ForegroundColor Yellow
            Write-Host "Time Since : $([math]::Floor($timeDiff.TotalHours)) h $($timeDiff.Minutes) min" -ForegroundColor Yellow
            
            Write-Host "`n================== Network Interface Info ==================" -ForegroundColor Green
            $this.FormatIPInfoForDisplay($latestLog.IPInfo)
            Write-Host "============================================================" -ForegroundColor Green
        }
        catch {
            $errorMessage = "Error occurred while reading or processing IP log for display: $_"
            $this.WriteToEventLog($errorMessage, 'Error')
            Write-Error $errorMessage
        }
    }

    [bool] CheckAndRecordIPChange([switch]$ShowCurrent, [switch]$ShowChange, [switch]$Silent) {
        if ($Silent) {
            $ErrorActionPreference = [IPMonitor]::SILENT_PREFERENCE
            $ProgressPreference = [IPMonitor]::SILENT_PREFERENCE
            $WarningPreference = [IPMonitor]::SILENT_PREFERENCE
        }

        try {
            $currentSystemIPs = $this.GetCurrentSystemIPInfo()

            if ($ShowCurrent -and -not $Silent) {
                Write-Host "`n================== Current IP Info ==================" -ForegroundColor Cyan
                $this.FormatIPInfoForDisplay($currentSystemIPs)
                Write-Host "=====================================================" -ForegroundColor Cyan
            }

            $isChanged = $this.UpdateIPLog($currentSystemIPs)
            
            if ($ShowChange -and -not $Silent) {
                if ($isChanged) {
                    Write-Host "`nIP Address Updated!" -ForegroundColor Magenta
                }
                else {
                    Write-Host "`nIP Address Unchanged." -ForegroundColor Blue
                }
                $this.ShowLatestIPLogInfo()
            }
            return $isChanged
        }
        catch {
            $errorMessage = "IP check execution error: $_"
            $this.WriteToEventLog($errorMessage, 'Error')
            if (-not $Silent) {
                Write-Error $errorMessage
            }
            return $false # Indicate failure or no change due to error
        }
        finally {
            if ($Silent) {
                # Reset preferences to defaults after silent run
                $ErrorActionPreference = [IPMonitor]::DEFAULT_ERROR_ACTION
                $ProgressPreference = [IPMonitor]::DEFAULT_PROGRESS_PREFERENCE
                $WarningPreference = [IPMonitor]::DEFAULT_WARNING_PREFERENCE
            }
        }
    }
    #endregion Public Methods
}
#endregion Main Class