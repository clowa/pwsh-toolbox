<#
.SYNOPSIS
    Join a given root URI with a given Path.
.DESCRIPTION
    This cmdlet joins a given root URI a given Path and takes care about leading or tailing '/'.
.EXAMPLE
    PS C:\> Join-DroneAPIPath -Uri "https://example.org/" -Path "/api/info/"
    Returns a new URI object representing the actual string "https://example.org/api/info". You can skip the tailing '/' of the URI
.INPUTS
    See paramter explaination for supported input values and switch parameters.
.OUTPUTS
    Returns a new URI representing the given URI Path combination.
.NOTES
    None
#>
function Join-DroneAPIPath {
    param (
        # Absolute Uri of the drone server
        [Parameter(Position = 0, Mandatory)]
        [Uri]
        $Uri,

        # Path of the API endpoint to use 
        [Parameter(Position = 1)]
        [String]
        $Path = '/'
    )

    #? Should it realy have to be a absolute path?
    if ($Uri.AbsolutePath -NE '/') {
        try { throw "Invalid argument. Vaue of -Uri has to be a root URI." } catch { $PSCmdlet.ThrowTerminatingError($_) }
    }

    [Uri]$ApiUri = $Uri.AbsoluteUri.Trim('/'), $Path.Trim('/') -join '/'

    return $ApiUri
}