<#
.SYNOPSIS
Use ViveTool to query and manage the status of Windows Feature IDs.
.DESCRIPTION
This function queries the current status of one or more Windows Feature IDs using ViveTool.exe.
It displays the initial status, then asks the user whether to enable each feature individually.
Finally, it executes the selected enable actions and queries/displays the final status again.
.PARAMETER FeatureId
Required. One or more Windows Feature IDs. Can be a single ID, a comma-separated string of IDs, or multiple IDs as separate arguments (separated by spaces or commas).
Examples:
-FeatureId 41415841
-FeatureId "41415841,39809531"
-FeatureId 41415841, 39809531, 42105254
-FeatureId 41415841 39809531
.PARAMETER ViveToolPath
Optional. The full path to ViveTool.exe. If not provided, the script assumes vivetool.exe is in the system PATH environment variable.
Example: "C:\Tools\ViveTool\vivetool.exe".
.EXAMPLE
PS C:\> Set-WindowsFeatureState -FeatureId 41415841
# This will query the status of ID 41415841, ask whether to enable it, and then query again.
.EXAMPLE
PS C:\> Set-WindowsFeatureState -FeatureId 41415841, 39809531, 42105254
# This will query the status of the three IDs, ask individually whether to enable them, and then query again.
.EXAMPLE
PS C:\> Set-WindowsFeatureState -FeatureId "41415841,39809531" -ViveToolPath "C:\MyPrograms\ViveTool\vivetool.exe"
# This will use the specified ViveTool path to query the status of the two IDs, ask individually whether to enable them, and then query again.
.EXAMPLE
PS C:\> Set-WindowsFeatureState 41415841 39809531 # No need for -FeatureId parameter name, positional parameter works
# This will query the status of the two IDs, ask individually whether to enable them, and then query again.
.NOTES
Version: 1.1
Dependencies: ViveTool.exe (https://github.com/thebookisclosed/ViVe)
Ensure ViveTool.exe is executable and the script has sufficient permissions to run it (may require administrator privileges).
ViveTool's output will be displayed directly in the terminal.
Update v1.1:
    - FeatureId parameter type changed to [string[]] to accept more flexible input.
    - Added more robust ID parsing logic, supporting comma and space separators.
    - Moved ID format validation before executing ViveTool commands.
#>
function Set-WindowsFeatureState {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true, HelpMessage="Enter one or more Feature IDs (can be comma/space separated)")]
        [string[]]$FeatureId, # Changed to string array to accept multiple input types

        [Parameter(Mandatory=$false, HelpMessage="Specify the full path to ViveTool.exe")]
        [string]$ViveToolPath = "vivetool.exe" # Defaults to assuming it's in PATH
    )

    # --- 0. Verify if ViveTool is executable ---
    Write-Verbose "🔄️ Checking if ViveTool.exe is available..."
    $viveToolExecutable = Get-Command $ViveToolPath -ErrorAction SilentlyContinue
    if (-not $viveToolExecutable) {
        Write-Error "Error: Cannot find ViveTool.exe at path '${ViveToolPath}' or in the system PATH."
        Write-Error "Please ensure ViveTool.exe exists and the path is correct, or add it to your PATH."
        return # Terminate function execution
    }
    $viveToolFullPath = $viveToolExecutable.Source
    Write-Verbose "🔄️ Found ViveTool.exe: ${viveToolFullPath}"

    # --- 0.5. Validate and process Feature IDs ---
    Write-Verbose "🔄️ Parsing and validating Feature IDs..."
    $processedIds = [System.Collections.Generic.List[string]]::new()
    $invalidIdsFound = $false

    # Process the input array, allowing elements to contain comma or space separated IDs
    foreach ($item in $FeatureId) {
        # Split each input item, handling commas and spaces as delimiters, and remove empty entries
        $splitItems = $item -split '[, ]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        foreach ($idString in $splitItems) {
            $trimmedId = $idString.Trim()
            if ($trimmedId) { # Ensure it's not an empty string
                # Validate if the ID is purely numeric
                if ($trimmedId -match '^\d+$') {
                    if (-not $processedIds.Contains($trimmedId)) { # Avoid adding duplicates
                       $processedIds.Add($trimmedId)
                       Write-Verbose "   -> Parsed valid ID: $trimmedId"
                    }
                } else {
                    Write-Error "Error: Found invalid Feature ID format: '$trimmedId'. ID should only contain numbers."
                    $invalidIdsFound = $true
                }
            }
        }
    }

    if ($invalidIdsFound) {
        Write-Error "Function execution terminated due to invalid ID format."
        return
    }

    if ($processedIds.Count -eq 0) {
        Write-Error "Error: No valid Feature IDs were provided."
        return
    }

    # Convert the validated ID list to a comma-separated string for ViveTool use
    $validIdStringForViveTool = $processedIds -join ','
    $validIds = $processedIds # Use $validIds for subsequent iteration

    Write-Host "🔍 IDs to be passed to ViveTool:`n   $($validIds -join ', ')" -ForegroundColor Blue
    Write-Host "--------------------------------------------------" -ForegroundColor Blue

    # --- 1. Initial Status Check ---
    Write-Host "🛠️ [Step 1/4] Checking initial ID status" -ForegroundColor Blue
    $queryArgs = "/query /id:${validIdStringForViveTool}"
    Write-Verbose "🔄️ Executing command: $viveToolFullPath $queryArgs"
    try {
        # Use unique temporary filenames
        $tempPrefixA = [System.IO.Path]::GetTempFileName()
        $queryOutputA = "${tempPrefixA}.query.tmp"
        $queryErrorA = "${tempPrefixA}.query-err.tmp"

        $process = Start-Process -FilePath $viveToolFullPath -ArgumentList $queryArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput $queryOutputA -RedirectStandardError $queryErrorA

        if (Test-Path $queryOutputA) {
            $initialOutput = Get-Content $queryOutputA
            if ($initialOutput) { Write-Host "📝 ViveTool Output:" -ForegroundColor Cyan; $initialOutput | Out-Host }
            Remove-Item $queryOutputA -ErrorAction SilentlyContinue
        }
        if (Test-Path $queryErrorA) {
            $initialError = Get-Content $queryErrorA
            if ($initialError) { Write-Warning "ViveTool Error Output:"; $initialError | ForEach-Object { Write-Warning $_ } }
            Remove-Item $queryErrorA -ErrorAction SilentlyContinue
        }
        if ($process.ExitCode -ne 0) { Write-Warning "ViveTool query command may not have completed successfully (Exit Code: $($process.ExitCode))." }

    } catch {
        Write-Error "Error executing ViveTool query: $_"
    }
    Write-Host "--------------------------------------------------" -ForegroundColor Blue

    # --- 2. Ask individually and collect IDs to enable ---
    Write-Host "🛠️ [Step 2/4] Confirm enable actions" -ForegroundColor Blue
    $idsToEnable = [System.Collections.Generic.List[string]]::new()
    $skipAll = $false

    foreach ($id in $validIds) { # Use the validated ID list
        $validChoice = $false
        while (-not $validChoice) {
            $prompt = "Do you want to enable Feature ID: $id ?`n[Y] Yes / [D] Do not change / [S] Skip all remaining"
            $choice = Read-Host -Prompt $prompt

            switch ($choice.Trim().ToUpper()) {
                'Y' { Write-Host "🎯 [Choice] Will enable ID: ${id}" -ForegroundColor Yellow; $idsToEnable.Add($id); $validChoice = $true }
                'D' { Write-Host "🎯 [Choice] Skipping ID: ${id}" -ForegroundColor Gray; $validChoice = $true }
                'S' { Write-Host "🎯 [Choice] Skipping all remaining IDs" -ForegroundColor Gray; $skipAll = $true; $validChoice = $true }
                default { Write-Warning "Invalid input '$choice'. Please enter Y, D, or S (case-insensitive)." }
            }
        }
        if ($skipAll) { break }
    }
    Write-Host "--------------------------------------------------" -ForegroundColor Blue

    # --- 3. Execute enable actions (if needed) ---
    if ($idsToEnable.Count -gt 0) {
        $enableIdString = $idsToEnable -join ','
        Write-Host "🛠️ [Step 3/4] Enabling selected IDs:`n   $($idsToEnable -join ', ')" -ForegroundColor Blue

        if ($PSCmdlet.ShouldProcess("Feature ID(s): $enableIdString", "Enable via ViveTool")) {
            $enableArgs = "/enable /id:$enableIdString"
            Write-Verbose "🔄️ Executing command: $viveToolFullPath $enableArgs"
            try {
                $tempPrefixB = [System.IO.Path]::GetTempFileName()
                $enableOutput = "${tempPrefixB}.enable.tmp"
                $enableError = "${tempPrefixB}.enable-err.tmp"

                $process = Start-Process -FilePath $viveToolFullPath -ArgumentList $enableArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput $enableOutput -RedirectStandardError $enableError

                if (Test-Path $enableOutput) {
                    $processOutput = Get-Content $enableOutput
                    if ($processOutput) { Write-Host "📝 ViveTool Output:" -ForegroundColor Cyan; $processOutput | Out-Host }
                    Remove-Item $enableOutput -ErrorAction SilentlyContinue
                }
                if (Test-Path $enableError) {
                    $processError = Get-Content $enableError
                    if ($processError) { Write-Warning "ViveTool Error Output:"; $processError | ForEach-Object { Write-Warning $_ } }
                    Remove-Item $enableError -ErrorAction SilentlyContinue
                }

                if ($process.ExitCode -eq 0) {
                    Write-Host "✅ ViveTool enable command executed successfully." -ForegroundColor Green
                    Write-Host "❗ Note: Changes for some features may require a system restart to take full effect." -ForegroundColor Magenta
                } else {
                    Write-Warning "ViveTool enable command may not have completed successfully (Exit Code: $($process.ExitCode))."
                }
            } catch {
                Write-Error "Error executing ViveTool enable: $_"
            }
        } else {
            Write-Host "Operation cancelled (due to -WhatIf parameter or user selecting 'N')." -ForegroundColor Yellow
        }
    } else {
        Write-Host "🛠️ [Step 3/4] No IDs were selected for enabling" -ForegroundColor Gray
    }
    Write-Host "--------------------------------------------------" -ForegroundColor Blue

    # --- 4. Final Status Check ---
    Write-Host "🛠️ [Step 4/4] Re-checking final status of all initial IDs" -ForegroundColor Blue
    $queryArgsFinal = "/query /id:$validIdStringForViveTool" # Reuse the string containing all valid IDs
    Write-Verbose "🔄️ Executing command: $viveToolFullPath $queryArgsFinal"
    try {
        $tempPrefixC = [System.IO.Path]::GetTempFileName()
        $queryOutputFinal = "${tempPrefixC}.query.tmp"
        $queryErrorFinal = "${tempPrefixC}.query-err.tmp"

        $process = Start-Process -FilePath $viveToolFullPath -ArgumentList $queryArgsFinal -Wait -NoNewWindow -PassThru -RedirectStandardOutput $queryOutputFinal -RedirectStandardError $queryErrorFinal

        if (Test-Path $queryOutputFinal) {
            $finalOutput = Get-Content $queryOutputFinal
            if ($finalOutput) { Write-Host "📝 ViveTool Output:" -ForegroundColor Cyan; $finalOutput | Out-Host }
            Remove-Item $queryOutputFinal -ErrorAction SilentlyContinue
        }
        if (Test-Path $queryErrorFinal) {
            $finalError = Get-Content $queryErrorFinal
            if ($finalError) { Write-Warning "ViveTool Error Output:"; $finalError | ForEach-Object { Write-Warning $_ } }
            Remove-Item $queryErrorFinal -ErrorAction SilentlyContinue
        }
        if ($process.ExitCode -ne 0) { Write-Warning "ViveTool final query command may not have completed successfully (Exit Code: $($process.ExitCode))." }

    } catch {
        Write-Error "Error executing ViveTool final query: $_"
    }
    Write-Host "--------------------------------------------------" -ForegroundColor Blue
    Write-Host "🎉 Function execution finished." -ForegroundColor Blue
}
