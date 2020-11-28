[CmdletBinding()]
param (
    # Dry run of script without doing anything
    [Parameter(Mandatory=$false)]
    [switch] $WhatIf,

    # Force uninstall
    [Parameter(Mandatory=$false)]
    [Switch] $Force
)

# To Do:
# * Add progressbar depending on finished/remaining backgroundtasks
function Get-LatestModuleVersion {
    #Requires -Module PoshRsJob
    #Requires -Module PowerShellGet

    [CmdletBinding()]
    param (
        # Name of module to get versions from
        [Parameter(
            Mandatory=$true,
            Position=1,
            ValueFromPipelineByPropertyName=$true
        )]
        [String] $Name,

        # Parameter help description
        [Parameter()]
        [Switch] $Online,

        # Internet domain to check internet connection
        [ValidateNotNullOrEmpty()]
        [String] $TargetName = "google.com"
    )

    begin {
        $ModVsList = New-Object System.Collections.Generic.List[psobject]
        $Jobs = New-Object System.Collections.Generic.List[psobject]
        $MaxThreads = [System.Environment]::ProcessorCount
        $i = 0
    }

    process {
        $ScriptBlock = {
            # unfortunately nobody can see this verbose messages
            param (
                $Name
            )

            Write-Verbose "Looking for latest version of module $Name"
            if ( $Using:Online -AND (Test-Connection -ComputerName $Using:TargetName -Quiet)) {
                Write-Verbose "Internet connection detected - Get module versions from installed repositories."
                $Mod = Find-Module -Name $Name
                $Mod | Add-Member -NotePropertyName Source -NotePropertyValue "Online"
            } else {
                Write-Verbose "Using local installed modules."
                Write-Verbose "You can use the online repositorys if you set -Online parameter."
                $Mod = Get-InstalledModule -Name $Name
                $Mod | Add-Member -NotePropertyName Source -NotePropertyValue "Local"
            }

            return [PSCustomObject]@{
                Name = $Mod.name
                Latest = $Mod.Version
                Source = $Mod.Source
                Type = $Mod.Type
            }
        }

        Write-Verbose "Starting background thread in new runspacepool..."
        $Jobs.Add( (Start-RSJob -ScriptBlock $ScriptBlock -ArgumentList $Name -Throttle $MaxThreads ) )
    }

    end {
        Write-Verbose "Start collection data from background jobs..."
        $totalJobs = $Jobs.Count
        while ( ($Jobs.Count -gt 0) -or ($Jobs.State -contains "Completed") ) {
            Write-Verbose "$($Jobs.Count) Jobs remain..."
            # necessary to temporary store all completed jobs to sacrifice "Collection was modified; enumeration operation may not execute." error
            $finishedJobs = Get-RSJob -State Completed
            $finishedJobs | ForEach-Object {
                Write-Verbose "Background thread with id: $($_.id) finished."
                Write-Verbose "Receive data from $($_.id)..."
                $jobResult = ($_ | Wait-RSJob | Receive-RSJob)
                $ModVsList.Add($jobResult) | Out-Null
                Write-Verbose "Remove job $($_.id)..."
                $_ | Remove-RSJob
                $Jobs.Remove($_) | Out-Null
                # Increment the $i counter variable which is used to create the progress bar.
                $i = $i + 1
                Write-Progress -Activity "Collecting data" -Status "Progress:" -PercentComplete ($i/$totalJobs*100)
            }
            Write-Verbose "Sleep for next loop..."
            Start-Sleep -Milliseconds 100
        }
        Write-Verbose "Finished - return module list."
        return $ModVsList
    }
} 

function Get-MyModuleVersions {
    #Requires -Module PowerShellGet

    [CmdletBinding()]
    param (
        # Name of module to get versions from
        [Parameter(
            Mandatory=$true,
            Position=1,
            ValueFromPipelineByPropertyName=$true
        )]
        [String] $Name
    )

    process {
        Write-Verbose "Get installed versions of module $($Name)..."
        $ModInfo = Get-InstalledModule -Name $Name -AllVersions | Sort-Object -Property Version -Descending
        Write-Verbose "Found $($ModInfo.Version.Count) versions of module $($Name)"
        Write-Verbose "Get latest version of module..."
        $ModVs = Get-LatestModuleVersion -Name $ModInfo[0].Name
        Write-Verbose "Build object of module $($Name)..."
        return [PSCustomObject]@{
            Name = $ModInfo[0].Name
            Latest = $ModVs.Latest
            Installed = $ModInfo.Version
            Version = $ModInfo.Version
            Source = $ModVs.Source
        }
    }
}

# This has to be changed
function Remove-MyOldVersions {
    #Requires -Module PowerShellGet

    [CmdletBinding()]
    param (
        # Hashtable with module names
        [Parameter(ValueFromPipeline=$true)]
        [System.Object] $Module
    )

    process {
        Write-Verbose "Checking $($Module.name)"
        try {
            $ModuleVersionInfo = Get-MyModuleVersions -Module $Module -ErrorAction Stop
            [PSCustomObject]@{
                Name = $ModuleVersionInfo.Name
                Latest = $ModuleVersionInfo.Latest
                Count = $ModuleVersionInfo.Version.Count
            } | Out-Host
        } catch {
            $skipedModules.Add($Module.name)
            Write-Verbose "Skipping module $($Module.name)"
        }
            
        if ($ModuleVersionInfo.Version.Count -gt 1) {
            foreach ($Mod in $ModuleVersionInfo) {
                Write-Verbose "Delete old version of Module $($Mod.Name)"
                foreach ($ModVs in $Mod.Version) {
                    if ($ModVs -eq $Mod.Latest) { $color = "green"} Else { $color = "magenta"}
                    Write-Host "Processing module $($Mod.Name) - $($ModVs) [latest is $($Mod.Latest)]" -ForegroundColor $color

                    if ($ModVs -ne $Mod.Latest) {
                        Write-Verbose "Uninstalling $($Mod.Name) - $($ModVs) [latest is $($Mod.Latest)]"
                        try {
                            Uninstall-Module -Name $Mod.Name -ErrorAction Stop
                            $uninstalledModules.Add("$($Mod.Name) - $($ModVs)")
                            Write-Verbose "SUCCESS: uninstalled module $($Mod.Name) - $($ModVs)"
                        } catch {
                            $faileddModules.Add("$($Mod.Name) - $($ModVs)")
                            Write-Warning "WARNING: failed to uninstall $($Mod.Name) - $($ModVs)"
                        }
                    }

                }
            }
        } else {
            Write-Verbose "Only one version installed - Do not run clean up"
        }
    }    
    
    end {
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
Write-Host "be sure to run this as an admin" -foregroundcolor yellow
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

write-host "done"