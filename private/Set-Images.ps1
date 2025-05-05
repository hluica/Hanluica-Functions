function Set-Images {
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

    # verbose ANSI color codes
    $yellow    = "`e[33m"
    $fuchsia   = "`e[35m"
    $underline = "`e[4m"
    $reset     = "`e[0m"

    $count = 0
    foreach ($file in $Files) {
        $count++
        try {
            & $ProcessBlock $file
            Write-Progress -Activity $Activity -Id $ProgressId `
                -Status "${count} / $($Files.Count) - $(Limit-StringLength -InputStrings $file.Name -MaxLength 15)" `
                -PercentComplete ($count / $Files.Count * 100)
        } catch {
            $basicErrorOutput = "Error processing file '$($file.FullName)': $($_.Exception.Message)" # for error stream
            $verboseErrorOutput = @"
❗ ${yellow}ERROR PROCESSING FILE!${reset}
   ${yellow}File   : ${underline}$($file.FullName)${reset}
   ${yellow}Message: ${reset}${fuchsia}$($_.Exception.Message)${reset}
"@ # for display in terminal
            Write-Error -Message $basicErrorOutput -ErrorAction SilentlyContinue
            Write-Host $verboseErrorOutput
        }
    }
    # Ensure progress bar closes cleanly
    Write-Progress -Activity $Activity -Id $ProgressId -Completed
}