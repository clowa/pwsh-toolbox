
Function Install-AWSCLIV2 {
    #Requires -RunAsAdministrator
    <#
    .SYNOPSIS
    Download and install AWSCLIv2 from official AWS Source. 
    
    
    .PARAMETER Version
    Optional version of AWSCLIv2.
    
    .EXAMPLE
    Install-AWSCLIV2 -Version 2.1.39
    
    #>

    [CmdletBinding()]
    param (
        # Version of AWSCLIV2 to install
        [Parameter()]
        [System.String] $Version
    )
    [uri] $winUri = 'https://awscli.amazonaws.com/AWSCLIV2.msi'
    [uri] $linuxUri = 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip'
    [uri] $macUri = 'https://awscli.amazonaws.com/AWSCLIV2.pkg'

    # set uri based on os
    if ($IsWindows) {
        Write-Verbose 'Windows detected'
        [uri] $uri = $winUri
    } elseif ($IsLinux) {
        Write-Verbose 'Linux detected'
        [uri] $uri = $linuxUri
    } elseif ($IsMacOS) {
        Write-Verbose 'macOS detected'
        [uri] $uri = $macUri
    }

    if (-Not [System.String]::IsNullOrEmpty($Version)) {
        Write-Verbose "Create uri for Version $Version"
        $filename = $uri.Segments[$uri.Segments.Length - 1]
        # insert version number in filename
        # Format: Filename-Version.Extension
        $filenameVersion = $filename.Insert($filename.IndexOf('.'), '-' + $Version)
        # create new uri with new filename
        $uri = New-Object -TypeName Uri -ArgumentList ($uri, $filenameVersion)
        Write-Verbose "New uri: $uri"
    }
    Write-Verbose 'Create temp directory...'
    $guid = New-Guid
    if ($IsWindows){
        $tmpFolder = New-Item -ItemType Directory -Path (Join-Path -Path $env:TMP -ChildPath $guid)
    } else {
        $tmpFolder = New-Item -ItemType Directory -Path (Join-Path -Path $env:TMPDIR -ChildPath $guid)
    }
    

    Write-Verbose "Downloading from $uri"
    $file = Get-WebFile -Url $uri -Path $tmpFolder
    Write-Verbose "Stored file at $($file.Fullname)"
    if ($IsWindows) {
        Write-Verbose 'Started windows installation process.'
        Write-Verbose "Start .msi`t$file /quiet"
        Start-Process msiexec.exe -Wait -ArgumentList "/I $file /quiet"
    } elseif ($IsLinux) {
        Write-Verbose 'Started Linux installation process.'
        
        Write-Verbose "Extract archive to $tmpFolder"
        Expand-Archive -LiteralPath $file -DestinationPath $tmpFolder

        Write-Verbose 'Start installation script'
        $installScriptChildPath = 'aws/install'
        $executionPath = Join-Path -Path $tmpFolder -ChildPath $installScriptChildPath
        Invoke-Command -ScriptBlock { sudo $executionPath }
    } elseif ($IsMacOS) {
        Write-Verbose 'Started macOS installation process.'
        Invoke-Command -ScriptBlock { sudo installer -pkg $file.FullName -target / }
    } else {
        Write-Verbose 'Unknown operating system.'
    }

    Write-Verbose 'Verify installation'
    try {
        if ($IsWindows){
            # Looking for registry entri of AWS CLI v2
            $softwareDisplayName = 'AWS Command Line Interface v2'
            $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            Write-Verbose "Search registry for entries for '$softwareDisplayName'"
            if(-Not ((Get-ItemProperty $registryPath).DisplayName -match $softwareDisplayName).Length -gt 0){
                throw "Software '$softwareDisplayName' not present at $registryPath"
            }  
        }
        Write-Debug 'Check if aws cli is in $PATH...'
        $cliCmd = 'aws'
        if(-Not (Get-Command -Name $cliCmd)){
            Write-Warning 'AWS CLI v2 is not present in Path.'
        }
        
        Write-Host 'AWS cli installation successfully.'
    } catch {
        throw 'Failed to install AWS cli.'
    } finally {
        Write-Verbose 'Cleanup...'
        Remove-Item -Path $tmpFolder -Recurse
    }
}


