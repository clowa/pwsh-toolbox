#using System.Management.Automation

# create password file if it isn't present yet
function Export-Credential {
    <#
    .SYNOPSIS
    The `Export-Credential` save credentials encrypted to disk.
    
    .DESCRIPTION
    The `Export-Credential` cmdlet accepts a credential object and a path to save credentials to.
    
    .PARAMETER Credential
    PSCredential object to write to disk.
    
    .PARAMETER Path
    Path to an .xml file. Credentials will be stored at this location. File must not yet exist.
    Defaults to: .\.Credentials.xml
    
    .PARAMETER Key
    Specifies the encryption key used to convert the original secure string into the encrypted standard string. Valid key lengths are 16, 24 and 32 bytes.

    .EXAMPLE
    Export-Credential -Path ./.secret.xml -Credential (Get-Credential)

    Description
    -----------
    Save credentials to file ./.secret.xml

    .EXAMPLE
    Export-Credential -Path ./.secret.xml -Credential (Get-Credential) -Key $(New-AESKey AES256)

    Description
    -----------
    Save credentials to file ./.secret.xml with custom AES256 encryption key. This method allow encryption and decryption on other machines and other users.

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
        $Path = '.\.Credentials.xml',

        # AES key to decrypt data.
        [Parameter()]
        [Byte[]]
        $Key
    )

    # checks if file already exists
    if (-Not (Test-Path -Path $Path -PathType Leaf)) {
        Write-Verbose "Exporting credentials to $Path"
        try {
            $cred = New-Object -TypeName psobject -Property @{ Username = $Credential.UserName; Password = $Credential.Password | ConvertFrom-SecureString -Key $Key -ErrorAction Stop }
            $cred | Export-Clixml -Path $Path -ErrorAction Stop
        } catch {
            $err = $_ 
            Remove-Item -Path $Path -ErrorAction SilentlyContinue
            throw $err
        }
    } else {
        throw 'Credential file exists. Delete file to set new credentials'
    }
}

# set/import powershell credential object from file
function Import-Credential {
    <#
    .SYNOPSIS
    The `Import-Credential` imports credentials from xml file.
    
    .DESCRIPTION
    The `Import-Credential` cmdlet accepts a path to an .xml file to read encrypted credentials from. 
    
    .PARAMETER Path
    Path to an .xml file. Credentials will be read in from this location.

    .PARAMETER Key
    Specifies the encryption key used to convert the original secure string into the encrypted standard string. Valid key lengths are 16, 24 and 32 bytes.
    
    .EXAMPLE
    Import-Credential -Path ./.secret.xml

    Description
    -----------
    Returns credentials as PSCredential object saved in file ./.secret.xml

    .EXAMPLE
    Import-Credential -Path ./.secret.xml -Key $key

    Description
    -----------
    Returns credentials as PSCredential object saved in file ./.secret.xml. Decryption is done by custom AES key so file can be encrypt by other user and on other machine. 
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
        $Path,

        # AES key to decrypt data.
        [Parameter()]
        [Byte[]]
        $Key
    )
    
    # checks if file exists
    if (Test-Path -Path $Path -PathType Leaf) {
        # create and return powershell credentials object 
        Write-Verbose "Importing credentials from $Path"
        $cred = Import-Clixml -Path $Path
        return  New-Object -TypeName PSCredential -ArgumentList $cred.Username, ($cred.Password | ConvertTo-SecureString -Key $Key)
    } else {
        throw "Path is not valid. Make sure Path is present and of type leaf."
    }
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

function New-AESKey {
    <#
    .SYNOPSIS
    `New-AESKey` generates a AES encryption key.
    
    .PARAMETER Type
    AES types (eg. AES256) 
    
    .EXAMPLE
    New-AESKey -Type AES256
    
    #>
    param (
        [Parameter(Mandatory, Position=0)]
        [ValidateSet(
            "AES128",
            "AES192",
            "AES256"
        )]
        [string]
        $Type
    )
    
    switch ($Type) {
        AES128 { 
            $keyLength = 16
         }
        AES192 {
            $keyLength = 24
        }
        AES256 {
            $keyLength = 32
        }
    }

    $AESKey = New-Object Byte[] $keyLength
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey)

    return @($AESKey)
}