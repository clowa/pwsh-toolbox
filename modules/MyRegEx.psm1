
function Get-DomainLinks
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


function Rename-ContentWithRegEx
{
    <#
    .SYNOPSIS
    The `Rename-ContentWithRegEx` replaces regex filtered string within a file.
    
    .DESCRIPTION
    The `Rename-ContentWithRegEx` cmdlet accepts a hashtable with regex keys and the replace value as value of the regex key.
    You can replace multiple stings and filter with multiple regexs.
    
    .PARAMETER Path
    The path to the target file you want to replace strings in.
    
    .PARAMETER Destination
    The path to the new file with the replaced strings.
    
    .PARAMETER Replace
    The hashtable with regex keys and replace stings as value. eg. @{'http.?:\/\/.*?\.org' = 'https://example.org'}
    
    .EXAMPLE
    Rename-ContentWithRegEx -Path ~\Downloads\db-dump.sql -Destination ~\Downloads\new-db-dump.sql -Replace @{'http.?:\/\/.*?\.org' = 'https://example.org'}

    Description
    -----------
    Replace all weblinks on top level domain .org with https://example.org

    .NOTES
    The original reason for creating this cmdlet was to replace links on a database dump with the new webserver url.
    This cmdlet loads whole file content into memory while replacements.
    
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

        # Hashtable with regex and replace value
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Replace
    )
    
    Write-Verbose "Load raw file content into memory"
    $content = (Get-Content -Path $Path -Raw) 
    foreach ($k in $Replace.Keys) {
        Write-Verbose "replace $k with $($Replace[$k])"
        $content = $content -replace $k, $Replace[$k]
    }
    Write-Verbose "Write new content to file $Destination"
    Set-Content -Path $Destination -Value $content
    Write-Verbose "Run garbage collector"
    [GC]::Collect()
}