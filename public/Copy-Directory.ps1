<#
.SYNOPSIS
    复制目录结构到目标位置。
.DESCRIPTION
    将源目录的完整目录结构复制到目标位置，仅创建文件夹结构而不复制文件。
.PARAMETER Path
    源目录的路径。
.PARAMETER Destination
    目标目录的路径。
.EXAMPLE
    Copy-Directory -Path "C:\SourceFolder" -Destination "D:\DestFolder"
    将C:\SourceFolder目录的文件夹结构复制到D:\DestFolder。
.NOTES
    别名: cpdir
#>
function Copy-Directory {
    [CmdletBinding()]
    param (
        [String] $Path,
        [String] $Destination
    )
    
    $Path = Resolve-Path -Path $Path
    $Destination = Resolve-Path -Path $Destination

    $SourceDir = Get-ChildItem -Path $Path -Recurse -Directory
    foreach ($dir in $SourceDir) {
        $DestinationDir = $dir.FullName.Replace($Path, $Destination)
        if (!(Test-Path -Path $DestinationDir)) {
            New-Item -Path $DestinationDir -ItemType Directory -Force
        }
    }
}

Set-Alias -Name cpdir -Value Copy-Directory