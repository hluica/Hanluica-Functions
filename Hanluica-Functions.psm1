# The module contains a collection of functions for various tasks.

# The function for testing Administrator privileges.
. "${PSScriptRoot}\public\Test-AdminPrivilege.ps1"

# The function for truncating strings.
. "${PSScriptRoot}\public\Limit-StringLength.ps1"

# The function for file system operations.
. "${PSScriptRoot}\public\Resolve-OrCreateDirectory.ps1"
. "${PSScriptRoot}\public\Copy-Directory.ps1"
. "${PSScriptRoot}\public\Move-SubdirFiles.ps1"

# The functions for video convertion.
. "${PSScriptRoot}\public\Convert-Videos.ps1"

# The functions for image processing.
# Common helper function.
. "${PSScriptRoot}\private\Format-TimeSpan.ps1"
# Normal version.
. "${PSScriptRoot}\class\ImageProcessingTask.ps1"
. "${PSScriptRoot}\public\Edit-Pictures.ps1"
# Parallel version.
. "${PSScriptRoot}\class\ParallelImageProcessingTask.ps1"
. "${PSScriptRoot}\public\Edit-PicturesParallel.ps1"

# The functions for testing and logging IP changes.
. "${PSScriptRoot}\class\IPMonitor.ps1"
. "${PSScriptRoot}\public\Show-LatestIPLog.ps1"
. "${PSScriptRoot}\public\Test-IPChange.ps1"

# The functions for managing VMs.
. "${PSScriptRoot}\public\Get-VMIPAddress.ps1"
. "${PSScriptRoot}\public\Set-VMPortProxy.ps1"

# The function for setting WindowsApps permissions.
. "${PSScriptRoot}\public\Set-WindowsAppsAcl.ps1"

# The function for managing Windows features.
. "${PSScriptRoot}\public\Set-WindowsFeatureState.ps1"