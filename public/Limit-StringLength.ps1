<#
.SYNOPSIS
Limits the length of input strings, replacing the middle with "..." if they exceed a specified maximum length.
.DESCRIPTION
This function takes an array of strings and a maximum length. For each string:
- If its length is greater than the specified MaxLength, it truncates the string.
- If its length is less than or equal to MaxLength, it returns the string unchanged.
Truncation method:
1. Adjust MaxLength to the nearest odd number >= MaxLength (OddLength).
2. Calculate the length of the start/end segments to keep RemainLength = (OddLength - 3) / 2.
3. Keep the first and last RemainLength characters of the original string, replacing the middle part with "...".
.PARAMETER InputStrings
An array of strings to process. Can be passed via pipeline.
.PARAMETER MaxLength
The maximum desired length for the output strings. Must be 15 or greater.
It does NOT ALWAYS exatly equal to the length of the output strings. The actual truncation length might be MaxLength or MaxLength + 1 (to ensure an odd length for calculation).
.OUTPUTS
[String[]] An array of strings, with long strings truncated according to the rules.
.EXAMPLE
PS> $myStrings = "This is a very long string that needs truncation.", "Short string", "Another quite long string example for testing purposes."
PS> Limit-StringLength -InputStrings $myStrings -MaxLength 20
This is a...uncation.
Short string
Another q...purposes.
.EXAMPLE
PS> Limit-StringLength -InputStrings "12345678901234567890" -MaxLength 15
# MaxLength=15 (odd) -> OddLength=15 -> RemainLength=(15-3)/2=6
# Keep first 6: "123456"
# Keep last 6: "567890"
123456...567890
.EXAMPLE
PS> Limit-StringLength -InputStrings "12345678901234567890123" -MaxLength 16
# MaxLength=16 (even) -> OddLength=17 -> RemainLength=(17-3)/2=7
# Keep first 7: "1234567"
# Keep last 7: "7890123"
1234567...7890123
.NOTES
The final truncated string length will be (2 * RemainLength) + 3, which equals to OddLength.
#>
function Limit-StringLength {
    [CmdletBinding()]
    [OutputType([String[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String[]]$InputStrings,

        [Parameter(Mandatory = $true)]
        [ValidateRange(15, [int]::MaxValue)] # There's no need to limit the string shorter than 15 characters.
        [int]$MaxLength
    )

    process {
        $OddLength = if ($MaxLength % 2 -eq 0) { $OddLength = $MaxLength + 1 } else { $MaxLength }
        # $OddLength will be the nearest odd number >= $MaxLength

        $RemainLength = ($OddLength - 3) / 2
        # Since $OddLength is odd, (OddLength - 3) is even, $RemainLength will be an integer.

        foreach ($string in $InputStrings) {
            if ($string.Length -gt $MaxLength) {

                $start = $string.Substring(0, $RemainLength)
                $end = $string.Substring($string.Length - $RemainLength)

                $truncatedString = "${start}...${end}"
                Write-Output $truncatedString
            } else {
                Write-Output $string
            }
        }
    }
}