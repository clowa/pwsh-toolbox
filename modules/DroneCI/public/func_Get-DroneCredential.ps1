<#
.SYNOPSIS
    Get credential of drone CI from different sources.
.DESCRIPTION
    This cmdlet get credential of drone CI ether from vault or environment variables of drone CLI. Per default this cmdlets expose these secrets in a encrypted format as environment variables to be used by other cmdlets, optionally you can disable this behavior by setting '-DoNotSetEnvironmentVariables'.
.EXAMPLE
    PS C:\> Get-DroneCredential -VaultName MyVault
    Assuming you have stored the credential via 'Set-DroneCredential' within a vault called MyVault this will return the stored credential and expose it via the environment variables DRONE_SERVER_PS and DROONE_TOKEN_PS.
.EXAMPLE
    PS C:\> Get-DroneCredential -VaultName MyVault -DoNotSetEnvironmentVariables
    Assuming you have stored the credential via 'Set-DroneCredential' within a vault called MyVault this will return the stored credential and will not expose it via environment variables.
.EXAMPLE
    PS C:\> Get-DroneCredential -FromCLIEnvironmentVariables
    This will get the drone server and API token from the drone CLI environment variables (DRONE_SERVER, DRONE_TOKEN). For drone CLI configuration see: https://docs.drone.io/cli/configure/
.INPUTS
    See paramter explaination for supported input values and switch parameters.
.OUTPUTS
    Returns server URI and API token.
.NOTES
    This cmdlet maybe doesn't support all <CommonParameters> correctly.
#>
function Get-DroneCredential {
    [CmdletBinding(DefaultParameterSetName = "Vault")]
    param (
        # Secret vault name to get secrets from
        [Parameter(
            Mandatory,
            Position = 0,
            ParameterSetName = 'Vault'
        )]
        [String]
        $VaultName,

        # Load configuration from environment variables of drone CLI instead of vault
        [Parameter(
            Mandatory,
            ParameterSetName = 'EnvironmentVariables'
        )]
        [Switch]
        $FromCLIEnvironmentVariables,

        # Avoid setting the environment variables 
        [Parameter()]
        [Switch]
        $DoNotSetEnvironmentVariables
    )

    ## Load config from CLI environment variables and return
    if ($FromCLIEnvironmentVariables) {
        Write-Verbose "Loading secrets from environment variables of drone cli."

        if ( -Not $env:DRONE_SERVER -Or -Not $env:DRONE_TOKEN) {
            if ( -Not $env:DRONE_SERVER) { Write-Error "Environment variable `'`$env:DRONE_SERVER`' isn`'t set." }
            if ( -Not $env:DRONE_TOKEN) { Write-Error "Environment variable `'`$env:DRONE_TOKEN`' isn`'t set." }
            return
        }
        
        $server = $env:DRONE_SERVER
        $token = ($env:DRONE_TOKEN | ConvertTo-SecureString -AsPlainText)
    } else {
        ## Load config from secret vault

        ## Check if vault is present, if not throw terminating error
        $ErrorActionPreferenceBefore = $ErrorActionPreference
        $ErrorActionPreference = "Stop"
        Write-Verbose "Check if vault is present."
        Confirm-VaultExists -VaultName $VaultName | Out-Null
        $ErrorActionPreference = $ErrorActionPreferenceBefore

        ## Unlock vault
        try { Unlock-SecretStore } catch { $PSCmdlet.ThrowTerminatingError($_) }

        ## Check existans of secrets
        $StoredServer = Get-SecretInfo -Name "DRONE_SERVER_PS" -Vault $VaultName -ErrorAction SilentlyContinue
        $StoredToken = Get-SecretInfo -Name "DRONE_TOKEN_PS" -Vault $VaultName -ErrorAction SilentlyContinue

        ## Display messages if secrets aren't present
        if ( -Not $StoredServer) { Write-Error "Secret `'DRONE_SERVER_PS`' isn`'t present in vault `'$VaultName`'. Use `'Set-DroneCredential`' setup secrets." }
        if ( -Not $StoredToken) { Write-Error "Secret `'DRONE_TOKEN_PS`' isn`'t present in vault `'$VaultName`'. Use `'Set-DroneCredential`' setup secrets." }

        ## Load secrets if present
        if ($StoredServer -AND $StoredToken) {
            ## Convert secrets to correct string representation
            $server = Get-Secret -Name "DRONE_SERVER_PS" -Vault $VaultName -AsPlainText
            $token = Get-Secret -Name "DRONE_TOKEN_PS" -Vault $VaultName | ConvertFrom-SecureString # Secret is still encrypted

            Write-Host "Credentials are available as environment variables `'`$env:DRONE_SERVER_PS`' and `'`$env:DRONE_TOKEN_PS`'."
        }
    }

    if ( -Not $DoNotSetEnvironmentVariables) {
        $env:DRONE_SERVER_PS = $server
        $env:DRONE_TOKEN_PS = $token
    }

    $Credentials = [PSCustomObject]@{
        Server = [Uri]$server
        Token  = $token
    }

    return $Credentials
}