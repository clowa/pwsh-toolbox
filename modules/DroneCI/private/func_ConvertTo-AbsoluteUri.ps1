<#
.SYNOPSIS
    Converts an given URI to an URI with an absolute path.
.DESCRIPTION
    This cmdlet converts a given URI. If the given URI doesn't has a scheme/protocol it will default to 'https'. If the given URI has a non root path is will be converted to a absolute path set to '/'.
.EXAMPLE
    PS C:\> ConvertTo-AbsoluteUri -Uri "example.org/home"
    This will return an URI object from the actual string "https://example.org/". So the scheme/protocol will be set to 'https' and the custom path will be set form '/home' to '/'.
.INPUTS
    See paramter explaination for supported input values and switch parameters.
.OUTPUTS
    Retruns a modified URI object of the given URI.
.NOTES
    This cmdlet maybe doesn't support all <CommonParameters> correctly.
#>
function ConvertTo-AbsoluteUri {
    param (
        # Uri to parse
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Uri,

        # Uri scheme to use.
        [Parameter(Position = 1)]
        [String]
        $Scheme = "https"
    )
    
    if (-Not $Uri.Scheme) {
        [Uri]$Uri = $Scheme + "://" + $uri.OriginalString
    }

    if (-Not $Uri.AbsolutePath -NE "/") {
        [Uri]$Uri = $Uri.Scheme + "://" + $Uri.Host
    }

    return $Uri
}