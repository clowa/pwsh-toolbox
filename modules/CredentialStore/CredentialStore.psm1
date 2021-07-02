#using System.Management.Automation

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
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
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
        return  New-Object -TypeName PSCredential -ArgumentList $cred.Username, ($cred.Password | ConvertTo-SecureString)
    } else {
        throw 'Credential file is not set. Please set credential file by calling script with parameter -SetCredentials'
    }
}

function Get-CredentialFromFile {
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    Write-Verbose "Check if $Path is present and of type leaf..."
    # import credentials
    if ( -Not (Test-Path -Path $Path -PathType Leaf)) {
        throw "Path is not a valid Path of type Leaf."
    }
    try {
        $Credential = Import-Credentials -Path $Path -ErrorAction Stop
    } catch {
        $err = $_
        $message = "Can't import credentials from $Path`nError: $err"
        throw $message
    }
    return $Credential
}

# AWS configuration object
class AWSCredential {
    [ValidateNotNullOrEmpty()][PSCredential]$Credential;

    AWSCredential([PSCredential]$_credential){
        $this.Credential = $_credential
    }

    setEnv() {
        $Env:AWS_ACCESS_KEY_ID=$this.Credential.UserName
        $plainTxt = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($this.Credential.Password))

        $Env:AWS_SECRET_ACCESS_KEY=$plainTxt
    }

    unsetEnv() {
        Remove-Item Env:\AWS_ACCESS_KEY_ID
        Remove-Item Env:\AWS_SECRET_ACCESS_KEY
    }
}


function Get-AWSCustomCredential {
    <#
    .SYNOPSIS
    `Get-AWSCustomCredential` creates an custom AWS credential object with the provided credentials.
    
    .PARAMETER Credential
    AWS credentials. Access key as username and secret key as password
    
    .EXAMPLE
    Get-AWSCustomCredential -Credential (Get-Credental)
    
    #>
    param (
        # Credential object containing AWS credentials.
        [Parameter(ValueFromPipeline)]
        [pscredential]
        $Credential
    )
    return [AWSCredential]::new($Credential)
} 