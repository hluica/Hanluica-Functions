function Format-IPInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object[]]$IPInfo
    )

    $table = @()
    foreach ($ip in $IPInfo) {
        $interface = if ([string]::IsNullOrEmpty($ip.Interface)) { "<未知接口>" } else { $ip.Interface }
        $table += [PSCustomObject]@{
            "网络接口" = $interface
            "IP地址" = $ip.IPAddress
        }
    }

    # Set interface sort order priority
    $sortOrder = @{
        'WLAN' = 1
        '以太网' = 2
        'vEthernet (Default Switch)' = 3
        '<未知接口>' = 5
    }

    $table | Sort-Object {
        $interface = $_.'网络接口'
        if ($sortOrder.ContainsKey($interface)) {
            $sortOrder[$interface]
        }
        else {
            4  # Default sort value for other known interfaces
        }
    } | Format-Table -AutoSize
}