<#
.SYNOPSIS
    检查并授予当前用户对 WindowsApps 文件夹的"读取和执行"权限。
.DESCRIPTION
    此函数用于授予当前用户对 %ProgramFiles%\WindowsApps 目录的"读取和执行"权限，
    权限将应用于"此文件夹和子文件夹"。函数会自动处理 TrustedInstaller 所有权问题。

    主要功能：
    1. 检查管理员权限
    2. 识别当前用户和 TrustedInstaller SID
    3. 获取 WindowsApps 文件夹的原始所有者和 ACL
    4. 检查当前用户是否已有所需权限
    5. 如果权限缺失：
       - 获取文件夹所有权（设置为 Administrators 组）
       - 添加所需的访问控制条目（ACE）
       - 应用修改后的 ACL
       - 恢复原始所有者（TrustedInstaller）
    6. 确保在修改 ACL 过程中其他权限保持不变
.INPUTS
    该函数无输入参数，因其执行的操作只有一种。
.EXAMPLE
    Set-WindowsAppsAcl
    检查并添加所需权限，完成后恢复原始所有者。
.NOTES
    PowerShell版本：7
    需要管理员权限
    ⚠️警告：修改系统文件夹的所有权和权限具有潜在风险，请谨慎使用。
#>
function Set-WindowsAppsAcl {
    [CmdletBinding()]
    param ()

    # --- 预定义信息 ---
    # WindowsApps 文件夹路径
    $windowsAppsPath = Join-Path $env:ProgramFiles "WindowsApps"
    # "NT SERVICE\TrustedInstaller" 的 SID
    $trustedInstallerSid = "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464"

    # --- 函数开始 ---
    Write-Host "ℹ️ 开始运行。`n📝 检查并授予 ${env:USERNAME} 对 ${windowsAppsPath} 的读取和执行权限（此文件夹和子文件夹）。" -ForegroundColor Blue
    Write-Host "--------------------------------------------------------------------`n" -ForegroundColor Magenta

    # 1. 验证管理员权限
    Write-Host "🛠️ 检查 1/5: 正在检查管理员权限。" -ForegroundColor Magenta
    $currentUserPrincipal = [System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $currentUserPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "此脚本需要管理员权限。请以管理员身份运行 PowerShell。"
        if ($Host.Name -eq 'ConsoleHost') { Read-Host "按 Enter 键终止运行" }
        return 1
    }
    Write-Host "✅ 管理员权限检查通过。" -ForegroundColor Green

    # 2. 获取当前用户身份和 TrustedInstaller 账户对象
    Write-Host "🛠️ 检查 2/5: 正在获取用户身份信息。" -ForegroundColor Magenta
    try {
        $currentUserIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $userAccountName = $currentUserIdentity.Name # User full name, e.g., "COMPUTERNAME\Username"
        $userSid = $currentUserIdentity.User # User SID
        Write-Host "ℹ️ 当前用户: ${userAccountName}`n   SID: $($userSid.Value))" -ForegroundColor Blue

        $tiSidObject = [System.Security.Principal.SecurityIdentifier]$trustedInstallerSid
        $tiAccount = $tiSidObject.Translate([System.Security.Principal.NTAccount])
        Write-Host "ℹ️ 目标所有者: $($tiAccount.Value)`n   SID: $trustedInstallerSid)" -ForegroundColor Blue

        $adminsGroup = [System.Security.Principal.NTAccount]"BUILTIN\Administrators"
        $adminsSid = $adminsGroup.Translate([System.Security.Principal.SecurityIdentifier])
        Write-Host "ℹ️ 临时所有者将设置为: $($adminsGroup.Value)`n   SID: $($adminsSid.Value))" -ForegroundColor Blue
    }
    catch {
        Write-Error "无法获取用户或组信息: $($_.Exception.Message)"
        if ($Host.Name -eq 'ConsoleHost') { Read-Host "按 Enter 键终止运行" }
        return 1
    }

    # 3. 检查文件夹是否存在
    Write-Host "🛠️ 检查 3/5: 正在检查文件夹可用性。" -ForegroundColor Magenta
    if (-not (Test-Path -LiteralPath $windowsAppsPath -PathType Container)) {
        Write-Error "目标文件夹 '$windowsAppsPath' 不存在。"
        if ($Host.Name -eq 'ConsoleHost') { Read-Host "按 Enter 键终止运行" }
        return 1
    }
    Write-Host "✅ 目标文件夹可用。`n   目标文件夹路径：${windowsAppsPath}" -ForegroundColor Green

    # --- 定义所需权限参数 ---
    $requiredRights = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute # 权限：读取和执行
    $requiredInheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit # 继承：此文件夹和子文件夹
    $requiredPropagation = [System.Security.AccessControl.PropagationFlags]::None # # 传播：不允许传播
    $requiredAccessType = [System.Security.AccessControl.AccessControlType]::Allow # 访问控制类型：允许

    # --- 主要操作 ---
    $originalOwner = $null
    $acl = $null
    $ownerRestored = $true

    try {
        # 4. 获取原始 ACL 和所有者
        Write-Host "🛠️ 检查 4/5: 正在获取目标文件夹的原始 ACL 和所有者..." -ForegroundColor Magenta
        $acl = Get-Acl -LiteralPath $windowsAppsPath
        $originalOwner = $acl.Owner
        Write-Host "✅ 成功获取 ACL。`n   原始所有者: ${originalOwner}" -ForegroundColor Green

        # 5. 检查现有权限
        $permissionExists = $false
        Write-Host "🛠️ 检查 5/5: 正在检查 ${userAccountName} 是否已拥有所需的 ReadAndExecute 权限 (ContainerInherit)..." -ForegroundColor Magenta

        foreach ($ace in $acl.Access) {
            if ($ace.IdentityReference -eq $userSid) {
                if ($ace.AccessControlType -eq $requiredAccessType -and
                    ($ace.FileSystemRights -band $requiredRights) -eq $requiredRights -and
                    $ace.InheritanceFlags -eq $requiredInheritance -and
                    $ace.PropagationFlags -eq $requiredPropagation) {
                    $permissionExists = $true
                    Write-Host "🎉 现有权限规则已匹配。" -ForegroundColor Green
                    break
                }
            }
        }

        # 6. 如果权限不存在或强制执行，则执行修改流程
        if (-not $permissionExists) {
            Write-Host "⚠️ ${userAccountName} 需要添加所需的权限。开始修改流程..." -ForegroundColor Yellow
            Write-Host "`n--------------------------------------------------------------------`n" -ForegroundColor Magenta
            $ownerRestored = $false # 无论 try 块是否成功或出错，只要获取了所有权 ($ownerRestored -eq $false) 就会恢复原始所有者

            # --- a. 获取所有权 ---
            Write-Host "🛠️ 步骤 1/3: 尝试将所有者更改为 Administrators 组。" -ForegroundColor Magenta
            $acl = Get-Acl -LiteralPath $windowsAppsPath
            $acl.SetOwner($adminsGroup)
            Set-Acl -LiteralPath $windowsAppsPath -AclObject $acl -ErrorAction Stop
            Write-Host "✅ 成功将所有者临时更改为 Administrators。" -ForegroundColor Green

            # --- b. 添加权限规则 ---
            Write-Host "🛠️ 步骤 2/3: 添加 'ReadAndExecute' (ContainerInherit) 权限规则..." -ForegroundColor Magenta
            $newRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $userSid,
                $requiredRights,
                $requiredInheritance,
                $requiredPropagation,
                $requiredAccessType
            )
            $acl = Get-Acl -LiteralPath $windowsAppsPath # 再次获取 ACL，以防万一
            $acl.AddAccessRule($newRule)
            # --- c. 应用修改后的 ACL ---
            Set-Acl -LiteralPath $windowsAppsPath -AclObject $acl -ErrorAction Stop
            Write-Host "✅ 成功添加权限规则并应用 ACL。" -ForegroundColor Green

        } else {
            Write-Host "☑️ ${userAccountName} 已拥有所需的权限。无需操作。" -ForegroundColor Magenta
        }
    }
    catch {
        Write-Error "在处理权限时发生错误: $($_.Exception.Message)"
        Write-Error "函数执行失败。"
    }
    finally {
        if (
            ($ownerRestored -eq $false) -and
            ($null -ne $originalOwner) -and
            ($originalOwner -ne $adminsGroup.Value)
        ) {
            Write-Host "🛠️ 步骤 3/3: 尝试恢复原始所有者 (${originalOwner})。" -ForegroundColor Magenta
            try {
                $aclForRestore = Get-Acl -LiteralPath $windowsAppsPath # 再次获取 ACL，以防万一
                $originalOwnerAccount = New-Object System.Security.Principal.NTAccount($originalOwner)
                $aclForRestore.SetOwner($originalOwnerAccount)
                Set-Acl -LiteralPath $windowsAppsPath -AclObject $aclForRestore -ErrorAction Stop
                $ownerRestored = $true # 标记为已恢复
                Write-Host "✅ 成功恢复所有者为 $originalOwner。" -ForegroundColor Green
            }
            catch {
                Write-Error "恢复原始所有者 ($originalOwner) 失败: $($_.Exception.Message)"
                Write-Warning "文件夹 '$windowsAppsPath' 的所有者可能仍为 Administrators！请手动恢复为 'NT SERVICE\TrustedInstaller'。"
            }
        }
        elseif ($ownerRestored -eq $false) {
            Write-Warning "无法自动恢复原始所有者，因为原始所有者信息未知或已是 Administrators。"
            Write-Warning "请手动检查并恢复 '$windowsAppsPath' 的所有者为 'NT SERVICE\TrustedInstaller'。"
        }
    }

    Write-Host "`n--------------------------------------------------------------------" -ForegroundColor Magenta
    Write-Host "函数执行完毕。" -ForegroundColor Blue
}