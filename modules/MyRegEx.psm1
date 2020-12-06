
function Get-DomainLinks ()
{
    <#
    .SYNOPSIS
    The `Get-DomainLinks` cmdlet collects all http links for the given domains in a new file.

    .DESCRIPTION
    The `Get-DomainLinks` cmdlet collects all http links for the given domains in file provided by -Path in a new file provided by -Destination.

    .PARAMETER Path
    Path to the file to be searched.

    .PARAMETER Destination
    Path to the file with the urls found

    .PARAMETER Domains
    Array of domains to be searched for

    .PARAMETER PassThru
    Pass results through the pipeline

    .EXAMPLE
    Get-DomainLinks -Path ./SQL-Dump-01-01-2020.sql -Destination ./LinksIn_SQL-Dump-01-01-2020.txt -Domains @("example.org", "example.lan", "example.local")
    
    Description
    ----------- 
    Collect links within a file in another file. Results are saved in ./LinksIn_SQL-Dump-01-01-2020.txt 

    .EXAMPLE
    Get-DomainLinks -Path ./SQL-Dump-01-01-2020.sql  -Domains @("example.org", "example.lan", "example.local") -PassThru | Write-Output
    
    Sample output
    -----------
    http://example.lan/src/jquery/images/sort_both.gif
    https://webserver.example.lan/src/jquery/images/sort_down.gif
    https://wiki.sport-thieme.lan/src/jquery/images/sort_up.gif
    
    Description
    ----------- 
    Collect links within a file and pass each object through the pipeline.

    .NOTES
    The original reason for creating this cmdlet was to replace links to local resources on a database dump
    #>
    [CmdletBinding()]
    param (
        # Path to file
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (Test-Path -Path $_ -Type Leaf)
                {
                    return $true
                }
                else
                {
                    throw "Provided file doesn't exists."
                }
            }
        )]
        [String]
        $Path,

        # Destination file with all found regex matches
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (Test-Path -Path $_ -IsValid -PathType Leaf)
                {
                    if (Test-Path -Path $_)
                    {
                        Write-Verbose "Move $($_) to $($_ + ".bak")"
                        $_ | Move-Item -Destination ($_ + ".bak")
                    }
                    Write-Verbose "Create file $($_)"
                    New-Item -Path $_ -ItemType File > $null
                }
                else
                {
                    throw "Provided argument doesn't seems to be a valid leaf."
                }
                return $true
            }
        )]
        [String]
        $Destination,

        # List of domain names
        [Parameter()]
        [String[]]
        $Domains = @("sport-thieme.lan", "thieme.ad"),

        # Parameter help description
        [Parameter()]
        [Switch]
        $PassThru
    )

    foreach ($d in $Domains)
    {
        # escape each domain in array
        Write-Verbose "Escape domain $d"
        $esc_domain = [Regex]::Escape($d)
        Write-Verbose "Add $esc_domain to regex collection"
        # add escaped domain regex to array
        $regex_array += "http.?:\/\/(?:\w){0,25}\.$($esc_domain)(?:\/.*?\.(?:\w){3,4})?"
    }
    #$regex = "http:\/\/osxap01\.sport-thieme\.lan.*?\.(?:\w){3,4}"
    # general regex collection for internal domain
    #$regex_array = @("http.?:\/\/(?:\w){0,25}\.sport-thieme.lan(?:\/.*?\.(?:\w){3,4})?", "http.?:\/\/(?:\w){0,25}\.thieme.ad(?:\/.*?\.(?:\w){3,4})?")
    # regex collection without groupwise links
    #$regex_array = @("http.?:\/\/(?:\w){0,25}\.sport-thieme.lan(?:(?:\/gw\/webacc)|(?:\/.*?\.(?:[A-Za-z]){3,4}))?", "http.?:\/\/(?:\w){0,25}\.thieme.ad(?:\/.*?\.(?:[A-Za-z]){3,4})?")

    foreach ($regex in $regex_array)
    {
        Write-Verbose "Search $regex in $Path - results are saved in $Destination"

        Select-String -Path $Path -Pattern $regex -AllMatches |  ForEach-Object { $_.Matches.Value } | Sort-Object -Unique | ForEach-Object {
            if ($PassThru)
            {
                return $_
            }
            else
            {
                $_ >> $Destination
            }
        }        
    }
}