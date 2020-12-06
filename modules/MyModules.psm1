# ? Multithreading: Measure-Command { Get-InstalledModule | Start-RSJob -ScriptBlock { $_ | Get-LatestModuleVersion } -Throttle ([System.Environment]::ProcessorCount) -FunctionsToImport Get-LatestModuleVersion | Wait-RSJob | Receive-RSJob }

# To Do:
# * Add progressbar depending on finished/remaining backgroundtasks
function Get-LatestModuleVersion
{
    #Requires -Module PowerShellGet

    [CmdletBinding()]
    param (
        # Name of module to get versions from
        [ValidateNotNullOrEmpty()]
        [Parameter(
            Mandatory = $true,
            Position = 1,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true
        )]
        [String] $Name,

        # Look up latest module version in online repositories
        [Parameter(ParameterSetName = "Online")]
        [Switch] $Online,

        # Check module if update is available
        [Parameter(ParameterSetName = "Online")]
        [Switch] $CheckUpdate,

        # Perform internet connection check
        [Parameter(ParameterSetName = "Online")]
        [Switch] $CheckConnection,

        # Internet domain to check internet connection
        [Parameter(ParameterSetName = "Online")]
        [ValidateNotNullOrEmpty()]
        [String] $TargetName = "google.com"
    )

    begin
    {
        $ObjectProperties = @("Name", "Version", "Source", "Update", "Type")
        $InternetConnection = $true
    }

    process
    {
        if ($CheckConnection -And ($CheckUpdate -Or $Online) )
        {
            Write-Verbose "Checking internet connection"
            if (-Not (Test-Connection -ComputerName $TargetName -Quiet) )
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

        if ($InternetConnection -And ($CheckUpdate -Or $Online) ) # this is wrong
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

        # $Mod properties: Name, Version, Source, Update, Type
        return $Mod
    }

    end { }
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

    begin { }

    process
    {
        Write-Verbose "Get installed versions of module $($Name)..."
        $ModInfo = Get-InstalledModule -Name $Name -AllVersions | Sort-Object -Property Version -Descending
        Write-Verbose "Found $($ModInfo.Version.Count) versions of module $($Name)"
        Write-Verbose "Build object of module $($Name)..."
        return [PSCustomObject]@{
            Name    = $Name
            Version = $ModInfo.Version
        }
    }

    end { }
}

# This has to be changed
function Remove-MyOldVersions
{
    #Requires -Module PowerShellGet

    [CmdletBinding()]
    param (
        # Hashtable with module names
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [String] $Name
    )

    begin { }

    process
    {
        Write-Verbose "Checking $($Name)"
        $ModuleVersionInfo = Get-MyModuleVersions -Name $Name
        $ModuleVersionInfo | Out-Host
        $versionsCount = $ModuleVersionInfo.Version.Count
            
        if ($versionsCount -gt 1)
        {
            $count = 0
            $modName = $ModuleVersionInfo.Name
            $latestLocal = (Get-InstalledModule -Name $Name).Version

            Write-Verbose "Delete old version of Module $($modName)"
            foreach ($ModVs in $ModuleVersionInfo.Version)
            {
                # write prgress for each module version
                Write-Progress -PercentComplete ($count / $versionsCount * 100) -Activity "Processing $($modName) - $($ModVs) [latest: $($latestLocal)]"
                if ($ModVs -ne $latestLocal)
                {
                    Write-Verbose "Uninstalling $($modName) - $($ModVs) [latest installed is $($latestLocal)]"
                    try
                    {
                        Uninstall-Module -Name $modName -RequiredVersion $ModVs -ErrorAction Stop
                        Write-Verbose "SUCCESS: uninstalled module $($modName) - $($ModVs)"
                    }
                    catch
                    {
                        Write-Warning "Failed to uninstall $($modName) - $($ModVs)"
                    }
                }
                $count++
            }
        }
        else
        {
            Write-Verbose "Only one version installed - Do not run clean up"
        }
    }    
    
    end { }
}