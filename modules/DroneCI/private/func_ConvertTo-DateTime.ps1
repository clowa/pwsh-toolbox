<#
.SYNOPSIS
    Converts a unix timestamp to a DateTime object.
.DESCRIPTION
    Converts a unix timestamp to a DateTime object.
.EXAMPLE
    PS C:\> ConvertTo-DateTime -Timestamp 1638982349
    This will convert the unix timestamp to a DateTime object with value 'Wednesday, December 8, 2021 4:52:29 PM'
.INPUTS
    See paramter explaination for supported input values and switch parameters.
.OUTPUTS
    DateTime object representing the unix timestamp.
.NOTES
    This cmdlet maybe doesn't support all <CommonParameters> correctly.
#>
function ConvertTo-DateTime {
    [CmdletBinding()]
    param (
        # Unix timestamp
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Int64]
        $Timestamp
    )

    ## Throw error if argument is null
    if ( -Not $Timestamp) {
        try { throw "Invalid argument. Vaue of -Timestamp is `$null" } catch { $PSCmdlet.ThrowTerminatingError($_) }
    }

    return (New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0).AddSeconds($Timestamp)
}