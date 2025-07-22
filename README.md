# Hanluica-Functions

一个功能丰富的 PowerShell 模块，提供了多种实用工具函数。

A feature-rich PowerShell module providing various utility functions.

## 功能特点 | Features

所有公开函数均提供详细的英文帮助文档（Get-Help）。

All public functions come with detailed English help documentation (Get-Help).

此模块包含以下主要功能：

This module includes the following main features:

### 管理员权限检测 | Administrator Privilege Check

- `Test-AdminPrivilege`: 检测当前 PowerShell 会话是否具有管理员权限 | Check if current PowerShell session has administrator privileges

### 文件系统操作 | File System Operations
- `Copy-Directory`: 复制目录结构（不包含文件）

  Copies directory structure (without files)

- `Move-SubdirFiles`: 展平（flatten）当前目录的结构：将子目录中的文件移动到当前目录，并以子目录名作为前缀。
  - 别名 | Alias: `flatmv`
  - 只考虑深度为1的结构，即当前目录中只有一层子目录。

  Flattens current directory structure: moves files from subdirectories to current directory, using subdirectory names as prefixes.
  - Only considers depth-1 structure, i.e., only one level of subdirectories.

- `Limit-StringLength`: 限制字符串长度，超长时使用省略号
  - 支持单个或多个字符串输入
  - 支持管道输入
  - 自动计算截断位置，保持显示效果
  - 最小长度为15字符
  - 输出格式为"前缀...后缀"

  Limits string length by replacing middle part with ellipsis
  - Supports single or multiple string inputs
  - Supports pipeline input
  - Auto-calculates truncation points for balanced display
  - Minimum length is 15 characters
  - Output format is "prefix...suffix"

- `Resolve-OrCreateDirectory`: 解析或创建目录路径
  - 支持解析完整路径
  - 自动创建不存在的目录
  - 支持管道输入
  - 提供详细的操作日志与错误处理

  Resolves or creates directory paths
  - Supports full path resolution
  - Automatically creates non-existent directories
  - Supports pipeline input
  - Provides detailed operation logging & error handling

- `Get-LinkTarget`: 解析快捷方式、符号链接等文件的目标路径
  - 支持 .lnk、.url 文件和符号链接
  - 使用 Windows API Code Pack 解析快捷方式
  - 支持管道输入
  - 自动扫描当前目录（无参数时）

  Parses target paths of shortcuts, symbolic links, and similar files
  - Supports .lnk, .url files and symbolic links
  - Uses Windows API Code Pack for shortcut parsing
  - Supports pipeline input
  - Auto-scans current directory (when no parameters)

### 图像处理 | Image Processing
- `Edit-Pictures`: 批量处理图片文件 | Batch process image files
  - 支持设置 JPG/PNG 的 PPI | Supports setting PPI for JPG/PNG
  - 支持 WebP 转 PNG | Supports WebP to PNG conversion
  - 支持线性 PPI 计算 | Supports linear PPI calculation
  - 支持批量格式转换 | Supports batch format conversion
  - 提供终端文件统计与进度显示 | Provides statics on files & progress bar in terminal
  - 支持单线程与多线程双模式，自动根据文件数量切换 | Supports both single-threaded/sequential and multi-threaded/parallel modes, automatically switching based on file count
  - 别名 | Alias: `ma`

> ❕ 注意 Note
> 
> - 此函数默认使用当前工作目录，暂不提供指定操作目录的功能。
>
>   This function defaults to the current working directory, and does not provide the option to specify it.
>
> - 此函数不支持手动调节单/多线程模式，只能根据待处理文件数量自动切换。
>
>   This function does not support manual switching between single-threaded and multi-threaded modes, it automatically switches based on the number of files to process.

### 视频处理 | Video Processing
- `Convert-Videos`: 使用 FFMPEG 进行视频转码 | Video transcoding using FFMPEG
  - 启用 NVIDIA GPU 加速 | Enables NVIDIA GPU acceleration
  - 使用 HEVC/H.265 编码 | Uses HEVC/H.265 encoding
  - 支持高质量预设和2-pass编码 | Supports high-quality preset and 2-pass encoding

