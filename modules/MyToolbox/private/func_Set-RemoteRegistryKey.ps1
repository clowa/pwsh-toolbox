<#
.SYNOPSIS
    This cmdlet allows to set registry keys / vlaues on remote computers.
.DESCRIPTION
    This cmdlet allows you to configure registry keys / values on remote computers.
#>
function Set-RemoteRegistryKey {
    [CmdletBinding()]
    param (
        # Registry path
        [Parameter(
            Mandatory,
            Position = 0
        )]
        [string]
        $Path,

        # Name of entry
        [Parameter(
            Mandatory,
            Position = 1
        )]
        [String]
        $Name,

        # Value of entry
        [Parameter(
            Mandatory,
            Position = 2
        )]
        [String]
        $Value,

        # Computer name(s) for which you want to configure IE ESC
        [Parameter(
            ValueFromPipelineByPropertyName,
            ValueFromPipeline
        )]
        [String]
        $ComputerName = $env:ComputerName,

        # Credentials to authenticate at the computer
        [Parameter()]
        [ValidateNotNull()]
        [PSCredential]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin { }

    process {
        try {
            Write-Verbose "Setting item $Name at $Path to $Value on $ComputerName"

            ## Parameters of Invoke-Command
            $params = @{
                ComputerName = $ComputerName
                Credential   = $Credential
                ScriptBlock  = {
                    Set-ItemProperty -Path $Using:Path -Name $Using:Name -Value $Using:Value
                } 
            }

            Invoke-Command @params -ErrorAction Stop

            return [PSCustomObject]@{
                ComputerName = $ComputerName
                Path         = $Path
                Name         = $Name
                Value        = $Value
            }

        } catch {
            try { throw "Failed to set $Path $Name to $Value on $Computer" } catch { $PSCmdlet.ThrowTerminatingError($_) }
        }
    }

    end { }   
}