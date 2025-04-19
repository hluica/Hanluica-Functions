<#
.SYNOPSIS
    将子目录中的文件移动到当前目录，并以子目录名作为前缀。
.DESCRIPTION
    遍历当前目录下的所有子目录（*不包含*二级以及更深层递归），将其中的非txt文件移动到当前目录。
    移动的文件将以所在子目录的名称作为前缀。
    支持处理包含特殊字符的文件名。
    显示详细的处理进度和错误信息。
.EXAMPLE
    Move-SubdirFiles
    将当前目录下所有子目录中的非txt文件移动到当前目录。
.NOTES
    - 需要确保当前目录有足够的写入权限
    - 建议在执行前备份重要文件
    - 如遇到文件名冲突，将自动覆盖目标文件
    - 别名： flatmv
#>
function Move-SubdirFiles {
    [CmdletBinding()]
    param()
    
    # 检查是否具有管理员权限
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "⚠️脚本可能需要管理员权限才能正常运行"
    }

    $currentPath = Get-Location
    $dirs = Get-ChildItem -Directory 
    Write-Host "开始处理……`n待处理子目录数量：$($dirs.Count)" -ForegroundColor Magenta

    $dirs | ForEach-Object {
        $dirName = $_.Name
        # 使用 Join-Path 构建完整路径
        $dirPath = Join-Path -Path $_.FullName -ChildPath "*"
        Write-Host "正在处理子目录：$dirPath" -ForegroundColor Cyan
        
        try {
            # 使用 -LiteralPath 参数以确保正确处理特殊字符
            $files = Get-ChildItem -LiteralPath "$($_.FullName)" -File
            Write-Host "当前子目录中的文件数量：$($files.Count)" -ForegroundColor Magenta
            
            $files | ForEach-Object {
                $newFileName = "{0}_{1}" -f $dirName, $_.Name
                $targetPath = Join-Path -Path $currentPath -ChildPath $newFileName
                
                try {
                    Move-Item -LiteralPath $_.FullName -Destination $targetPath -Force -ErrorAction Stop
                    Write-Host "成功移动文件：" -ForegroundColor Green
                    Write-Host "    $($_.FullName)`n -> $targetPath"
                }
                catch {
                    Write-Error "移动文件失败：$($_.FullName)`n错误信息：$($_.Exception.Message)"
                }
            }
        }
        catch {
            Write-Error "处理目录失败：$dirPath`n错误信息：$($_.Exception.Message)"
        }
    }

    Write-Host "命令执行完成。请确认运行情况。" -ForegroundColor Magenta
}

Set-Alias -Name flatmv -Value Move-SubdirFiles