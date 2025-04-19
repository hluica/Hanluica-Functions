function Update-IPLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object[]]$CurrentIPInfo,
        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # 读取历史记录
    if (Test-Path $LogFile) {
        $LogHistory = Get-Content $LogFile -Raw | ConvertFrom-Json
        if ($LogHistory -isnot [Array]) { $LogHistory = @($LogHistory) }
    }
    else {
        $LogHistory = @()
    }

    # 比较IP变化
    $LastIPInfo = if ($LogHistory.Count -gt 0) { $LogHistory[0].IPInfo } else { @() }
    $CurrentIPString = ($CurrentIPInfo | ConvertTo-Json)
    $LastIPString = ($LastIPInfo | ConvertTo-Json)
    
    if ($CurrentIPString -ne $LastIPString) {
        # 创建新记录
        $NewEntry = @{
            TimeStamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            IPInfo    = $CurrentIPInfo
        }
        
        # 更新日志
        $LogHistory = @($NewEntry) + $LogHistory
        if ($LogHistory.Count -gt 100) {
            $LogHistory = $LogHistory | Select-Object -First 100
        }
        $LogHistory | ConvertTo-Json -Depth 10 | Set-Content -Path $LogFile -Encoding UTF8
        return $true
    }
    return $false
}