using namespace System.Management.Automation

<#
.SYNOPSIS
    Hardware-accelerated video transcoding to HEVC/H.265 using FFMPEG.
.DESCRIPTION
    Batch video transcoding using FFMPEG with NVIDIA GPU acceleration.
    Uses HEVC/H.265 encoder (NVENC) with high quality preset and 2-pass encoding.
    Audio streams will be copied directly.
    Output files will be converted to MP4 format.
.PARAMETER BitRate
    Average video bitrate in Mbps (e.g., 12 means 12Mbps). Specify manually. Value can be an integer between 1 and 100.
.PARAMETER SourcePath
    Source video files directory. Defaults to current directory.
.PARAMETER DestinationPath
    Output files directory. Defaults to parent directory of source.
.EXAMPLE
    Convert-Videos -BitRate 12
    Converts all video files in current directory to H.265 format with 12Mbps average bitrate.
.EXAMPLE
    Convert-Videos -BitRate 8 -SourcePath "D:\Videos" -DestinationPath "E:\Output"
    Converts videos from D:\Videos directory and saves to E:\Output directory.
.NOTES
    - Requires FFMPEG installed and added to system PATH
    - Requires NVIDIA GPU with NVENC support
    - Output files will use the same filename as source
    - Does not process subdirectories recursively
    - Supported input formats: mp4, mkv, avi, mov, wmv, webm
    - Output format: mp4.
    - ❗ May not preserve subtitles, chapters, and other container-specific features.
.LINK
    https://github.com/Hanluica-Functions
#>
function Convert-Videos {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateRange(1, 100)]
        [int]$BitRate,

        [Parameter()]
        [string]$SourcePath = ".",

        [Parameter()]
        [string]$DestinationPath = ".."
    )

    # Validate paths
    # Validate SourcePath
    try {
        $SourcePath = Join-Path -Path "$((Resolve-Path $SourcePath).ProviderPath)" -ChildPath "*"
    }
    catch {
        Write-Error "Unexpected error occurred while validating Source Path: $($_.Exception.Message)"
        return
    }
    # Validate DestinationPath
    $resolvedDestPath = Resolve-OrCreateDirectory -Path $DestinationPath
    if (-not $resolvedDestPath) {
        # If the Resolve-OrCreateDirectory function fails, it will return $null, in which case we should return.
        return
    }
    $DestinationPath = $resolvedDestPath

    # Validate ffmpeg
    $ffmpegPath = $null
    try {
        $ffmpeg = Get-Command "ffmpeg.exe" -CommandType Application -ErrorAction Stop
        $ffmpegPath = $ffmpeg.Source
        Write-Host "🔍 Found FFMPEG executable file at: '$ffmpegPath'" -ForegroundColor Blue
    }
    catch [CommandNotFoundException] {
        Write-Error "FFMPEG not found. Please ensure ffmpeg.exe exists and its location is included in the PATH environment variable."
        return
    }
    catch {
        # Catch any other exceptions that may occur.
        Write-Error "Unexpected error occurred while locating ffmpeg.exe: $($_.Exception.Message)"
        return
    }

    # Get video files
    $videos = Get-ChildItem -Path $SourcePath -File -Include @("*.mp4", "*.mkv", "*.avi", "*.mov", "*.wmv", "*.webm")
    if ($videos.Count -eq 0) {
        Write-Warning "No video files found in path: ${SourcePath}"
        return
    }

    # Calculate encoding parameters
    $maxRate = $BitRate * 1.5
    $bufSize = $BitRate * 2

    # Start Process
    Write-Host "🔍 Found $($videos.Count) video files, starting processing..." -ForegroundColor Blue
    Write-Host "❗ Warning: Converting to MP4 may remove subtitles and embedded sources.`n" -ForegroundColor Yellow
    $count = 0
    foreach ($video in $videos) {
        $outputPath = Join-Path -Path "${DestinationPath}" -ChildPath "$([System.IO.Path]::GetFileNameWithoutExtension($video.Name)).mp4"

        $ffmpegArgs = @(
            "-y"                                  # Overwrite output files
            "-i",            "$($video.FullName)" # Input file
            "-c:v",          "hevc_nvenc"         # Use NVENC H.265 encoder
            "-preset",       "p5"                 # Encoding preset: Slow
            "-tune",         "hq"                 # Tuning: High quality
            "-rc",           "vbr"                # Rate control: Variable bitrate
            "-b:v",          "${BitRate}M"        # Average bitrate
            "-maxrate",      "${maxRate}M"        # Maximum bitrate
            "-bufsize",      "${bufSize}M"        # Buffer size
            "-multipass",    "2"                  # Two-pass encoding: Full frame
            "-rc-lookahead", "32"                 # Look-ahead frames: 32
            "-spatial-aq",   "1"                  # Spatial adaptive quantization: On
            "-temporal-aq",  "1"                  # Temporal adaptive quantization: On
            "-c:a",          "copy"               # Audio stream: Direct copy
            "${outputPath}"                       # Output file
        )

        & $ffmpegPath $ffmpegArgs

        $count++

        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n🔄️ $($count) in $($videos.Count) files processed successfully: `n   $($video.Name)`n-> ${outputPath}`n" -ForegroundColor Blue
        } else {
            Write-Warning "One task failed with FFMPEG exit code $LASTEXITCODE."
        }
    }
}
