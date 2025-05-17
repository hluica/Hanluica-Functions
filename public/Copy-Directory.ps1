<#
.SYNOPSIS
    Copy directory structure to destination path.
.DESCRIPTION
    Creates a directory structure mirror at the destination path without copying any files.
    This cmdlet only creates empty folders while maintaining the same hierarchy as the source.
.PARAMETER Path
    Source directory path to copy structure from.
.PARAMETER Destination
    Destination path where the directory structure will be created.
.EXAMPLE
    Copy-Directory -Path "C:\SourceFolder" -Destination "D:\DestFolder"
    Creates empty folder structure from C:\SourceFolder to D:\DestFolder.
.NOTES
    Alias: cpdir
.LINK
    https://github.com/Hanluica-Functions
#>
function Copy-Directory {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        [ValidateScript({
                Test-Path $_ -PathType Container
            })]
        [String] $Path,

        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [ValidateNotNullOrEmpty()]
        [String] $Destination
    )

    try {
        # Resolve full paths using Resolve-OrCreateDirectory
        $Path = Resolve-OrCreateDirectory -Path $Path
        $Destination = Resolve-OrCreateDirectory -Path $Destination

        # Get all subdirectories
        $SourceDirs = Get-ChildItem -Path $Path -Recurse -Directory

        # Create directory structure
        foreach ($dir in $SourceDirs) {
            $DestinationDir = $dir.FullName.Replace($Path, $Destination)
            Resolve-OrCreateDirectory -Path $DestinationDir | Out-Null
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Created directory: $DestinationDir"
        }

        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Directory structure copied successfully"
    }
    catch {
        Write-Error "Failed to copy directory structure: $_"
    }
}

Set-Alias -Name cpdir -Value Copy-Directory