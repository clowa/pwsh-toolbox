#Requires -Modules PoshRSJob
#Requires -Modules ./modules/MyModules.psm1
#Requires -PSEdition Core
#Requires -Version 7.0

[CmdletBinding()]
param (
    # Dry run of script without doing anything
    [Parameter(Mandatory = $false)]
    [switch] $WhatIf,

    # Force uninstall
    [Parameter(Mandatory = $false)]
    [Switch] $Force
)

Write-Host "this will remove all old versions of installed modules"
Write-Host "be sure to run this as an admin" -ForegroundColor yellow
Write-Host "(You can update all your Azure RM modules with update-module Azurerm -force)"

#Write-Verbose "Importing modules..."
#Import-Module -Name ./modules/MyModules.psm1

#Get-InstalledModule | Remove-MyOldVersions
Get-InstalledModule | Start-RSJob -ScriptBlock { $_ | Remove-MyOldVersions } -Throttle ([System.Environment]::ProcessorCount) -ModulesToImport ./modules/MyModules.psm1 | Wait-RSJob | Receive-RSJob

[GC]::Collect()