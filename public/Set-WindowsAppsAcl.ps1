using namespace System.Security.AccessControl
using namespace System.Security.Principal

<#
.SYNOPSIS
    Checks and grants the current user 'Read and Execute' permissions for the WindowsApps folder.
.DESCRIPTION
    This function grants the current user 'Read and Execute' permissions for the %ProgramFiles%\WindowsApps directory.
    The permissions apply to 'This folder and subfolders'. The function automatically handles TrustedInstaller ownership issues.

    Key features:
    1. Checks for administrator privileges.
    2. Identifies the current user and TrustedInstaller SID.
    3. Retrieves the original owner and ACL of the WindowsApps folder.
    4. Checks if the current user already has the required permissions.
    5. If permissions are missing:
       - Takes ownership of the folder (setting it to the Administrators group).
       - Adds the necessary Access Control Entry (ACE).
       - Applies the modified ACL.
       - Restores the original owner (TrustedInstaller).
    6. Ensures other permissions remain unchanged during the ACL modification process.
.INPUTS
    This function takes no input parameters as it performs a specific, predefined operation.
.EXAMPLE
    Set-WindowsAppsAcl
    Checks and adds the required permissions, then restores the original owner upon completion.
.NOTES
    PowerShell Version: 7
    Requires administrator privileges.
    ⚠️ WARNING: Modifying system folder ownership and permissions carries potential risks. Use with caution.
.LINK
    https://github.com/Hanluica-Functions
