function Get-AzStorageContainerStats {
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageContainer]
        $Container
    )

    begin {}

    process {
        $blob_continuation_token = $null

        $total_blob_count = 0
        $total_usage = 0
        $soft_delete_count = 0
        $soft_delete_usage = 0
        $snapshot_count = 0
        $snapshot_usage = 0
        $version_count = 0
        $version_usage = 0

        do {
            $blobs = $Container | Get-AzStorageBlob -IncludeDeleted -IncludeVersion -ConcurrentTaskCount 100 -MaxCount 5000 -ContinuationToken $blob_continuation_token 
            $blob_continuation_token = $null
            
            if ($blobs -ne $null) {
                $blob_continuation_token = $blobs[$blobs.Count - 1].ContinuationToken
              
                for ([int] $b = 0; $b -lt $blobs.Count; $b++) {
                    $total_blob_count++
                    $total_usage += $blobs[$b].Length
                
                    if ($blobs[$b].IsDeleted) {
                        $soft_delete_count++
                        $soft_delete_usage += $blobs[$b].Length
                    }
                
                    if ($blobs[$b].SnapshotTime -ne $null) {
                        $snapshot_count++
                        $snapshot_usage += $blobs[$b].Length
                    }
                
                    if ($blobs[$b].VersionId -ne $null) {
                        $version_count++
                        $version_usage += $blobs[$b].Length
                    }
                }
              
                if ($blob_continuation_token -ne $null) {
                    Write-Verbose ("Blob listing continuation token = {0}" -f $blob_continuation_token.NextMarker)
                }
            }
        } while ($blob_continuation_token -ne $null)
          
        return [PSCustomObject] @{ 
            Name                     = $Container.Name
            StorageAccountName       = $Container.Context.StorageAccountName
            TotalBlobCount           = $total_blob_count 
            TotalBlobUsageinGB       = $total_usage / 1GB
            SoftDeletedBlobCount     = $soft_delete_count
            SoftDeletedBlobUsageinGB = $soft_delete_usage / 1GB
            SnapshotCount            = $snapshot_count
            SnapshotUsageinGB        = $snapshot_usage / 1GB
            VersionCount             = $version_count
            VersionUsageinGB         = $version_usage / 1GB
        }
    }

    end {}
    
}


Function Restore-AzureDeletedBlob {
    [CmdletBinding()]
    param (
        # # Azure storage context
        # [Parameter(Mandatory)]
        # [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]
        # $Context,

        # # Blob Container Name
        # [Parameter(Mandatory)]
        # [String]
        # $ParameterName,

        # Deleted Blob Object
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageBlob]
        $Blob,

        # Azure Storage API Version
        # See https://learn.microsoft.com/en-us/rest/api/storageservices/previous-azure-storage-service-versions
        [Parameter()]
        [String]
        $Version = "2020-04-08"#"2023-05-03"
    )

    begin {
        # Import the AzureRM module
        Import-Module -Name "Az.Storage" -MinimumVersion "1.0.0" -Force -ErrorAction Stop

        $curlFound = Get-Command -Name "curl" -ErrorAction SilentlyContinue
        if ($null -eq $curlFound ) {
            Write-Error "curl not found in PATH. Please install or add curl to PATH to use this function."
            exit 1
        }

        $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
        $accessToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $resource).AccessToken
    }

    process {
        if ($Blob.IsDeleted -eq $false) {
            Write-Warning "Blob is not deleted yet: $($Blob.Name)"
            return
        }

        $date = (Get-Date).ToUniversalTime().ToString('R')

        $uri = ($Blob.BlobBaseClient.Uri.AbsoluteUri -replace "\?.*", "") + "?comp=undelete"
        # $uri = $Blob.BlobBaseClient.Uri.AbsoluteUri + "?comp=undelete"
        Write-Verbose "Restoring: $uri"
        curl `
            -v `
            -X "PUT" `
            -H "x-ms-date: $date" `
            -H "x-ms-version: $Version" `
            -H "x-ms-blob-type: $($Blob.BlobType)" `
            -H "Authorization: Bearer $accessToken" `
            -H "Content-Length: 0" `
            $uri
    }

    end {
        Remove-Module -Name "Az.Storage" -Force
    }
}

