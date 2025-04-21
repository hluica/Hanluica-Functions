# Hanluica-Functions

一个功能丰富的 PowerShell 模块，提供了多种实用工具函数。

A feature-rich PowerShell module providing various utility functions.

## 功能特点 | Features

所有公开函数均提供详细的英文帮助文档（Get-Help）。

All public functions come with detailed English help documentation (Get-Help).

此模块包含以下主要功能：

This module includes the following main features:

### 文件系统操作 | File System Operations
- `Copy-Directory`: 复制目录结构（不包含文件）
  
  Copies directory structure (without files)

- `Move-SubdirFiles`: 展平（flatten）当前目录的结构：将子目录中的文件移动到当前目录，并以子目录名作为前缀。
  - 别名 | Alias: `flatmv`
  - 只考虑深度为1的结构，即当前目录中只有一层子目录。
  
  Flattens current directory structure: moves files from subdirectories to current directory, using subdirectory names as prefixes.
  - Only considers depth-1 structure, i.e., only one level of subdirectories.

### 图像处理 | Image Processing
- `Edit-Pictures`: 批量处理图片文件 | Batch process image files
  - 支持设置 JPG/PNG 的 PPI | Supports setting PPI for JPG/PNG
  - 支持 WebP 转 PNG | Supports WebP to PNG conversion
  - 支持线性 PPI 计算 | Supports linear PPI calculation
  - 支持批量格式转换 | Supports batch format conversion
  - 别名 | Alias: `ma`
  - 提供终端文件统计与进度显示 | Provides statics on files & progress bar in terminal

### 视频处理 | Video Processing
- `Convert-Videos`: 使用 FFMPEG 进行视频转码 | Video transcoding using FFMPEG
  - 启用 NVIDIA GPU 加速 | Enables NVIDIA GPU acceleration
  - 使用 HEVC/H.265 编码 | Uses HEVC/H.265 encoding
  - 支持高质量预设和2-pass编码 | Supports high-quality preset and 2-pass encoding

### 虚拟机管理 | VM Management
- `Get-VMIPAddress`: 获取指定虚拟机的 IP 地址 | Get IP address of specified VM
- `Set-VMPortProxy`: 配置虚拟机的端口转发 | Configure port forwarding for VM

### IP 地址监控 | IP Address Monitoring
- `Test-IPChange`: 检查并记录 IP 地址变化 | Check and record IP address changes
- `Show-LatestIPLog`: 显示最新的 IP 地址记录 | Show latest IP address records

### Windows 系统管理 | Windows System Management
- `Set-WindowsAppsAcl`: 设置 WindowsApps 文件夹的访问权限 | Set access permissions for WindowsApps folder
- `Set-WindowsFeatureState`: 使用 ViveTool 管理 Windows 功能开关 | Manage Windows feature flags using ViveTool
- 这些函数提供了详细且易读的终端信息。 | These functions provide detailed and understandable information in terminal

## 系统要求 | System Requirements

- PowerShell 7.0 或更高版本 | PowerShell 7.0 or higher
- 部分功能仅限于 Windows 操作系统 | Some features are Windows-only
- 部分功能需要管理员权限 | Some features require administrator privileges
- 视频转码功能需要 FFMPEG 且需要 NVIDIA 显卡支持 | Video transcoding requires FFMPEG and NVIDIA GPU support
- 图像处理功能需要 ImageSharpProcessorLib 库支持（已包含在模块中，或者参见[Github主页](https://github.com/hluica/ImageSharpProcessorLib)）| Image processing requires ImageSharpProcessorLib (included in the module; or visit the [Homepage](https://github.com/hluica/ImageSharpProcessorLib))
  - 该库由 .NET 9 生成并依赖于 SixLabors.ImageSharp，故需要 .NET 9 运行时。依赖库则已包含在模块中 | The ImageSharpProcessorLib is built with .NET 9, and dependent on SixLabors.ImageSharp (included in the module)

## 安装 | Installation

1. 下载模块文件夹到 PowerShell 模块目录 | Download module folder to PowerShell module directory
2. 使用 Import-Module 导入 | Import using Import-Module:
```powershell
Import-Module Hanluica-Functions
```

## 使用示例 | Usage Examples

### 复制目录结构 | Copy Directory Structure
```powershell
Copy-Directory -Path "C:\SourceFolder" -Destination "D:\DestFolder"
# 或使用别名 | Or use alias
cpdir -Path "C:\SourceFolder" -Destination "D:\DestFolder"
```

### 处理图片 | Process Images
```powershell
# 设置所有 JPG 和 PNG 文件的 PPI | Set PPI for all JPG and PNG files
Edit-Pictures -all -ppi 144

# 将 JPG 转换为 PNG（保持原始 PPI） | Convert JPG to PNG (retain original PPI)
Edit-Pictures -trans -no_ppi

# 使用别名处理单个格式 | Use alias to process single format
ma -jpg -ppi 300
```

### 视频转码 | Video Transcoding
```powershell
# 以 12Mbps 的码率转码当前目录的视频 | Transcode videos in current directory at 12Mbps bitrate
Convert-Videos -BitRate 12

# 指定源目录和目标目录 | Specify source and destination directories
Convert-Videos -BitRate 8 -SourcePath "D:\Videos" -DestinationPath "E:\Output"
```

### 虚拟机操作 | VM Operations
```powershell
# 获取虚拟机 IP 并设置端口转发 | Get VM IP and set port forwarding
Get-VMIPAddress -VMName "Ubuntu" | Set-VMPortProxy -Port 2222
```

### IP 地址监控 | IP Address Monitoring
```powershell
# 检查 IP 变化并显示状态 | Check IP changes and display status
Test-IPChange -ShowChange

# 显示最新的 IP 记录 | Show latest IP records
Show-LatestIPLog
```

### Windows 功能管理 | Windows Feature Management
```powershell
# 管理 Windows 功能开关 | Manage Windows feature flags
Set-WindowsFeatureState -FeatureId 41415841
```

## 更新日志 | Changelog

- 25-04-22 | 检查并移除了未被翻译的中文。 | Untransalted Chinese has been replaced.
- 25-04-21 | 注释和帮助信息已翻译为英文。 | Comments and help information has been translated to English.

## 许可证 | License

MIT License - 见 [LICENSE](LICENSE) 文件 | See [LICENSE](LICENSE) file
