# create password file if it isn't present yet
function Export-Credentials {
    <#
    .SYNOPSIS
    The `Export-Credentials` save credentials encrypted to disk.
    
    .DESCRIPTION
    The `Export-Credentials` cmdlet accepts a credential object and a path to save credentials to.
    
    .PARAMETER Credential
    PSCredential object to write to disk.
    
    .PARAMETER Path
    Path to an .xml file. Credentials will be stored at this location. File must not yet exist.
    Defaults to: .\.Credentials.xml
    
    .EXAMPLE
    Export-Credentials -Path ./.secret.xml -Credential (Get-Credential)

    Description
    -----------
    Save credentials to file ./.secret.xml
    #>
    param(
        # input credential object
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        # path to store credentials
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {
                # checks if input is a valid path
                if (-Not (Test-Path -Path $_ -IsValid)) {
                    throw 'The path argument must be a file. Folder paths are not allowed'
                }
                # checks if input has extension 'xml'
                if (($_ | Split-Path -Leaf) -notmatch '(\.xml)') {
                    throw 'The file specified in the path argument must be of type xml'
                }
                return $true
            })]
        [System.IO.FileInfo]
        $Path = '.\.Credentials.xml'
    )

    # checks if file already exists
    if (-Not (Test-Path -Path $Path -PathType Leaf)) {
        Write-Verbose "Exporting credentials to $Path"
        try {
            New-Object -TypeName psobject -Property @{Username = $Credential.UserName; Password = $Credential.Password | ConvertFrom-SecureString } | Export-Clixml -Path $Path
        } catch {
            Remove-Item -Path $Path
        }
    } else {
        throw 'Credential file exists. Delete file to set new credentials'
    }
}

# set/import powershell credential object from file
function Import-Credentials {
    <#
    .SYNOPSIS
    The `Import-Credentials` imports credentials from xml file.
    
    .DESCRIPTION
    The `Import-Credentials` cmdlet accepts a path to an .xml file to read encrypted credentials from. 
    
    .PARAMETER Path
    Path to an .xml file. Credentials will be read in from this location.
    Defaults to: .\.Credentials.xml
    
    .EXAMPLE
    Import-Credentials -Path ./.secret.xml

    Description
    -----------
    Returns credentials as PSCredential object saved in file ./.secret.xml
    #>
    param(
        # path to store credentials
        [Parameter()] 
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {
                # checks if input has extension 'xml'
                if (($_ | Split-Path -Leaf) -notmatch '(\.xml)') {
                    throw 'The file specified in the path argument must be type xml'
                }
                return $true
            })]
        [System.IO.FileInfo]
        $Path = '.\.Credentials.xml'
    )
    
    # checks if file exists
    if (Test-Path -Path $Path -PathType Leaf) {
        # create and return powershell credentials object 
        Write-Verbose "Importing credentials from $Path"
        $cred = Import-Clixml -Path $Path
        return  New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $cred.Username, ($cred.Password | ConvertTo-SecureString)
    } else {
        throw 'Credential file is not set. Please set credential file by calling script with parameter -SetCredentials'
    }
}

# AWS configuration object
class AWSSettings {
    [ValidateNotNullOrEmpty()][System.String]$AccessKey
    [ValidateNotNullOrEmpty()][System.Security.SecureString]$SecretAccessKey
    [ValidateNotNullOrEmpty()][System.String]$Region

    AWSSettings($_accessKey, $_secretAccessKey, $_region){
        $this.AccessKey = $_accessKey
        $this.SecretAccessKey = $_secretAccessKey | ConvertTo-SecureString -AsPlainText
        $this.Region = $_region
    }

    # Convert object credentials to PSCredential object
    [System.Management.Automation.PSCredential] ToPSCredential(){
        return [System.Management.Automation.PSCredential]::new($this.AccessKey, $this.SecretAccessKey)
    }
}


function Get-AWSSettings {
    <#
    .SYNOPSIS
    `Get-AWSSettings` creates an custom AWS settings object with the provided settings.
    
    .PARAMETER AccessKey
    AWS access key of API user.
    
    .PARAMETER SecretKey
    AWS secret key of API user.
    
    .PARAMETER Region
    AWS region to use. Defaults to configured default location
    
    .EXAMPLE
    Get-AWSSettings -AccessKey "MyAccessKey" -SecretKey "MySecretKey" -Region us-east-1
    
    #>
    
    #Requires -Module AWS.Tools.Common
    param (
        # AWS Access key
        [Parameter(Mandatory)]
        [System.String]
        $AccessKey,

        # AWS Access key
        [Parameter(Mandatory)]
        [System.String]
        $SecretKey,

        # AWS region
        [Parameter()]
        [ValidateScript(
            {
                if (-Not (Get-AWSRegion -IncludeChina -IncludeGovCloud).Region.Contains($_)){
                    throw "Region '$_' isn't a valid AWS region. (Eg. us-east-1)"
                }
                return $true
            }
        )]
        [System.String]
        $Region = (Get-AWSRegion | Where-Object IsShellDefault -eq $true).Region
    )
    return [AWSSettings]::new($AccessKey, $SecretKey, $Region)
} 