function Invoke-ImageProcess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$Files,
        [Parameter(Mandatory)]
        [string]$Activity,
        [int]$ProgressId = 0,
        [Parameter(Mandatory)]
        [scriptblock]$ProcessBlock
    )

    Set-Images -Files $Files -Activity $Activity -ProgressId $ProgressId -ProcessBlock $ProcessBlock
    Format-TimeSpan -TimeSpan $Script:StopWatch.Elapsed
}