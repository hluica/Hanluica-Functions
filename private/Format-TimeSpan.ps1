function Format-TimeSpan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [TimeSpan] $TimeSpan,
        [string]$Label = "Task Runtime"
    )
    $Elapsed = [String]::Format("{0:00}:{1:00}:{2:00}.{3:00}", $TimeSpan.Hours, $TimeSpan.Minutes, $TimeSpan.Seconds, $TimeSpan.Milliseconds / 10)
    Write-Host "${Label}: ${Elapsed}" -ForegroundColor Yellow
}