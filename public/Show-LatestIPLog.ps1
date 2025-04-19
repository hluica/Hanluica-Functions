<#
.SYNOPSIS
    显示最新的IP地址记录信息。
.DESCRIPTION
    从JSON日志文件中读取并显示最新的IP地址记录，包括记录时间和各网络接口的IP地址信息。
    显示内容包括：
    - 记录的时间戳
    - 距离现在的时间差
    - 所有网络接口的IP地址（按接口类型排序）
.EXAMPLE
    Show-LatestIPLog
    显示最新记录的IP信息和时间信息。
.NOTES
    日志文件位置：$Env:OneDrive\ip_log.json
    网络接口显示优先级：
    1. WLAN
    2. 以太网
    3. vEthernet (Default Switch)
    4. 其他接口
    5. 未知接口
#>
function Show-LatestIPLog {
    $logPath = "$Env:OneDrive\ip_log.json"

    try {
        $logContent = Get-Content -Path $logPath -Raw | ConvertFrom-Json
        $latestLog = $logContent[0]
        $logTime = [DateTime]::ParseExact($latestLog.TimeStamp, "yyyy-MM-dd HH:mm:ss", $null)
        $timeDiff = (Get-Date) - $logTime
        
        Write-Host "`n=================== 时间信息 ===================" -ForegroundColor Cyan
        Write-Host "记录时间: $($latestLog.TimeStamp)"
        Write-Host "距离现在: $([math]::Floor($timeDiff.TotalHours))小时 $($timeDiff.Minutes)分钟"
        
        Write-Host "`n================= 网络接口信息 =================" -ForegroundColor Cyan
        Format-IPInfo -IPInfo $latestLog.IPInfo
        Write-Host "================================================" -ForegroundColor Cyan
    }
    catch {
        Write-Error "读取或处理IP日志时发生错误: $_"
    }
}