function Uninstall-AWSCLIV2 {
    #Requires -RunAsAdministrator
    <#
    .SYNOPSIS
    Unistall AWSCLIv2 from default location. Must run as administrator.
    
    .PARAMETER FromRegistry
    Deinstalatin via the registry on Windows.
    
    #>
    [CmdletBinding()]
    param (
        # Uninstall with registry instructions
        # Get uninstallation string from registry
        [Parameter()]
        [Switch]
        $FromRegistry
    )

    # Uninstallation process of AWS CLI v2 is documented at: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html#cliv2-linux-remove
    if ($IsWindows) {
        # Windows uninstallation flow
        Write-Verbose 'Windows detected'
        if($FromRegistry){
            # Get unistall string from registry
            Write-Debug "Get uninstall string from registry..."
            $softwareDisplayName = 'AWS Command Line Interface v2'
            $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            $regEntri = Get-ItemProperty $registryPath | Where-Object { $_.DisplayName -eq $softwareDisplayName }
            Write-Debug "Got: $($regEntri.UninstallString)"

            $msiKey = ($regEntri.UninstallString -split '/I')[1]
            Write-Verbose "Got msi key: $msiKey"
            Write-Verbose 'Starting uninstallation...'
            Start-Process msiexec.exe -Wait -ArgumentList "/uninstall $msiKey /quiet"
        }else {
            # Open control panel programs and features
            Invoke-Command -ScriptBlock { appwiz.cpl }
        }
    } elseif ($IsLinux) {
        # Linux uninstallation flow
        Write-Verbose 'Linux detected'
        $AwsBinLink = (Get-Command -Name aws).Source
        Write-Debug "Find aws binary at $AwsBinLink."
        $AwsCompleterLink = (Get-Command -Name aws_completer).Source
        Write-Debug "Find aws_completer at $AwsCompleterLink."
        $AwsCliDir = (Get-Item -Path $AwsBinLink).Target
        Write-Debug "Find aws-cli directory at $AwsCliDir."

        $AwsCliFolderName = 'aws-cli'
        $AwsCliDir = $AwsCliDir.Substring(0, $AwsCliDir.IndexOf($AwsCliFolderName)) | Join-Path -ChildPath $AwsCliFolderName
        Write-Debug "Path shortened to $AwsCliDir."

        Write-Verbose 'Removing AWS CLI v2...'
        Invoke-Command -ScriptBlock {
            sudo rm $AwsBinLink
            sudo rm $AwsCompleterLink
            sudo rm -r $AwsCliDir
        }
        
    } elseif ($IsMacOS) {
        # macOS uninstallation flow
        Write-Verbose 'macOS detected'
        $AwsBinLink = (Get-Command -Name aws).Source
        Write-Debug "Find aws binary at $AwsBinLink."
        $AwsCompleterLink = (Get-Command -Name aws_completer).Source
        Write-Debug "Find aws_completer at $AwsCompleterLink."
        $AwsCliDir = (Get-Item -Path $AwsBinLink).Target
        Write-Debug "Find aws-cli directory at $AwsCliDir."
        Write-Verbose 'Removing AWS CLI v2...'
        Invoke-Command -ScriptBlock {
            sudo rm $AwsBinLink
            sudo rm $AwsCompleterLink
            sudo rm -r $AwsCliDir
        }
    }
    if (Get-Command -Name aws -ErrorAction SilentlyContinue) {
        Write-Warning 'AWS CLI v2 is still within $PATH'
        return $false
    }
    Write-Verbose 'AWS CLI v2 successfully uninstalled.'
    return $true
}
function Get-WebFile {
    <#
    .SYNOPSIS
    `Get-WebFile` downloads a file from a web Url.
    
    .DESCRIPTION
    `Get-WebFile` downloads a file from a web Url. Location of downloaded file will be returned.
    You can specify where the file should be saved by providing a path to the `Path` argument.
    
    .PARAMETER Url
    URL to file.
    
    .PARAMETER Path
    Path where the downloaded file should be saved.
    
    .EXAMPLE
    Get-WebFile -Url 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -Path ~/Downloads/
    #>
    param (
        # Download Url
        [Parameter(Mandatory = $true)]
        [System.String] $Url,

        # Local path to save file
        [Parameter()]
        [ValidateScript( {
                # checks if input has extension 'xml'
                if ([System.IO.Path]::HasExtension($_)) {
                    throw 'Path has to be a directory.'
                }
                return $true
            })]
        [System.IO.DirectoryInfo] $Path
    )
    $fileName = Split-Path -Path $Url -Leaf
    if ($null -ne $Path) {
        [System.IO.FileInfo] $localLocation = Join-Path -Path $Path -ChildPath $fileName
    } else {
        [System.IO.FileInfo] $localLocation = Join-Path -Path $Env:TMPDIR -ChildPath $fileName
    }
    Invoke-WebRequest -Uri $Url -OutFile $localLocation.FullName
    return $localLocation
}