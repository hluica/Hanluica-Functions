function Format-TimeSpan {
    [CmdletBinding()]
    param(
        [TimeSpan] $TimeSpan
    )
    $Elapsed = [String]::Format("{0:00}:{1:00}:{2:00}.{3:00}", $TimeSpan.Hours, $TimeSpan.Minutes, $TimeSpan.Seconds, $TimeSpan.Milliseconds / 10)
    Write-Host "Task Runtime: $Elapsed" -ForegroundColor Yellow
}