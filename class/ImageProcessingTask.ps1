using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Threading

#region Base Class
class BaseImageProcessingTask {
    #region Properties
    # shared properties for both sequential and parallel tasks
    [FileInfo[]]        $Files
    [string]            $Activity
    [int]               $ProgressId
    [Stopwatch]         $Stopwatch
    [bool]              $WasExecuted = $false
    [List[ErrorRecord]] $Errors      = [List[ErrorRecord]]::new()

    # Configuration properties
    [bool] $ConvertToPng
    [bool] $UseLinearPpi
    [bool] $PreserveOriginalPpi # Corresponds to the 'no_ppi' flag in ImageSharpProcessorLib.ProcessImage
    [int]  $PpiValue

    # static hidden helper properties
    static hidden [int] $ProcessorCount = [Environment]::ProcessorCount
    #endregion Properties

    #region Constructor and Initializer
    BaseImageProcessingTask(
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

    hidden [void] InitializeConfig([hashtable]$ProcessingConfig) {
        $this.ConvertToPng        = [bool]$ProcessingConfig.ConvertToPng
        $this.UseLinearPpi        = [bool]$ProcessingConfig.UseLinearPpi
        $this.PreserveOriginalPpi = [bool]$ProcessingConfig.PreserveOriginalPpi
        $this.PpiValue            = $ProcessingConfig.ContainsKey('PpiValue') ? [int]$ProcessingConfig.PpiValue : 144

        if (-not $ProcessingConfig.ContainsKey('PpiValue')) {
            Write-Verbose "[BaseImageProcessingTask] PpiValue not found in ProcessingConfig. Defaulting to 144."
        }
    }
    #endregion Constructor and Initializer

    #region Virtual Execution (Default:Sequential)
    [void] Execute() {
        if (-not $this.Files -or $this.Files.Count -eq 0) {
            Write-Verbose "[BaseImageProcessingTask] No files to process for activity: $($this.Activity)"
            return
        }

        $this.Stopwatch.Start()
        $this.WasExecuted = $true

        $count = 0

        Write-Host "[SequentialImageProcessingTask] Starting task: $($this.Activity)" -ForegroundColor Blue

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
        Format-TimeSpan -TimeSpan $this.Stopwatch.Elapsed -Label "[SequentialImageProcessingTask] Task '$($this.Activity)' Runtime"
    }
    #endregion Virtual Execution (Default:Sequential)

    #region Public Helper Methods
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
    #endregion Public Helper Methods

    #region Factory Method
    static [BaseImageProcessingTask] Create(
        [FileInfo[]]$InputFiles,
        [string]$ActivityDescription,
        [hashtable]$ProcessingConfig,
        [int]$ProgressIdentifier = 0
    ) {
        if ($InputFiles.Count -lt [BaseImageProcessingTask]::ProcessorCount) {
            Write-Verbose "File count ($($InputFiles.Count)) is less than processor count ($([BaseImageProcessingTask]::ProcessorCount)). Using sequential processing."
            return [SequentialImageProcessingTask]::new($InputFiles, $ActivityDescription, $ProcessingConfig, $ProgressIdentifier)
        }
        else {
            Write-Verbose "File count ($($InputFiles.Count)) is sufficient for parallel processing (cores: $([BaseImageProcessingTask]::ProcessorCount))."
            return [ParallelImageProcessingTask]::new($InputFiles, $ActivityDescription, $ProcessingConfig, $ProgressIdentifier)
        }
    }
    #endregion Factory Method
}
#endregion Base Class

#region Sequential Derived Class
class SequentialImageProcessingTask : BaseImageProcessingTask {
    SequentialImageProcessingTask(
        [FileInfo[]]$InputFiles,
        [string]$ActivityDescription,
        [hashtable]$ProcessingConfig,
        [int]$ProgressIdentifier = 0
    ) : base($InputFiles, $ActivityDescription, $ProcessingConfig, $ProgressIdentifier) {
        # The constructor simply calls the base class constructor.
        # It inherits the Execute() method from the base class, which provides the sequential logic as default.
    }
}
#endregion Sequential Derived Class

#region Parallel Derived Class
class ParallelImageProcessingTask : BaseImageProcessingTask {
    #region Parallel-specific Properties
    hidden [int]             $ProcessedCount = 0
    hidden [int]             $MaxThreads     = [BaseImageProcessingTask]::ProcessorCount
    hidden [Mutex]           $Mutex          
    hidden [HashSet[string]] $ProcessedJobs  
    #endregion Parallel-specific Properties

    #region Constructor
    ParallelImageProcessingTask(
        [FileInfo[]]$InputFiles,
        [string]$ActivityDescription,
        [hashtable]$ProcessingConfig,
        [int]$ProgressIdentifier = 0
    ) : base($InputFiles, $ActivityDescription, $ProcessingConfig, $ProgressIdentifier) {
        # Initialize parallel-specific properties
        $this.Mutex         = [Mutex]::new($false)
        $this.ProcessedJobs = [HashSet[string]]::new()
    }
    #endregion Constructor

    #region Overridden Execution
    [void] Execute() {
        if ($this.ValidateAndInitialize()) {
            return
        }

        $jobs = $this.CreateJobs()
        $this.ProcessAllJobs($jobs)
        $this.Finish()
    }
    #endregion Overridden Execution

    #region Private Helper Methods
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
    #endregion Private Helper Methods
    
    #region Public Helper Methods
    [int] GetProcessedJobCount() {
        return $this.ProcessedJobs.Count
    }

    [string[]] GetProcessedJobIds() {
        return [string[]]$this.ProcessedJobs
    }
    #endregion Public Helper Methods
}
#endregion Parallel Derived Class