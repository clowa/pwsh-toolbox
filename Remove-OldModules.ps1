[CmdletBinding()]
param (
    # Dry run of script without doing anything
    [Parameter(Mandatory = $false)]
    [switch] $WhatIf,

    # Force uninstall
    [Parameter(Mandatory = $false)]
    [Switch] $Force
)

# To Do:
# * Add progressbar depending on finished/remaining backgroundtasks
function Get-LatestModuleVersion
{
    #Requires -Module PoshRsJob
    #Requires -Module PowerShellGet

    [CmdletBinding()]
    param (
        # Name of module to get versions from
        [Parameter(
            Mandatory = $true,
            Position = 1,
            ValueFromPipelineByPropertyName = $true
        )]
        [String] $Name,

        # Look up latest module version in online repositories
        [Parameter()]
        [Switch] $Online,

        # Check module if update is available
        [Parameter()]
        [Switch] $CheckUpdate,

        # Perform internet connection check
        [Parameter()]
        [Switch] $CheckConnection,

        # Internet domain to check internet connection
        [ValidateNotNullOrEmpty()]
        [String] $TargetName = "google.com"
    )

    begin
    {
        Write-Verbose "$($MyInvocation.MyCommand) - beginn block"
        $ObjectProperties = @("Name", "Version", "Source", "Update", "Type")
    }

    process
    {
        if ($CheckConnection -And ($CheckUpdate -Or $Online) )
        {
            Write-Verbose "Checking internet connection"
            if (Test-Connection -ComputerName $TargetName -Quiet)
            { 
                Write-Verbose "Internet connection detected"
                $InternetConnection = $true 
            }
            else
            { 
                Write-Verbose "Can not detect internet connection"
                Write-Verbose "Maybe $TargetName did not answer ping request."
                $InternetConnection = $false 
            }
        }

        # only look up local module version if no online lookup will be performed
        if (-Not $Online)
        {
            Write-Verbose "Get local installed module version."
            $Mod = Get-InstalledModule -Name $Name | Select-Object -Property $ObjectProperties 
            $Mod.Source = "Local"
            $Mod.Update = $false
        }

        if (-Not $CheckConnection -Or $InternetConnection)
        {
            $ModOnline = Find-Module -Name $Name | Select-Object -Property $ObjectProperties 
            if ($CheckUpdate)
            {
                if ($ModOnline.Version -gt $Mod.Version)
                {
                    $Mod.Update = $true
                }
                $Mod.Source = "Online"
            }
            else
            {
                $Mod = $ModOnline
                $Mod.Update = $false
                $Mod.Source = "Online"
            } 
        }

        return $Mod
    }

    end
    {
        Write-Verbose "$($MyInvocation.MyCommand) - end block"
    }
} 

function Get-MyModuleVersions
{
    #Requires -Module PowerShellGet

    [CmdletBinding()]
    param (
        # Name of module to get versions from
        [Parameter(
            Mandatory = $true,
            Position = 1,
            ValueFromPipelineByPropertyName = $true
        )]
        [String] $Name
    )

    process
    {
        Write-Verbose "Get installed versions of module $($Name)..."
        $ModInfo = Get-InstalledModule -Name $Name -AllVersions | Sort-Object -Property Version -Descending
        Write-Verbose "Found $($ModInfo.Version.Count) versions of module $($Name)"
        Write-Verbose "Get latest version of module..."
        $ModVs = Get-LatestModuleVersion -Name $ModInfo[0].Name
        Write-Verbose "Build object of module $($Name)..."
        return [PSCustomObject]@{
            Name      = $ModInfo[0].Name
            Latest    = $ModVs.Latest
            Installed = $ModInfo.Version
            Version   = $ModInfo.Version
            Source    = $ModVs.Source
        }
    }
}

# This has to be changed
function Remove-MyOldVersions
{
    #Requires -Module PowerShellGet

    [CmdletBinding()]
    param (
        # Hashtable with module names
        [Parameter(ValueFromPipeline = $true)]
        [System.Object] $Module
    )

    process
    {
        Write-Verbose "Checking $($Module.name)"
        try
        {
            $ModuleVersionInfo = Get-MyModuleVersions -Module $Module -ErrorAction Stop
            [PSCustomObject]@{
                Name   = $ModuleVersionInfo.Name
                Latest = $ModuleVersionInfo.Latest
                Count  = $ModuleVersionInfo.Version.Count
            } | Out-Host
        }
        catch
        {
            $skipedModules.Add($Module.name)
            Write-Verbose "Skipping module $($Module.name)"
        }
            
        if ($ModuleVersionInfo.Version.Count -gt 1)
        {
            foreach ($Mod in $ModuleVersionInfo)
            {
                Write-Verbose "Delete old version of Module $($Mod.Name)"
                foreach ($ModVs in $Mod.Version)
                {
                    if ($ModVs -eq $Mod.Latest) { $color = "green" } Else { $color = "magenta" }
                    Write-Host "Processing module $($Mod.Name) - $($ModVs) [latest is $($Mod.Latest)]" -ForegroundColor $color

                    if ($ModVs -ne $Mod.Latest)
                    {
                        Write-Verbose "Uninstalling $($Mod.Name) - $($ModVs) [latest is $($Mod.Latest)]"
                        try
                        {
                            Uninstall-Module -Name $Mod.Name -ErrorAction Stop
                            $uninstalledModules.Add("$($Mod.Name) - $($ModVs)")
                            Write-Verbose "SUCCESS: uninstalled module $($Mod.Name) - $($ModVs)"
                        }
                        catch
                        {
                            $faileddModules.Add("$($Mod.Name) - $($ModVs)")
                            Write-Warning "WARNING: failed to uninstall $($Mod.Name) - $($ModVs)"
                        }
                    }

                }
            }
        }
        else
        {
            Write-Verbose "Only one version installed - Do not run clean up"
        }
    }    
    
    end
    {
        # cleanup
        $ModuleVersionInfo = $null
        $Mod
        $ModVs = $null
        $Module = $null
        $color = $null
        [GC]::Collect()
    }
    
}

##########
## MAIN ##
##########

# Global Variables
$skipedModules = New-Object System.Collections.Generic.List[String]
$uninstalledModules = New-Object System.Collections.Generic.List[String]
$faileddModules = New-Object System.Collections.Generic.List[String]

Write-Host "this will remove all old versions of installed modules"
Write-Host "be sure to run this as an admin" -ForegroundColor yellow
Write-Host "(You can update all your Azure RM modules with update-module Azurerm -force)"

Get-InstalledModule | Remove-MyOldVersions



Write-Host "Skiped Modules:"
$skipedModules -split ', '
Write-Host "Failed Modules:"
$faileddModules -split ', '
Write-Host "Uninstalled Modules:"
$uninstalledModules -split ', '

$skipedModules = $null
$faileddModules = $null
$uninstalledModules = $null


[GC]::Collect()

Write-Host "done"