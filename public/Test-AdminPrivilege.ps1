<#
.SYNOPSIS
    Tests if the current user has administrator privileges.
.DESCRIPTION
    Tests if the current user has administrator privileges and handles the result
    according to the specified mode.
.PARAMETER Mode
    Defines how the function handles non-administrator scenarios:
    - Silent: Returns a boolean value without any prompting. The calling script is responsible for handling this.
    - Prompt: Warns the user and asks for confirmation to continue. - This is the default behavior.
    - Force: Throws an error if not running as administrator. This will abort the script. - The calling script CAN still keep running by catching the error.
.EXAMPLE
    PS> Test-AdminPrivilege
    Returns $true if running as admin, $false otherwise
.EXAMPLE
    PS> Test-AdminPrivilege -Mode Force
    Throws an error if not running as administrator
.LINK
    https://github.com/Hanluica-Functions
#>
function Test-AdminPrivilege {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # Define the mode of operation for the function.
        # Default: Returns a boolean value without any UI interaction.
        # Prompt: Warns the user and asks for confirmation to continue if not admin.
        # Force: Throws an error and stops execution if not admin.
        [Parameter(Mandatory = $false)]
        [ValidateSet("Silent", "Prompt", "Force")]
        [string]$Mode = "Prompt"
    )

    # Get the current Windows identity and principal.
    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($windowsIdentity)

    # Check if the current user is in the 'Administrators' built-in role.
    $isAdmin = $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        # If the user has administrator privileges, always return $true.
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Current user has administrator privileges."
        return $true
    } else {
        # If the user does not have administrator privileges, the behavior depends on the selected mode.
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Current user does NOT have administrator privileges. Mode: $Mode"
        switch ($Mode) {
            "Silent" {
                # Default mode: Silently return $false.
                # The calling script is responsible for handling this.
                return $false
            }
            "Prompt" {
                # Prompt mode: Display a warning and ask the user if they want to continue.
                Write-Warning "Administrator privileges are recommended for this script/operation to function correctly."
                
                $title = "Permission Warning"
                $message = "You are not running with administrator privileges. Some operations may fail. Do you want to continue anyway?"
                
                # Create choice descriptions for Yes/No.
                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Continue the script without administrator privileges."
                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Abort the script."
                $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
                
                # Prompt the user for a choice. Default to 'No'.
                $userChoice = $Host.UI.PromptForChoice($title, $message, $options, 1) # 1 is the index for 'No'

                if ($userChoice -eq 0) { # User selected "Yes" (index 0)
                    Write-Warning "Continuing without administrator privileges as per user choice."
                    # Return $false to indicate lack of admin rights, but the user opted to proceed.
                    return $false 
                } else { # User selected "No" (index 1) or closed the prompt
                    # Interrupt the caller's code by throwing an error.
                    throw "Execution aborted by user due to lack of administrator privileges."
                }
            }
            "Force" {
                # Force mode: Write an error and interrupt the caller's code.
                $errorMessage = "Administrator privileges are required to proceed. Please re-run this script as an Administrator."
                # Throw a terminating error. This will stop the script.
                throw $errorMessage
                # Remenber the calling script can still kepp running if it catches the error withour terminating itself.
            }
        }
    }
}