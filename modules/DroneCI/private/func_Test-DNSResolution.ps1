<#
.SYNOPSIS
    Test DNS resolution of URI
.DESCRIPTION
    Checks if the DNS host of the URI can be resolved.
.EXAMPLE
    PS C:\> Test-APIEndpoint -Uri "http://google.de"
    If DNS is configured correctly this returns $true.
.INPUTS
    See paramter explaination for supported input values and switch parameters.
.OUTPUTS
    Returns $true if DNS host can be resolved, otherwise $false.
.NOTES
    This cmdlet maybe doesn't support all <CommonParameters> correctly.
    The input has to be a valide URI with an leading protocol/scheme. 
#>
function Test-DNSResolution {
    param (
        # URI of API endpoint
        [Parameter(Position = 0, Mandatory)]
        [Uri]
        $Uri
    )

    try {
        [System.Net.Dns]::GetHostEntry($Uri.DnsSafeHost) | Out-Null
        $result = $true
    } catch {
        $result = $false
    }

    return $result
}