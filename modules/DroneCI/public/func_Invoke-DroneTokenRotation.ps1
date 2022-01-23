<#
.SYNOPSIS
    Rotate the API token of the current user.
.DESCRIPTION
    This cmdlet rotates the API token of the current user and adds the ability to store the new token at different places.
.EXAMPLE
    PS C:\> Invoke-DroneTokenRotation -VaultName MyVault
    This will rotate the API token and store the new token within a vault called MyVault. This vault have to exist.
.EXAMPLE
    PS C:\> Invoke-DroneTokenRotation -VaultName MyVault -UpdateEnvironmentVariables:$false
    This will rotate the API token and store the new token within a vault called MyVault. Additionally, it will prevent the cmdlet to store the new token as a environment variable.
.INPUTS
    See paramter explaination for supported input values and switch parameters.
.OUTPUTS
    Returns the new API token.
.NOTES
    This cmdlet maybe doesn't support all <CommonParameters> correctly.
#>
function Invoke-DroneTokenRotation {
    param (
        # Drone server uri
        [Parameter(Position = 0)]
        [Uri]
        $Server = $env:DRONE_SERVER_PS,

        # API token of drone user
        [Parameter(Position = 1)]
        [SecureString]
        $Token = ($env:DRONE_TOKEN_PS | ConvertTo-SecureString),
        
        # Name of the vault in which the new token should to be saved
        [Parameter(Position = 2)]
        [String]
        $VaultName,

        # Enable automatical update of environment variables
        [Parameter()]
        [Switch]
        $UpdateEnvironmentVariables = $true
    )

    $ErrorActionPreference = 'Stop'
    $ApiPath = "/api/user/token?rotate=true"


    if (-Not (Test-DNSResolution -Uri $Server)) {
        try { throw "Endpoint $($Server.OriginalString) seams not to be a valid endpoint. Please check!" } catch { $PSCmdlet.ThrowTerminatingError($_) }
    }

    $DroneApi = Join-DroneAPIPath (ConvertTo-AbsoluteUri $Server) $ApiPath

    try { $Response = Invoke-RestMethod -Method Post -Uri $DroneApi -Authentication Bearer -Token $Token } catch { $PSCmdlet.ThrowTerminatingError($_) }
    

    $newToken = ConvertTo-SecureString -String $Response.token -AsPlainText -Force

    ## If set store new token to provided vault
    if ($VaultName) {
        ## Check if provided vault exists. If not throw error otherwise store new token.
        Confirm-VaultExists -VaultName $VaultName | Out-Null # Requires ErrorActionPreference set to Stop
        Set-Secret -Name "DRONE_TOKEN_PS" -Vault $VaultName -Secret $newToken
    }

    $newTokenAsString = $newToken | ConvertFrom-SecureString # Secret is still encrypted
    if ($UpdateEnvironmentVariables) {
        $env:DRONE_TOKEN_PS = $newTokenAsString
    }
    
    return [PSCustomObject]@{
        Token = $newTokenAsString # Secret is still encrypted
    }
}