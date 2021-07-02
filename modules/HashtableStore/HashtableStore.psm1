
function Export-Hashtable
{
    <#
    .SYNOPSIS
    The `Export-Hashtable` cmdlet exports a hashtable as json.
    
    .DESCRIPTION
    The `Export-Hashtable` cmdlet exports the given hashtable to the given path.
    
    .PARAMETER Hashtable
    The hashtable you want to save to disk.
    
    .PARAMETER Path
    Path to the new json file.
    
    .EXAMPLE
    Export-Hashtable -Hashtable @{'key' = 'value'} -Path ~\export-hashtable.json'

    .LINK
    https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-hashtable?view=powershell-7.1#saving-a-nested-hashtable-to-file
    #>
    [CmdletBinding()]
    param (
        # hashtable object to save
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Hashtable,

        # Path to file
        # accepts only json files
        # add .bak if file already exists
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if (Test-Path -Path $_ -IsValid)
                {
                    if ([IO.Path]::GetExtension($_) -ne ".json") {
                        throw "File must have extension .json"
                    }
                    elseif (Test-Path -Path $_)
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
            })]
        [String]
        $Path
    )

    $Hashtable | ConvertTo-Json | Set-Content -Path $Path
}

function Import-HashtableFromJson
{
    <#
    .SYNOPSIS
    The `Import-HashtableFromJson` cmdlet imports a hashtable from a json file.
    
    .DESCRIPTION
    The `Import-HashtableFromJson` cmdlet imports a hashtable from a json file.
    
    .PARAMETER Path
    The path to the json file you want to import a hashtable from.
    
    .EXAMPLE
    Import-HashtableFromJson -Path ~\export-hashtable.json

    Description
    -----------
    Importing a hashtable from a json file

    Sample output
    -----------
    Name    Value
    ----    -----
    key1    value1
    key2    value2
    
    .LINK
    https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-hashtable?view=powershell-7.1#converting-json-to-hashtable
    #>
    #>
    param (
        # Path to file
        # accepts only json files
        # file must exist
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (Test-Path -Path $_ -PathType Leaf)
                {
                    if ([IO.Path]::GetExtension($_) -ne ".json") {
                        throw "File must have extension .json"
                    }
                    return $true
                }
                else
                {
                    throw "Provided file doesn't exists."
                }
            }
        )]
        [String]
        $Path
    )
    
    return Get-Content -Path $Path -Raw | ConvertFrom-Json -AsHashtable
}