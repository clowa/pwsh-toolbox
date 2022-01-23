<#
.SYNOPSIS
    Returns the currently authenticated user’s build feed.
.DESCRIPTION
    Returns the build feed of the currently authenticated user.
.EXAMPLE
    PS C:\> Get-DroneFeed -Server "https://my.drone.de" -Token (Read-Host -Prompt "Token" -AsSecureString)
    This will prompt you to type in your drone API token and fetch information about the build feed of the current user.
.EXAMPLE
    PS C:\> Get-DroneFeed
    This will read drone configuration from environment variables and fetch information about the build feed of the current user.
.INPUTS 
    See paramter explaination for supported input values and switch parameters.
.OUTPUTS
    Information about the build feed of the current user.
.NOTES
    This cmdlet maybe doesn't support all <CommonParameters> correctly.
#>
function Get-DroneFeed {
    [CmdletBinding()]
    param (
        # Drone server uri
        [Parameter(Position = 0)]
        [ValidateScript({ Test-DNSResolution (ConvertTo-AbsoluteUri $_) })]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Server = $env:DRONE_SERVER_PS,

        # API token of drone user
        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [SecureString]
        $Token = ($env:DRONE_TOKEN_PS | ConvertTo-SecureString)
    )

    $ApiPath = "/api/user/builds"

    $DroneApi = Join-DroneAPIPath (ConvertTo-AbsoluteUri $Server) $ApiPath

    try { $Response = Invoke-RestMethod -Method Get -Uri $DroneApi -Authentication Bearer -Token $Token } catch { $PSCmdlet.ThrowTerminatingError($_) }

    $polishedResponses = foreach ($resp in $Response) {
        
        ## Convert values of property "build" to more usefull objects/types
        $polishedBuild = [PSCustomObject]@{
            id            = $resp.build.id
            repo_id       = $resp.build.repo_id
            trigger       = $resp.build.trigger
            number        = $resp.build.number
            status        = $resp.build.status
            event         = $resp.build.event
            action        = $resp.build.action
            link          = [Uri]$resp.build.link
            timestamp     = $resp.build.timestamp
            message       = $resp.build.message
            before        = $resp.build.before
            after         = $resp.build.after
            ref           = $resp.build.ref
            source_repo   = $resp.build.source_repo
            source        = $resp.build.source
            target        = $resp.build.target
            author_login  = $resp.build.author_login
            author_name   = $resp.build.author_name
            author_email  = [System.Net.Mail.MailAddress]$resp.build.author_email
            author_avatar = [Uri]$resp.build.author_avatar
            sender        = $resp.build.sender
            started       = (Get-Date -UnixTimeSeconds $resp.build.started)
            finished      = (Get-Date -UnixTimeSeconds $resp.build.finished)
            created       = (Get-Date -UnixTimeSeconds $resp.build.created)
            updated       = (Get-Date -UnixTimeSeconds $resp.build.updated)
            version       = $resp.build.version
        }


        ## Build the feed object and convert values to more usefull objects/types
        return [PSCustomObject]@{
            id                        = $resp.id
            uid                       = $resp.uid                # TODO: check how to store UUID - which type???
            user_id                   = $resp.user_id
            namespace                 = $resp.namespace
            name                      = $resp.name
            slug                      = $resp.slug
            scm                       = $resp.scm
            git_http_url              = [Uri]$resp.git_http_url
            git_ssh_url               = $resp.git_ssh_url        # Can not be stored as Uri object. Example value: git@github.com:PowerShell/PowerShell.git
            link                      = [Uri]$resp.link
            default_branch            = $resp.default_branch
            private                   = $resp.private
            visibility                = $resp.visibility
            active                    = $resp.active
            config_path               = $resp.config_path
            trusted                   = $resp.trusted
            protected                 = $resp.protected
            ignore_forks              = $resp.ignore_forks
            ignore_pull_requests      = $resp.ignore_pull_requests
            auto_cancel_pull_requests = $resp.auto_cancel_pull_requests
            auto_cancel_pushes        = $resp.auto_cancel_pushes
            auto_cancel_running       = $resp.auto_cancel_running
            timeout                   = $resp.timeout
            counter                   = $resp.counter
            synced                    = (Get-Date -UnixTimeSeconds $resp.synced)
            created                   = (Get-Date -UnixTimeSeconds $resp.created)
            updated                   = (Get-Date -UnixTimeSeconds $resp.updated)
            version                   = $resp.version
            build                     = $polishedBuild
        }
    }

    return $polishedResponses
}