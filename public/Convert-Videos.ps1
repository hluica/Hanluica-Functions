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
    - Supported input formats: mp4, mkv, avi, mov, wmv
    - Output format: mp4.
    - ❗ May not preserve subtitles, chapters, and other container-specific features
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
    try {
        $SourcePath = [string](Resolve-Path $SourcePath) + "\*"
        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }
        $DestinationPath = Resolve-Path $DestinationPath
    }
    catch {
        Write-Error "Path validation failed: $_"
        return
    }
    
    # Validate ffmpeg
    try {
        ffmpeg.exe -version | Out-Null
    }
    catch {
        Write-Error "FFMPEG not found. Please ensure FFMPEG is installed and added to PATH."
        return
    }
    $ffmpeg = "ffmpeg.exe"
    
    # Get video files
    $videos = Get-ChildItem -Path $SourcePath -File -Include @("*.mp4", "*.mkv", "*.avi", "*.mov", "*.wmv")
    if ($videos.Count -eq 0) {
        Write-Warning "No video files found in path: ${SourcePath}"
        return
    }
    
    # Calculate encoding parameters
    $maxRate = $BitRate * 1.5
    $bufSize = $BitRate * 2
    
    # Start Process
    Write-Host "🔍 Found $($videos.Count) video files, starting processing..." -ForegroundColor Blue
    Write-Host "❗ Warning: Converting to MP4 may remove subtitles and embedded sources. " -ForegroundColor Yellow
    $count = 0
    foreach ($video in $videos) {
        $outputPath = Join-Path -Path "${DestinationPath}" -ChildPath "$([System.IO.Path]::GetFileNameWithoutExtension($video.Name)).mp4"
        
        $ffmpegArgs = @(
            "-y"                           # Overwrite output files
            "-i", "$($video.FullName)"     # Input file
            "-c:v", "hevc_nvenc"           # Use NVENC H.265 encoder
            "-preset", "p5"                # Encoding preset: Slow
            "-tune", "hq"                  # Tuning: High quality
            "-rc", "vbr"                   # Rate control: Variable bitrate
            "-b:v", "${BitRate}M"          # Average bitrate
            "-maxrate", "${maxRate}M"      # Maximum bitrate
            "-bufsize", "${bufSize}M"      # Buffer size
            "-multipass", "2"              # Two-pass encoding: Full frame
            "-rc-lookahead", "32"          # Look-ahead frames: 32
            "-spatial-aq", "1"             # Spatial adaptive quantization: On
            "-temporal-aq", "1"            # Temporal adaptive quantization: On
            "-c:a", "copy"                 # Audio stream: Direct copy
            "$($outputPath)"               # Output file
        )
        
        & $ffmpeg $ffmpegArgs

        $count++
        Write-Host "🔄️ $($count) in $($videos.Count) files processed: `n   $($video.Name)`n-> $($outputPath)" -ForegroundColor Blue
    }
}
