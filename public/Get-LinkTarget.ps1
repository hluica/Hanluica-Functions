<#
.SYNOPSIS
    Parse the target path of shortcuts, symbolic links, and similar files.
.DESCRIPTION
    This function determines the actual target location of one or more link files (such as .lnk, .url, or symbolic links).
    It prefers to use the Windows API Code Pack to parse .lnk files, supporting complex Shell Folder targets.
    If the Windows API Code Pack is not available, it falls back to using the WScript.Shell COM object.
    This function also supports resolving symbolic links, junctions, and .url Internet shortcuts.
.PARAMETER Path
    One or more file paths (string array). Can be relative or absolute paths.
    If this parameter is omitted, the function will automatically scan the current working directory for all possible link files.
    This parameter accepts pipeline input.
.EXAMPLE
    # Parse a shortcut named "My Document.lnk" in the current directory
    Get-LinkTarget -Path ".\My Document.lnk"

.EXAMPLE
    # Parse all shortcuts and links in the C:\Users\Public\Desktop directory
    Get-ChildItem "C:\Users\Public\Desktop" | Get-LinkTarget

.EXAMPLE
    # Without parameters, automatically find and parse all links in the current directory
    Get-LinkTarget

.EXAMPLE
    # Parse multiple specified shortcuts, outputting in the order provided.
    Get-LinkTarget -Path "C:\link1.lnk", "D:\data\app.url", "C:\symlink"

.OUTPUT
    An array of PSCustomObject objects, each containing LinkFile and Target properties.
    The output will be automatically formatted as a table in the console.
.NOTES
    Version: 1.0
    Dependencies: To achieve the best .lnk parsing capabilities (especially for Shell Folder), the Microsoft.WindowsAPICodePack.Shell.dll file is required.
        This DLL can be obtained from the WindowsAPICodePack-Shell NuGet package.
#>
function Get-LinkTarget {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(
            Mandatory                       = $false,
            Position                        = 0,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Path
    )

    begin {
        # --- Detect Windows API Code Pack availability ---
        if ([System.AppDomain]::CurrentDomain.GetAssemblies().Where({
            $_.GetType('Microsoft.WindowsAPICodePack.Shell.ShellFile')
        })) {
            $apiCodePackLoaded = $true
            Write-Verbose "Windows API Code Pack Shell type is available."
        } else {
            $apiCodePackLoaded = $false
            Write-Warning "Microsoft.WindowsAPICodePack.Shell assembly not found. Using fallback method to resolve .lnk files, may not recognize Shell Folder."
        }

        # --- Initialize WScript.Shell COM object (as fallback) ---
        try {
            $wshShell = New-Object -ComObject WScript.Shell -ErrorAction Stop
        }
        catch {
            if (-not $apiCodePackLoaded) {
                Write-Warning "Failed to create WScript.Shell COM object. Unable to resolve .lnk files."
            }
            $wshShell = $null
        }
    }

    process {
        # If no path is provided via parameters or pipeline, search the current directory for files
        if (-not $PSBoundParameters.ContainsKey('Path')) {
            Write-Verbose "No path provided, scanning current directory..."
            # Find all .lnk, .url files, and all types of symbolic links
            $filesToProcess = Get-ChildItem -Path (Get-Location) -File |
                Where-Object { ($_.Extension -in '.lnk', '.url') -or ($null -ne $_.LinkType) } |
                ForEach-Object { $_.FullName }
        } else {
            $filesToProcess = $Path
        }

        foreach ($file in $filesToProcess) {
            $targetPath = $null
            $errorMessage = $null

            try {
                # Expand the file path to an absolute path
                $absolutePath = Convert-Path -LiteralPath $file
                if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
                    $errorMessage = "Error: File does not exist or is not a file."
                } else {
                    $fileInfo = Get-Item -LiteralPath $absolutePath

                    # 1. Check if it's a symbolic link or junction
                    if ($null -ne $fileInfo.LinkType) {
                        $targetPath = ($fileInfo.Target | ForEach-Object { Convert-Path -LiteralPath $_ }) -join ', '
                        Write-Verbose "[$($fileInfo.Name)] is a $($fileInfo.LinkType), target is '$targetPath'."
                    }
                    # 2. Check if it's a .lnk shortcut
                    elseif ($fileInfo.Extension -eq '.lnk') {
                        # 2a. Prefer using API Code Pack
                        if ($apiCodePackLoaded) {
                            try {
                                $shellLink = [Microsoft.WindowsAPICodePack.Shell.ShellFile]::FromFilePath($absolutePath)
                                $targetPath = $shellLink.Properties.System.Link.TargetParsingPath.Value
                                Write-Verbose "[$($fileInfo.Name)] parsed using API Code Pack, target is '$targetPath'."
                            } catch {
                                $errorMessage = "API Code Pack parsing failed: $($_.Exception.Message)"
                                Write-Warning $errorMessage
                            }
                        }

                        # 2b. If API Code Pack fails or is not loaded, use WScript.Shell as a fallback
                        if (-not $targetPath -and $wshShell) {
                             try {
                                $shortcut = $wshShell.CreateShortcut($absolutePath)
                                $targetPath = $shortcut.TargetPath
                                Write-Verbose "[$($fileInfo.Name)] parsed using WScript.Shell (fallback), target is '$targetPath'."
                             } catch {
                                $errorMessage = "WScript.Shell parsing failed: $($_.Exception.Message)"
                                Write-Warning $errorMessage
                             }
                        }
                    }
                    # 3. Check if it's a .url Internet shortcut
                    elseif ($fileInfo.Extension -eq '.url') {
                        try {
                            $targetPath = (Get-Content -LiteralPath $absolutePath | Select-String -Pattern '^URL=' | Select-Object -First 1).Line.Split('=')[1]
                            Write-Verbose "[$($fileInfo.Name)] is an Internet shortcut, target is '$targetPath'."
                        } catch {
                            $errorMessage = "Parsing .url file failed: $($_.Exception.Message)"
                            Write-Warning $errorMessage
                        }
                    }
                    # 4. If it's not a known link type
                    else {
                        $errorMessage = "Not a known link or shortcut type."
                    }
                }
            }
            catch {
                $errorMessage = "An unknown error occurred while processing: $($_.Exception.Message)"
                Write-Warning $errorMessage
            }

            # Create and output result object
            $result = [PSCustomObject]@{
                LinkFile = $file
                Target   = if ($errorMessage) { $errorMessage } else { $targetPath }
            }
            $result.PSObject.TypeNames.Insert(0, 'LinkTarget')
            $result
        }
    }

    end {
        # Clean up COM objects
        if ($wshShell) {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wshShell) | Out-Null
        }
    }
}