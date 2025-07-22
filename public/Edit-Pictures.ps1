using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.IO

<#
.SYNOPSIS
Processes image files to set PPI values and convert between formats using an object-oriented approach.
.DESCRIPTION
The Edit-Pictures function provides batch processing capabilities for image files, including:
- Setting PPI (Pixels Per Inch) values for JPG and PNG files
- Converting WebP files to PNG format
- Converting JPG files to PNG while maintaining transparency
- Linear PPI calculation based on image width
.PARAMETER jpg
Processes only JPG files in the current directory and its subdirectories, setting their PPI to the specified value.
.PARAMETER png
Processes only PNG files in the current directory and its subdirectories, setting their PPI to the specified value.
.PARAMETER webp
Converts WebP files to PNG format. Does not modify PPI values during conversion.
.PARAMETER all
Processes both JPG and PNG files, setting their PPI to the specified value.
.PARAMETER linear
Calculates and sets PPI values for JPG and PNG files based on their width using a linear scale. (ppi = int (width / 10))
.PARAMETER trans
Processes images for transparency:
- Converts JPG files to PNG format
- Optionally sets PPI for both converted and existing PNG files
.PARAMETER no_ppi
Skip PPI setting.
- For -trans: Skips PPI setting for existing PNGs and for JPGs converted to PNG.
- For -webp: (Implicitly) WebP conversion to PNG preserves original PPI by default.
- For -jpg, -png, -all: If specified with these, it means preserve original PPI instead of setting a new one.
.PARAMETER ppi
Specifies the target PPI value. Default is 144. Must be greater than 0. Ignored if -linear or -no_ppi (for relevant operations) is used.
.PARAMETER scan
Scan image files without processing them. Outputs the count of found JPG, PNG, and WEBP files.
.EXAMPLE
Edit-Pictures -jpg -ppi 300
Sets the PPI of all JPG files in the current directory and subdirectories to 300.
.EXAMPLE
Edit-Pictures -all -ppi 144
Sets the PPI of all JPG and PNG files to 144.
.EXAMPLE
Edit-Pictures -trans -no_ppi
Converts JPG files to PNG, preserving their original PPI. Existing PNG files are not touched regarding PPI.
.EXAMPLE
Edit-Pictures -linear
Sets PPI values for all images based on their width using a linear calculation.
.NOTES
Alias: ma (ma-Parallel, ma refers to magick, which was the original command used, now replaced by ImageSharpProcessorLib)
Requires ImageSharpProcessorLib for image processing operations, and .NET 9 for supporting the library.
The library is included in the Module, but .NET runtime isn't.
#>
function Edit-Pictures {
    [CmdletBinding(DefaultParameterSetName = 'BatchProcess')]
    param (
        [Parameter(ParameterSetName = 'SingleFormat')]
        [switch]$jpg,
        [Parameter(ParameterSetName = 'SingleFormat')]
        [switch]$png,
        [Parameter(ParameterSetName = 'SingleFormat')]
        [switch]$webp,
        [Parameter(ParameterSetName = 'BatchProcess')]
        [switch]$all,
        [Parameter(ParameterSetName = 'BatchProcess')]
        [switch]$linear,
        [Parameter(ParameterSetName = 'BatchProcess')]
        [switch]$trans,
        [Parameter(ParameterSetName = 'SingleFormat')]
        [Parameter(ParameterSetName = 'BatchProcess')]
        [switch]$no_ppi,
        [Parameter(ParameterSetName = 'SingleFormat')]
        [Parameter(ParameterSetName = 'BatchProcess')]
        [int]$ppi = 144,
        [Parameter(ParameterSetName = 'Scan')]
        [switch]$scan
    )

    if ($ppi -le 0 -and !$linear -and !$no_ppi) {
        Write-Error "PPI value must be greater than 0 when setting a specific PPI. (Ingnored if -linear and -no_ppi exist.)"
        return
    }

    Write-Host "`nScanning for image files..." -ForegroundColor Blue
    [FileInfo[]]$jpgfiles  = Get-ChildItem -Path . -Recurse -File -Include @("*.jpg", "*.jpeg")
    [FileInfo[]]$pngfiles  = Get-ChildItem -Path . -Recurse -File -Include *.png
    [FileInfo[]]$webpfiles = Get-ChildItem -Path . -Recurse -File -Include *.webp
    Write-Host "Found $($jpgfiles.Count) JPG, $($pngfiles.Count) PNG, $($webpfiles.Count) WEBP files." -ForegroundColor Yellow

    if ($scan) { return }

    $overallStopwatch  = [Stopwatch]::StartNew()
    $tasksToRun        = [List[BaseImageProcessingTask]]::new()
    $progressIdCounter = 0

    # This flag is for the C# ProcessImage's 'no_ppi' parameter.
    # It's true if PowerShell's -no_ppi is present AND we are NOT using -linear.
    # If -linear is true, the C# library ignores 'no_ppi' and 'ppi' value.
    $effectivePreservePpiForCSharp = if ($linear) { $false } else { $no_ppi.IsPresent }

    switch ($PSCmdlet.ParameterSetName) {
        'SingleFormat' {
            if ($jpg) {
                $config = @{
                    ConvertToPng        = $false
                    UseLinearPpi        = $linear.IsPresent
                    PreserveOriginalPpi = $effectivePreservePpiForCSharp
                    PpiValue            = $ppi
                }
                $activityLabel = "Processing JPGs (PPI: $($config.UseLinearPpi ? 'Linear' : ($config.PreserveOriginalPpi ? 'Original' : $config.PpiValue)))"
                $tasksToRun.Add([BaseImageProcessingTask]::Create($jpgfiles, $activityLabel, $config, $progressIdCounter++))
            }
            if ($png) {
                $config = @{
                    ConvertToPng        = $false
                    UseLinearPpi        = $linear.IsPresent
                    PreserveOriginalPpi = $effectivePreservePpiForCSharp
                    PpiValue            = $ppi
                }
                $activityLabel = "Processing PNGs (PPI: $($config.UseLinearPpi ? 'Linear' : ($config.PreserveOriginalPpi ? 'Original' : $config.PpiValue)))"
                $tasksToRun.Add([BaseImageProcessingTask]::Create($pngfiles, $activityLabel, $config, $progressIdCounter++))
            }
            if ($webp) {
                $config = @{
                    ConvertToPng        = $true
                    UseLinearPpi        = $false # Linear not applicable for WebP to PNG direct conversion intent
                    PreserveOriginalPpi = $true  # WebP to PNG conversion should preserve PPI by default
                    PpiValue            = $ppi   # Passed but ignored by C# if PreserveOriginalPpi is true
                }
                $tasksToRun.Add([BaseImageProcessingTask]::Create($webpfiles, "Converting WEBP to PNG (PPI preserved)", $config, $progressIdCounter++))
            }
        }
        'BatchProcess' {
            if ($all) {
                $jpgConfig = @{
                    ConvertToPng        = $false
                    UseLinearPpi        = $linear.IsPresent
                    PreserveOriginalPpi = $effectivePreservePpiForCSharp
                    PpiValue            = $ppi
                }
                $jpgActivity = "Processing JPGs (PPI: $($jpgConfig.UseLinearPpi ? 'Linear' : ($jpgConfig.PreserveOriginalPpi ? 'Original' : $jpgConfig.PpiValue)))"
                $tasksToRun.Add([BaseImageProcessingTask]::Create($jpgfiles, $jpgActivity, $jpgConfig, $progressIdCounter++))

                $pngConfig = @{
                    ConvertToPng        = $false
                    UseLinearPpi        = $linear.IsPresent
                    PreserveOriginalPpi = $effectivePreservePpiForCSharp
                    PpiValue            = $ppi
                }
                $pngActivity = "Processing PNGs (PPI: $($pngConfig.UseLinearPpi ? 'Linear' : ($pngConfig.PreserveOriginalPpi ? 'Original' : $pngConfig.PpiValue)))"
                $tasksToRun.Add([BaseImageProcessingTask]::Create($pngfiles, $pngActivity, $pngConfig, $progressIdCounter++))
            }
            if ($linear -and !$all) { # If -all is present, linear logic is already incorporated above.
                $allImageFiles = @($jpgfiles + $pngfiles | Where-Object { $_ -is [FileInfo] })
                $config = @{
                    ConvertToPng        = $false
                    UseLinearPpi        = $true
                    PreserveOriginalPpi = $false # When linear is true, C# ignores this
                    PpiValue            = $ppi   # When linear is true, C# ignores this
                }
                $tasksToRun.Add([BaseImageProcessingTask]::Create($allImageFiles, "Processing JPG/PNG (PPI: Linear)", $config, $progressIdCounter++))
            }
            if ($trans) {
                # 1. Process existing PNG files (set PPI unless -no_ppi for this step)
                if (-not $no_ppi) { # PowerShell's -no_ppi applies here
                    $pngTransConfig = @{
                        ConvertToPng        = $false
                        UseLinearPpi        = $false # Not linear for this specific step
                        PreserveOriginalPpi = $false # We want to set PPI
                        PpiValue            = $ppi
                    }
                    $tasksToRun.Add([BaseImageProcessingTask]::Create($pngfiles, "Setting PPI for existing PNGs to $ppi", $pngTransConfig, $progressIdCounter++))
                } else {
                    Write-Host "Skipping PPI setting for existing PNG files (due to -no_ppi with -trans)." -ForegroundColor Yellow
                }

                # 2. Convert JPG to PNG (PPI setting depends on -no_ppi for this step)
                $jpgToPngConfig = @{
                    ConvertToPng        = $true
                    UseLinearPpi        = $false            # Not linear for this specific step
                    PreserveOriginalPpi = $no_ppi.IsPresent # C# no_ppi is PowerShell's -no_ppi for this conversion
                    PpiValue            = $ppi
                }
                $jpgToPngActivity = if ($jpgToPngConfig.PreserveOriginalPpi) { "Converting JPG to PNG (PPI preserved)" } else { "Converting JPG to PNG (PPI: $($jpgToPngConfig.PpiValue))" }
                $tasksToRun.Add([BaseImageProcessingTask]::Create($jpgfiles, $jpgToPngActivity, $jpgToPngConfig, $progressIdCounter++))
            }
        }
    }

    $anyTaskExecuted = $false
    if ($tasksToRun.Count -gt 0) {
        foreach ($task in $tasksToRun) {
            $task.Execute()
            if ($task.GetWasExecuted()) {
                $anyTaskExecuted = $true
            }
        }
    } else {
        Write-Host "No image processing tasks were configured to run." -ForegroundColor Gray
    }

    $overallStopwatch.Stop()
    if ($tasksToRun.Count -eq 0 -or $anyTaskExecuted) {
         Format-TimeSpan -TimeSpan $overallStopwatch.Elapsed -Label "Total Script Runtime"
    }

    $tasksWithErrors = $tasksToRun | Where-Object { $_.HasErrors() }

    if ($tasksWithErrors.Count -gt 0) {
        Write-Host "`nWarning: Processing completed with one or more errors." -ForegroundColor Red
        foreach ($task in $tasksWithErrors) {
            Write-Host "`nWhen $($task.Activity):"
            Write-Host $task.GetErrorSummary() -ForegroundColor Yellow
        }
    } elseif ($anyTaskExecuted) {
        Write-Host "All image processing tasks complete." -ForegroundColor Green
    } elseif ($tasksToRun.Count -gt 0 -and -not $anyTaskExecuted) {
        Write-Host "Image processing tasks were configured, but no files were processed (e.g., no matching files found)." -ForegroundColor Gray
    }

    if ($Error) { $Error.Clear() }
}

Set-Alias -Name ma -Value Edit-Pictures
