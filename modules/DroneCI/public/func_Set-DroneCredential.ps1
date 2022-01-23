<#
.SYNOPSIS
    Store credential of drone CI to vault from different sources.
.DESCRIPTION
    This cmdlet stores credential of drone CI into a secret vault. you can choose between different sources from where the credential should be saved.
.EXAMPLE
    PS C:\> Register-SecretVault -Name MyVault -ModuleName Microsoft.PowerShell.SecretStore -Description "This is my test vault"
    PS C:\> Set-DroneCredential -VaultName MyVault -Server "https://my.drone.de" -Token (Read-Host -Prompt "Token" -AsSecureString)
    This will create a new vault and prompt you to type in your drone API token and store everything within the new created vault.
.EXAMPLE
    PS C:\> Register-SecretVault -Name MyVault -ModuleName Microsoft.PowerShell.SecretStore -Description "This is my test vault"
    PS C:\> Set-DroneCredential -VaultName MyVault -FromCLIEnvironmentVariables
    This will create a new vault and store drone server and API token from the drone CLI environment variables (DRONE_SERVER, DRONE_TOKEN) to the vault. For drone CLI configuration see: https://docs.drone.io/cli/configure/
.EXAMPLE
    PS C:\> Register-SecretVault -Name MyVault -ModuleName Microsoft.PowerShell.SecretStore -Description "This is my test vault"
    PS C:\> Set-DroneCredential -VaultName MyVault -FromEnvironmentVariables
    This will create a new vault and store drone server and API token from the environment variables (DRONE_SERVER_PS, DRONE_TOKEN_PS) this module uses to the vault.
.INPUTS
    See paramter explaination for supported input values and switch parameters.
.OUTPUTS
    This cmdlet doesn't return anything, it just stores secrets to a vault.
.NOTES
    This cmdlet maybe doesn't support all <CommonParameters> correctly.
#>

function Set-DroneCredential {
    [CmdletBinding()]
    param (
        # Secret vault name to store secrets within
        [Parameter(
            Mandatory,
            Position = 0
        )]
        [String]
        $VaultName,

        # Absolute uri of drone server
        [Parameter(
            Mandatory,
            Position = 1,
            ParameterSetName = 'Vault'
        )]
        [ValidateScript({ $_ -match "https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&=]*)" })]
        [String]
        $Server,

        # Personal bearer token of drone api
        [Parameter(
            Mandatory,
            Position = 2,
            ParameterSetName = 'Vault'
        )]
        [SecureString]
        $Token,

        # Store values of drone CLI environment variables to vault
        [Parameter(
            ParameterSetName = 'CLIEnvironmentVariables'
        )]
        [Switch]
        $FromCLIEnvironmentVariables,

        # Store values of module environment variables to vault
        [Parameter(
            ParameterSetName = 'EnvironmentVariables'
        )]
        [Switch]
        $FromEnvironmentVariables,

        # Force overwrite of values
        [Parameter()]
        [Switch]
        $Force
    )

    ## Check if vault is present, if not throw terminating error
    $ErrorActionPreferenceBefore = $ErrorActionPreference
    $ErrorActionPreference = "Stop"
    Write-Verbose "Check if vault is present."
    Confirm-VaultExists -VaultName $VaultName
    $ErrorActionPreference = $ErrorActionPreferenceBefore

    ## Check if secrets are already present in vault
    Write-Verbose "Checking presence of secrets."
    $StoredServer = Get-SecretInfo -Name "DRONE_SERVER_PS" -Vault $VaultName -ErrorAction SilentlyContinue
    $StoredToken = Get-SecretInfo -Name "DRONE_TOKEN_PS" -Vault $VaultName -ErrorAction SilentlyContinue

    ## Display message if secrets are already present and return
    if ($StoredServer -AND $StoredToken -AND -Not $Force) { 
        if ($StoredServer) { Write-Error "Secret `'DRONE_SERVER_PS`' already present in vault. Use parameter -Force to overwrite." }
        if ($StoredToken) { Write-Error "Secret `'DRONE_TOKEN_PS`' already present in vault. Use parameter -Force to overwrite." }
        return
    }

    ## Deside where to load configuration from
    if ($FromCLIEnvironmentVariables) {
        Write-Verbose "Storing secrets from drone CLI environment variables."
        $_server = $env:DRONE_SERVER
        $_token = $env:DRONE_TOKEN | ConvertTo-SecureString -AsPlainText
    } elseif ($FromEnvironmentVariables) {
        Write-Verbose "Storing secrets from module environment variables."
        $_server = $env:DRONE_SERVER_PS
        $_token = $env:DRONE_TOKEN_PS
    } else {
        Write-Verbose "Storing secrets from -Server and -Token."
        $_server = $Server
        $_token = $Token
    }
    
    ## Store new secrets
    Set-Secret -Name "DRONE_SERVER_PS" -Vault $VaultName -Secret $_server
    Set-Secret -Name "DRONE_TOKEN_PS" -Vault $VaultName -Secret $_token
}