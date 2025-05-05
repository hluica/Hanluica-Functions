# The module contains a collection of functions for various tasks.

# The function for copying directory structures.
. "${PSScriptRoot}\public\Copy-Directory.ps1"

# The function for truncating strings.
. "${PSScriptRoot}\public\Limit-StringLength.ps1"

# The functions for editing pictures.
. "${PSScriptRoot}\private\Format-TimeSpan.ps1"
. "${PSScriptRoot}\private\Set-Images.ps1"
. "${PSScriptRoot}\private\Invoke-ImageProcess.ps1"
. "${PSScriptRoot}\public\Edit-Pictures.ps1"

# The functions for managing VMs.
. "${PSScriptRoot}\public\Get-VMIPAddress.ps1"
. "${PSScriptRoot}\public\Set-VMPortProxy.ps1"

# The functions for testing and logging IP changes.
. "${PSScriptRoot}\private\Format-IPInfo.ps1"
. "${PSScriptRoot}\public\Show-LatestIPLog.ps1"
. "${PSScriptRoot}\private\Update-IPLog.ps1"
. "${PSScriptRoot}\public\Test-IPChange.ps1"

# The functions for converting videos.
. "${PSScriptRoot}\public\Resolve-OrCreateDirectory.ps1"
. "${PSScriptRoot}\public\Convert-Videos.ps1"

# The function for flattening directory structures.
. "${PSScriptRoot}\public\Move-SubdirFiles.ps1"

# The function for setting folder permissions.
. "${PSScriptRoot}\public\Set-WindowsAppsAcl.ps1"

# The function for managing Windows features.
. "${PSScriptRoot}\public\Set-WindowsFeatureState.ps1"