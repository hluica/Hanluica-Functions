<#
.SYNOPSIS
    检查并记录IP地址变化。
.DESCRIPTION
    检查当前系统的IP地址配置，与历史记录比较并记录变化。
    支持以下功能：
    - 静默运行（适用于计划任务）
    - 显示当前IP信息
    - 显示IP变化状态
    - 记录到Windows事件日志
.PARAMETER ShowCurrent
    显示当前检测到的IP地址信息。
.PARAMETER ShowChange
    显示IP地址是否发生变化，并显示最新的记录信息。
.PARAMETER Silent
    静默模式运行，不显示任何输出。适用于计划任务场景。
.EXAMPLE
    Test-IPChange
    检查IP变化并更新日志。通常情况下，该命令不会显示任何输出。
.EXAMPLE
    Test-IPChange -ShowCurrent
    显示当前IP信息，并更新日志。
.EXAMPLE
    Test-IPChange -ShowChange
    检查IP变化，显示变化状态和最新记录。
.EXAMPLE
    Test-IPChange -ShowCurrent -ShowChange
    同时显示当前IP和变化状态。
.OUTPUTS
    System.Boolean
    返回True表示IP发生变化，False表示未变化。
.NOTES
    外部日志文件位置：$Env:OneDrive\ip_log.json
    系统日志名称：Application；
    系统日志源：IPCheck
    系统日志EventID：1001
    当未检测到事件日志时，可以创建事件日志，但需要管理员权限。
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

    # 错误处理首选项
    if ($Silent -or (-not ($ShowCurrent -or $ShowChange))) {
        $ErrorActionPreference = 'SilentlyContinue'
        $ProgressPreference    = 'SilentlyContinue'
        $InformationPreference = 'SilentlyContinue'
        $VerbosePreference     = 'SilentlyContinue'
        $DebugPreference       = 'SilentlyContinue'
        $WarningPreference     = 'SilentlyContinue'
    }

    # 检查系统事件日志
    if (-not [System.Diagnostics.EventLog]::SourceExists("IPCheck")) {
        try {
            New-EventLog -LogName Application -Source "IPCheck" -ErrorAction Stop
        }
        catch {
            # 如果没有管理员权限，静默失败
            Write-Debug "无法创建事件日志源：$_"
        }
    }

    $LogFile = "$Env:OneDrive\ip_log.json"
    $LogDir = Split-Path $LogFile -Parent

    # 检查外部文本日志
    if (-not (Test-Path $LogDir)) {
        try {
            New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction Stop | Out-Null
        }
        catch {
            $errorMessage = "无法创建日志目录：$_"
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

        # 仅在非静默模式下显示当前IP
        if ($ShowCurrent -and -not $Silent) {
            Write-Host "`n================== 当前IP信息 ==================" -ForegroundColor Cyan
            Format-IPInfo -IPInfo $CurrentIPInfo
            Write-Host "================================================" -ForegroundColor Cyan
        }

        $isChanged = Update-IPLog -CurrentIPInfo $CurrentIPInfo -LogFile $LogFile
        
        # 仅在非静默模式下显示变更信息
        if ($ShowChange -and -not $Silent) {
            if ($isChanged) {
                Write-Host "`nIP地址已更新！" -ForegroundColor Magenta
            }
            else {
                Write-Host "`nIP地址未发生变化。" -ForegroundColor Cyan
            }
            Show-LatestIPLog
        }

        return $isChanged
    }
    catch {
        $errorMessage = "IP检查执行错误：$_"
        Write-EventLog -LogName "Application" -Source "IPCheck" -EventId 1001 -EntryType Error -Message $errorMessage -ErrorAction SilentlyContinue
        if (-not $Silent) {
            Write-Error $errorMessage
        }
        return $false
    }
}