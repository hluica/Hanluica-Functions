<#
.SYNOPSIS
    Set interface port proxy for virtual machines.
.DESCRIPTION
    Configure IPv6 to IPv4 interface port proxy using netsh to forward traffic from the specified port to target IP addresses.
.PARAMETER IPAddress
    Target IP address(es) for port proxy configuration.
    This parameter supports pipeline input.
.PARAMETER Port
    Port number to configure. Required, no default value.
.EXAMPLE    
    Set-VMPortProxy -IPAddress "192.168.1.100" -Port 2233
    # Configure for a single IP address
.EXAMPLE 
    Set-VMPortProxy -IPAddress "192.168.1.100","192.168.1.101" -Port 8080
    # Configure for multiple IP addresses
.EXAMPLE 
    Get-VMIPAddress -VMName "Ubuntu-VM" | Set-VMPortProxy -Port 2233
    # Pass IP addresses through pipeline
.NOTES
    - Requires administrator privileges
    - Port must be manually specified
    - Supports pipeline input
    - This function configures IPv6 to IPv4 port proxy, ensure IPv6 address is available
.LINK
    https://github.com/Hanluica-Functions
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
            Write-Error "This function requires administrator privileges. Please run PowerShell as administrator."
            return
        }
    }

    process {
        foreach ($ip in $IPAddress) {
            try {
                $command = "netsh interface portproxy set v6tov4 listenport=$Port listenaddress=:: connectport=$Port connectaddress=$ip"
                Write-Verbose "Executing command: $command"
                Invoke-Expression $command | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully configured port proxy for IP $ip on port $Port." -ForegroundColor Green
                }
                else {
                    Write-Error "Failed to configure port proxy for IP $ip on port $Port."
                }
            }
            catch {
                Write-Error "Error occurred: $_"
            }
        }
    }
}