<#
.SYNOPSIS
    获取指定虚拟机的IP地址。
.DESCRIPTION
    获取Hyper-V虚拟机的所有IPv4地址，排除链路本地地址。
.PARAMETER VMName
    虚拟机的名称。
.EXAMPLE
    Get-VMIPAddress -VMName "Ubuntu-VM"
    获取名为"Ubuntu-VM"的虚拟机的IP地址。
.OUTPUTS
    System.String[]
    返回虚拟机的IP地址列表。
.NOTES
    需要Hyper-V管理员权限。
#>
function Get-VMIPAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VMName
    )

    try {
        Get-VM -Name $VMName -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "未找到名为 '$VMName' 的虚拟机。请确认虚拟机名称是否正确。"
        return
    }

    $vmNetworkAdapters = Get-VMNetworkAdapter -VMName $VMName
    $ipAddresses = @()

    foreach ($adapter in $vmNetworkAdapters) {
        $adapter.IPAddresses | Where-Object { $_ -and $_ -notlike "fe80*" } | ForEach-Object {
            $ipAddresses += $_
        }
    }

    if ($ipAddresses.Count -eq 0) {
        Write-Error "虚拟机 '$VMName' 当前没有可用的 IP 地址。可能是虚拟机尚未启动或尚未获得 IP。"
    }
    else {
        return $ipAddresses
    }
}