#>
function Set-WindowsAppsAcl {
    [CmdletBinding()]
    param ()

    # --- Predefined Information ---
    # WindowsApps folder path
    $windowsAppsPath = Join-Path $env:ProgramFiles "WindowsApps"
    # SID for "NT SERVICE\TrustedInstaller"
    $trustedInstallerSid = "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464"

    # --- Function Start ---
    Write-Host "ℹ️ Starting run.`n📝 Checking and granting ${env:USERNAME} Read and Execute permissions for ${windowsAppsPath} (This folder and subfolders)." -ForegroundColor Blue
    Write-Host "--------------------------------------------------------------------`n" -ForegroundColor Magenta

    # 1. Verify administrator privileges
    Write-Host "🛠️ Check 1/5: Checking for administrator privileges." -ForegroundColor Magenta
    try {
        Test-AdminPrivilege -Mode Force
        Write-Host "✅ Administrator privileges confirmed." -ForegroundColor Green
    } catch {
        Write-Error $_.Exception.Message
        if ($Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter key to terminate execution" }
        return
    }

    # 2. Get current user identity and TrustedInstaller account object
    Write-Host "🛠️ Check 2/5: Getting user identity information." -ForegroundColor Magenta
    try {
        $currentUserIdentity = [WindowsIdentity]::GetCurrent()
        $userAccountName = $currentUserIdentity.Name # User full name, e.g., "COMPUTERNAME\Username"
        $userSid = $currentUserIdentity.User # User SID
        Write-Host "ℹ️ Current user: ${userAccountName}`n   SID: $($userSid.Value))" -ForegroundColor Blue

        $tiSidObject = [SecurityIdentifier]$trustedInstallerSid
        $tiAccount = $tiSidObject.Translate([NTAccount])
        Write-Host "ℹ️ Current target owner: $($tiAccount.Value)`n   SID: $trustedInstallerSid)" -ForegroundColor Blue

        $adminsGroup = [NTAccount]"BUILTIN\Administrators"
        $adminsSid = $adminsGroup.Translate([SecurityIdentifier])
        Write-Host "ℹ️ Temporary owner will be set to: $($adminsGroup.Value)`n   SID: $($adminsSid.Value))" -ForegroundColor Blue
    }
    catch {
        Write-Error "Failed to get user or group information: $($_.Exception.Message)"
        if ($Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter key to terminate execution" }
        return 1
    }

    # 3. Check if the folder exists
    Write-Host "🛠️ Check 3/5: Checking folder availability." -ForegroundColor Magenta
    if (-not (Test-Path -LiteralPath $windowsAppsPath -PathType Container)) {
        Write-Error "Target folder '$windowsAppsPath' does not exist."
        if ($Host.Name -eq 'ConsoleHost') { Read-Host "Press Enter key to terminate execution" }
        return 1
    }
    Write-Host "✅ Target folder is available.`n   Target folder path: ${windowsAppsPath}" -ForegroundColor Green

    # --- Define required permission parameters ---
    $requiredRights      = [FileSystemRights]::ReadAndExecute   # Permission: Read and Execute
    $requiredInheritance = [InheritanceFlags]::ContainerInherit # Inheritance: This folder and subfolders
    $requiredPropagation = [PropagationFlags]::None             # Propagation: None
    $requiredAccessType  = [AccessControlType]::Allow           # Access control type: Allow

    # --- Main Operations ---
    $originalOwner = $null
    $acl           = $null
    $ownerRestored = $true

    try {
        # 4. Get original ACL and owner
        Write-Host "🛠️ Check 4/5: Getting original ACL and owner of the target folder..." -ForegroundColor Magenta
        $acl = Get-Acl -LiteralPath $windowsAppsPath
        $originalOwner = $acl.Owner
        Write-Host "✅ Successfully retrieved ACL.`n   Original owner: ${originalOwner}" -ForegroundColor Green

        # 5. Check existing permissions
        $permissionExists = $false
        Write-Host "🛠️ Check 5/5: Checking if ${userAccountName} already has the required ReadAndExecute permissions (ContainerInherit)..." -ForegroundColor Magenta

        foreach ($ace in $acl.Access) {
            if ($ace.IdentityReference -eq $userSid) {
                if ($ace.AccessControlType -eq $requiredAccessType -and
                    ($ace.FileSystemRights -band $requiredRights) -eq $requiredRights -and
                    $ace.InheritanceFlags -eq $requiredInheritance -and
                    $ace.PropagationFlags -eq $requiredPropagation) {
                    $permissionExists = $true
                    Write-Host "🎉 Existing permission rule matches." -ForegroundColor Green
                    break
                }
            }
        }

        # 6. If permission does not exist, execute the modification process
        if (-not $permissionExists) {
            Write-Host "⚠️ ${userAccountName} needs the required permissions added. Starting modification process..." -ForegroundColor Yellow
            Write-Host "`n--------------------------------------------------------------------`n" -ForegroundColor Magenta
            $ownerRestored = $false # Regardless of whether the try block succeeds or errors, the original owner will be restored if ownership was taken ($ownerRestored -eq $false)

            # --- a. Take ownership ---
            Write-Host "🛠️ Step 1/3: Attempting to change owner to the Administrators group." -ForegroundColor Magenta
            $acl = Get-Acl -LiteralPath $windowsAppsPath
            $acl.SetOwner($adminsGroup)
            Set-Acl -LiteralPath $windowsAppsPath -AclObject $acl -ErrorAction Stop
            Write-Host "✅ Successfully changed owner temporarily to Administrators." -ForegroundColor Green

            # --- b. Add permission rule ---
            Write-Host "🛠️ Step 2/3: Adding 'ReadAndExecute' (ContainerInherit) permission rule..." -ForegroundColor Magenta
            $newRule = New-Object FileSystemAccessRule(
                $userSid,
                $requiredRights,
                $requiredInheritance,
                $requiredPropagation,
                $requiredAccessType
            )
            $acl = Get-Acl -LiteralPath $windowsAppsPath # Get ACL again, just in case
            $acl.AddAccessRule($newRule)
            # --- c. Apply modified ACL ---
            Set-Acl -LiteralPath $windowsAppsPath -AclObject $acl -ErrorAction Stop
            Write-Host "✅ Successfully added permission rule and applied ACL." -ForegroundColor Green

        } else {
            Write-Host "☑️ ${userAccountName} already has the required permissions. No action needed." -ForegroundColor Magenta
        }
    }
    catch {
        Write-Error "An error occurred while processing permissions: $($_.Exception.Message)"
        Write-Error "Function execution failed."
    }
    finally {
        if (
            ($ownerRestored -eq $false) -and
            ($null -ne $originalOwner) -and
            ($originalOwner -ne $adminsGroup.Value)
        ) {
            Write-Host "🛠️ Step 3/3: Attempting to restore original owner (${originalOwner})." -ForegroundColor Magenta
            try {
                $aclForRestore = Get-Acl -LiteralPath $windowsAppsPath # Get ACL again, just in case
                $originalOwnerAccount = New-Object NTAccount($originalOwner)
                $aclForRestore.SetOwner($originalOwnerAccount)
                Set-Acl -LiteralPath $windowsAppsPath -AclObject $aclForRestore -ErrorAction Stop
                $ownerRestored = $true # Mark as restored
                Write-Host "✅ Successfully restored owner to $originalOwner." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to restore original owner ($originalOwner): $($_.Exception.Message)"
                Write-Warning "The owner of folder '$windowsAppsPath' might still be Administrators! Please manually restore it to 'NT SERVICE\TrustedInstaller'."
            }
        }
        elseif ($ownerRestored -eq $false) {
            Write-Warning "Could not automatically restore the original owner because the original owner information is unknown or was already Administrators."
            Write-Warning "Please manually check and restore the owner of '$windowsAppsPath' to 'NT SERVICE\TrustedInstaller'."
        }
    }

    Write-Host "`n--------------------------------------------------------------------" -ForegroundColor Magenta
    Write-Host "Function execution finished." -ForegroundColor Blue
}