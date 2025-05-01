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
        $resolvedPath = $null
        $finalPath = $null

        try {
            # 1. Resolve path to fully qualified path
            Write-Verbose "Attempting to resolve path: '$Path'"
            $resolvedPathInfo = Resolve-Path -Path $Path -ErrorAction Stop
            $resolvedPath = $resolvedPathInfo.Path
            Write-Verbose "Resolved path to: '$resolvedPath'"

            # 2. Check if path exists and verify its type
            if (Test-Path -Path $resolvedPath) {
                Write-Verbose "Path '$resolvedPath' exists."
                # Check if it's a file
                if (Test-Path -Path $resolvedPath -PathType Leaf) {
                    # If it's a file, throw an error
                    throw "The specified path '$resolvedPath' exists, but it is a file, not a directory."
                } elseif (Test-Path -Path $resolvedPath -PathType Container) {
                    # If it's a directory, this is what we want
                    Write-Verbose "Path '$resolvedPath' is an existing directory."
                    $finalPath = $resolvedPath
                } else {
                    # Path exists but type is unknown or unsupported (e.g., Junction Point, which might need additional handling)
                    # For most cases, if it's not a Leaf, assume it's Container-like
                    Write-Warning "Path '$resolvedPath' exists but its type is not explicitly 'Container'. Assuming it's directory-like."
                    $finalPath = $resolvedPath
                }
            } else {
                # 3. Path doesn't exist, create the directory
                Write-Verbose "Path '$resolvedPath' does not exist. Creating directory..."
                New-Item -ItemType Directory -Path $resolvedPath -Force -ErrorAction Stop | Out-Null
                Write-Verbose "Successfully created directory '$resolvedPath'."
                $finalPath = $resolvedPath
            }

            # 4. Return the final fully qualified path
            Write-Output $finalPath

        } catch {
            # 5. Get more specific error information
            $errorMessage = "Error processing path '$Path' (resolved to '$resolvedPath'): $($_.Exception.Message)"
            Write-Error $errorMessage
        }
    }
}