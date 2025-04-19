<#
.SYNOPSIS
    使用FFMPEG进行硬件加速的HEVC/H.265编码视频转码。
.DESCRIPTION
    使用FFMPEG对指定目录中的视频文件进行批量转码，开启NVIDIA GPU加速。
    使用HEVC/H.265编码器(NVENC)，支持高质量预设和2-pass编码。
    音频流将直接复制。
.PARAMETER BitRate
    视频平均码率，以Mbps为单位（例如：12表示12Mbps）。必须手动指定。值可为1到100之间的整数。
.PARAMETER SourcePath
    源视频文件所在目录。默认为当前目录。
.PARAMETER DestinationPath
    输出文件保存目录。默认为源目录的上一层目录。
.EXAMPLE
    Convert-Videos -BitRate 12
    将当前目录下的所有视频文件转码为H.265格式，平均码率12Mbps。
.EXAMPLE
    Convert-Videos -BitRate 8 -SourcePath "D:\Videos" -DestinationPath "E:\Output"
    将D:\Videos目录下的视频转码后保存到E:\Output目录。
.NOTES
    - 需要安装FFMPEG且添加到系统PATH
    - 需要NVIDIA显卡并支持NVENC
    - 输出文件将使用与源文件相同的文件名
    - 不递归处理子目录
    - 支持的输入格式：mp4, mkv, avi, mov, wmv
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
    
    # 验证路径
    try {
        $SourcePath = [string](Resolve-Path $SourcePath) + "\*"
        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }
        $DestinationPath = Resolve-Path $DestinationPath
    }
    catch {
        Write-Error "路径验证失败：$_"
        return
    }
    
    # 检查ffmpeg
    try {
        ffmpeg.exe -version | Out-Null
    }
    catch {
        Write-Error "未找到ffmpeg。请确保ffmpeg已安装且已添加到PATH中。"
        return
    }
    $ffmpeg = "ffmpeg.exe"
    
    # 获取视频文件
    $videos = Get-ChildItem -Path $SourcePath -File -Include @("*.mp4", "*.mkv", "*.avi", "*.mov", "*.wmv")
    if ($videos.Count -eq 0) {
        Write-Warning "在 $SourcePath 中未找到视频文件。"
        return
    }
    
    # 计算编码参数
    $maxRate = $BitRate * 1.5     # 最大码率 = 平均码率 * 1.5
    $bufSize = $BitRate * 2     # 缓冲大小 = 平均码率 * 2
    
    # 开始处理
    Write-Host "找到 $($videos.Count) 个视频文件，开始处理..." -ForegroundColor Cyan
    $count = 0
    foreach ($video in $videos) {
        $outputPath = Join-Path -Path "${DestinationPath}" -ChildPath "$($video.Name)"
        
        $ffmpegArgs = @(
            "-y"                           # 自动覆盖输出文件
            "-i", "$($video.FullName)"     # 输入文件
            "-c:v", "hevc_nvenc"           # 使用NVENC H.265编码器
            "-preset", "p5"                # 编码预设：Slow
            "-tune", "hq"                  # 调优：高质量
            "-rc", "vbr"                   # 码率模式：可变码率
            "-b:v", "${BitRate}M"          # 平均码率
            "-maxrate", "${maxRate}M"      # 最大码率
            "-bufsize", "${bufSize}M"      # 缓冲大小
            "-multipass", "2"              # 两遍编码：全画幅
            "-rc-lookahead", "32"          # 前向分析帧数：32
            "-spatial-aq", "1"             # 空间自适应量化：开启
            "-temporal-aq", "1"            # 时间自适应量化：开启
            "-c:a", "copy"                 # 音频流：直接复制
            "$($outputPath)"               # 输出文件
        )
        
        & $ffmpeg $ffmpegArgs

        $count++
        Write-Host "[Convert-Videos @ pwsh] $($count) / $($videos.Count) 文件已处理：`n    $($video.Name)`n -> $($outputPath)" -ForegroundColor Green
    }
}