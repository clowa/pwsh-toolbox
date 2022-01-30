<#
.SYNOPSIS
    This cmdlet allows basic configuration of user access control (UAC) on remote computers
.DESCRIPTION
    This cmdlet allows you to configure the admin prompt behavior, user prompt behavior and to enable or disable UAC in general.
.EXAMPLE
    PS C:\> Set-UserAccessControl -ComputerName server01 -Credential (Get-Credential) -UserPromptBehavior AutoDeny
    This example configures UAC on remote computer server01 to deny any operation invoked as a standard user that requires elevation of privilege.
#>
function Set-UserAccessControl {
    [CmdletBinding()]
    param (
        # Computer name(s) for which you want to configure user access control (UAC)
        [Parameter(
            Position = 0,
            ValueFromPipelineByPropertyName,
            ValueFromPipeline
        )]
        [String[]]
        $ComputerName = $env:computername,

        # Credential to authenticate on remote computer
        [Parameter()]
        [ValidateNotNull()]
        [PSCredential]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        # Genable or disable UAC in general. If enabled windows will notify the user when programs try to make changes to the computer.
        [Parameter(
            Position = 1,
            ParameterSetName = "EnableLUA"
        )]
        [EnableDisable]
        $Mode = [EnableDisable]::Enable,

        # Set the UAC admin prompt behavior
        [Parameter(
            ParameterSetName = "AdminPromptBehavior"
        )]
        [ConsentPromptBehaviorAdmin]
        $AdminPromptBehavior = [ConsentPromptBehaviorAdmin]::AgreeIfNotMicrosoft,

        # Set the UAC user prompt behavior
        [Parameter(
            ParameterSetName = "UserPromptBehavior"
        )]
        [ConsentPromptBehaviorUser]
        $UserPromptBehavior = [ConsentPromptBehaviorUser]::LoginSecureDesktop
    )

    begin {
        $GeneralUACPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        $regKeysToProcess = New-Object System.Collections.Generic.List[PSCustomObject]

        ## Add registry key / value to list depending on ParameterSetName
        switch ($PSCmdlet.ParameterSetName) {
            'EnableLUA' {
                $EnableLUARegKey = [PSCustomObject]@{
                    Path  = $GeneralUACPath
                    Name  = "EnableLUA"
                    Value = $Mode.value__
                }
                $regKeysToProcess.Add($EnableLUARegKey)
                break
            }
            'AdminPromptBehavior' {
                $AdminPromptBehaviorRegKey = [PSCustomObject]@{
                    Path  = $GeneralUACPath
                    Name  = "ConsentPromptBehaviorAdmin"
                    Value = $AdminPromptBehavior.value__
                }
                $regKeysToProcess.Add($AdminPromptBehaviorRegKey)
                break
            }
            'UserPromptBehavior' {
                $UserPromptBehaviorRegKey = [PSCustomObject]@{
                    Path  = $GeneralUACPath
                    Name  = "ConsentPromptBehaviorUser"
                    Value = $UserPromptBehavior.value__
                }
                $regKeysToProcess.Add($UserPromptBehaviorRegKey)
                break
            }
        }
    }

    process {
        foreach ($Computer in $ComputerName) {
            Write-Verbose "Configure UAC on $Computer"
            try {

                ## Set registry key / value depending on ParameterSetName - see begin block
                foreach ($key in $regKeysToProcess) {
                    Set-RemoteRegistryKey -Computer $Computer -Credential $Credential -Path $key.Path -Name $key.Name -Value $key.Value | Out-Null
                    Write-Verbose "Successfully configured UAC on $Computer"
                }

                ## Retrun successfully processed computer name
                return [PSCustomObject]@{
                    ComputerName = $Computer
                }
            } catch {
                Write-Warning "Failed to configure UAC on $Computer - $_"
            }
            
        }        
    }

    end { }
}