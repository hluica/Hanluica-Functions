<#
.SYNOPSIS
    Moves files from subdirectories to the current directory, prefixing them with the subdirectory name.
.DESCRIPTION
    Iterates through all immediate subdirectories of the current directory (does *not* recurse into deeper levels), moving non-txt files within them to the current directory.
    Moved files are prefixed with the name of their original subdirectory.
    Supports handling filenames with special characters.
    Displays detailed progress and error messages.
.EXAMPLE
    Move-SubdirFiles
    Moves files from all immediate subdirectories of the current directory to the current directory.
.NOTES
    - Ensure you have sufficient write permissions in the current directory.
    - It is recommended to back up important files before execution.
    - If filename conflicts occur, the target file will be automatically overwritten.
    - Alias: flatmv
.LINK
    https://github.com/Hanluica-Functions
#>
function Move-SubdirFiles {
    [CmdletBinding()]
    param()

    # Check if running with administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "⚠️ Script might require administrator privileges to run correctly"
    }

    $currentPath = Get-Location
    $dirs = Get-ChildItem -Directory
    Write-Host "🛠️ Starting processing...`n   Number of subdirectories to process: $($dirs.Count)" -ForegroundColor Magenta

    $dirs | ForEach-Object {
        $dirName = $_.Name
        # Use Join-Path to build the full path
        $dirPath = Join-Path -Path $_.FullName -ChildPath "*"
        Write-Host "Processing subdirectory: $dirPath" -ForegroundColor Cyan

        try {
            # Use the -LiteralPath parameter to ensure correct handling of special characters
            $files = Get-ChildItem -LiteralPath "$($_.FullName)" -File
            Write-Host "Number of files in the current subdirectory: $($files.Count)" -ForegroundColor Magenta

            $files | ForEach-Object {
                $newFileName = "{0}_{1}" -f $dirName, $_.Name
                $targetPath = Join-Path -Path $currentPath -ChildPath $newFileName

                try {
                    Move-Item -LiteralPath $_.FullName -Destination $targetPath -Force -ErrorAction Stop
                    Write-Host "Successfully moved file:" -ForegroundColor Green
                    Write-Host "    $($_.FullName)`n -> $targetPath"
                }
                catch {
                    Write-Error "Failed to move file: $($_.FullName)`nError message: $($_.Exception.Message)"
                }
            }
        }
        catch {
            Write-Error "Failed to process directory: $dirPath`nError message: $($_.Exception.Message)"
        }
    }

    Write-Host "Command execution completed. Please verify the results." -ForegroundColor Magenta
}

Set-Alias -Name flatmv -Value Move-SubdirFiles