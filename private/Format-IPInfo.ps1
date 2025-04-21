function Format-IPInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object[]]$IPInfo
    )

    $table = @()
    foreach ($ip in $IPInfo) {
        $interface = if ([string]::IsNullOrEmpty($ip.Interface)) { "<Unknown Interface>" } else { $ip.Interface }
        $table += [PSCustomObject]@{
            "Interface" = $interface
            "IPAddress" = $ip.IPAddress
        }
    }

    # Set interface sort order priority
    $sortOrder = @{
        'WLAN' = 1
        '以太网' = 2
        'vEthernet (Default Switch)' = 3
        '<Unknown Interface>' = 5
    }

    $table | Sort-Object {
        $interface = $_.'Interface'
        if ($sortOrder.ContainsKey($interface)) {
            $sortOrder[$interface]
        }
        else {
            4  # Default sort value for other known interfaces
        }
    } | Format-Table -AutoSize
}