using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Diagnostics

class ImageProcessingTask {
    [FileInfo[]]        $Files
    [string]            $Activity
    [int]               $ProgressId
    [Stopwatch]         $Stopwatch
    [bool]              $WasExecuted = $false
    [List[ErrorRecord]] $Errors = [List[ErrorRecord]]::new()

    # Configuration properties
    [bool] $ConvertToPng
    [bool] $UseLinearPpi
    [bool] $PreserveOriginalPpi # Corresponds to the 'no_ppi' flag in ImageSharpProcessorLib.ProcessImage
    [int]  $PpiValue

    ImageProcessingTask(
        [FileInfo[]]$InputFiles,
        [string]$ActivityDescription,
        [hashtable]$ProcessingConfig, # Configuration object
        [int]$ProgressIdentifier = 0
    ) {
        $this.Files      = $InputFiles
        $this.Activity   = $ActivityDescription
        $this.ProgressId = $ProgressIdentifier
        $this.Stopwatch  = [Stopwatch]::new()

        # Extract configuration from the hashtable
        # Default to $false if key is not present or value evaluates to $false
        $this.ConvertToPng        = [bool]$ProcessingConfig.ConvertToPng
        $this.UseLinearPpi        = [bool]$ProcessingConfig.UseLinearPpi
        $this.PreserveOriginalPpi = [bool]$ProcessingConfig.PreserveOriginalPpi
        $this.PpiValue            = $ProcessingConfig.ContainsKey('PpiValue') ? [int]$ProcessingConfig.PpiValue : 144

        if (-not $ProcessingConfig.ContainsKey('PpiValue')) {
            Write-Verbose "[ImageProcessingTask] PpiValue not found in ProcessingConfig. Defaulting to 144."
        }
    }

    [void] Execute() {
        if (-not $this.Files -or $this.Files.Count -eq 0) {
            Write-Verbose "[ImageProcessingTask] No files to process for activity: $($this.Activity)"
            return
        }

        $this.Stopwatch.Start()
        $this.WasExecuted = $true

        $count = 0

        Write-Host "[ImageProcessingTask] Starting task: $($this.Activity)" -ForegroundColor Blue

        foreach ($file in $this.Files) {
            $count++
            try {
                # Use the class properties for ProcessImage parameters
                [ImageSharpProcessorLib.ImageProcessor]::ProcessImage(
                    $file.FullName,
                    $this.ConvertToPng,
                    $this.UseLinearPpi,
                    $this.PreserveOriginalPpi, # This is the 'no_ppi' flag for ProcessImage
                    $this.PpiValue
                )

                Write-Progress -Activity $this.Activity -Id $this.ProgressId `
                    -Status ("{0} / {1} - {2}" -f $count, $this.Files.Count, (Limit-StringLength -InputStrings $file.Name -MaxLength 15)) `
                    -PercentComplete ($count / $this.Files.Count * 100)
            } catch {
                $this.Errors.Add($_.ErrorRecord)
            }
        }
        Write-Progress -Activity $this.Activity -Id $this.ProgressId -Completed
        $this.Stopwatch.Stop()
        Format-TimeSpan -TimeSpan $this.Stopwatch.Elapsed -Label "[ImageProcessingTask] Task '$($this.Activity)' Runtime"
    }

    [bool] GetWasExecuted() {
        return $this.WasExecuted
    }

    [TimeSpan] GetElapsedTime() {
        return $this.Stopwatch.Elapsed
    }

    [bool] HasErrors() {
        return ($this.Errors.Count -gt 0)
    }

    [string] GetErrorSummary() {
        $ErrorSummary = (
            $this.Errors `
            | ForEach-Object { "- Error '$($_.Exception.Message)' in file '$($_.TargetObject)'" } `
            | Out-String
        )
        return $ErrorSummary
    }
}
