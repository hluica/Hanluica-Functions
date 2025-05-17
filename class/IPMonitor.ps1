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
    static [string] $DEFAULT_ERROR_ACTION        = 'Continue'
    static [string] $DEFAULT_PROGRESS_PREFERENCE = 'Continue'
    static [string] $DEFAULT_WARNING_PREFERENCE  = 'Continue'
    static [string] $SILENT_PREFERENCE           = 'SilentlyContinue'
    #endregion Properties

    #region Constructor
    IPMonitor() {
        $this.LogFile = "$Env:OneDrive\ip_log.json"
        $this.EventLogSource = "IPCheck"
        $this.EventLogName = "Application"
        $this.MaxLogEntries = 100
        $this.InterfaceSortOrder = @{
            'WLAN'                       = 1
            '以太网'                     = 2 # the display language of my system is Chinese, so I have to use Chinese name in which powershell can recognize the adapter.
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
        # Get the names' list of network adapters
        $adapterMap = @{}
        Get-NetAdapter | ForEach-Object {
            $adapterMap[$_.InterfaceIndex] = $_.Name
        }

        # Get the list of IP addresses
        $validIPs = Get-NetIPAddress | Where-Object {
            $_.AddressFamily -in ('IPv4', 'IPv6') -and
            $_.IPAddress -notmatch '^(fe80|::1|127\.)'
        }

        # Map IP addresses to their respective interfaces, leave unknowns as "<Unknown Interface>"
        $ipDetails = $validIPs | ForEach-Object {
            $interfaceName = $adapterMap[$_.InterfaceIndex] ?? "<Unknown Interface>"
            [IPAddressDetail]::new($interfaceName, $_.IPAddress)
        }

        return $ipDetails
    }

    hidden [IPAddressDetail[]] ConvertToIPDetails($ipInfoArray) {
        return (
            $ipInfoArray |
            ForEach-Object {
                [IPAddressDetail]::new($_.Interface, $_.IPAddress)
            }
        )
    }

    hidden [array] ConvertToSerializableHistory([IPLogRecord[]]$LogHistory) {
        $serializedRecords = foreach ($record in $LogHistory) {
            $serializedIPInfo = foreach ($ip in $record.IPInfo) {
                @{
                    Interface = $ip.Interface
                    IPAddress = $ip.IPAddress
                }
            }

            @{
                TimeStamp = $record.TimeStamp
                IPInfo = $serializedIPInfo
            }
        }

        return $serializedRecords
    }

    hidden [IPLogRecord[]] ReadLogHistory() {
        if (-not (Test-Path $this.LogFile)) { # Unable to get log file. Assuming empty history.
            return @()
        }

        try {
            $logData = Get-Content $this.LogFile -Raw | ConvertFrom-Json
            # Empty history case
            if (-not $logData) {
                return @()
            }
            # Single record case
            if ($logData -isnot [array]) {
                $ipDetails = $this.ConvertToIPDetails($logData.IPInfo)
                return @([IPLogRecord]::new($logData.TimeStamp, $ipDetails))
            }
            # Multiple records case
            return (
                $logData |
                ForEach-Object {
                    $ipDetails = $this.ConvertToIPDetails($_.IPInfo)
                    [IPLogRecord]::new($_.TimeStamp, $ipDetails)
                }
            )
        }
        catch {
            Write-Warning "Failed to read or parse log file '$($this.LogFile)': $_. `nAssuming empty history."
            return @()
        }
    }

    hidden [void] WriteLogHistory([IPLogRecord[]]$LogHistory) {
        $serializableHistory = $this.ConvertToSerializableHistory($LogHistory)

        try {
            ConvertTo-Json -InputObject $serializableHistory -Depth 10 |
            Set-Content -Path $this.LogFile -Encoding UTF8
        }
        catch {
            $errorMessage = "Failed to write log history: $_"
            $this.WriteToEventLog($errorMessage, 'Error')
            throw $errorMessage
        }
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