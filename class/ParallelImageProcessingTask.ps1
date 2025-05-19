using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Threading

class ParallelImageProcessingTask {
#region properties and constructors
    [FileInfo[]]             $Files
    [string]                 $Activity
    [int]                    $ProgressId
    [Stopwatch]              $Stopwatch
    [bool]                   $WasExecuted    = $false
    [List[ErrorRecord]]      $Errors         = [List[ErrorRecord]]::new()
    hidden [int]             $ProcessedCount = 0
    hidden [int]             $MaxThreads     = [Environment]::ProcessorCount * 2
    hidden [Mutex]           $Mutex          = [Mutex]::new($false)
    hidden [HashSet[string]] $ProcessedJobs  = [HashSet[string]]::new()

    # Configuration properties
    [bool] $ConvertToPng
    [bool] $UseLinearPpi
    [bool] $PreserveOriginalPpi
    [int]  $PpiValue

    ParallelImageProcessingTask(
        [FileInfo[]]$InputFiles,
        [string]$ActivityDescription,
        [hashtable]$ProcessingConfig,
        [int]$ProgressIdentifier = 0
    ) {
        $this.Files      = $InputFiles
        $this.Activity   = $ActivityDescription
        $this.ProgressId = $ProgressIdentifier
        $this.Stopwatch  = [Stopwatch]::new()

        $this.InitializeConfig($ProcessingConfig)
    }
#endregion properties and constructors

#region private helper methods
    hidden [void] InitializeConfig([hashtable]$ProcessingConfig) {
        $this.ConvertToPng        = [bool]$ProcessingConfig.ConvertToPng
        $this.UseLinearPpi        = [bool]$ProcessingConfig.UseLinearPpi
        $this.PreserveOriginalPpi = [bool]$ProcessingConfig.PreserveOriginalPpi
        $this.PpiValue            = $ProcessingConfig.ContainsKey('PpiValue') ? [int]$ProcessingConfig.PpiValue : 144

        if (-not $ProcessingConfig.ContainsKey('PpiValue')) {
            Write-Verbose "[ParallelImageProcessingTask] PpiValue not found in ProcessingConfig. Defaulting to 144."
        }
    }

    hidden [bool] ValidateAndInitialize() {
        if (-not $this.Files -or $this.Files.Count -eq 0) {
            Write-Verbose "[ParallelImageProcessingTask] No files to process for activity: $($this.Activity)"
            return $true
        }
        
        $this.Stopwatch.Start()
        $this.WasExecuted = $true
        Write-Host "[ParallelImageProcessingTask] Starting parallel task: $($this.Activity)" -ForegroundColor Blue
        return $false
    }

    hidden [void] IncrementProcessedCount() {
        try {
            $this.Mutex.WaitOne() | Out-Null
            $this.ProcessedCount++
        }
        finally {
            $this.Mutex.ReleaseMutex()
        }
    }

    hidden [void] UpdateProgressBar() {
        $currentCount = $this.ProcessedCount
        Write-Progress -Activity $this.Activity -Id $this.ProgressId `
            -Status ("{0} / {1} files processed" -f $currentCount, $this.Files.Count) `
            -PercentComplete ($currentCount / $this.Files.Count * 100)
    }

    hidden [void] AddError([Exception]$exception, [string]$filePath) {
        $errorRecord = [ErrorRecord]::new(
            $exception,
            "ImageProcessingError",
            [ErrorCategory]::OperationStopped,
            $filePath
        )
        
        try {
            $this.Mutex.WaitOne() | Out-Null
            $this.Errors.Add($errorRecord)
        }
        finally {
            $this.Mutex.ReleaseMutex()
        }
    }

    hidden [List[object]] CreateJobs() {
        $jobs = [List[object]]::new()
        
        foreach ($file in $this.Files) {
            $job = Start-ThreadJob `
                -ScriptBlock {
                    param($filePath, $convertToPng, $useLinearPpi, $preserveOriginalPpi, $ppiValue)
                    try {
                        [ImageSharpProcessorLib.ImageProcessor]::ProcessImage(
                            $filePath, $convertToPng, $useLinearPpi, $preserveOriginalPpi, $ppiValue
                        )
                        return @{ Success = $true; File = $filePath }
                    } catch {
                        return @{ Success = $false; File = $filePath; Error = $_.Exception }
                    }
                } `
                -ArgumentList $file.FullName, $this.ConvertToPng, $this.UseLinearPpi, $this.PreserveOriginalPpi, $this.PpiValue `
                -ThrottleLimit $this.MaxThreads
                
            $jobs.Add($job)
        }
        
        return $jobs
    }

    hidden [void] ProcessSingleJob([object]$job) {
        $result = Receive-Job -Job $job -Wait -AutoRemoveJob
        if (-not $result.Success -and $result.Error) {
            $this.AddError($result.Error, $result.File)
        }
        
        $this.ProcessedJobs.Add($job.Id)
        $this.IncrementProcessedCount()
    }

    hidden [void] ProcessCompletedJobs([List[object]]$jobs) {
        $completed = $jobs.Where(
            { $_.State -eq 'Completed' -and -not $this.ProcessedJobs.Contains($_.Id) }
        )
        
        foreach ($job in @($completed)) {
            $this.ProcessSingleJob($job)
            $jobs.Remove($job)
        }
        
        $this.UpdateProgressBar()
    }
    hidden [void] ProcessAllJobs([List[object]]$jobs) {
        while ($jobs.Count -gt 0) {
            $this.ProcessCompletedJobs($jobs)
            Start-Sleep -Milliseconds 50
        }
    }

    hidden [void] Finish() {
        Write-Progress -Activity $this.Activity -Id $this.ProgressId -Completed
        $this.Stopwatch.Stop()
        Format-TimeSpan -TimeSpan $this.Stopwatch.Elapsed -Label "[ParallelImageProcessingTask] Task '$($this.Activity)' Runtime"
    }
#endregion private helper methods

#region main execution method
    [void] Execute() {
        if ($this.ValidateAndInitialize()) {
            return
        }

        $jobs = $this.CreateJobs()
        $this.ProcessAllJobs($jobs)
        $this.Finish()
    }
#endregion main execution method

#region public helper methods
    [bool] GetWasExecuted() {
        return $this.WasExecuted
    }

    [TimeSpan] GetElapsedTime() {
        return $this.Stopwatch.Elapsed
    }

    [int] GetProcessedJobCount() {
        return $this.ProcessedJobs.Count
    }

    [string[]] GetProcessedJobIds() {
        return [string[]]$this.ProcessedJobs
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
#endregion public helper methods
}