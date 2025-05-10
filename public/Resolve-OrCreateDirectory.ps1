<#
.SYNOPSIS
    Resolves a path and creates the directory if it doesn't exist.
.DESCRIPTION
    The Resolve-OrCreateDirectory function takes a path string and performs the following operations:
    1. Resolves the path to a fully qualified path
    2. Validates if the path exists and is a directory
    3. Creates the directory if it doesn't exist
    4. Returns the fully qualified path of the directory

    The function supports pipeline input and provides verbose output for tracking the operation process.
.PARAMETER Path
    Specifies the path to resolve or create. This parameter is mandatory and accepts pipeline input.
    The path can be relative or absolute.
.INPUTS
    System.String
    You can pipe a string that contains the path to this function.
.OUTPUTS
    System.String
    Returns the fully qualified path of the resolved or created directory.
    If the required dictionary does not exist, it will be created.
.EXAMPLE
    PS> Resolve-OrCreateDirectory -Path "C:\Temp\NewFolder"
    # Creates the directory if it doesn't exist and returns the full path
    C:\Temp\NewFolder
.EXAMPLE
    PS> "C:\Temp\Folder1", "C:\Temp\Folder2" | Resolve-OrCreateDirectory
    # Creates multiple directories using pipeline input
    C:\Temp\Folder1
    C:\Temp\Folder2
.LINK
    https://github.com/Hanluica-Functions
#>
function Resolve-OrCreateDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]$Path
    )

    process {
        $absolutePath = $null

        try {
            # 1. Resolve path to fully qualified path
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Attempting to resolve path: '$Path'"
            if ([System.IO.Path]::IsPathRooted($Path)) {
                $absolutePath = $Path
            } else {
                $absolutePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PWD.Path, $Path))
            }
            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Resolved to absolute path: '$absolutePath'"

            # 2. Check if path exists and verify its type
            if (Test-Path -Path $absolutePath) {
                Write-Verbose "[$($MyInvocation.MyCommand.Name)] Path '$absolutePath' exists."
                if (Test-Path -Path $absolutePath -PathType Leaf) { # If it's a file...
                    # If it's a file, throw an error
                    throw "The specified path '$absolutePath' exists, but it is a file, not a directory."
                } elseif (Test-Path -Path $absolutePath -PathType Container) { # If it's a directory...
                    # If it's a directory, this is what we want
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Path '$absolutePath' is an existing directory."
                } else { # If path exists but type is unknown or unsupported, e.g., Junction Point...
                    # For most cases, if it's not a Leaf, assume it's Container-like
                    Write-Warning "Path '$absolutePath' exists but its type is not explicitly 'Container'. Assuming it's directory-like."
                }
            } else {
                # 3. Path doesn't exist, create the directory
                Write-Verbose "[$($MyInvocation.MyCommand.Name)] Path '$absolutePath' does not exist. Creating directory..."
                New-Item -ItemType Directory -Path $absolutePath -Force -ErrorAction Stop | Out-Null
                Write-Verbose "[$($MyInvocation.MyCommand.Name)] Successfully created directory '$absolutePath'."
            }

            # 4. Return the final fully qualified path
            Write-Output $absolutePath

        } catch {
            # 5. Get more specific error information
            $errorMessage = "Error processing path '$Path' (resolved to '$absolutePath'): $($_.Exception.Message)"
            Write-Error $errorMessage
        }
    }
}