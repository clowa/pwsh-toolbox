<#
.SYNOPSIS
    Returns the currently authenticated user.
.DESCRIPTION
    Returns information about the currently authenticated drone user.
.EXAMPLE
    PS C:\> Get-DroneUser -Server "https://my.drone.de" -Token (Read-Host -Prompt "Token" -AsSecureString)
    This will prompt you to type in your drone API token and fetch information about the current user.
.EXAMPLE
    PS C:\> Get-DroneUser
    This will read drone configuration from environment variables and fetch information about the current user.
.INPUTS 
    See paramter explaination for supported input values and switch parameters.
.OUTPUTS
    Information about the current authenticated user.
.NOTES
    This cmdlet maybe doesn't support all <CommonParameters> correctly.
#>
function Get-DroneUser {
    [CmdletBinding()]
    param (
        # Drone server uri
        [Parameter(Position = 0)]
        [ValidateScript({ Test-DNSResolution (ConvertTo-AbsoluteUri $_) })]
        [Uri]
        $Server = $env:DRONE_SERVER_PS,

        # API token of drone user
        [Parameter(Position = 1)]
        [SecureString]
        $Token = ($env:DRONE_TOKEN_PS | ConvertTo-SecureString)
    )

    $ApiPath = "/api/user"

    $DroneApi = Join-DroneAPIPath (ConvertTo-AbsoluteUri $Server) $ApiPath

    try { $Respone = Invoke-RestMethod -Method Get -Uri $DroneApi -Authentication Bearer -Token $Token } catch { $PSCmdlet.ThrowTerminatingError($_) }

    $polishedRespone = [PSCustomObject]@{
        id         = $Respone.id
        login      = $Respone.login
        email      = $Respone.email
        machine    = $Respone.machine
        admin      = $Respone.admin
        active     = $Respone.active
        avatar     = [Uri]$Respone.avatar
        syncing    = $Respone.syncing
        synced     = (Get-Date -UnixTimeSeconds $Respone.synced)
        created    = (Get-Date -UnixTimeSeconds $Respone.created)
        updated    = (Get-Date -UnixTimeSeconds $Respone.updated)
        last_login = (Get-Date -UnixTimeSeconds $Respone.last_login)
    }

    return $polishedRespone
}