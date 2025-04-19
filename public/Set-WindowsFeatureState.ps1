<#
.SYNOPSIS
使用 ViveTool 查询和管理 Windows 功能 ID 的状态。
.DESCRIPTION
此函数通过 ViveTool.exe 查询一个或多个 Windows 功能 ID 的当前状态。
它会显示初始状态，然后逐一询问用户是否要启用每个功能。
最后，它会执行所选的启用操作，并再次查询并显示最终状态。
.PARAMETER FeatureId
必需。一个或多个 Windows 功能 ID。可以提供单个 ID、逗号分隔的 ID 字符串，或多个 ID 作为单独的参数（用空格或逗号分隔）。
例如：
-FeatureId 41415841
-FeatureId "41415841,39809531"
-FeatureId 41415841, 39809531, 42105254
-FeatureId 41415841 39809531
.PARAMETER ViveToolPath
可选。ViveTool.exe 的完整路径。如果未提供，脚本将假定 vivetool.exe 在系统 PATH 环境变量中。
例如："C:\Tools\ViveTool\vivetool.exe"。
.EXAMPLE
PS C:\> Set-WindowsFeatureState -FeatureId 41415841
# 这将查询 ID 41415841 的状态，询问是否启用，然后再次查询。
.EXAMPLE
PS C:\> Set-WindowsFeatureState -FeatureId 41415841, 39809531, 42105254
# 这将查询三个 ID 的状态，逐一询问是否启用，然后再次查询。
.EXAMPLE
PS C:\> Set-WindowsFeatureState -FeatureId "41415841,39809531" -ViveToolPath "C:\MyPrograms\ViveTool\vivetool.exe"
# 这将使用指定路径的 ViveTool 查询两个 ID 的状态，逐一询问是否启用，然后再次查询。
.EXAMPLE
PS C:\> Set-WindowsFeatureState 41415841 39809531 # 无需 -FeatureId 参数名，位置参数即可
# 这将查询两个 ID 的状态，逐一询问是否启用，然后再次查询。
.NOTES
作者: Gemini 2.5 Pro
版本: 1.1
依赖项: ViveTool.exe (https://github.com/thebookisclosed/ViVe)
请确保 ViveTool.exe 可执行，并且脚本有足够的权限运行它（可能需要管理员权限）。
ViveTool 的输出将直接显示在终端中。
Update v1.1:
- FeatureId 参数类型改为 [string[]]，接受更灵活的输入。
- 添加了更健壮的 ID 解析逻辑，支持逗号和空格分隔。
- 将 ID 格式验证提前到执行 ViveTool 命令之前。
#>
function Set-WindowsFeatureState {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true, HelpMessage="输入一个或多个功能 ID (可逗号/空格分隔)")]
        [string[]]$FeatureId, # 改为字符串数组以接受多种输入

        [Parameter(Mandatory=$false, HelpMessage="指定 ViveTool.exe 的完整路径")]
        [string]$ViveToolPath = "vivetool.exe" # 默认假定在 PATH 中
    )

    # --- 0. 验证 ViveTool 是否可执行 ---
    Write-Verbose "🔄️ 正在检查 ViveTool.exe 是否可用..."
    $viveToolExecutable = Get-Command $ViveToolPath -ErrorAction SilentlyContinue
    if (-not $viveToolExecutable) {
        Write-Error "错误：无法在路径 '${ViveToolPath}' 或系统 PATH 环境变量中找到 ViveTool.exe。"
        Write-Error "请确保 ViveTool.exe 存在且路径正确，或将其添加到 PATH。"
        return # 终止函数执行
    }
    $viveToolFullPath = $viveToolExecutable.Source
    Write-Verbose "🔄️ 找到 ViveTool.exe: ${viveToolFullPath}"

    # --- 0.5. 验证和处理 Feature ID ---
    Write-Verbose "🔄️ 正在解析和验证 Feature ID..."
    $processedIds = [System.Collections.Generic.List[string]]::new()
    $invalidIdsFound = $false

    # 处理输入的数组，允许元素内包含逗号或空格分隔的ID
    foreach ($item in $FeatureId) {
        # 分割每个输入项，处理逗号和空格作为分隔符，并去除空条目
        $splitItems = $item -split '[, ]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        foreach ($idString in $splitItems) {
            $trimmedId = $idString.Trim()
            if ($trimmedId) { # 确保不是空字符串
                # 验证ID是否为纯数字
                if ($trimmedId -match '^\d+$') {
                    if (-not $processedIds.Contains($trimmedId)) { # 避免重复添加
                       $processedIds.Add($trimmedId)
                       Write-Verbose "   -> 解析得到有效 ID: $trimmedId"
                    }
                } else {
                    Write-Error "错误：发现无效的功能 ID 格式: '$trimmedId'。ID 应仅包含数字。"
                    $invalidIdsFound = $true
                }
            }
        }
    }

    if ($invalidIdsFound) {
        Write-Error "由于存在无效的 ID 格式，函数执行已终止。"
        return
    }

    if ($processedIds.Count -eq 0) {
        Write-Error "错误：未提供任何有效的功能 ID。"
        return
    }

    # 将验证后的 ID 列表转换为逗号分隔的字符串，供 ViveTool 使用
    $validIdStringForViveTool = $processedIds -join ','
    $validIds = $processedIds # 使用 $validIds 进行后续迭代

    Write-Host "🔍 将传递给 ViveTool 的 ID 是：`n   $($validIds -join ', ')" -ForegroundColor Blue
    Write-Host "--------------------------------------------------" -ForegroundColor Blue

    # --- 1. 初始状态检查 ---
    Write-Host "🛠️ [步骤1/4] 检查 ID 初始状态" -ForegroundColor Blue
    $queryArgs = "/query /id:${validIdStringForViveTool}"
    Write-Verbose "🔄️ 执行命令: $viveToolFullPath $queryArgs"
    try {
        # 使用唯一临时文件名
        $tempPrefixA = [System.IO.Path]::GetTempFileName()
        $queryOutputA = "${tempPrefixA}.query.tmp"
        $queryErrorA = "${tempPrefixA}.query-err.tmp"

        $process = Start-Process -FilePath $viveToolFullPath -ArgumentList $queryArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput $queryOutputA -RedirectStandardError $queryErrorA

        if (Test-Path $queryOutputA) {
            $initialOutput = Get-Content $queryOutputA
            if ($initialOutput) { Write-Host "📝 ViveTool 输出:" -ForegroundColor Cyan; $initialOutput | Out-Host }
            Remove-Item $queryOutputA -ErrorAction SilentlyContinue
        }
        if (Test-Path $queryErrorA) {
            $initialError = Get-Content $queryErrorA
            if ($initialError) { Write-Warning "   ViveTool 错误输出:"; $initialError | ForEach-Object { Write-Warning $_ } }
            Remove-Item $queryErrorA -ErrorAction SilentlyContinue
        }
        if ($process.ExitCode -ne 0) { Write-Warning "ViveTool 查询命令可能未成功完成 (退出代码: $($process.ExitCode))。" }

    } catch {
        Write-Error "执行 ViveTool 查询时出错: $_"
    }
    Write-Host "--------------------------------------------------" -ForegroundColor Blue

    # --- 2. 逐一询问并收集要启用的 ID ---
    Write-Host "🛠️ [步骤2/4] 确认启用操作" -ForegroundColor Blue
    $idsToEnable = [System.Collections.Generic.List[string]]::new()
    $skipAll = $false

    foreach ($id in $validIds) { # 使用验证过的 ID 列表
        $validChoice = $false
        while (-not $validChoice) {
            $prompt = "是否要启用功能 ID: $id ?`n[Y] Yes / [D] Do not change / [S] Skip all remaining"
            $choice = Read-Host -Prompt $prompt

            switch ($choice.Trim().ToUpper()) {
                'Y' { Write-Host "🎯 [选择] 将启用 ID: ${id}" -ForegroundColor Yellow; $idsToEnable.Add($id); $validChoice = $true }
                'D' { Write-Host "🎯 [选择] 跳过 ID: ${id}" -ForegroundColor Gray; $validChoice = $true }
                'S' { Write-Host "🎯 [选择] 跳过所有剩余的 ID" -ForegroundColor Gray; $skipAll = $true; $validChoice = $true }
                default { Write-Warning "无效输入 '$choice'。请输入 Y, D 或 S（大小写不敏感）。" }
            }
        }
        if ($skipAll) { break }
    }
    Write-Host "--------------------------------------------------" -ForegroundColor Blue

    # --- 3. 执行启用操作（如果需要） ---
    if ($idsToEnable.Count -gt 0) {
        $enableIdString = $idsToEnable -join ','
        Write-Host "🛠️ [步骤3/4] 启用选定的 ID:`n   $($idsToEnable -join ', ')" -ForegroundColor Blue

        if ($PSCmdlet.ShouldProcess("功能 ID(s): $enableIdString", "通过 ViveTool 启用")) {
            $enableArgs = "/enable /id:$enableIdString"
            Write-Verbose "🔄️ 执行命令: $viveToolFullPath $enableArgs"
            try {
                $tempPrefixB = [System.IO.Path]::GetTempFileName()
                $enableOutput = "${tempPrefixB}.enable.tmp"
                $enableError = "${tempPrefixB}.enable-err.tmp"

                $process = Start-Process -FilePath $viveToolFullPath -ArgumentList $enableArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput $enableOutput -RedirectStandardError $enableError

                if (Test-Path $enableOutput) {
                    $processOutput = Get-Content $enableOutput
                    if ($processOutput) { Write-Host "📝 ViveTool 输出:" -ForegroundColor Cyan; $processOutput | Out-Host }
                    Remove-Item $enableOutput -ErrorAction SilentlyContinue
                }
                if (Test-Path $enableError) {
                    $processError = Get-Content $enableError
                    if ($processError) { Write-Warning "ViveTool 错误输出:"; $processError | ForEach-Object { Write-Warning $_ } }
                    Remove-Item $enableError -ErrorAction SilentlyContinue
                }

                if ($process.ExitCode -eq 0) {
                    Write-Host "✅ ViveTool 启用命令已成功执行。" -ForegroundColor Green
                    Write-Host "❗ 注意：某些功能的更改可能需要重新启动系统才能完全生效。" -ForegroundColor Magenta
                } else {
                    Write-Warning "ViveTool 启用命令可能未成功完成 (退出代码: $($process.ExitCode))。"
                }
            } catch {
                Write-Error "执行 ViveTool 启用时出错: $_"
            }
        } else {
            Write-Host "操作已取消 (由于 -WhatIf 参数或用户选择 'N')。" -ForegroundColor Yellow
        }
    } else {
        Write-Host "🛠️ [步骤 3/4] 未选择任何 ID 进行启用" -ForegroundColor Gray
    }
    Write-Host "--------------------------------------------------" -ForegroundColor Blue

    # --- 4. 最终状态检查 ---
    Write-Host "🛠️ [步骤4/4] 复查所有初始 ID 的最终状态" -ForegroundColor Blue
    $queryArgsFinal = "/query /id:$validIdStringForViveTool" # 重新使用包含所有有效 ID 的字符串
    Write-Verbose "🔄️ 执行命令: $viveToolFullPath $queryArgsFinal"
    try {
        $tempPrefixC = [System.IO.Path]::GetTempFileName()
        $queryOutputFinal = "${tempPrefixC}.query.tmp"
        $queryErrorFinal = "${tempPrefixC}.query-err.tmp"

        $process = Start-Process -FilePath $viveToolFullPath -ArgumentList $queryArgsFinal -Wait -NoNewWindow -PassThru -RedirectStandardOutput $queryOutputFinal -RedirectStandardError $queryErrorFinal

        if (Test-Path $queryOutputFinal) {
            $finalOutput = Get-Content $queryOutputFinal
            if ($finalOutput) { Write-Host "📝 ViveTool 输出:" -ForegroundColor Cyan; $finalOutput | Out-Host }
            Remove-Item $queryOutputFinal -ErrorAction SilentlyContinue
        }
        if (Test-Path $queryErrorFinal) {
            $finalError = Get-Content $queryErrorFinal
            if ($finalError) { Write-Warning "   ViveTool 错误输出:"; $finalError | ForEach-Object { Write-Warning $_ } }
            Remove-Item $queryErrorFinal -ErrorAction SilentlyContinue
        }
        if ($process.ExitCode -ne 0) { Write-Warning "ViveTool 最终查询命令可能未成功完成 (退出代码: $($process.ExitCode))。" }

    } catch {
        Write-Error "执行 ViveTool 最终查询时出错: $_"
    }
    Write-Host "--------------------------------------------------" -ForegroundColor Blue
    Write-Host "🎉 函数执行完毕。" -ForegroundColor Blue
}