Function Copy-AzSqlInstanceDatabaseViaPointInTimeBackup {
    param(
        # Name of the database to recreate
        [Parameter(Mandatory = $true)]
        [String]
        $DatabaseName,

        # Name of the resource group where the source instance is located
        [Parameter(Mandatory = $true)]
        [String]
        $SourceResourceGroupName,

        # Name of the source instance
        [Parameter(Mandatory = $true)]
        [String]
        $SourceInstanceName,

        # Name of the target resource group where the target instance is located
        [Parameter(Mandatory = $true)]
        [String]
        $TargetResourceGroupName,

        # Name of the target instance
        [Parameter(Mandatory = $true)]
        [String]
        $TargetInstanceName,

        # Age of the backup to restore in minutes
        [Parameter(Mandatory = $false)]
        [Int]
        $BackupAgeInMinutes = 7
    )

    $source = @{
        ResourceGroupName = $SourceResourceGroupName
        InstanceName      = $SourceInstanceName
        DatabaseName      = $DatabaseName
    }

    $target = @{
        ResourceGroupName = $TargetResourceGroupName
        InstanceName      = $TargetInstanceName
        DatabaseName      = $DatabaseName
    }

    Write-Host "Copying database `"$($source.DatabaseName)`" from `"$($source.InstanceName)`" to `"$($target.InstanceName)`" ..."

    $sourceInstance = Get-AzSqlInstance `
        -ResourceGroupName $source.ResourceGroupName `
        -Name $source.InstanceName
    $sourceDatabase = $sourceInstance | Get-AzSqlInstanceDatabase -Name $source.DatabaseName

    if (-Not $?) {
        Write-Error "Database `"$($source.DatabaseName)`" does not exist on `"$($source.InstanceName)`"."
        exit 1
    }

    $BackupAgeInMinutes = $BackupAgeInMinutes * -1

    # Checking if the target time is older than the earliest restore point available on the source database.
    if ((Get-Date).AddMinutes($BackupAgeInMinutes) -lt $sourceDatabase.EarliestRestorePoint) {
        Write-Host "Your target restore point is older than the earliest restore point available on the source database. Please choose a more recent restore point. The earliest restore point available is `"$($sourceDatabase.EarliestRestorePoint)`""
        exit 1
    }

    $targetInstance = Get-AzSqlInstance `
        -ResourceGroupName $target.ResourceGroupName `
        -Name $target.InstanceName
    $targetDatabase = $targetInstance | Get-AzSqlInstanceDatabase -Name $target.DatabaseName -ErrorAction SilentlyContinue

    # Dropping the database if it exists on the target instance.
    if (-Not ($? -eq $false -And $null -eq $targetDatabase)) {
        Write-Host "Target Database `"$($targetDatabase.Name)`" already exists."

        ## Prompting the user to confirm the deletion of the database if -Force is not set.
        if (-Not $Force) {
            $deleteDatabase = Read-Host -Prompt "Do you want to delete the database and recreate it? (y/n)"
        }
        if (-Not $Force -And $deleteDatabase -ne "y") {
            Write-Host "Aborting."
            exit 1
        }
        
        $targetDatabase | Remove-AzSqlInstanceDatabase -Force | Out-Null
        if ($?) {
            Write-Host "Successfully deleted Target Database `"$($targetDatabase.Name)`"."
        } else {
            Write-Host "Failed to delete Target Database `"$($targetDatabase.Name)`"."
            exit 1
        }

        Write-Host "Waiting for the azure APIs to catch up ..."
        Start-Sleep -Seconds 10 # Wait for the azure APIs to catch up
    }

    Write-Host "Initiating restore of `"$($source.DatabaseName)`" from `"$($source.InstanceName)`" to `"$($target.InstanceName)`" ..."

    $sourceDatabase | Restore-AzSqlInstanceDatabase `
        -FromPointInTimeBackup `
        -PointInTime (Get-Date).AddMinutes($BackupAgeInMinutes) `
        -TargetResourceGroupName $targetInstance.ResourceGroupName `
        -TargetInstanceName $targetInstance.ManagedInstanceName `
        -TargetInstanceDatabaseName $target.DatabaseName |
    Out-Null

    if ($?) {
        Write-Host "Database `"$($source.DatabaseName)`" recreated successfully."
    } else {
        Write-Host "Database `"$($source.DatabaseName)`" recreated failed."
        exit 1
    }
}

# Function to retrieve all principals assigned to a given Azure AD role via Microsoft Graph API.
function Get-AzureEntraIdRoleAssignments {
    param (
        [Parameter(
            Position = 0,
            Mandatory = $true
        )]
        [String[]] $EntraIdRoles
    )
    
    Invoke-MgRestMethod -Method GET -Uri https://graph.microsoft.com/v1.0/directoryRoles |
    Select-Object -ExpandProperty value |
    Where-Object -Property displayName -In $EntraIdRoles |
    ForEach-Object {
        $role = $_
        $roleMembers = Invoke-MgRestMethod -Method GET -Uri https://graph.microsoft.com/v1.0/directoryRoles/$($role.id)/members
        $roleMembers.value | ForEach-Object {
            $member = $_
            if ($member.'@odata.type' -eq '#microsoft.graph.user') {
                $identity = Invoke-MgRestMethod -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$($member.id)?`$select=id,accountEnabled" |
                Add-Member -MemberType NoteProperty -Name type -Value "#microsoft.graph.user" -PassThru
            } elseif ($member.'@odata.type' -eq '#microsoft.graph.group') {
                $identity = Invoke-MgRestMethod -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$($member.id)" |
                Add-Member -MemberType NoteProperty -Name accountEnabled -Value $true -PassThru | 
                Add-Member -MemberType NoteProperty -Name type -Value "#microsoft.graph.group" -PassThru
            }
  
            [PSCustomObject]@{
                Role              = $role.displayName
                RoleId            = $role.id
                RoleMember        = $identity.displayName
                RoleMemberId      = $identity.id
                RoleMemberType    = $identity.type
                RoleMemberEnabled = $identity.accountEnabled
            }
        }
    }
}
  
