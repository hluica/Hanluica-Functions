<#
.SYNOPSIS
    为虚拟机设置界面端口代理。
.DESCRIPTION
    使用netsh配置IPv6到IPv4的界面端口代理，将2233端口的流量转发到指定IP地址。
.PARAMETER IPAddress
    要设置端口代理的目标IP地址。可以是多个IP地址。
    该参数支持管道输入。
.PARAMETER Port
    要设置的端口号。必填，不设置默认值。
.EXAMPLE    
    Set-VMPortProxy -IPAddress "192.168.1.100" -Port 2233
    # 设置单个 IP 地址
.EXAMPLE 
    Set-VMPortProxy -IPAddress "192.168.1.100","192.168.1.101" -Port 8080
    # 设置多个 IP 地址
.EXAMPLE 
    Get-VMIPAddress -VMName "Ubuntu-VM" | Set-VMPortProxy -Port 2233
    # 通过管道传递 IP 地址
.NOTES
    - 需要管理员权限
    - 必须手动指定端口。
    - 支持管道输入。
    - 该函数配置的是 IPv6 到 IPv4 的端口代理，请确保存在可用的 IPv6 地址。
#>
function Set-VMPortProxy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$IPAddress,
        
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port
    )

    begin {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Write-Error "此函数需要管理员权限才能执行。请以管理员身份运行 PowerShell。"
            return
        }
    }

    process {
        foreach ($ip in $IPAddress) {
            try {
                $command = "netsh interface portproxy set v6tov4 listenport=$Port listenaddress=:: connectport=$Port connectaddress=$ip"
                Write-Verbose "执行命令: $command"
                Invoke-Expression $command | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "成功为 IP $ip 设置端口 $Port 的代理。" -ForegroundColor Green
                }
                else {
                    Write-Error "为 IP $ip 设置端口 $Port 的代理时失败。"
                }
            }
            catch {
                Write-Error "发生错误: $_"
            }
        }
    }
}