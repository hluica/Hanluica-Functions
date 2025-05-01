<#
.SYNOPSIS
    Get IP addresses of the specified virtual machine.
.DESCRIPTION
    Retrieves all IPv4 addresses of a Hyper-V virtual machine, excluding link-local addresses.
.PARAMETER VMName
    Name of the virtual machine.
.EXAMPLE
    Get-VMIPAddress -VMName "Ubuntu-VM"
    Gets IP addresses of the virtual machine named "Ubuntu-VM".
.OUTPUTS
    System.String[]
    Returns a list of IP addresses for the virtual machine.
.NOTES
    Requires Hyper-V Administrator privileges.
.LINK
    https://github.com/Hanluica-Functions
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
        Write-Error "Virtual machine '$VMName' not found. Please verify the virtual machine name."
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
        Write-Error "No IP addresses available for virtual machine '$VMName'. The VM may not be running or hasn't obtained an IP yet."
    }
    else {
        return $ipAddresses
    }
}