# Function to retrieve all azure role assignments via Azure Resource Graph.
# This function used pagination to retrieve all role assignments.
function Get-AzureRbacAllRoleAssignments {
    $query = @"
authorizationresources
| where type == "microsoft.authorization/roleassignments"
| extend roleDefinitionId = tostring(properties.roleDefinitionId)
| extend shortRoleDefinitionId = split(roleDefinitionId, "/")[array_length(split(roleDefinitionId, "/")) - 1]
| extend principalType = tostring(properties.principalType)
| extend principalId = tostring(properties.principalId)
| extend scope = tostring(properties.scope)
| join kind=leftouter (
authorizationresources
| where type == "microsoft.authorization/roledefinitions"
| extend roleDefinitionId = tostring(id)
| extend roleDefinitionName = tostring(properties.roleName)
) on roleDefinitionId
| project principalId, principalType, shortRoleDefinitionId, roleDefinitionName, scope
"@
  
    $skipToken = $null
  
    do {
        $result = Search-AzGraph -UseTenantScope -Query $query -First 1000 -SkipToken $skipToken
        $skipToken = $result.SkipToken
  
        # Stream each result directly into the pipeline
        $result.Data | ForEach-Object { return $_ }
    } while ($skipToken)
}

# Function to retrieve principal information form Microsoft Graph API
function Get-AzurePrincipal {
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0,
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]$PrincipalId,
  
        [Parameter(
            Position = 1,
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateSet("User", "Group", "ForeignGroup", "ServicePrincipal")]
        [string]$PrincipalType
    )
  
    process {
        switch ($PrincipalType) {
            "User" {
                $principal = Get-MgUser -UserId $PrincipalId -Property Id, DisplayName, AccountEnabled
                break
            }
            { "Group" -or "ForeignGroup" } {
                $principal = Get-MgGroup -GroupId $PrincipalId
                break
            }
            "ServicePrincipal" {
                $principal = Get-MgServicePrincipal -ServicePrincipalId $PrincipalId
                break
            }
            default {
                return "Unknown Principal Type"
            }
        }
  
        return $principal
    }
}
