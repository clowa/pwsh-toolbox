<#
.SYNOPSIS
    Disables or enable Internet Explorer Enhanced Security (IE ESC).
.DESCRIPTION
    This cmdlet enables or disables IE ESC on a list of given servers running  Windows 2008 and above.
.EXAMPLE
    PS C:\> Set-InternetExplorerESC -ComputerName Computer1, Computer2 -Mode Enable
    This command enables IE ESC on Computer1 and Computer2.
#>

function Set-InternetExplorerESC {
    [CmdletBinding()]
    param (
        # Computer name(s) for which you want to configure IE ESC
        [Parameter(
            Position = 0, 
            ValueFromPipelineByPropertyName,
            ValueFromPipeline
        )]
        [String[]]
        $ComputerName = $env:computername,

        # Disable or enable internet explorer enhanced security
        [Parameter(Position = 1)]
        [EnableDisable]
        $Mode = [EnableDisable]::Enable,

        # Credential to authenticate on remote computer
        [Parameter()]
        [ValidateNotNull()]
        [PSCredential]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        $AdministratorsKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
        $UsersKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
        $RegistryKeyValue = $Mode.value__
    }

    process {
        foreach ($Computer in $ComputerName) {
            Write-Verbose "Configure IE ESC on $Computer"
            try {
                Set-RemoteRegistryKey -Computer $Computer -Credential $Credential -Path $AdministratorsKey -Name "IsInstalled" -Value $RegistryKeyValue | Out-Null
                Set-RemoteRegistryKey -Computer $Computer -Credential $Credential -Path $UsersKey -Name "IsInstalled" -Value $RegistryKeyValue | Out-Null
                Write-Verbose "Successfully $($RegistryKeyValue ? 'enabled' : 'disabled') IE ESC on $Computer"

                return [PSCustomObject]@{
                    ComputerName = $Computer
                }
            } catch {
                Write-Warning "Failed to disable IE ESC $Computer - $_"
            }
        }
    }       

    end { }   
}