> ❕ 注意 Note
> 
> - 默认不提供修改编码器和关闭硬件加速功能。
> 
>   The default does not provide options to change the encoder or disable hardware acceleration.

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
- Get-LinkTarget 函数需要 Windows API Code Pack Shell 库支持（已包含在模块中）| Get-LinkTarget function requires Windows API Code Pack Shell library (included in the module)
- Convert-Videos 函数需要 FFMPEG 且需要 NVIDIA 显卡支持 | Video transcoding requires FFMPEG and NVIDIA GPU support
- Edit-Pictures Edit-PicturesParallel 函数需要 ImageSharpProcessorLib 库支持（已包含在模块中，或者参见[Github主页](https://github.com/hluica/ImageSharpProcessorLib)）| Image processing requires ImageSharpProcessorLib (included in the module; or visit the [Homepage](https://github.com/hluica/ImageSharpProcessorLib))
  - 该库由 .NET 9 生成并依赖于 SixLabors.ImageSharp，故需要 .NET 9 运行时。依赖库则已包含在模块中 | The ImageSharpProcessorLib is built with .NET 9, and dependent on SixLabors.ImageSharp (included in the module)
- Set-WindowsFeatureState 函数需要 ViveTool 支持（**未包含**在模块中）| Set-WindowsFeatureState function requires ViveTool (**not included** in the module)

## 安装 | Installation

1. 下载模块文件夹到 PowerShell 模块目录 | Download module folder to PowerShell module directory
2. 使用 Import-Module 导入 | Import using Import-Module:
```powershell
Import-Module Hanluica-Functions
```

## 使用示例 | Usage Examples

### 管理员权限检测 | Administrator Privilege Check
```powershell
# 检测当前 PowerShell 会话是否具有管理员权限 | Check if current PowerShell session has administrator privileges
Test-AdminPrivilege
```

### 复制目录结构 | Copy Directory Structure
```powershell
Copy-Directory -Path "C:\SourceFolder" -Destination "D:\DestFolder"
# 或使用别名 | Or use alias
cpdir -Path "C:\SourceFolder" -Destination "D:\DestFolder"
```

### 解析并创建路径 | Resolve and Create Directories
```powershell
# 获取 '..\New_Folder' 的完全限定路径，然后生成它（如果原本不存在） | Get fully qualified path of '..\New_Folder' , then create the folder if it doesn't exist.
Resolve-OrCreateDirectory -Path '..\New_Folder'
```

### 解析链接目标 | Parse Link Targets
```powershell
# 解析当前目录中的所有链接文件 | Parse all link files in current directory
Get-LinkTarget

# 解析指定的快捷方式文件 | Parse specific shortcut file
Get-LinkTarget -Path "C:\Users\Public\Desktop\App.lnk"

# 通过管道处理多个链接 | Process multiple links via pipeline
Get-ChildItem "C:\Links" | Get-LinkTarget
```

### 字符串处理 | String Truncation
```powershell
# 限制单个字符串长度 | Limit single string length
"This is a very long string" | Limit-StringLength -MaxLength 20
# Output: This is a...ng string
```

### 处理图片 | Image Processing
```powershell
# 设置所有 JPG 和 PNG 文件的 PPI | Set PPI for all JPG and PNG files
Edit-Pictures -all -ppi 144

# 将 JPG 转换为 PNG（保持原始 PPI） | Convert JPG to PNG (retain original PPI)
Edit-Pictures -trans -no_ppi
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

### WindowsApps 文件夹权限管理 | WindowsApps folder permission granting
```powershell
# 以管理员权限运行powershell，然后运行函数即可 | Run powersell as administrator, then type the function name.
Set-WindowsAppsAcl
```

### Windows 功能管理 | Windows Feature Management
```powershell
# 管理 Windows 功能开关 | Manage Windows feature flags
Set-WindowsFeatureState -FeatureId 41415841
```

## 更新日志 | Changelog

| Date | 更新 | Updates |
| ---- | ---- | ------- |
| 25-07-23 | 重写 Edit-Pictures 函数和 ImageProcessingTask 类，整合单线程和多线程功能并支持自动切换；弃用 Edit-PicturesParallel 函数 | Rewrote Edit-Pictures function and ImageProcessingTask class, integrating single-threaded and multi-threaded functionality with automatic switching; deprecated Edit-PicturesParallel function |
| 25-07-21 | 添加 Get-LinkTarget 函数用于解析快捷方式和符号链接。支持 Windows API Code Pack 和 WScript方案 | Added Get-LinkTarget function for parsing shortcuts and symbolic links. Supports Windows API Code Pack and WScript. |
| 25-05-20 | 添加 ImageProcessingTask 类和 Edit-Pictures 函数的多线程并行版本 | The Parallel version of ImageProcessingTask class and  Edit-Pictures function have been added |
| 25-05-12 | 更新 ImageProcessingTask 类，更改 Edit-Pictures 函数的错误处理方法 | ImageProcessingTask class has been updated, and Edit-Pictures function's error handling method has been changed |
| 25-05-11 | 添加 Test-AdminPrivilege 函数，修正几个函数的 Write-Verbose 信息 | Test-AdminPrivilege function has been added, and Write-Verbose information of some functions has been fixed |
| 25-05-08 | 添加 IPMonitor 类和几个辅助类，重构 Show-IPAddress 和 Test-IPChange 函数以使用这些类，移除不再需要的函数 | IPMonitor class and some helper classes have been added, and Show-IPAddress & Test-IPChange have been refactored with the classes |
| 25-05-07 | 添加 ImageProcessingTask 类，重构 Edit-Pictures 函数以使用该类，移除不再需要的辅助函数；更新 Format-TimeSpan 函数 | ImageProcessingTask class has been added, and Edit-Pictures function has been refactored with the class. Format-TimeSpan function has been updated |
| 25-05-05 | 添加 Limit-StringLength 函数，用于处理长文本的显示效果，并以此改进了 Set-Images 函数的进度显示 | Limit-StringLength function has been added for formatting long text display, and the process bar of Set-Images function has been improved. |
| 25-05-01 | 改进 Set-WindowsFeatureState 函数，当无 Feature ID 被修改时不再复查 ID 状态 | Set-WindowsFeatureState function has been updated to skip the final status check if no feature IDs were actually enabled. |
| 25-04-24 | 添加 Resolve-OrCreateDirectory 函数，并以此改进了 Convert-Videos 函数的逻辑 | Resolve-OrCreateDirectory function has been added, and Convert-Videos function has been improved. |
| 25-04-22 | 检查并移除了未被翻译的中文。 | Untransalted Chinese has been replaced. |
| 25-04-21 | 注释和帮助信息已翻译为英文。 | Comments and help information has been translated to English. |

## 许可证 | License

MIT License - See [LICENSE](LICENSE)
