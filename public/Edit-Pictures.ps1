function Edit-Pictures {
    [CmdletBinding(DefaultParameterSetName = 'SingleFormat')]
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
        [switch]$no_ppi, # Applicable only to -trans
        [int]$ppi = 144
    )

    # Validate PPI input
    if ($ppi -le 0) {
        Write-Error "PPI value must be greater than 0."
        return
    }

    Write-Host "Scanning for image files..." -ForegroundColor Cyan
    [System.IO.FileInfo[]]$jpgfiles = Get-ChildItem -Path . -Recurse -Include *.jpg, *.jpeg -File
    [System.IO.FileInfo[]]$pngfiles = Get-ChildItem -Path . -Recurse -Include *.png -File
    [System.IO.FileInfo[]]$webpfiles = Get-ChildItem -Path . -Recurse -Include *.webp -File
    Write-Host "Found $($jpgfiles.Count) JPG, $($pngfiles.Count) PNG, $($webpfiles.Count) WEBP files." -ForegroundColor Yellow

    $Script:StopWatch = [System.Diagnostics.Stopwatch]::StartNew()

    switch ($PSCmdlet.ParameterSetName) {
        'SingleFormat' {
            switch ($true) {
                $jpg {
                    if ($jpgfiles.Count -gt 0) {
                        Invoke-ImageProcess -Files $jpgfiles -Activity "Setting JPG PPI to $ppi..." `
                            -ProcessBlock {
                                param($f)
                                # Call ProcessImage: Keep format JPG, use fixed PPI, don't use linear, set PPI
                                [ImageSharpProcessorLib.ImageProcessor]::ProcessImage($f.FullName, $false, $false, $false, $ppi)
                            }
                    }
                }
                $png {
                     if ($pngfiles.Count -gt 0) {
                        Invoke-ImageProcess -Files $pngfiles -Activity "Setting PNG PPI to $ppi..." `
                            -ProcessBlock {
                                param($f)
                                # Call ProcessImage: Keep format PNG, use fixed PPI, don't use linear, set PPI
                                [ImageSharpProcessorLib.ImageProcessor]::ProcessImage($f.FullName, $false, $false, $false, $ppi)
                            }
                     }
                }
                $webp {
                    if ($webpfiles.Count -gt 0) {
                        # Note: This is used only to convert WebP to PNG, not to set PPI
                        # But the ProcessImage() method DO HAVE ability to set PPI.
                        Invoke-ImageProcess -Files $webpfiles -Activity "Converting WEBP to PNG (PPI unchanged)..." `
                            -ProcessBlock {
                                param($f)
                                # Call ProcessImage: Convert to PNG, don't use linear, DO NOT set PPI
                                [ImageSharpProcessorLib.ImageProcessor]::ProcessImage($f.FullName, $true, $false, $true, $ppi)
                            }
                    }
                }
            }
        }
        'BatchProcess' {
            switch ($true) {
                $all {
                    if ($jpgfiles.Count -gt 0) {
                        Invoke-ImageProcess -Files $jpgfiles -Activity "Setting JPG PPI to $ppi..." -ProgressId 0 `
                            -ProcessBlock {
                                param($f)
                                # Call ProcessImage: Keep format JPG, use fixed PPI, don't use linear, set PPI
                                [ImageSharpProcessorLib.ImageProcessor]::ProcessImage($f.FullName, $false, $false, $false, $ppi)
                            }
                    }
                    if ($pngfiles.Count -gt 0) {
                        Invoke-ImageProcess -Files $pngfiles -Activity "Setting PNG PPI to $ppi..." -ProgressId 1 `
                            -ProcessBlock {
                                param($f)
                                # Call ProcessImage: Keep format PNG, use fixed PPI, don't use linear, set PPI
                                [ImageSharpProcessorLib.ImageProcessor]::ProcessImage($f.FullName, $false, $false, $false, $ppi)
                            }
                    }
                }
                $linear {
                    # Combine JPG and PNG for processing
                    $pics = @(($jpgfiles + $pngfiles) | Where-Object { $_ -is [System.IO.FileInfo] })
                    if ($pics.Count -gt 0) {
                         Invoke-ImageProcess -Files $pics -Activity "Setting verbose PPI based on width..." `
                            -ProcessBlock {
                                param($f)
                                # Call ProcessImage: Keep original format, use linear PPI calc, set PPI
                                [ImageSharpProcessorLib.ImageProcessor]::ProcessImage($f.FullName, $false, $true, $false, $ppi) # $ppi value ignofuchsia when linear=true
                            }
                    }
                }
                $trans {
                    # Process PNG files first (only if -no_ppi is NOT specified)
                    if (-not $no_ppi) {
                        if ($pngfiles.Count -gt 0) {
                            Invoke-ImageProcess -Files $pngfiles -Activity "Setting PNG PPI to $ppi..." -ProgressId 1 `
                                -ProcessBlock {
                                    param($f)
                                    # Call ProcessImage: Keep format PNG, use fixed PPI, don't use linear, set PPI
                                    [ImageSharpProcessorLib.ImageProcessor]::ProcessImage($f.FullName, $false, $false, $false, $ppi)
                                }
                        }
                    } else {
                         Write-Host "Skipping PPI setting for PNG files." -ForegroundColor Cyan
                    }
                    # Process JPG files (convert to PNG, optionally set PPI)
                    if ($jpgfiles.Count -gt 0) {
                        $activity = if ($no_ppi) { "Converting JPG to PNG (PPI unchanged)..." } else { "Converting JPG to PNG and setting PPI to $ppi..." }
                        Invoke-ImageProcess -Files $jpgfiles -Activity $activity -ProgressId 2 `
                            -ProcessBlock {
                                param($f)
                                # Call ProcessImage: Convert to PNG, don't use linear, set PPI based on $no_ppi flag
                                [ImageSharpProcessorLib.ImageProcessor]::ProcessImage($f.FullName, $true, $false, $no_ppi, $ppi)
                            }
                    }
                }
            }
        }
    }

    # Final time reported by Invoke-ImageProcess if it ran, otherwise report here if no files processed.
    $Script:StopWatch.Stop()
    if ($Script:StopWatch.IsRunning) { $Script:StopWatch.Stop() }

    # Special case where Invoke-ImageProcess might not have run.
    if (
        (($PSCmdlet.ParameterSetName -eq 'SingleFormat') -and $webp) -and
        ($webpfiles.Count -eq 0)
    ) {
        Format-TimeSpan -TimeSpan $Script:StopWatch.Elapsed
    }
    elseif (
        (($PSCmdlet.ParameterSetName -eq 'BatchProcess') -and $all) -and
        (($jpgfiles.Count -eq 0) -and ($pngfiles.Count -eq 0))
    ) {
        Format-TimeSpan -TimeSpan $Script:StopWatch.Elapsed
    }
    elseif (
        (($PSCmdlet.ParameterSetName -eq 'BatchProcess') -and $complex) -and
        (($jpgfiles.Count -eq 0) -and ($pngfiles.Count -eq 0))
    ) {
        Format-TimeSpan -TimeSpan $Script:StopWatch.Elapsed
    }
    elseif (
        (($PSCmdlet.ParameterSetName -eq 'BatchProcess') -and $trans) -and
        ($jpgfiles.Count -eq 0) -and ($no_ppi -or ($pngfiles.Count -eq 0)) # chekc jpgs first, then check pngs, but only necessary if no_ppi is not set
    ) {
        Format-TimeSpan -TimeSpan $Script:StopWatch.Elapsed
    }

    # Check for errors and processing status
    $hasErrors = (
        ($Error.Count -gt 0) -or 
        ($Global:Error.Count -gt 0 )
    )

    if ($hasErrors) {
        Write-Host "Processing did not complete normally." -ForegroundColor Red
    } else {
        Write-Host "Image processing complete." -ForegroundColor Green
    }

    # Clear errors for next run
    if ($Error) { $Error.Clear() }
    if ($Global:Error) { $Global:Error.Clear() }
}

Set-Alias -Name ma -Value Edit-Pictures