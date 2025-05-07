class ImageProcessingTask {
    [System.IO.FileInfo[]]$Files
    [string]$Activity
    [int]$ProgressId
    [System.Diagnostics.Stopwatch]$Stopwatch
    [bool]$WasExecuted = $false

    # Configuration properties
    [bool]$ConvertToPng
    [bool]$UseLinearPpi
    [bool]$PreserveOriginalPpi # Corresponds to the 'no_ppi' flag in ImageSharpProcessorLib.ProcessImage
    [int]$PpiValue

    ImageProcessingTask(
        [System.IO.FileInfo[]]$InputFiles,
        [string]$ActivityDescription,
        [hashtable]$ProcessingConfig, # Configuration object
        [int]$ProgressIdentifier = 0
    ) {
        $this.Files = $InputFiles
        $this.Activity = $ActivityDescription
        $this.ProgressId = $ProgressIdentifier
        $this.Stopwatch = [System.Diagnostics.Stopwatch]::new()

        # Extract configuration from the hashtable
        # Default to $false if key is not present or value evaluates to $false
        $this.ConvertToPng = [bool]$ProcessingConfig.ConvertToPng
        $this.UseLinearPpi = [bool]$ProcessingConfig.UseLinearPpi
        $this.PreserveOriginalPpi = [bool]$ProcessingConfig.PreserveOriginalPpi
        
        # PpiValue should ideally always be provided by Edit-Pictures, which has a default.
        # For robustness, ensure it's an int.
        if ($ProcessingConfig.ContainsKey('PpiValue')) {
            $this.PpiValue = [int]$ProcessingConfig.PpiValue
        } else {
            # This case should ideally not be hit if Edit-Pictures is setting defaults correctly.
            Write-Warning "PpiValue not found in ProcessingConfig. Defaulting to 144. This might be unexpected."
            $this.PpiValue = 144 
        }
    }

    [void] Execute() {
        if (-not $this.Files -or $this.Files.Count -eq 0) {
            Write-Verbose "No files to process for activity: $($this.Activity)"
            return
        }

        $this.Stopwatch.Start()
        $this.WasExecuted = $true

        $yellow    = "`e[33m"
        $fuchsia   = "`e[35m"
        $underline = "`e[4m"
        $reset     = "`e[0m"
        
        $count = 0

        Write-Host "Starting task: $($this.Activity)" -ForegroundColor Cyan

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
                $basicErrorOutput = "Error processing file '$($file.FullName)': $($_.Exception.Message)"
                $verboseErrorOutput = @"
❗ ${yellow}ERROR PROCESSING FILE!${reset}
   ${yellow}File   : ${underline}$($file.FullName)${reset}
   ${yellow}Message: ${reset}${fuchsia}$($_.Exception.Message)${reset}
"@
                Write-Error -Message $basicErrorOutput -ErrorAction SilentlyContinue
                Write-Host $verboseErrorOutput
            }
        }
        Write-Progress -Activity $this.Activity -Id $this.ProgressId -Completed
        $this.Stopwatch.Stop()
        Format-TimeSpan -TimeSpan $this.Stopwatch.Elapsed -Label "Task '$($this.Activity)' Runtime"
    }

    [bool] GetWasExecuted() {
        return $this.WasExecuted
    }

    [TimeSpan] GetElapsedTime() {
        return $this.Stopwatch.Elapsed
    }
}
